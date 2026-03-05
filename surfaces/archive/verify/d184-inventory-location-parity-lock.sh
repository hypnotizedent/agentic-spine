#!/usr/bin/env bash
# TRIAGE: reconcile inventory location IDs and site parity across intake, hardware parts, and business catalog bindings before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LOCATIONS="$ROOT/ops/bindings/inventory.locations.yaml"
PARTS="$ROOT/ops/bindings/hardware.parts.inventory.yaml"
CATALOG="$ROOT/ops/bindings/business.inventory.catalog.yaml"
INTAKE_DIR="$ROOT/mailroom/outbox/intake"

fail() {
  echo "D184 FAIL: $*" >&2
  exit 1
}

[[ -f "$LOCATIONS" ]] || fail "missing locations binding: $LOCATIONS"
[[ -f "$PARTS" ]] || fail "missing hardware parts binding: $PARTS"
[[ -f "$CATALOG" ]] || fail "missing business inventory binding: $CATALOG"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$LOCATIONS" "$PARTS" "$CATALOG" "$INTAKE_DIR" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

locations_path = Path(sys.argv[1]).expanduser().resolve()
parts_path = Path(sys.argv[2]).expanduser().resolve()
catalog_path = Path(sys.argv[3]).expanduser().resolve()
intake_dir = Path(sys.argv[4]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


try:
    locations_doc = load_yaml(locations_path)
    parts_doc = load_yaml(parts_path)
    catalog_doc = load_yaml(catalog_path)
except Exception as exc:
    print(f"D184 FAIL: unable to parse bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

location_rows = locations_doc.get("locations") if isinstance(locations_doc.get("locations"), list) else []
location_map: dict[str, str] = {}
violations: list[tuple[str, str]] = []

for row in location_rows:
    if not isinstance(row, dict):
        continue
    loc_id = str(row.get("id", "")).strip()
    site = str(row.get("site", "")).strip()
    if not loc_id:
        continue
    if loc_id in location_map:
        violations.append((str(locations_path), f"duplicate location id: {loc_id}"))
    location_map[loc_id] = site

if not location_map:
    violations.append((str(locations_path), "locations[] must contain at least one location"))


def check_rows(rows, source_path: Path, id_key: str = "id"):
    for row in rows:
        if not isinstance(row, dict):
            continue
        row_id = str(row.get(id_key, "")).strip() or "unknown"
        site = str(row.get("site", "")).strip()
        location_id = str(row.get("location_id", "")).strip()
        if not location_id:
            violations.append((str(source_path), f"{row_id}: missing location_id"))
            continue
        if location_id not in location_map:
            violations.append((str(source_path), f"{row_id}: location_id not found in inventory.locations.yaml: {location_id}"))
            continue
        if site != location_map[location_id]:
            violations.append((str(source_path), f"{row_id}: site/location mismatch ({site} vs {location_map[location_id]})"))


parts_rows = parts_doc.get("parts") if isinstance(parts_doc.get("parts"), list) else []
materials_rows = catalog_doc.get("materials") if isinstance(catalog_doc.get("materials"), list) else []

check_rows(parts_rows, parts_path)
check_rows(materials_rows, catalog_path)

if intake_dir.is_dir():
    for path in sorted(intake_dir.glob("ITK-*.yaml")):
        try:
            intake_doc = load_yaml(path)
        except Exception as exc:
            violations.append((str(path), f"invalid YAML: {exc}"))
            continue
        check_rows([intake_doc], path, id_key="intake_id")

if violations:
    for path, msg in violations:
        print(f"D184 FAIL: {path} :: {msg}", file=sys.stderr)
    print(f"D184 FAIL: inventory location parity violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D184 PASS: inventory location parity valid")
PY
