# What The Spine Is

The spine is shared memory for stateless agents working on Ronny's infrastructure.

Monday's agent doesn't know what Thursday's agent did. Without the spine, they break things. With it, they read state, execute against declared truth, and leave a receipt so the next agent picks up where they left off.

That's it. Everything else is mechanism that either serves that purpose or doesn't.


# What The Spine Solves

Four things. If a capability doesn't serve one of these, it doesn't belong here.

**1. Identity & Access**
Every device has one name, one way in, one set of credentials. An agent never figures out "how do I reach this machine." It looks up the name. It gets the answer. It connects. Address resolution goes through `ops/lib/ssh-resolve.sh` (D321). Hardcoded IPs are prohibited — use the hostname, let the spine resolve it.

**2. Network Stability**
Hostname resolves. Device is reachable. Every time. No stale IPs, no DHCP surprises, no "it worked yesterday." The network is declared, not discovered.

**3. Configuration Management**
A VM is what its declaration says it is. Run the config once, the VM matches. Run it a hundred times, nothing changes. No imperative SSH sessions. No "one agent configured it this way, another configured it that way." Declared state, enforced state.

**4. Golden Images & Templates**
A VM is born correct. Not "born base, then manually configured, then drifts for 3 weeks." A fileserver template IS a fileserver. Clone it, name it, done. Post-provisioning configuration is zero or near-zero.


# What The Spine Does NOT Solve

The spine is not a business application platform. It is not a media manager. It is not a home automation controller. It is not a CRM.

Mint, media, Home Assistant, finance — these are domains that USE the spine's infrastructure. They don't live inside it. When Mint needs a database, it asks the spine to provision a VM. Mint never touches SSH configs, never creates DHCP reservations, never manages NFS mounts. The spine handles that. Mint handles orders.


# How It's Sliced

**Layer 1 — The Framework (open source, GitHub)**
The pattern. Session lifecycle, capability dispatch, receipt system, entry gate, loop model. No infrastructure knowledge. No IPs. No credentials. Someone clones it and gets a working governance skeleton with example capabilities.

**Layer 2 — The Infrastructure (Ronny's spine, Gittea)**
The machines. SERVICE_REGISTRY, ssh.targets, DHCP bindings, VM profiles, DNS authority, templates. This is where the four pain points live. An agent working here knows what machines exist, how to reach them, and what they should look like. This layer has maybe 100-170 capabilities. Not 808.

**Layer 3 — The Domains (separate runtimes)**
The businesses. Mint has its own repo, its own MCP server, its own capabilities. Media has its own. HA has its own. Finance has its own. Each domain connects to the spine for infrastructure but owns its own logic. An agent working on Mint sees Mint capabilities. Not 808 things it doesn't need.


# How Agents Use The Spine

**The 30-second version:**

You are a stateless agent. You don't remember previous sessions. The spine is how you know what's true.

1. You attach (`session.v3.attach`). This gives you context — what exists, what's running, what was done before you.
2. You receive a controller prompt. It tells you what to do. It was compiled by a translator that already understands the system. Trust it.
3. You execute the prompt. Read what it says to read. Create what it says to create. Don't explore. Don't orient. Don't launch discovery agents.
4. You emit a receipt. What you did, what changed, what's still broken. The next agent reads this.

If the prompt is wrong, file a blocker. Don't freelance.

If you don't have a controller prompt and you're working directly with the operator, your job is to: check state → propose a change → get approval → make the change → verify → receipt. One thing at a time.

**What you never do:**
- Assume. Read the binding. If the binding doesn't exist, ask.
- Explore for orientation. The spine has 800+ files. You will burn your context window and deliver nothing. Read only what your task requires.
- Create documentation unless explicitly asked. Doc sprawl is how the last system died.
- Touch domains outside your scope. If you're working on network, you don't touch Mint. If you're working on Mint, you don't touch network.


# The History (Why This Exists)

ronny-ops was 58 files. Nineteen scripts that synced secrets, checked health, and managed DNS. It worked until it didn't — 19 VMs, distributed stacks, mounts breaking, credentials drifting. The scripts couldn't keep up.

The spine was built to govern what scripts couldn't. But agents built the governance, and agents optimize for what agents like: structure, contracts, gates, registries, schemas. The governance grew to 808 capabilities, 451 bindings, 412 drift gates. The system that was supposed to prevent chaos became its own source of chaos.

This document is the correction. The spine goes back to solving four problems. Everything that doesn't serve identity, network, configuration, or templates gets extracted into its own domain or deprecated.


# The Rule

If you're an agent reading this and you're about to add a new capability, binding, drift gate, governance doc, or contract — stop. Ask: does this serve one of the four things above? If the answer is no, it doesn't go in the spine. Put it in the domain it belongs to.

The spine's job is to shrink, not grow.
