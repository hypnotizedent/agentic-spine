# What The Spine Is

The spine is a production-grade agentic execution system and governance-first
control plane.

It exists to make repeatable, unattended, recoverable work possible across
models, tools, terminals, and nodes without depending on chat memory, a single
vendor surface, or one machine staying special forever.

It provides governed entry, explicit role and write-scope boundaries, canonical
runtime and evidence roots, receipted execution, and verification that survives
session loss, tool changes, and operator handoff.

Model independence, tool independence, node portability, and local or
self-hosted AI are part of the platform identity now, not future aspirations.

## What It Is Not

- Not shared memory for stateless agents
- Not a homelab-only control surface
- Not a bucket of domain apps
- Not a platform whose purpose is exhausted by four infrastructure concerns

## Platform vs Workloads

Infrastructure, media, Home Assistant, finance, and future systems are
workloads the platform runs or governs. They are not the platform identity.

The platform is the governed execution system itself. Workloads attach to it,
route through it, and leave evidence through it.

## The First Workload Family

The first workload family is infrastructure:

1. **Identity & Access**: every device has one name, one path in, and one
   governed credential story.
2. **Network Stability**: hostname resolution and reachability are declared, not
   rediscovered every session.
3. **Configuration Management**: a machine converges to declared state
   repeatably and idempotently.
4. **Golden Images & Templates**: systems are born close to correct instead of
   depending on long post-provisioning drift repair.

These four concerns matter because they are the first governed workload family,
not because they define the total purpose of the spine.

## The Rule

If you are adding a capability, binding, adapter, or doctrine surface, ask two
questions:

1. Does this strengthen the platform as a governed execution system?
2. Does this serve a governed workload that runs on the platform?

If the answer to both is no, it does not belong here.

If it is workload-specific but not platform-specific, put it in the runtime or
domain that owns that workload.
