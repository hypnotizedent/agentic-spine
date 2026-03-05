#!/usr/bin/env bash
# TRIAGE: complete required inventory item metadata fields and lifecycle/timestamp validity before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
PARTS="$ROOT/ops/bindings/hardware.parts.inventory.yaml"
CATALOG="$ROOT/ops/bindings/business.inventory.catalog.yaml"

fail() {
  echo "D187 FAIL: $*" >&2
  exit 1
}

[[ -f "$PARTS" ]] || fail "missing parts binding: $PARTS"
[[ -f "$CATALOG" ]] || fail "missing catalog binding: $CATALOG"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$PARTS" "$CATALOG" <<'PY'
from __future__ import annotations

from datetime import datetime
from pathlib import Path
import sys

import yaml

parts_path = Path(sys.argv[1]).expanduser().resolve()
catalog_path = Path(sys.argv[2]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


def valid_date_or_datetime(value: str) -> bool:
    value = value.strip()
    if not value:
        return False
    try:
        if len(value) == 10:
            datetime.strptime(value, "%Y-%m-%d")
            return True
        datetime.fromisoformat(value.replace("Z", "+00:00"))
        return True
    except Exception:
        return False


def as_float(value, label: str) -> float:
    try:
        return float(value)
    except Exception:
        raise ValueError(f"{label} must be numeric")


try:
    parts_doc = load_yaml(parts_path)
    catalog_doc = load_yaml(catalog_path)
except Exception as exc:
    print(f"D187 FAIL: unable to parse inventory bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

violations: list[tuple[str, str]] = []


def check_collection(doc: dict, path: Path, key: str):
    rows = doc.get(key)
    if not isinstance(rows, list):
        violations.append((str(path), f"{key} must be a list"))
        return

    lifecycle = {
        str(x).strip()
        for x in (doc.get("lifecycle_statuses") or [])
        if str(x).strip()
    }
    required_fields = [
        str(x).strip()
        for x in (doc.get("required_item_fields") or [])
        if str(x).strip()
    ]
    if not required_fields:
        violations.append((str(path), "required_item_fields must be non-empty"))

    for idx, row in enumerate(rows):
        row_tag = f"{key}[{idx}]"
        if not isinstance(row, dict):
            violations.append((str(path), f"{row_tag} must be mapping"))
            continue
        item_id = str(row.get("id", "")).strip() or row_tag

        for field in required_fields:
            if field not in row:
                violations.append((str(path), f"{item_id}: missing field {field}"))
                continue
            value = row.get(field)
            if field in {"on_hand_qty", "reorder_point"}:
                try:
                    numeric = as_float(value, f"{item_id}.{field}")
                except Exception as exc:
                    violations.append((str(path), str(exc)))
                    continue
                if numeric < 0:
                    violations.append((str(path), f"{item_id}.{field} cannot be negative"))
            elif field == "last_counted_at":
                if not valid_date_or_datetime(str(value or "")):
                    violations.append((str(path), f"{item_id}.last_counted_at invalid timestamp/date"))
            else:
                if not str(value or "").strip():
                    violations.append((str(path), f"{item_id}.{field} cannot be empty"))

        lifecycle_status = str(row.get("lifecycle_status", "")).strip()
        if lifecycle and lifecycle_status not in lifecycle:
            violations.append((str(path), f"{item_id}.lifecycle_status not in lifecycle_statuses: {lifecycle_status}"))


check_collection(parts_doc, parts_path, "parts")
check_collection(catalog_doc, catalog_path, "materials")

if violations:
    for source, msg in violations:
        print(f"D187 FAIL: {source} :: {msg}", file=sys.stderr)
    print(f"D187 FAIL: inventory item contract violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D187 PASS: inventory item contract metadata valid")
PY
