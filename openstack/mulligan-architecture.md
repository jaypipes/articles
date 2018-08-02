This is the third and final part of a three-post series describing Project
Mulligan, the OpenStack Redo. If you missed the [first part](mulligan.md) go
read it. It is about changes I'd make to the community and mission of OpenStack
had I my way with a theoretical reboot of the project.

In this part, I'll be discussing what I'd change about the **architecture**, **APIs** and
**technology choices** of OpenStack in the new world of Project Mulligan.

## Redoing the architecture

There are three areas of "software system architecture" that I'd like to
discuss in relation to OpenStack and Project Mulligan:

* **component layout**: the topology of the system's components and how
  components communicate with each other
* **dependencies**: the technology choices a project makes
  regarding dependencies and implementation
* **extensibility**: the degree to which a project tolerates flexibility of
  underlying implementation

### OpenStack's architecture

OpenStack has no coherent architecture. Period.

Within OpenStack, different projects are designed in very different ways, with
the individual contributors on a project team making decisions about how that
project is structured, what technologies should be dependencies, and how
opinionated the implementation should be (or conversely, how extensible it
should be made)

Some projects, like Swift, are highly opinionated in their implementation and
design. Other projects, like Neutron, go out of their way to enable
extensibility and avoid making any sort of choice when it comes to underlying
implementation or hardware support.

Taking a further look at Swift, we see it is designed using a top-level router
topology with various server components fulfilling the needs of different parts
of the request (object storage/retrieval, container and account metadata
lookup, etc). There's no message queue, no centralized database (Swift
replicates SQLite database files from one container/account server to another)
and the object servers require filesystems with xattr support in order to do
their work. Swift's authors didn't build extensibility into how their object
metadata storage worked. They just said "hey, you need a filesystem with xattr
support".  Similarly, the authors didn't go out of their way to allow
PostgreSQL to be used for container and account data. Instead, they chose to
replicate SQLite database files and have stuck with that design choice since
day one.

Looking at Neutron, we see the opposite of Swift. From a component layout
perspective, we see a top-level API server that communicates via a message bus
to one or more agent services. There is a centralized database that stores
object model information but much of Neutron's design is predicated on a plugin
system that does the actual work of wiring up an L2 network. Layer 3 networking
in Neutron always felt like it was bolted on and not really part of Neutron's
natural worldview. [1]

Nearly everything about Neutron is extensible. Everything is a driver or plugin
or API extension. While there is a top-level API server, in many deployments it
does little more than forward requests on to a vendor-specific driver that does
"the real work", with the driver (hopefully) saving some information about the
work it did in Neutron's database.

Still other projects, like Nova, have dependencies on traditional databases and
brokered message queues, a component layout that was designed to address a
specific scale problem but causes many other problems and a confusing blend of
highly extensible, sometimes extensible, and extensible-in-name-only approaches
to underlying technology choices.

Nova's component layout features a top-level API server, similar to Neutron and
Swift. From there, however, there's virtually nothing the same about Nova. Nova
uses a system of "cells" which are designed as scaling domains for the
technology underpinning Nova's component communications: a brokered message
queue for communicating between various system services and a traditional
relational database system for storing and retrieving state.

Take old skool RPC with all the operational pitfalls and headaches of using
RabbitMQ and AMQP. Then tack on eight years of abusing the database for more
than relational data and horrible database schema inefficiencies. Finally,
overcomplicate both database connectivity and data migration because of a
couple operators' poor choices and inexperienced developers early in
the development of Nova. And you've got the ball of spaghetti that Nova's
component layout and technology choice currently entails.

As for Nova's extensibility, it varies. There is a virt driver interface that
allows different hypervisors (and Ironic for baremetal) to perform the
on-compute-node actions needed to start, stop, pause and terminate a VM
instance. There are some out-of-tree virt drivers that ostensibly try to keep
up with the virt driver interface, but it isn't technically public so it's
mostly a "use with caution and good luck with that" affair. The scheduler
component in Nova used to be ludicrously extensible, with support for all sorts
of out-of-tree filters, weighers, even whole replacement scheduler drivers.
That sucked, since there was no way to change anything without breaking the
world. So now, we've removed a good deal of the extensibility in the scheduler
in order to return some level of sanity there.

Similarly, we used to give operators the ability to whole-hog replace entire
subsystems like the networking driver with an out-of-tree driver of their own
making. We no longer allow this kind of madness. Neutron is the only supported
networking driver at this time. Same for volume management. Cinder is the one
and only supported volume manager.

### Project Mulligan's architecture

Throw everything out and start over.

Screw extensibility. Seriously, screw it.

## Redoing the API

A project's API is its primary user interface. As such, its API is critically
important to both the success of the project as well as the project's perceived
quality and ease of use.

If I could change OpenStack's API, what would I change for Project Mulligan?

### OpenStack's API

OpenStack has no coherent API. Period.

Each OpenStack project has its own REST API, with the valiant API working group
trying (in vain) to keep an eye out for consistency and issuing guidelines for
projects to (fail to) use.

The gripes I have with the various project REST APIs are virtually endless, so
I'll just stick with a few major grievances here before talking up the wonders
that Project Mulligan will bring to bear on the world of APIs.

### Project Mulligan's API

gRPC only. Versioned from the get-go with a sane set of clear rules for
describing the evolution of the request and response payloads.

No more inane and endless debates about "proper" REST-ness or HATEOS or which
HTTP code thought up in the 1990s is more appropriate for describing a
particular application failure.

No more trying to shoehorn a control plane API into a data plane API or vice
versa.

## Conclusion



## Footnotes

[1] This makes perfect sense considering the origins of the Neutron project,
which was founded by folks from Nicira which ended up as VMWare's NSX
technology -- an L2-centric software defined networking technology. FYI, some
of those same people are the driving force behind the Cilium project that is
now showing promise in the container world. Isn't it great to be able to walk
away from your original ideas (granted, after a nice hiatus) and totally
re-start without any of the baggage of the original stuff you wrote? I agree,
which is why Project Mulligan will be a resounding success.
