# Host Drift Policy

> Status: authoritative
> Owner: @ronny
> Last verified: 2026-05-03
> Surface: governance — defines how host-local code checkouts stay aligned with `origin/main` truth

## Purpose

Spine governance has one code source of truth: `origin/main` of
`agentic-spine` on the forge. Every host that runs spine code must execute the
same committed contracts and capabilities. Drift between a runtime checkout and
`origin/main` is silent corruption: caps run stale code, verify readback teaches
old truth, and closeout rituals turn into manual sync ceremonies.

PACKET-616 makes runtime checkout deployment first-class. The canonical
placement contract is:

`ops/bindings/runtime.checkout.placement.yaml`

The canonical readback is:

`./bin/ops cap run infra.host.code.drift.status`

The canonical update path is:

`./bin/ops cap run infra.host.code.deploy.update`

## The Single Rule

**Every managed runtime checkout HEAD must equal `origin/main` HEAD before
operators trust that host's spine readback.**

`runtime.checkout.placement.yaml` declares which hosts are managed, where their
checkouts live, and which hosts are intentionally unmanaged. The drift cap reads
that contract. The deploy cap reads the same contract and updates only managed
checkouts.

## Canonical Runtime Checkout Placement

| Host | Role | Code path | Canonical update mode | Drift gate |
|---|---|---|---|---|
| MacBook | operator_console | `/Users/ronnyworks/code/agentic-spine` | `infra.host.code.deploy.update` local `git pull --ff-only` | `infra.host.code.drift.status` |
| ai-consolidation | execution_host | `/home/ubuntu/code/agentic-spine` | `infra.host.code.deploy.update` over SSH, `git pull --ff-only` | `infra.host.code.drift.status` |
| pve | storage_evidence_node | `/opt/agentic-spine` | `infra.host.code.deploy.update` over SSH, `git pull --ff-only` using pve's read-only forge deploy key | `infra.host.code.drift.status` |
| pve-r620 | watcher_node | no checkout | unmanaged witness surface | n/a |

The table is explanatory. The machine-readable authority is
`ops/bindings/runtime.checkout.placement.yaml`.

## Subtracted Operator Grammar

These are no longer the normal deployment path:

- operator-typed `ssh ... git pull`
- per-host manual checkout sync after every commit
- MacBook-to-pve rsync as normal deployment

They remain legal only as expert emergency/bootstrap drilldown when the governed
deploy cap cannot run and the incident is recorded. Normal closeout should be one
cap call, followed by drift readback.

## Governed Update Behavior

`infra.host.code.deploy.update`:

- reads `ops/bindings/runtime.checkout.placement.yaml`
- refuses dirty checkouts
- refuses non-fast-forward/diverged checkouts
- skips unmanaged witness surfaces
- performs `git fetch origin main` and `git pull --ff-only origin main`
- writes before/after HEAD receipts under
  `$SPINE_STATE/domain-state/host-code-deploy/`

The deploy cap declares `routing.db_authority: skip` because it does not mutate
the shared authority DB. Its target is external runtime checkouts.

## What This Policy Does Not Cover

- File-plane state (`$SPINE_STATE`, loop scopes, domain-state, mailroom writes):
  owned by root authority and storage_evidence_node file-plane policy.
- Workbench role-aware verify: workbench is not pve's role.
- Watcher transfer: paused by operator instruction; pve-r620 stays a witness
  surface with no spine checkout.
- Product/domain deploys: this policy only updates the `agentic-spine` runtime
  checkout on hosts that run spine code.

## Related Contracts and Gates

- `ops/bindings/runtime.checkout.placement.yaml` — canonical runtime checkout placement
- `ops/bindings/runtime.bootstrap.contract.yaml#db_authority.code_path` — pve routed-cap checkout path
- `ops/bindings/root.authority.contract.yaml#taxonomy.storage_evidence_node_canonical` — pve canonical roots
- `surfaces/verify/d447-node-admission-subtraction-truth.sh` — static lock that the placement/readback/deploy surfaces exist
- `infra.host.code.drift.status` — read-only drift readback
- `infra.host.code.deploy.update` — governed runtime checkout update

## History

- 2026-05-02: Created to stop hidden pve checkout drift after D.3b migration.
- 2026-05-03: PACKET-616 subtracted rsync as canonical sync after pve received a
  read-only forge deploy key. Runtime checkout deployment is now a governed cap
  over a placement contract.
