---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-27
scope: tailscale-ssh-lifecycle-operations
---

# Tailscale + SSH Lifecycle Operations Runbook

## Authority

- `docs/CANONICAL/TAILSCALE_AUTHORITY_CONTRACT_V1.yaml`
- `docs/CANONICAL/SSH_IDENTITY_LIFECYCLE_CONTRACT_V1.yaml`
- `ops/bindings/tailscale.ssh.lifecycle.contract.yaml`

## 1) Tailscale Auth Incident Playbook

Trigger symptoms:
- monitor output includes `tailscale ssh requires an additional check`
- monitor output includes `to authenticate, visit:` or `login.tailscale.com`
- monitor lane state flips to `BLOCKED_AUTH`

Procedure:
1. Run monitor in JSON mode:
   `./ops/plugins/communications/bin/communications-mail-archiver-import-monitor --json`
2. If `lane_state=BLOCKED_AUTH`, stop automated retries immediately.
3. Confirm state artifact:
   `mailroom/state/communications/mail-archiver-import-monitor.state.yaml`
4. Human operator performs interactive remediation outside machine monitor path:
   - inspect node auth state in Tailscale admin console
   - resolve auth challenge manually
5. Re-run monitor once:
   `./ops/plugins/communications/bin/communications-mail-archiver-import-monitor --json`
6. If recovered (`HEALTHY`/`DEGRADED`), resume normal schedule.
7. If still blocked, file/update gap and attach state artifact.

## 2) VM/Site Onboarding Checklist

Required before `status: active`:
1. `vm.lifecycle.yaml`
   - `status` is `registered` then `active`
   - `tailscale_ip` non-empty
   - `ssh_target` and `ssh_user` set
2. `ssh.targets.yaml`
   - entry exists for `vm.lifecycle.ssh_target`
   - `host` equals lifecycle `tailscale_ip`
3. `SERVICE_REGISTRY.yaml`
   - `hosts.<hostname>.tailscale_ip` matches lifecycle
   - `hosts.<hostname>.ssh` matches lifecycle `ssh_target`
4. Workbench parity contract still anchored:
   - `ops/bindings/workbench.ssh.attach.contract.yaml`
5. Run report-mode gates:
   - `D258`, `D259`, `D260`, `D261`, `D262`
6. Run pack verification:
   - `./bin/ops cap run verify.pack.run communications`
   - `./bin/ops cap run verify.pack.run secrets`
   - `./bin/ops cap run verify.pack.run mint`

## 3) Monitor Behavior SOP

Machine monitors must:
- use single-flight lock
- remain non-interactive
- classify auth challenges as `BLOCKED_AUTH`
- stop retries on blocked-auth

Canonical monitor:
- `ops/plugins/communications/bin/communications-mail-archiver-import-monitor`

State and lock artifacts:
- state: `mailroom/state/communications/mail-archiver-import-monitor.state.yaml`
- lock: `mailroom/state/locks/mail-archiver-import-monitor.lock`

Expected policy:
- `lane_state=BLOCKED_AUTH` when auth URL/check detected
- `retry_allowed=false` in blocked-auth state

## 4) Decommission and Tombstone Workflow

When retiring a VM/site/target:
1. Move VM to `status: decommissioned` in `vm.lifecycle.yaml`.
2. Deprecate or retire related service entries in `SERVICE_REGISTRY.yaml`.
3. Remove or tombstone SSH target in `ssh.targets.yaml`.
4. If legacy external path remains as reference only, add tombstone entry in:
   `ops/bindings/tailscale.ssh.lifecycle.contract.yaml`.
5. Run gates `D258-D262` in report mode and confirm no unresolved critical findings.
6. Capture decision and artifact links in lane receipt.
