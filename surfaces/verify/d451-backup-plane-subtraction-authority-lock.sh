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
READBACK="$ROOT/ops/plugins/core/bin/backup-readback-admission-status"
FIRSTBOOT="$ROOT/ops/plugins/infra/host/bin/host-operator-hardware-firstboot-claim"
NORMALIZE="$ROOT/ops/plugins/infra/host/bin/host-operator-hardware-post-boot-normalize"

fail() { echo "D451 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -f "$INVENTORY" ]] || fail "missing backup inventory"
[[ -f "$SCHEDULE" ]] || fail "missing backup schedule"
[[ -f "$DOC" ]] || fail "missing backup domain doc"
[[ -f "$CAPS" ]] || fail "missing capability registry"
[[ -x "$READBACK" ]] || fail "missing legacy backup readback drilldown"
[[ -x "$FIRSTBOOT" ]] || fail "missing firstboot claim script"
[[ -x "$NORMALIZE" ]] || fail "missing post-boot normalize script"

python3 - "$INVENTORY" "$SCHEDULE" "$DOC" "$CAPS" "$READBACK" "$FIRSTBOOT" "$NORMALIZE" <<'PY'
import sys
from pathlib import Path

import yaml

inventory_path = Path(sys.argv[1])
schedule_path = Path(sys.argv[2])
doc_path = Path(sys.argv[3])
caps_path = Path(sys.argv[4])
readback_path = Path(sys.argv[5])
firstboot_path = Path(sys.argv[6])
normalize_path = Path(sys.argv[7])

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
