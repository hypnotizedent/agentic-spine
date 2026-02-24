#!/usr/bin/env bash
# TRIAGE: reconcile ha.automations.ledger.yaml with observed ha.automations snapshot before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LEDGER="$ROOT/ops/bindings/ha.automations.ledger.yaml"
OBSERVED="$ROOT/ops/bindings/ha.automations.yaml"

fail() {
  echo "D190 FAIL: $*" >&2
  exit 1
}

[[ -f "$LEDGER" ]] || fail "missing ledger binding: $LEDGER"
[[ -f "$OBSERVED" ]] || fail "missing observed binding: $OBSERVED"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$LEDGER" "$OBSERVED" <<'PY'
from __future__ import annotations

from datetime import datetime, timezone
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


def parse_expires(value: str):
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
    print(f"D190 FAIL: unable to parse bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

ledger_rows = ledger.get("items") if isinstance(ledger.get("items"), list) else []
observed_rows = observed.get("automations") if isinstance(observed.get("automations"), list) else []

ledger_map = {
    str(row.get("id", "")).strip(): row
    for row in ledger_rows
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}

allowed = {"approved", "ignored"}
violations: list[str] = []

for row in observed_rows:
    if not isinstance(row, dict):
        continue
    automation_id = str(row.get("entity_id", "")).strip()
    if not automation_id:
        continue

    entry = ledger_map.get(automation_id)
    if not entry:
        violations.append(f"unmanaged observed HA automation: {automation_id}")
        continue

    status = str(entry.get("status", "")).strip().lower()
    if status not in allowed:
        violations.append(f"{automation_id}: status must be approved|ignored (got {status or 'empty'})")
        continue

    if status == "ignored":
        expires = parse_expires(str(entry.get("expires_on", "")))
        if expires is None:
            violations.append(f"{automation_id}: ignored items require valid expires_on")
            continue
        if expires < datetime.now(timezone.utc).date():
            violations.append(f"{automation_id}: ignored expires_on is in the past ({expires.isoformat()})")

if violations:
    for msg in violations:
        print(f"D190 FAIL: {msg}", file=sys.stderr)
    print(f"D190 FAIL: HA automation ledger parity violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(f"D190 PASS: HA automation ledger parity valid ({len(observed_rows)} observed, {len(ledger_map)} ledgered)")
PY
