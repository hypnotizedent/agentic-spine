#!/usr/bin/env bash
set -euo pipefail

# D451: Backup Plane Subtraction Authority Lock
# Purpose: keep backup readiness tied to the canonical backup plane. Old
# app-local backups must stay retired unless they prove unique data.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INVENTORY="$ROOT/ops/bindings/domains/backup/backup.inventory.yaml"
SCHEDULE="$ROOT/ops/bindings/domains/backup/backup.schedule.yaml"
DOC="$ROOT/docs/governance/domains/backup.md"
CAPS="$ROOT/ops/capabilities.yaml"
VM_LIFECYCLE="$ROOT/ops/bindings/vm.lifecycle.yaml"
READBACK="$ROOT/ops/plugins/core/bin/backup-readback-admission-status"
ESTATE_READBACK="$ROOT/ops/plugins/core/bin/backup-estate-readback-status"
FIRSTBOOT="$ROOT/ops/plugins/infra/host/bin/host-operator-hardware-firstboot-claim"
NORMALIZE="$ROOT/ops/plugins/infra/host/bin/host-operator-hardware-post-boot-normalize"
SURVEILLANCE_BACKUP="$ROOT/ops/plugins/infra/backup/bin/backup-surveillance-config-archive-create"

fail() { echo "D451 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -f "$INVENTORY" ]] || fail "missing backup inventory"
[[ -f "$SCHEDULE" ]] || fail "missing backup schedule"
[[ -f "$DOC" ]] || fail "missing backup domain doc"
[[ -f "$CAPS" ]] || fail "missing capability registry"
[[ -f "$VM_LIFECYCLE" ]] || fail "missing VM lifecycle authority"
[[ -x "$READBACK" ]] || fail "missing legacy backup readback drilldown"
[[ -x "$ESTATE_READBACK" ]] || fail "missing backup estate readback"
[[ -x "$FIRSTBOOT" ]] || fail "missing firstboot claim script"
[[ -x "$NORMALIZE" ]] || fail "missing post-boot normalize script"
[[ -x "$SURVEILLANCE_BACKUP" ]] || fail "missing surveillance config backup script"

python3 - "$INVENTORY" "$SCHEDULE" "$DOC" "$CAPS" "$VM_LIFECYCLE" "$READBACK" "$ESTATE_READBACK" "$FIRSTBOOT" "$NORMALIZE" "$SURVEILLANCE_BACKUP" <<'PY'
import sys
from pathlib import Path

import yaml

inventory_path = Path(sys.argv[1])
schedule_path = Path(sys.argv[2])
doc_path = Path(sys.argv[3])
caps_path = Path(sys.argv[4])
vm_lifecycle_path = Path(sys.argv[5])
readback_path = Path(sys.argv[6])
estate_readback_path = Path(sys.argv[7])
firstboot_path = Path(sys.argv[8])
normalize_path = Path(sys.argv[9])
surveillance_backup_path = Path(sys.argv[10])

RULE = (
    "If the backup plane covers the workload, old app-local backups are debt "
    "unless they protect unique data not captured by the backup plane."
)
RETIRED_TARGETS = {
    "app-mail-archiver",
    "app-mail-archiver-offsite",
    "app-mail-archiver-uploads-offsite",
    "app-mail-archiver-manifest-offsite",
    "app-media-config-media-home",
}
RETIRED_JOBS = {
    "mail-archiver-db-pgdump-daily",
    "mail-archiver-uploads-snapshot-daily",
    "media-config-media-home-cold-sync-daily",
    "media-config-restore-drill-monthly",
}
CLASSIFIED_DISABLED_TARGETS = {
    "vm-offsite-critical": "decommissioned_residue",
    "vm-211-finance-stack-offsite": "decommissioned_residue",
    "vm-213-mint-apps-offsite": "decommissioned_residue",
    "vm-212-mint-data-offsite": "decommissioned_residue",
    "vm-214-communications-stack-offsite": "decommissioned_residue",
    "app-home-assistant": "decommissioned_residue",
    "app-minio": "disabled_by_policy",
    "vm-216-observability-r620-primary": "disabled_by_policy",
}
TEMPLATE_SUBJECTS = {("pve", 9000), ("pve-r620", 9000)}
VM_PREFIXES = ("vm-", "home-vm-", "home-lxc-", "lxc-")


def fail(message: str) -> None:
    print(f"D451 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail(f"invalid YAML mapping: {path}")
    return data


inventory = load_yaml(inventory_path)
schedule = load_yaml(schedule_path)
caps = load_yaml(caps_path)
vm_lifecycle = load_yaml(vm_lifecycle_path)
doc = doc_path.read_text(encoding="utf-8")

capabilities = caps.get("capabilities") or {}
legacy_readback = capabilities.get("backup.readback.admission.status") or {}
if legacy_readback.get("lifecycle") == "ready":
    fail("backup.readback.admission.status must not be lifecycle=ready")
if legacy_readback.get("lifecycle") != "expert_diagnostic":
    fail("backup.readback.admission.status must be lifecycle=expert_diagnostic")
desc = str(legacy_readback.get("description") or "")
if "backup.status" not in desc or "backup.estate.readback.status" not in desc:
    fail("legacy backup readback description must name canonical readbacks")

readback_text = readback_path.read_text(encoding="utf-8")
if "authority_state" not in readback_text or "legacy_drilldown" not in readback_text:
    fail("legacy backup readback output must label authority_state=legacy_drilldown")

estate_readback_text = estate_readback_path.read_text(encoding="utf-8")
for required in [
    'description = str(target_def.get("description") or "")',
    'target_def.get("recovery_alternative")',
    "template_excluded_from_runtime_backup",
    'lifecycle_status == "template"',
]:
    if required not in estate_readback_text:
        fail(f"backup estate readback must retain PACKET-1381 subtraction behavior: {required}")

policy = (
    ((inventory.get("model") or {}).get("authority_policy") or {})
    .get("app_local_backup_subtraction")
    or {}
)
if policy.get("status") != "active":
    fail("app_local_backup_subtraction policy must be active")
if policy.get("rule") != RULE:
    fail("app_local_backup_subtraction policy rule drifted")
if RULE not in doc:
    fail("backup domain doc must state the app-local backup subtraction rule")

targets = inventory.get("targets") or []
if not isinstance(targets, list):
    fail("inventory targets must be a list")
targets_by_name = {row.get("name"): row for row in targets if isinstance(row, dict)}

for target, expected_classification in CLASSIFIED_DISABLED_TARGETS.items():
    row = targets_by_name.get(target)
    if not isinstance(row, dict):
        fail(f"classified disabled target missing from inventory: {target}")
    if row.get("enabled") is not False:
        fail(f"{target} must remain disabled unless explicitly re-admitted")
    description = str(row.get("description") or "").lower()
    if expected_classification == "decommissioned_residue":
        if "decommissioned" not in description and "tombstoned" not in description:
            fail(f"{target} must carry decommissioned/tombstoned evidence for disabled readback classification")
    elif expected_classification == "disabled_by_policy":
        if not any(marker in description for marker in ["adequate recovery surface", "vm-level-only backup", "no_recurring_vzdump policy"]):
            fail(f"{target} must carry policy evidence for disabled readback classification")

if targets_by_name.get("app-home-assistant", {}).get("recovery_alternative") != ["home-vm-100-ha-primary"]:
    fail("app-home-assistant disabled target must point at home-vm-100-ha-primary recovery alternative")
if targets_by_name.get("app-minio", {}).get("recovery_alternative") != ["vm-212-mint-data-primary"]:
    fail("app-minio disabled target must point at vm-212-mint-data-primary recovery alternative")

template_rows = {
    (str(row.get("proxmox_host") or "pve"), int(row.get("id") or 0)): row
    for row in vm_lifecycle.get("vms") or []
    if isinstance(row, dict) and str(row.get("id") or "").isdigit()
}
for key in TEMPLATE_SUBJECTS:
    row = template_rows.get(key)
    if not isinstance(row, dict):
        fail(f"template VM missing from lifecycle authority: {key[0]}/{key[1]}")
    if row.get("status") != "template" or row.get("role") != "template":
        fail(f"{key[0]}/{key[1]} must remain lifecycle template authority")
    if row.get("backup_target") is not None:
        fail(f"{key[0]}/{key[1]} template must not carry backup_target")

for target in RETIRED_TARGETS:
    row = targets_by_name.get(target)
    if not isinstance(row, dict):
        fail(f"retired target missing from inventory: {target}")
    if row.get("enabled") is not False:
        fail(f"{target} must remain disabled")
    if row.get("classification") != "retired":
        fail(f"{target} must remain classification=retired")
    if row.get("retirement_reason") != "app_local_backup_subtraction_policy":
        fail(f"{target} must name app_local_backup_subtraction_policy")

runtime_units = inventory.get("runtime_units") or []
for unit in runtime_units:
    if not isinstance(unit, dict):
        continue
    state = unit.get("backup_admission_state")
    if state in {"production_ready", "planned"}:
        refs = set(unit.get("inventory_targets") or [])
        leaked = sorted(refs & RETIRED_TARGETS)
        if leaked:
            fail(f"{unit.get('unit_id')} still references retired target(s): {', '.join(leaked)}")

jobs = schedule.get("jobs") or []
jobs_by_id = {row.get("id"): row for row in jobs if isinstance(row, dict)}
for job in RETIRED_JOBS:
    row = jobs_by_id.get(job)
    if not isinstance(row, dict):
        fail(f"retired schedule job missing: {job}")
    if row.get("enabled") is not False:
        fail(f"{job} must remain disabled in declared schedule authority")

surveillance_config_targets = {
    "app-surveillance-config": "surveillance-config-*.tar.gz",
    "app-surveillance-config-manifest": "surveillance-config-*.txt",
}
for target, glob in surveillance_config_targets.items():
    row = targets_by_name.get(target)
    if not isinstance(row, dict):
        fail(f"surveillance config target missing from inventory: {target}")
    if row.get("enabled") is not True:
        fail(f"{target} must be enabled")
    if row.get("host") != "pve":
        fail(f"{target} must land on pve")
    if row.get("base_path") != "/md1400/backups/configs/surveillance":
        fail(f"{target} must land under /md1400/backups/configs/surveillance")
    if row.get("glob") != glob:
        fail(f"{target} glob drifted")
    if not str(row.get("unique_data_reason") or "").strip():
        fail(f"{target} must name unique_data_reason")

vm215_target = targets_by_name.get("vm-215-surveillance-stack-primary")
if not isinstance(vm215_target, dict):
    fail("vm-215-surveillance-stack-primary target missing")
if vm215_target.get("enabled") is not False:
    fail("vm-215-surveillance-stack-primary must remain disabled for config-only posture")
if sorted(vm215_target.get("recovery_alternative") or []) != sorted(surveillance_config_targets):
    fail("vm-215-surveillance-stack-primary must point at surveillance config recovery alternatives")

surveillance_job = jobs_by_id.get("surveillance-config-manual")
if not isinstance(surveillance_job, dict):
    fail("surveillance-config-manual schedule job missing")
if surveillance_job.get("enabled") is not True:
    fail("surveillance-config-manual must be enabled")
if surveillance_job.get("capability_ref") != "backup.surveillance.config.archive.create":
    fail("surveillance-config-manual must use backup.surveillance.config.archive.create")
if sorted(surveillance_job.get("inventory_targets") or []) != sorted(surveillance_config_targets):
    fail("surveillance-config-manual inventory_targets must match surveillance config targets")

surveillance_cap = capabilities.get("backup.surveillance.config.archive.create") or {}
if surveillance_cap.get("safety") != "mutating":
    fail("backup.surveillance.config.archive.create must be mutating")
if surveillance_cap.get("command") != "./ops/plugins/infra/backup/bin/backup-surveillance-config-archive-create":
    fail("backup.surveillance.config.archive.create command drifted")

surveillance_script = surveillance_backup_path.read_text(encoding="utf-8")
for required in [
    ".env",
    "/srv/data/surveillance",
    "/srv/runtime/surveillance",
    "RTSP/NVR credential values",
]:
    if required not in surveillance_script:
        fail(f"surveillance config backup script must explicitly exclude {required}")

missing_unique_reason = []
for row in targets:
    if not isinstance(row, dict) or row.get("enabled") is not True:
        continue
    name = str(row.get("name") or "")
    if name.startswith(VM_PREFIXES):
        continue
    reason = str(row.get("unique_data_reason") or "").strip()
    if not reason:
        missing_unique_reason.append(name)

if missing_unique_reason:
    fail(
        "enabled non-VM/app-level backup target(s) missing unique_data_reason: "
        + ", ".join(sorted(missing_unique_reason))
    )

for path in [firstboot_path, normalize_path]:
    text = path.read_text(encoding="utf-8")
    for forbidden in [
        "backup_admission_state",
        "backup_targets",
        "inventory_targets",
        "backup_generation_lanes",
        "backup_profiles",
    ]:
        if forbidden in text:
            fail(f"{path.name} must not emit backup authority field: {forbidden}")

normalize_text = normalize_path.read_text(encoding="utf-8")
if "No admission, role, placement, watcher, or backup mutation" not in normalize_text:
    fail("post-boot normalize must explicitly refuse backup mutation")

print("D451 PASS: backup plane authority rejects unproved app-local backup debt and firstboot/admission claims cannot create backup truth")
PY
