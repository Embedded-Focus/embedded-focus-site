---
title: "Coding in C++ like it's Golang (Part 3)"
authors: ["Rainer Poisel"]
lastmod: 2023-07-18T22:53:52+02:00
draft: true
toc: true
comments: true
image: "header.jpg"
tags: ["c++", "golang"]
categories: ["Coding"]
---

Golang has some nice features such as multiple return values, the `defer` keyword, and channels. This article shows how to implement some of Golang's features in Modern C++.

<!--more-->


## Introduction and Related Work {#introduction-and-related-work}

Golang has some mechanisms which are helpful for developing software in Cloud Computing environments. These mechanisms address challenges that are ubiquitous in cloud computing environments, such as handling concurrency scenarios or deploying programs in distributed execution contexts. Some of these mechanisms are useful for real-time scenarios as well. When porting them to C++, care must be taken to follow the principles of real-time programming. Despite these extra challenges (e.g. handling memory allocations) it is absolutely possible to achieve our goal. In this article we will show how to return multiple values from functions/methods and how to defer logic to be executed before a function scope is left.

-   [A C++ developer looks at Go (3 part series)](https://www.murrayc.com/permalink/2017/06/26/a-c-developer-looks-at-go-the-programming-language-part-1-simple-features/)
-   [bolu.dev: Go channels in Cpp, part 1](https://bolu.dev/programming/2020/06/28/go-channels-part1.html)


## Channels in Go {#channels-in-go}

Initial situation:

```go { linenos=true, linenostart=1 }
package main

import (
	"fmt"
	"sync"
)

func producer(ch chan<- int, numItems int) {
	for i := 1; i <= numItems; i++ {
		ch <- i
	}
	close(ch)
}

func consumer(id int, ch <-chan int, wg *sync.WaitGroup) {
	defer wg.Done()

	for num := range ch {
		fmt.Printf("Consumer %d received: %d\n", id, num)
	}
}

func main() {
	numConsumers := 10
	numItems := 5_000_000

	ch := make(chan int, 3)
	wg := &sync.WaitGroup{}

	wg.Add(numConsumers)

	for i := 1; i <= numConsumers; i++ {
		go consumer(i, ch, wg)
	}

	go producer(ch, numItems)

	wg.Wait()

	fmt.Println("All consumers have finished")
}
```

Running the `.go` file:

```shell
(time go run channels/cmd/main.go) 2>&1 >/dev/null
```

```shell

real	0m3.043s
user	0m7.216s
sys	0m1.142s
```


### Implementation {#implementation}

```cpp { linenos=true, linenostart=1 }
#include <circular_buffer.hpp>
#include <condition_variable>
#include <mutex>
#include <optional>

template <typename T, std::size_t buf_siz> class Channel {
public:
  friend Channel &operator<<(Channel &channel, const T &value) {
    std::unique_lock lock_send{channel.mutex_send_};
    channel.condition_send_.wait(lock_send,
                                 [&channel] { return !channel.elems_.full(); });

    std::unique_lock lock{channel.mutex_recv_};
    channel.elems_.put(std::move(value));
    channel.condition_recv_.notify_all();
    return channel;
  }

  friend Channel &operator>>(Channel &channel, std::optional<T> &received) {
    {
      std::unique_lock lock_send{channel.mutex_send_};
      channel.condition_send_.notify_one();
    }
    std::unique_lock lock{channel.mutex_recv_};
    channel.condition_recv_.wait(
        lock, [&channel] { return channel.quit_ || !channel.elems_.empty(); });
    if (!channel.elems_.empty()) {
      received = std::move(channel.elems_.get());
      return channel;
    }
    received.reset();
    return channel;
  }

  void Close() {
    std::unique_lock<std::mutex> lock(mutex_recv_);
    quit_ = true;
    condition_recv_.notify_all();
  }

private:
  std::mutex mutex_recv_;
  std::condition_variable condition_recv_;

  std::mutex mutex_send_;
  std::condition_variable condition_send_;

  circular_buffer<T, buf_siz> elems_;
  bool quit_ = false;
};

#include <iostream>

int main() {
  constexpr auto NUM_MSGS = 5000000;
  constexpr auto NUM_RECVS = 32;
  constexpr auto BUF_SIZ = 300;

  Channel<int, BUF_SIZ> channel;

  auto producer = [&channel]() {
    for (int i = 0; i < NUM_MSGS; ++i) {
      channel << i;
    }
    channel.Close();
  };
  auto consumer = [&channel](auto id) {
    for (;;) {
      std::optional<int> received;
      channel >> received;
      if (!received) {
        break;
      }
      std::cout << "Consumer id {" << id << "} Received: " << *received
                << std::endl;
    }
  };

  std::thread producerThread(producer);
  std::array<std::thread, NUM_RECVS> consumerThreads;
  for (auto cnt = 0; cnt < NUM_RECVS; cnt++) {
    consumerThreads[cnt] = std::move(std::thread{consumer, cnt});
  }

  producerThread.join();
  for (auto &&consumer : consumerThreads) {
    consumer.join();
  }

  return EXIT_SUCCESS;
}
```

```shell
g++ -std=c++20 -o channel -I. channel.cpp
(time ./channel) 2>&1 >/dev/null
```

```shell

real	0m9.009s
user	0m16.193s
sys	2m5.047s
```


### Discussion {#discussion}

...


## Conclusion {#conclusion}

In conclusion, the implementation of a hard real-time state machine described in this blog entry demonstrates that it is possible to meet strict timing requirements in a program without dynamic memory allocations. By using standard library machinery and move semantics, the code can be optimized for performance and memory usage. The absence of dynamic memory allocations also eliminates the possibility of memory fragmentation, which can be a concern in long-running programs. Overall, this implementation provides a useful template for designing and implementing hard real-time systems in C++.

Outlook:

-   [Designing the coroutine channel](https://luncliff.github.io/coroutine/articles/designing-the-channel/)
    -   [GitHub](https://github.com/luncliff/coroutine/)
