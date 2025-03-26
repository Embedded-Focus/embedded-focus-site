---
title: "Implementing a Real-Time State Machine in Modern C++"
authors: ["Rainer Poisel"]
lastmod: 2023-05-15T08:48:50+02:00
draft: false
toc: true
comments: true
image: "header.jpg"
tags: ["pytest", "labgrid"]
categories: ["QA", "Testing"]
canonical: "https://honeytreelabs.com/posts/real-time-state-machine-in-cpp/"
sitemap:
  disable: true
---

In this article we will implement a real-time state machine allowing for the implementation of complex scenarios with predictable timing behavior.

<!--more-->


## Introduction {#introduction}

Finite State Machines (FSMs) are a common design pattern in software engineering, particularly in the development of industrial control software. FSMs offer a powerful and flexible approach to modeling complex behavior in systems with discrete states. The concept of finite state machines was introduced in the 1940s, and since then, they have been widely used in various fields such as computer science, control engineering, and game development. The use of FSMs has been elaborated in detail in seminal works such as the Gang of Four's [Design Patterns: Elements of Reusable Object-Oriented Software](https://en.wikipedia.org/wiki/Design_Patterns) and David Harel's [Statecharts: A Visual Formalism for Complex Systems](https://www.sciencedirect.com/science/article/pii/0167642387900359). In this blog post, we will explore the implementation of an FSM in C++, leveraging modern language features to provide a flexible, real-time capable, and efficient solution for modeling stateful behavior in software systems.

Several related state machine frameworks such as the following exist:

-   [TinyFSM](https://github.com/digint/tinyfsm): an event based FSM based on C++11 template metaprogramming features suitable for embedded real-time systems.
-   [HFSM2](https://github.com/andrew-gresyk/HFSM2): a hierarchical FSM framework in C++11, with fully statically-defined structure (no dynamic allocations), built with variadic templates.
-   [QP/C++](https://www.state-machine.com/qpcpp/): a C++ implementation of the Quantum Platform (QP) state machine framework offering a lot of advanced features.
-   [SML (Boost.SML)](https://boost-ext.github.io/sml/): uses a high-level DSL for defining state machines with support for advanced features.
-   [The Boost Statechart Library](https://www.boost.org/doc/libs/master/libs/statechart/doc/index.html): part of the Boost library collection. The library is well-documented and actively maintained.

While all of these implementations are operationally proven and well documented in addition to being widely used, I would like to implement something new that, in addition to being easy to use, has low memory footprint and is suitable for real-time systems.


## Implementation {#implementation}

The actual state machine implementation is relatively short (when compared to the related projects). It is heavily based on two C++17 features, [std::optional](https://en.cppreference.com/w/cpp/utility/optional) and [std::variant](https://en.cppreference.com/w/cpp/utility/variant), and [move semantics](https://stackoverflow.com/questions/3106110/what-is-move-semantics) which have been introduced with C++11. One of the design principles is that each state defines the transitions and the conditions related to them to other states (this is in contrast to event-based finite state machines).

If you are curious and want to try it yourself, the source code is publicly available:

-   [GitHub](https://gist.github.com/rpoisel/bada82555a1b08c98f41f6e72616e50a)
-   [Compiler Explorer](https://godbolt.org/z/r66YY5dsa)

The state machine in this code uses a `std::variant` to hold all possible states as a union. This is because at any given time, only one state can be active in the state machine. The `StateVariant` type alias represents this variant type. When the state machine transitions from one state to another, the transition function is called with the current state and the state machine's context. This function must return an `std::optional` of `StateVariant` that represents the next state of the state machine. If no transition should be performed, the transition function must return `std::nullopt`.

```cpp { linenos=true, linenostart=1 }
#include <optional>
#include <variant>

template <class Context, class... States> class FSM {
public:
  virtual ~FSM() = default;

  using StateVariant = std::variant<States...>;
  using OptionalStateVariant = std::optional<StateVariant>;

  FSM(StateVariant &&initialState, Context &&context)
    : curState{std::move(initialState)}, context_{std::move(context)} {}
  void update() {
    std::visit([&context = context_](auto &state) { state.update(context); },
               curState);
    auto newState = std::visit(
                               [&context = context_](auto &state) -> OptionalStateVariant {
                                 return transition(state, context);
                               },
                               curState);
    if (newState) {
      curState = std::move(newState.value());
    }
  }

  Context &context() { return context_; }

private:
  StateVariant curState;
  Context context_;
};
```

The code defines a C++ class template FSM that implements a finite state machine.

The class template takes two template parameters: `Context`, which represents the context of the state machine, and `States`, which represents the states of the state machine. The class template contains a nested type alias `StateVariant` that represents a `std::variant` of all possible states, and an `OptionalStateVariant` that represents an optional `StateVariant`. The constructor of the `FSM` class takes two parameters: an initial `StateVariant` and a `Context`, which are both moved into the corresponding member variables.

The update method of the `FSM` class updates the current state of the state machine. First, it visits the current state using `std::visit`, and calls the `update` method of the current state passing in the `context_` member variable. Then, it calls the `transition` method passing in the current state and the `context_` member variable, and stores the resulting `OptionalStateVariant` in a local variable `newState`. If `newState` is not empty, it moves its value into `curState`, effectively changing the current state of the state machine.

The `context` method returns a reference to the `context_` member variable of the `FSM` class. So that it is accessible by all code that has access to FSM instances.


## Example Time {#example-time}

In the next step, we implement a state machine consisting of three states as an example: A, B, and C. The state machine starts with state B.

The signal handler of the SIGINT signal increments the designated counter for the signal in the context of the state machine. As soon as this reaches the value 1 or greater, the state machine changes from states A and B to state C. A value of 2 or higher additionally leads to the end of the program.

State A is initialized with a number of calls. If the number of given state calls is reached, the program switches to state B. State B changes, provided a SIGINT has not yet occurred, at the first call again to state A, where the number of calls of state A is initialized with a random number.

![Sample State Machine](./sample-state-machine.svg)

The following code demonstrates the implementation of the three states (StateA, StateB, and StateC) in the C++ FSM shown above. The FSM transitions between these states based on specific conditions defined in the transition functions.

The FSM's context is represented by the `ABCContext` struct, which contains a counter for the number of SIGINT signals received by the program. Each state in the FSM is represented by a struct (`StateA`, `StateB`, and `StateC`), each of which has an `update` function called by the FSM to update the state.

The `transition` functions, which are called by the FSM to determine the next state, take a reference to the current state and the FSM's context and return an `OptionalStateVariant`. This variant either contains the next state or is empty (`std::nullopt`) if no transition is needed.

In the `main` function, an instance of the FSM template is created and initialized with `StateB` as the starting state and an `ABCContext` object. Additionally, a SIGINT signal handler is set up to count the number of signals received by the program. The `while` loop updates the FSM by calling the `update` function, sleeps for 500ms before repeating, and continues until the program receives two SIGINT signals or exits.

<a id="code-snippet--Sample application based on the real-time FSM presented above"></a>
```cpp { linenos=true, linenostart=1 }
#include "fsm.hpp"

#include <csignal>
#include <cstdlib>
#include <ctime>

#include <chrono>
#include <iostream>
#include <thread>

static inline std::size_t rand_number(std::size_t min, std::size_t max) {
  return min + std::rand() / ((RAND_MAX + 1u) / max);
}

struct StateA;
struct StateB;
struct StateC;
struct ABCContext {
  std::uint8_t cnt_sigint = 0;
};

using StateVariant = std::variant<StateA, StateB, StateC>;
using OptionalStateVariant = std::optional<StateVariant>;

struct StateA {
  StateA(std::size_t c) : cycles{c}, cycle{0} {}
  void update(ABCContext &context) {
    std::cout << "StateA: " << ++cycle << " of " << cycles << std::endl;
  }

  std::size_t cycles;
  std::size_t cycle;
};

struct StateB {
  void update(ABCContext &context) { std::cout << "StateB" << std::endl; }
};

struct StateC {
  void update(ABCContext &context) {
    std::cout << "StateC (final state)" << std::endl;
  }
};

OptionalStateVariant transition(StateA &stateA, ABCContext &context) {
  if (context.cnt_sigint > 0) {
    return StateC{};
  } else if (stateA.cycle == stateA.cycles) {
    return StateB();
  }
  return std::nullopt;
}

OptionalStateVariant transition(StateB &stateB, ABCContext &context) {
  if (context.cnt_sigint > 0) {
    return StateC{};
  }
  return StateA(rand_number(1, 6));
}

OptionalStateVariant transition(StateC &stateC, ABCContext &context) {
  return std::nullopt;
}

static FSM<ABCContext, StateA, StateB, StateC> fsm{StateB{},
                                                   std::move(ABCContext{})};

auto main() noexcept -> int {
  using namespace std::chrono_literals;

  std::srand(std::time(nullptr));

  std::signal(SIGINT, [](int signal) -> void { ++fsm.context().cnt_sigint; });

  while (fsm.context().cnt_sigint < 2) {
    fsm.update();
    std::this_thread::sleep_for(500ms);
  }

  return EXIT_SUCCESS;
}
```

In C++, when representing states as classes or structs, the transition functions need to have access to the private members of the state objects to operate on them. For classes this can be achieved by making the transition functions friend functions of the state classes or structs.

One of the downsides of this approach is that state objects cannot have const members, as they need to be usable as r-value references with `std::move()`. If a state object had a const member, `std::move()` would be unable to move it, as const objects cannot be modified. This limitation can be overcome by using mutable members, or by avoiding const members altogether.


## Discussion {#discussion}

The `StateVariant` type is a `std::variant` that can hold any of the states in the FSM, and the `OptionalStateVariant` type is a `std::optional` that can hold either an instance of `StateVariant` or be empty. The memory required to store a `std::variant` is at least the size of its largest alternative, while the memory required to store a `std::optional` is the size of the stored type plus a bit of overhead to represent whether the `std::optional` is empty or not.

In the FSM implementation used in the provided code example, the memory needed by the FSM is twice the size of the largest alternative type of the state variant. This is because when transitioning to another state, two states exist in memory at the same time: the current state and the next state. The reason for this is that when a state is transitioned to a new state, the new state is constructed and stored as a temporary object before it is moved into the current state.

In addition to these member variables and the FSM context, there may be some additional memory overhead associated with the class definition itself, such as vtable pointers for virtual functions or padding to meet alignment requirements. Therefore, the total memory required by this FSM depends on the size of the StateVariant, the size of the OptionalStateVariant, and the size of the context object, as well as any additional memory overhead required by the class definition.

However, by combining `std::optional` and `std::variant` we can overcome the need for dynamic memory allocation completely while still having a simplistic approach to implementing a FSM in C++. Care should be taken when using complex data types as state class members, as they can dynamically request or release memory when used. An example of this is `std::string`. This class dynamically requests memory to store the represented string in case no allocator suitable for usage in real-time systems is passed to the constructor. It also frees the requested memory in the destructor. One way around this behavior is to store memory requesting objects in the context of the FSM. However, it must be noted that the state of these objects is retained beyond state changes and must be reset manually in the states if necessary.


## Conclusion {#conclusion}

In conclusion, the implementation of a hard real-time state machine described in this blog entry demonstrates that it is possible to meet strict timing requirements in a program without dynamic memory allocations. By using standard library machinery and move semantics, the code can be optimized for performance and memory usage. The absence of dynamic memory allocations also eliminates the possibility of memory fragmentation, which can be a concern in long-running programs. Overall, this implementation provides a useful template for designing and implementing hard real-time systems in C++.
