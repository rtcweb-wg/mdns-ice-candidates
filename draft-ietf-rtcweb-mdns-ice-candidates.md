---
title: Using Multicast DNS to protect privacy when exposing ICE candidates
abbrev: mdns-ice-candidates
docname: draft-ietf-rtcweb-mdns-ice-candidates-00
date: 2018-09-12
category: info

ipr: trust200902
area: General
workgroup: RTCWEB
keyword: Internet-Draft

stand_alone: yes
pi: [toc, sortrefs, symrefs]

author:
 -
    ins: Y. Fablet
    name: Youenn Fablet
    organization: Apple Inc.
    email: youenn@apple.com
 -
    ins: J. de Borst
    name: Jeroen de Borst
    organization: Google
    email: jeroendb@google.com
 -
    ins: J. Uberti
    name: Justin Uberti
    organization: Google
    email: juberti@google.com
 -
    ins: Q. Wang
    name: Qingsi Wang
    organization: Google
    email: qingsi@google.com

informative:
  RFC4122:
  RFC8445:
  RFC6763:
  ICESDP:
    target: https://tools.ietf.org/html/draft-ietf-mmusic-ice-sip-sdp
    title: Session Description Protocol (SDP) Offer/Answer procedures for Interactive Connectivity Establishment (ICE)
    author:
      ins: M. Petit-Huguenin
      ins: S. Nandakumar
      ins: A. Keranen
    date: 2018-04-01
  IPHandling:
    target: https://tools.ietf.org/html/draft-ietf-rtcweb-ip-handling
    title:  WebRTC IP Address Handling Requirements
    author:
      ins: J. Uberti
      ins: G. Shieh
    date: 2018-04-18
  IPLeak:
    target: https://ipleak.net
    title:  IP/DNS Detect
  WebRTCSpec:
    target: https://w3c.github.io/webrtc-pc/
    title:  The WebRTC specification
    author:
      ins: A. Bergkvist
      ins: D. Burnett
      ins: C. Jennings
      ins: A. Narayanan
      ins: B. Aboba
      ins: T. Brandstetter
      ins: J.I. Bruaroey

--- abstract

WebRTC applications rely on ICE candidates to enable peer-to-peer connections between clients in as many network configurations as possible.
To maximize the probability to create a direct peer-to-peer connection, client private IP addresses are often exposed without user consent.
This is currently used as a way to track users.
This document describes a way to share IP addresses with other clients while preserving client privacy.
This is achieved by obfuscating IP addresses using dynamically generated names resolvable through Multicast DNS {{RFC6763}}.

--- middle

Introduction {#problems}
============

As detailed in {{IPHandling}}, exposing client private IP addresses allows maximizing the probability to successfully create a connection between two clients.
This information is also used by many web sites as a way to fingerprint and identify users without their consent.

The first approach exposes client private IP addresses by default, as can be seen from websites such as {{IPLeak}}.
The second approach implemented in the WebKit engine enforces the following policy:

1. By default, use mode 3 as defined in {{IPHandling}}: any host ICE candidate is filtered out.

2. Use mode 2 as defined in {{IPHandling}} if there is an explicit user action to trust the web site: host ICE candidates are exposed to the web site based on the use of navigator.mediaDevices.getUserMedia, which typically prompts the user to grant or deny access to cameras/microphones.

The second approach supports most common audio/video conference applications
but leads to failing or suboptimal connections for applications relying solely on data channel.
This is particularly an issue on unmanaged networks, typically home or small offices where NAT loopback might not be supported.

To overcome the shortcomings of the above two approaches, this document proposes to register dynamically generated names using Multicast DNS when gathering ICE candidates.
These dynamically generated names are used to replace private IP addresses in host ICE candidates.
Only clients that can resolve these dynamically generated names using Multicast DNS will get access to the actual client IP address.

Privacy Concerns {#concerns}
============

The gathering of ICE candidates without user consent is a well-known fingerprinting technique to track users.
This is particularly a concern when users are connected through a NAT which is a usual configuration.
In such a case, knowing both the private IP address and the public IP address will usually identify uniquely the user device.
Additionally, Internet web sites can more easily attack intranet web sites when knowing the intranet IP address range.

A successful WebRTC connection between two peers is also a potential thread to user privacy.
When a WebRTC connection latency is close to zero, the probability is high that the two peers are running on the same device.
Browsers often isolate contexts one from the other.
Private browsing mode contexts usually do not share any information with regular browsing contexts.
The WebKit engine isolates third-party iframes in various ways (cookies, ITP) to prevent user tracking.
Enabling a web application to determine that two contexts run in the same device would defeat some of the protections provided by modern browsers.

Principle {#principle}
============

This section uses the concept of ICE agent as define in {{RFC8445}}.
In the remainder of the document, it is assumed that each browser execution context has its own ICE agent.

ICE Candidate Gathering {#gathering}
----------------------------

For any host ICE candidate gathered by a browsing context as part of {{RFC8445}} section 5.1.1, obfuscation of the candidate is done as follows:

1. Check whether the context ICE agent registered a name resolving to the ICE host candidate IP address.

2. If the ICE agent registered the name, replace the IP address of the ICE host candidate with the name with ".local" appended to it. Expose the candidate and abort these steps.

3. Generate a random unique name, typically a version 4 UUID as defined in {{RFC4122}}.

4. Register the unique name using Multicast DNS.

5. If registering of the unique name fails, abort these steps. The candidate is not exposed.

6. Store the name and its related IP address in the ICE agent for future reuse.

7. Replace the IP address of the ICE host candidate with the name with ".local" appended to it. Expose the candidate.

ICE Candidate Processing {#processing}
----------------------------

For any remote host ICE candidate received by the ICE agent, the following procedure is used:

1. If the connection-address field value of the ICE candidate does not finish by ".local", process the candidate as defined in {{RFC8445}}.

2. Otherwise, remove the ".local" suffix to the value and resolve it using Multicast DNS.

3. If it resolves to an IP address, replace the value of the ICE host candidate by the resolved IP address and continue processing of the candidate.

4. Otherwise, ignore the candidate.

Multicast DNS resolution might end up retrieving both an IPv4 and IPv6 address.
In that case, the IPv6 address may be used preferably to the IPv4 address.

Privacy Guidelines {#guidelines}
============

APIs leaking IP addresses
----------------------------

When there is no user consent, the following filtering should be done to prevent private IP address leakage:

1. host ICE candidates with an IP address are not exposed as ICE candidate events.

2. Server reflexive ICE candidate raddr field is set to 0.0.0.0 and rport to 0.

3. SDP does not expose any a=candidate line corresponding to a host ICE candidate which contains an IP address.

4. RTCIceCandidateStats dictionaries exposed to web pages do not contain any 'ip' member if related to a host ICE candidate.

Generated names reuse
----------------------------

Dynamically generated names can be used to track users if used too often.
Conversely, registering too many names will also generate useless processing.
The proposed rule is to create and register a new generated name for a given IP address on a per execution context.

Specific execution contexts
----------------------------

Privacy might also be breached if two execution contexts can identify whether they are run in the same device based on a successful peer-to-peer connection.
The proposed rule is to not register any name using Multicast DNS for any ICE agent belonging to:

1. A third-party browser execution context, i.e. a context that is not same origin as the top level execution context.

2. A private browsing execution context.

Specification Requirements {#requirements}
============

The proposal relies on identifying and resolving any Multicast DNS based ICE candidates as part of adding/processing a remote candidate.
{{ICESDP}} section 4.1 could be updated to explicitly allow Multicast DNS names in the connection-address field.

The proposal relies on adding the ability to register Multicast DNS names at ICE gathering time.
This could be described in {{ICESDP}} and/or {{WebRTCSpec}}.

The proposal allows updating {{IPHandling}} so that mode 2 is not the mode used by default when user consent is not required.
Instead, the default mode could be defined as mode 3 with Multicast DNS based ICE candidates.
