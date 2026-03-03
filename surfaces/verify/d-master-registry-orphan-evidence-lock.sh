#!/usr/bin/env bash
# TRIAGE: Every master row must have intake lineage + evidence links; remove or complete orphan rows in master.inventory.registry.yaml.
set -euo pipefail

ROOT_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="${SPINE_ROOT:-$ROOT_DEFAULT}"
if [[ ! -f "$ROOT/ops/bindings/master.inventory.registry.yaml" && -f "$ROOT_DEFAULT/ops/bindings/master.inventory.registry.yaml" ]]; then
  ROOT="$ROOT_DEFAULT"
fi
MASTER="$ROOT/ops/bindings/master.inventory.registry.yaml"
PROJECTION="$ROOT/ops/bindings/domain.projection.contract.yaml"

fail() {
  echo "D340 FAIL: $*" >&2
  exit 1
}

[[ -f "$MASTER" ]] || fail "missing master registry: $MASTER"
[[ -f "$PROJECTION" ]] || fail "missing projection contract: $PROJECTION"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 - "$ROOT" "$MASTER" "$PROJECTION" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

root = Path(sys.argv[1]).expanduser().resolve()
master_path = Path(sys.argv[2]).expanduser().resolve()
projection_path = Path(sys.argv[3]).expanduser().resolve()


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        doc = yaml.safe_load(handle) or {}
    if not isinstance(doc, dict):
        raise ValueError(f"{path}: YAML root must be a mapping")
    return doc


def as_list(value) -> list:
    return value if isinstance(value, list) else []


def as_dict(value) -> dict:
    return value if isinstance(value, dict) else {}


def is_glob_like(value: str) -> bool:
    return "*" in value or "?" in value or "[" in value


violations: list[str] = []

try:
    master = load_yaml(master_path)
    projection = load_yaml(projection_path)
except Exception as exc:
    print(f"D340 FAIL: unable to parse registry files ({exc})", file=sys.stderr)
    raise SystemExit(1)

rows = as_list(master.get("rows"))
if not rows:
    print("D340 FAIL: master registry rows[] is empty", file=sys.stderr)
    raise SystemExit(1)

projection_ids = {
    str(as_dict(entry).get("id", "")).strip()
    for entry in as_list(projection.get("projections"))
    if isinstance(entry, dict)
}
projection_ids.discard("")

for row in rows:
    if not isinstance(row, dict):
        violations.append("master row must be a mapping")
        continue

    row_id = str(row.get("id", "")).strip() or "unknown"
    authority = as_dict(row.get("authority"))
    authority_path = str(authority.get("path", "")).strip()
    if not authority_path:
        violations.append(f"{row_id}: missing authority.path")
    elif not (root / authority_path).exists():
        violations.append(f"{row_id}: authority.path does not exist: {authority_path}")

    intake_lineage = as_dict(row.get("intake_lineage"))
    intake_refs = [str(v).strip() for v in as_list(intake_lineage.get("accepted_intake_refs")) if str(v).strip()]
    if not intake_refs:
        violations.append(f"{row_id}: orphan row missing intake_lineage.accepted_intake_refs")

    evidence_required = bool(intake_lineage.get("evidence_required", False))
    evidence_refs = [str(v).strip() for v in as_list(row.get("evidence_refs")) if str(v).strip()]
    if evidence_required and not evidence_refs:
        violations.append(f"{row_id}: evidence_required=true but evidence_refs is empty")
    elif not evidence_refs:
        violations.append(f"{row_id}: orphan row missing evidence_refs")

    local_evidence_found = False
    for ref in evidence_refs:
        if ref.startswith("ops/") or ref.startswith("docs/"):
            if is_glob_like(ref):
                continue
            if not (root / ref).exists():
                violations.append(f"{row_id}: evidence path does not exist: {ref}")
            else:
                local_evidence_found = True
    if evidence_refs and not local_evidence_found:
        violations.append(
            f"{row_id}: evidence_refs must include at least one concrete local ops/ or docs/ path"
        )

    projection_refs = [str(v).strip() for v in as_list(row.get("projection_refs")) if str(v).strip()]
    if not projection_refs:
        violations.append(f"{row_id}: orphan row missing projection_refs")
    for projection_ref in projection_refs:
        if projection_ref not in projection_ids:
            violations.append(f"{row_id}: projection ref missing from domain.projection.contract.yaml: {projection_ref}")

if violations:
    for item in violations:
        print(f"D340 FAIL: {item}", file=sys.stderr)
    print(f"D340 FAIL: orphan/evidence violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(f"D340 PASS: no orphan master rows without intake/evidence (rows={len(rows)})")
PY
