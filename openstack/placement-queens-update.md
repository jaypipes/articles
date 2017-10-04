# An Update on the Placement API and Scheduler plans for Queens

This article provides an update on the progress that has been made by the
OpenStack contributor community over the last few releases in the area of the
Nova scheduler and Placement services. I'll also outline the blueprints we are
tackling in the Queens release cycle and provide a roadmap for the big ticket
items we want to complete in the next few releases.

1. [Recap of previous release accomplishments](#recap-of-previous-release-accomplishments)
1. [Priorities for Queens release](#priorities-for-queens)
    1. [Properly handling move operations](#properly-handling-move-operations)
    1. [Alternate host lists and in-cell retries](#alternate-host-lists-and-in-cell-retries)
    1. [Nested resource providers](#nested-resource-providers)
1. [Other Queens stuff](#other-items-to-try-in-queens)
    1. [Trait-flavor wiring](#completion-of-trait-flavor-wiring)
    1. [Placement API HTTP cache headers](#cache-header-handling-in-placement-api)
    1. [Placement API POST multiple allocations](#supporting-post-multiple-allocations-in-placement-api)
    1. [Rudimentary vGPU support](#rudimentary-vgpu-support)
1. [Beyond Queens](#beyond-queens)
    1. [Generic device manager](#a-generic-device-manager)
    1. [NUMA support](#numa-support)
    1. [Shared resource providers](#shared-resource-providers)

## Recap of previous release accomplishments

Recall that the Placement API was published as a separate API endpoint in the
Newton release of OpenStack.

The [Placement API](https://developer.openstack.org/api-ref/placement/) exposes
data used in tracking inventory, resource consumption, grouping and sharing of
resources, and string capability tags that we call "traits".

Since then, the team has been steadily improving the API and integrating it
further into Nova. The Newton release focused mainly on getting the
`nova-compute` workers to **properly inventory** local (to the compute node)
resources and send those inventory records to the Placement API.

In Ocata, we began the integration of the `nova-scheduler` service with the
Placement API. We modified the scheduler to make use of the Placement API in
**filtering compute nodes** that met some basic resource requests. We also
added a mechanism, called [aggregates](https://developer.openstack.org/api-ref/placement/#resource-provider-aggregates),
for grouping providers of resources.

In the Pike release we focused on moving the location of where we [**claim
resources**](http://specs.openstack.org/openstack/nova-specs/specs/pike/implemented/placement-claims.html)
from the `nova-compute` worker to the `nova-scheduler` service. The
reason for this focus was two-fold: performance/scale and alignment with the
Cells V2 architecture. I cover the details of this in the section below
called "[Alternate host lists and in-cell retries](#alternate-host-lists-and-in-cell-retries)".

## Priorities for Queens

At the Denver Project Team Gathering, the Nova contributor team
[resolved](https://etherpad.openstack.org/p/nova-ptg-queens-placement) to work
on three primary areas in the scheduler and resource placement functional
areas:

* Properly handling move operations
* Alternate hosts and retry operations in cells
* Nested resource providers

It should be noted that we understand that there are many, many additional
feature requests in this area -- some having been on our radar for years. We
recognize that it can be frustrating for operators and potential users to see
some longstanding issues and items not receieve priority for Queens. However,
there is only so much review bandwidth that the core team realistically has,
and choices do need to be made. We welcome discussion of those choices both at
the PTG and on the mailing list.

It should also be noted that while there are only three priority workstreams
for the scheduler and resource placement area in Queens, that does **NOT** mean
that no other proposed items will be reviewed or make progress. It simply means
that the core teams' review focus will be on patch sets that further the effort
in these areas.

### Properly handling move operations

The first priority effort we're tackling in Queens is cleaning up and fully
covering the functional test coverage of move operations -- migrate, rebuild,
resize, evacuate, unshelve, etc -- in relation to the placement API.

In the waning days of the Pike release, Balasz Gibizer, Dan Smith and Matt
Riedemann identified a number of issues regarding how resources were being
tracked (or not) in the Placement API during the various move operations
supported by Nova. Note that in the Pike release, we began claiming resources
in the `nova-scheduler` service. We clearly needed to do this claim process for
move operations as well. The initial solution we came up with creating a sort
of "doubled-up allocation" for the instance during a move operation, with
resources from both the source and destination host being consumed by the
instance in a single set of allocation records. This worked but there were
obvious warts in the solution especially around things like same-host resize
operations.

There was a steady stream of incoming bugs about how various move operations
resulted in missing or incorrect allocation records, and we needed to put some
fairly nasty code into the resource tracker and compute manager code in order
to deal with rolling upgrade scenarios where newer conductor and scheduler
services needed to properly handle and not "correct" inaccurate data that older
compute nodes might be writing.

[Dan Smith identified](http://specs.openstack.org/openstack/nova-specs/specs/queens/approved/migration-allocations.html)
a pretty ingenious way of solving the problem with
allocation tracking during move operations in the Pike release but due to time
constraints we weren't able to implement his solution in Pike.

Now that we're in Queens, we're prioritizing Dan's solution, which is to change
the ownership of allocation records on the source (before move) host from the
instance UUID to the UUID of the migration object itself. This allows the
allocation of resources on the destination host to be allocated to the instance
UUID and, upon successful move, we merely delete the allocations consumed by
the migration UUID. No more messing around with doubled-up allocations.

### Alternate host lists and in-cell retries

The second priority effort has to do with enabling retries of launch requests
within a Cells V2 deployment.

Above, I noted that the reasons for changing the location of resource claim
operations from the `nova-compute` host to the `nova-scheduler` service was
two-fold. Let me elaborate.

First, there exists a problem in current versions of Nova where two scheduler
processes pick the same host for two different instances, and whichever launch
process ends up getting to that host first ends up consuming the last bit of
resources on the host. The unlucky second launch process must then do what is
called a "scheduler retry". This process is quite heavyweight; the scheduler
must be called again over RPC to get a new destination host for the instance
and various pieces of state about the retry need to be passed in the request
spec. Plus, there's no guarantee that when the retry hits a new destination
host that the exact same fate might befall it and cause yet another retry.

Claiming resources within the `nova-scheduler` instead of on the destination
compute host means that we can dramatically reduce the length of time and
complexity of the primary cause of retry operations: resource contention and
race conditions during on-compute-host claiming.

We now attempt to claim resources against the chosen destination host from the
`nova-scheduler` service. If the Placement API returns a `200 OK`, we know that
the instance has already consumed resources on the destination host and the
only thing that can trigger a retry would be some sort of weird host failure --
something that is not a commonly-occurring event. If the Placement API returns
a `409 Conflict`, we can tell from the information returned in the error
response whether the failure was due to a concurrent update or whether the
destination host no longer has any capacity to house the instance.

If another process ended up claiming resources on the destination host in the
time interval between initial selection and the attempt to claim resources for
our instance, we simply retry (in a tight loop within the scheduler code) our
attempt to claim resources against that destination host. If the destination
host was exhausted of resources, then the scheduler moves on to trying another
destination host.  We do all this without ever sending the launch request down
to a target compute host.

The second reason we wanted to move the claiming of resources into the
`nova-scheduler` was because of the Cells V2 design. Recall that the `Cells V2
architecture`_ is designed to remove the peculiarities and segregated API layers
of the old Cells V1 codebase. Having a single API control plane in Cells V2
means simpler and thus easier to maintain code.

However, one of the design tenets of the Cells V2 architecture is that once a
launch (or move) instance request gets to the target cell, there is no "upcall"
ability for the target cell to communicate to the API layer. This is
problematic for our existing retry mechanism. The current retry mechanism
relies on the compute host which failed the initial resource claim being able
to call "back up" to the scheduler to identify another host to attempt the
launch on.

[Ed Leafe is leading the effort](https://blueprints.launchpad.net/nova/+spec/return-alternate-hosts)
in Queens to have the scheduler pass a set of alternate host and allocation
information from the API/scheduler layer down into a target cell. This
alternate host and allocation information will be used by the cell conductor to
retry the launch against an alternative destination, claiming the instance's
resources on that alternative host without the cell conductor needing to
contact the higher API/scheduler layer.

.. Cells V2 architecture: https://docs.openstack.org/nova/pike/user/cellsv2_layout.html#multiple-cells

### Nested resource providers

The third priority effort is around something called "nested resource
providers".

Sometimes there is a natural parent-child relationship between two providers of
resources. Examples of this relationship include NUMA cells and their
containing host, SR-IOV physical functions and their containing host, and
physical GPU groups and their containing host.

Let's say we have two compute nodes. Both compute nodes have 2 SR-IOV physical
functions each. The first compute node has been set up so each physical
function has an inventory of 8 virtual functions. The second compute node has
been set up so that one of the physical functions is marked as passthrough --
meaning the guest will have full control over it. The other physical function
is configured to have an inventory of 8 virtual functions assignable to guests,
similar to the first compute node's physical functions.

![Advanced nested provider topology](images/nested-resource-providers-advanced-topo.png "Nested resource provider topologies")

Currently, the Placement API does not understand the relationship between
parent and child providers. The nested resource providers spec and patch series
adds this awareness to the placement service and allows users to specify the
parent provider UUID of a child resource provider.

The nested resource providers work opens up a number of use cases involving PCI
devices, advanced networking, NUMA support and more. For this reason, it was
decided to put shared resource provider support on the backburner for Queens
and focus on getting at least rudimentary support for simple nested resource
providers done for SR-IOV PF to VF relationships.

### Other items to try in Queens

In addition to the above priority items, we are aiming to wrap up work on a
number of other workstreams. While the focus for reviews will be the three
priority items listed above, progress will still be made in these areas and
reviews will be done on an as-possible basis.

#### Completion of trait-flavor wiring

This is an outstanding item from Pike that needs to be completed. The Placement
API now supports listing traits -- simple string tags describing capabilities
of a resource provider.

However, a couple places still need to be code complete:

* The flavor needs to contain a list of required traits
* The scheduler needs to ask the Placement API to filter providers that have
  all the required traits for a flavor
* The virt drivers need to begin reporting traits against the compute node
  resource providers instead of reporting an unstructured virt-driver-specific
  bag of randomness in the `get_available_resource()` virt driver API call

#### Cache header handling in Placement API

Chris Dent has [proposed](http://specs.openstack.org/openstack/nova-specs/specs/queens/approved/placement-cache-headers.html)
adding `Last-Modified` and other HTTP headers to some resource endpoints in the
Placement REST API. This is important to ensure appropriate behaviour by
caching proxies and the amount of work to complete this effort seems
manageable.

#### Supporting POST multiple allocations in Placement API

This [spec](http://specs.openstack.org/openstack/nova-specs/specs/queens/approved/post-allocations.html)
is actually an enabler for the move operations cleanup work. Chris
proposes to allow a `POST /allocations` call (we currently only support a `PUT
/allocations/{consumer_uuid}` call) that would atomically write multiple
allocation records for multiple consumers in a single transaction. This would
allow us to do the "allocation transfer from instance to migration UUID" that
is part of Dan Smith's solution for move operation resource tracking.

#### Rudimentary vGPU support

Though it unlikely that we will be able to implement the entire
[proposed vGPU spec](http://specs.openstack.org/openstack/nova-specs/specs/queens/approved/virt-add-support-for-vgpu.html)
from Citrix's Jianghua Wang, we will try to at least have some rudimentary support for a `VGPU` resource class completed in Queens.

This initial support means that there may not be support for multiple GPU types
or pGPU pools (in other words, only a single inventory record of `VGPU` per
compute host will be supported).

## Beyond Queens

### A generic device manager

Eric Fried and I have been discussing ideas around a [generic device manager](https://etherpad.openstack.org/p/nova-ptg-queens-generic-device-management)
that would replace much of the code in the existing
[`nova/pci/`](https://github.com/openstack/nova/tree/master/nova/pci) module.
We'll probably move on this initiative in early Rocky.

### NUMA support

Even though the nested resource providers functionality was designed with NUMA
topologies in mind, actually being able to replace the
[`NUMATopologyFilter`](https://github.com/openstack/nova/blob/master/nova/scheduler/filters/numa_topology_filter.py)
in the Nova scheduler with an equivalent functionality in the Placement API is
still a long shot, even for the Rocky release.

The way NUMA support is implemented in Nova is highly coupled with support for
huge pages, CPU pinning, emulator I/O thread pinning, and even the PCI device
manager (for things like NUMA affinity for PCI devices).

It's likely that for the foreseeable future, the `NUMATopologyFilter` will stay
in the Nova scheduler as a complex custom scheduling filter/weigher, and we
will slowly modify the virt driver interface and resource tracker on the
`nova-compute` node to report NUMA cells as resource providers to the Placement
API, gradually replacing some pieces of functionality from the
`NUMATopologyFilter` with queries against the Placement database.

### Shared resource providers

The Placement API allows the representation of a resource provider that shares
its resources with other providers via an aggregate association. These resource
providersare often called "shared resource providers" though a more appropriate
term would be "sharing resource providers".

We need to clean up and add functional testing for shared storage and routed
network IP pool use cases and make sure the resource reporting and tracking is
done accurately.
