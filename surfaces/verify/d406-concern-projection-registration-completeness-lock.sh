#!/usr/bin/env bash
# TRIAGE: Register concern-map projections in master.inventory.registry.yaml and domain.projection.contract.yaml.
set -euo pipefail

ROOT_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="${SPINE_ROOT:-$ROOT_DEFAULT}"
if [[ ! -f "$ROOT/ops/bindings/authority.concerns.yaml" && -f "$ROOT_DEFAULT/ops/bindings/authority.concerns.yaml" ]]; then
  ROOT="$ROOT_DEFAULT"
fi
AUTHORITY_CONCERNS="$ROOT/ops/bindings/authority.concerns.yaml"
MASTER="$ROOT/ops/bindings/master.inventory.registry.yaml"
PROJECTION="$ROOT/ops/bindings/domain.projection.contract.yaml"

fail() {
  echo "D406 FAIL: $*" >&2
  exit 1
}

for file in "$AUTHORITY_CONCERNS" "$MASTER" "$PROJECTION"; do
  [[ -f "$file" ]] || fail "missing required file: $file"
done
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 - "$ROOT" "$AUTHORITY_CONCERNS" "$MASTER" "$PROJECTION" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

root = Path(sys.argv[1]).expanduser().resolve()
authority_path = Path(sys.argv[2]).expanduser().resolve()
master_path = Path(sys.argv[3]).expanduser().resolve()
projection_path = Path(sys.argv[4]).expanduser().resolve()
ENFORCED_CONCERNS = {
    "service_registry_surfaces",
    "backup_inventory_surfaces",
    "service_lifecycle_retention_surfaces",
    "internet_asset_surfaces",
}


def load_yaml(path: Path) -> dict:
    try:
        with path.open("r", encoding="utf-8") as handle:
            doc = yaml.safe_load(handle) or {}
    except Exception as exc:
        raise ValueError(f"{path}: invalid YAML ({exc})") from exc
    if not isinstance(doc, dict):
        raise ValueError(f"{path}: YAML root must be a mapping")
    return doc


def as_list(value) -> list:
    return value if isinstance(value, list) else []


def as_dict(value) -> dict:
    return value if isinstance(value, dict) else {}


def normalize_repo_path(raw_path: str) -> str:
    rel = str(raw_path or "").strip()
    if rel.startswith("agentic-spine/"):
        rel = rel.split("/", 1)[1]
    return rel


violations: list[str] = []

try:
    authority = load_yaml(authority_path)
    master = load_yaml(master_path)
    projection = load_yaml(projection_path)
except ValueError as exc:
    print(f"D406 FAIL: {exc}", file=sys.stderr)
    raise SystemExit(1)

rows = as_list(master.get("rows"))
row_by_authority_path: dict[str, list[dict]] = {}
for row in rows:
    if not isinstance(row, dict):
        continue
    authority_cfg = as_dict(row.get("authority"))
    authority_rel = str(authority_cfg.get("path", "")).strip()
    if authority_rel:
        row_by_authority_path.setdefault(authority_rel, []).append(row)

projection_entries = as_list(projection.get("projections"))
entry_by_output_path: dict[str, dict] = {}
for entry in projection_entries:
    if not isinstance(entry, dict):
        continue
    output_path = str(entry.get("output_path", "")).strip()
    if output_path:
        entry_by_output_path[output_path] = entry

checked_concerns: list[str] = []
for concern_id, payload in sorted(as_dict(authority.get("concerns")).items()):
    if concern_id not in ENFORCED_CONCERNS:
        continue
    concern = as_dict(payload)
    sources = as_list(concern.get("sources"))
    if not sources:
        continue

    authoritative_paths: list[str] = []
    projection_paths: list[str] = []
    skip_due_to_manual_projection = False

    for source in sources:
        source_map = as_dict(source)
        state = str(source_map.get("state", "")).strip()
        rel_path = normalize_repo_path(source_map.get("path", ""))
        current_state = str(source_map.get("current_state", "")).strip()
        if state == "authoritative" and rel_path and not rel_path.startswith(("workbench/", "agentic-foundation/", "mint-modules/")):
            authoritative_paths.append(rel_path)
        if state != "projection":
            continue
        if current_state in {"hand_maintained", "partially_hand_maintained"}:
            skip_due_to_manual_projection = True
            break
        if rel_path.startswith("ops/bindings/"):
            projection_paths.append(rel_path)

    if skip_due_to_manual_projection:
        violations.append(f"{concern_id}: concern is still marked manual and cannot be enforced by D406 yet")
        continue
    if not projection_paths:
        violations.append(f"{concern_id}: no ops/bindings projection surfaces found for registration completeness")
        continue
    if not authoritative_paths:
        violations.append(f"{concern_id}: no in-repo authoritative source found for registration completeness")
        continue
    if len(authoritative_paths) != 1:
        violations.append(
            f"{concern_id}: expected exactly one in-repo authoritative path for registration completeness, found {len(authoritative_paths)}"
        )
        continue

    for rel_path in projection_paths:
        file_path = root / rel_path
        if not file_path.exists():
            violations.append(f"{concern_id}: missing projection surface on disk: {rel_path}")
            continue

    authoritative_path = authoritative_paths[0]
    matching_rows = row_by_authority_path.get(authoritative_path, [])
    if len(matching_rows) != 1:
        violations.append(
            f"{concern_id}: expected exactly one master row for authority.path={authoritative_path}, found {len(matching_rows)}"
        )
        continue

    row = matching_rows[0]
    row_id = str(row.get("id", "")).strip()
    projection_refs = {str(item).strip() for item in as_list(row.get("projection_refs")) if str(item).strip()}
    if not row_id:
        violations.append(f"{concern_id}: master row for {authoritative_path} is missing id")
        continue

    for rel_path in sorted(projection_paths):
        entry = entry_by_output_path.get(rel_path)
        if not entry:
            violations.append(f"{concern_id}: projection contract missing output_path {rel_path}")
            continue
        projection_id = str(entry.get("id", "")).strip()
        if not projection_id:
            violations.append(f"{concern_id}: projection contract entry for {rel_path} missing id")
            continue
        if projection_id not in projection_refs:
            violations.append(f"{concern_id}: master row {row_id} missing projection ref {projection_id}")
        source_rows = {str(item).strip() for item in as_list(entry.get("source_master_rows")) if str(item).strip()}
        if row_id not in source_rows:
            violations.append(f"{concern_id}: projection {projection_id} missing source_master_rows link to {row_id}")

    checked_concerns.append(concern_id)

if violations:
    for item in violations:
        print(f"D406 FAIL: {item}", file=sys.stderr)
    print(
        f"D406 FAIL: concern projection registration completeness violations ({len(violations)} finding(s))",
        file=sys.stderr,
    )
    raise SystemExit(1)

print(
    "D406 PASS: concern projection registration completeness enforced "
    f"(concerns={len(checked_concerns)})"
)
PY
