---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: proposal-flow-quickstart
---

# Proposal Flow Quickstart

Use this sequence for mailroom-gated writes:

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run proposals.submit "your change summary"
./bin/ops cap run proposals.status
echo "yes" | ./bin/ops cap run proposals.apply CP-YYYYMMDD-HHMMSS__your-change
```

## Change Action Contract

Proposal manifests only support `create|modify|delete` actions (`created|update|edit|api-write|remove` normalize to those canonical values).
`append` is not a valid action and will be rejected by `proposals.apply`.

## Admission Routing Contract

`proposals.apply` always evaluates loop/gap governance route checks by sending
`--capability proposals.apply` into `verify.route.recommend` equivalent routing.
This guarantees `loop_gap` domain evaluation even when changed file paths are sparse
or do not match existing path trigger inventories.

## Workbench Preflight Behavior

When a proposal touches `/Users/ronnyworks/code/workbench/**`, `proposals.apply` runs:

```bash
/Users/ronnyworks/code/workbench/scripts/root/aof/workbench-aof-check.sh --mode all --changed-files <paths...>
```

Blocking policy:
1. `P0` or `P1` findings block apply.
2. `P2` findings warn only.

Typical failure pattern:

```text
ERROR: Workbench AOF preflight failed (P0/P1). Proposal apply blocked.
Workbench preflight summary: summary: P0=0 P1=2 P2=1 total=3
```

Repair flow:
1. Fix the reported workbench files.
2. Re-run checker directly:
   `cd /Users/ronnyworks/code/workbench && ./scripts/root/aof/workbench-aof-check.sh --mode all --changed-files <same-paths>`
3. Re-run apply:
   `echo "yes" | ./bin/ops cap run proposals.apply <CP-ID>`

Environment remediation if root path check fails:
```bash
export WORKBENCH_ROOT=/Users/ronnyworks/code/workbench
```
