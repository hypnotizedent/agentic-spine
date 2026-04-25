---
status: authoritative
owner: "@ronny"
type: derived-conclusion-note
loop: LOOP-WORKLOAD-SEPARATION-NORMALIZATION-20260425
wave: WAVE-WORKLOAD-SEPARATION-NORMALIZATION
scope: design-only
last_verified: "2026-04-25"
---

# Workload Separation Matrix — Design Note

## Purpose

Name the workload classes, name the node roles, and map current placement vs
ideal placement so a future implementation loop can pick a row and execute.
This note does not move anything.

## Sources

- `ops/bindings/infra.placement.policy.yaml` — host inventory and VM targets
- `ops/bindings/fabric.boundary.contract.yaml` — spine vs workbench boundary
- `docs/reference/RAG_WORKLOAD_DECOMPOSITION_20260425.md` — RAG plane analysis
- `ops/bindings/domains/rag/rag.workload.budget.yaml` — ai-consolidation budget

---

## 1. Workload Classes

| ID | Class | Examples |
|----|-------|----------|
| W1 | operator-facing-read-submit | cockpit, mobile surface (spine.ronny.works), phone ingress |
| W2 | autonomous-daemon | spine runtime daemons: auto-metabolizer, state-sync, dispatch, context/session services (launchd on macbook, systemd on ai-consolidation) |
| W3 | agent-work-synthesis | worktrees, Claude Code terminal sessions, wave execution, long-running synthesis |
| W4 | model-serving | Ollama inference + embedding (mxbai-embed-large), Open WebUI |
| W5 | domain-app-container | AnythingLLM, Qdrant, n8n, Firefly III, Data Importer, Immich |
| W6 | observability | Prometheus, Grafana, Loki, Uptime Kuma |
| W7 | infrastructure | Cloudflare tunnel, PiHole, Vaultwarden, Infisical, CrowdSec |
| W8 | media-acquisition | Prowlarr, Radarr, Sonarr, Lidarr, SABnzbd, qBittorrent, Unpackerr, FlareSolverr, Recyclarr, Bazarr, Huntarr, Decypharr, Swaparr-*, Soularr |
| W9 | media-serving | Jellyfin, Jellyseerr, Navidrome, Trailarr, Posterizarr, Homarr, Wizarr, Spotisub, Subgen, Tdarr, AutoPulse, Crosswatch |
| W10 | storage | NAS (nas), md1400 (media/archive target), backup destinations |

## 2. Node Roles

| ID | Role | Current Host | Site |
|----|------|-------------|------|
| N1 | operator-console | macbook | mobile |
| N2 | agent-work | ai-consolidation | shop |
| N3 | model-serve | automation-stack | shop |
| N4 | domain-app | (no dedicated host — mixed into N2) | shop |
| N5 | hypervisor-shop | pve, pve-r620 | shop |
| N6 | hypervisor-home | proxmox-home | home |
| N7 | watcher | proxmox-home (VM) | home |
| N8 | observability | observability (VM) | shop |
| N9 | infrastructure | infra-core (VM) | shop |
| N10 | media-acquire | download-stack (VM) | shop |
| N11 | media-serve | streaming-stack (VM) | shop |
| N12 | dev-tools | dev-tools (VM) | shop |
| N13 | finance | finance-stack (VM) | shop |
| N14 | communications | communications-stack (VM) | shop |
| N15 | storage | nas | home |

## 3. Placement Matrix

Legend: `C` = current placement, `I` = ideal placement, `CI` = current and ideal match.

```
                 N1    N2    N3    N4    N5   N6   N7   N8   N9  N10  N11  N12  N13  N14  N15
                 oper  agent model dom  hyp  hyp  wat  obs  inf  dl  strm dev  fin  comm stor
                 cons  work  serve app  shop home cher serv fra  stk  stk  tls  stk  stk
W1  read-submit  CI    C     .     .    .    .    .    .    .    .    .    .    .    .    .
W2  auto-daemon  C     C     .     .    .    .    .    .    .    .    .    .    .    .    .
                       I
W3  agent-synth  CI    CI    .     .    .    .    .    .    .    .    .    .    .    .    .
W4  model-serve  .     .     CI    .    .    .    .    .    .    .    .    .    .    .    .
W5  domain-app   .     C     .     I    .    .    .    .    .    .    .    CI   CI   CI   .
W6  observ       .     .     .     .    .    .    .    CI   .    .    .    .    .    .    .
W7  infra        .     .     .     .    .    .    .    .    CI   .    .    CI   .    .    .
W8  media-acq    .     .     .     .    .    .    .    .    .    CI   .    .    .    .    .
W9  media-serve  .     .     .     .    .    .    .    .    .    .    CI   .    .    .    .
W10 storage      .     .     .     .    .    .    .    .    .    .    .    .    .    .    CI
```

### Reading the Matrix

- **W1 read-submit**: cockpit/mobile serves from ai-consolidation (`C` on N2)
  but operator reads it on macbook (`CI` on N1). The surface is operator-facing
  so N1 is the correct role. N2 hosting is an implementation detail, not a
  misfit.

- **W2 auto-daemon**: runs on both macbook (launchd, `C` on N1) and
  ai-consolidation (systemd, `C` on N2). Ideal is ai-consolidation only
  (`I` on N2). macbook is primary-when-awake by design, but the dual placement
  creates state-sync complexity.

- **W3 agent-synth**: macbook is the operator terminal for Claude Code sessions
  (`CI` on N1). ai-consolidation runs governed agent execution (`CI` on N2).
  Both placements are correct — different roles.

- **W5 domain-app**: AnythingLLM, Qdrant, n8n currently on ai-consolidation
  (`C` on N2). These are domain-app containers, not spine agent-work daemons.
  Ideal placement is a dedicated domain-app node (`I` on N4) which does not
  exist today. Firefly is correctly on finance-stack (`CI` on N13),
  communications on communications-stack (`CI` on N14), Gitea on dev-tools
  (`CI` on N12).

---

## 4. Current Misfits

### 4a. ai-consolidation role conflation

ai-consolidation serves as both agent-work (N2) and domain-app (N4). It
carries:

- Spine runtime daemons (auto-metabolizer, state-sync, dispatch)
- n8n (workflow automation — domain-app container)
- AnythingLLM (RAG frontend — domain-app container)
- Qdrant (vector DB — domain-app container)
- operator-ingress-auto-metabolizer
- state-sync
- additional daemons (7+ total per rag.workload.budget.yaml)

The agent-work daemons and domain-app containers have different failure modes,
resource profiles, and lifecycle cadences. Mixing them on one host means a
Qdrant memory spike or n8n webhook storm can starve spine runtime daemons.

### 4b. Deployment roots on host, not in repo

Per `rag.workload.budget.yaml`, docker-compose definitions for AnythingLLM and
Qdrant live at `ai-consolidation:/opt/stacks/` — NOT in the repo. This is the
`root_ownership` blocker that Wave B surfaced. Container resource limits,
restart policies, and volume mounts cannot be governed by spine until
deployment roots are brought under version control or a remote provisioning
path exists.

This applies to n8n and likely other domain-app containers on ai-consolidation
as well.

### 4c. Dual daemon placement (macbook + ai-consolidation)

Spine daemons run via launchd on macbook and systemd on ai-consolidation.
macbook is primary when the operator is awake; ai-consolidation is always-on
fallback. This is intentional but creates:

- State divergence when macbook sleeps and ai-consolidation continues
- No governed handoff — whichever host writes last wins
- Two sets of service definitions to maintain (launchd plists + systemd units)

### 4d. No dedicated domain-app node (N4)

The matrix shows `I` on N4 for W5, but N4 does not exist as a host today.
AnythingLLM, Qdrant, and n8n need a home that is not ai-consolidation. This
could be a new VM on pve or a repurposed existing VM — but the node does not
exist yet.

---

## 5. Future Migration Candidates

These are named for future implementation loops. This note does not execute
any of them.

| Candidate | From | To | Blocker |
|-----------|------|----|---------|
| AnythingLLM + Qdrant | ai-consolidation (N2) | domain-app node (N4) | N4 does not exist; deployment roots not in repo |
| n8n | ai-consolidation (N2) | domain-app node (N4) | Same as above |
| Spine daemons (dual) | macbook (N1) + ai-consolidation (N2) | ai-consolidation (N2) only | Operator must accept always-on-only; state-sync handoff contract needed |
| Deployment roots | host filesystem (/opt/stacks/) | repo-governed path | Compose files must be brought into repo or remote provisioning built |

### Sequencing note

Deployment root governance (last row) is prerequisite for the container
migrations. Without compose files in-repo, moving containers to a new host
just recreates the same ungoverned root problem somewhere else.

---

## 6. Explicitly NOT Doing

- No migration execution
- No docker-compose rewrites
- No new VM creation or hardware planning
- No binding changes
- No resource limit enforcement
- No node topology mutations
- No capacity planning numbers

This note is a map. The territory stays where it is until an implementation
loop picks a row from the matrix and moves it.
