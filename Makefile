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

all:
	@echo "Please choose a target manually."

static/en:
	mkdir -p static/en

.PHONY: htaccess
htaccess:
	echo "ErrorDocument 404 $(BASEDIR)/404.html" > static/.htaccess
	echo "RewriteEngine On" >> static/.htaccess
	echo "RewriteCond %{HTTP_HOST} !^$(DOMAIN)$$ [NC]" >> static/.htaccess
	echo "RewriteRule ^(.*)$$ https://$(DOMAIN)/\$$1 [R=301,L]" >> static/.htaccess
ifeq ($(VERSION),preview)
	echo "AuthType Basic" >> static/.htaccess
	echo "AuthName \"Restricted Area\"" >> static/.htaccess
	echo "AuthUserFile /var/www/vhosts/$(HOSTING)/$(DOMAIN)/.htpasswd" >> static/.htaccess
	echo "Require valid-user" >> static/.htaccess
endif

	echo "ErrorDocument 404 $(BASEDIR)/en/404.html" > static/en/.htaccess
	echo "RewriteEngine On" >> static/en/.htaccess
	echo "RewriteCond %{HTTP_HOST} !^$(DOMAIN)$$ [NC]" >> static/en/.htaccess
	echo "RewriteRule ^(.*)$$ https://$(DOMAIN)/en/\$$1 [R=301,L]" >> static/en/.htaccess
ifeq ($(VERSION),preview)
	echo "AuthType Basic" >> static/en/.htaccess
	echo "AuthName \"Restricted Area\"" >> static/en/.htaccess
	echo "AuthUserFile /var/www/vhosts/$(HOSTING)/$(DOMAIN)/.htpasswd" >> static/en/.htaccess
	echo "Require valid-user" >> static/en/.htaccess
endif

build: htaccess | static/en
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

