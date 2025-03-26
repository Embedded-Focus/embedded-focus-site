---
title: "Integrating the Unity test-framework with CMake"
authors: ["Rainer Poisel"]
lastmod: 2022-11-18T11:35:38+01:00
draft: false
toc: true
comments: true
image: "header.jpg"
tags: ["cmake", "buildsystems"]
categories: ["QA", "Testing"]
canonical: "https://honeytreelabs.com/posts/cmake-unity-integration/"
sitemap:
  disable: true
---

<!-- Header source: https://www.pexels.com/photo/persons-left-hand-with-blue-manicure-4659806/ -->

In this tutorial I will demonstrate practical CMake Unity integration in order to make it easy to run unit-tests in CI/CD environments.

<!--more-->

## Prerequisites

The sample project described in this article is hosted on my [github page]. Projects used in this tutorial can be found under the following URLs:

* [CMake]
* [Unit Testing for C (especially embedded software)]

## Preparing the project tree

In this article I am assuming that you are using Git as your source code version control system. The Unity source code is hosted on github, thus making it perfectly suitable for being used as a Git Submodule. This is what I have done in the sample project as well.

In order to check out the sample project including its submodules the `--recursive` option has to be passed to the `git clone` command:

```bash
git clone --recursive https://github.com/rpoisel/cmake-unity-tutorial.git
```

More information on git submodules can be found [here]. Learning how git submodules work can be cumbersome in the beginning but it pays on the long run. Git submodules make it possible to manage what version of a specific other source tree is being used or referenced in a given source tree.

The structure of the sample project is as follows:

```shell
    .
    |- external
    |  \- (Unity sources)
    |- main
    |  \- (entry point of the main application)
    |- module_a
    |  \- (module_a sources)
    \- test
       \- (Unit-Tests sources)
```

The module_a module contains a library of shared code. In this project it is both referenced by the main application as well as the unit-tests. The `external` directory contains the sources from external projects or other git submodules (in this case the Unity testing framework). The main directory contains the production code and the test directory contains the source of the unit-tests.

## CMake Unity targets

First, let’s have a look at the main `CMakeLists.txt` file:

```CMake
project("Sample Project" C)
cmake_minimum_required(VERSION 3.0)

set(TARGET_GROUP production CACHE STRING "Group to build")

add_subdirectory(module_a)

if(TARGET_GROUP STREQUAL production)
  add_subdirectory(main)
elseif(TARGET_GROUP STREQUAL test)
  include(CTest)

  add_subdirectory(external)
  add_subdirectory(test)
else()
  message(FATAL_ERROR "Given TARGET_GROUP unknown")
endif()
```

The `TARGET_GROUP` variable determines whether to build the production code or the test code. It is important to put the `include(CTest)` instruction in the outermost `CMakeLists.txt` file. Otherwise `ctest` will complain that there aren’t any tests.

The Unity framework has no default CMake configuration. Therefore it is provided at the closest place in our project tree (the external directory):

```CMake
add_library(Unity STATIC
  Unity/src/unity.c
)

target_include_directories(Unity PUBLIC
  Unity/src
)
```

If desired it is also possible to make the Unity framework a dynamic library. However, unit-tests can now make use of the Unity framework by issuing `target_link_libraries(Unity)` (see below).

> The `target_link_libraries` command does more than just specifying which libraries to link to the target executable. It also pulls in all `INTERFACE` and `PUBLIC` properties of the referenced library such as include directories defined by `target_include_directories`, compile definitions defined by `target_compile_definitions`, etc. Thus, using the `target_link_libraries` command also affects compile time of your build!

See the [CMake documentation] for more information on that.

## Code to be tested

The sample code has been taken from the [Unity documentation] page. The library interface exposes the only function AverageThreeBytes():

```C
#ifndef MODULE_A_H
#define MODULE_A_H

#include <stdint.h>

int8_t AverageThreeBytes(int8_t a, int8_t b, int8_t c);
   
#endif /* MODULE_A_H */
```

Due to the `PUBLIC` keyword of the call to `target_include_directories`, the directory containing the module’s header file is exposed to all other binary targets linking to `module_a`‘s library.

```CMake
add_library(module_a STATIC
  module_a.c
)

target_include_directories(module_a PUBLIC
  ${CMAKE_CURRENT_LIST_DIR}
)
```

## A sample unit-test

The unit-test executable `suite_1_app` is added to the test `suite_1_test` which is intended to be executed by `ctest`. Please note that line 10 shows the simplified call of the `add_test` command. See the [CMake documentation of add_test] on more information of its invocation!

```CMake
add_executable(suite_1_app
  suite_1.c
)

target_link_libraries(suite_1_app
  module_a
  Unity
)

add_test(suite_1_test suite_1_app)
```

The test suite consists of two tests both of which should pass. The state of executed tests is managed internally by the Unity framework (library). The `unity.h` and `module_a.h` header files can be found by the compiler due to the `target_link_libraries` call pulling in all usage requirements of dependent libraries.

```C
#include <unity.h>
 
#include <module_a.h>
 
void test_AverageThreeBytes_should_AverageMidRangeValues(void)
{
  TEST_ASSERT_EQUAL_HEX8(40, AverageThreeBytes(30, 40, 50));
  TEST_ASSERT_EQUAL_HEX8(40, AverageThreeBytes(10, 70, 40));
  TEST_ASSERT_EQUAL_HEX8(33, AverageThreeBytes(33, 33, 33));
}
 
void test_AverageThreeBytes_should_AverageHighValues(void)
{
  TEST_ASSERT_EQUAL_HEX8(80, AverageThreeBytes(70, 80, 90));
  TEST_ASSERT_EQUAL_HEX8(127, AverageThreeBytes(127, 127, 127));
  TEST_ASSERT_EQUAL_HEX8(84, AverageThreeBytes(0, 126, 126));
}
 
int main(void)
{
  UNITY_BEGIN();
 
  RUN_TEST(test_AverageThreeBytes_should_AverageMidRangeValues);
  RUN_TEST(test_AverageThreeBytes_should_AverageHighValues);
 
  return UNITY_END();
}
```

CTest only checks the exit code of unit-test executables. In case it is other than 0 (zero), a test suite has failed.

The `UNITY_END()` macro aggregates the results of all `TEST_ASSERT_*` macros. the return value is the sum of all failed tests.

## Building and executing unit-tests

On the command-line the sample project’s unit-tests can be built using the [Ninja build system] by issuing the following commands:

```bash
cmake -GNinja -DTARGET_GROUP=test {path-to-source-tree}
ninja -v
```

The tests in turn can be executed by invoking `ctest`. The `--verbose` switch makes ctest more talkative and shows which of your unit-tests have passed (or failed).

```bash
user@machine:/tmp/build$ ctest --verbose
UpdateCTestConfiguration  from :/tmp/build/DartConfiguration.tcl
Parse Config file:/tmp/build/DartConfiguration.tcl
UpdateCTestConfiguration  from :/tmp/build/DartConfiguration.tcl
Parse Config file:/tmp/build/DartConfiguration.tcl
Test project /tmp/build
Constructing a list of tests
Done constructing a list of tests
Checking test dependency graph...
Checking test dependency graph end
test 1
    Start 1: suite_1_test
     
    1: Test command: /tmp/build/test/suite_1/suite_1_app
    1: Test timeout computed to be: 1500
    1: /tmp/cmake_unity/test/suite_1/suite_1.c:23:test_AverageThreeBytes_should_AverageMidRangeValues:PASS
    1: /tmp/cmake_unity/test/suite_1/suite_1.c:24:test_AverageThreeBytes_should_AverageHighValues:PASS
    1: 
1: -----------------------
1: 2 Tests 0 Failures 0 Ignored 
1: OK
1/1 Test #1: suite_1_test .....................   Passed    0.00 sec
 
100% tests passed, 0 tests failed out of 1
 
Total Test time (real) =   0.00 sec
```

Alternatively, CTest can be invoked by the test target which is available to the used build system, e. g. `ninja -v test`. The return code of the ctest call gives information whether the execution of configured unit-tests has been successful. It is 0 (zero) on success.

```bash
user@machine:/tmp/build$ echo $?
0
```

When changing any sources of your project, make sure to invoke your build system before executing CTest again!

## Conclusion

This brief tutorial tries to explain the main steps of integrating the Unity test framework into a software project managed by [CMake]. The Unity source is provided as a git submodule and the framework is used as a static or dynamic library.

[CMake]: https://cmake.org
[Unit Testing for C (especially embedded software)]: https://www.throwtheswitch.org/unity/
[Ninja build system]: https://ninja-build.org
[github page]: https://github.com/rpoisel/cmake-unity-tutorial
[here]: https://git-scm.com/book/en/v2/Git-Tools-Submodules
[CMake documentation]: https://cmake.org/cmake/help/v3.0/manual/cmake-buildsystem.7.html#target-usage-requirements
[Unity documentation]: https://www.throwtheswitch.org/unity
[CMake documentation of add_test]: https://cmake.org/cmake/help/v3.0/command/add_test.html
[valgrind]: https://valgrind.org
