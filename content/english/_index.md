---
banner:
  title: "Embedded Focus"
  content: "Ready to lead with strong, efficient processes."
  slogan: "DevSecOps for Embedded Systems: <br /> Innovation without compromise"
  quote:  "\"Modern development methods aren't a luxury for software giants—they can be implemented securely and scalably by any team.\""
  button:
    enable: false
    label: "Contact"
    link: "contact/"

customers:
  title: "My Customers"
  description: "My collaboration with clients is defined by partnership and reliability. My extensive DevSecOps expertise delivers proven solutions that create long-term value."
  logos:
  - image: "/images/customers/wago.svg"
    name: "WAGO"
  - image: "/images/customers/oebb-ts.svg"
    name: "OeBB Train Tech"
  - image: "/images/customers/haag.cc.svg"
    name: "haag embedded systems und it consulting GmbH"

features:
- title: "Have you ever thought ..."
  image: "/images/challenges.jpg"
  content: ""
  # icon: fa-road-barrier
  # padding: 8
  bulletpoints:
  - "\"How can we stay innovative with all the requirements of the Cyber Resilience Act?\""
  - "\"Our code is so fragile that every change is risky.\""
  - "\"Fixing bugs and security issues takes too long.\""
  - "\"Our variants and dependencies constantly cause problems.\""
  - "\"Outdated processes frustrate our best people.\""
  button:
    enable: false

- title: "This is How I Help Companies"
  image: "/images/success.jpg"
  content: |-
    Because the truth is: The number one risk in global competition is a lack of innovation. We can no longer afford productivity blockers like insecure processes or missing automation.

    ##### What if ...
  icon: fa-circle-check
  padding: 6
  bulletpoints:
  - "... you saw IEC 62443 or the Cyber Resilience Act (CRA) as a springboard—automated compliance, faster processes, and finally room for real innovation?"
  - "... your embedded software was now built consistently and reproducibly through automated build pipelines?"
  - "... the safety net created by automation encouraged bold moves—so that innovation no longer feels risky, but liberating?"
  - "... the narrative changed—applications started coming in again because word spread about how enjoyable the work is?"
  button:
    enable: false

- title: "My Offer for your Success"
  image: "/images/lightbulb.jpg"
  content: ""
  # icon: fa-gears
  # padding: 8
  accordions:
  - title: Build Pipelines for Embedded Software
    content: |-
      I develop custom build pipelines that prioritize reliability, speed, and scalability.

      **Development Environments**  
      Container technologies like Docker, Podman, and Kubernetes enable reproducible development environments. Using GitOps, build and test environments are versioned and automatically deployed.

      **Continuous Integration / Continuous Delivery (CI/CD)**  
      Efficient CI/CD pipelines are essential for reliable builds and fast iterations. With GitLab CI/CD, GitHub Actions, and Jenkins, processes can be automated, incremental builds optimized, and secure deployments ensured.

      **Integrated Security Checks**  
      - SBOM creation, CVE scanning, and code signing with Trivy, Grype, or Sigstore to ensure software reproducibility and integrity.

      **Artifact Repositories**  
      Product components, firmware images, and development tools are managed through powerful repository managers like Artifactory, Nexus, and [Pulp](https://pulpproject.org/), ensuring secure versioning and reproducibility of all software components.

      **Automated Builds**  
      I optimize build processes for complex embedded projects using CMake, Bazel, or Meson, reducing compilation times and efficiently managing dependencies. Automated CI/CD workflows with GitLab CI/CD, GitHub Actions, or Jenkins ensure continuous and reproducible builds, catching errors early.

      **Quality Assurance & Test Automation**  
      Implementation of unit, integration, and system tests (including hardware-in-the-loop testing with pytest and labgrid) for embedded software systems. Static code analysis tailored to the specific technology stack.

      **Firmware/Software Deployment & Updates**  
      Proven methods such as OTA (Over-the-Air) updates and artifact repositories ensure secure and efficient distribution of embedded software.

      **Issue Tracking**  
      By integrating issue tracking systems like Jira, Polarion, or Redmine, bugs and requirements become visible throughout the development process. Tight integration with CI/CD pipelines ensures traceable workflows and efficient task management.

  - title: "Modernizing Legacy Software Systems."
    content: |-
      This is my specialty: I help you modernize existing systems without disrupting ongoing operations—using a well-thought-out approach that prioritizes security, maintainability, and performance.

      **Clean Architecture & Sustainable Codebase**  
      A successful modernization starts with structured code and architectural improvements. I analyze existing systems, resolve technical debt, remove outdated dependencies, and enhance modularity. Targeted refactoring and code optimization improve maintainability, while modern programming languages like Rust, Modern C++, or Python provide better security and performance. Additionally, I support migration to modern build systems like CMake, Bazel, or Meson to streamline development processes.

      **Automation & DevSecOps for Smooth Workflows**  
      Many embedded projects still rely on manually triggered builds in IDEs. I migrate these workflows to a CI/CD environment, ensuring automated and reproducible builds. CI/CD pipelines with GitLab CI/CD or Jenkins reduce wait times and prevent errors. Automated tests with Google Test, Catch2, doctest, or Hardware-in-the-Loop (HiL) approaches enhance quality assurance, while security checks with tools such as SonarQube, Clang-Tidy, and SBOM analysis ensure security requirements are met.

      **Porting & Integrating New Technologies**  
      Outdated platforms and operating systems slow down innovation. I assist in porting to modern embedded platforms, ensure reproducible development environments with Docker and Podman, and optimize embedded systems for Embedded Linux and RTOS. This keeps software maintainable and ready for future developments.

  - title: "DevSecOps Training and Workshops."  
    content: |-
      Secure and efficient embedded development requires well-structured processes and solid expertise. Whether it's DevOps or DevSecOps as a whole, or specific topics like Git workflows, CI/CD practices, or security testing—my hands-on training sessions combine deep theoretical knowledge with practical experience, enabling your team to apply what they learn immediately.

      **Custom Training Programs**  
      Every company faces unique challenges. I tailor my training courses specifically to your team’s needs—from introductory sessions to in-depth workshops for experienced developers. Whether it’s best practices for CI/CD, efficient Git workflows, or integrating security checks into existing processes, the content is customized to match your requirements.

      **Practical, Hands-On Learning**  
      My training sessions focus on active learning rather than dry theory. In interactive workshops, we work with real development environments and solve problems directly in code. Whether using local setups or Docker containers for a consistent environment, your team can try everything out immediately and get answers to their questions in real time.

      **Extensive Experience in Teaching & Industry**  
      With years of university teaching experience and leading numerous industry workshops, I present complex topics in a clear and practical way. I not only help your team understand these concepts but also ensure they can apply them in their daily work.
  - title: "Automation for Secure Compliance."
    content: |-
      Meeting security standards such as IEC 62443, IEC 26262, IEC 61508, and the requirements of the Cyber Resilience Act (CRA) presents significant challenges for many companies. I help automate these processes to ensure audit security, implement compliance efficiently, and maintain development speed.

      **Automated Compliance Documentation & Reporting**  
      Regulatory requirements demand extensive documentation and proof of security and compliance. I develop solutions that generate relevant reports automatically—from security analyses and test protocols to automated compliance reports for audits. This reduces manual effort and ensures that no critical information is missing.

      **Integrated Security Checks**  
      Rather than treating security as a separate process, I integrate security checks directly into CI/CD pipelines. Static and dynamic code analysis with tools such as SonarQube, Clang-Tidy, and Coverity helps identify potential vulnerabilities early. Tests for secure boot, access controls, and cryptographic processes are embedded as automated checks within the development workflow.

      **SBOMs & Software Supply Chain Transparency**  
      With increasing focus on supply chain security, generating a Software Bill of Materials (SBOM) is becoming essential. I integrate tools such as Syft, SPDX, or CycloneDX to provide full transparency over dependencies, licenses, and potential security risks. By automating dependency tracking, I ensure that all requirements of the Cyber Resilience Act (CRA) are met.

  - title: "Embedded Software Development."
    content: |-
      Modern embedded systems require high performance, security, and scalability. I develop tailored software solutions for embedded, IoT, and industrial systems, helping companies implement scalable, robust, and standards-compliant solutions.  

      **System Software & Infrastructure for (I)IoT**  
      IoT and Industry 4.0 applications demand powerful server services, runtime systems for PLC applications, and backends for distributed systems. I design scalable client-server architectures, cloud integrations, and edge computing solutions optimized for efficient operation. My iSAQB© CPSA-F certification formally demonstrates my deep expertise in software architecture.

      **Low-Level Software for Bare-Metal & Embedded Linux**  
      Real-time capability and low-level hardware design are crucial for microcontroller and embedded Linux applications. I develop firmware, drivers, and real-time systems that run safely and efficiently—from bootloader optimization to device-specific drivers.

      **Containerization for Embedded and Edge Devices**  
      Modern embedded and edge systems increasingly benefit from container technologies like Docker, Podman, and Kubernetes, making applications more flexible, scalable, and manageable. I assist companies in adopting containerization for embedded environments—from architecture consulting and planning to implementation and optimization. I carefully consider resource efficiency, real-time requirements, and security aspects to seamlessly integrate containers into embedded and industrial environments.

      **Integration of External Software & Machine Learning**  
      Integrating third-party software components, protocol stacks, and AI models requires a deep understanding of embedded architectures. I bring machine learning to embedded hardware and optimize models for edge AI and resource-constrained systems.

      **Extensive Experience & Broad Technology Expertise**  
      With strong expertise in C/C++, Python, Golang, Java, Lua, and Rust, I develop efficient, portable, and future-proof software solutions. My ability to quickly adapt to new ecosystems allows for flexible, tailored implementations across a wide range of applications.
  button:
    enable: false

featured_authors:
- "rainer-poisel"

---
