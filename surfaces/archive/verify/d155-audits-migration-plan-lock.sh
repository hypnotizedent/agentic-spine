#!/usr/bin/env bash
# TRIAGE: Keep audits migration metadata strict while enforcing receipts/audits as the post-migration execution destination.
# D155: audits migration plan lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
PLAN_PATH="$ROOT/ops/bindings/audits.migration.plan.yaml"
MIGRATION_RECEIPTS_DIR="$ROOT/receipts/audits/migration"
TARGETS_DOC="$ROOT/docs/governance/AUDITS_MIGRATION_TARGETS_V1.md"

fail() {
  echo "D155 FAIL: $*" >&2
  exit 1
}

[[ -f "$PLAN_PATH" ]] || fail "missing migration plan: $PLAN_PATH"
[[ -f "$TARGETS_DOC" ]] || fail "missing migration targets policy doc: $TARGETS_DOC"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

latest_inventory="$(ls -1 "$MIGRATION_RECEIPTS_DIR"/MIGRATION_INVENTORY_*.yaml 2>/dev/null | sort | tail -n 1 || true)"
[[ -n "$latest_inventory" ]] || fail "missing inventory: receipts/audits/migration/MIGRATION_INVENTORY_YYYYMMDD.yaml"
latest_move_receipt="$(ls -1 "$MIGRATION_RECEIPTS_DIR"/H2_*_move_receipt.yaml 2>/dev/null | sort | tail -n 1 || true)"

python3 - "$latest_inventory" "$PLAN_PATH" "$latest_move_receipt" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

inventory_path = Path(sys.argv[1])
plan_path = Path(sys.argv[2])
receipt_arg = (sys.argv[3] or "").strip()
receipt_path = Path(receipt_arg) if receipt_arg else None

LEGACY_AUDITS_PREFIX = "docs/governance/_audits/"
LEGACY_KEEP_PREFIX = "docs/governance/_audits/KEEP/"
RECEIPTS_AUDITS_PREFIX = "receipts/audits/"


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

receipt = {}
if receipt_path is not None:
    try:
        receipt = load_yaml(receipt_path)
    except Exception as exc:
        errors.append(f"receipt parse error ({receipt_path}): {exc}")
        receipt = {}

entries = inventory.get("entries")
actions = plan.get("actions")
if not isinstance(entries, list):
    errors.append("inventory.entries must be a list")
    entries = []
if not isinstance(actions, list):
    errors.append("plan.actions must be a list")
    actions = []

inventory_source_root = str(inventory.get("source_root", "")).strip()
if inventory_source_root:
    if not (
        inventory_source_root.startswith(LEGACY_AUDITS_PREFIX.rstrip("/"))
        or inventory_source_root.startswith(RECEIPTS_AUDITS_PREFIX.rstrip("/"))
    ):
        errors.append(
            f"inventory source_root must start with '{LEGACY_AUDITS_PREFIX.rstrip('/')}' or "
            f"'{RECEIPTS_AUDITS_PREFIX.rstrip('/')}' (got '{inventory_source_root}')"
        )

inv_total = len(entries)
inv_move = 0
inv_keep = 0
inv_review = 0

for idx, entry in enumerate(entries, start=1):
    if not isinstance(entry, dict):
        errors.append(f"inventory.entries[{idx}] must be a map")
        continue

    src = str(entry.get("source_path", "")).strip()
    if not (src.startswith(LEGACY_AUDITS_PREFIX) or src.startswith(RECEIPTS_AUDITS_PREFIX)):
        errors.append(
            "inventory entry source outside approved roots "
            f"('{LEGACY_AUDITS_PREFIX}' or '{RECEIPTS_AUDITS_PREFIX}'): {src or '<empty>'}"
        )

    action = str(entry.get("migration_action", "")).strip()
    proposed_target = str(entry.get("proposed_target_path", "")).strip()
    if not proposed_target:
        errors.append(f"inventory entry missing proposed_target_path: {src or '<empty>'}")
    elif action == "move":
        if not proposed_target.startswith(RECEIPTS_AUDITS_PREFIX):
            errors.append(
                "inventory move action must target receipts/audits/** "
                f"(source={src or '<empty>'} target={proposed_target})"
            )
    elif action in {"keep", "review"}:
        if not (
            proposed_target.startswith(RECEIPTS_AUDITS_PREFIX)
            or proposed_target.startswith(LEGACY_KEEP_PREFIX)
        ):
            errors.append(
                "inventory keep/review target must be receipts/audits/** or docs/governance/_audits/KEEP/** "
                f"(source={src or '<empty>'} target={proposed_target})"
            )

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

execution_mode = any(
    isinstance(action, dict) and action.get("dry_run") is False
    for action in actions
)

receipt_results: dict[str, str] = {}
if execution_mode:
    if receipt_path is None:
        errors.append("execution-mode plan requires receipts/audits/migration/H2_*_move_receipt.yaml")
    executed_at = str(plan.get("executed_at", "")).strip()
    executed_by = str(plan.get("executed_by", "")).strip()
    if not executed_at:
        errors.append("execution-mode plan requires top-level executed_at")
    if not executed_by:
        errors.append("execution-mode plan requires top-level executed_by")

    for key in ("moved_count", "skipped_count", "failed_count"):
        value = plan.get(key)
        if not isinstance(value, int) or value < 0:
            errors.append(f"execution-mode plan requires non-negative integer '{key}'")

    moves_payload = receipt.get("moves") if isinstance(receipt, dict) else None
    if not isinstance(moves_payload, list):
        errors.append("execution-mode plan requires receipt.moves list")
        moves_payload = []

    for idx, row in enumerate(moves_payload, start=1):
        if not isinstance(row, dict):
            errors.append(f"receipt.moves[{idx}] must be a map")
            continue
        rid = str(row.get("id", "")).strip()
        rres = str(row.get("result", "")).strip()
        rtarget = str(row.get("target", "")).strip()
        if not rid:
            errors.append(f"receipt.moves[{idx}] missing id")
            continue
        if rres not in {"moved", "skipped", "failed"}:
            errors.append(f"receipt.moves[{idx}] invalid result '{rres or '<empty>'}'")
            continue
        if not rtarget:
            errors.append(f"receipt.moves[{idx}] missing target")
            continue
        if rres == "moved" and not rtarget.startswith(RECEIPTS_AUDITS_PREFIX):
            errors.append(
                f"receipt.moves[{idx}] moved target must be receipts/audits/** (got '{rtarget}')"
            )
        if rres in {"skipped", "failed"} and not (
            rtarget.startswith(RECEIPTS_AUDITS_PREFIX) or rtarget.startswith(LEGACY_KEEP_PREFIX)
        ):
            errors.append(
                f"receipt.moves[{idx}] skipped/failed target must be receipts/audits/** "
                f"or docs/governance/_audits/KEEP/** (got '{rtarget}')"
            )
        receipt_results[rid] = rres

for idx, action in enumerate(actions, start=1):
    if not isinstance(action, dict):
        errors.append(f"plan.actions[{idx}] must be a map")
        continue

    source = str(action.get("source", "")).strip()
    target = str(action.get("target", "")).strip()
    if not (source.startswith(LEGACY_AUDITS_PREFIX) or source.startswith(RECEIPTS_AUDITS_PREFIX)):
        errors.append(
            "plan action source outside approved roots "
            f"('{LEGACY_AUDITS_PREFIX}' or '{RECEIPTS_AUDITS_PREFIX}'): {source or '<empty>'}"
        )
    if not target:
        errors.append(f"plan action target missing at index {idx}")

    dry_run = action.get("dry_run")
    if dry_run is True:
        if not (
            target.startswith(RECEIPTS_AUDITS_PREFIX) or target.startswith(LEGACY_KEEP_PREFIX)
        ):
            errors.append(
                "dry_run=true target must be receipts/audits/** or docs/governance/_audits/KEEP/** "
                f"(index={idx} target={target or '<empty>'})"
            )
        continue

    if dry_run is False:
        if not target.startswith(RECEIPTS_AUDITS_PREFIX):
            errors.append(
                "dry_run=false action target must be receipts/audits/** "
                f"(index={idx} target={target or '<empty>'})"
            )
        if not execution_mode:
            errors.append(f"plan action dry_run=false without execution-mode metadata at index {idx}")
            continue

        aid = str(action.get("id", "")).strip()
        if not aid:
            errors.append(f"execution-mode action missing id at index {idx}")
            continue

        if aid not in receipt_results:
            errors.append(f"execution-mode action '{aid}' missing from move receipt")
            continue

        if receipt_results[aid] not in {"moved", "skipped", "failed"}:
            errors.append(
                f"execution-mode action '{aid}' invalid receipt result '{receipt_results[aid]}'"
            )
        continue

    errors.append(f"plan action dry_run must be boolean true/false at index {idx}")

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
