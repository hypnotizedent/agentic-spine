---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: build-mode-execution
---

# Build Mode Checklist

> Fast operator checklist for governed changes with explicit stop gates.

---

## 1) Pre-Change Gate (Required)

Run in order:

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops status
./bin/ops cap run spine.verify
./bin/ops cap run gaps.status
```

Stop if:
- `spine.verify` fails.
- open work contains unlinked gaps you are about to bypass.
- another terminal/agent is actively mutating same surface.

---

## 2) Choose Execution Path

Use this command rule:

```text
single read-only check      -> ops cap run <read-only>
single governed mutation    -> ops cap run <mutating>
context/evidence note only  -> ops run --inline "..."
multi-step/cross-surface    -> proposal flow
```

Proposal flow:

```bash
./bin/ops cap run proposals.submit "<change summary>"
# edit CP payload
./bin/ops cap run proposals.apply <CP-ID>
```

Stop if:
- change spans multiple files/surfaces and you are not in proposal flow.
- action requires manual approval and no explicit approval path is captured.

---

## 3) In-Flight Safety Checks

- keep writes inside declared scope only.
- generate receipts for every governed action.
- do not mutate `ops/bindings/operational.gaps.yaml` directly.

Recommended in-flight checks:

```bash
./bin/ops cap run verify.drift_gates.certify
./bin/ops cap run host.drift.audit
```

---

## 4) Definition of Done (By Change Type)

### Read-Only Discovery
- receipt exists
- no file mutations
- decision/evidence logged (`run --inline` if needed)

### Single Capability Mutation
- capability receipt exists
- `spine.verify` passes after mutation
- relevant domain status capability passes

### Proposal-Based Change
- CP payload complete (`manifest.yaml`, `receipt.md`, `files/...`)
- all YAML parses clean
- no secret-like content in payload
- `proposals.apply` succeeds and commit boundary is clean

### Onboarding Change (VM/Agent/Capability/Tool/Surface)
- onboarding playbook steps completed
- required artifacts created/updated
- gate set for that lifecycle passes
- loop/closeout receipts captured

---

## 5) Closeout Gate (Required)

```bash
./bin/ops cap run spine.verify
./bin/ops cap run agent.session.closeout
```

Stop if:
- verification regresses after change.
- closeout indicates stale or untraceable work.
