#!/usr/bin/env bash
# TRIAGE: reconcile network.devices.ledger.yaml with observed home.device.registry devices before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LEDGER="$ROOT/ops/bindings/network.devices.ledger.yaml"
OBSERVED="$ROOT/ops/bindings/home.device.registry.yaml"

fail() {
  echo "D188 FAIL: $*" >&2
  exit 1
}

[[ -f "$LEDGER" ]] || fail "missing ledger binding: $LEDGER"
[[ -f "$OBSERVED" ]] || fail "missing observed binding: $OBSERVED"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$LEDGER" "$OBSERVED" <<'PY'
from __future__ import annotations

from datetime import date, datetime, timezone
from pathlib import Path
import sys

import yaml

ledger_path = Path(sys.argv[1]).expanduser().resolve()
observed_path = Path(sys.argv[2]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


def parse_expires(value: str) -> date | None:
    text = (value or "").strip()
    if not text:
        return None
    try:
        if len(text) == 10:
            return datetime.strptime(text, "%Y-%m-%d").date()
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        return datetime.fromisoformat(text).date()
    except Exception:
        return None


try:
    ledger = load_yaml(ledger_path)
    observed = load_yaml(observed_path)
except Exception as exc:
    print(f"D188 FAIL: unable to parse bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

items = ledger.get("items") if isinstance(ledger.get("items"), list) else []
observed_rows = observed.get("devices") if isinstance(observed.get("devices"), list) else []

allowed = {"approved", "ignored"}
ledger_map: dict[str, dict] = {}
violations: list[str] = []

for row in items:
    if not isinstance(row, dict):
        continue
    item_id = str(row.get("id", "")).strip()
    if not item_id:
        continue
    ledger_map[item_id] = row

for row in observed_rows:
    if not isinstance(row, dict):
        continue
    item_id = str(row.get("id", "")).strip()
    if not item_id:
        continue
    entry = ledger_map.get(item_id)
    if not entry:
        violations.append(f"unmanaged observed network device: {item_id}")
        continue

    status = str(entry.get("status", "")).strip().lower()
    if status not in allowed:
        violations.append(f"{item_id}: status must be approved|ignored (got {status or 'empty'})")
        continue

    if status == "ignored":
        expires = parse_expires(str(entry.get("expires_on", "")))
        if expires is None:
            violations.append(f"{item_id}: ignored items require valid expires_on")
            continue
        if expires < datetime.now(timezone.utc).date():
            violations.append(f"{item_id}: ignored expires_on is in the past ({expires.isoformat()})")

if violations:
    for msg in violations:
        print(f"D188 FAIL: {msg}", file=sys.stderr)
    print(f"D188 FAIL: network device ledger parity violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(f"D188 PASS: network device ledger parity valid ({len(observed_rows)} observed, {len(ledger_map)} ledgered)")
PY
