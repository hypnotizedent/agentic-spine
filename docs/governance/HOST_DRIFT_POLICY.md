# Host Drift Policy

> Status: authoritative
> Owner: @ronny
> Last verified: 2026-05-02
> Surface: governance — defines how host-local code/state checkouts stay aligned with `origin/main` truth

## Purpose

Spine governance is a single canonical source: `origin/main` of `agentic-spine`. Every host that runs spine code (operator console, execution host, watcher, storage_evidence_node) holds a local checkout of that repo. Drift between any host's local checkout and `origin/main` is silent corruption — code can run against stale contracts, verify gates can pass against demoted truth, and routed dispatches can land on stale targets.

This policy declares the canonical host drift surfaces, names the drift gate that catches divergence, and defines resolution paths.

## Canonical host drift surfaces

| Host | Role | Code path | Sync mechanism | Drift gate |
|---|---|---|---|---|
| MacBook | operator_console | `/Users/ronnyworks/code/agentic-spine` | `git pull origin main --ff-only` (operator-driven) | git tracks divergence directly |
| ai-consolidation | execution_host | `/home/ubuntu/code/agentic-spine` | `git pull origin main --ff-only` (run after ops on MacBook push) | git tracks divergence directly |
| pve | storage_evidence_node (delivered) | `/opt/agentic-spine` | rsync from MacBook primary checkout (no gitea SSH from pve today) | **D447 extension (PACKET-586)** — verifies pve checkout HEAD matches `origin/main` HEAD |
| pve-r620 | watcher_node | (no spine code checkout — observes only via NFS read-only mount + heartbeat) | n/a | n/a |

## The single rule

**Every host's spine checkout HEAD must equal `origin/main` HEAD before consumers can trust authority readback.**

For git-tracked hosts (MacBook, ai-consolidation), `git pull origin main --ff-only` enforces this naturally; CI / operator workflow catches divergence on next pull. The drift surface is bounded.

For pve, the rsync-from-MacBook pattern was a substrate workaround during D.3b cutover (PACKET-581) — pve does not currently have gitea SSH access. The drift gate at D447 catches divergence at verify time. If pve drifts, spine.verify on pve fails before any cap dispatches against stale code.

## Resolution paths

When the drift gate fires (pve HEAD ≠ `origin/main` HEAD):

1. **Routine drift after operator push**: re-rsync from MacBook primary checkout:
   ```bash
   rsync -av --exclude=node_modules --exclude=.runtime --exclude=.evidence \
     -e "ssh -i ~/.ssh/spine_machine_ed25519" \
     /Users/ronnyworks/code/agentic-spine/ \
     root@192.168.1.184:/opt/agentic-spine/
   ssh -i ~/.ssh/spine_machine_ed25519 root@192.168.1.184 'chown -R root:root /opt/agentic-spine'
   ```
2. **Substrate gap** (gitea SSH not available from pve): out-of-scope for this policy — separate slice would set up pve→gitea SSH so `git pull` works directly. Until then, rsync is the authoritative sync mechanism.

## What this policy does NOT cover

- File-plane state plane (loop scopes / domain-state / mailroom file writes — three-host fragmentation): **the policy is now declared** in `ops/bindings/root.authority.contract.yaml#taxonomy.storage_evidence_node_canonical.file_plane_policy` (PACKET-590). pve is the canonical home; consumer-host `$SPINE_STATE/...` is projection/cache only. This file does not own the file-plane policy — it covers host **code** drift only. PACKET-600 propagated the policy teaching into AGENTS.md and SESSION_PROTOCOL.md so first-read docs match root authority.
- Workbench role-aware verify (D153/D397): separate slice. Workbench is not pve's role.
- Watcher transfer: paused per operator instruction.

## Related contracts and gates

- `ops/bindings/runtime.bootstrap.contract.yaml#db_authority.code_path` — declares `/opt/agentic-spine` as the routed-cap dispatch target on pve
- `ops/bindings/root.authority.contract.yaml#taxonomy.storage_evidence_node_canonical` — declares pve canonical roots (PACKET-585)
- `surfaces/verify/d447-node-admission-subtraction-truth.sh` — D447 gate; PACKET-586 extends with the pve checkout drift check
- Receipts: PACKET-581 (path resolution), PACKET-584 (recovery drill), PACKET-585 (root authority truth-up)

## History

- 2026-05-02: Created. Closes the dangling `/ctx` skill reference. Pairs with PACKET-586 drift gate extension.
