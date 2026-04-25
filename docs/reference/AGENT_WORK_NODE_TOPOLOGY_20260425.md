---
status: authoritative
owner: "@ronny"
type: derived-conclusion-note
loop: LOOP-AGENT-WORK-NODE-TOPOLOGY-20260425
wave: WAVE-AGENT-WORK-NODE-TOPOLOGY
scope: design-only
last_verified: "2026-04-25"
---

# Agent Work Node Topology — Design Note

## What an Agent Work Node Is For

An agent work node is a host whose purpose is autonomous agent execution. It
runs spine orchestration, agent worktree synthesis, long-running daemon tasks,
and operator-ingress auto-metabolization. It is the place where spine "does
work" without an operator sitting at a terminal.

An agent work node is NOT the operator console (macbook). The operator console
is where Ronny launches sessions, reviews output, and runs Claude Code
interactively — it is human-driven, not autonomous. An agent work node is also
NOT a domain application host. Domain containers (AnythingLLM, Qdrant, media
stack services, finance tools) serve domain workloads, not spine orchestration.

## What Belongs on the Agent Work Node

These workloads define the agent-work role:

- **Spine runtime** — orchestration engine, dispatch, wave execution, loop
  lifecycle, capability resolution
- **Agent worktrees and synthesis** — codex branch checkouts, agent task
  execution surfaces, worktree-scoped mutation
- **Operator ingress auto-metabolizer** — daemon that classifies, routes, and
  processes operator intent objects without human presence
- **State sync daemons** — any governed background process that keeps spine
  state consistent across surfaces (projection parity, surface standing
  refresh, reconcile writeback)
- **MCP gateway** — spine's MCP server for agent-facing tool access

## What Does NOT Belong on the Agent Work Node

| Workload class | Examples | Why it does not belong |
|---|---|---|
| Domain app containers | AnythingLLM, Qdrant, n8n | These are domain services consumed by agents, not agent execution infrastructure. Their resource pressure (memory, disk, CPU) is driven by domain data volume, not by spine orchestration load. Mixing them creates ungoverned resource contention (see `rag.workload.budget.yaml` advisory ceilings). |
| Model serving | Ollama, Open WebUI | Inference is a shared compute service with GPU/CPU pressure independent of spine. It already has its own host (automation-stack, VM 202). Colocating would make agent execution latency hostage to embedding or inference load. |
| Media stack | Radarr, Sonarr, Jellyfin, SABnzbd, etc. | Domain workloads with heavy disk I/O and their own lifecycle. Governed under `download-stack` and `streaming-stack` VMs. No relationship to agent execution. |
| Finance stack | Firefly III, Data Importer | Domain workload on `finance-stack`. No spine dependency. |
| Observability collectors | Prometheus, Grafana, Loki | Infrastructure services on `observability` VM. Agent work node is a target for observation, not the observer. |
| Operator console tooling | Claude Code interactive sessions, terminal UI | These run on macbook under operator control. The agent work node runs autonomously; the operator console is human-present. |

## Current State — Honest Assessment

**ai-consolidation plays two roles today: agent-work-node AND domain-app-host.**

When the execution host was activated (2026-04-13), spine runtime workloads
moved to ai-consolidation. That was correct — it separated autonomous execution
from the operator console (macbook). But ai-consolidation also hosts domain
containers: AnythingLLM, Qdrant, and n8n. The result is a host carrying 7
workloads across two distinct role classes with no governed resource boundary
between them.

Evidence of the misfit:

- `rag.workload.budget.yaml` documents advisory resource ceilings for
  AnythingLLM and Qdrant but notes enforcement is impossible because
  docker-compose definitions live on the host, not in the repo
  (`blocker_class: root_ownership`).
- `RAG_WORKLOAD_DECOMPOSITION_20260425.md` identifies ai-consolidation
  container density as a secondary seam — "AnythingLLM + Qdrant colocate with
  5 other spine workloads."
- The 7-workload count in `host_context` mixes spine-runtime and domain-app
  without distinguishing which pressure class each belongs to.

This is not broken today. It is honest about the overlap. The design gap is
that no topology concept distinguishes "agent work" from "domain app" on the
same host, so placement decisions have no vocabulary for reasoning about
separation.

## Node Role Taxonomy

| Role | Current host(s) | Purpose |
|---|---|---|
| **operator-console** | macbook | Operator terminal, Claude Code interactive, human-present. Not autonomous. |
| **agent-work** | ai-consolidation (shared) | Spine autonomous daemons, agent synthesis, worktree execution, ingress metabolizer. |
| **model-serve** | automation-stack (VM 202) | Ollama inference, embedding serving. Shared compute service. |
| **domain-app** | ai-consolidation (shared), plus download-stack, streaming-stack, finance-stack, communications-stack, mint-data, mint-apps, immich | Domain service containers. Workload pressure driven by domain data, not spine orchestration. |
| **hypervisor** | pve, pve-r620, proxmox-home | VM hosting. Control plane for VMs. |
| **watcher** | proxmox-home | Observation, interrupt origin, system-dispatch. Physically separated (home site). |
| **storage** | nas, md1400 | Bulk storage, archive, media. |
| **infra-core** | infra-core, observability, dev-tools | Infrastructure services (DNS, secrets, monitoring, git). |

A host MAY carry multiple roles today (ai-consolidation carries agent-work +
domain-app). This taxonomy names the roles so that future placement decisions
can reason about separating them. It does not prescribe when or how to separate.

## Key Boundaries

1. **Agent-work is spine-owned.** The workloads on an agent work node are
   governed by spine bindings, spine orchestration, and spine lifecycle. Domain
   containers are governed by their domain's deployment roots.

2. **Agent-work consumes domain-app services, not the reverse.** The agent work
   node calls AnythingLLM's API, queries Qdrant, triggers n8n workflows. Domain
   apps do not call spine orchestration. The dependency arrow is one-way.

3. **Agent-work has no GPU dependency.** Spine orchestration, worktree
   synthesis, and daemon tasks are CPU/memory/disk workloads. GPU belongs in
   model-serve. If an agent needs inference, it calls model-serve or an external
   API — it does not colocate inference.

4. **Operator-console is not agent-work.** macbook runs Claude Code
   interactively but does not run autonomous daemons. The execution host
   activation (2026-04-13) established this separation. The agent work node
   concept preserves it.

## Explicitly Out of Scope

- Host assignment — this note does not say which host should become the
  dedicated agent work node or whether ai-consolidation should be split.
- Migration plan — no steps for moving domain containers off ai-consolidation.
- Hardware — no VM sizing, CPU/RAM allocation, or procurement.
- Provisioning — no docker-compose changes, systemd unit changes, or deployment
  root governance.
- Timeline — no dates for when role separation should happen.

This note defines the vocabulary. A future implementation loop can reference it
to know what goes where.
