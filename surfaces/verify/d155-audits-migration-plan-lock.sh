#!/usr/bin/env bash
# TRIAGE: Regenerate audits inventory/plan and fix invalid dry-run entries before running hygiene wave.
# D155: audits migration plan lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
AUDITS_DIR="$ROOT/docs/governance/_audits"
PLAN_PATH="$ROOT/ops/bindings/audits.migration.plan.yaml"

fail() {
  echo "D155 FAIL: $*" >&2
  exit 1
}

[[ -d "$AUDITS_DIR" ]] || fail "missing audits directory: $AUDITS_DIR"
[[ -f "$PLAN_PATH" ]] || fail "missing migration plan: $PLAN_PATH"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

latest_inventory="$(ls -1 "$AUDITS_DIR"/MIGRATION_INVENTORY_*.yaml 2>/dev/null | sort | tail -n 1 || true)"
[[ -n "$latest_inventory" ]] || fail "missing inventory: docs/governance/_audits/MIGRATION_INVENTORY_YYYYMMDD.yaml"

python3 - "$latest_inventory" "$PLAN_PATH" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

inventory_path = Path(sys.argv[1])
plan_path = Path(sys.argv[2])


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


errors: list[str] = []

try:
    inventory = load_yaml(inventory_path)
except Exception as exc:
    print(f"D155 FAIL: inventory parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

try:
    plan = load_yaml(plan_path)
except Exception as exc:
    print(f"D155 FAIL: plan parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

entries = inventory.get("entries")
actions = plan.get("actions")
if not isinstance(entries, list):
    errors.append("inventory.entries must be a list")
    entries = []
if not isinstance(actions, list):
    errors.append("plan.actions must be a list")
    actions = []

inv_total = len(entries)
inv_move = 0
inv_keep = 0
inv_review = 0

for idx, entry in enumerate(entries, start=1):
    if not isinstance(entry, dict):
        errors.append(f"inventory.entries[{idx}] must be a map")
        continue

    src = str(entry.get("source_path", "")).strip()
    if not src.startswith("docs/governance/_audits/"):
        errors.append(f"inventory entry source outside audits root: {src or '<empty>'}")

    action = str(entry.get("migration_action", "")).strip()
    if action == "move":
        inv_move += 1
    elif action == "keep":
        inv_keep += 1
    elif action == "review":
        inv_review += 1
    else:
        errors.append(f"inventory entry invalid migration_action: {action or '<empty>'}")

plan_totals = plan.get("totals") or {}
if not isinstance(plan_totals, dict):
    errors.append("plan.totals must be a map")
    plan_totals = {}

expected_totals = {
    "total_files": inv_total,
    "move_count": inv_move,
    "keep_count": inv_keep,
    "review_count": inv_review,
}
for key, expected in expected_totals.items():
    value = plan_totals.get(key)
    if value != expected:
        errors.append(f"plan.totals.{key}={value!r} does not match inventory count {expected}")

for idx, action in enumerate(actions, start=1):
    if not isinstance(action, dict):
        errors.append(f"plan.actions[{idx}] must be a map")
        continue

    source = str(action.get("source", "")).strip()
    if not source.startswith("docs/governance/_audits/"):
        errors.append(f"plan action source outside audits root: {source or '<empty>'}")

    dry_run = action.get("dry_run")
    if dry_run is not True:
        errors.append(f"plan action dry_run must be true at index {idx}")

if errors:
    for err in errors:
        print(f"  FAIL: {err}", file=sys.stderr)
    print(f"D155 FAIL: audits migration plan violations ({len(errors)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(
    f"D155 PASS: audits migration plan lock valid "
    f"(inventory={inventory_path.name} total={inv_total} move={inv_move} keep={inv_keep} review={inv_review})"
)
PY
