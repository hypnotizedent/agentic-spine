# W69 Registration Hardening Report

wave_id: W69_BRANCH_DRIFT_AND_REGISTRATION_HARDENING_20260228
scope: registration_completeness

## Required Gate Repairs

| gate_id | issue | change_applied | verification |
|---|---|---|---|
| D79 | Missing workbench scripts in allowlist | Added `scripts/root/mounts/mint-storage-contract-guard.sh` and `scripts/root/mcp/mcp-parity-check.sh` to `ops/bindings/workbench.script.allowlist.yaml`. | `D79 PASS: workbench script allowlist lock enforced` |
| D84 | Missing governance runbook index registration | Added `TAILSCALE_SSH_LIFECYCLE_OPERATIONS_RUNBOOK.md` entry in `docs/governance/_index.yaml`. | `D84 PASS: docs index registration valid` |
| D85 | Missing TRIAGE headers in gate scripts | Added `# TRIAGE:` headers to `d225,d251,d258,d259,d260,d261,d262,d291`. | `D85 PASS: gate registry parity lock enforced (289 gates, 288 active, 1 retired)` |
| D31 | Missing mailroom bridge sink allowlist | Added `"/Users/ronnyworks/code/.runtime/spine-mailroom/logs/"` prefix to `ops/bindings/home.output.sinks.yaml`. | `D31 PASS: home output sink lock enforced` |

## Changed Files

- `ops/bindings/workbench.script.allowlist.yaml`
- `docs/governance/_index.yaml`
- `ops/bindings/home.output.sinks.yaml`
- `surfaces/verify/d225-mint-live-before-auth-lock.sh`
- `surfaces/verify/d251-nightly-closeout-lifecycle-lock.sh`
- `surfaces/verify/d258-ssh-lifecycle-cross-registry-parity-lock.sh`
- `surfaces/verify/d259-onboarding-canonical-registration-lock.sh`
- `surfaces/verify/d260-noninteractive-monitor-access-lock.sh`
- `surfaces/verify/d261-auth-loop-blocked-auth-guard-lock.sh`
- `surfaces/verify/d262-ssh-tailscale-duplicate-truth-lock.sh`
- `surfaces/verify/d291-gate-budget-add-one-retire-one-lock.sh`
