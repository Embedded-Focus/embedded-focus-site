---
title: "Developing Software for the Ubiquiti G4 Doorbell"
authors: ["Rainer Poisel", "Stefan Riegler"]
lastmod: 2022-11-21T22:13:01+01:00
draft: false
image: "header.png"
toc: true
comments: true
tags: ["c++"]
categories: ["Coding"]
canonical: "https://honeytreelabs.com/posts/developing-software-for-the-ubiquiti-g4-doorbell/"
---

What is special about a radio doorbell? Press the button and wait for someone to open the door. What if things are more complex than that?

<!--more-->


## Introduction {#introduction}

In this article, we want to prepare an environment to port arbitrary C/C++ software to the [Ubiquiti G4 doorbell](https://store.ui.com/products/uvc-g4-doorbell). In the course of the article we will find out that this doorbell is a quite potent platform having more than enough power to even run quite complex software such as games. The Ubiquiti G4 Doorbell is a Linux-based device that provides a comprehensive platform with familiar services and access capabilities.


## Obtaining and Analyzing the Firmware {#obtaining-and-analyzing-the-firmware}

The G4 doorbell can be accessed using `ssh`. The user is usually `ubnt` for peripheral devices and `root` for the controller. The password is the recovery password set for the devices, which can be found in the general settings of the Protect application. On the device, the SSH service is implemented by [dropbear](https://matt.ucc.asn.au/dropbear/dropbear.html). It considers the `/etc/dropbear/authorized_keys` file, allowing for password-less logins. However, the file is not persisted to the device' flash memory.

To obtain the firmware from the device, it is possible to do this using `tar` via `ssh`. Some exceptions have to be defined. Otherwise, not only unnecessary files will be transferred, but pseudo file systems such as proc with its files of virtually infinite size will make it impossible to finish this operation at all.

```shell
(
  ssh ubnt@doorbell 'sh -s' <<-"EOF"
	echo "sys/*" > /tmp/tar-excludes
	echo "run/udev/*" >> /tmp/tar-excludes
	echo "proc/*" >> /tmp/tar-excludes
	tar c -X /tmp/tar-excludes -vf - /
	EOF
) | gzip -v9 -c - > /tmp/g4/v4.55.5_public.tar.gz
```

In the next step we will analyze the binaries to get a better understanding of the platform the doorbell is based on. First, we have to extract one of the binaries in the image. Typically, embedded Linux systems are based on [busybox](https://busybox.net/) which is located in `/bin/busybox`:

```shell
cd /tmp/g4
tar tvf v4.55.5_public.tar.gz ./bin/busybox
tar xf v4.55.5_public.tar.gz ./bin/busybox
```

```shell
-rwxr-x--- 501/staff    566312 2022-07-04 16:19 ./bin/busybox
```

A look into the header of the binary reveals, that this is a 64-bit ARM platform (aarch64):

```shell
file ./bin/busybox
```

```shell
./bin/busybox: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, for GNU/Linux 3.7.0, BuildID[sha1]=d8d2fb06d04174adea5ddb3eab569d90bd92d5b0, stripped
```

Using [qemu](https://www.qemu.org/) and the wonderful [`binfmt_misc` kernel mdoule](https://packages.debian.org/sid/binfmt-support), we can try to run the firmware directly in user-space on the current platform:

```shell
cd /tmp/g4

# install emulator packages
sudo apt install binfmt-support qemu-user-static

# extract firmware, install emulator into firmware root filesystem
mkdir -p firmware
sudo tar xf v4.55.5_public.tar.gz -C firmware
sudo cp $(command -v qemu-aarch64-static) firmware/usr/bin

# run a program telling us the emulated platform
sudo chroot firmware /bin/uname -a
```

```shell
Reading package lists...
Building dependency tree...
Reading state information...
binfmt-support is already the newest version (2.2.2-1+b1).
qemu-user-static is already the newest version (1:7.1+dfsg-2+b2).
0 upgraded, 0 newly installed, 0 to remove and 2 not upgraded.
Linux machine.lan 6.0.0-4-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.0.8-1 (2022-11-11) aarch64 GNU/Linux
```

The last line shows us that `uname` thinks that it is running in a 64-bit ARM environment. Great, so we can now run the G4 software on our machine as well. This will help us to analyze and debug software we built for the G4 without the actual device. It would also be possible to run automated tests for this platform in an emulator.

If we want to work with the firmware interactively, we can also run a shell:

```shell
cd /tmp/g4

# run a program telling us the emulated platform
sudo chroot firmware /bin/sh
```

```shell
BusyBox v1.34.1 (2022-07-04 14:19:13 UTC) built-in shell (ash)

# ls -la /lib/libc*
-rwxr-x---    1 501      50         1255024 Jul  4 16:19 /lib/libc-2.23.so
lrwxrwxrwx    1 501      50              12 Jul  4 16:38 /lib/libc.so.6 -> libc-2.23.so
lrwxrwxrwx    1 501      50              11 Jul  4 16:38 /lib/libcap.so -> libcap.so.2
lrwxrwxrwx    1 501      50              14 Jul  4 16:38 /lib/libcap.so.2 -> libcap.so.2.25
-rw-r-----    1 501      50           18568 Jul  4 16:19 /lib/libcap.so.2.25
lrwxrwxrwx    1 501      50              15 Jul  4 16:38 /lib/libcgi.so.1 -> libcgi.so.1.0.0
-rwxr-x---    1 501      50           22368 Jul  4 16:19 /lib/libcgi.so.1.0.0
lrwxrwxrwx    1 501      50              19 Jul  4 16:38 /lib/libcharset.so -> libcharset.so.1.0.0
lrwxrwxrwx    1 501      50              19 Jul  4 16:38 /lib/libcharset.so.1 -> libcharset.so.1.0.0
-rw-r-----    1 501      50            8024 Jul  4 16:19 /lib/libcharset.so.1.0.0
-rwxr-x---    1 501      50          186536 Jul  4 16:19 /lib/libcidn-2.23.so
lrwxrwxrwx    1 501      50              15 Jul  4 16:38 /lib/libcidn.so.1 -> libcidn-2.23.so
-rwxr-x---    1 501      50           30832 Jul  4 16:19 /lib/libcrypt-2.23.so
lrwxrwxrwx    1 501      50              16 Jul  4 16:38 /lib/libcrypt.so.1 -> libcrypt-2.23.so
-rw-r-----    1 501      50         2494040 Jul  4 16:19 /lib/libcrypto.so.1.1
-rwxr-x---    1 501      50           67624 Jul  4 16:19 /lib/libcryptoauth.so
lrwxrwxrwx    1 501      50              16 Jul  4 16:38 /lib/libcurl.so.4 -> libcurl.so.4.5.0
-rwxr-x---    1 501      50          305296 Jul  4 16:19 /lib/libcurl.so.4.5.0
#
```


## Building Software for the G4 Platform {#building-software-for-the-g4-platform}

Now that we have an environment to run G4 software on our host, we can try to build our own programs and execute them in the emulator before transferring them to the actual hardware.

[Linaro](https://www.linaro.org/downloads/#gnu_and_llvm) and [arm (deprecated toolchains page)](https://developer.arm.com/downloads/-/gnu-a) offer several toolchains in different versions. I guess, that an older version of GCC bound to an older version of the `libc` library has been used to create binaries for this platform. So, let's analyze the contained `libc` library first to get a rough estimate:

```shell
cd /tmp/g4
echo "Check for musl libc"
strings firmware/lib/libc.so.6 | grep musl
echo "Check for glibc"
strings firmware/lib/libc.so.6 | grep glibc
```

```shell
Check for musl libc
Check for glibc
glibc 2.23
```

Typically, embedded Linux systems rely on the [musl libc](https://musl.libc.org/). But in this case we are dealing with a fully-fledged [glibc 2.23](https://www.gnu.org/software/libc/) from [around 2016](https://sourceware.org/glibc/wiki/Glibc%20Timeline). When looking for suitable toolchains, we will have to look for the [target triplet](https://wiki.osdev.org/Target_Triplet):

-   CPU family/model: `aarch64`
-   Vendor: &lt;none&gt;
-   Operating System: `linux-gnu`

So, something like `aarch64-linux-gnu`. The [arm developer page](https://developer.arm.com/downloads/-/gnu-a) provides GCC versions from 2018 containing this triplet. After downloading such a package, the contained libc can be analyzed:

```shell
cd /tmp/g4
curl -LO https://developer.arm.com/-/media/Files/downloads/gnu-a/8.2-2018.08/gcc-arm-8.2-2018.08-x86_64-aarch64-linux-gnu.tar.xz
tar xf gcc-arm-8.2-2018.08-x86_64-aarch64-linux-gnu.tar.xz
cd gcc-arm-8.2-2018.08-x86_64-aarch64-linux-gnu
fdfind 'libc.*\.so'
```

```shell
./aarch64-linux-gnu/libc/lib64/libc-2.28.so
./aarch64-linux-gnu/libc/lib64/libc.so.6
./aarch64-linux-gnu/libc/lib64/libcrypt-2.28.so
./aarch64-linux-gnu/libc/lib64/libcrypt.so.1
./aarch64-linux-gnu/libc/usr/lib64/gconv/libCNS.so
./aarch64-linux-gnu/libc/usr/lib64/libc.so
./aarch64-linux-gnu/libc/usr/lib64/libcrypt.so
./lib/gcc/aarch64-linux-gnu/8.2.1/plugin/libcc1plugin.so
./lib/gcc/aarch64-linux-gnu/8.2.1/plugin/libcc1plugin.so.0
./lib/gcc/aarch64-linux-gnu/8.2.1/plugin/libcc1plugin.so.0.0.0
./lib/gcc/aarch64-linux-gnu/8.2.1/plugin/libcp1plugin.so
./lib/gcc/aarch64-linux-gnu/8.2.1/plugin/libcp1plugin.so.0
./lib/gcc/aarch64-linux-gnu/8.2.1/plugin/libcp1plugin.so.0.0.0
./lib64/libcc1.so
./lib64/libcc1.so.0
./lib64/libcc1.so.0.0.0
```

The contained `libc` is too new (2.28 vs 2.23). We have to look for an older toolchain. But these are only available from Linaro. Thanks to their archive, older releases are easy to find and download, e.g. [version 6.5.0](https://releases.linaro.org/components/toolchain/binaries/6.5-2018.12/aarch64-linux-gnu/). The same steps as above have to be repeated with the older toolchain:

```shell
curl -LO https://releases.linaro.org/components/toolchain/binaries/6.5-2018.12/aarch64-linux-gnu/gcc-linaro-6.5.0-2018.12-x86_64_aarch64-linux-gnu.tar.xz
tar xf gcc-linaro-6.5.0-2018.12-x86_64_aarch64-linux-gnu.tar.xz
cd gcc-linaro-6.5.0-2018.12-x86_64_aarch64-linux-gnu
fdfind 'libc.*\.so'
```

```shell
./aarch64-linux-gnu/libc/lib/libc-2.23.so
./aarch64-linux-gnu/libc/lib/libc.so.6
./aarch64-linux-gnu/libc/lib/libcidn-2.23.so
./aarch64-linux-gnu/libc/lib/libcidn.so.1
./aarch64-linux-gnu/libc/lib/libcrypt-2.23.so
./aarch64-linux-gnu/libc/lib/libcrypt.so.1
./aarch64-linux-gnu/libc/usr/lib/gconv/libCNS.so
./aarch64-linux-gnu/libc/usr/lib/libc.so
./aarch64-linux-gnu/libc/usr/lib/libcidn.so
./aarch64-linux-gnu/libc/usr/lib/libcrypt.so
./lib/gcc/aarch64-linux-gnu/6.5.0/plugin/libcc1plugin.so
./lib/gcc/aarch64-linux-gnu/6.5.0/plugin/libcc1plugin.so.0
./lib/gcc/aarch64-linux-gnu/6.5.0/plugin/libcc1plugin.so.0.0.0
./lib/libcc1.so
./lib/libcc1.so.0
./lib/libcc1.so.0.0.0
```

It seems we have found exactly what we have been looking for! 🙂 The `libc` versions match now. We should now be able to build binaries for this platform. Let's try our first sample:

```cpp { linenos=true, linenostart=1 }
#include <stdio.h>

int main(void) {
  printf("Hello, honeytreeLabs!\n");
  return 0;
}
```

```shell
cd /tmp/g4
./gcc-arm-8.2-2018.08-x86_64-aarch64-linux-gnu/bin -Wall -Wextra -O3
./gcc-linaro-6.5.0-2018.12-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-gcc -Wall -Wextra -O3 -o hello hello.c

# check resulting binary
file hello
echo

# copy into firmware and run
sudo mv hello firmware/usr/bin
sudo chroot firmware hello
```

```shell
hello: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, for GNU/Linux 3.7.0, BuildID[sha1]=63748bf473812fdc9d476e5a880e6e3f9b4f971a, with debug_info, not stripped

Hello, honeytreeLabs!
```

It works. The resulting binary is built for the aarch64 platform and can be run in `qemu` directly on our host. We now have the perfect cross-development setup.


## Conclusion {#conclusion}

We analyzed the Ubiquiti G4 Doorbell's firmware and created software that can be executed in the `qemu` emulator or directly on the device. After gaining access to the device, we transferred the firmware to our host system.

When searching for a suitable C/C++ toolchain, one crucial step was to identify the `libc` library used in the devices' firmware. In this case, Linaro offered a toolchain which perfectly matches the given platform.

In the next step we will interface with the Linux Frame Buffer Device as this is the display device used by the G4 doorbell to display information to its users. Our ultimate goal is to port some well-known software marvel to this device. What would it be? Stay tuned!
