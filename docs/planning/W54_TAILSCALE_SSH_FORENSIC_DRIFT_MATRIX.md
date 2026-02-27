---
status: authoritative
owner: "@ronny"
created: 2026-02-27
scope: w54-tailscale-ssh-forensic-drift-matrix
parent_loop: LOOP-SPINE-W54-TAILSCALE-SSH-LIFECYCLE-CANONICALIZATION-20260227-20260301-20260227
---

# W54 Tailscale + SSH Forensic Drift Matrix

## Scope

- Primary mutable repo: `/Users/ronnyworks/code/agentic-spine`
- Parity references (read-only): `/Users/ronnyworks/code/workbench`, `/Users/ronnyworks/code/mint-modules`
- Runtime mutation: none

## Runtime Forensics (Read-Only)

- `tailscale status --self`: 23 peers visible; no monitor-side command evidence of `tailscale login` or `tailscale ssh`.
- `tailscale debug prefs`:
  - `RunSSH=false`
  - `WantRunning=true`
  - `LoggedOut=false`
- `tailscale serve status`: active local tailnet proxy on macbook to `127.0.0.1:8799`.

## Drift Matrix

| # | Finding | Class | Evidence | Action |
|---|---|---|---|---|
| 1 | No canonical Tailscale authority contract existed in repo. | contract-needed | No `docs/CANONICAL/*TAILSCALE*` contract file in baseline. | Add `TAILSCALE_AUTHORITY_CONTRACT_V1.yaml`. |
| 2 | No canonical SSH lifecycle contract existed in repo. | contract-needed | No `docs/CANONICAL/*SSH*LIFECYCLE*` contract file in baseline. | Add `SSH_IDENTITY_LIFECYCLE_CONTRACT_V1.yaml`. |
| 3 | No machine-readable lifecycle policy contract linking preflight, monitor policy, and tombstones. | contract-needed | Missing `ops/bindings/tailscale.ssh.lifecycle.contract.yaml`. | Add binding contract + gate coverage. |
| 4 | Machine monitor auth-loop behavior existed only as implicit/undocumented behavior. | barrier-needed | No monitor wrapper for mail-archiver import in baseline branch head. | Add monitor wrapper with single-flight + blocked-auth state machine. |
| 5 | No explicit policy enforcing noninteractive machine monitor transport modes. | barrier-needed | No dedicated gate for machine monitor transport policy. | Add D260. |
| 6 | Cross-registry parity relied on older gates but lacked explicit SSH lifecycle gate for vm ssh_target + SERVICE_REGISTRY ssh parity. | drift | Existing D69 checks hostname-based path; no dedicated vm.ssh_target-centric parity lock. | Add D258. |
| 7 | Active/registered onboarding was enforced indirectly and not explicitly tied to tailscale+ssh registration-before-active policy. | drift | No dedicated gate framing registration requirement as a lifecycle lock. | Add D259. |
| 8 | Hostname to ssh-target divergence (`homeassistant` -> `ha`) was present without explicit lifecycle override registry. | duplicate-truth | `vm.lifecycle.yaml` active hostname differs from `ssh_target`; no explicit override table. | Add approved alias override contract + D262 check. |
| 9 | Legacy Tailscale governance doc in workbench remained a competing reference path. | tombstone-needed | `/workbench/docs/legacy/infrastructure/runbooks/TAILSCALE_GOVERNANCE.md`. | Add explicit tombstone record in lifecycle contract. |
| 10 | Legacy bootstrap scripts still carry machine-incompatible `tailscale up` guidance. | tombstone-needed | `/workbench/scripts/root/bootstrap/new-vm.sh`, `/new-lxc.sh`. | Tombstone for machine-monitor context, preserve as human bootstrap reference only. |
| 11 | Ambient out-of-scope untracked artifacts repeatedly blocked feature-lane startup under global-clean interpretation. | runbook-needed | `agentic-spine/docs/governance/_audits/SPINE_SCHEMA_CONVENTIONS_AUDIT_20260227.md`, `workbench/agents/media/.spine-link.yaml`. | Move to `SCOPE_CLEAN_REQUIRED` policy + cleanup lane gap. |
| 12 | No single runbook captured auth incident, onboarding checklist, monitor SOP, and tombstone workflow for tailscale+ssh lifecycle. | runbook-needed | Domain runbooks cover partial slices only. | Add lifecycle operations runbook. |

## Classification Totals

- `canonical`: 0
- `drift`: 2
- `duplicate-truth`: 1
- `tombstone-needed`: 2
- `barrier-needed`: 2
- `contract-needed`: 3
- `runbook-needed`: 2

## Protected-Lane Attestation

- `LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226`: untouched
- `GAP-OP-973`: untouched
- Active EWS import lanes: untouched
- Active MD1400 rsync lanes: untouched
