# W62-B Metadata Debt Register

Status: final
Wave: LOOP-SPINE-W62B-LEARNING-SYSTEM-20260228
Owner: @ronny
Purpose: enumerate missing metadata required to fully generate a single boot manifest from governed registries.

## Scope

- This register is report-only for W62-B.
- Debt counts were measured from live registry files using deterministic parser checks.

## Debt Inventory

| debt_id | missing_field | missing_count | target_file | owner | expiry_check | impact_on_boot_manifest | evidence_command |
|---|---|---:|---|---|---|---|---|
| W62B-MD-001 | `services.*.tier` | 83 | `docs/governance/SERVICE_REGISTRY.yaml` | `@ronny` | 2026-03-15 | cannot derive service criticality policy class for generated boot manifest | `python3` YAML check on `SERVICE_REGISTRY.yaml` |
| W62B-MD-002 | `services.*.verify_domain` | 83 | `docs/governance/SERVICE_REGISTRY.yaml` | `@ronny` | 2026-03-15 | cannot generate deterministic verify domain mapping from service entries | `python3` YAML check on `SERVICE_REGISTRY.yaml` |
| W62B-MD-003 | `services.*.startup_sequence` | 83 | `docs/governance/SERVICE_REGISTRY.yaml` | `@ronny` | 2026-03-15 | cannot generate ordered boot dependency plan from service registry alone | `python3` YAML check on `SERVICE_REGISTRY.yaml` |
| W62B-MD-004 | `roles.*.verify_scope_default` | 16 | `ops/bindings/terminal.role.contract.yaml` | `@ronny` | 2026-03-22 | terminal-role -> verify scope projection cannot be generated deterministically | `python3` YAML check on `terminal.role.contract.yaml` |
| W62B-MD-005 | `roles.*.boot_manifest_segment` | 16 | `ops/bindings/terminal.role.contract.yaml` | `@ronny` | 2026-03-22 | generated boot manifest cannot attach role-specific startup segments | `python3` YAML check on `terminal.role.contract.yaml` |
| W62B-MD-006 | `agents.*.status` | 12 | `ops/bindings/agents.registry.yaml` | `@ronny` | 2026-03-22 | boot generator cannot distinguish active/planned agent runtime entries from registry only | `python3` YAML check on `agents.registry.yaml` |
| W62B-MD-007 | `concerns.*.owner` | 7 | `ops/bindings/authority.concerns.yaml` | `@ronny` | 2026-03-22 | concern-level escalation/approval routing unavailable in generated manifest | `python3` YAML check on `authority.concerns.yaml` |
| W62B-MD-008 | `concerns.*.expiry_check` | 7 | `ops/bindings/authority.concerns.yaml` | `@ronny` | 2026-03-22 | generated manifest cannot enforce concern freshness revalidation windows | `python3` YAML check on `authority.concerns.yaml` |

## Deterministic Extraction Command

```bash
python3 - <<'PY'
import yaml
from pathlib import Path
root=Path('/Users/ronnyworks/code/agentic-spine')
sr=yaml.safe_load(open(root/'docs/governance/SERVICE_REGISTRY.yaml'))
tr=yaml.safe_load(open(root/'ops/bindings/terminal.role.contract.yaml'))
ag=yaml.safe_load(open(root/'ops/bindings/agents.registry.yaml'))
ac=yaml.safe_load(open(root/'ops/bindings/authority.concerns.yaml'))
print('service_tier_missing', sum(1 for _,v in sr['services'].items() if 'tier' not in v))
print('service_verify_domain_missing', sum(1 for _,v in sr['services'].items() if 'verify_domain' not in v))
print('service_startup_sequence_missing', sum(1 for _,v in sr['services'].items() if 'startup_sequence' not in v))
print('role_verify_scope_missing', sum(1 for r in tr.get('roles',[]) if 'verify_scope_default' not in r))
print('role_boot_segment_missing', sum(1 for r in tr.get('roles',[]) if 'boot_manifest_segment' not in r))
print('agent_status_missing', sum(1 for a in ag.get('agents',[]) if 'status' not in a))
print('concern_owner_missing', sum(1 for _,c in ac.get('concerns',{}).items() if 'owner' not in c))
print('concern_expiry_missing', sum(1 for _,c in ac.get('concerns',{}).items() if 'expiry_check' not in c))
PY
```
