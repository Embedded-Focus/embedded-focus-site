SHELL := /bin/bash

ifeq ($(PLATFORM),Darwin)
	LISTEN_ADDR := "localhost"
else
	LISTEN_ADDR := $(shell if tailscale status --self --json 2>/dev/null | jq -e 'select(.BackendState == "Running")' >/dev/null 2>&1; then tailscale ip -4; else echo "localhost"; fi)
endif

ENVIRONMENT ?= production
BASEURL ?= $(shell yq '.baseURL' < hugo.yaml)
DOMAIN ?= $(shell echo $(BASEURL) | sed 's|https://\([^/]\+\).*$$|\1|')
BASEDIR := $(shell echo $(BASEURL) | sed -E 's|^[^/]+://[^/]+/?([^/]*)?.*$$|\1|')
UMAMI_ID := $(shell echo $${UMAMI_ID_$(VERSION)})

all:
	@echo "Please choose a target manually."

static/en:
	mkdir -p static/en

ifeq ($(VERSION),preview)
define generate_htpasswd
	echo "AuthType Basic" >> $(1)/.htaccess
	echo "AuthName \"Restricted Area\"" >> $(1)/.htaccess
	echo "AuthUserFile /var/www/vhosts/$(HOSTING)/$(DOMAIN)/.htpasswd" >> $(1)/.htaccess
	echo "Require valid-user" >> $(1)/.htaccess
endef
else
define generate_htpasswd
endef
endif

define generate_htaccess
	echo "ErrorDocument 404 $(BASEDIR)/$(1)/404.html" > $(1)/.htaccess
	echo "RewriteEngine On" >> $(1)/.htaccess
	echo "RewriteCond %{HTTP_HOST} !^$(DOMAIN)$$ [NC]" >> $(1)/.htaccess
	echo "RewriteRule ^(.*)$$ https://$(DOMAIN)/$(1)/\$$1 [R=301,L]" >> $(1)/.htaccess
	$(call generate_htpasswd,$(1))
endef

.PHONY: static/.htaccess
static/.htaccess:
	$(call generate_htaccess,static)

.PHONY: static/en/.htaccess
static/en/.htaccess:
	$(call generate_htaccess,static/en)

.PHONY: htaccess
htaccess: static/.htaccess static/en/.htaccess

build: htaccess | static/en
	yq -i '.params.umami.id = "$(UMAMI_ID)"' hugo.yaml
	yamlfmt hugo.yaml
	hugo build --baseURL $(BASEURL) --environment $(ENVIRONMENT)

hugo.yaml.in: themes/hugoplate/exampleSite/hugo.toml
	yq -P -p toml -o yaml < $^ > $@
	yamlfmt $@

.PHONY: update-yamls
update-yamls:
	(cd themes/hugoplate/exampleSite && fdfind . -e '.toml' -x sh -c 'yq -oy -ptoml . < "$${1}" > "../../../$${1%.toml}.yaml"' _ {})
	fdfind . -e '.yaml' -E themes -x yamlfmt {}

.PHONY: clean-go-modules
clean-go-modules:
	hugo mod clean --all

.PHONY: update-go-modules
update-go-modules:
	cp themes/hugoplate/exampleSite/go.mod .
	hugo mod get -u
	hugo mod tidy

.PHONY: build
serve: BASEURL := http://$(LISTEN_ADDR):1313/
serve:
	hugo serve \
		--bind $(LISTEN_ADDR) \
		--baseURL $(BASEURL) \
		--environment $(ENVIRONMENT) \
		--disableFastRender

.PHONY: deploy-preview
deploy-preview:
	$(MAKE) build BASEURL=https://preview.embedded-focus.com/ VERSION=preview
	rsync -avz -e ssh --rsync-path="/tmp/rsync" public/ netcup:/preview.embedded-focus.com/httpdocs/

.PHONY: deploy-release
deploy-release:
	$(MAKE) build BASEURL=https://embedded-focus.com/ VERSION=release
	rsync -avz -e ssh --rsync-path="/tmp/rsync" public/ netcup:/embedded-focus.com/httpdocs/

.PHONY: install-fonts
install-fonts:
	uv sync
	./.venv/bin/python scripts/self_host_fonts_css.py ./data/theme.json themes/hugoplate/assets/css/fonts.css themes/hugoplate/static/fonts /fonts

