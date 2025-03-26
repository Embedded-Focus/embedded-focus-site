---
title: "Automatic Memory Checking for Your Unit-Tests"
authors: ["Rainer Poisel"]
lastmod: 2022-11-27T23:30:35+01:00
draft: false
toc: true
image: "header.jpg"
tags: ["c++", "memory"]
categories: ["Coding", "testing"]
canonical: "https://honeytreelabs.com/posts/memory-checking-unit-tests/"
sitemap:
  disable: true
---

There cannot be enough safety nets in software development. In this post, we will automatically run unit-tests with a memory checker.

<!--more-->


## Introduction and Motivation {#introduction-and-motivation}

In one of my [latest articles about undefined behavior in C++](/blog/dangling-temporaries-in-range-based-loops/), I suggested running unit-tests both with and without a memory checker. Running them with a memory checker has the advantage to detect any potential memory leaks as early as possible.

It has to be mentioned that running tests in a memory checker not only takes longer, but it also affects the scheduling behavior of your application. As it is often impossible to deterministically tell the exact scheduling behavior of the underlying system, this is a minor issue, or even an advantage because your application needs to be prepared for these situations as well. In the course of this article, I will explain how to selectively run tests with and without a memory checker.

Recently, I integrated the [Lua](https://www.lua.org/) interpreter using [sol2](https://github.com/ThePhD/sol2) into my [homeautomation PLC](https://github.com/rpoisel/homeautomation-plc). You can expect some articles about this project soon 😉. Using this approach, I was able to tell that there are no memory leaks despite adding this new feature.

If you only want to look at the code, I created a git repository on GitHub for your convenience: [honeytreelabs/ctest-valgrind-example](https://github.com/honeytreelabs/ctest-valgrind-example).


## Approach to Automatically Add a Memory Checker {#approach-to-automatically-add-a-memory-checker}

All tools described in this article are available under an open-source license. Debian GNU/Linux provides packages for all of them:

```shell
sudo apt install cmake g++ ninja-build valgrind
```

We will write our (fake) unit-tests using the [Catch2](https://github.com/catchorg/Catch2) framework. To prepare the source directory for our tests, we will create a shallow clone of Catch2:

```shell
mkdir -p /tmp/memorycheck/simple
cd /tmp/memorycheck/simple
if ! [ -d Catch2 ]; then
  git clone --depth 1 https://github.com/catchorg/Catch2.git
fi
```

Our first test will consist of a single assertion. The `printf()` call returns the number of characters printed, which is `14` for `Hello, World!`.

```cpp { linenos=true, linenostart=1 }
#include <catch2/catch_test_macros.hpp>

#include <cstdio>

TEST_CASE("states of inputs unchanged", "[single-file]") {
  REQUIRE(printf("Hello, World!\n") == 14);
}
```

The `CMakeLists.txt` for this test is shown in the following snippet. It adds an executable for the test (line 10) and the actual test on line 14. In addition to the regular test, a test run with [valgrind](https://valgrind.org/) is set up as well (line 15 et seqq.). To make this approach more robust, `valgrind` has to be provided with the absolute path of the test binary. The `$<TARGET_FILE:...>` generator expression does exactly that.

To make the test fail if there were any memory leaks detected, we have to make `valgrind` fail if it detects any memory leaks, first. This can be achieved by providing it with additional command line switches. The `--error-exitcode=1` specifies the exit code of `valgrind` if any errors have been detected. We want to use the memcheck tool, thus providing `--tool=memcheck`. To give details for each definitely lost or possibly lost block, including where in the code it was allocated, the `--leak-check=full` is added. We will only concentrate on definitely lost memory leaks which is typically sufficient to detect self-inflicted memory leaks. This can be achieved using the `--show-leak--kinds=definite` option. This type of errors shall make `valgrind` have an exit code of 1 by providing the `--errors-for-leak-kinds=definite` option.

To make it easy for the test executable to find companion files in the source directory of our application, it is used as the working directory of the test execution by setting it to `${CMAKE_CURRENT_LIST_DIR}`.

```cmake { linenos=true, linenostart=1 }
cmake_policy(SET CMP0048 NEW)
project(simple)
cmake_minimum_required(VERSION 3.20)

include(CTest)
enable_testing()

add_subdirectory(Catch2)

add_executable(simple_test simple_test.cpp)
target_link_libraries(simple_test PRIVATE
  Catch2::Catch2WithMain)

add_test(NAME simple_test COMMAND simple_test)
add_test(NAME simple_memchecked_test
  COMMAND valgrind
    --error-exitcode=1
    --tool=memcheck
    --leak-check=full
    --errors-for-leak-kinds=definite
    --show-leak-kinds=definite $<TARGET_FILE:simple_test>
  WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR})
```

Having the test source code and build script in place, the test can be built and executed.

The `-DCMAKE_BUILD_TYPE` set to `Debug` results in a debug build (optimizations turned off, debug symbols added), allowing `valgrind` to show the origin (source file and line) of memory leaks. We will be able to find the location in the call stack that's printed alongside each leak it finds. Actually, it would also make sense to run the tests with a release build (optimizations turned on, no debug symbols). Despite not being able to accurately locate the source of memory leaks, we would be more on the safe side and test what's actually being shipped.

```shell
cd /tmp/memorycheck/simple
# generate actual ninja build script into a sub-directory called build
cmake -S . -B build -GNinja -DCMAKE_BUILD_TYPE=Debug
# perform build in the build directory, out of source
cmake --build build
# run the tests in the build directory
ctest --test-dir build --verbose 2>&1
echo
```

Result:

```shell
-- Configuring done
-- Generating done
-- Build files have been written to: /tmp/memorycheck/simple/build
ninja: no work to do.
Internal ctest changing into directory: /tmp/memorycheck/simple/build
UpdateCTestConfiguration  from :/tmp/memorycheck/simple/build/DartConfiguration.tcl
Parse Config file:/tmp/memorycheck/simple/build/DartConfiguration.tcl
UpdateCTestConfiguration  from :/tmp/memorycheck/simple/build/DartConfiguration.tcl
Parse Config file:/tmp/memorycheck/simple/build/DartConfiguration.tcl
Test project /tmp/memorycheck/simple/build
Constructing a list of tests
Done constructing a list of tests
Updating test list for fixtures
Added 0 tests to meet fixture requirements
Checking test dependency graph...
Checking test dependency graph end
test 1
    Start 1: simple_test

1: Test command: /tmp/memorycheck/simple/build/simple_test
1: Working Directory: /tmp/memorycheck/simple/build
1: Test timeout computed to be: 1500
1: Randomness seeded to: 1852508778
1: Hello, World!
1: ===============================================================================
1: All tests passed (1 assertion in 1 test case)
1:
1/2 Test #1: simple_test ......................   Passed    0.00 sec
test 2
    Start 2: simple_memchecked_test

2: Test command: /usr/bin/valgrind "--error-exitcode=1" "--tool=memcheck" "--leak-check=full" "--errors-for-leak-kinds=definite" "--show-leak-kinds=definite" "/tmp/memorycheck/simple/build/simple_test"
2: Working Directory: /tmp/memorycheck/simple
2: Test timeout computed to be: 1500
2: ==305683== Memcheck, a memory error detector
2: ==305683== Copyright (C) 2002-2022, and GNU GPL'd, by Julian Seward et al.
2: ==305683== Using Valgrind-3.19.0 and LibVEX; rerun with -h for copyright info
2: ==305683== Command: /tmp/memorycheck/simple/build/simple_test
2: ==305683==
2: Randomness seeded to: 241255086
2: Hello, World!
2: ===============================================================================
2: All tests passed (1 assertion in 1 test case)
2:
2: ==305683==
2: ==305683== HEAP SUMMARY:
2: ==305683==     in use at exit: 0 bytes in 0 blocks
2: ==305683==   total heap usage: 3,356 allocs, 3,356 frees, 544,504 bytes allocated
2: ==305683==
2: ==305683== All heap blocks were freed -- no leaks are possible
2: ==305683==
2: ==305683== For lists of detected and suppressed errors, rerun with: -s
2: ==305683== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
2/2 Test #2: simple_memchecked_test ...........   Passed    1.82 sec

100% tests passed, 0 tests failed out of 2

Total Test time (real) =   1.82 sec

```

As expected, `ctest` executes both tests with the same executable: once with the memory checker and another time without it. Executing unit-tests with a memory checker usually takes much longer. It is possible to run tests in parallel using the `-j <jobs>` or `--parallel <jobs>` options to `ctest` to run the tests in parallel using the given number of jobs.

To run the tests quickly during the developing phase, we can distinguish between tests running with a memory checker and tests running without it using the `-R` or `--tests-regex` and the `-E` or `--exclude-regex` command line switches, respectively.

Only execute the tests without a memory checker first:

```shell
cd /tmp/memorycheck/simple/build
ctest -E '.*_memchecked_.*' --verbose 2>&1
echo
```

Result:

```shell
UpdateCTestConfiguration  from :/tmp/memorycheck/simple/build/DartConfiguration.tcl
Parse Config file:/tmp/memorycheck/simple/build/DartConfiguration.tcl
UpdateCTestConfiguration  from :/tmp/memorycheck/simple/build/DartConfiguration.tcl
Parse Config file:/tmp/memorycheck/simple/build/DartConfiguration.tcl
Test project /tmp/memorycheck/simple/build
Constructing a list of tests
Done constructing a list of tests
Updating test list for fixtures
Added 0 tests to meet fixture requirements
Checking test dependency graph...
Checking test dependency graph end
test 1
    Start 1: simple_test

1: Test command: /tmp/memorycheck/simple/build/simple_test
1: Working Directory: /tmp/memorycheck/simple/build
1: Test timeout computed to be: 1500
1: Randomness seeded to: 4077881419
1: Hello, World!
1: ===============================================================================
1: All tests passed (1 assertion in 1 test case)
1:
1/1 Test #1: simple_test ......................   Passed    0.00 sec

The following tests passed:
	simple_test

100% tests passed, 0 tests failed out of 1

Total Test time (real) =   0.01 sec

```

Now let's explicitly run the tests that must run with a memory checker:

```shell
cd /tmp/memorycheck/simple
ctest --test-dir build -R '.*_memchecked_.*' --verbose 2>&1
echo
```

Result:

```shell
UpdateCTestConfiguration  from :/tmp/memorycheck/simple/build/DartConfiguration.tcl
Parse Config file:/tmp/memorycheck/simple/build/DartConfiguration.tcl
UpdateCTestConfiguration  from :/tmp/memorycheck/simple/build/DartConfiguration.tcl
Parse Config file:/tmp/memorycheck/simple/build/DartConfiguration.tcl
Test project /tmp/memorycheck/simple/build
Constructing a list of tests
Done constructing a list of tests
Updating test list for fixtures
Added 0 tests to meet fixture requirements
Checking test dependency graph...
Checking test dependency graph end
test 2
    Start 2: simple_memchecked_test

2: Test command: /usr/bin/valgrind "--error-exitcode=1" "--tool=memcheck" "--leak-check=full" "--errors-for-leak-kinds=definite" "--show-leak-kinds=definite" "/tmp/memorycheck/simple/build/simple_test"
2: Working Directory: /tmp/memorycheck/simple
2: Test timeout computed to be: 1500
2: ==219837== Memcheck, a memory error detector
2: ==219837== Copyright (C) 2002-2022, and GNU GPL'd, by Julian Seward et al.
2: ==219837== Using Valgrind-3.19.0 and LibVEX; rerun with -h for copyright info
2: ==219837== Command: /tmp/memorycheck/simple/build/simple_test
2: ==219837==
2: Randomness seeded to: 249037994
2: Hello, World!
2: ===============================================================================
2: All tests passed (1 assertion in 1 test case)
2:
2: ==219837==
2: ==219837== HEAP SUMMARY:
2: ==219837==     in use at exit: 0 bytes in 0 blocks
2: ==219837==   total heap usage: 3,356 allocs, 3,356 frees, 544,504 bytes allocated
2: ==219837==
2: ==219837== All heap blocks were freed -- no leaks are possible
2: ==219837==
2: ==219837== For lists of detected and suppressed errors, rerun with: -s
2: ==219837== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
1/1 Test #2: simple_memchecked_test ...........   Passed    1.98 sec

The following tests passed:
	simple_memchecked_test

100% tests passed, 0 tests failed out of 1

Total Test time (real) =   1.98 sec

```

In the next step, we will optimize our build infrastructure a bit and see what happens if there is a memory leak in our code.


### Detection of a Memory Leak in a Test {#detection-of-a-memory-leak-in-a-test}

To show that tests will fail due to memory leaks, we will add one to the code deliberately. But before that, we can make creating memory checked tests more general using a CMake `function`:

```cmake
cmake_policy(SET CMP0048 NEW)
project(leak)
cmake_minimum_required(VERSION 3.20)

enable_testing()

add_subdirectory(Catch2)
include(CTest)
include(Catch)

function(add_test_incl_memcheck name)
  add_executable(${name}_test ${name}_test.cpp)
  target_link_libraries(${name}_test PRIVATE
    Catch2::Catch2WithMain)

  add_test(NAME ${name}_test COMMAND ${name}_test)
  add_test(NAME ${name}_memchecked_test
    COMMAND valgrind
      --error-exitcode=1
      --tool=memcheck
      --leak-check=full
      --errors-for-leak-kinds=definite
      --show-leak-kinds=definite $<TARGET_FILE:${name}_test>
    WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR})
endfunction()

add_test_incl_memcheck(leak)
```

The `add_test_incl_memcheck` function automatically adds the original test including the same test run with `valgrind`. This is especially useful if more than just one test should be run with `valgrind`.

In our `function_under_test` we will allocate 20 bytes on the heap without freeing them. Let's now see if our memory checked test fails:

```cpp { linenos=true, linenostart=1 }
#include <catch2/catch_test_macros.hpp>

#include <cstdio>

int function_under_test() {
  new char[20]; // deliberate memory leak
  return printf("Hello, World!\n");
}

TEST_CASE("states of inputs unchanged", "[single-file]") {
  REQUIRE(function_under_test() == 14);
}
```

Build and run the tests:

```shell
cd /tmp/memorycheck/leak
if ! [ -d Catch2 ]; then
  git clone --depth 1 https://github.com/catchorg/Catch2.git
fi
cmake -S . -B build -GNinja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
ctest --test-dir build --verbose 2>&1
echo
```

Result:

```shell
-- Configuring done
-- Generating done
-- Build files have been written to: /tmp/memorycheck/leak/build
[1/2] Building CXX object CMakeFiles/leak_test.dir/leak_test.cpp.o
[2/2] Linking CXX executable leak_test
Internal ctest changing into directory: /tmp/memorycheck/leak/build
UpdateCTestConfiguration  from :/tmp/memorycheck/leak/build/DartConfiguration.tcl
Parse Config file:/tmp/memorycheck/leak/build/DartConfiguration.tcl
UpdateCTestConfiguration  from :/tmp/memorycheck/leak/build/DartConfiguration.tcl
Parse Config file:/tmp/memorycheck/leak/build/DartConfiguration.tcl
Test project /tmp/memorycheck/leak/build
Constructing a list of tests
Done constructing a list of tests
Updating test list for fixtures
Added 0 tests to meet fixture requirements
Checking test dependency graph...
Checking test dependency graph end
test 1
    Start 1: leak_test

1: Test command: /tmp/memorycheck/leak/build/leak_test
1: Working Directory: /tmp/memorycheck/leak/build
1: Test timeout computed to be: 1500
1: Randomness seeded to: 3250556275
1: Hello, World!
1: ===============================================================================
1: All tests passed (1 assertion in 1 test case)
1:
1/2 Test #1: leak_test ........................   Passed    0.00 sec
test 2
    Start 2: leak_memchecked_test

2: Test command: /usr/bin/valgrind "--error-exitcode=1" "--tool=memcheck" "--leak-check=full" "--errors-for-leak-kinds=definite" "--show-leak-kinds=definite" "/tmp/memorycheck/leak/build/leak_test"
2: Working Directory: /tmp/memorycheck/leak
2: Test timeout computed to be: 1500
2: ==320286== Memcheck, a memory error detector
2: ==320286== Copyright (C) 2002-2022, and GNU GPL'd, by Julian Seward et al.
2: ==320286== Using Valgrind-3.19.0 and LibVEX; rerun with -h for copyright info
2: ==320286== Command: /tmp/memorycheck/leak/build/leak_test
2: ==320286==
2: Randomness seeded to: 912796586
2: Hello, World!
2: ===============================================================================
2: All tests passed (1 assertion in 1 test case)
2:
2: ==320286==
2: ==320286== HEAP SUMMARY:
2: ==320286==     in use at exit: 20 bytes in 1 blocks
2: ==320286==   total heap usage: 3,357 allocs, 3,356 frees, 544,520 bytes allocated
2: ==320286==
2: ==320286== 20 bytes in 1 blocks are definitely lost in loss record 1 of 1
2: ==320286==    at 0x484220F: operator new[](unsigned long) (vg_replace_malloc.c:640)
2: ==320286==    by 0x11AFD6: function_under_test() (leak_test.cpp:6)
2: ==320286==    by 0x11B07C: CATCH2_INTERNAL_TEST_0() (leak_test.cpp:11)
2: ==320286==    by 0x16FF65: Catch::TestInvokerAsFunction::invoke() const (catch_test_case_registry_impl.cpp:149)
2: ==320286==    by 0x16662E: Catch::TestCaseHandle::invoke() const (catch_test_case_info.hpp:114)
2: ==320286==    by 0x16592C: Catch::RunContext::invokeActiveTestCase() (catch_run_context.cpp:508)
2: ==320286==    by 0x1656AE: Catch::RunContext::runCurrentTest(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&) (catch_run_context.cpp:473)
2: ==320286==    by 0x1641BE: Catch::RunContext::runTest(Catch::TestCaseHandle const&) (catch_run_context.cpp:238)
2: ==320286==    by 0x11C29F: Catch::(anonymous namespace)::TestGroup::execute() (catch_session.cpp:110)
2: ==320286==    by 0x11D603: Catch::Session::runInternal() (catch_session.cpp:332)
2: ==320286==    by 0x11D18F: Catch::Session::run() (catch_session.cpp:263)
2: ==320286==    by 0x11B7C0: int Catch::Session::run<char>(int, char const* const*) (catch_session.hpp:41)
2: ==320286==
2: ==320286== LEAK SUMMARY:
2: ==320286==    definitely lost: 20 bytes in 1 blocks
2: ==320286==    indirectly lost: 0 bytes in 0 blocks
2: ==320286==      possibly lost: 0 bytes in 0 blocks
2: ==320286==    still reachable: 0 bytes in 0 blocks
2: ==320286==         suppressed: 0 bytes in 0 blocks
2: ==320286==
2: ==320286== For lists of detected and suppressed errors, rerun with: -s
2: ==320286== ERROR SUMMARY: 1 errors from 1 contexts (suppressed: 0 from 0)
2/2 Test #2: leak_memchecked_test .............***Failed    1.88 sec

50% tests passed, 1 tests failed out of 2

Total Test time (real) =   1.89 sec

The following tests FAILED:
	  2 - leak_memchecked_test (Failed)
Errors while running CTest
Output from these tests are in: /tmp/memorycheck/leak/build/Testing/Temporary/LastTest.log
Use "--rerun-failed --output-on-failure" to re-run the failed cases verbosely.

```

Voila, the test fails. It even correctly locates where the "unfreed" block has been allocated. By looking at the results of the tests executed without a memory checker alone, we would not have detected this issue.


## Conclusion {#conclusion}

In this article, we extended an existing CMake-based build system to additionally run unit-tests in a memory checker. This way, potential memory leaks can be identified at early development stages.

The code of this tutorial is available in a public git repository at GitHub: [honeytreelabs/ctest-valgrind-example](https://github.com/honeytreelabs/ctest-valgrind-example).

In my view, it should be really easy for developers to add their tests to the (existing) build script infrastructure. That is why we encapsulated creating tests and running them with the memory checker in a dedicated function that can be easily called from the rest of the code base.

As running applications in the context of a memory checker is much slower than running them without it, I suggest making it possible for developers to run unit-tests both with and without the memory checker.
