This is the second and final part of series describing Project Mulligan, the
OpenStack Redo. If you missed the [first part](mulligan.md) go read it. It is
about changes I'd make to the community and mission of OpenStack had I my way
with a theoretical reboot of the project.

In this part, I'll be discussing what I'd change about the **architecture**, **APIs** and
**technology choices** of OpenStack in the new world of Project Mulligan.

## A word on programming language

For those of you frothing like hyenas waiting to get into a religious battle
over programming languages, you will need to put your tongues back into your
skulls. I'm afraid you're going to be supremely disappointed by this post,
since I quite deliberately did not want to get into a Golang vs. Python vs.
Rust vs. Brainfuck debate.

Might as well get used to that feeling of disappointment now before going
further. Or, whatever, just stop reading if that's what you were hoping for.

For the record, shitty software can be written in any programming language.
Likewise, excellent software can be written in most programming languages. I
personally have a love/hate relationship with all three programming languages
that I code with on a weekly basis (Python, Golang, C++).

Regardless of which programming language might be chosen for Project Mulligan,
I doubt this love/hate relationship would change. At the end of the day, what
is most important is the communication mechanisms between components in a
distributed system and how various data is persisted. Programming language
matters in neither of those thing. There are bindings in every programming
language for communicating over HTTP and for persisting and retrieving data
from various purpose-build data stores.

## Redoing the architecture

There are four areas of system design that I'd like to discuss in relation to
OpenStack and Project Mulligan:

* **component layout**: the topology of the system's components and how
  components communicate with each other
* **dependencies**: the technology choices a project makes regarding
  dependencies and implementation
* **pluggability**: the degree to which a project tolerates flexibility of
  underlying implementation
* **extensibility**: the degree to which a project enables being used in ways
  that the project was not originally intended

Before getting to what I'd like to see in Project Mulligan's architecture,
let's first discuss the architecture of OpenStack v1.

### OpenStack's architecture

OpenStack has no coherent architecture. Period.

Within OpenStack, different projects are designed in different ways, with the
individual contributors on a project team making decisions about how that
project is structured, what technologies should be dependencies, and how
opinionated the implementation should be (or conversely, how pluggable it
should be made)

Some projects, like Swift, are highly opinionated in their implementation and
design. Other projects, like Neutron, go out of their way to enable
extensibility and avoid making any sort of choice when it comes to underlying
implementation or hardware support.

#### Swift

Taking a further look at Swift, we see it is designed using a router-like
topology with a top-level Proxy server routing incoming client requests along
to various stand-alone daemon components fulfilling the needs of different
parts of the request (object storage/retrieval, container and account metadata
lookup, reaper and auditor workers, etc).

From a technology dependency point of view, Swift has very few.

There's no message queue. Instead, the (minimal) communication between certain
Swift internal service daemons is done via HTTP calls, and most Swift service
daemons push incoming work requests on internal simple in-memory queues for
processing.

There is no centralized database either. Swift replicates SQLite database files
from one container/account server to another. These SQLite database files are
replicated between other nodes in the Swift system via shellout calls to the
`rsync` command-line tool,

Finally, the object servers require filesystems with xattr support in order to
do their work. While Swift can work with the OpenStack Identity service
(Keystone), it has no interdependency with any OpenStack service nor does it
utilitize any shared OpenStack library code (the OpenStack Oslo project).

Swift's authors built some minor pluggability into how some of their Python
backend classes were written, however pluggability is mostly not a priority in
Swift. I'm not really aware of anyone implementing out-of-tree
*implementations* for any of the Swift server code. Perhaps the Swift authors
might comment on this blog entry and let me know if that is incorrect or
outdated information.

Swift is not extensible in the sense that the core Swift software does not
enable the scope of Swift's API to extend beyond its core mission of being a
highly available distributed object storage system.

[Swift's API](https://developer.openstack.org/api-ref/object-store/) is a pure
data plane API. It is not a control plane API, meaning its API is not intended
to perform execution of actions against some controllable resources. Instead,
Swift's API is all about writing and reading data from one or more objects and
defining/managing the containers/accounts associated with those objects.

#### Neutron

Looking at Neutron, we see the opposite of Swift. From a component layout
perspective, we see a top-level API server that issues RPC calls to a set of
agent workers via a traditional brokered message bus.

There is a centralized database that stores object model information, however
much of Neutron's design is predicated on a plugin system that does the actual
work of wiring up an L2 network. Layer 3 networking in Neutron always felt like
it was bolted on and not really part of Neutron's natural worldview. [1]

Neutron's list of dependencies is broad and is influenced by the hardware and
vendor technology a deployer chooses for actually configuring networks and
ports. Its use of the common OpenStack Oslo Python libraries is
[extensive](https://github.com/openstack/neutron/blob/master/requirements.txt#L27-L43),
as its dependency on a raft of other Python libraries. It communicates directly
(and therefore has a direct relationship) with the OpenStack Nova and Designate
projects, and it depends on the OpenStack Keystone project for identity,
authentication and authorization information.

Nearly everything about Neutron is both pluggable and extensible. Everything
seems to be a driver or plugin or API extension [2]. While there is a top-level
API server, in many deployments it does little more than forward requests on to
a proprietary vendor driver that does "the real work", with the driver or
plugin (hopefully [3]) saving some information about the work it did in
Neutron's database.

The "modular L2 plugin" (ML2) system is a framework for allowing mechanism
drivers that live outside of Neutron's source tree to perform the work of
creating and plugging layer-2 ports, networks, and subnets. Within the Neutron
source tree, there are some base [mechanism
drivers](https://github.com/openstack/neutron/tree/master/neutron/plugins/ml2/drivers)
that enable software-defined networking using various technologies like Linux
bridges or OpenVSwitch.

This means that every vendor offering software-defined networking functionality
has its own ML2 plugin (or more than one plugin) along with separate drivers
for its own proprietary technology that essentially translate the Neutron
worldview into the vendor's proprietary system's worldview (and back again).
And example of this is the Cisco Neutron ML2 plugin which has [mechanism drivers](https://github.com/openstack/networking-cisco/tree/master/networking_cisco/ml2_drivers)
that speak the various Cisco-flavored networking.

One nice relatively recent development in Neutron is the separation of many
"common" API constructs and machinery into the
[neutron-lib](https://github.com/openstack/neutron-lib) repository. This at
least goes part way towards reducing some duplicative code and allowing out of
tree source repositories to import a much smaller footprint than the entire
Neutron source tree.

On the topic of extensibility in Neutron's API, I'd like to point to Neutron's
[own documentation on its API extensions](https://developer.openstack.org/api-ref/network/v2/#id5), which
states the following:

    The purpose of Networking API v2.0 extensions is to:

    - Introduce new features in the API without requiring a version change.
    - Introduce vendor-specific niche functionality.
    - Act as a proving ground for experimental functionalities that might be
      included in a future version of the API.

I'll discuss a bit more in the section below on Project Mulligan's API, but I'm
not a fan of API extensibility as seen in Neutron. It essentially encourages a
Wild West mentality where there is no consistency between API resources, no
coherent connection between various resources exposed by the API, and a
proliferation of vendor-centric implementation details leaking out of the API
itself. Neutron's API is not the only OpenStack project API to succumb to these
problems, though. Not by a long shot.

#### Nova

Still other projects, like the OpenStack Nova project, have dependencies on
traditional databases and brokered message queues, a component layout that was
designed to address a specific scale problem but causes many other problems and
a confusing blend of highly extensible, sometimes extensible, and
extensible-in-name-only approaches to underlying technology choices.

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

For Project Mulligan, we'll be throwing out pretty much everything and starting
over. So, out with the chaos and inconsistency. In with sensibility, simplicity
and far fewer plug and extension points.

Now that Project Mulligan's scope has been healthily trimmed, we can focus on
only the components and requirements for a simple machine provisioning system.

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

[2] Even the comically-named "[core extensions](https://github.com/openstack/neutron/tree/master/neutron/core_extensions)".
*sigh*.

[3] The base Neutron plugin actually allows the plugin to not use Neutron's
database for state persistence, which is basically the Neutron authors
relenting to vendor pressure to just have Neutron be a very thin shim over some
proprietary network administration technology -- like [Juniper Contrail](https://github.com/Juniper/contrail-neutron-plugin).
