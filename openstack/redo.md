# Redoing OpenStack

Jess Frazelle's [tweet](https://twitter.com/jessfraz/status/1023550446026276864) this morning got me thinking. [1]

![Jess Frazelle's original tweet](images/jesstweet.png "Jess Frazelle's original tweet that got me thinking")

What if I could go back and undo basically the last eight years and remake
OpenStack (whatever "OpenStack" has come to entail)? What if we could have a
big do-over?

In this article, I will be describing "Project Mulligan", the OpenStack Redo.
This is a highly opinionated reflection on what I personally would change about
the world I've lived in for nearly a decade.

I'm bound to offend lots of people along the way in both the OpenStack and
Kubernetes communities. Sorry in advance. Try not to take things personally --
in many cases I'm referring to myself as much as anyone else and so feel free
to join me on this self-deprecating journey.

## Background

I've been involved in the OpenStack community for more than eight years now.
I've worked for five different companies on OpenStack and cloud-related
projects, with a focus on compute infrastructure (as opposed to network or
storage infrastructure). I've been on the [OpenStack Technical Committee](https://www.openstack.org/foundation/tech-committee/), served
as a Project Team Lead (PTL) and am on a number of core reviewer teams.

When it comes to technical knowledge, I consider myself a journeyman. I'm never
the smartest person in the room, but I'm not afraid to share an opinion that
comes from a couple decades of programming experience.

I've also managed community relations for an open source company, given and
listened to lots of talks at conferences, and met a whole bunch of really smart
and talented individuals in my time in the community.

All this to say that I feel I do have the required background and knowledge to
at least put forth a coherent vision for Project Mulligan and that I am as much
responsible as anyone else for the mess that OpenStack has become.

## Redoing the mission

When OpenStack began, we dreamt big. The mission of OpenStack was big, bold and
screamed of self-confidence. We wanted to create **an open source cloud
operating system**.

The #1 goal in those days was expansion. Specifically, expansion of **user
footprint** and **industry mindshare**. It was all about quantity versus
quality.

As time rolled on, the mission got wordier, but remained as massive and vague
as "cloud operating system" ever was. In 2013, the mission looked like this:

> to produce the ubiquitous Open Source Cloud Computing platform that will meet the needs of public and private clouds regardless of size, by being simple to implement and massively scalable.

See the word "ubiquitous" in there? That pretty much sums up what OpenStack's
mission has been since the beginning: get installed in as many places as
possible.

While "simple to implement" and "massively scalable" were aspirational, neither
were realistic and both were subject to interpretation (though I think it's
safe to say OpenStack has never been "simple to implement").

Today, the mission continues to be ludicrously broad, vague, and open-ended, to
the point that it's pretty much impossible to tell what OpenStack ***is*** by
reading the mission:

> to produce a ubiquitous Open Source Cloud Computing platform that is easy to use, simple to implement, interoperable between deployments, works well at all scales, and meets the needs of users and operators of both public and private clouds.

"Meets the needs of users and operators of both public and private clouds" is
about as immeasurable of a thing as I can think of. Again, it's aspirational,
but so broad as to be meaningless outside of any abstract discussion.

One thing I've learned in my work life over the last twenty years is that if
I try and do too many things at once, I end up doing a shit job at all of
them.

Instead, I've found that focusing on a single thing allows me to refine my
effort into something with clear purpose and clean design.

Project Mulligan is getting a new mission in life; one that is purpose-driven
(though not like that Christian cult book crap).

The mission of Project Mulligan is to:

> demystify the process of provisioning compute infrastructure

It's aspirational but not open-ended; singularly focused on the compute
provisioning process.

Project Mulligan isn't trying to be a "cloud operating system". Heck, it
doesn't even care what "cloud" *is*. Or isn't.  Or might be in the future for a
DevOpsSysAdminUserator.

"OK, Jay, but what really *IS* 'compute infrastructure'?"

I'm glad you asked, because that's a perfect segue into a discussion about the
scope of Project Mulligan.

## Redoing the scope

Defining the scope of OpenStack is like attempting to bathe a mud-soaked cat in
a bubble bath -- a slippery affair that only ends up getting the bather muddy
and angering the cat.

The scope of OpenStack escapes definition due to the sheer expanse of
OpenStack's mission.

Now that we've slashed Project Mulligan's mission like Freddy Krueger on
holiday in a paper factory, defining the scope of Project Mulligan is a much
easier task.

We're going to start with a relatively tiny scope (compared to OpenStack v1's),
and if the demand is there, we'll expand it later. Maybe. If I'm offered enough
chocolate chip cookies.

The scope of Project Mulligan is:

> singular baremetal and virtual machine resource provisioning

I've chosen each word in the above scope carefully.

> singular

"singular" was chosen to make it clear that Project Mulligan doesn't attempt to
provision multiple identical things in the same operation.

> baremetal and virtual machine

"baremetal and virtual machine" was selected to disambiguate Project Mulligan's
target deployment unit. It's not containers. It's not applications. It's not
lambda functions. It's not unikernels or ACIs or OCIs or OVFs or debs or RPMs
or Helm Charts or any other type of package.

Project Mulligan's target deployment unit is a **machine** -- either baremetal
or virtual.

A machine is what is required to run some code on. Containers, cgroups,
namespaces, applications, packages, and yes, serverless/lambda functions
require a machine to run on. That's what Project Mulligan targets: the machine.

> resource

The word "resource" was used for good reason: a resource is something that is
used or consumed by some other system. How those systems describe, request,
claim and ultimately consume resources is such a core concept in any software
system that extreme care must taken to ensure that the mechanics of resource
management are done *right*, and done in a way that doesn't hinder the creation
of higher-level systems and platforms that utilize resource and usage
information.

I go into a lot of detail below in the section on "Redoing the architecture"
about resource management and why it's important to be part of Project
Mulligan.

> provisioning

At its core, the purpose of Project Mulligan is to demystify the arcane and
hideously complex process inherent in provisioning machines. Provisioning
involves the setup and activation of the machine. It does not involve
operational support of the machine, nor does it involve moving the machine,
powering it down, restarting it, pausing it, or throwing it a birthday party.

The *only* things that are important to be in Project Mulligan's scope are the
items that enable its mission and that cannot be fulfilled by other existing
libraries or systems in a coherent way.

I imagine at this point, I've offended more than three quarters of the universe
by not including in Project Mulligan's scope any of the following:

* Storage
* Networking
* Containers
* Security
* Orchestration
* Filesystems
* Deployment
* Configuration management
* AmigaOS

Are these things important? Yep. Well, OK, maybe not AmigaOS. Do I want them in
Project Mulligan's mission statement or scope? No. No, I don't.

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
natural worldview. [2]

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

### Project Mulligan's API

No more REST.

gRPC only.

## Conclusion



## Footnotes

[1] Yes, I'm aware Jess Frazelle wasn't actually asking the OpenStack community
what the next version of OpenStack would look like. Rather, she was opining
that some negative aspects of the OpenStack ecosystem and approach have snuck
into Kubernetes. Still, I think it's an interesting question to ponder,
regardless.

[2] This makes perfect sense considering the origins of the Neutron project,
which was founded by folks from Nicira which ended up as VMWare's NSX
technology -- an L2-centric software defined networking technology. FYI, some
of those same people are the driving force behind the Cilium project that is
now showing promise in the container world. Isn't it great to be able to walk
away from your original ideas (granted, after a nice hiatus) and totally
re-start without any of the baggage of the original stuff you wrote? I agree,
which is why Project Mulligan will be a resounding success.
