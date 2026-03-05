#!/usr/bin/env bash
# TRIAGE: rebuild network.inventory.snapshot.yaml with network-inventory-snapshot-build so observed device parity and freshness remain locked.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SNAPSHOT="$ROOT/ops/bindings/network.inventory.snapshot.yaml"
OBS_HOME="$ROOT/ops/bindings/network.unifi.home.clients.observed.yaml"
OBS_SHOP="$ROOT/ops/bindings/network.unifi.shop.clients.observed.yaml"

fail() {
  echo "D194 FAIL: $*" >&2
  exit 1
}

[[ -f "$SNAPSHOT" ]] || fail "missing snapshot binding: $SNAPSHOT"
[[ -f "$OBS_HOME" ]] || fail "missing observed binding: $OBS_HOME"
[[ -f "$OBS_SHOP" ]] || fail "missing observed binding: $OBS_SHOP"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$SNAPSHOT" "$OBS_HOME" "$OBS_SHOP" <<'PY'
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import sys

import yaml

snapshot_path = Path(sys.argv[1]).expanduser().resolve()
home_path = Path(sys.argv[2]).expanduser().resolve()
shop_path = Path(sys.argv[3]).expanduser().resolve()


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


def parse_dt(value: str):
    text = (value or "").strip()
    if not text:
        return None
    try:
        if len(text) == 10:
            return datetime.strptime(text, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        dt = datetime.fromisoformat(text)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except Exception:
        return None


try:
    snapshot = load_yaml(snapshot_path)
    home = load_yaml(home_path)
    shop = load_yaml(shop_path)
except Exception as exc:
    print(f"D194 FAIL: unable to parse bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []

for key in ("home_devices", "shop_devices", "hardware_assets", "upgrade_candidates"):
    if not isinstance(snapshot.get(key), list):
        violations.append(f"missing required snapshot section list: {key}")

freshness = snapshot.get("freshness_policy") if isinstance(snapshot.get("freshness_policy"), dict) else {}
try:
    max_age_hours = int(freshness.get("max_age_hours", 24))
except Exception:
    max_age_hours = 24

generated_at = parse_dt(str(snapshot.get("generated_at", "")))
if generated_at is None:
    violations.append("generated_at missing or invalid")
else:
    age_hours = (datetime.now(timezone.utc) - generated_at).total_seconds() / 3600.0
    if age_hours > max_age_hours:
        violations.append(f"snapshot stale ({age_hours:.1f}h > {max_age_hours}h)")

home_snapshot_map = {
    str(row.get("id", "")).strip(): row
    for row in (snapshot.get("home_devices") or [])
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}
shop_snapshot_map = {
    str(row.get("id", "")).strip(): row
    for row in (snapshot.get("shop_devices") or [])
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}


def check_source(source_name: str, source_doc: dict, target_map: dict[str, dict]) -> int:
    observed_count = 0
    for row in source_doc.get("devices") or []:
        if not isinstance(row, dict):
            continue
        item_id = str(row.get("id", "")).strip()
        if not item_id:
            continue
        observed_count += 1
        snap_row = target_map.get(item_id)
        if snap_row is None:
            violations.append(f"{source_name}: missing observed device in snapshot: {item_id}")
            continue
        source_ip = str(row.get("ip", "")).strip()
        if source_ip:
            snapshot_ip = str(snap_row.get("ip", "")).strip()
            if not snapshot_ip:
                violations.append(f"{source_name}: snapshot device {item_id} missing ip while source has ip={source_ip}")
    return observed_count


home_count = check_source("home", home, home_snapshot_map)
shop_count = check_source("shop", shop, shop_snapshot_map)

if violations:
    for msg in violations:
        print(f"D194 FAIL: {msg}", file=sys.stderr)
    print(f"D194 FAIL: network inventory snapshot parity violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(
    "D194 PASS: network inventory snapshot parity valid "
    f"(home_observed={home_count} shop_observed={shop_count} "
    f"home_snapshot={len(home_snapshot_map)} shop_snapshot={len(shop_snapshot_map)})"
)
PY
