---
title: "Coding in C++ like it's Golang (Part 2)"
authors: ["Rainer Poisel"]
lastmod: 2023-11-21T20:35:47+01:00
draft: false
toc: true
comments: true
image: "header.jpg"
tags: ["c++", "golang"]
categories: ["Coding"]
---

Golang has some nice features such as multiple return values, the `defer` keyword, and channels. This article shows how to implement Golang's `defer` statement in Modern C++.

<!--more-->


## Introduction and Related Work {#introduction-and-related-work}

Golang has some mechanisms which are helpful for developing software in Cloud Computing environments. These mechanisms address challenges that are ubiquitous in cloud computing environments, such as handling concurrency scenarios or deploying programs in distributed execution contexts. Some of these mechanisms are useful for real-time scenarios as well. When porting them to C++, care must be taken to follow the principles of real-time programming. Despite these extra challenges (e.g. handling memory allocations) it is absolutely possible to achieve our goal. In this article we will show how to defer logic to be executed before a scope (function, block, etc.) is left.

We are not the first to re-implement Golang-features in C++. There are several resources that deal with achieving this goal:

-   [A C++ developer looks at Go (3 part series)](https://www.murrayc.com/permalink/2017/06/26/a-c-developer-looks-at-go-the-programming-language-part-1-simple-features/)
-   [GoForCPPProgrammers](https://zchee.github.io/golang-wiki/GoForCPPProgrammers/)
-   [coost](https://coostdocs.github.io/en/about/co/)

Similar to Python's `try-finally` mechanism, this approach can be highly advantageous for effectively managing resource cleanup or deferring actions in a structured and convenient manner.


## Deferring Logic in Go {#deferring-logic-in-go}

In this article, we will focus on deferring logic specifically in the context of database access scenarios. This emphasis will provide the foundation for our broader discussion on deferring specific actions to later points in time, such as finalizing access or closing the database towards the end of our process. To get started, let's demonstrate how to create and populate an SQLite database using the `sqlite3` command-line tool.

```shell
rm -f /tmp/example.db
sqlite3 /tmp/example.db <<-EOF
    CREATE TABLE employees (id INTEGER PRIMARY KEY, name TEXT, age INTEGER);
    INSERT INTO employees (name, age) VALUES ('John Doe', 30), ('Jane Smith', 25);
    SELECT * FROM employees;
EOF
```

Result:

```shell
1|John Doe|30
2|Jane Smith|25
```


### Golang Reference Implementation {#golang-reference-implementation}

The Golang reference implementation queries the previously created and populated database using the `database/sql` interfaces which are implemented by [mattn/go-sqlite3](https://github.com/mattn/go-sqlite3):

```go { linenos=true, linenostart=1 }
package main

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/mattn/go-sqlite3"
)

func main() {
	db, err := sql.Open("sqlite3", "file:/tmp/example.db?mode=ro")
	if err != nil {
		log.Fatal("Cannot open database:", err)
	}
	defer db.Close()

	rows, err := db.Query("SELECT * FROM employees")
	if err != nil {
		log.Fatal("SQL error:", err)
	}
	defer rows.Close()

	for rows.Next() {
		var id int
		var name string
		var age int

		err := rows.Scan(&id, &name, &age)
		if err != nil {
			log.Fatal("Error scanning row:", err)
		}

		fmt.Printf("ID: %d, Name: %s, Age: %d\n", id, name, age)
	}

	if err = rows.Err(); err != nil {
		log.Fatal("Error retrieving rows:", err)
	}
}
```

First, we open the SQLite database at `/tmp/example.db` in read-only mode. In case, opening the database goes well, closing the database handle is deferred to the end of the `main` function. After that, all fields from all rows are queried from the `employees` table and printed to stdout.

In Golang, the `defer` statement is used to schedule a function call to be executed when the surrounding function returns, either because it reaches the end of the function or encounters a `panic`. If `defer` is used multiple times in the same scope, the scheduled function calls are executed in the reverse order they were deferred.

When you defer a function call, the arguments to that function are actually evaluated at the time the defer statement is executed, not when the deferred function itself is executed ([link to the documentation](https://go.dev/blog/defer-panic-and-recover)). This means that the code at the point of the `defer` statement determines the values of the arguments, and the deferred function uses those values when it is eventually called.

Running the above `.go` file results in:

```shell
go run database/cmd/main.go
```

```shell
ID: 1, Name: John Doe, Age: 30
ID: 2, Name: Jane Smith, Age: 25
```

Now, we will move on to implementing the `defer` statement in C++.


### Implementation in Modern C++ {#implementation-in-modern-c-plus-plus}

As the C++ language does not have a `defer` statement built-in, we have to implement it ourselves through the use of RAII (Resource Acquisition Is Initialization). In C++, RAII is a common idiom used to manage resources such as memory, file handles, and network connections. Objects in C++ are automatically destroyed when they go out of scope, and their destructors are called. This behavior can be leveraged to mimic the `defer` functionality. By creating an object whose destructor contains the code you would like to defer, you ensure that this code is executed when the object goes out of scope.

For instance, you can define a class with a destructor that executes the desired deferred action. When an instance of this class goes out of scope, the destructor is called, and the deferred action is executed:

```cpp { linenos=true, linenostart=1 }
#include <iostream>
#include <functional>

class Defer {
public:
    Defer(std::function<void()> f) : func(f) {}
    ~Defer() { func(); }

private:
    std::function<void()> func;
};

int main() {
    Defer defer_example([]{ std::cout << "Deferred action executed.\n"; });
    std::cout << "Main function body.\n";
    // Deferred action is executed here when defer_example goes out of scope
    return 0;
}
```

```shell
g++ -std=c++20 -o raii_defer raii_defer.cpp
./raii_defer
```

```shell
Main function body.
Deferred action executed.
```

In this example, the lambda function passed to the `Defer` class is executed when the `defer_example` object is destroyed at the end of the `main` function's scope. This technique effectively simulates parts of Go's `defer` behavior in C++. Variables used in deferred callbacks must be captured to ensure accessibility.

For the moment, only one function can be deferred by a single object. What if we want to allow for registering multiple deferred functions? In this case, we will need a data structure capable of holding multiple such callbacks:

```cpp { linenos=true, linenostart=1 }
#include <array>
#include <functional>
#include <initializer_list>
#include <stdexcept>

namespace htl {

using CallbackT = std::function<void()>;

template <std::size_t stack_depth = 4> class Defer {
public:
  Defer() : callbacks{}, num_callbacks{0} {}
  template <typename T, typename... Rest>
  Defer(T arg, Rest... rest)
      : callbacks{arg, rest...}, num_callbacks{sizeof...(Rest) + 1} {}
  ~Defer() {
    if (!num_callbacks) {
      return;
    }
    for (auto idx = num_callbacks; idx > 0; --idx) {
      callbacks[idx - 1]();
    }
  }
  void defer(CallbackT callback) {
    if (num_callbacks >= callbacks.max_size()) {
      throw std::runtime_error("Number of deferred functions exceeded.");
    }
    callbacks[num_callbacks++] = callback;
  }

private:
  std::array<CallbackT, stack_depth> callbacks;
  std::size_t num_callbacks;
};

} // namespace htl
```

To avoid runtime memory allocations (assuming usage in real-time scenarios), the `Defer` class utilizes a statically sized `std::array` to store callbacks. The size of the array, defining the maximum number of callbacks it can accommodate, is set by the `stack_depth` template parameter. Deferred functions are added through the class's variadic constructor or the `defer` method and are executed in the destructor in reverse order they have been registered (LIFO; Last In - First Out).

Let's find out by porting the SQLite Golang example from above to C++. But first, we have to decide on the SQLite library to use in our C++ samples. Numerous modern C++ wrappers for SQLite are available that offer high-quality and user-friendly interfaces. Notable examples include:

-   [sqlite_modern_cpp](https://github.com/SqliteModernCpp/sqlite_modern_cpp),
-   [SQLiteCpp](https://github.com/SRombauts/SQLiteCpp).

However, to better illustrate the principles of our self-development, I would like to keep things simple in our practical example and stay with the [original C-style API of the SQLite project](https://www.sqlite.org/cintro.html):

```cpp { linenos=true, linenostart=1 }
#include "defer.hpp"

#include <cstdlib>
#include <iostream>

#include <sqlite3.h>

int main() {
  sqlite3 *db;
  int rc = sqlite3_open("file:/tmp/example.db?mode=ro", &db);
  if (rc != SQLITE_OK) {
    std::cerr << "Cannot open database: " << sqlite3_errmsg(db) << std::endl;
    return rc;
  }

  htl::Defer deferred{[&db] { sqlite3_close(db); }};

  sqlite3_stmt *stmt;
  rc = sqlite3_prepare_v2(db, "SELECT * FROM employees;", -1, &stmt, 0);
  if (rc != SQLITE_OK) {
    std::cerr << "SQL error: " << sqlite3_errmsg(db) << std::endl;
    return rc;
  }

  deferred.defer([&stmt] { sqlite3_finalize(stmt); });

  while ((rc = sqlite3_step(stmt)) == SQLITE_ROW) {
    int id = sqlite3_column_int(stmt, 0);
    const char *name =
        reinterpret_cast<const char *>(sqlite3_column_text(stmt, 1));
    int age = sqlite3_column_int(stmt, 2);

    std::cout << "ID: " << id << ", Name: " << name << ", Age: " << age
              << std::endl;
  }

  if (rc != SQLITE_DONE) {
    std::cerr << "SQL error: " << sqlite3_errmsg(db) << std::endl;
  }

  return EXIT_SUCCESS;
}
```

Upon opening the database, the `Defer` class instance, `deferred`, is initialized with a lambda that captures the `db` pointer by reference. This lambda ensures the database connection closes when `deferred` exits the `main` scope. Additionally, to manage the prepared statement `stmt`, its cleanup procedure is also registered with `deferred`. Callbacks in `Defer` execute in reverse order, so the statement is freed before the database connection is closed.

Thus, the `Defer` class efficiently handles resource cleanup for both the database and statement, guaranteeing their proper release upon exiting `main`, regardless of the exit path.

Running the example works as expected:

```shell
g++ -std=c++20 -o sqlite3_query sqlite3_query.cpp -lsqlite3
./sqlite3_query
```

```shell
ID: 1, Name: John Doe, Age: 30
ID: 2, Name: Jane Smith, Age: 25
```

Note that we did not take into account, that function arguments to deferred functions in Golang are evaluated when the `defer` statement is encountered.


## Conclusion {#conclusion}

Deferred statements in C++ offer a flexible and explicit approach to resource management, surpassing traditional methods like manual cleanup or more automatic approaches such as RAII with smart pointers. They allow cleanup code to be defined at the point of resource acquisition, enhancing code readability and maintainability, especially in complex functions with multiple resources. This approach is particularly beneficial for managing resources that can't be easily encapsulated or require specific release calls.
