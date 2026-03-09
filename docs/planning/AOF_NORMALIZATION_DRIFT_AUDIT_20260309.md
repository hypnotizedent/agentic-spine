---
status: completed
created: 2026-03-09
updated_at: 2026-03-09
owner: "@ronny"
scope: aof-normalization-cross-plane-audit
authority: runtime-admission-health-normalization-wave
---

# AOF Normalization Drift Audit — 2026-03-09

## Executive Summary

Cross-plane normalization is complete for the active runtime/deploy/health control plane.

The recurring Firefly / Mint / SSH confusion traced back to one pattern:
- health probes, deploy scripts, and helper surfaces were choosing hosts with different rules
- Mint HTTP health metadata existed in two bindings
- some operator-facing scripts still taught raw-IP workflows
- assertion-grade health automation was not consistently using strict exit semantics

The canonical model is now:
- `ops/lib/ssh-resolve.sh` is the only resolver contract
- `ssh_resolve_ssh_host_with_fallback` is the SSH/deploy resolver
- `ssh_resolve_host_with_fallback` is only for non-SSH host reachability
- `ops/bindings/services.health.yaml` is the canonical HTTP health source
- `ops/bindings/mint.probe.targets.yaml` carries only Mint-only non-HTTP metadata
- assertion-grade automation uses `--strict-exit`

## Drift Classes Closed

### 1. Resolver-policy split

Fixed:
- deploy and docker mutation scripts now use `ssh_resolve_ssh_host_with_fallback`
- `D389` enforces TCP/22 resolver use for SSH deploy/mutation surfaces

Result:
- health/deploy no longer choose different reachability rules for the same target class

### 2. Duplicate Mint HTTP probe truth

Fixed:
- Mint HTTP port/path definitions now derive from `ops/bindings/services.health.yaml`
- `ops/lib/mint-health-surface.sh` is the projection helper
- `ops/bindings/mint.probe.targets.yaml` no longer stores `http_checks`
- `D390` enforces that projection model

Result:
- one canonical Mint HTTP health surface
- no dual naming (`payment` vs `payment-v2`) inside active Mint health consumers

### 3. Hardcoded operator IP residue

Fixed for active operational scripts:
- `payment-stripe-test-canary-inner` now resolves `mint-apps` through the shared resolver
- `ghostfolio-portfolio-status` now derives host/port from `services.health.yaml`
- `media-queue-reconcile` now derives Radarr from `services.health.yaml`
- auth deploy helpers now resolve `mint-apps` through the shared resolver

Clarification:
- authoritative inventory/binding files may still contain IP literals as canonical data
- those are not parallel truth by themselves; the drift was operational scripts bypassing the resolver/binding layer

### 4. Non-strict assertion semantics

Fixed:
- `lane-standard-run` now calls `services.health.status --strict-exit`
- `loop-daily` now calls `mint.modules.health --strict-exit`
- `D391` enforces strict assertion usage for those automation surfaces

Result:
- assertion-grade automation now fails when health is degraded instead of only printing FAIL

### 5. Stale doctrine teaching split semantics

Fixed:
- `docs/planning/MINT_RUNTIME_PROBE_CONSISTENCY_20260226.md` is now superseded
- `docs/planning/MINT_RUNTIME_GAPS_AUDIT_20260309.md` was already superseded by resolver normalization work
- this document now records the completed boring model instead of an in-progress recommendation set

## Canonical Boring Model

### Resolver rules

- Use `ssh_resolve_ssh_host_with_fallback` for:
  - deploy
  - docker remote operations
  - SSH-backed proofs
  - SSH-backed mutation helpers

- Use `ssh_resolve_probe_host` / `ssh_resolve_url_with_fallback` for:
  - HTTP probe paths
  - HTTP-only health surfaces

- Do not use ping-based resolution to decide SSH deploy reachability.

### Health rules

- `services.health.yaml` is the global HTTP health authority
- `mint.probe.targets.yaml` carries only:
  - plane target ids
  - VM ids
  - Mint-only SSH checks
  - proof routes
  - claim policy

### Assertion rules

- human status surfaces may support non-strict output
- automation/gates that treat health as an assertion must use `--strict-exit`

## Gates

- `D389` `resolver-ssh-deployment-parity-lock`
  - enforce TCP/22 resolver usage for SSH deploy/mutation scripts

- `D390` `mint-probe-health-projection-lock`
  - enforce that Mint HTTP health truth lives only in `services.health.yaml`

- `D391` `assertion-health-strictness-lock`
  - enforce strict-exit semantics in assertion-grade automation surfaces

## Verification

Verified after normalization:
- `D389`: PASS
- `D390`: PASS
- `D391`: PASS
- `services.health.status --strict-exit`: PASS
- `mint.modules.health --strict-exit`: PASS

## Final State

The active AOF control plane is now normalized enough that future agents should not have to guess:
- which resolver to use
- which Mint health binding is canonical
- whether a passing health command is assertion-grade
- whether a raw IP in an operator script is authoritative or drift

The remaining IP literals in authoritative binding data are intentional inventory, not split operational truth.
