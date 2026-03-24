---
status: authoritative
owner: "@ronny"
created_at: "2026-03-24"
scope: control-node-vm207-requirements
related_gaps:
  - GAP-OP-1657  # operator-as-join-table (open)
  - GAP-OP-1675  # no always-on single-writer control node (closed/deferred)
related_arch: docs/governance/SPINE_V3_BOOTSTRAP.md
---

# Control Node Requirements — VM 207

This document defines the requirements for the always-on spine control node to be
deployed on Proxmox VM 207. It is the governing complement to the node taxonomy in
`docs/governance/SPINE_V3_BOOTSTRAP.md` and the gap record for GAP-OP-1657
(operator-as-join-table reduction).

---

## 1. What the Control Node IS

Per `SPINE_V3_BOOTSTRAP.md`, the control node owns:

| Role | Responsibility |
|------|----------------|
| **Broker** | Authoritative read surface for loop status, loop progress, request attestation, latest-loop query |
| **Scheduler** | Periodic tick execution (`spine.control.tick`, `spine.control.cycle`, nightly closeout, reconcile jobs) |
| **State authority** | Single writer for `shared_authority.db` (gaps + loops tables via governed bridges) |
| **Packet compilation** | Assembling governed execution packets (not prompt authoring; shape only) |
| **Attestation surface** | Emitting and storing run receipts, capability attestations, `SPINE_CAP_RUN_KEY` envelope |

Key properties (from V3 Bootstrap):

- **stable** — does not reboot on operator whim
- **always-on** — available when the MacBook is sleeping, lid closed, or traveling
- **infrastructure-grade** — same posture as the git forge (VM 206) and AI stack (VM 207 co-tenant)
- **login-independent** — no dependency on an active operator session

---

## 2. What the Control Node is NOT

These responsibilities explicitly do NOT belong here:

| NOT here | Belongs elsewhere |
|----------|-------------------|
| Capability execution (running gaps.file, loops.create, verify packs) | Execution nodes (SPINE-EXECUTION-01 workers) |
| Verification and gate runs | Verification node (SPINE-AUDIT-01) |
| Natural-language translation / prompt authoring | Translator node (MacBook operator session) |
| Operator console / session attach surface | MacBook — `session.v3.attach` stays local |
| Domain decisions (approve merge, close loop, take gap action) | Operator — these are approval-gated, never automated here |
| Media, archive, cold history storage | Storage/archive node (md1400, Synology) |
| Git write authority | Execution worktrees only |

The control node is a **read+schedule+state** node. It does not hold terminal
operator authority and cannot approve manual-approval capabilities on its own.

---

## 3. Services Running on the Control Node

### 3.1 Core Services

| Service | Description | Deployment |
|---------|-------------|------------|
| `spine-broker-api` | HTTP wrapper around `spine-control` subcommands: `latest-loop`, `loop-status`, `loop-progress`, `request-attestation`. Replaces direct MacBook invocations. | Docker service, Tailscale-only |
| `spine-tick-scheduler` | Periodic cron runner: executes `spine.control.tick`, `spine.control.cycle --dry-run`, nightly closeout, state reconcile. Replaces launchd on MacBook. | Docker service with cron sidecar or cron in-container |
| `shared_authority.db` | SQLite WAL-mode authority for gaps table and loops table. Already the canonical store as of 2026-03-23 (`shared-authority.mutation.contract.yaml`). | Volume-mounted on VM 207 host filesystem |

### 3.2 Existing MacBook Residents That Move Here

These currently run on the MacBook and are the primary source of MacBook-dependency
fragility (GAP-OP-1675):

| MacBook-resident today | Target on VM 207 | Notes |
|-----------------------|------------------|-------|
| `spine.control.tick` (launchd cron, 33 jobs — 10 failed) | `spine-tick-scheduler` container | Replaces `launchd` with Docker Compose cron |
| MCP broker read tools via `mcp serve` (stdio, in-session) | `spine-broker-api` HTTP service | Removes session dependency for broker reads |
| `shared_authority.db` (lives at `$SPINE_STATE/shared_authority.db`, MacBook path) | VM 207 volume mount | Needs network-accessible read path |
| `nightly-closeout-daily`, `state-shared-reconcile` launchd jobs | Cron jobs in `spine-tick-scheduler` | Already failing on MacBook (10/33 launchd jobs failed) |

### 3.3 Services That Stay on MacBook

| Stays on MacBook | Reason |
|-----------------|--------|
| `session.v3.attach` / operator terminal sessions | Operator console; requires interactive TTY |
| `mcp serve` gateway (stdio, Claude Code / Codex) | Process-bound to the IDE session |
| Cap-run execution of mutating capabilities | Terminal role check requires `OPS_TERMINAL_ROLE` in session |
| Worktree management, git commits | Needs filesystem access to `~/code/` |

---

## 4. Hardware

| Attribute | Value |
|-----------|-------|
| **VM ID** | 207 |
| **Hostname** | ai-consolidation (current) — control-node services co-tenant with Qdrant/AnythingLLM |
| **Proxmox host** | pve |
| **LAN IP** | 192.168.1.8 (DHCP; no VMID parity) |
| **Tailscale IP** | 100.71.17.29 |
| **SSH target** | `ai-consolidation` (SSH alias) |
| **CPU** | 8 cores |
| **Memory** | 32 GB |
| **Boot disk** | 200 GB |
| **OS** | Ubuntu 24.04 |
| **Status** | active (Qdrant + AnythingLLM already deployed) |

Resource overhead for control-node services is minimal:

- Broker API: single-threaded Python/FastAPI, ~100 MB RAM
- Tick scheduler: cron + Python subprocesses, ~200 MB RAM peak
- SQLite: already <10 MB for current gaps+loops data; WAL-mode safe for concurrent reads

No additional VM resources required. The existing VM 207 allocation is sufficient.

---

## 5. Deployment

### 5.1 Stack Location

```
/opt/stacks/spine-control-node/docker-compose.yml
/opt/stacks/spine-control-node/.env
```

Follows the Docker Boringness Contract (`docs/governance/DOCKER_RUNTIME_BORINGNESS_CONTRACT.md`):

- Image-first deploys (no host `docker build` in production path)
- Required labels: `com.ronny.stack`, `com.ronny.service`, `com.ronny.env`
- Restart policy: `unless-stopped`
- Stop grace period: 30s
- Memory limits declared
- Healthcheck on broker API HTTP port
- Backup coverage in `ops/bindings/backup.inventory.yaml`
- Smoke path: `curl http://localhost:<port>/health` or equivalent

### 5.2 Services in Compose

```yaml
services:
  broker-api:
    image: ronny/spine-broker-api:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:<port>:8000"   # Tailscale-only; no public port
    volumes:
      - spine-repo:/opt/spine:ro  # read-only clone of agentic-spine
      - spine-state:/opt/state    # shared_authority.db + mailroom state
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
    labels:
      com.ronny.stack: spine-control-node
      com.ronny.service: broker-api
      com.ronny.env: production

  tick-scheduler:
    image: ronny/spine-tick-scheduler:latest
    restart: unless-stopped
    volumes:
      - spine-repo:/opt/spine:ro
      - spine-state:/opt/state
    environment:
      - SPINE_ROOT=/opt/spine
      - SPINE_STATE=/opt/state
    labels:
      com.ronny.stack: spine-control-node
      com.ronny.service: tick-scheduler
      com.ronny.env: production

volumes:
  spine-repo:    # shallow clone or bind-mount from /opt/repos/agentic-spine
  spine-state:   # bind-mount to /opt/spine-state (persisted volume)
```

### 5.3 Network

- Broker API binds `127.0.0.1` only on the host; accessible over Tailscale via `100.71.17.29:<port>`
- No public internet exposure; no CF tunnel for this service
- MacBook and other Tailscale nodes call the broker API over the mesh
- MCP tools (`get_latest_loop`, `get_loop_status`, `get_loop_progress`, `get_request_attestation`,
  `route_resolve`) will proxy over HTTP instead of running `spine-control` locally via stdio

---

## 6. Migration Path

### Phase 1 — Read surface (broker API)

Move MCP broker reads from local `subprocess`-spawned `spine-control` to HTTP calls against
the VM 207 broker API.

Affected capabilities (all currently implemented in `ops/plugins/core/evidence/bin/spine-control`):

| Capability | Current path | Target path |
|------------|-------------|-------------|
| `spine.broker.get_latest_loop` | `spine-control latest-loop` (local) | `GET /latest-loop` on VM 207 |
| `spine.broker.get_loop_status` | `spine-control loop-status` (local) | `GET /loop-status` on VM 207 |
| `spine.broker.get_loop_progress` | `spine-control loop-progress` (local) | `GET /loop-progress` on VM 207 |
| `spine.broker.get_request_attestation` | `spine-control request-attestation` (local) | `GET /request-attestation` on VM 207 |
| `mcp__spine__route_resolve` | `spine-control` local via stdio | `GET /route-resolve` on VM 207 |

Parity requirement: broker API must emit the same JSON envelope as the local
`spine-control` commands (same `capability`, `schema_version`, `status`, `data` fields).

### Phase 2 — Scheduler migration

Move the 33 launchd jobs off MacBook (currently 10/33 failed as of 2026-03-24):

| Job | Migration target |
|-----|-----------------|
| `com.ronny.nightly-closeout-daily` | Cron in `tick-scheduler` |
| `com.ronny.state-shared-reconcile` | Cron in `tick-scheduler` |
| `com.ronny.spine-briefing-email-daily` | Cron in `tick-scheduler` |
| `com.ronny.launchd-health-check` | Replace with Docker healthcheck pattern |
| Other 29 jobs | Audit: keep (migrate), defer, or retire |

Transition: launchd jobs stay as fallback during Phase 2 build-out; jobs are disabled
one-by-one after VM 207 equivalents are verified.

### Phase 3 — State authority network access

Currently `shared_authority.db` lives at `$SPINE_STATE/shared_authority.db` on MacBook.
After Phase 1+2, this moves to VM 207 with a network-accessible read path:

- Write path: governed bridge mutations (`gaps.file`, `gaps.close`, `loops.create`,
  `loop.closeout.finalize`) still execute on SPINE-CONTROL-01 MacBook terminal sessions
  and write via SSH or a governed HTTP mutation endpoint
- Read path: broker API reads directly from the VM 207 SQLite volume
- Interim: keep MacBook copy as primary write authority; broker API reads a replicated
  copy synced via `state-shared-reconcile` cron

Full migration to VM 207 as single-writer requires Phase 3 mutation bridge (out of scope
for this spec; operator decision pending).

---

## 7. Operator-as-Join-Table Reduction (GAP-OP-1657)

GAP-OP-1657 states: "Operator is still the implicit join table. 13 active loops, 70 open
gaps in a single YAML hotspot, 205 friction entries with no auto-triage, 25 dirty files
blocking session attach. Every reconciliation pass requires operator memory."

### What the control node eliminates

The following operator-joins become mechanical after VM 207 deployment:

| Operator join today | Eliminated by |
|--------------------|---------------|
| "What loop is active? What's its status?" → manual `loops list` | `get_latest_loop` HTTP call, no operator needed |
| "Is the broker online?" → depends on MacBook being awake | Broker API always-on on VM 207 |
| "Did the nightly closeout run?" → check launchd logs | `tick-scheduler` cron log in Docker; observable without operator session |
| "Are there stale scheduled jobs?" → launchd on MacBook | VM 207 cron + health endpoint; 10 currently-failing launchd jobs resolved |
| "What are the P0 actions right now?" → operator recalls state | `spine.control.plan` produces deterministic prioritized action list (P0/P1/P2) without operator intervention |
| "Is `shared_authority.db` in sync with the YAML projection?" → manual `state-shared-reconcile` | Cron on VM 207, runs on schedule without operator |
| MCP broker tools require active Claude Code session | Broker API callable from any Tailscale node without a live session |

### What remains operator-only (not reduced)

These joins cannot and should not be automated:

| Operator join that stays | Reason |
|--------------------------|--------|
| Approving manual-approval capabilities | Policy: these require `--confirm` from an active operator terminal |
| Authoring loop objectives, gap descriptions | Domain knowledge; no mechanical substitute |
| Deciding to close a loop | Governance contract: operator declares completion level |
| Reviewing and acting on P0 plan actions | Final authority stays with operator; plan is advisory |
| Approving PR merges | `gitea.pr.merge` is approval-gated; operator decides |

---

## 8. Dependencies

| Dependency | Requirement |
|-----------|-------------|
| **Git access** | Read-only clone of `agentic-spine` repo at `/opt/repos/agentic-spine` on VM 207; updated by a periodic `git pull` in `tick-scheduler` |
| **SQLite** | Python `sqlite3` stdlib — no external DB server required |
| **Python runtime** | Python 3.11+ (same as current `spine-control` script) |
| **PyYAML** | Required by `spine-control` for YAML parsing |
| **Tailscale** | VM 207 already on Tailscale at `100.71.17.29`; broker API bound to Tailscale interface |
| **Docker + Compose** | Already estate-standard; VM 207 must have Docker installed |
| **SSH access from MacBook** | Already in place (`ssh ai-consolidation`) |
| **No Infisical secrets required** | Broker API is read-only; no API keys needed for core broker surface. Scheduler jobs that call external services (SimpleFIN sync, email) need secrets via Infisical or env file. |

---

## 9. Network

| Surface | Binding | Access |
|---------|---------|--------|
| Broker API (HTTP) | `127.0.0.1:<port>` on VM 207 host | Tailscale-only: `http://100.71.17.29:<port>` |
| SSH (existing) | Port 22 | Tailscale-only |
| No CF tunnel | — | Control node has no public exposure |
| No VLAN ACL changes required | VM 207 is in Servers VLAN with existing Tailscale access | |

Port number is operator-assigned at deploy time; recommend `18701` to avoid collision
with existing services. Register in `docs/governance/SERVICE_REGISTRY.yaml` after deploy.

---

## 10. Success Criteria

The control node is considered operational when:

1. `GET http://100.71.17.29:18701/latest-loop` returns valid broker envelope without
   MacBook being awake or a session attached
2. `tick-scheduler` cron fires `spine.control.tick` on schedule and logs to Docker stdout
3. `state-shared-reconcile` runs without manual operator trigger
4. MCP broker tools (`get_latest_loop`, `get_loop_status`, `get_loop_progress`,
   `get_request_attestation`) are re-implemented to call VM 207 HTTP instead of local subprocess
5. All 10 currently-failing launchd jobs either have a VM 207 equivalent or are retired
6. `shared_authority.db` is readable from VM 207 (Phase 1: replicated; Phase 3: primary)

Gate: file as `D-spine-control-node-parity` in `gate.registry.yaml` when all 6 criteria pass.

---

## 11. Out of Scope for This Spec

- VM 207 provisioning details (VM is already active)
- Docker installation on VM 207 (operator prerequisite)
- Secrets management for scheduler external calls (separate runbook)
- Full mutation bridge (Phase 3 state authority migration)
- Translator node requirements (separate spec)
- Execution node (SPINE-EXECUTION-01) requirements (separate spec)
