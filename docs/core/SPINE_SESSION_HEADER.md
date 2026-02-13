# Spine Session Header (Canonical)

> **Status:** authoritative
> **Last verified:** 2026-02-10

Copy this block into any new session working on agentic-spine.

```
BEGIN SPINE
Authority: agentic-spine only. No ronny-ops runtime. No HOME drift roots.
Baseline: main / tag v0.1.24-spine-canon.
Front door: ./bin/ops (capabilities + mailroom + receipts).
Admissible proof: RCAP receipts under agentic-spine/receipts/sessions/.
Drift gates: D1–D82 (82 active) ALL PASS (surfaces/verify/drift-gate.sh v2.7).

Root Structure (D17 locked):
  bin/           → Front door (./bin/ops)
  ops/           → Capabilities, plugins, bindings, runtime
  surfaces/      → Verify gates (D1–D82)
  docs/core/     → Canonical docs (D16)
  docs/brain/    → Agent context + lessons
  docs/governance/ → SSOTs, policies, runbooks
  mailroom/      → Runtime lanes (inbox/outbox/state)
  receipts/      → RCAP audit trail
  fixtures/      → Replay baseline
  FORBIDDEN: agents/, _imports/, runs/

Secrets canon (locked + enforced):
  Binding SSOT: ops/bindings/secrets.binding.yaml
  Auth hydration: source ~/.config/infisical/credentials (perm 600)
  Exec: ./bin/ops cap run secrets.exec -- <cmd>
  API preconditions rule: any API-touching capability MUST declare:
    requires: [secrets.binding, secrets.auth.status, secrets.projects.status]
  (enforced by .requires[] + D13 gate)

STOP RULE:
If any READY CHECK fails → STOP and fix spine core before any other work.
END SPINE
```

## When to use

- Paste at the start of any Claude Code / agent session
- Ensures baseline is understood before any extraction work
- Prevents drift by making authority explicit
