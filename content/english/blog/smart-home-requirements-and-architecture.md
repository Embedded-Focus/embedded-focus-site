---
title: "Requirements and High-Level Architecture of my Smart Home"
authors: ["Rainer Poisel"]
lastmod: 2022-12-16T09:52:16+01:00
draft: false
toc: true
comments: true
image: "header.jpg"
tags: ["homeautomation", "requirements"]
categories: ["Coding"]
canonical: "https://honeytreelabs.com/posts/smart-home-requirements-and-architecture/"
sitemap:
  disable: true
---

I have been working on my smart home solution for more than eight years. In the first part of my smart home series I want to discuss my design principles.

<!--more-->


## Introduction {#introduction}

<div class="alert alert-danger">
Disclaimer

In this article, components are connected to mains power. Here you need to know what you are doing. This can be very dangerous. I do not take any responsibility for any imitation attempts.
</div>

My smart home is equipped with a [Loxone](https://www.loxone.com/) home automation system. I have to admit: I am pretty satisfied with the system so far. It is very reliable, it was easy to set up. Just take it out of the box, plug it in, off you go. From the price point, it was okay too, at least to get started with something. However, my dream was to have complete freedom in terms of my home automation system and to get rid of my Loxone components. Expanding with additional IOs or newer technologies (e.g. protocols) was one of the pain points of the system: either for financial reasons or for the closed nature of the system.

This document describes the inventory of my home automation system, as well as the requirements for it. I will be compiling the requirements as I go along. Thus, this is a <span class="underline">living document</span>.

You might be tempted to ask: "Why yet another home automation system? There are so many available freely!" This is a legitimate question - and it is the reason for the existence of this document. As you will see, the existing systems do not meet my requirements. But they are a great addition to what I have planned. Especially when it comes to implementing high-level use cases or for providing visualization services, they are great.

In the course of the last years as lead architect of Soft PLC systems, I got great technical insights into the inner workings of such controllers and into the tools of the trade to document complex systems. This post will be more of a living document. Whenever I discover something new or whenever a decision has to be made, it will be documented here.

I already published some home automation articles for the German "Linux Magazin". Many of my thoughts from back then are still valid. Unfortunately, all articles are in German. But in case, they should be translatable using available online tools. For reference, I will list my articles here:

-   [Feldbussysteme unter Linux konfigurieren und einsetzen](https://www.linux-magazin.de/ausgaben/2018/04/feldbusse/), Rainer Poisel, Linux Magazin 04/2018
-   [Hausautomatisierung auf Basis des MQTT-Protokolls](https://www.linux-magazin.de/ausgaben/2017/07/mqtt/), Rainer Poisel, Linux Magazin 07/2017
-   [Hausautomatisierung mit I2C-Buskomponenten](https://www.linux-magazin.de/ausgaben/2016/12/i2c-bus/), Rainer Poisel, Linux Magazin 12/2016


## Base Architecture of the System {#base-architecture-of-the-system}

The following diagram shows the general structure of electrical components in my house. All components are wired in a structured manner. Actors and inputs are connected to the electrical cabinet of the story they are located in. The cabinets in turn are wired so that it is possible to communicate between them. In my case, I decided to use Ethernet as communication medium between the cabinets.

Please note that in this diagram, I am using switches as inputs and lights as actors. In reality, inputs could be anything from digital inputs to analog inputs representing some physical quantity such as temperature or electrical current. Actors could also refer to window blind motors or other devices which should be operated by the home automation controller.

![System High-Level Architecture](./system-low-level-arch.svg)

Two typical use cases:

-   Use Case 1: A switch on the upper floor should activate a light located on the same floor. Input and actor are located on the same floor. No inter-cabinet communication is necessary. All logic can be processed within the cabinet.
-   Use Case 2: Using a switch in the ground floor, some light in the basement should be operated. Input and actor are located on different floors of the building. The change in inputs has to be communicated between the relevant electric cabinets.

Let's formalize the relationship between components here first. The model is like this:

-   Each floor has 1 electric cabinet installed. Therefore, with 1:n floors, the system consists of 1:n electric cabinets.
-   Each cabinet might have 0:n inputs connected to it.
-   Each cabinet might have 0:n actors connected to it.

The next diagram shows a typical layout of an electric cabinet:

![Cabinet Layout](./cabinet-layout.jpg)

A cabinet typically consists of one Single Board Computer (SBC) like a Raspberry Pi and multiple I/O components attached to it. The Raspberry Pi acts like a Programmable Logical Controller (PLC) with periodic cyclic scanning. Inter-cabinet communication takes place via Ethernet. In simple terms, the SBC converts between signals that may arrive on different bus systems to outputs that may also be connected on different bus systems. In the shown diagram, only I<sup>2</sup>C components are attached to the Raspberry Pi. But in practice, components on other communication busses such as ModBus might also be attached to it.


### Hardware Suppliers {#hardware-suppliers}

The hardware components shown in the diagrams are actually installed in my home automation solution. They are all high quality and characterized by favorable purchasing costs.


#### CC-Tools {#cc-tools}

This manufacturer offers its modules as kits and as fully assembled boards for the I<sup>2</sup>C and other bus systems. In addition to the circuit boards, touch-proof housings are also offered, which are suitable for direct installation in control cabinets. I mainly use CC-Tools' [Output Modules](https://www.cctools.eu/artikel/index.php/1008) to operate heavy loads and/or lights.

Shop: [Link](https://www.cctools.eu/)


#### Horter &amp; Kalb {#horter-and-kalb}

Horter &amp; Kalb sell I<sup>2</sup>C input and output blocks (among other communication media) for 24VDC components (switches, buttons, relays). Almost all of my light and window blinds push buttons are connected to [input modules](https://www.horter-shop.de/en/i2c-din-rail-modules/105-kit-i2c-digital-input-module-4260404260714.html) like this one. Horter &amp; Kalb also offer [output modules](https://www.horter-shop.de/en/i2c-din-rail-modules/117-kit-i2c-digital-output-module-4260404260721.html) which allow for operating 24VDC relays, e.g. by the German manufacturer [Finder](https://www.findernet.com/). The [Finder Relay 38.51.7.024.0050](http://www.reichelt.at/?ARTICLE=28317) relays incl. sockets are a great choice for electrical cabinets due to their narrow form factor.

Shop: [Link](https://www.horter-shop.de/)


#### KMtronic {#kmtronic}

KMtronic sells relays for all sorts of communication media such as ModBus/RTU, ModBus/TCP, and RF protocols. They also offer adapters for the various communication protocols and clips for mounting their modules to DIN rails (35 mm). In my home automation system I have installed some ModBus/RTU relays to operate lights and other high-current appliances.

Shop: [Link](https://sigma-shop.com/)


## Requirements {#requirements}

I will summarize the main requirements that need to be met by the software controlling the whole system. For now, most of them address shortcomings of my existing system. I have been living with them for more than eight years and want to overcome them first. The keywords for defining requirement levels are chosen according to [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119). In complex systems, requirements are classified into system requirements, architecture requirements, and implementation requirements. Due to the low number of actual requirements, I will not make this classification at least for now.


### Non-functional Requirements {#non-functional-requirements}

From the [Scaled Agile Framework (SAFe)](https://www.scaledagileframework.com/nonfunctional-requirements/), © Scaled Agile, Inc.:

<div class="alert alert-success">
Nonfunctional Requirements

Nonfunctional Requirements (NFRs) define system attributes such as security, reliability, performance, maintainability, scalability, and usability. ... Also known as system qualities, nonfunctional requirements ... ensure the usability and effectiveness of the entire system.
</div>

The non-functional requirements thus specify criteria which can be used to judge the operation of the system. Most of the non-functional requirements of my home automation system target shortcomings of my existing system.


#### The software must be resilient to outages of sub-systems. {#the-software-must-be-resilient-to-outages-of-sub-systems-dot}

Linking inputs with outputs represents dependencies between the different components. The failure of one component must not lead to the failure of other, functioning components. An example of this would be the failure of a pushbutton. This must not lead to faulty evaluation of other inputs. Furthermore, it must also be possible to further activate/deactivate linked outputs.

A more complex example is the communication between floors. If this fails, linked components within a floor must continue to function. With relation to the use cases mentioned above, this means that use case 1 must continue to function even when use case 2 does not function anymore.


#### The software must have minimal dependencies to other components. {#the-software-must-have-minimal-dependencies-to-other-components-dot}

Developed software components must be as self-contained as possible. Dependencies, such as program libraries must be contained directly in the executable programs, in order to keep the number of components to be installed as small as possible.


#### The solution must be usable independent of the chosen Linux distribution. {#the-solution-must-be-usable-independent-of-the-chosen-linux-distribution-dot}

Different Linux distributions mean different requirements for running software. In addition to different C standard libraries, different package formats are also used. My home automation solution should be open for all these combinations. Primarily, I am thinking of a deployment under Debian GNU/Linux or OpenWrt. Of course this implies that the control software has to be rebuilt (read: compiled, linked, and deployed) depending on the case.

Some approaches, such as [gokrazy](https://gokrazy.org/), let the software to be executed run directly from the kernel without an init process at all. The overall product behaves like an appliance with well-defined tasks. Also for my home automation solution such an approach is conceivable, if also efforts would have to be invested, in order to implement the configuration tasks, which the complete distributions take over.


#### The software must be executable on read-only Linux systems. {#the-software-must-be-executable-on-read-only-linux-systems-dot}

My home automation system is built from Linux-based devices. Currently, a Raspberry Pi is serving as a controller in each control cabinet. A major problem of embedded Linux systems is the so-called flash wear-out due to too frequently executed write operations on flash memory.

Common Linux distributions like OpenWrt allow read-only operation. The control software for my home automation system has to cope with this execution context.


#### The downtime when migrating must be as short as possible. {#the-downtime-when-migrating-must-be-as-short-as-possible-dot}

It must be possible to operate the existing and new systems side by side, so that a gradual conversion is possible. My home automation system has critical components attached to it, such as the lights in my house, which have to work no matter what.


#### The cost per IO must be more favorable than for the existing system. {#the-cost-per-io-must-be-more-favorable-than-for-the-existing-system-dot}

The existing solution is characterized by simple setup and reliable operation. However, this is reflected in the cost of sourcing the components. Therefore, high-quality and widely used standard components that meet the necessary safety requirements should be used as far as possible. At the time of writing, a price of 15 € per digital output and 3 € per digital input is targeted.


#### The software must be implemented in Modern C++. {#the-software-must-be-implemented-in-modern-c-plus-plus-dot}

I decided to create the software of my home automation solution in modern C++ (minimum: C++11). Modern C++ allows to write less and more readable code. The language is widely used and offers extensive tooling to ensure quality requirements. It also provides a large number of libraries.

Another reason to use modern C++ was to deepen my knowledge in this ecosystem. Alternatively, I thought about an implementation in Rust. However, I currently have a greater need for C++ knowledge. Therefore I decided for the latter.


### Functional Requirements {#functional-requirements}

From "Chapter 4: Requirements - Writing Requirements", Fulton R, Vandermolen R in CRC Press, 2017:

<div class="alert alert-success">
Functional Requirements

In software engineering and systems engineering, a functional requirement defines a function of a system or its component, where a function is described as a specification of behavior between inputs and outputs.
</div>

In this document, functional requirements describe all features pertaining to the functioning of the technical aspects of my house. Some of them are obvious: the bus systems my IO components are attached to must be supported by the controller's software. Other requirements are less obvious as they define the inner workings of my controller's software, e.g. by specifying how the logic of my home automation system can be created or how additional sub-systems, such as protocols, can be added to the system.


#### The software must support I<sup>2</sup>C Components. {#the-software-must-support-ic-components-dot}

Most of the existing components in my home automation system communicate via I<sup>2</sup>C with the Raspberry Pis installed in each electrical cabinet. Since I want to continue using these components, the software of the controller must support this bus system. The advantage of the components I use lies in the favorable procurement costs, as well as in the good availability and operational reliability.


#### The software must support ModBus IOs. {#the-software-must-support-modbus-ios-dot}

Since several of my output modules speak the ModBus protocol, the software of the controller must necessarily support this protocol.


#### The software must support MQTT communication. {#the-software-must-support-mqtt-communication-dot}

The inter-floor communication is based on Ethernet in my case. Therefore, I want to use MQTT to exchange messages between the controllers of the floors.

Furthermore, MQTT is a protocol that is supported by practically all common home automation solutions.


#### The software must be integrable into existing OSS Smart Home Solutions. {#the-software-must-be-integrable-into-existing-oss-smart-home-solutions-dot}

As mentioned in the introduction, I want to integrate my solution into existing home automation solutions such as [Home Assistant](https://www.home-assistant.io/) or [openHAB](https://www.openhab.org/) in order to be able to implement high-level use cases (e.g. scenes) or to make it easier to integrate other systems such as [HomeMatic](https://homematic-ip.com/).

The integration must be designed in such a way that a failure of the other home automation solutions is not critical and directly operated components can continue to be correctly linked with each other.


#### It must be possible to extend the system with additional protocols. {#it-must-be-possible-to-extend-the-system-with-additional-protocols-dot}

I want to extend my system with additional components. Unfortunately, not all locations in my house are wired properly, so I have to rely on integrating wireless components. This requires the controller's software to be open to integrating new protocols that are not yet known.

In the near future I would like to integrate [LoRa](https://lora-alliance.org/) or [HomeMatic](https://homematic-ip.com/) devices. Many different battery-powered and high-quality sensors and actuators are available here at reasonable prices.


#### It must be possible to create the logic in C++. {#it-must-be-possible-to-create-the-logic-in-c-plus-plus-dot}

The controller creates the links between input signals and actuators. The definition of this logic shall be done in modern C++ in a first step. To keep implementation efforts as low as possible, a standard library with blocks for controlling lights, blinds or for communication via MQTT will be provided.


#### It must be possible to create the logic in Lua. {#it-must-be-possible-to-create-the-logic-in-lua-dot}

Formalizing the logical links in C++ offers the greatest possible flexibility. However, this approach is also the most labor-intensive. For less time-critical applications, I would like to rely on interpreter-based solutions.

[The Programming Language Lua](https://www.lua.org/) is characterized by universal applicability and easy integrability. It is still high-level enough to keep the amount of boilerplate code low. The standard library for C++ implementations should also be available in Lua scripts.


#### It should be possible to create the logic according to IEC 61131-3. {#it-should-be-possible-to-create-the-logic-according-to-iec-61131-3-dot}

In central Europe, logic for PLCs is created according to the IEC 61131-3 standard. The most widely used sub-languages of this standard are Structured Text (ST) and Function Block Diagram (FBD). As first attempt, an interpreter for the Structured Text language should be implemented.


## What Systems I Have Looked Into {#what-systems-i-have-looked-into}

[Loxone](https://www.loxone.com/) is the obvious one: I have been using this system for more than eight years. Logic for this system can be created using a GUI application with a programming language similar to IEC 61131-3 Function Block Diagram (FBD). It also offers light-weight scripting possibilities. But aside that, the system is rather closed. There are solutions which integrate Loxone, such as [LoxBerry](https://wiki.loxberry.de/start). To me, this approach is still too inflexible. I want to control every part of my system. Furthermore, I want maximum freedom when it comes to the components that I can attach to my system.

Several smart home solutions are publicly available for free (as in "open source") on the internet. The following were evaluated for their ability to integrate third-party software:

[OpenHAB](https://www.openhab.org/) is related to the Eclipse Ecosystem. The runtime is implemented in Java. It supports more than 2.000 things, is available as Open Source Software, and has a large user base. From a technical point of view, I am not convinced to use Java-based applications in the embedded area. My experience with deploying Java applications is mixed. There are too many moving parts that have to interact with each other.

I am still considering [OpenHAB](https://www.openhab.org/) as component which offers additional services to my home automation system such as visualization or scenes. It might also be suitable to implement prototypical solutions for new protocols or types of devices. But there are similar solutions for scenarios like these:

[Home Assistant](https://www.home-assistant.io/) seems to be the most complete solution for now. It offers myriads of integrations, dedicated apps, and is flexible in terms of the execution environment. The runtime is implemented Python. As with Java applications, I'm not yet convinced that Python applications will work well in the embedded space. I can rather imagine running Home Assistant in a container at a central location in a local cluster.

My control software is then integrated by one of these higher-level solutions. The details still need to be worked out here, but they are currently not critical in terms of time, since the above-mentioned Use Cases 1 and 2 can also be implemented with my control software alone.


## Conclusion {#conclusion}

In this post I started to document my thoughts about my smart home system. As already mentioned, this is a living document. On the way to implementation will certainly happen more considerations, you also want to write down here.

In the next post I will refine the architecture. In the meantime there is already a working prototype. I can therefore also describe details of the implementation.
