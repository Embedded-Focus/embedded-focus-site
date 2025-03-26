---
title: "Implementing Unit-Tests and Mocks for UNIX Shells"
authors: ["Rainer Poisel"]
lastmod: 2022-09-15T23:40:15+02:00
draft: false
toc: true
comments: true
image: "header.jpg"
tags: ["shunit2", "shellspec"]
categories: ["QA", "Testing"]
canonical: "https://honeytreelabs.com/posts/writing-unit-tests-and-mocks-for-unix-shells/"
---

In this post, I will describe how to write unit tests for shell script components wich allow for mocking called commands.

<!--more-->


## Introduction {#introduction}

Let's start by giving a definition of the different types of tests:

****System Test****: Testing the system with all components/modules integrated - so called end-to-end testing. System tests are typically based on real-world use-cases. This allows for verifying that the system [works as expected](https://www.softwaretestinghelp.com/system-testing/).  Testing that the system can handle all possible error conditions is more difficult on this level than with the "lower-level" tests (see below).

****Integration Test****: These tests work with the actual components as much as possible. The tested scenario is therefore close to the real world. Integration tests show what is working (or not) and are typically focused on a subset of the system's components/modules.

****Unit Test****: According to their definition, [unit tests mock every single dependency](https://stackoverflow.com/a/7876055). Unit tests show where a problem might be located or, in other words, help someone to find out whether an interface behaves correctly under all circumstances.

In the following, I want to focus on unit tests. A given file containing some shell funtions shall be tested so that it is ensured that the functions formally conform to their specification.

Now, what does mocking actually mean? Again, [some definitions](https://interrupt.memfault.com/blog/unit-test-mocking) before discussing some real-world examples:

****Stubs****: an "empty" implementation which generally always returns hard-coded values (valid/invalid).

****Fakes****: substitutes dependencies with a simpler implementation of it.

****Mocks****: allow for mimicking behavior of real implementations. The behavior is under full control of the executing unit-test.

The boundaries between the different types of replacement techniques are blurred and each has its justification in the context of unit testing. Using mocks allows the test creator for having full control of the behavior of all dependencies. As a result it is comparably easy on this level to analyze the behavior of the component/module under test in "bad weather conditions".


## Requirements and Related Work {#requirements-and-related-work}

As the shell scripts I want to test are intended to be executed in embedded Linux systems running [busybox/ash](https://github.com/brgl/busybox/blob/master/shell/ash.c), I am in search of a test framework that supports this minimalistic shell variant. (Fun fact: despite being a minimalistic shell, its source code is still 13k SLOC.)

If you are 100% into bash, don't worry. The approaches shown in this blog post are absolutely applicable to this shell as well.


### shellspec {#shellspec}

Project link: [shellspec](https://shellspec.info/) (approx. 1.3k stars on GitHub at the time of writing)

This framework has it all: it supports almost any shell, features determining code coverage, mocking, support for parameterized tests, parallel execution - simply anything one would expect from a test framework. It's definitely worth to have a look. I have rarely seen such a comprehensive test framework.

Shellspec is a so called "Behavior Driven Development (BDD) unit testing framework". From the definition of [Behavior Driven Development of the Agile Alliance](https://www.agilealliance.org/glossary/bdd/):

<div class="alert alert-success">

> ... BDD ... describes behaviors in a single notation which is directly accessible to domain experts, testers and developers, so as to improve communication ...
</div>

This "single notation" typically refers to specifying the behavior (incl. related tests) in [Gherkin Language](https://en.wikipedia.org/wiki/Cucumber_(software)#Gherkin_language). While making (a lot of) sense in large systems/organizations, in my situation, it is too abstract/different from the code I want to test (matter of taste). The following example has been taken from the [shellspec documentation](https://shellspec.info/):

```shell { linenos=true, linenostart=1 }
Describe 'sample'
  Describe 'implemented by shell function'
    Include ./mylib.sh # add() function defined

    It 'performs addition'
      When call add 2 3
      The output should eq 5
    End
  End
End
```

While being close to human language, I am more into code, always looking for, ideally at most just one, function call and some assertions. As far as I can tell, there is no other way than Gherkin Language to specify tests and mocks with shellspec. Therefore, I started to look for alternatives.


### Bats-core {#bats-core}

Project link: [Bats-core](https://github.com/bats-core/bats-core) (approx. 3.2k stars on GitHub at the time of writing)

As the name suggests, the "Bash Automated Testing System" uses features only available in the bash shell. Therefore, it is not possible to run my tests with the shell (interpreter) of my target systems.

This is the most popular shell script testing framework based on the number of stars the project has on GitHub. The "[Why I created ShellSpec](https://shellspec.info/why.html)" page also mentions a few references which explain some shortcomings of this framework.

Again, looking for alternatives ...


### shUnit2 {#shunit2}

Project link: [shUnit2](https://github.com/kward/shunit2) (approx. 1.3k stars on GitHub at the time of writing)

This framework claims to be similar to other [xUnit](https://en.wikipedia.org/wiki/XUnit) testing frameworks. So, if you happen to worked with another one, you should be at least be familiar with the used terminology.

ShUnit2 works with any POSIX shell and it allows for writing tests in shell code. So, it perfectly meets my requirements for a testing framework. Profit! We will use it for the rest of this article.


## A Simple Example {#a-simple-example}

The following snippet shows the function under test which is located in a file called `lib.inc`. It contains a simple logging function which writes a logging message enriched with a timestamp to stdout and optionally appends the message to a file with a path specified in the `LOG_FILE_PATH` environment variable:

```shell { linenos=true, linenostart=1 }
# available as examples/lib.inc

myFunc() {
    local msg log
    msg="${1}"

    log="[$(date)] ${msg}"
    echo "${log}"
    if [ -n "${LOG_FILE_PATH}" ]; then
        echo "${log}" 2>/dev/null >> "${LOG_FILE_PATH}"
    fi
}
```

Let's use this function in an ad-hoc shell session:

```shell
$ . ./shunit2/examples/lib.inc
$ export LOG_FILE_PATH=/tmp/01.log
$ myFunc "simple log message"
[Di 10 Mai 2022 21:14:21 CEST] simple log message
$ cat /tmp/01.log
[Di 10 Mai 2022 21:14:21 CEST] simple log message
```

Most likely one already has spotted the challenging part of this function: the result depends on the current date/time (line 7). In order to get rid of this problem, we will mock the `date` utility by making the executing shell find "our" `date` before searching the `PATH` for it by creating  a shell function of the same name.

Let's get our hands dirty and write some tests:

```shell { linenos=true, linenostart=1 }
#!/bin/sh

# file containing the functions to be tested
. ./shunit2/examples/lib.inc

# mock
date() {
    echo "now"
}

testMyFuncMissingPath() {
    unset LOG_FILE_PATH

    local result rc
    result=$(myFunc "some message")
    rc=$?

    assertEquals 0 "${rc}"
    assertEquals "[now] some message" "${result}"
}

testMyFuncHappy() {
    LOG_FILE_PATH="/tmp/01.log"

    local result rc exists contents
    result=$(myFunc "some message")
    rc=$?

    assertEquals 0 "${rc}"
    assertEquals "[now] some message" "${result}"

    exists=0
    [ -e "/tmp/01.log" ] && exists=1
    assertEquals 1 "${exists}"
    contents=$(cat /tmp/01.log)
    assertEquals "[now] some message" "${contents}"
}

setUp() {
    cp /dev/null /tmp/01.log
}

# sourcing the unit test framework
. shunit2/shunit2
```

Lines 7 to 9 show how mocking the `date` utility works: a function with the same name has priority over the program located in the search path, `PATH`. By always returning (echoing) the same value, the expected values of the function calls are independent of the actual time when they are executed.

Running these tests results in:

```shell
$ ./mock_cmd_simple_test.sh
testMyFuncMissingPath
testMyFuncHappy

Ran 2 tests.

OK
```


## A More Complex Mock {#a-more-complex-mock}

What if we want the `date` utility to behave differently depending on the test performed? One way would be to create one file per test. Especially, when writing complex tests, this would be the way to go.

However, there are alternatives: using the  `eval` function allows to make our mock more dynamic. It is now possible to have more than one test with `date` to behave differently, depending on the test:

```shell { linenos=true, linenostart=1 }
#!/bin/sh

. ./shunit2/examples/lib.inc

ACTION="true"

# mock
date() {
    eval "${ACTION}"
}

#dedicated function implementing the mock logic
dying_date_func() {
    exit 1
}

testMyFuncDateDies() {
    ACTION="dying_date_func"
    LOG_FILE_PATH="/tmp/01.log"

    local result rc exists contents
    result=$(myFunc "some message")
    rc=$?

    assertEquals 0 "${rc}"
    assertEquals "[] some message" "${result}"

    exists=0
    [ -e "/tmp/01.log" ] && exists=1
    assertEquals 1 "${exists}"
    contents=$(cat /tmp/01.log)
    assertEquals "[] some message" "${contents}"
}

testMyFuncDoesSomethingMeaningful() {
    ACTION="echo \"now\""
    LOG_FILE_PATH="/tmp/02.log"

    local result rc exists contents
    result=$(myFunc "some message")
    rc=$?

    assertEquals 0 "${rc}"
    assertEquals "[now] some message" "${result}"

    exists=0
    [ -e "/tmp/02.log" ] && exists=1
    assertEquals 1 "${exists}"
    contents=$(cat /tmp/02.log)
    assertEquals "[now] some message" "${contents}"
}

setUp() {
    cp /dev/null /tmp/01.log
    cp /dev/null /tmp/02.log
}

. ./shunit2/shunit2
```


## Closing Notes and Future Thoughts {#closing-notes-and-future-thoughts}


#### Mocking dependencies of the framework might be difficult {#mocking-dependencies-of-the-framework-might-be-difficult}

Replacing (mocking) the dependencies of the test framework can have direct impact on test executions, i.e. prevent successful test execution at all.

The fewer dependencies a test framework has, the easier it is to get it up and running and to execute at all using the approaches shown in this blog post.

The `shellspec` framework comes around this issue by having its own [approach to mocking](https://github.com/shellspec/shellspec#mocking). ShUnit2 on the other hand does not support mocking out of the box. However, its dependencies are minimal. In addition to that, most utilities are invoked by the framework using the shell builtin command `command`, e.g. `command rm`. This suppresses the normal shell function lookup: only shell builtin commands or programs found in the `PATH` are executed.


#### Working with scripts sourced from an absolute path {#working-with-scripts-sourced-from-an-absolute-path}

One of the challenges with shell scripts might be that other files are sourced by their absolute path (line 1):

```shell { linenos=true, linenostart=1 }
. /lib/functions.sh

call_some_function_from_functions_sh
```

Testing such scripts becomes cumbersome as the file system structure of the developer's machine would need to match the structure of the actual target. I don't want to pollute my dev environment with files which are actually under development.

There are (simple) solutions to this challenge such as creating dedicated root file systems or docker containers. An explanation of these will be part of another blog post.


#### Mocking dependencies which are called by the absolute path {#mocking-dependencies-which-are-called-by-the-absolute-path}

What if a library calls a dependency by its absolute path? Let's discuss an [example](https://git.openwrt.org/?p=openwrt/openwrt.git;a=blob;f=package/system/uci/files/lib/config/uci.sh) of the [OpenWrt project](https://openwrt.org/)::

```shell { linenos=true, linenostart=1 }
# ...
uci_set_state() {
    local PACKAGE="$1"
    local CONFIG="$2"
    local OPTION="$3"
    local VALUE="$4"

    [ "$#" = 4 ] || return 0
    /sbin/uci ${UCI_CONFIG_DIR:+-c $UCI_CONFIG_DIR} -P /var/state set "$PACKAGE.$CONFIG${OPTION:+.$OPTION}=$VALUE"
}
# ...
```

On line 9 the `/sbin/uci` utility is called by its absolute path. If changing the invocation is not an option, there are multiple approaches to come around this situation:

One option would be to work with the original utility. However, typically, this makes it hard to instrument the functionality, e.g. which simulates some rare error conditions. This approach, according to the defintion given above, is actually closer to an integration test than a unit test. Alternatively, one could create an instrumentable shell script that resides in exactly that place with the same interface as the original utility.

Again, the creation of such a mock will be part of another article.


## Summary {#summary}

While the amount of logic that should be included in shell scripts is worthy of discussion (in my view shell script logic should be minimal), writing tests for shell scripts not only makes sense. It is absolutely possible with the frameworks at hand. Many of them are written in a way to also work with lightweight shells intended to be used in embedded systems which lack some of the features of their bigger counterparts.

Linux distributions such as [OpenWrt](https://openwrt.org/) are heavily built around myriads of shell scripts. Writing mocks allows for testing the logic of these parts of the system. By creating root filesystems one can run these tests in environments which are similar to the actual target system at speeds which meet the expectations of executing unit-tests.
