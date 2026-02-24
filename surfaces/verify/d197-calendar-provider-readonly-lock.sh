#!/usr/bin/env bash
# TRIAGE: Keep calendar sync provider read-only and enforce local writable store path.
# D197: calendar provider readonly lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/calendar.sync.contract.yaml"

fail() {
  echo "D197 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CONTRACT" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

contract_path = Path(sys.argv[1]).expanduser().resolve()

try:
    doc = yaml.safe_load(contract_path.read_text(encoding="utf-8")) or {}
except Exception as exc:
    print(f"D197 FAIL: unable to parse contract: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(doc, dict):
    print("D197 FAIL: contract root must be mapping", file=sys.stderr)
    raise SystemExit(1)

violations: list[str] = []

provider = doc.get("runtime", {}).get("provider")
if provider != "microsoft":
    violations.append(f"runtime.provider must remain 'microsoft' (actual={provider!r})")

local_path = doc.get("local_calendar_store", {}).get("path")
expected_local_path = "mailroom/state/calendar-sync/writable"
if local_path != expected_local_path:
    violations.append(
        f"local_calendar_store.path must be '{expected_local_path}' (actual={local_path!r})"
    )

sync_contracts = doc.get("sync_contracts", {})
if not isinstance(sync_contracts, dict):
    violations.append("sync_contracts mapping missing")
    sync_contracts = {}

pull_caps = sync_contracts.get("pull_read_capabilities", [])
if not isinstance(pull_caps, list):
    violations.append("sync_contracts.pull_read_capabilities must be a list")
    pull_caps = []

expected_pull = ["microsoft.calendar.list", "microsoft.calendar.get"]
if pull_caps != expected_pull:
    violations.append(f"pull_read_capabilities mismatch: expected={expected_pull} actual={pull_caps}")

push_caps = sync_contracts.get("push_write_capabilities", [])
if not isinstance(push_caps, list):
    violations.append("sync_contracts.push_write_capabilities must be a list")
    push_caps = []

blocked = {"microsoft.calendar.create", "microsoft.calendar.update", "microsoft.calendar.rsvp"}
present_blocked = [cap for cap in push_caps if str(cap) in blocked]
if present_blocked:
    violations.append(f"push_write_capabilities contains blocked microsoft calendar writes: {present_blocked}")

if push_caps:
    violations.append(f"push_write_capabilities must be empty for provider-readonly mode (actual={push_caps})")

if violations:
    for item in violations:
        print(f"D197 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D197 PASS: calendar provider readonly lock valid (local writable store + provider read-only)")
PY
