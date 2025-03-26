---
title: "Taming UB in C++ with static/dynamic analysis"
authors: ["Rainer Poisel"]
lastmod: 2022-11-16T11:35:38+01:00
draft: false
image: "header.jpg"
toc: true
comments: true
tags: ["c++"]
categories: ["Coding"]
canonical: "https://honeytreelabs.com/posts/dangling-temporaries-in-range-based-loops/"
sitemap:
  disable: true
---

This article presents static and dynamic code anlaysis tools which help to detect programming errors leading to undefined behavior.

<!--more-->


## Introduction {#introduction}

Recently, [I learned](https://twitter.com/hankadusikova/status/1591530148188532736) that the lifetime of temporaries in range expressions does not apply to the entire loop-body. This article does not only cover this topic, but it also gives some insights into the methodology that I use to analyze problems like this one. The research question is: "Can current open-source static and dynamic code anlaysis tools be used to identify problems with the lifetime of temporaries in range-expressions?"

Please note: in most listings shown below, `stderr` is redirected into `stdout`. This is currently needed by my article publishing infrastructure in order to capture all output of called programs.

Let's start by looking into the reference manuals first. From the [cppreference](https://en.cppreference.com/w/cpp/language/range-for#Temporary_range_expression), the lifetime of temporary range expressions is defined:

Pre C++23:

<div class="alert alert-info">

> Lifetimes of all temporaries within range-expression are not extended.
</div>

Since C++23:

<div class="alert alert-info">

> Lifetimes of all temporaries within range-expression are extended if they would otherwise be destroyed at the end of range-expression.
</div>

The next step is to verify this in practical examples. I will only look into pre C++23 toolchains because these are the ones that do not extend the lifetime of temporaries.


## Practical Example: Broken {#practical-example-broken}

The following snippet shows a short proof-of-concept:

<a id="code-snippet--Dangling temporary"></a>
```cpp { linenos=true, linenostart=1, hl_lines=["12"] }
#include <iostream>
#include <vector>

struct HasVector {
  std::vector<int> &get_vector() { return vec; }
  std::vector<int> vec;
};

HasVector get_temporary() { return HasVector{{0, 1, 2, 3, 4, 5, 6}}; }

int main() {
  for (auto v : get_temporary().get_vector()) {
    std::cout << "Value: " << v << std::endl;
  }
  return 0;
}
```

The range-expression with a temporary can be seen on line 12. The `get_temporary()` function returns the temporary which must be valid for the loop-body in each iteration. Let's compile this sample and run it. [Will it blend™](https://www.youtube.com/willitblend)?

```shell
g++ -g3 -O0 -o broken_O0 broken.cpp
./broken_O0
```

```shell
Value: 1453890557
Value: 5
Value: -2114017428
Value: 1442540707
Value: 4
Value: 5
Value: 6
```

Fortunately, even with no optimization active, the program is obviously broken. But let's imagine, we would get valid results for this small sample. This is totally possible because things might be arranged in memory in a way that the program executes correctly coincidentally.

Let's improve the static code analysis and increase the warnings level and recompile our sample:

```shell
g++ -g3 -O0 -Wall -Wextra -o broken_O0 broken.cpp
```

```shell

```

Still no warnings. Hm. Let's try with a different compiler, Clang/LLVM:

```shell
clang++ -g3 -O0 -Wall -Wextra -o broken_O0 broken.cpp
./broken_O0
```

```shell
Value: 1693209972
Value: 5
Value: 1234248299
Value: 482492603
Value: 4
Value: 5
Value: 6
```

Also, no warnings, no problems. Maybe static code anlaysis tools such as `cppcheck` detect this problem:

```shell
cppcheck --enable=all broken.cpp 2>&1
```

```shell
Checking broken.cpp ...
nofile:0:0: information: Cppcheck cannot find all the include files (use --check-config for details) [missingIncludeSystem]

```

Okay, it doesn't. When using `cppcheck` with the `--check-config` flag, it mentions that it could not find the C++ standard headers, but that it is still possible to fully analyze my source file. What about something different: [`clang-analyzer`](https://clang-analyzer.llvm.org/)?

```shell
scan-build-14 clang++ -g3 -O0 -Wall -Wextra -o broken_O0 broken.cpp
```

```shell
scan-build: Using '/usr/lib/llvm-14/bin/clang' for static analysis
scan-build: Analysis run complete.
scan-build: Removing directory '/tmp/scan-build-2022-11-15-141516-1438047-1' because it contains no reports.
scan-build: No bugs found.
```

No luck with static code analysis. How about dynamic analysis with [`valgrind`](https://valgrind.org/)?

```shell
valgrind ./broken_O0 2>&1
```

```shell
==1463467== Memcheck, a memory error detector
==1463467== Copyright (C) 2002-2022, and GNU GPL'd, by Julian Seward et al.
==1463467== Using Valgrind-3.19.0 and LibVEX; rerun with -h for copyright info
==1463467== Command: ./broken_O0
==1463467==
==1463467== Invalid read of size 4
==1463467==    at 0x1092FE: main (broken.cpp:12)
==1463467==  Address 0x4d98c80 is 0 bytes inside a block of size 28 free'd
==1463467==    at 0x484399B: operator delete(void*, unsigned long) (vg_replace_malloc.c:935)
==1463467==    by 0x109AE8: std::__new_allocator<int>::deallocate(int*, unsigned long) (new_allocator.h:158)
==1463467==    by 0x1099F6: std::allocator_traits<std::allocator<int> >::deallocate(std::allocator<int>&, int*, unsigned long) (alloc_traits.h:496)
==1463467==    by 0x109851: std::_Vector_base<int, std::allocator<int> >::_M_deallocate(int*, unsigned long) (stl_vector.h:387)
==1463467==    by 0x109651: std::_Vector_base<int, std::allocator<int> >::~_Vector_base() (stl_vector.h:366)
==1463467==    by 0x1094FA: std::vector<int, std::allocator<int> >::~vector() (stl_vector.h:733)
==1463467==    by 0x1093F5: HasVector::~HasVector() (broken.cpp:4)
==1463467==    by 0x1092CF: main (broken.cpp:12)
==1463467==  Block was alloc'd at
==1463467==    at 0x4840F2F: operator new(unsigned long) (vg_replace_malloc.c:422)
==1463467==    by 0x109B8D: std::__new_allocator<int>::allocate(unsigned long, void const*) (new_allocator.h:137)
==1463467==    by 0x109A63: std::allocator_traits<std::allocator<int> >::allocate(std::allocator<int>&, unsigned long) (alloc_traits.h:464)
==1463467==    by 0x109917: std::_Vector_base<int, std::allocator<int> >::_M_allocate(unsigned long) (stl_vector.h:378)
==1463467==    by 0x109732: void std::vector<int, std::allocator<int> >::_M_range_initialize<int const*>(int const*, int const*, std::forward_iterator_tag) (stl_vector.h:1687)
==1463467==    by 0x109496: std::vector<int, std::allocator<int> >::vector(std::initializer_list<int>, std::allocator<int> const&) (stl_vector.h:677)
==1463467==    by 0x109268: get_temporary() (broken.cpp:9)
==1463467==    by 0x1092B3: main (broken.cpp:12)
==1463467==
Value: 0
Value: 1
Value: 2
Value: 3
Value: 4
Value: 5
Value: 6
==1463467==
==1463467== HEAP SUMMARY:
==1463467==     in use at exit: 0 bytes in 0 blocks
==1463467==   total heap usage: 3 allocs, 3 frees, 76,828 bytes allocated
==1463467==
==1463467== All heap blocks were freed -- no leaks are possible
==1463467==
==1463467== For lists of detected and suppressed errors, rerun with: -s
==1463467== ERROR SUMMARY: 7 errors from 1 contexts (suppressed: 0 from 0)
```

Funnily, the program gives the correct result. And `valgrind` is able to detect the problem. No exact location is given, but at least, it tells that some sort of illegal memory access occured.

Actually, we should also be able to find out when the temporary gets destructed by adding some tracing to the destructor of the `HasVector` class:

<a id="code-snippet--Dangling temporary"></a>
```cpp
#include <iostream>
#include <vector>

struct HasVector {
  ~HasVector() {
    std::cerr << "HasVector object " << this << " destructed." << std::endl;
  }
  std::vector<int> &get_vector() { return vec; }
  std::vector<int> vec;
};

HasVector get_temporary() { return HasVector{{0, 1, 2, 3, 4, 5, 6}}; }

int main() {
  for (auto v : get_temporary().get_vector()) {
    std::cout << "Value: " << v << std::endl;
  }
  return 0;
}
```

Build and run:

```shell
g++ -g3 -O0 -o broken_w_destructor broken_w_destructor.cpp
./broken_w_destructor 2>&1

```

```shell
HasVector object 0x7ffc566c0320 destructed.
Value: 1634431731
Value: 5
Value: 43747346
Value: -1719330267
Value: 4
Value: 5
Value: 6
```

Right there! The destructor is called as expected: before the first execution of the loop-body of our range-based loop. In the next step we will extend the lifetime of our object by moving its scope.


## Practical Example: Fixed {#practical-example-fixed}

In order to extend the lifetime, the temporary will be created and assigned to a variable outside the range-expresseion - or - actually, even outside the range-loop:

<a id="code-snippet--Increased lifetime"></a>
```cpp { linenos=true, linenostart=1, hl_lines=["12-13"] }
#include <iostream>
#include <vector>

struct HasVector {
  std::vector<int> &get_vector() { return vec; }
  std::vector<int> vec;
};

HasVector get_temporary() { return HasVector{{0, 1, 2, 3, 4, 5, 6}}; }

int main() {
  auto t = get_temporary();
  for (auto v : t.get_vector()) {
    std::cout << "Value: " << v << std::endl;
  }
  return 0;
}
```

Now, iterating over the elements in the vector member of the `HasVector` object is separated into two lines: instantiating the temporary and the actual range-based loop. The lifetime of the `HasVector` object is extended to the body of `main`. Build and run:

```shell
g++ -g3 -O0 -o fixed_O0 fixed.cpp
./fixed_O0
```

```shell
Value: 0
Value: 1
Value: 2
Value: 3
Value: 4
Value: 5
Value: 6
```

Great! Let's try again with the memory checker `valgrind`:

```shell
valgrind ./fixed_O0 2>&1
```

```shell
==1406906== Memcheck, a memory error detector
==1406906== Copyright (C) 2002-2022, and GNU GPL'd, by Julian Seward et al.
==1406906== Using Valgrind-3.19.0 and LibVEX; rerun with -h for copyright info
==1406906== Command: ./fixed_O0
==1406906==
Value: 0
Value: 1
Value: 2
Value: 3
Value: 4
Value: 5
Value: 6
==1406906==
==1406906== HEAP SUMMARY:
==1406906==     in use at exit: 0 bytes in 0 blocks
==1406906==   total heap usage: 3 allocs, 3 frees, 76,828 bytes allocated
==1406906==
==1406906== All heap blocks were freed -- no leaks are possible
==1406906==
==1406906== For lists of detected and suppressed errors, rerun with: -s
==1406906== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```

Boom! There we go. No more errors. Done.


## Conclusion {#conclusion}

The access to the invalid temporary was found by given code analysis tools. Even though the static code analysis could not detect any errors, its use still pays off. The fact that the error was found by the dynamic code analysis supports my thesis:

<div class="alert alert-info">

> Tests (unit, integration and system tests) should be executed both with and without memory checkers.
</div>

As demonstrated above, memory checkers can often detect and sometimes locate memory access errors. On the other hand, they are a different execution context than the production environment. Besides the differences in memory access, they also affect the scheduling behavior. Therefore, it makes sense to run tests additionally without memory checkers.

The shown problem is not relevant for C++23 and newer as the lifetime of temporaries in range-expressions has been extended to also cover the loop-statement.
