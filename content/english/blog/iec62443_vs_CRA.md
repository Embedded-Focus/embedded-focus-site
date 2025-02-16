---
authors: ["Markus Haag", "Rainer Poisel", "Stefan Riegler"]
date: '2024-06-27'
image: header.jpg
title: IEC 62443 Standard GAP Analysis to the Cyber Resilience Act (CRA)
toc-own-page: true
tags: ["cra", "iec62443"]
categories: ["security"]
---

This whitepaper explores the alignment and gaps between IEC 62443 and the Cyber Resilience Act (CRA), offering insights to enhance compliance and product cybersecurity.

<!--more-->

# Abstract

This whitepaper examines the alignment between the IEC 62443 standard series and the EU Cyber Resilience Act (CRA) regulation. It provides a detailed examination of the correlations and highlights the gaps between the IEC 62443 standard and the CRA. Additionally, it offers insights into how organizations can address these gaps to enhance their compliance and improve the robustness of their products against current and future cybersecurity threats.

# Introduction

In general, due to the specific focus and objectives of the IEC 62443 standard ([reference](https://www.dke.de/iec-62443)), it is designed to be applicable primarily to Industrial Automation and Control Systems (IACS). The IEC 62443 standard targets the unique security requirements of industrial environments, where the integration of operational technology (OT) and information technology (IT) presents distinct challenges. The standard provides guidelines and best practices to secure IACS against cyber threats, ensuring the security, reliability, and resilience of industrial operations. Consequently, its applicability is tailored to address the complexities and cybersecurity needs of industries such as manufacturing, energy, water treatment, and other - often critical - sectors dependent on automation and control systems.

Following the IEC 62443 standard offers a multitude of advantages for organizations, particularly those operating within Industrial Automation and Control Systems (IACS). Beyond being well-known and established with a clear focus on IACS, the standard provides comprehensive coverage that includes both technical and procedural aspects, improving overall risk management. It also enhances interoperability between various components and systems, supports regulatory compliance, and boosts trust and credibility. The standard is globally recognized, vendor-neutral, and scalable, ensuring adaptability to different environments. Additionally, it promotes secure lifecycle management and facilitates effective incident response, making it a robust framework for enhancing cybersecurity resilience.

The EU Cyber Resilience Act ([reference](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=celex:52022PC0454)), set to come into effect soon, aims to strengthen cybersecurity measures across member states. Below is a brief summary of the timeline of key events:

- September 2022: Cyber Resilience Act proposal ([reference](https://www.europarl.europa.eu/legislative-train/theme-a-europe-fit-for-the-digital-age/file-european-cyber-resilience-act))
- November 2023: EU council agrees on the (revised) CRA ([reference](https://www.europarl.europa.eu/news/en/press-room/20231106IPR09007/cyber-resilience-act-agreement-with-council-to-boost-digital-products-security))
- March 2024: Parliament approves the CRA ([reference](https://www.europarl.europa.eu/news/en/press-room/20240308IPR18991/cyber-resilience-act-meps-adopt-plans-to-boost-security-of-digital-products))
- **2024**: Expected **entry into force** ([reference](https://ec.europa.eu/commission/presscorner/detail/en/QANDA_22_5375))
- **Reporting for vulnerabilities** and incidents applies **21 months** from entry. ([reference](https://ec.europa.eu/commission/presscorner/detail/en/QANDA_22_5375))
- **Manufacturers** will have to apply the rules **36 months** after their entry into force. ([reference](https://digital-strategy.ec.europa.eu/en/library/cyber-resilience-act-factsheet), [reference](https://ec.europa.eu/commission/presscorner/detail/en/QANDA_22_5375))

The requirements of the [CRA proposal](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=celex:52022PC0454) are defined in its Annex I in two groups:

- Section 1: Security requirements relating to the properties of products with digital elements,
- Section 2: Vulnerability handling requirements.

The Cyber Resilience Act Requirements Standards Mapping ([reference](https://data.europa.eu/doi/10.2760/905934)) also reflects these two groups in its document structure. In this whitepaper, we focus on requirements for components to ensure they meet overall system security needs, specifically discussing parts:

- IEC 62443-2-1: Establishing an industrial automation and control system security program
- IEC 62443-3-2: Security risk assessment for system design
- IEC 62443-4-1: Secure product development lifecycle requirements,
- IEC 62443-4-2: Technical security requirements for IACS components.

Comparing the headlines of the CRA Sections and the IEC 62443 Standards suggests that CRA Annex I Section 1 covers parts of IEC 62443 and CRA Annex I Section 2 is similar to IEC 62443-4-1. The following sections provide a closer look at these comparisons.

## Overview of IEC 62443 vs. CRA: Matches and Gaps

To clearly illustrate how the IEC 62443 standard addresses the requirements of the Cyber Resilience Act (CRA), we provide the following summary based on Section 4 of the Cyber Resilience Act Requirements Standards Mapping ([reference](https://data.europa.eu/doi/10.2760/905934)). This summary highlights the relevant sections within the IEC 62443, that correspond to specific CRA requirements. Tables 1 and 2 detail how the provisions and requirements align with the cybersecurity requirements outlined in the CRA, thereby enhancing the security and resilience of digital products in Industrial Automation and Control Systems. CRA Requirements that are not covered by the IEC 62443 standard series are identified as **GAP** in the tables. Each table focuses on a specific section of CRA Annex I.

| CRA Requirement | Description                                                                              | IEC 62443 Part |
| :-------------: | ---------------------------------------------------------------------------------------- | :------------: |
|        1        | Products designed, developed, and produced with appropriate cybersecurity based on risks |   3-2 & 4-1    |
|        2        | Products delivered without known exploitable vulnerabilities                             |      4-1       |
|       3a        | Risk assessment                                                                          |      GAP       |
|       3b        | Protection from unauthorized access (authentication, identity, and access management)    |      4-2       |
|       3c        | Protection of data confidentiality (encryption at rest and in transit)                   |      4-2       |
|       3d        | Protection of data integrity (against unauthorized manipulation or modification)         |      4-2       |
|       3e        | Process only relevant and necessary data (data minimization)                             |      GAP       |
|       3f        | Availability of essential functions (resilience against denial of service attacks)       |      4-2       |
|       3g        | Minimize negative impact on other services' availability                                 |      GAP       |
|       3h        | Limiting attack surfaces (external interfaces)                                           |      4-2       |
|       3i        | Reduce incident impact using mitigation techniques                                       |      3-2       |
|       3j        | Recording and monitoring of internal activity (security-related information)             |      4-2       |
|       3k        | Addressing vulnerabilities through security updates                                      |   2-1 & 4-2    |

| CRA Requirement | Description                                                                                | IEC 62443 Part |
| :-------------: | ------------------------------------------------------------------------------------------ | :------------: |
|        1        | Manufacturers shall document vulnerabilities and include a software bill of materials      |      GAP       |
|        2        | Address and remediate vulnerabilities promptly, including security updates                 |      4-1       |
|        3        | Regularly test and review product security                                                 |      GAP       |
|        4        | Disclose fixed vulnerabilities, including descriptions and remediation info, after updates |      4-1       |
|        5        | Enforce a coordinated vulnerability disclosure policy                                      |      GAP       |
|        6        | Facilitate sharing info on vulnerabilities and provide a contact address for reporting     |      GAP       |
|        7        | Provide secure mechanisms for timely updates to fix vulnerabilities                        |      4-1       |
|        8        | Distribute free security patches promptly with relevant advisories                         |      4-1       |

The following sections summarize how the IEC 62443 parts meet the requirements outlined in the CRA. These sections are relatively brief as complying with the IEC 62443 standard results in satisfying the related CRA requirements. In our whitepaper, we aim to highlight the identified gaps. Therefore, the subsequent sections will address the GAP entries from the tables above.

## Aligning IEC 62443 with CRA Annex I, Section 1

For designing and developing secure products, IEC 62443-4-1:2018 prescribes security principles, including security by design, integrated throughout product development. This ensures robust cybersecurity measures in combination with IEC 62443-3-2:2020, which details steps for identifying assets, threats, and vulnerabilities, and specifies different security levels, from the outset.

For delivering products without known vulnerabilities, IEC 62443-4-1:2018 mandates thorough security testing and management of identified issues. To prevent unauthorized access, IEC 62443-4-2:2019 outlines robust user authentication and authorization controls. Additionally, it covers data confidentiality through encryption, data integrity protections, and operational availability against denial of service attacks.

The standard IEC 62443-4 addresses CRA requirements on limiting attack surfaces through physical hardening and mandates capabilities for event auditing, such as timestamping and non-repudiation. It also provides guidelines for patch management and security updates, ensuring vulnerabilities can be promptly addressed. In conjunction with IEC 62443-2-1:2010 which defines guidelines for developing and implementing a comprehensive cybersecurity management system for Industrial Automation and Control Systems (IACS), a proper process can be established.

## Aligning IEC 62443 with CRA Annex I, Section 2

CRA Annex I, Section 2 focuses on preparing companies from a process and organizational standpoint to manage potential incidents with minimal impact. While IEC 62443-4-1 aims for a similar goal, it lacks specific provisions for device emergency response, typically managed by teams such as Computer Emergency Response Teams (CERTs) or Product Security Incident Response Teams (PSIRTs), and this aspect requires further verification.

IEC 62443-4-1 already addresses nearly 50% of the requirements outlined in CRA Annex I, Section 2. It includes a secure update process that ensures devices can be updated from the company’s process perspective.

Furthermore, the IEC 62443-4-1 standard does not explicitly mandate CERTs and PSIRTs, but the requirements logically necessitate the formation of such teams. Although the Software Bill of Materials (SBOM) is not explicitly required, the requirements will result in the creation of an SBOM, and the outcomes of these teams must be handled in an update process. Preferably, this should be done through a Continuous Integration/Continuous Deployment (CI/CD) process to ensure timely updates.

As CRA I, Section 2 addresses the preparation of companies from the processes or organizational point of view to handle possible incidents in a manner that minimizes the impact. IEC 62443-4-1 also intends to achieve this but is missing the specific device emergency response provisions typically handled by CERTs and PSIRTs.

# IEC 62443 Gap Analysis

The following section lists the remaining requirements from the Cyber Resilience Act (CRA) that are not addressed by the IEC 62443 standard. Each of the following subsections details the unmet requirements and outlines the necessary measures to satisfy them. Direct quotes from the Cyber Resilience Act are highlighted *like this*.

## Cyber Resilience Act, Annex I, Section 1

The first section of Annex I to the CRA starts as follows:

*(3) On the basis of the risk assessment referred to in Article 10(2) and where applicable, products with digital elements shall:*

**CRA Requirement**: *(a) be delivered with a secure by default configuration, including the possibility to reset the product to its original state;*

Following the IEC 62443-4-1 an Implementation of Secure Guidelines is needed. This requires to adhere to security guidelines such as the "Secure Product Design Cheat Sheet", Chapter "Configuration" ([reference](https://cheatsheetseries.owasp.org/cheatsheets/Secure_Product_Design_Cheat_Sheet.html)) by the Open Web Application Security Project (OWASP). The OWASP recommends to implement secure defaults: "Ensuring Secure by Default: Configure systems and software to be secure by default, with minimal manual setup or configuration required".

The requirement to reset the products to their original state should reflect the state-of-the-art in Embedded Systems and is, in general, a good requirement. Nevertheless, it must be well specified, and it must be ensured that everything is set back to factory settings.

**CRA Requirement**: *(e) process only data, personal or other, that are adequate, relevant and limited to what is necessary in relation to the intended use of the product ('minimisation of data');*

To fulfill this requirement, it is necessary to select secure principles and guidelines as part of the IEC 62443-4-1 process and to establish a well-defined device architecture. An important principle highlighted in the OWASP "Secure Product Design Cheat Sheet" is the Principle of Least Privilege and Separation of Duties ([reference](https://cheatsheetseries.owasp.org/cheatsheets/Secure_Product_Design_Cheat_Sheet.html)). This overarching principle must be translated into specific, actionable requirements, resulting in a comprehensive set of requirements that address the CRA requirements to this aspect.

**CRA Requirement**: *(g) minimise their own negative impact on the availability of the services provided by other devices or networks;*

The selected security principles, 3a, and a secure architecture implicitly force the implementation of a firewall, which fulfills 3g, if it is well designed. It is also good practice that no service is configured, installed, or active that is not necessary. This results in a requirement that the device shall work with secure defaults, which implicitly makes the device independent of other services. Nevertheless, this must be clearly stated as a requirement and respected during each phase of secure architecture design. The OWASP also refers to this in its "Secure Product Design Cheat Sheet", Chapter "Security Focus Areas Component and Connections" ([reference](https://cheatsheetseries.owasp.org/cheatsheets/Secure_Product_Design_Cheat_Sheet.html)).

**CRA Requirement**: *(i) be designed, developed and produced to reduce the impact of an incident using appropriate exploitation mitigation mechanisms and techniques;*

This requirement results in a clean architecture, defense in depth, and clean coding (see also IEC 62443-3-2). This leads to a set of Secure Design Guidelines for architecture, design, development, such as:

- SOLID principles,
- TDD (Test-Driven Development),
- Secure by Design,
- CD/CI (Continuous Deployment/Continuous Integration).

These and many more explicitly stated rules and techniques must be considered to fulfill the CRA/IEC 62443-4-2. Each product development lifecycle should incorporate them anyway, but as the CRA requires, it is necessary to choose them and state them explicitly. This normally results in a customized product development handbook for each company.

## Cyber Resilience Act, Annex I, Section 2

The second section of Annex I to the CRA starts as follows: *Manufacturers of the products with digital elements shall:*

**CRA Requirement**: *(1) identify and document vulnerabilities and components contained in the product, including by drawing up a software bill of materials in a commonly used and machine-readable format covering at the very least the top-level dependencies of the product;*

Manufacturers should implement ongoing monitoring of the cybersecurity status of their entire supply chain to ensure the security of the components used in their products. A comprehensive Software Bill of Materials (SBOM) must be created, listing all libraries and external components used in the product's software, along with their version numbers. This SBOM should be readily accessible to users and conform to relevant standards such as ISO/IEC 5921:2021 (SPDX) or CycloneDX.

Integrating initiatives like the NTIA's Software Component Transparency Initiative ([reference](https://www.ntia.gov/page/software-bill-materials)) and the ECSO Supply Chain Management and Product Certification Composition ([reference](https://ecs-org.eu/activities/standardisation-certification-and-supply-chain-management/)) with ISO/IEC 27036 can help manufacturers develop a robust approach to managing SBOMs. These efforts collectively address information security risks in supplier relationships and enhance software supply chain transparency.

**CRA Requirement**: *(3) apply effective and regular tests and reviews of the security of the product with digital elements;*

Manufacturers should conduct periodic vulnerability assessments, focusing particularly on components that present the highest risk. During the development or maintenance of software components, automatic tests should be executed with each new commit, build, or version, preferably utilizing Continuous Integration/Continuous Deployment (CI/CD) techniques. Risk assessments should be re-evaluated whenever there are significant changes in any of the analyzed dimensions, such as the emergence of new threats, vulnerabilities, or a new product release.

To fulfill this requirement, manufacturers should consider implementing a combination of relevant standards and guidelines, customizing their approach to meet specific needs, industry requirements, and regulatory landscapes. Utilizing the strengths of various standards can help develop a more comprehensive security testing process during the development phase, such as adopting DevSecOps practices. This ensures that effective and regular tests and reviews are applied to the security of products with digital elements.

**CRA Requirement**: *(5) put in place and enforce a policy on coordinated vulnerability disclosure;*

While standards and initiatives such as EN ISO/IEC 29147:2020 contribute to the development and implementation of a coordinated vulnerability disclosure (CVD) policy, they do not comprehensively cover all aspects of enforcing such a policy or provide specific guidance tailored to different industries and product types.

To address this gap, manufacturers should consider implementing a combination of relevant standards, initiatives, and national/EU CVD policies. Additionally, reliance on CVD policies and procedures that align with industry best practices, such as NIST SP 800-61 Revision 2 ([reference](https://csrc.nist.gov/pubs/sp/800/61/r2/final)) and FIRST VRDX SIG ([reference](https://www.first.org/global/sigs/vrdx)), can also be beneficial. By drawing on the strengths of these standards and initiatives, manufacturers can develop a comprehensive and effective CVD policy that meets the requirement. This policy should detail the process for disclosing vulnerabilities in a coordinated manner, ensuring timely and consistent communication with all stakeholders involved.

**CRA Requirement**: *(6) take measures to facilitate the sharing of information about potential vulnerabilities in their product with digital elements as well as in third party components contained in that product, including by providing a contact address for the reporting of the vulnerabilities discovered in the product with digital elements;*

The company distributing a product or service should establish and prominently advertise a contact point specifically designated for collecting information related to vulnerabilities found in their products or services. If available, this contact point should be the company’s Product Security Incident Response Team (PSIRT).

The company should also inform relevant authorities, such as national CERTs/Computer Security Incident Response Teams (CSIRTs), about how they can be reached promptly for issues related to vulnerability handling. To meet this requirement, companies should consider implementing standards such as EN ISO/IEC 29147:2020 and collaborate closely with national CERTs/CSIRTs and the ENISA. It is also beneficial to follow the activities of the CSIRTs Network forum and the latest ENISA initiatives under the EU Cybersecurity Act umbrella. The CSIRTs Network, composed of CSIRTs appointed by EU Member States and CERT-EU, actively supports cooperation between CSIRTs and provides incident coordination support upon request, with the ENISA acting as a facilitator.

Additionally, companies should adopt policies and procedures that align with industry best practices, such as NIST SP 800-61 Revision 2 ([reference](https://csrc.nist.gov/pubs/sp/800/61/r2/final)) and the FIRST PSIRT Services Framework ([reference](https://www.first.org/standards/frameworks/psirts/psirt_services_framework_v1.1)). By building on the strengths of each standard and initiative, companies can create a comprehensive and effective process for sharing information about potential vulnerabilities and managing discovered vulnerabilities in their products and third-party components.

# Conclusion

In conclusion, our analysis confirms a strong alignment between the IEC 62443 standard and the Cyber Resilience Act (CRA). Though specific differences exist, our detailed examination has highlighted how these gaps can be effectively addressed. Looking ahead, we aim to provide future articles focused on guiding organizations on how to achieve certification according to the IEC 62443 standard while simultaneously fulfilling the requirements posed by the Cyber Resilience Act. This will equip organizations to navigate the evolving cybersecurity landscape with confidence and resilience.
