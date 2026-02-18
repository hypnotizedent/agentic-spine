---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-18
scope: aof-deployment-playbook
---

# AOF Deployment Playbook

> Step-by-step guide for deploying AOF to a new tenant environment.

## Prerequisites

1. Git repository initialized with AOF spine structure
2. Tenant profile YAML prepared (see `ops/bindings/tenant.profile.schema.yaml`)
3. Policy preset selected (strict / balanced / permissive)
4. Infrastructure targets provisioned (VMs, services, secrets provider)

## Phase 1: Profile Validation

```bash
# Validate tenant profile against schema
./bin/ops cap run tenant.profile.validate -- --profile path/to/tenant.profile.yaml
```

Fix any validation errors before proceeding.

## Phase 2: Dry Run

```bash
# Generate provisioning plan without mutations
./bin/ops cap run tenant.provision.dry-run -- --profile path/to/tenant.profile.yaml
```

Review the plan output. Confirm all targets are correct.

## Phase 3: Binding Configuration

1. Copy tenant profile to `ops/bindings/tenant.profile.yaml`
2. Select policy preset in `ops/bindings/policy.presets.yaml`
3. Configure secrets binding (`ops/bindings/secrets.binding.yaml`)
4. Configure service registry (`docs/governance/SERVICE_REGISTRY.yaml`)

## Phase 4: Gate Verification

```bash
# Run full drift gate suite
./bin/ops cap run spine.verify
```

All gates must pass. Address any failures using `/triage` workflow.

## Phase 5: Acceptance

```bash
# Confirm acceptance gates
./bin/ops cap run spine.verify
./bin/ops cap run tenant.profile.validate -- --profile ops/bindings/tenant.profile.yaml
```

Deployment is complete when both commands exit 0.

## Rollback

AOF is git-based. Rollback = `git revert` of the deployment commit(s).
No external state mutations occur during deployment (all config is file-based).
