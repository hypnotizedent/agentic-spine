#!/usr/bin/env bash
# TRIAGE: Enforce HA calendar snapshot/index freshness and union layer parity.
# D208: calendar-ha-snapshot-freshness-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HA_CONTRACT="$ROOT/ops/bindings/calendar.ha.ingest.contract.yaml"

fail() {
  echo "D208 FAIL: $*" >&2
  exit 1
}

[[ -f "$HA_CONTRACT" ]] || fail "missing contract: $HA_CONTRACT"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$HA_CONTRACT" "$ROOT" <<'PY'
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import json
import sys

import yaml

contract_path = Path(sys.argv[1]).expanduser().resolve()
root = Path(sys.argv[2]).expanduser().resolve()


def parse_age_hours(raw: str) -> float | None:
    value = raw.strip()
    if not value:
        return None
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(value)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return (datetime.now(timezone.utc) - dt.astimezone(timezone.utc)).total_seconds() / 3600.0


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


try:
    contract = yaml.safe_load(contract_path.read_text(encoding="utf-8")) or {}
except Exception as exc:
    print(f"D208 FAIL: unable to parse contract: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(contract, dict):
    print("D208 FAIL: contract root must be mapping", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []

output = contract.get("output") if isinstance(contract.get("output"), dict) else {}
merge = contract.get("merge") if isinstance(contract.get("merge"), dict) else {}
freshness = contract.get("freshness") if isinstance(contract.get("freshness"), dict) else {}

snapshot_rel = str(output.get("snapshot_path", "")).strip()
index_rel = str(output.get("index_path", "")).strip()
layer_store_rel = str(merge.get("target_local_store_path", "")).strip()
layer_id = str(merge.get("layer_id", "")).strip()
max_age_hours = int(freshness.get("max_snapshot_age_hours", 24) or 24)

if not snapshot_rel:
    violations.append("output.snapshot_path missing")
if not index_rel:
    violations.append("output.index_path missing")
if not layer_store_rel:
    violations.append("merge.target_local_store_path missing")
if not layer_id:
    violations.append("merge.layer_id missing")

snapshot_path = (root / snapshot_rel).resolve() if snapshot_rel else None
index_path = (root / index_rel).resolve() if index_rel else None
layer_path = (root / layer_store_rel).resolve() / layer_id if layer_store_rel and layer_id else None

snapshot = None
if snapshot_path:
    if not snapshot_path.is_file():
        violations.append(f"snapshot missing: {snapshot_path}")
    else:
        try:
            snapshot = load_json(snapshot_path)
        except Exception as exc:
            violations.append(f"invalid snapshot JSON: {exc}")

index = None
if index_path:
    if not index_path.is_file():
        violations.append(f"index missing: {index_path}")
    else:
        try:
            index = load_json(index_path)
        except Exception as exc:
            violations.append(f"invalid index JSON: {exc}")

if isinstance(snapshot, dict):
    generated = str(snapshot.get("generated_at", "")).strip()
    age = parse_age_hours(generated)
    if age is None:
        violations.append("snapshot generated_at missing or invalid")
    elif age > max_age_hours:
        violations.append(f"snapshot too old ({age:.2f}h > {max_age_hours}h)")
    data = snapshot.get("data") if isinstance(snapshot.get("data"), dict) else {}
    events = data.get("events") if isinstance(data.get("events"), list) else None
    if events is None:
        violations.append("snapshot data.events must be list")
        events = []
    required = {"source", "source_calendar_id", "source_event_id", "title", "start", "end", "read_only", "immutable_by_source"}
    for idx, event in enumerate(events):
        if not isinstance(event, dict):
            violations.append(f"snapshot event[{idx}] must be mapping")
            continue
        missing = sorted(required - set(event.keys()))
        if missing:
            violations.append(f"snapshot event[{idx}] missing fields: {missing}")
        if event.get("read_only") is not True:
            violations.append(f"snapshot event[{idx}] read_only must be true")
        if event.get("immutable_by_source") is not True:
            violations.append(f"snapshot event[{idx}] immutable_by_source must be true")
    expected_count = int(data.get("event_count", len(events)) or 0)
    if expected_count != len(events):
        violations.append(f"snapshot event_count mismatch: {expected_count} != {len(events)}")

if isinstance(index, dict):
    data = index.get("data") if isinstance(index.get("data"), dict) else {}
    layer = data.get("layer") if isinstance(data.get("layer"), dict) else {}
    if str(layer.get("id", "")).strip() != layer_id:
        violations.append("index data.layer.id mismatch")
    if layer.get("read_only") is not True:
        violations.append("index data.layer.read_only must be true")
    if layer.get("immutable_by_source") is not True:
        violations.append("index data.layer.immutable_by_source must be true")

if layer_path:
    if not layer_path.is_dir():
        violations.append(f"layer path missing: {layer_path}")
    else:
        manifest_path = layer_path / "manifest.json"
        if not manifest_path.is_file():
            violations.append(f"layer manifest missing: {manifest_path}")
        else:
            try:
                manifest = load_json(manifest_path)
            except Exception as exc:
                violations.append(f"invalid layer manifest JSON: {exc}")
                manifest = {}
            if isinstance(manifest, dict):
                if manifest.get("read_only") is not True:
                    violations.append("layer manifest read_only must be true")
                if manifest.get("immutable_by_source") is not True:
                    violations.append("layer manifest immutable_by_source must be true")
                ics_count = len(list(layer_path.glob("*.ics")))
                manifest_raw = manifest.get("event_count")
                if not isinstance(manifest_raw, int) or manifest_raw < 0:
                    violations.append("layer manifest event_count must be non-negative integer")
                elif manifest_raw != ics_count:
                    violations.append(f"layer manifest event_count mismatch: {manifest_raw} != {ics_count}")

if violations:
    for item in violations:
        print(f"D208 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D208 PASS: HA snapshot/index freshness + union layer parity valid")
PY
