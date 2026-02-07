# CORE_LOCK v1.0

**Locked:** 2026-02-07
**Status:** ACTIVE
**Gate Version:** drift-gate.sh v2.3

---

## Core SSOT Paths

| Surface | Canonical Path | Env Override |
|---------|---------------|--------------|
| Mailroom | `$SPINE_REPO/mailroom/` | - |
| Inbox | `$SPINE_REPO/mailroom/inbox/` | `SPINE_INBOX` |
| Outbox | `$SPINE_REPO/mailroom/outbox/` | `SPINE_OUTBOX` |
| State | `$SPINE_REPO/mailroom/state/` | `SPINE_STATE` |
| Logs | `$SPINE_REPO/mailroom/logs/` | `SPINE_LOGS` |
| Receipts | `$SPINE_REPO/receipts/sessions/` | - |

## Runtime Model

**Single runtime: Mailroom**

All work (terminal and daemon) flows through mailroom:
- Terminal commands enqueue to `mailroom/inbox/queued/`
- Watcher processes through lanes: `queued/ → running/ → done/ | failed/`
- Every run produces: outbox result + receipt + ledger entry

## Identity System

**Single identity: run_key**

Watcher format: `<session>__<slug>__R<id>`  
Capability format: `CAP-<timestamp>__<capability>__R<id>`

This key is used everywhere:
- Outbox result: `<run_key>__RESULT.md`
- Receipt folder: `receipts/sessions/R<run_key>/`
- Ledger row: `run_id` column (latest row per run_id is authoritative state)

## Entry Points

| Entry | Path | Purpose |
|-------|------|---------|
| CLI | `bin/ops` | Human entrypoint (enqueues to mailroom) |
| Watcher | `ops/runtime/inbox/hot-folder-watcher.sh` | Daemon runtime |
| LaunchAgent | `com.ronny.agent-inbox` | **Canonical** persistent watcher |

**Launchd is the only canonical watcher runtime.** Do not manually run `hot-folder-watcher.sh` in production; use launchd via `ops cap run spine.watcher.restart` for restarts. Manual runs are for debugging only.

## Drift Gates

All must PASS for core to be healthy:

| Gate | Enforces |
|------|----------|
| D1 | Top-level dirs bounded (allowlist enforced) |
| D2 | No `runs/` directory |
| D3 | Entrypoint smoke (`bin/ops preflight`) |
| D4 | Watcher running (warn only) |
| D5 | No legacy coupling (`~/agent`, `ronny-ops`) |
| D6 | Receipts exist for recent sessions |
| D7 | Executables only in allowed zones |
| D8 | No backup clutter |
| D10 | Logs under mailroom only |
| D11 | `~/agent` is symlink to mailroom |
| D12 | This file exists |
| D13 | API capability secrets preconditions |
| D14 | Cloudflare surface drift (no legacy smells) |
| D15 | GitHub Actions surface drift (read-only, no leaks) |
| D16 | Docs quarantine (no competing truths) |
| D17 | Root allowlist (no drift magnets at root) |
| D18 | Docker compose surface drift (read-only) |
| D19 | Backup surface drift (read-only, no secret printing) |
| D20 | Secrets surface drift (non-leaky, read-only) |
| D22 | Nodes surface drift (read-only SSH, no credentials) |
| D23 | Services health surface drift (no verbose curl) |
| D24 | GitHub labels surface drift (read-only, no mutations) |
| D25 | Secrets CLI canonical lock (spine tooling required; external parity advisory) |
| D26 | Agent startup read-surface and host/service route lock |
| D27 | Fact duplication lock for startup/governance read docs |
| D28 | Archive runway lock (active legacy absolute paths + extraction queue contract) |
| D29 | Active entrypoint lock (launchd/cron ronny namespace cannot execute from ronny-ops without valid exception) |
| D30 | Active config lock (legacy refs + plaintext secret patterns) |
| D31 | Home output sink lock (home-root logs/out/err not allowlisted) |
| D32 | Codex instruction source lock (`~/.codex/AGENTS.md` must resolve to spine AGENTS) |
| D33 | Extraction pause lock (`ops/bindings/extraction.mode.yaml` must remain `mode: paused`) |
| D34 | Loop ledger integrity lock (summary counts must match deduped reducer output) |
| D35 | Infra relocation parity lock (cross-SSOT consistency for service moves during cutover/cleanup) |
| D36 | Legacy exception hygiene lock (stale/near-expiry exception enforcement) |
| D37 | Infra placement policy lock (canonical site/hypervisor/vmid/service target enforcement) |
| D38 | Extraction hygiene lock (EXTRACTION_PROTOCOL enforcement) |
| D39 | Infra hypervisor identity lock (active relocation states must pass identity invariants) |
| D40 | Maker tools drift lock (binding validity, script hygiene, no debug/secret/tmp leaks) |
| D41 | Hidden-root governance lock (home-root inventory + forbidden pattern enforcement) |
| D42 | Code path case lock (runtime scripts must use `$HOME/code` not `$HOME/Code`) |
| D43 | Secrets namespace policy lock (freeze legacy root-path debt + enforce /spine namespace wiring) |
| D44 | CLI tools discovery lock (inventory + cross-refs + probes) |
| D45 | Naming consistency lock (cross-file identity surface verification) |
| D46 | Claude instruction source lock (shim compliance + path case enforcement) |
| D47 | Brain surface path lock (no `.brain/` references in runtime scripts) |

## Rules

1. **No new runtime surfaces outside mailroom**
2. **If gates pass, core is healthy**
3. **Legacy is archived, never deleted** (`.archive/`)
4. **All work produces receipts** (no exceptions)
5. **Provider/model recorded in every receipt**

## Archived Legacy

Located in `.archive/` (excluded from gates, recoverable):
- `legacy-root/runs/` - old CLI run traces
- `legacy-root/examples/` - old CLI examples
- `legacy-root/tasks/` - old CLI tasks
- `surfaces/quarantine/` - deprecated scripts
- `bin/ops-import-info-only.sh` - one-time import tool

---

_If this file is missing, the repo is not a valid spine core._
