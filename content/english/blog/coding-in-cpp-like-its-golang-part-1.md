---
title: "Coding in C++ like it's Golang (Part 1)"
authors: ["Rainer Poisel"]
lastmod: 2023-07-19T07:22:03+02:00
draft: false
toc: true
comments: true
image: "header.jpg"
tags: ["c++", "golang"]
categories: ["Coding"]
canonical: "https://honeytreelabs.com/posts/coding-in-cpp-like-its-golang-part-1/"
sitemap:
  disable: true
---

Golang has some nice features such as multiple return values, the `defer` keyword, and channels. This article shows how to implement multiple return values of functions in Golang and C++.

<!--more-->


## Series Introduction {#series-introduction}

Golang has some mechanisms which are helpful for developing software in Cloud Computing environments. These mechanisms address challenges that are ubiquitous in cloud computing environments, such as handling concurrency scenarios or deploying programs in distributed execution contexts. Some of these mechanisms are useful for real-time scenarios as well. When porting them to C++, care must be taken to follow the principles of real-time programming. Despite these extra challenges (e.g. handling memory allocations) it is absolutely possible to achieve our goal. In the first part of this article series we will show how to return multiple values from functions/methods.

Several frameworks implementing Go languages features in C++ as well as blog posts discussing the usage of language mechanisms of one programming language in the other have been published. For example:

-   [A C++ developer looks at Go (3 part series)](https://www.murrayc.com/permalink/2017/06/26/a-c-developer-looks-at-go-the-programming-language-part-1-simple-features/)
-   [GoForCPPProgrammers](https://zchee.github.io/golang-wiki/GoForCPPProgrammers/)
-   [coost](https://coostdocs.github.io/en/about/co/)

In this article series we want to implement some of Go's language features in C++ as well in order to get a better understanding of what's "behind" them. In our first part, we will focus on returning multiple values from functions in both languages.


## Introduction and Related Work {#introduction-and-related-work}

In modern programming languages, the ability to return multiple values from a function is a powerful feature that enables concise and expressive code. Languages like Go (Golang), Lua, or Python have embraced this paradigm by allowing functions to effortlessly return multiple values, providing increased flexibility and reducing the need for complex data structures or out parameters.

Software developers typically throw exceptions to signal that the flow of execution is in an erroneous state. Exception handling separates the error-handling code from the normal control flow, improving code readability and maintainability. However, the use of exceptions usually has higher requirements on the executing hardware compared to the processing of return values, making using them on embedded systems unfeasible in some scenarios. In real-time capable code, the use of exceptions might also not be possible due to strict timing conditions.

This is where multiple return values come in handy: one return value displays the success of the operation whereas others convey the actual result of the operation. Before Modern C++, or in C, workaround solutions such as structured return types or reference function parameters (a.k.a. "var in/out") could be used. These solutions came at the expense of readability or comprehensibility of the code. Features of modern C++ such as `std::tuple`, structured bindings, and copy elision (return value optimization; RVO) make this absolutely possible with low overhead.


## Multiple Return Values in Go {#multiple-return-values-in-go}

Let's start with a fictional, but practical example: a function that divides two numbers. It is illegal to divide by zero. In case this happens, the function returns a fixed value and an error which must be evaluated by the calling code.

```go { linenos=true, linenostart=1 }
package main

import (
	"errors"
	"fmt"
)

func divide(dividend, divisor float64) (float64, error) {
	if divisor == 0 {
		return 0, errors.New("divisor must not be zero")
	} else {
		return dividend / divisor, nil
	}
}

func main() {
	var divisions = []struct {
		Dividend float64
		Divisor  float64
	}{{1, 2}, {2, 0}, {3, 4}}

	for _, division := range divisions {
		q, err := divide(division.Dividend, division.Divisor)
		if err != nil {
			fmt.Printf("An error occurred: %v.\n", err)
		} else {
			fmt.Printf("The result is: %v\n", q)
		}
	}
}
```

Running the `.go` file results in the following output:

```shell
go run multiret/cmd/main.go
```

Result:

```shell
The result is: 0.5
An error occurred: divisor must not be zero.
The result is: 0.75
```

As expected, in case the divisor is `0`, an error is returned and printed to the terminal. The return value of the quotient is set to 0. But it has no meaning and must be ignored, in case the return value of the error part is not `nil`. Conversely, the value of the error part must also be ignored in the good case.


## Implementation in Modern C++ {#implementation-in-modern-c-plus-plus}

C++17 supports structured bindings to define the return values with named variables in a single definition. Using the `auto` specifier, the compiler can even infer the return types for each variable. The code showcases a technique to return multiple values from a function by utilizing `std::tuple`:

```cpp { linenos=true, linenostart=1 }
//< -------------------- implementation -------------------- >

#include <tuple>

std::tuple<double, char const *> divide(double dividend,
                                        double divisor) noexcept {
  if (divisor == 0) {
    return {0, "divisor must not be zero"};
  }
  return {dividend / divisor, nullptr};
}

//< -------------------- usage example -------------------- >

#include <initializer_list>
#include <iostream>

int main() {
  struct Division {
    double dividend;
    double divisor;
  };
  std::initializer_list<Division> divisions = {{1, 2}, {2, 0}, {3, 4}};
  for (auto const &division : divisions) {
    auto [result, err] = divide(division.dividend, division.divisor);
    if (err) {
      std::cout << "An error occurred: " << err << "." << std::endl;
    } else {
      std::cout << "The result is: " << result << std::endl;
    }
  }
  return EXIT_SUCCESS;
}
```

Compiling and running the code results in the following output:

```shell
g++ -std=c++20 -o divisions multi_retval.cpp
./divisions
```

Result:

```shell
The result is: 0.5
An error occurred: divisor must not be zero.
The result is: 0.75
```


## Discussion and Conclusion {#discussion-and-conclusion}

This approach for returning multiple values from functions has also been discussed in the [CppCoreGuidelines: If you can't throw exceptions, use error codes systematically](https://github.com/isocpp/CppCoreGuidelines/blob/master/CppCoreGuidelines.md#e27-if-you-cant-throw-exceptions-use-error-codes-systematically).

We can write even more Go-like code by using structured bindings inside an if-statement (see line 25):

```cpp { linenos=true, linenostart=1 }
//< -------------------- implementation -------------------- >

#include <tuple>

std::tuple<double, char const *> divide(double dividend,
                                        double divisor) noexcept {
  if (divisor == 0) {
    return {0, "divisor must not be zero"};
  }
  return {dividend / divisor, nullptr};
}

//< -------------------- usage example -------------------- >

#include <initializer_list>
#include <iostream>

int main() {
  struct Division {
    double dividend;
    double divisor;
  };
  std::initializer_list<Division> divisions = {{1, 2}, {2, 0}, {3, 4}};
  for (auto const &division : divisions) {
    if (auto [result, err] = divide(division.dividend, division.divisor); err) {
      std::cout << "An error occurred: " << err << "." << std::endl;
    } else {
      std::cout << "The result is: " << result << std::endl;
    }
  }
  return EXIT_SUCCESS;
}
```

Another advantage of using structured bindings inside an if-statement is that the scope of the variables is as small as possible. This is especially important when you consider that structured bindings always define new variables.

Structured bindings go even further by e.g. allowing for binding array elements to variables by reference or by value. This technique is not shown here, but it is mentioned for the sake of completeness.

Even though we have to be a bit more specific regarding used data types, by utilizing tuples, the code achieves a pattern similar to Go's multiple return values, enabling the function to convey both a result value and an error condition as part of its return.
