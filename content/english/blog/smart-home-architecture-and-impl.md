---
title: "Architecture and Implementation of my Smart Home PLC"
authors: ["Rainer Poisel"]
lastmod: 2023-01-30T17:56:57+01:00
draft: false
toc: true
comments: true
image: "header.jpg"
tags: ["homeautomation", "architecture"]
categories: ["Coding"]
---

Since my last article, I have implemented a proof-of-concept version of my PLC. In this article I describe the architecture and implementation of this.

<!--more-->


## Introduction {#introduction}

In our [last article](/blog/smart-home-requirements-and-architecture/), I discussed the requirements and high-level architecture of my home automation system. Now, that I implemented a proof-of-concept version of this system, I want to describe the architecture and implementation details of it. In my view, the results are quite promising. The system is already in use on each of the three floors of my own house making it a distributed system consisting of three nodes.

For now, the feature set is still limited, but powerful at the same time: the application logic can be implemented in C++ as well as in Lua. A small library contains all the blocks I need to automatize lights, window blinds, and alarm switches. The actual runtime parameters such as the cycle time of tasks and the programs associated with them can be configured in a textual format. Supported IO subsystems are I²C, Modbus, and MQTT.

Let's take a closer look at what's behind it and what options there are for interacting with the system.

A hint for you "tl;dr, give me the code" people: just head over to [Implementation](#implementation).


## Roles Interacting with the PLC {#roles-interacting-with-the-plc}

Before describing the architecture and actual usage scenarios of the system, I define the roles that interact with it. The roles determine the requirements for the interfaces they address. Vice versa, the interfaces also define what the roles can do when they work with them.

****Application Developer****: This role configures the system and creates the actual application logic. For the moment, the logic can be implemented in C++ and in the [Lua Programming Language](https://www.lua.org/). The system is currently configured in YAML format. Since JSON is a strict [subset of YAML](https://yaml.org/spec/1.2/), the configuration can alternatively be created in this format. In this way, any text editor is sufficient to perform the application developer's tasks, if she only uses Lua to implement the application logic.

The credo of this PLC runtime is that "everything is a variable". For the moment, only so-called "global variables" are supported. These variables are shared between all components of the PLC runtime. Library blocks (see below) and PLC application logic only rely on the values of these variables. The transfer of the input states to variable values and variable values to the system's outputs is the task of the runtime environment and encapsulated by it, making it possible to test this part of the system independently. This approach allows for easier testing and thus quality assurance (QA) of the whole system because the states of inputs can easily be mocked.

****Library Developer****: On a high-level, the PLC runtime is used to link inputs to outputs using logic defined by the application developer. Predefined logic blocks can be bundled into so-called "libraries". Typical examples of logic blocks are simple logical operations, such as triggers (R_TRIG, F_TRIG), or more complex operations, such as window blind control blocks. Using the libraries can significantly speed up the development of PLC applications. As all inputs and outputs are provided to the PLC application as variables, the library developer can fully focus on the actual logic of components. Direct access to IO subsystems is possible to be implemented in library blocks, but this should be the exception.

My proof-of-concept implementation allows for implementing library blocks in C++. These blocks can be called from application logic implemented in both C++ and Lua. Library developers implementing library blocks in C++ need access to a compiler toolchain to build these blocks including tests for them. It is also possible to implement library block logic in Lua making any text editor sufficient to perform the library developer's tasks. But for now, such logic could only be called from Lua application logic. In the future, I want to implement calling such blocks from C++ application logic as well.

****Runtime Developer****: Extensions to the PLC runtime and the surrounding infrastructure are implemented by this role. Typical examples for such extensions are additional IO subsystems or execution environments. As the core (runtime) is implemented in C++, access to a compiler toolchain is a requirement for now. The following sections describe the architecture and implementation details. These details are especially important for developments carried out by this role.

As a first step, I will give an example for what the application developer has to do in order to create an actual PLC application based on a real-world scenario.


## Developing a PLC Application: Configuration and Logic {#developing-a-plc-application-configuration-and-logic}

In this section, the role of the application developer mentioned above is described using a practical example. The following diagram illustrates this and shows the actual (but simplified) configuration of one of my home automation subsystems (= one floor).

![Hardware Setup for this example](./example-layout.svg)

It consists of:

-   a Raspberry Pi (any Linux based system is possible) executing the PLC runtime and application
-   an Ethernet connection which is used as transport medium by the MQTT client built into the PLC runtime
-   a I²C bus with a PCF8574 module (digital inputs) and a MAX7311 module (digital outputs) attached to it.

What we want to achieve: there are two buttons attached to the system (= two digital inputs). These buttons allow controlling one window blind (= two digital outputs). Furthermore, there is a light attached to the system (= one more digital output). This light is controlled by messages published to a given MQTT topic. Thus, the PLC runtime must subscribe to the defined topic in order to receive these messages. Another PLC setup on a different floor publishes aforementioned MQTT messages. There, publishing them is bound to a button allowing for switching lights on one floor with buttons located on a different floor.

As mentioned above, one of the basic principles of my PLC solution is that all states of inputs and outputs are represented as variables. These variables can then be logically linked. The advantage of this approach is that all IO exchange can be separated from the actual PLC logic. The logic flow per task consists of three steps: read inputs, execute programs (= logically link variables), and write outputs. In order to better understand the execution context of executed programs, the runtime architecture is presented in the next step.


### Runtime Architecture {#runtime-architecture}

The runtime consists of a scheduler managing executed tasks. Each managed task is executed cyclically in its own thread. Within these threads, the assigned `IOLogic` operations (read/write IOs) are executed before and after the assigned programs, respectively. Assigned programs are executed sequentially. Tasks may contain any number of programs with the latter containing the PLC application logic.

![Runtime White-box View](./runtime-classes.svg)

Typical examples for `IOLogic` implementations are (at the time of writing) I<sup>2</sup>C, Modbus, and MQTT subsystems. According to "Everything is a variable", inputs and outputs of the assigned subsystems are assigned to variables. As the `IOLogic` operations are bound to the cyclic execution of the assigned task, there is no need for synchronization when accessing the global variables, the IOs are bound to. There is one exception to this rule: global variables must only be accessed in the tasks, the IOs are exchanged in. At the moment there are no mechanisms in place which prevent the application developer from accessing global variables in multiple tasks at the same time (= potential race condition).

There are two options in my view to assure 100% correct behavior when dealing with global variables: either they are made local to the task, the IO exchange is assigned to or accessing global variables involves some logic which locks and unlocks some resource (e.g. mutex or semaphore) before and after the variable access, respectively.


### Application Development {#application-development}

After understanding the underlying data model, the actual application configuration and logic should be straight forward. In a first step, available IOs are assigned to variables which are then logically linked in the second step. For the aforementioned scenario, the complete configuration looks like this:

<a id="code-snippet--Example runtime configuration"></a>
```yaml
---
tasks:
  - name: main
    interval: 25000  # us
    programs:
      - name: SimpleLogic
        type: Lua
        script: |
          local blind, light_a

          -- executed once before the cyclic execution phase
          function Init(gv)
              blind = Blind.new(BlindConfigFromMillis(500, 50000, 50000))
              light_a = Light.new("A")
          end

          -- executed once every cycle
          function Cycle(gv, now)
              gv.outputs.blind_up, gv.outputs.blind_down =
                  blind:execute(now, gv.inputs.button_up, gv.inputs.button_down)
              if gv.inputs.light_remote then gv.outputs.light_a = light_a:toggle() end
          end
    io:
      - type: mqtt
        client:
          username: user
          password: password
          address: tcp://mybroker:1883
          client_id: floor::main
        inputs:
          /homeautomation/light_remote: light_remote
        outputs: {}
      - type: i2c
        bus: /dev/i2c-1
        components:
          0x3b:  # i2c address
            type: pcf8574
            direction: input
            inputs:
              0: button_up
              1: button_down
          0x20:  # i2c address
            type: max7311
            direction: output
            outputs:
              0: blind_up
              1: blind_down
              2: light_a
```

The configuration contains one task which is assigned one program (implemented in Lua) which is executed every 25 milliseconds. Two IO subsystem instances are assigned to the `main` task: MQTT and I<sup>2</sup>C.

MQTT is an event-based system whereas PLC runtimes are typically executed in a cyclic fashion. This means that MQTT messages need to be buffered until they can be processed by the PLC runtime in the next cycle. Therefore, received messages are stored in a circular buffer. The runtime processes the input states in this circular buffer before it evaluates the tasks which are assigned to a task. In the example shown above, the PLC runtime subscribes to the defined topic `/homeautomation/light_remote`. Upon arrival of a message to that topic, the message's content is evaluated. A `0` (or 0x30) represents a `false` value and `1` (or 0x31) represents a `true` value. The `light_remote` variable is `true` for one cycle once a `1` has been received by the PLC runtime.

The I<sup>2</sup>C bus has two components attached to it: a PCF8574 port expander on address `0x3b` used as provider for digital inputs (up to 8). The buttons are wired to it. A MAX7311 port expander on address `0x20` is used as provider for digital outputs (up to 16). The window blind motor and the MQTT controlled light are attached to it. The button states are copied to the `button_up` and `button_down` (input) variables before the execution of the `SimpleLogic` program. The values of the `blind_up`, `blind_down`, and `light_a` variables are transferred to the real blind motor and the attached light after execution of the `SimpleLogic` program.

The aforementioned YAML file can be processed with any tool suitable for working with YAML files, e.g. [yq](https://github.com/mikefarah/yq). If needed, the logic of the first task's first program can be extracted by issuing:

<a id="code-snippet--Extract program logic using yq"></a>
```shell
yq eval-all ".tasks[0].programs[0].script" <path-to-file>
```

Result:

<a id="code-snippet--BlindLogic"></a>
```lua { linenos=true, linenostart=1 }
local blind, light_a

-- executed once before the cyclic execution phase
function Init(gv)
    blind = Blind.new(BlindConfigFromMillis(500, 50000, 50000))
    light_a = Light.new("A")
end

-- executed once every cycle
function Cycle(gv, now)
    gv.outputs.blind_up, gv.outputs.blind_down =
        blind:execute(now, gv.inputs.button_up, gv.inputs.button_down)
    if gv.inputs.light_remote then gv.outputs.light_a = light_a:toggle() end
end
```

Using these tools, it is also possible to manipulate YAML files. One use-case would be to inject an existing Lua file into the YAML configuration. This way, the application logic can be edited with tools of the trade, e. g. Visual Studio Code or any other Lua editor.

The PLC runtime expects two functions to be defined for each program: `Init` and `Cycle` with the former being optional. The `Init` function, if existing, is called once before the cyclic execution phase starts. It is typically used to define object instances which are then available and used in the `Cycle` function. The `Cyclic` function is executed in the `interval` defined for the task the program is assigned to.

As mentioned before, in the application logic, developers can fully focus on variables only. So, it contains no IO exchange logic. The `blind` object implements the logic of a window blind: switching the motor into "up" or "down" state, turning this state off after specified amounts of time, stopping in the middle of travel, timeout before reversing the movement direction, etc. So, there is a lot going on here, which might not be clear at first sight of the code. The values of the `button_up` and `button_down` input variables are transferred into the `blind` object. The values of the output variables (`blind_up`, `blind_down`) are returned by executing the `blind:execute()` method. The `light_a` object represents the state of the light controlled by the `light_remote` input variable. The value of the `light_a` output variable is returned by the `light_a:toggle()` method in case a MQTT message has been received and stored into the circular buffer.

After creating this configuration, all the application developer has to do to get this up and running is to 1) copy the PLC runtime binary and the YAML configuration file to the target and to 2) start the PLC runtime binary and providing it with the path (e.g. `/etc/config.yaml`) to the YAML configuration file:

<a id="code-snippet--Starting the runtime"></a>
```shell
# the generic binary expects all programs to be implemented in Lua
./generic /etc/config.yaml
```


## Library Architecture and Implementation {#library-architecture-and-implementation}

In this section I want to focus on the library developer's perspective. For the moment, library blocks can only be implemented in C++. But as library blocks only process passed variable values (they don't even know the variables' names) they have virtually no dependencies to other components. One exception to this statement is a dependency to [sol2](https://github.com/ThePhD/sol2) which is the C++ to/from Lua binding I am using in my project.

The following shows the implementation of a rising trigger (R_TRIG) which detects whether a given input was `false` in a previous cycle and is `true` in the current cycle:

<a id="code-snippet--Rising Trigger Implementation"></a>
```c++ { linenos=true, linenostart=1 }
#pragma once

#include <sol/sol.hpp>

namespace HomeAutomation {
namespace Library {

class R_TRIG {
public:
  R_TRIG(bool last) : last{last} {}
  R_TRIG() : R_TRIG(false) {}

  bool execute(bool cur) {
    bool ret = !last && cur;
    last = cur;
    return ret;
  }

  static void RegisterComponent(sol::state &lua) {
    sol::usertype<R_TRIG> trigger_type = lua.new_usertype<R_TRIG>(
        "R_TRIG", sol::constructors<R_TRIG(), R_TRIG(bool)>());
    trigger_type["execute"] = &R_TRIG::execute;
  }

private:
  bool last;
};

} // namespace Library
} // namespace HomeAutomation
```

The `RegisterComponent` function is called by the PLC runtime and registers the `R_TRIG` class in the provided Lua interpreter, allowing for executing Lua code in the application logic such as the following:

<a id="code-snippet--R-TRIG example"></a>
```Lua
local trigger = R_TRIG.new()
trigger:execute(false)
assert(trigger:execute(true), "must be true; rising edge detected")
```

Of course, library blocks may call code from other libraries or contain much more complex logic than the `R_TRIG` above. However, conceptually, it is not intended that IO functionality is executed in library blocks. It is planned for the future to provide facilities for easy implementation of unit tests for any library component in Lua.


## PLC Architecture {#plc-architecture}

The runtime developer is responsible for extending the PLC runtime with additional functionality. A thorough understanding of the PLC architecture is crucial for this task. The solution presented in this document is more a framework than a complete solution. The final product is a PLC application (read: a statically linked binary) which can be easily deployed to any number of target systems. The following figure shows the components of my PLC as [Directed Acyclic Graph (DAG)](https://en.wikipedia.org/wiki/Directed_acyclic_graph).

![PLC Components](./plc-components.svg)

The Entry component contains a generic `main()` function which instantiates the Factory and starts/stops the Runtime. Further, it handles high-level exceptions such as configuration parse errors. The Application is an optional component. It only exists for PLC applications developed in C++ and provides program instances which are defined in the configuration. The ConfigParser currently supports configuration files in [YAML](https://yaml.org/spec/1.2.2/) or JSON format. It is used by the factory to know what runtime components to instantiate.

The Runtime contains some common definitions that are used by most of the other Runtime components, e.g. time related data types. The Library contains pre-defined blocks that can be linked logically in the PLC application logic. This is the component, the library developer implements and extends. The Scheduler provides the mechanisms needed to execute defined PLC application logic according to the timing requirements specified in the configuration. The System component abstracts away peculiarities of the underlying platform such as signal handling. It also provides the low-level implementation of IO mechanisms (MQTT, Modbus, I<sup>2</sup>C). As it is possible to implement some parts (currently: the application logic) in the Lua programming language, the Runtime also contains an embedded Lua interpreter.


## Implementation {#implementation}

The source code is available on GitHub: <https://github.com/honeytreelabs/homeautomation-plc>.

To illustrate the concepts, I placed some examples into the `examples` directory of the repository. A convenience `Makefile` allows for building the examples, test, and production executables for the local platform and newer Raspberry Pi models. The build process is designed to create statically linked binaries for the Raspberry Pi platforms. Statically linked binaries are typically several megabytes in size but much easier to deploy and operate/maintain once deployed. I use [OpenWrt](https://openwrt.org/) on my automation Raspberry Pis because it is very easy with this distribution to create a system with reduced write cycles, which is important for running on storage media with a limited number of write cycles.

The PLC is implemented in modern C++ with [CMake](https://cmake.org/) as the build system generator and [Conan](https://conan.io/) as the dependency manager. Most of the aforementioned PLC components are developed following [TDD](https://en.wikipedia.org/wiki/Test-driven_development) best practices with [doctest](https://github.com/doctest/doctest) as the test framework.


## Conclusion and Outlook {#conclusion-and-outlook}

In this document I described the roles associated with the development of PLC applications using my PLC framework. I provided the knowledge needed to be known to get started quickly. The framework is [publicly available](https://github.com/honeytreelabs/homeautomation-plc) under an open-source license.

The framework presented in this article is more a proof of concept. The PLC configuration is evaluated during runtime. Thus, memory needs to be allocated dynamically when starting the application. Furthermore, the PLC framework must be capable of instantiating components based on a configuration it also needs to parse when starting up. To overcome these requirements towards the target platform, one of my next steps will be to start the development of a code generator which generates the whole PLC (application and runtime).

My ultimate goal is to have a framework which allows creating PLC applications not only for Linux based systems but also for bare metal systems such as microcontroller platforms.
