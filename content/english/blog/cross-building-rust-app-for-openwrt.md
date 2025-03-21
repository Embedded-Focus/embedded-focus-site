---
title: "Cross building Rust applications for Raspberry Pis"
authors: ["Rainer Poisel"]
lastmod: 2024-07-31T10:37:37+02:00
draft: false
image: "header.jpg"
toc: true
comments: true
tags: ["rust"]
categories: ["Embedded"]
---

In this article, we will demonstrate how to build Rust code for Raspberry Pi single-board computers (SBCs). We'll cover how to use libraries that require both an assembler and a C toolchain for the target platform.

<!--more-->


## Introduction {#introduction}

This article is about the challenges I had to cope with when building applications implemented in Rust for Raspberry Pi single-board computers (SBCs) and how I solved them. The [target application](https://www.emqx.com/en/blog/how-to-use-mqtt-in-rust) described in this article communicates via MQTT. The MQTT functionality is added to the project by third-party libraries.

Most of my home-automation Raspberry Pis run the [OpenWrt](https://openwrt.org/) Linux distribution. In one of our [previous articles](/blog/smart-home-requirements-and-architecture/) I described why I chose this distribution: it not only is minimal in terms of size and resulting attack surface but also because it is very easy to implement read-only systems that are reliable. While, in this article, our focus is on the Raspberry Pi 2 SBCs with their ARMv7 architecture, the principles discussed here can be adapted for newer Raspberry Pi models featuring AARCH64 CPUs.


## Related Work {#related-work}

Much has been written about cross-compiling Rust applications for Raspberry Pi single-board computers (SBC). The official [Rustup book](https://rust-lang.github.io/rustup/cross-compilation.html) provides a comprehensive overview of cross-compilation techniques. Additionally, Andrei Denisov's blog post [Building Rust code for my OpenWrt Wi-Fi router](https://blog.dend.ro/building-rust-for-routers/) offers valuable insights into cross-compiling for OpenWrt devices. As we will see, none of these resources describe how to deal with the situation that certain Rust crates require a pre-installed C/C++ toolchain.

Our approach builds upon these existing resources, addressing the gaps in handling complex dependencies. We'll guide you through installing the necessary toolchain, configuring Cargo for cross-compilation, and even building a custom cross-compilation toolchain using [crosstool-ng](https://crosstool-ng.github.io/). By the end of this article, you'll have a robust setup for cross-compiling Rust applications that can leverage C libraries on Raspberry Pi SBCs running OpenWrt.


## Building the Sample Application {#building-the-sample-application}

All source code created in this article can also be found in our companion repository on [GitHub](https://github.com/honeytreelabs/rust-cross-compile).

In this section, I will describe step-by-step how I built the aforementioned [target application](https://www.emqx.com/en/blog/how-to-use-mqtt-in-rust). This article assumes that you have Debian GNU/Linux or a similar distribution running on your machine. To follow along, additional prerequisites are:

-   [rustup](https://rustup.rs/) installed and
-   Docker installed, necessary in order to mitigate side-effects by tools such as [pyenv](https://github.com/pyenv/pyenv).


### Getting Started Building for ARMv7 Linux {#getting-started-building-for-armv7-linux}

OpenWrt builds on top of the [musl C library](https://musl.libc.org/). That's why we need a toolchain that links against this variant of the C library. Install the toolchain and including the required linker and additional development tools such as a binary stripper:

```shell
rustup toolchain install stable --target armv7-unknown-linux-musleabihf
```

In order to configure `cargo` to use the `lld-18` linker, the following has to be added to the `.cargo/config.toml` file in your project:

```toml
[target.armv7-unknown-linux-musleabihf]
linker = "rust-lld"
```

Note that this does ****not**** go into your project's `Cargo.toml`! Further information can be found in the [Config](https://doc.rust-lang.org/cargo/reference/config.html) section of The Cargo Book.

Then, `cargo` allows for building the application for the Raspberry Pi SBCs:

```shell
cargo build --release --target armv7-unknown-linux-musleabihf
```

However, this gives an error:

> warning: ring@0.17.8: Compiler family detection failed due to error: ToolNotFound: Failed to find tool. Is \`arm-linux-musleabihf-gcc\` installed?
>
> error: failed to run custom build command for \`ring v0.17.8\`


### Dealing with the ring Crate Dependency {#dealing-with-the-ring-crate-dependency}

The [ring crate](https://crates.io/crates/ring) is a Rust library that focuses on the implementation, testing, and optimization of a core set of cryptographic operations exposed via an easy-to-use (and hard-to-misuse) API. It is written in a hybrid of Rust, C, and assembly language. This package needs a cross-toolchain (actually, only an assembler for the ARMv7 platform is needed) for Linux running on the ARM platform, linking to the musl C library. There is a handy tool that allows us to build such a toolchain with minimal effort: [crosstool-ng](https://crosstool-ng.github.io/).

In order to reduce the side-effects when working on my production system, I decided to perform building the toolchain in a Docker Compose environment.

The `docker compose` service definition looks like this - we only have a single service for now:

<a id="code-snippet--compose.yaml"></a>
```yaml
---
services:
  debian:
    build:
      context: .
      dockerfile: Dockerfile.debian
    command: tail -f /dev/null
    volumes:
      - "${HOME}:/home/host_user"
```

This `compose.yaml` file defines a service named `debian` which is built from a Dockerfile located in the current directory. The service mounts the user's home directory into the container to allow access to files on the host system. The container runs indefinitely with the command `tail -f /dev/null`, effectively idling until we attach to it.

The referenced `Dockerfile.debian` has the contents shown in the next listing. You might have to adapt the user and group IDs to the ones used on your system:

<a id="code-snippet--Dockerfile.debian"></a>
```dockerfile
FROM debian:unstable

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update \
    && apt install -y \
        autoconf \
        bison \
        build-essential \
        curl \
        file \
        flex \
        gawk \
        git \
        help2man \
        libncurses-dev \
        libtool-bin \
        python3 \
        python3-dev \
        python-is-python3 \
        libpython3-dev \
        rsync \
        texinfo \
        tmux \
        unzip \
        wget

ARG USER_ID
ARG GROUP_ID

RUN groupadd -g "${USER_ID}" user \
    && useradd -d /home/user --create-home -u "${USER_ID}" -g "${GROUP_ID}" -s /bin/bash user

USER ${USER_ID}:${GROUP_ID}

WORKDIR /home/user

RUN mkdir git \
    && cd git \
    && git clone https://github.com/crosstool-ng/crosstool-ng.git \
    && cd crosstool-ng \
    && ./bootstrap \
    && ./configure --prefix="${HOME}/crosstool-ng-git" \
    && make \
    && make install
```

This `Dockerfile.debian` starts with the `debian:unstable` base image. It sets the `DEBIAN_FRONTEND` environment variable to `noninteractive` to avoid interactive prompts during package installation. The `RUN` commands update the package list and install several development tools needed for building the cross-toolchain. These tools include build essentials like `autoconf`, `bison`, `gcc`, `git`, and others required by crosstool-NG.

A new user group and user are created to avoid running as root, ensuring a safer environment. The `WORKDIR` is set to the home directory of this user. Finally, the script clones the crosstool-NG repository, bootstraps it, and installs it to the specified prefix directory.

Place the two files (the `Dockerfile.debian` and `compose.yaml`) into a directory. You can then bring up the Docker container in this directory with the following commands:

```shell
docker compose build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g)
docker compose up -d
docker compose exec -ti debian bash
```

As an alternative to providing `--build-arg` arguments to the `docker compose build` command, it may be more convenient to use [direnv](https://direnv.net) and define the required environment variables in a `.envrc` file. These variables can then be used in the `compose.yaml` file. See the [official docker compose documentation](https://docs.docker.com/compose/environment-variables/variable-interpolation/) for more information on that.

The crosstool NG utility allows for configuring the toolchain with similar mechanisms to the configuration mechanisms of the Linux kernel. The most convenient way to get started is to use one of the samples that comes with crosstool NG. Inside the `debian` docker container invoke the following commands:

```shell
# lists available samples including their current state
./crosstool-ng-git/bin/ct-ng list-samples

# choose sample as starting point:
./crosstool-ng-git/bin/ct-ng armv7-rpi2-linux-gnueabihf
```

This toolchain is based on the GNU C library. However, we want it to build upon the musl C library. To achieve this, this C library has to be configured either by crosstool NGs menu configuration system or by manipulating the `.config` configuration file by hand.

In order to make our toolchain suitable for Raspberry Pi 2 SBCs running OpenWrt, adjust the following configuration settings using the `menuconfig` utility:

```shell
# lists available samples including their current state
./crosstool-ng-git/bin/ct-ng menuconfig
```

-   Toolchain options =&gt; Tuple's alias: `arm-linux-musleabihf`
    -   This is the name of the toolchain executables, the `ring` crate is searching for
-   Operating System =&gt; Version of linux: `5.3.9`
    -   My Raspberries are currently running 5.4.179
-   C-library =&gt; C library: musl
    -   This is the target C library we want our application to link against.

Exit the `menuconfig` utility and save your configuration to the `.config` file. After this, the toolchain can be built by issuing:

```shell
./crosstool-ng-git/bin/ct-ng build
```

This process takes approximately 30 minutes. The resulting toolchain resides in `${HOME}/x-tools/armv7-rpi2-linux-musleabihf` within the `debian` container/service. When building software in a CI system, the compiler can be provided by an artifact server such as [Artifactory](https://jfrog.com/artifactory/) or [pulp](https://pulpproject.org/). In addition to that, the compiler can also be part of a docker image that will be used in a CI/CD environment to build applications.

Crosstool NG installs built toolchains into the user's `${HOME}/x-tools` directory. In order to use the newly built toolchain on your host, you have to copy it there, e.g. by invoking the commands of the next listing in the `debian` container:

```shell
mkdir -p /home/host_user/x-tools
cp -R "${HOME}/x-tools/armv7-rpi2-linux-musleabihf" /home/host_user/x-tools
```

Let's try again building our Rust application by adding the `arm-linux-musleabihf-gcc` to our `PATH`:

```shell
PATH="${HOME}/x-tools/armv7-rpi2-linux-musleabihf/bin:${PATH}" \
    cargo build --target armv7-unknown-linux-musleabihf
```

Result:

```shell
   Compiling libc v0.2.155
   ...
   Compiling mqtt-rust-example v0.1.0 (/home/user/git/honeytreelabs/rust-cross-compile)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 7.27s
```

The resulting binary can be found in the `target` directory. Its binary size is 47M. Pretty large for an application that sends a few MQTT messages. Assuming we don't need any debug information, the easiest way to reduce binary size is to strip these symbols. Stripping resulting binaries can be configured in the project's `Cargo.toml` file:

```toml
[profile.release]
strip="symbols"
```

In order to build a release version of our application, we have to pass the `--release` flag to `cargo`:

```shell
PATH="${HOME}/x-tools/armv7-rpi2-linux-musleabihf/bin:${PATH}" \
    cargo build --release --target armv7-unknown-linux-musleabihf
```

```shell
   Compiling libc v0.2.155
   ...
   Compiling mqtt-rust-example v0.1.0 (/home/user/git/honeytreelabs/rust-cross-compile)
    Finished `release` profile [optimized] target(s) in 9.34s
```

The resulting binary has 2.1M. That's handy and very well suitable to be deployed to our little Raspberry Pi as well. To try it out, we don't even need a Raspberry Pi at hand. [Qemu](https://www.qemu.org/) to the rescue. Let's emulate Linux for the ARMv7 platform in user-space:

```shell
sudo apt install qemu-user
qemu-arm ./target/armv7-unknown-linux-musleabihf/release/asyncpubsub
```

Result:

```shell
Reading package lists...
Building dependency tree...
Reading state information...
qemu-user is already the newest version (1:9.0.2+ds-1).
Summary:
  Upgrading: 0, Installing: 0, Removing: 0, Not Upgrading: 1
Event = Incoming(ConnAck(ConnAck { session_present: false, code: Success }))
Event = Outgoing(Subscribe(1))
Event = Outgoing(Publish(2))
Event = Incoming(SubAck(SubAck { pkid: 1, return_codes: [Success(AtMostOnce)] }))
Event = Outgoing(PubRel(2))
...
```

Great, our executable works. Let's also try it on my Raspberry Pi. First, we need to copy the executable to the Raspberry Pi. Please not the `-O` flag which is necessary for newer SSH programs to work with older versions of them:

```shell
scp -O ./target/armv7-unknown-linux-musleabihf/release/asyncpubsub raspberry:/tmp
```

My Raspberry Pi runs an outdated version of OpenWrt. Let's see if it still runs there:

```shell
ssh raspberry


BusyBox v1.33.2 (2022-02-16 20:29:10 UTC) built-in shell (ash)

  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__| W I R E L E S S   F R E E D O M
 -----------------------------------------------------
 OpenWrt 21.02.2, r16495-bf0c965af0
 -----------------------------------------------------
root@raspberry:~# /tmp/asyncpubsub
Event = Incoming(ConnAck(ConnAck { session_present: false, code: Success }))
Event = Outgoing(Subscribe(1))
Event = Outgoing(Publish(2))
Event = Incoming(SubAck(SubAck { pkid: 1, return_codes: [Success(AtMostOnce)] }))
Event = Outgoing(PubRel(2))
```

Et voila. Great, it works. We are now able to build Rust applications for the Raspberry Pi platform.


## Conclusion and Outlook {#conclusion-and-outlook}

In this blog post, we built a custom C/C++ toolchain for Raspberry Pi SBCs running OpenWrt to enable the compilation of Rust applications that require such a toolchain for integrating dependent libraries. To mitigate any potential side effects during this process, we performed these build steps within dedicated Docker containers.

In future blog posts, we plan to describe how to improve software quality of Rust projects through CI/CD practices. For now, we test these binaries by running them manually on the machine. However, it is also be possible to deploy and test them automatically on the target hardware with frameworks such as [pytest](https://pytest.org) and [labgrid](https://pengutronix.de/de/software/labgrid.html).
