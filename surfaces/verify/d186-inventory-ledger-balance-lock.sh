#!/usr/bin/env bash
# TRIAGE: reconcile inventory.transaction.ledger totals with on_hand_qty in hardware/business inventory bindings before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LEDGER="$ROOT/ops/bindings/inventory.transaction.ledger.yaml"
PARTS="$ROOT/ops/bindings/hardware.parts.inventory.yaml"
CATALOG="$ROOT/ops/bindings/business.inventory.catalog.yaml"

fail() {
  echo "D186 FAIL: $*" >&2
  exit 1
}

[[ -f "$LEDGER" ]] || fail "missing ledger binding: $LEDGER"
[[ -f "$PARTS" ]] || fail "missing parts binding: $PARTS"
[[ -f "$CATALOG" ]] || fail "missing catalog binding: $CATALOG"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$LEDGER" "$PARTS" "$CATALOG" <<'PY'
from __future__ import annotations

from collections import defaultdict
from pathlib import Path
import sys

import yaml

ledger_path = Path(sys.argv[1]).expanduser().resolve()
parts_path = Path(sys.argv[2]).expanduser().resolve()
catalog_path = Path(sys.argv[3]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


def as_float(value, label: str) -> float:
    try:
        return float(value)
    except Exception:
        raise ValueError(f"{label} must be numeric")


try:
    ledger_doc = load_yaml(ledger_path)
    parts_doc = load_yaml(parts_path)
    catalog_doc = load_yaml(catalog_path)
except Exception as exc:
    print(f"D186 FAIL: unable to parse bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

transactions = ledger_doc.get("transactions") if isinstance(ledger_doc.get("transactions"), list) else []
allowed_actions = {
    str(x).strip()
    for x in (((ledger_doc.get("enums") or {}).get("action")) or [])
    if str(x).strip()
}
required_fields = [
    str(x).strip()
    for x in (ledger_doc.get("required_fields") or [])
    if str(x).strip()
]

inventory: dict[tuple[str, str], float] = {}
violations: list[tuple[str, str]] = []

for row in (parts_doc.get("parts") or []):
    if not isinstance(row, dict):
        continue
    item_id = str(row.get("id", "")).strip()
    if not item_id:
        continue
    try:
        inventory[("part", item_id)] = as_float(row.get("on_hand_qty", 0), f"part/{item_id} on_hand_qty")
    except Exception as exc:
        violations.append((str(parts_path), str(exc)))

for row in (catalog_doc.get("materials") or []):
    if not isinstance(row, dict):
        continue
    item_id = str(row.get("id", "")).strip()
    if not item_id:
        continue
    try:
        inventory[("material", item_id)] = as_float(row.get("on_hand_qty", 0), f"material/{item_id} on_hand_qty")
    except Exception as exc:
        violations.append((str(catalog_path), str(exc)))

ledger_totals: dict[tuple[str, str], float] = defaultdict(float)
for idx, row in enumerate(transactions):
    row_tag = f"transactions[{idx}]"
    if not isinstance(row, dict):
        violations.append((str(ledger_path), f"{row_tag} must be mapping"))
        continue

    for key in required_fields:
        if key not in row:
            violations.append((str(ledger_path), f"{row_tag} missing required field: {key}"))

    item_class = str(row.get("item_class", "")).strip()
    item_id = str(row.get("item_id", "")).strip()
    action = str(row.get("action", "")).strip()

    if allowed_actions and action not in allowed_actions:
        violations.append((str(ledger_path), f"{row_tag} action not allowed: {action}"))

    if (item_class, item_id) not in inventory:
        violations.append((str(ledger_path), f"{row_tag} references unknown inventory item: {item_class}/{item_id}"))
        continue

    try:
        qty_delta = as_float(row.get("qty_delta", 0), f"{row_tag} qty_delta")
    except Exception as exc:
        violations.append((str(ledger_path), str(exc)))
        continue

    if action == "move" and abs(qty_delta) > 1e-9:
        violations.append((str(ledger_path), f"{row_tag} move action must have qty_delta=0"))

    ledger_totals[(item_class, item_id)] += qty_delta

for key, on_hand in sorted(inventory.items()):
    expected = ledger_totals.get(key, 0.0)
    if abs(on_hand - expected) > 1e-9:
        cls, item_id = key
        violations.append(("inventory-balance", f"{cls}/{item_id}: on_hand_qty={on_hand:g} expected_from_ledger={expected:g}"))

if violations:
    for source, msg in violations:
        print(f"D186 FAIL: {source} :: {msg}", file=sys.stderr)
    print(f"D186 FAIL: inventory ledger balance violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D186 PASS: ledger balances match inventory on_hand_qty")
PY
