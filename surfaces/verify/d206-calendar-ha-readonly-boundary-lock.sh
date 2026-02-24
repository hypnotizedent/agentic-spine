#!/usr/bin/env bash
# TRIAGE: Enforce HA calendar ingest read-only boundary and provider writeback lock.
# D206: calendar-ha-readonly-boundary-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HA_CONTRACT="$ROOT/ops/bindings/calendar.ha.ingest.contract.yaml"
HOME_CONTRACT="$ROOT/ops/bindings/calendar.home.contract.yaml"
SYNC_CONTRACT="$ROOT/ops/bindings/calendar.sync.contract.yaml"
CAPS="$ROOT/ops/capabilities.yaml"

fail() {
  echo "D206 FAIL: $*" >&2
  exit 1
}

for path in "$HA_CONTRACT" "$HOME_CONTRACT" "$SYNC_CONTRACT" "$CAPS"; do
  [[ -f "$path" ]] || fail "missing required file: $path"
done
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$HA_CONTRACT" "$HOME_CONTRACT" "$SYNC_CONTRACT" "$CAPS" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

ha_contract_path = Path(sys.argv[1]).expanduser().resolve()
home_contract_path = Path(sys.argv[2]).expanduser().resolve()
sync_contract_path = Path(sys.argv[3]).expanduser().resolve()
caps_path = Path(sys.argv[4]).expanduser().resolve()


def load_yaml(path: Path):
    payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(payload, dict):
        raise ValueError(f"YAML root must be mapping: {path}")
    return payload


def is_write_like(cap_id: str, meta: dict) -> bool:
    safety = str(meta.get("safety", "")).strip().lower()
    if safety in {"mutating", "destructive"}:
        return True
    lowered = cap_id.lower()
    return any(token in lowered for token in (".create", ".update", ".delete", ".write", ".send", ".rsvp"))


try:
    ha_contract = load_yaml(ha_contract_path)
    home_contract = load_yaml(home_contract_path)
    sync_contract = load_yaml(sync_contract_path)
    caps = load_yaml(caps_path)
except Exception as exc:
    print(f"D206 FAIL: parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []

provider_mode = ha_contract.get("provider_mode") if isinstance(ha_contract.get("provider_mode"), dict) else {}
if provider_mode.get("provider") != "home-assistant":
    violations.append("provider_mode.provider must be home-assistant")
if provider_mode.get("ingest_mode") != "read-only":
    violations.append("provider_mode.ingest_mode must be read-only")
if provider_mode.get("writeback_enabled") is not False:
    violations.append("provider_mode.writeback_enabled must be false")

home_ha = home_contract.get("home_assistant_ingest") if isinstance(home_contract.get("home_assistant_ingest"), dict) else {}
if home_ha.get("mode") != "read-only":
    violations.append("calendar.home.contract home_assistant_ingest.mode must be read-only")
if home_ha.get("contract_ref") != "ops/bindings/calendar.ha.ingest.contract.yaml":
    violations.append("calendar.home.contract home_assistant_ingest.contract_ref mismatch")

sync_ha = sync_contract.get("ha_ingest_contract") if isinstance(sync_contract.get("ha_ingest_contract"), dict) else {}
if sync_ha.get("mode") != "read-only":
    violations.append("calendar.sync.contract ha_ingest_contract.mode must be read-only")
if sync_ha.get("contract_ref") != "ops/bindings/calendar.ha.ingest.contract.yaml":
    violations.append("calendar.sync.contract ha_ingest_contract.contract_ref mismatch")

sync_push = (
    ((sync_contract.get("sync_contracts") or {}).get("push_write_capabilities", []))
    if isinstance(sync_contract.get("sync_contracts"), dict)
    else []
)
if not isinstance(sync_push, list):
    violations.append("calendar.sync.contract sync_contracts.push_write_capabilities must be list")
else:
    blocked = {"microsoft.calendar.create", "microsoft.calendar.update", "microsoft.calendar.rsvp"}
    found = sorted(str(cap) for cap in sync_push if str(cap) in blocked)
    if found:
        violations.append(f"calendar.sync.contract contains blocked Microsoft writes: {found}")

capabilities = caps.get("capabilities") if isinstance(caps.get("capabilities"), dict) else {}
for cap_id, meta in capabilities.items():
    if not str(cap_id).startswith("calendar.ha."):
        continue
    if not isinstance(meta, dict):
        continue
    if is_write_like(str(cap_id), meta):
        violations.append(f"calendar.ha capability must be read-only: {cap_id}")

if violations:
    for item in violations:
        print(f"D206 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D206 PASS: HA calendar ingest boundary locked read-only with provider writeback disabled")
PY
