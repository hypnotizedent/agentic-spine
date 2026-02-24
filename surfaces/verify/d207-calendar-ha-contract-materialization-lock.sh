#!/usr/bin/env bash
# TRIAGE: Enforce HA calendar ingest contract/input/output materialization and parity.
# D207: calendar-ha-contract-materialization-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HA_CONTRACT="$ROOT/ops/bindings/calendar.ha.ingest.contract.yaml"
HOME_CONTRACT="$ROOT/ops/bindings/calendar.home.contract.yaml"
SYNC_CONTRACT="$ROOT/ops/bindings/calendar.sync.contract.yaml"

fail() {
  echo "D207 FAIL: $*" >&2
  exit 1
}

for path in "$HA_CONTRACT" "$HOME_CONTRACT" "$SYNC_CONTRACT"; do
  [[ -f "$path" ]] || fail "missing required file: $path"
done
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$HA_CONTRACT" "$HOME_CONTRACT" "$SYNC_CONTRACT" "$ROOT" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

ha_contract_path = Path(sys.argv[1]).expanduser().resolve()
home_contract_path = Path(sys.argv[2]).expanduser().resolve()
sync_contract_path = Path(sys.argv[3]).expanduser().resolve()
root = Path(sys.argv[4]).expanduser().resolve()


def load_yaml(path: Path):
    payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(payload, dict):
        raise ValueError(f"YAML root must be mapping: {path}")
    return payload


def require_path_field(doc: dict, field: str, violations: list[str]) -> str:
    value = str(doc.get(field, "")).strip()
    if not value:
        violations.append(f"{field} missing")
    return value


try:
    ha_contract = load_yaml(ha_contract_path)
    home_contract = load_yaml(home_contract_path)
    sync_contract = load_yaml(sync_contract_path)
except Exception as exc:
    print(f"D207 FAIL: parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []

provider_mode = ha_contract.get("provider_mode") if isinstance(ha_contract.get("provider_mode"), dict) else {}
if provider_mode.get("provider") != "home-assistant":
    violations.append("provider_mode.provider must be home-assistant")
if provider_mode.get("ingest_mode") != "read-only":
    violations.append("provider_mode.ingest_mode must be read-only")
if provider_mode.get("writeback_enabled") is not False:
    violations.append("provider_mode.writeback_enabled must be false")

source = ha_contract.get("source") if isinstance(ha_contract.get("source"), dict) else {}
auto_rel = require_path_field(source, "automation_snapshot_binding", violations)
inv_rel = require_path_field(source, "inventory_snapshot_binding", violations)
for rel in (auto_rel, inv_rel):
    if rel and not (root / rel).resolve().is_file():
        violations.append(f"source binding does not exist: {rel}")

feeds = ha_contract.get("feeds") if isinstance(ha_contract.get("feeds"), dict) else {}
if not feeds:
    violations.append("feeds mapping missing")
for feed_id, feed in feeds.items():
    if not isinstance(feed, dict):
        violations.append(f"feeds.{feed_id} must be mapping")
        continue
    if not isinstance(feed.get("enabled"), bool):
        violations.append(f"feeds.{feed_id}.enabled must be boolean")
    if not str(feed.get("calendar_id", "")).strip():
        violations.append(f"feeds.{feed_id}.calendar_id missing")
    max_events = feed.get("max_events")
    if not isinstance(max_events, int) or max_events <= 0:
        violations.append(f"feeds.{feed_id}.max_events must be positive integer")

output = ha_contract.get("output") if isinstance(ha_contract.get("output"), dict) else {}
snapshot_rel = require_path_field(output, "snapshot_path", violations)
index_rel = require_path_field(output, "index_path", violations)
if snapshot_rel and not str(Path(snapshot_rel)).endswith(".json"):
    violations.append("output.snapshot_path must be .json")
if index_rel and not str(Path(index_rel)).endswith(".json"):
    violations.append("output.index_path must be .json")

merge = ha_contract.get("merge") if isinstance(ha_contract.get("merge"), dict) else {}
target_store_rel = require_path_field(merge, "target_local_store_path", violations)
layer_id = require_path_field(merge, "layer_id", violations)
if merge.get("read_only") is not True:
    violations.append("merge.read_only must be true")
if merge.get("immutable_by_source") is not True:
    violations.append("merge.immutable_by_source must be true")
if layer_id and "/" in layer_id:
    violations.append("merge.layer_id must be a simple directory id (no /)")
if target_store_rel and not str(target_store_rel).startswith("mailroom/state/"):
    violations.append("merge.target_local_store_path must live under mailroom/state/")

freshness = ha_contract.get("freshness") if isinstance(ha_contract.get("freshness"), dict) else {}
max_age = freshness.get("max_snapshot_age_hours")
if not isinstance(max_age, int) or max_age <= 0:
    violations.append("freshness.max_snapshot_age_hours must be positive integer")

home_ha = home_contract.get("home_assistant_ingest") if isinstance(home_contract.get("home_assistant_ingest"), dict) else {}
if home_ha.get("contract_ref") != "ops/bindings/calendar.ha.ingest.contract.yaml":
    violations.append("calendar.home.contract home_assistant_ingest.contract_ref mismatch")
if home_ha.get("mode") != "read-only":
    violations.append("calendar.home.contract home_assistant_ingest.mode must be read-only")
if not isinstance(home_ha.get("enabled"), bool):
    violations.append("calendar.home.contract home_assistant_ingest.enabled must be boolean")

sync_ha = sync_contract.get("ha_ingest_contract") if isinstance(sync_contract.get("ha_ingest_contract"), dict) else {}
if sync_ha.get("contract_ref") != "ops/bindings/calendar.ha.ingest.contract.yaml":
    violations.append("calendar.sync.contract ha_ingest_contract.contract_ref mismatch")
if sync_ha.get("mode") != "read-only":
    violations.append("calendar.sync.contract ha_ingest_contract.mode must be read-only")

if violations:
    for item in violations:
        print(f"D207 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D207 PASS: HA calendar ingest contract/materialization parity valid")
PY
