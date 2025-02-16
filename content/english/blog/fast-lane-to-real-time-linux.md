---
title: "Fast-lane to Real-Time Linux: How to Set Up Your System"
authors: ["Rainer Poisel"]
lastmod: 2022-11-25T18:00:58+01:00
draft: false
image: "header.jpg"
toc: true
tags: ["linux", "embedded"]
categories: ["Coding"]
---

Have you ever had the need to quickly get access to real-time Linux to test your apps? This article explains how to achieve this goal.

<!--more-->


## Introduction {#introduction}

Sometimes you need a real-time Linux system at hand quickly. Debian GNU/Linux already contains prepared real-time kernels that can be conveniently installed via the package manager. Therefore, assuming an installed Debian system, a real-time Linux system is often just installing the kernel packages and booting the real-time kernel away.

A typical use case for using these packages is to quickly get a feel for whether a developed real-time application basically meets the requirements placed on it. Of course, the presented approach has limitations: the actual real-time behavior of a system has to be measured and tested individually over longer periods of time on the real hardware.


## Procedure {#procedure}

Assuming an existing Debian installation, you can install the `PREEMPT_RT` [kernel packages](https://packages.debian.org/search?keywords=linux-image-rt-amd64&searchon=names&suite=all&section=all) with a few commands:

```shell
sudo apt update
sudo apt install linux-image-rt-amd64
```

After that, reboot the system. Make sure to enter the BIOS (typically, using the F2, F8, F10, or F12 keys). As someone who cares about low power consumption (reduced carbon footprint), I never thought I'd share this tip: turn off all power management or energy saving options. Typical keywords for this are "ACPI", "APM" or anything that has "power" in its name. This is important to make sure the system is ready to execute all commands at the right time (literally).


## Verification of the Real-Time Capabilities {#verification-of-the-real-time-capabilities}

Now that we have an environment to run our real-time applications, we can try that. The Linux Foundation offers a test suite to test various real-time Linux features. Further information can be found in their Wiki: [RT-Tests](https://wiki.linuxfoundation.org/realtime/documentation/howto/tools/rt-tests).

Building these applications requires the installation of some additional packages:

```shell
sudo apt install libnuma-dev build-essential git make
```

Building them involves cloning the git repository, checking out the stable branch and triggering the actual build using GNU `make`:

```shell
git clone git://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git
cd rt-tests
git checkout stable/v1.0
make all
```

```shell
branch 'stable/v1.0' set up to track 'origin/stable/v1.0'.
cc -D VERSION=1.0 -c src/cyclictest/cyclictest.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/cyclictest.o
cc -D VERSION=1.0 -c src/lib/error.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/error.o
cc -D VERSION=1.0 -c src/lib/rt-get_cpu.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/rt-get_cpu.o
cc -D VERSION=1.0 -c src/lib/rt-sched.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/rt-sched.o
cc -D VERSION=1.0 -c src/lib/rt-utils.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/rt-utils.o
ar rcs bld/librttest.a bld/error.o bld/rt-get_cpu.o bld/rt-sched.o bld/rt-utils.o
cc -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL  -o cyclictest bld/cyclictest.o -lrt -lpthread -lrttest -Lbld -lnuma
cc -D VERSION=1.0 -c src/hackbench/hackbench.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/hackbench.o
cc -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL  -o hackbench bld/hackbench.o -lrt -lpthread
cc -D VERSION=1.0 -c src/pi_tests/pip_stress.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/pip_stress.o
cc -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL  -o pip_stress bld/pip_stress.o -lrt -lpthread -lrttest -Lbld
cc -D VERSION=1.0 -c src/pi_tests/pi_stress.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/pi_stress.o
cc -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL  -o pi_stress bld/pi_stress.o -lrt -lpthread -lrttest -Lbld
cc -D VERSION=1.0 -c src/pmqtest/pmqtest.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/pmqtest.o
cc -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL  -o pmqtest bld/pmqtest.o -lrt -lpthread -lrttest -Lbld -ldl
cc -D VERSION=1.0 -c src/ptsematest/ptsematest.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/ptsematest.o
cc -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL  -o ptsematest bld/ptsematest.o -lrt -lpthread -lrttest -Lbld -ldl
cc -D VERSION=1.0 -c src/rt-migrate-test/rt-migrate-test.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/rt-migrate-test.o
cc -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL  -o rt-migrate-test bld/rt-migrate-test.o -lrt -lpthread -lrttest -Lbld
cc -D VERSION=1.0 -c src/backfire/sendme.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/sendme.o
cc -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL  -o sendme bld/sendme.o -lrt -lpthread -lrttest -Lbld -ldl
cc -D VERSION=1.0 -c src/signaltest/signaltest.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/signaltest.o
cc -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL  -o signaltest bld/signaltest.o -lrt -lpthread -lrttest -Lbld
cc -D VERSION=1.0 -c src/sigwaittest/sigwaittest.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/sigwaittest.o
cc -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL  -o sigwaittest bld/sigwaittest.o -lrt -lpthread -lrttest -Lbld -ldl
cc -D VERSION=1.0 -c src/svsematest/svsematest.c -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL -D_GNU_SOURCE -Isrc/include -o bld/svsematest.o
cc -Wall -Wno-nonnull -O2 -DNUMA -DHAVE_PARSE_CPUSTRING_ALL  -o svsematest bld/svsematest.o -lrt -lpthread -lrttest -Lbld -ldl
chmod +x src/hwlatdetect/hwlatdetect.py
ln -s src/hwlatdetect/hwlatdetect.py hwlatdetect
```

The [cyclictest](https://wiki.linuxfoundation.org/realtime/documentation/howto/tools/cyclictest/start) allows for a quick view into the real-time performance of the system. We have to provide a few command-line switches to make sure it behaves like an actual real-time application.

The `--smp` switch enables standard SMP testing which implies the options `-a -t -n` and same priority of all threads. The `-n` option is especially important, as it makes the `cyclictest` use `clock_nanosleep` which is one the more accurate of all "sleeps". The `--quiet` option makes sure, that a summary is printed after running the test. To use the FIFO scheduling policy, the `--policy=fifo` switch must be used. Read more about scheduling policies in the [Linux Foundation](https://wiki.linuxfoundation.org/realtime/documentation/technical_basics/sched_policy_prio/start). Finally, the tasks have to have assigned the highest priority possible for the best real-time performance: `--priority=99`.

Real-time applications have to be executed by `root` or by someone who is part of the `realtime` group. Thus, we have to use, e.g. `sudo` to make this happen. Let's now start our first test for 10 seconds:

```shell
cd rt-tests
sudo timeout 10s ./cyclictest --smp --quiet --policy=fifo --priority=99
echo # flush stdout
```

```shell
# /dev/cpu_dma_latency set to 0us
T: 0 ( 6199) P:99 I:1000 C:   9998 Min:      3 Act:   17 Avg:   11 Max:      43
T: 1 ( 6200) P:99 I:1500 C:   6665 Min:      3 Act:   14 Avg:   11 Max:      38
T: 2 ( 6201) P:99 I:2000 C:   4999 Min:      3 Act:   22 Avg:   11 Max:      33
T: 3 ( 6202) P:99 I:2500 C:   4000 Min:      3 Act:   14 Avg:   13 Max:      59

```

I ran this test on my notebook. Considering the measures being taken by notebook manufacturers to reduce the power consumption of this type of portable devices, these numbers are not bad.

The results can be interpreted as follows:

-   The (sleep) interval is set to 1000 µs by default.
-   The distance of thread intervals is set to 500 µs by default. This means, that the sleep interval for the second thread is 1500 µs, for the third thread 2000 µs, etc.
-   The test ran for 10 seconds. As the sleep interval is 1 ms, there should be 1000 sleeps per second. This is what the `C` values stand for: for the first thread, there were actually 9998 sleeps in the (inaccurate `timeout`) interval of 10s.
-   The minimum jitter was 3 µs, the latest measurements taken 14-22 µs with an average of 11-13 µs and the maximum (the most important figure) of 59 µs.

To get more real-world results, the system should be heavily stressed for testing purposes over longer periods of time when analyzing the real-time application. There are several tools available to do that, one example is [sysbench](https://github.com/akopytov/sysbench).


## Conclusion {#conclusion}

In this article, we quickly set up a real-time Linux system based on Debian GNU/Linux. The performance of the system can be verified quickly as well, using the `rt-tools`.

To learn more about how to implement real-time applications, look into the [Real-Time Linux](https://wiki.linuxfoundation.org/realtime/start) section of the Linux Foundation's Wiki. Especially, the application development How-tos are of great help to get started:

-   [HOWTO build a simple RT application](https://wiki.linuxfoundation.org/realtime/documentation/howto/applications/application_base)
-   [HOWTO build a basic cyclic application](https://wiki.linuxfoundation.org/realtime/documentation/howto/applications/cyclic)

In future articles, I want to analyze the impact of stressing the system on the real-time performance. Real-time Linux is often used on different platforms than my (at the time of writing) `x86_64` notebook. For sure, I will shed some light on running `PREEMPT_RT` kernels on other platforms as well in future posts.
