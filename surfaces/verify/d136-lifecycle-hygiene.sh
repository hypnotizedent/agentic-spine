#!/usr/bin/env bash
# TRIAGE: Run ops cap run lifecycle.health for details. Check lifecycle.rules.yaml exists with required fields, no orphaned gaps.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RULES_FILE="$ROOT/ops/bindings/lifecycle.rules.yaml"
SCHEMA_FILE="$ROOT/ops/bindings/lifecycle.rules.schema.yaml"
GAPS_FILE="$ROOT/ops/bindings/operational.gaps.yaml"
SCOPES_DIR="$ROOT/mailroom/state/loop-scopes"

source "$ROOT/ops/lib/resolve-policy.sh"
resolve_policy_knobs

fail() {
  echo "D136 FAIL: $*" >&2
  exit 1
}

warn() {
  echo "D136 WARN: $*" >&2
}

errors=0

# ── Check 1: lifecycle.rules.yaml exists with required fields ──
[[ -f "$RULES_FILE" ]] || fail "lifecycle.rules.yaml not found: $RULES_FILE"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

for field in version updated owner; do
  val="$(yq e ".$field" "$RULES_FILE" 2>/dev/null || true)"
  if [[ -z "$val" || "$val" == "null" ]]; then
    echo "D136 FAIL: missing required field '$field' in lifecycle.rules.yaml" >&2
    errors=$((errors + 1))
  fi
done

for path in '.rules.gap_quick.default_type' '.rules.gap_quick.default_severity' \
            '.rules.aging.thresholds.warning_days' '.rules.aging.thresholds.critical_days' \
            '.rules.linkage.parent_loop.required_for_statuses' '.rules.linkage.parent_loop.advisory_for_statuses'; do
  val="$(yq e "$path" "$RULES_FILE" 2>/dev/null || true)"
  if [[ -z "$val" || "$val" == "null" ]]; then
    echo "D136 FAIL: missing required field '$path' in lifecycle.rules.yaml" >&2
    errors=$((errors + 1))
  fi
done

# ── Check 2: schema file exists ──
if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "D136 FAIL: lifecycle.rules.schema.yaml not found: $SCHEMA_FILE" >&2
  errors=$((errors + 1))
fi

# ── Check 3: parent_loop linkage hygiene (required open/accepted, advisory closed/fixed) ──
if ! python3 - "$RULES_FILE" "$GAPS_FILE" "$SCOPES_DIR" <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

rules_file = Path(sys.argv[1])
gaps_file = Path(sys.argv[2])
scopes_dir = Path(sys.argv[3])


def yq_json(path: Path, expr: str):
    try:
        result = subprocess.run(
            ["yq", "e", "-o=json", expr, str(path)],
            capture_output=True,
            text=True,
            check=True,
        )
        text = result.stdout.strip()
        return json.loads(text) if text else None
    except Exception:
        return None


required_statuses_raw = yq_json(
    rules_file,
    ".rules.linkage.parent_loop.required_for_statuses // [\"open\", \"accepted\"]",
)
advisory_statuses_raw = yq_json(
    rules_file,
    ".rules.linkage.parent_loop.advisory_for_statuses // [\"closed\", \"fixed\"]",
)

required_statuses = {
    str(s).strip().lower()
    for s in (required_statuses_raw or [])
    if str(s).strip()
}
advisory_statuses = {
    str(s).strip().lower()
    for s in (advisory_statuses_raw or [])
    if str(s).strip()
}

if not required_statuses:
    required_statuses = {"open", "accepted"}
if not advisory_statuses:
    advisory_statuses = {"closed", "fixed"}

gaps_doc = yq_json(gaps_file, ".") or {}
gaps = gaps_doc.get("gaps", []) if isinstance(gaps_doc, dict) else []

closed_loops: set[str] = set()
if scopes_dir.is_dir():
    for scope_file in sorted(scopes_dir.glob("*.scope.md")):
        text = scope_file.read_text(encoding="utf-8", errors="ignore")
        if not text.startswith("---"):
            continue
        parts = text.split("---", 2)
        if len(parts) < 3:
            continue
        frontmatter = parts[1]
        status = ""
        loop_id = ""
        for raw_line in frontmatter.splitlines():
            line = raw_line.strip()
            if line.startswith("status:"):
                status = line.split(":", 1)[1].strip().strip('"').lower()
            elif line.startswith("loop_id:"):
                loop_id = line.split(":", 1)[1].strip().strip('"')
        if status == "closed" and loop_id:
            closed_loops.add(loop_id)

missing_required: list[tuple[str, str]] = []
orphan_open: list[tuple[str, str]] = []
advisory_missing: list[tuple[str, str]] = []

for gap in gaps:
    if not isinstance(gap, dict):
        continue
    gap_id = str(gap.get("id", "<unknown>")).strip() or "<unknown>"
    status = str(gap.get("status", "")).strip().lower()
    deferred_to_repo = str(gap.get("deferred_to_repo", "")).strip()
    parent_loop = gap.get("parent_loop")
    parent_loop_str = "" if parent_loop is None else str(parent_loop).strip()

    if status in required_statuses and not parent_loop_str:
        missing_required.append((gap_id, status))

    if status == "open" and deferred_to_repo:
        continue

    if status == "open" and parent_loop_str and parent_loop_str in closed_loops:
        orphan_open.append((gap_id, parent_loop_str))

    if status in advisory_statuses and not parent_loop_str:
        advisory_missing.append((gap_id, status))

max_print = 25
if missing_required:
    for gap_id, status in missing_required[:max_print]:
        print(
            f"D136 FAIL: {gap_id} status={status} requires parent_loop linkage",
            file=sys.stderr,
        )
    if len(missing_required) > max_print:
        print(
            f"D136 FAIL: ... and {len(missing_required) - max_print} more required-linkage gaps",
            file=sys.stderr,
        )

if orphan_open:
    for gap_id, loop_id in orphan_open[:max_print]:
        print(
            f"D136 FAIL: {gap_id} status=open linked to closed loop {loop_id}",
            file=sys.stderr,
        )
    if len(orphan_open) > max_print:
        print(
            f"D136 FAIL: ... and {len(orphan_open) - max_print} more open->closed loop link violations",
            file=sys.stderr,
        )

if advisory_missing:
    print(
        "D136 WARN: "
        f"{len(advisory_missing)} historical gap(s) in advisory statuses "
        f"{sorted(advisory_statuses)} missing parent_loop linkage",
        file=sys.stderr,
    )

if missing_required or orphan_open:
    print(
        "D136 FAIL: parent_loop linkage violations "
        f"(required_missing={len(missing_required)} open_orphans={len(orphan_open)})",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
then
  errors=$((errors + 1))
fi

# ── Check 4: aging advisory (warn, don't fail) ──
if command -v python3 >/dev/null 2>&1; then
  warn_days="$(yq e '.rules.aging.thresholds.warning_days' "$RULES_FILE" 2>/dev/null || echo 7)"
  crit_days="$(yq e '.rules.aging.thresholds.critical_days' "$RULES_FILE" 2>/dev/null || echo 14)"

  aging_critical="$(python3 - "$GAPS_FILE" "$crit_days" <<'PY'
import json
import subprocess
import sys
from datetime import datetime, timezone

gaps_file = sys.argv[1]
crit_days = int(sys.argv[2])
now = datetime.now(timezone.utc)

try:
    result = subprocess.run(
        ["yq", "e", "-o=json", ".", gaps_file],
        capture_output=True, text=True, check=True
    )
    data = json.loads(result.stdout)
except Exception:
    print("0")
    sys.exit(0)

gaps = data.get("gaps", [])
count = 0
for g in gaps:
    if g.get("status") != "open":
        continue
    d = g.get("discovered_at", "")
    if not d:
        continue
    try:
        dt = datetime.strptime(d, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        if (now - dt).days >= crit_days:
            count += 1
    except ValueError:
        pass
print(count)
PY
)"

  if [[ "$aging_critical" -gt 0 ]]; then
    warn "$aging_critical gaps exceed critical aging threshold (${crit_days} days)"
  fi
fi

# ── Result ──
if [[ "$errors" -gt 0 ]]; then
  fail "$errors check(s) failed"
fi

echo "D136 PASS: lifecycle hygiene OK"
