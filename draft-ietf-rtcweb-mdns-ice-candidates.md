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
  RFC6762:
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

WebRTC applications collect ICE candidates as part of the process of creating
peer-to-peer connections. To maximize the probability of a direct peer-to-peer
connection, client private IP addresses are included in this candidate
collection. However, disclosure of these addresses has privacy implications.
This document describes a way to share local IP addresses with other clients
while preserving client privacy. This is achieved by obfuscating IP addresses
with dynamically generated Multicast DNS {{RFC6762}} names.

--- middle

Introduction {#problems}
============

As detailed in {{IPHandling}}, exposing client private IP addresses by default
maximizes the probability of successfully creating direct peer-to-peer
connection between two clients, but creates a significant surface for user
fingerprinting. {{IPHandling}} recognizes this issue, but also admits that there
is no current solution to this problem; implementations that choose to use
Mode 3 to address the privacy concerns often suffer from failing or suboptimal
connections in WebRTC applications. This is particularly an issue on unmanaged
networks, typically homes or small offices, where NAT loopback may not be
supported.

This document proposes an overall solution to this problem by registering
ephemeral Multicast DNS names for each local private IP address, and then
providing those names, rather than the IP addresses, to the web application
when it gathers ICE candidates. WebRTC implementations resolve these names
to IP addresses and perform ICE processing as usual, but the actual IP addresses
are not exposed to the web application.

Principle {#principle}
============

This section uses the concept of ICE agent as define in {{RFC8445}}.
In the remainder of the document, it is assumed that each browser execution context has its own ICE agent.

ICE Candidate Gathering {#gathering}
----------------------------

For any host candidate gathered by an ICE agent as part of {{RFC8445}} section 5.1.1, obfuscation of the candidate is done as follows:

1. Check whether the ICE agent has a usable registered mDNS hostname resolving to the ICE host candidate's IP address. If one exists, skip ahead to Step 6.

2. If there is a registered hostname, replace the IP address of the ICE host candidate with the hostname. Expose the candidate and abort these steps.

3. Generate a unique mDNS hostname. The unique name MUST consist of a version 4 UUID as defined in {{RFC4122}}, followed by ".local".

4. Register the candidate's mDNS hostname using Multicast DNS.

5. If registering of the mDNS hostname fails, abort these steps. The candidate is not exposed.

6. Store the mDNS hostname and its related IP address in the ICE agent for future reuse.

7. Replace the IP address of the ICE host candidate with its mDNS hostname. Expose the candidate.

An ICE agent can implement this procedure in any way so long as it produces equivalent results to this procedure.

An implementation may for instance pre-register mDNS hostnames by executing steps 3 to 5 and prepopulate an ICE agent accordingly.
By doing so, only steps 1 and 2 of the above procedure will be executed at the time of gathering candidates.

An implementation may also detect that mDNS is not supported by the available network interfaces.
The ICE agent may skip step 3 and 4 and directly decide to not expose the host candidate.

This procedure ensures that a mDNS name is used to replace only one IP address.
Specifically an ICE agent using an interface with both IPv4 and IPv6 addresses MUST expose a different mDNS name for each address.

ICE Candidate Processing {#processing}
----------------------------

For any remote host ICE candidate received by the ICE agent, the following procedure is used:

1. If the connection-address field value of the ICE candidate does not end with ".local" or if the value contains more than one ".", then process the candidate as defined in {{RFC8445}}.

2. Otherwise, use the value and resolve it using Multicast DNS.

3. If it resolves to an IP address, replace the value of the ICE host candidate by the resolved IP address and continue processing of the candidate.

4. Otherwise, ignore the candidate.

An ICE agent may use a hostname resolver that transparently supports both Multicast and Unicast DNS.
In this case the resolution of a ".local" name may happen through Unicast DNS, see {{RFC6762}} section 3.

An ICE agent that supports mDNS candidates MUST support the situation where the hostname resolution results in more than one IP address.
In this case, the ICE agent MUST take exactly one of the resolved IP addresses and ignore the others.
The ICE agent SHOULD, if available, use the first IPv6 address resolved, otherwise the first IPv4 address.

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

It is important that use of registered mDNS hostnames is limited in time and/or scope. Indefinitely reusing the same mDNS hostname candidate would provide applications an even more reliable tracking mechanism than the private IP addresses that this specification is designed to hide. The use of registered mDNS hostnames SHOULD be scoped by origin, and have the lifetime of the page.

If the generated mDNS hostname candidate does not follow the pattern described, the exposed candidate might be used for fingerprinting.

If there are multiple host candidates with different IP addresses, IPv4 and/or IPv6, each results in a separate mDNS hostname candidate. The number of mDNS hostname candidates can provide a fingerprinting dimension. If so desired an ICE agent MAY expose additional mDNS hostname candidates that are not registered.

Specific execution contexts
----------------------------

As noted in {{IPHandling}}, privacy may be breached if a web application running
in two browser contexts can determine whether it is running on the same device.
While the approach in this document prevents the application from directly
comparing local private IP addresses, a successful local WebRTC connection
can also present a threat to user privacy. Specifically, when the latency of a
WebRTC connection latency is close to zero, the probability is high that the
two peers are running on the same device.

To avoid this issue, browsers SHOULD NOT register Multicast DNS names for
WebRTC applications running in a third-party browser execution context (i.e., a
context that has a different origin than the top-level execution context), or a
private browser execution context.

Specification Requirements {#requirements}
============

The proposal relies on identifying and resolving any Multicast DNS based ICE candidates as part of adding/processing a remote candidate.
{{ICESDP}} section 4.1 could be updated to explicitly allow Multicast DNS names in the connection-address field.

The proposal relies on adding the ability to register Multicast DNS names at ICE gathering time.
This could be described in {{ICESDP}} and/or {{WebRTCSpec}}.

The proposal allows updating {{IPHandling}} so that mode 2 is not the mode used by default when user consent is not required.
Instead, the default mode could be defined as mode 3 with Multicast DNS based ICE candidates.
