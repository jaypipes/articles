# An Update on the Placement API and Scheduler plans for Queens

This article provides an update on the progress that has been made by the
OpenStack contributor community in the area of the Nova scheduler and Placement
services. I'll also outline the blueprints we are tackling in the Queens
release cycle and provide a roadmap for the big ticket items we want to
complete in the next few releases.

## Recap of previous release accomplishments

Recall that the Placement API was exposed as a separate API endpoint in the
Newton release of OpenStack.

Since then, the team has been steadily improving the API and integrating it
further into Nova. In the Newton release focused mainly on getting the
`nova-compute` workers to **properly inventory** local (to the compute node)
resources and send those inventory records to the Placement API.

In Ocata, we modified the `nova-scheduler` service to make use of the Placement
API in **filtering compute nodes** that met some basic resource requests.

In the Pike release we focused on moving the location of where we **claim
resources** from the `nova-compute` worker to the `nova-scheduler` service. The
reason for this focus was two-fold: performance/scale and alignment with the
Cells V2 architecture. I'll cover the details of this in the section below
called "Alternate host lists and in-cell retries".

## Priorities for Queens

At the Denver Project Team Gathering, the Nova contributor team resolved to
work on three primary areas in the scheduler and resource placement functional
areas. It should be noted that we understand that there are many, many
additional feature requests in this area -- some having been on our radar for
years. We recognize that it can be frustrating for operators and potential
users to see some longstanding issues and items not receieve priority for
Queens. However, there is only so much review bandwidth that the core team
realistically has, and choices do need to be made. We welcome discussion of
those choices both at the PTG and on the mailing list.

It should also be noted that while there are only three priority workstreams
for the scheduler and resource placement area in Queens, that does **NOT** mean
that no other proposed items will be reviewed or make progress. It simply means
that the core teams' review focus will be on patch sets that further the effort
in these areas.

### Properly handling move operations

The first priority effort we're tackling in Queens is cleaning up and fully
covering the functional test coverage of move operations -- migrate, rebuild,
resize, evacuate, unshelve, etc -- in relation to the placement API.

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
complexity of the primary cause of retry operations. We now attempt to claim
resources against the chosen destination host from the `nova-scheduler`
service. If the Placement API returns a `200 OK`, we know that the instance has
already consumed resources on the destination host and the only thing that can
trigger a retry would be some sort of weird host failure -- something that is
not a commonly-occurring event. If the Placement API returns a `409 Conflict`,
we can tell from the information returned in the error response whether the
failure was due to a concurrent update or whether the destination host no
longer has any capacity to house the instance.

If another process ended up claiming resources on the destination host in the
time interval between initial selection and the attempt to claim resources for
our instance, we simply retry (in a tight loop within the scheduler code) our
attempt to claim resources against that destination host. If the destination
host was exhausted of resources, then the scheduler moves on to trying another
destination host.  We do all this without ever sending the launch request down
to a target compute host.

The second reason we wanted to move the claiming of resources into the
`nova-scheduler` was because of the Cells V2 design. Recall that the Cells V2
architecture is designed to remove the peculiarities and segregated API layers
of the old Cells V1 codebase. Having a single API control plane in Cells V2
means simpler code and thus easier to maintain code.

However, one of the design tenets of the Cells V2 architecture is that once a
launch (or move) instance request gets to the target cell, there is no "upcall"
ability for the target cell to communicate to the API layer. This is
problematic for our existing retry mechanism. The current retry mechanism
relies on the compute host which failed the initial resource claim being able
to call "back up" to the scheduler to identify another host to attempt the
launch on.

### Nested resource providers

The third priority effort is around something called "nested resource
providers".

### Other items to try in Queens

#### Completion of trait-flavor wiring

## Beyond Queens

### NUMA support

### Shared resource provider testing and cleanup

### Generic device manager
