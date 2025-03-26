---
title: "Sharing Variables between GNU Make and the Bash"
authors: ["Rainer Poisel"]
lastmod: 2022-10-24T23:11:21+02:00
draft: false
toc: true
comments: true
image: "header.jpg"
tags: ["make", "shell", "bash"]
categories: ["Coding"]
canonical: "https://honeytreelabs.com/posts/sharing-variables-between-gnu-make-and-the-bash/"
---

Both GNU Make and Bourne Again SHell allow for using variables. This post explains how to share them between these two tools.

<!--more-->


## Motivation {#motivation}

If you don't want to read all this and just see how it's done, for your convenience, all files mentioned in this article can be downloaded as a GitHub Gist: [Link](https://gist.github.com/rpoisel/c32033705b2aa8747d1ca5f5442a559a).

Let's first look at a typical application scenario. I am often working with several different hosts which are running a container runtime. Typical parameters involved in these cases are, e.g.

-   the [docker context](https://docs.docker.com/engine/context/working-with-contexts/), or
-   the [paths](https://docs.docker.com/compose/environment-variables/) to relevant `docker-compose.yaml` files when stacking them.

These parameters can be supplied to `docker compose` by setting environment variables before invoking it. Of course, these parameters shall be versioned in version control system (VCS) as any other project data.

In addition to that, suppose some tasks of your projects tasks have already been automated using GNU Make. The following question arises:

How can environment variables not only be versioned in git, but also be shared between Makefiles and shell sessions, so that they are used by direct invocations of `docker compose`?


## Step 1: Extract Variables from Your Makefile {#step-1-extract-variables-from-your-makefile}

One of the key elements to separate variable definitions from Makefiles is the `include` [directive](https://www.gnu.org/software/make/manual/html_node/Include.html). This directive suspends reading the current makefile and reads one or more other makefiles before continuing, e.g.:

```makefile
include env
export
```

In this case, the given Makefile includes the contents of a file called `env` from the same path as the Makefile. The `export` keyword makes sure that all variables known to GNU Make are also [exposed as environment variables](https://www.gnu.org/software/make/manual/make.html#Variables_002fRecursion) to tools invoked by it.

In our situation, the `env` file only contains variable definitions:

```shell
COMPOSE_FILE=../ts-client/docker-compose.yaml:docker-compose.myproject.yaml
DOCKER_CONTEXT=mycontext
COMPOSE_PROJECT_NAME=myproject
```

After including the aforementioned file, these variables can be referenced in the Makefile:

```makefile
all:
	@echo $(COMPOSE_FILE)
```

Now, these variables should also be made available to the current Bash session.


## Step 2: Set EnvVars depending on your CWD {#step-2-set-envvars-depending-on-your-cwd}

The next key element we need to look at is some kind of hook, the shell executes when changing directories. [direnv](https://direnv.net/) is such an extension to shells which allows to load/unload environment variables depending on the current directory.

After installing `direnv` in the system, the hook is enabled by adding the following to the <span class="inline-src language-sh" data-lang="sh">`~/.bashrc`</span> file:

```shell
eval "$(direnv hook bash)"
```

With this setup, `direnv` searches for a `.envrc` file in every directory when entering. In case it finds such file, it executes it in a subshell. Only the environment variables of this subshell are then passed to the current shell session. The containing directory must be "enabled" by issuing `direnv allow .`

The next step is to make sure that the `.envrc` file exports the files from the `env` file which is also included by our Makefile:

```shell
file=$(cat env)

for line in $file; do
	export "${line}"
done
```


## Conclusion {#conclusion}

With this approach, we can comply with the [DRY principle](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself). Variables are defined only once in the `env` file and are available to both GNU Make and the current shell session.
