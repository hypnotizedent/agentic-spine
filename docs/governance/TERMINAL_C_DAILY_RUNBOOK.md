---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-16
scope: terminal-c-orchestration
---

# TERMINAL_C_DAILY_RUNBOOK

## Purpose
Canonical operating model for parallel terminal work without collisions.

## Planes
1. Control Plane: SPINE-CONTROL-01 only. Opens loops, issues lane tickets, validates handoffs, integrates to `main`, closes loops.
2. Execution Plane: Worker terminals only (e.g. DOMAIN-HA-01, RUNTIME-IMMICH-01). One lane per terminal, code only, no integration.
3. Observation Plane: SPINE-AUDIT-01 only. Read-only status checks first; no writes unless explicitly approved.

## Canonical Terminal Names
| Name | Type | Scope |
|------|------|-------|
| SPINE-CONTROL-01 | control-plane | bin/, ops/, surfaces/, docs/governance/, docs/core/, docs/product/, docs/brain/, mailroom/ |
| SPINE-AUDIT-01 | observation | receipts/, docs/governance/_audits/ |
| RUNTIME-IMMICH-01 | domain-runtime | ops/plugins/immich/, ops/bindings/immich.* |
| DOMAIN-HA-01 | domain-runtime | ops/plugins/ha/, ops/bindings/ha.*, z2m.*, home.* |
| DEPLOY-MINT-01 | domain-runtime | ops/plugins/mint/, docs/governance/MINT_* |

Formal contract: `ops/bindings/terminal.role.contract.yaml`

## Non-Negotiables
1. `Ctrl+Shift+S/C/O` are solo launchers only. They are never worker lane entrypoints.
2. Worker terminals must launch with explicit `--role worker --lane <D|E|F|G>`.
3. SPINE-CONTROL-01 is the only terminal allowed to run `orchestration.integrate --apply`.
4. Do not use fallback mode unless emergency recovery is explicitly declared.
5. Stop immediately on any failed gate.

## Gate 0: Baseline
Daily flow is predictive-first. Run from `~/code/agentic-spine`:

```bash
cd ~/code/agentic-spine
./bin/ops cap run stability.control.snapshot
```

If `stability.control.snapshot` fails, stop immediately. Run guided planning:

```bash
./bin/ops cap run stability.control.reconcile
```

Execute only the printed recovery commands manually (operator-controlled), then re-run snapshot until green.
Only after snapshot is healthy, continue day-to-day checks:

```bash
./bin/ops cap run verify.core.run
./bin/ops cap run verify.route.recommend
./bin/ops cap run secrets.runway.status
./bin/ops cap run workbench.impl.audit --strict
./bin/ops cap run gaps.status
./bin/ops cap run orchestration.status
```

`secrets.runway.status` is the canonical pre-mutation secrets runway check:
it validates required domain keys and audits compose stacks so new secret keys
cannot drift without an explicit project/path route.

## Weekly Workbench AOF Sweep

Run once per week (SPINE-AUDIT-01 or SPINE-CONTROL-01):

```bash
cd /Users/ronnyworks/code/workbench
./scripts/root/aof/workbench-aof-check.sh --mode all --format text --explain

cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run proposals.status
```

Escalation:
1. Any `P0`/`P1` finding => stop proposal applies touching workbench until resolved.
2. Open/update loop scope and publish an audit note under `docs/governance/_audits/`.

## Nightly / Release Certification

Use full-suite verification for nightly/release only (not day-to-day):

```bash
./bin/ops cap run spine.verify
```

## Gate 1: Open Loop
Set values:

```bash
LOOP_ID="LOOP-<FEATURE>-$(date +%Y%m%d)"
TARGET_REPO="/Users/ronnyworks/code/<repo>"
BASE_SHA="$(git -C "$TARGET_REPO" rev-parse HEAD)"
```

Open orchestration manifest:

```bash
./bin/ops cap run orchestration.loop.open \
  --loop-id "$LOOP_ID" \
  --apply-owner SPINE-CONTROL-01 \
  --repo "$TARGET_REPO" \
  --base-sha "$BASE_SHA" \
  --lanes D,E,F \
  --sequence D,E,F \
  --allow D:'<scope-D>/**' \
  --allow E:'<scope-E>/**' \
  --allow F:'<scope-F>/**'
```

## Gate 2: Issue Lane Tickets
```bash
./bin/ops cap run orchestration.ticket.issue --loop-id "$LOOP_ID" --lane D --branch worker/<feature>-D --worker DOMAIN-HA-01
./bin/ops cap run orchestration.ticket.issue --loop-id "$LOOP_ID" --lane E --branch worker/<feature>-E --worker RUNTIME-IMMICH-01
./bin/ops cap run orchestration.ticket.issue --loop-id "$LOOP_ID" --lane F --branch worker/<feature>-F --worker DEPLOY-MINT-01
./bin/ops cap run orchestration.status --loop-id "$LOOP_ID"
```

## Worker Launch Contract
Send each worker one explicit launch command (example lane D):

```bash
SPINE_HOTKEY_ORCH_MODE=capability SPINE_HOTKEY_ALLOW_FALLBACK=0 \
~/code/workbench/scripts/root/spine_terminal_entry.sh \
--role worker --loop-id "$LOOP_ID" --lane D --tool claude
```

Use `--tool codex` or `--tool opencode` as needed.

## Gate 3: Validate + Integrate (Terminal C Only)
Run per lane in sequence order:

```bash
./bin/ops cap run orchestration.handoff.validate --loop-id "$LOOP_ID" --lane D --commit <sha-D>
./bin/ops cap run orchestration.integrate       --loop-id "$LOOP_ID" --lane D --commit <sha-D> --apply

./bin/ops cap run orchestration.handoff.validate --loop-id "$LOOP_ID" --lane E --commit <sha-E>
./bin/ops cap run orchestration.integrate       --loop-id "$LOOP_ID" --lane E --commit <sha-E> --apply

./bin/ops cap run orchestration.handoff.validate --loop-id "$LOOP_ID" --lane F --commit <sha-F>
./bin/ops cap run orchestration.integrate       --loop-id "$LOOP_ID" --lane F --commit <sha-F> --apply
```

If validation fails for any lane, stop integration, return lane to worker, and re-validate.

### Multi-Repo Loops
If the loop declares `related_repos`, integrate validates all related repos are clean before
each apply. Terminal C must integrate each repo separately in declared order. If any apply
fails, stop and resolve before continuing to the next repo.

## Gate 4: Close Loop
```bash
./bin/ops cap run verify.core.run
./bin/ops cap run gaps.status
./bin/ops cap run orchestration.loop.close --loop-id "$LOOP_ID"
./bin/ops cap run agent.session.closeout
```

If this loop is a release/cutover loop, run full certification before closeout:

```bash
./bin/ops cap run spine.verify
```

## Post-Loop Hygiene
1. Confirm target repo `main` is clean and synced.
2. Confirm no leftover worker branches for the closed loop.
3. Remove closed-loop deterministic worktrees only after integration is complete.
4. Keep stash count at zero unless explicitly preserving WIP with owner note.

## Watcher Adoption Path
1. Phase 1: Read-only watcher only (`verify.core.run`, `stability.control.snapshot`, `gaps.status`, `orchestration.status`).
2. Phase 2: Proposal/ticket drafting only, no apply.
3. Phase 3: Terminal C approves every apply action.
4. Phase 4: Allow limited autonomous apply for low-risk lanes only.

## Operator Reminder
If you are about to run coding commands in SPINE-CONTROL-01, stop. SPINE-CONTROL-01 is control plane only.
