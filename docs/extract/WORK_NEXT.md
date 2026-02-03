# WORK_NEXT — Ronny-ops extraction (mapping-first, zero runtime)

## Authority
- **Authority:** `agentic-spine` only.
- **Legacy:** `ronny-ops` remains **LEGACY** and must **never** become runtime.
- **No HOME drift roots:** No `~/agent`, `~/runs`, `~/log`, `~/logs`.
- **Canonical front door:** `./bin/ops` (mailroom + ops cap + watcher receipts).
- **Baseline:** `v0.1.1-canon-hardened` (commit `33ff991`).

## Goal
Extract **only the CORE reference material** agents need from `ronny-ops` without importing a competing runtime.
Extraction is **vendored snapshots only** (read-only), each with:
- a hash manifest
- an index entry
- an admissible receipt trail

## Non-negotiable principles
- `ronny-ops` must never run inside Spine.
- `/code` receives only **vendored snapshots** (read-only artifacts).
- Spine remains the single authority for protocols, gates, orchestration, and receipts.

## STOP RULES (hard)
Halt immediately if mapping detects any competing runtime surfaces that could drift authority, including:
- watchers / inbox/outbox pipelines
- launchd / LaunchAgents plists
- cron registries or schedulers
- receipt systems or mailrooms that aren't Spine

## Denylist (must never be vendored)
Any snapshot must exclude (or the gate must fail on presence of):
- `**/mailroom/**`
- `**/receipts/**`
- `**/agents/**` (runtime agents/watchers)
- `**/*.plist`
- `**/LaunchAgents/**`
- `**/*cron*` `**/*watch*` `**/*daemon*` `**/*hotkey*`
- anything referencing HOME drift roots

## Next actions
A) Produce a VERIFIED MAP (read-only) of ronny-ops:
- top-level pillars
- runtime/drift indicators
- infra/doc-only candidates

B) Decide Option A vs Option B:
- **Option A (lowest risk):** vendor docs/config only + manifest + index
- **Option B:** vendor docs/config + inert code surfaces (still no runtime)
