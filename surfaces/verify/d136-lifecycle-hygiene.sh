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
            '.rules.aging.thresholds.warning_days' '.rules.aging.thresholds.critical_days'; do
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

# ── Check 3: no orphaned gaps (open gap linked to closed loop) ──
if [[ -d "$SCOPES_DIR" ]]; then
  # Build list of closed loop IDs
  closed_loops=""
  for scope_file in "$SCOPES_DIR"/*.scope.md; do
    [[ -f "$scope_file" ]] || continue
    local_status="$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$scope_file" \
      | { grep "^status:" || true; } \
      | sed 's/^status: *//' | tr -d '"' | head -1)"
    if [[ "$local_status" == "closed" ]]; then
      lid="$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$scope_file" \
        | { grep "^loop_id:" || true; } \
        | sed 's/^loop_id: *//' | tr -d '"' | head -1)"
      [[ -n "$lid" ]] && closed_loops="${closed_loops}${lid}|"
    fi
  done

  if [[ -n "$closed_loops" ]]; then
    # Remove trailing pipe
    closed_loops="${closed_loops%|}"

    orphan_count="$(python3 - "$GAPS_FILE" "$closed_loops" <<'PY'
import json
import subprocess
import sys

gaps_file = sys.argv[1]
closed_pattern = sys.argv[2]
closed_set = set(closed_pattern.split("|"))

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
orphans = sum(1 for g in gaps
              if g.get("status") == "open"
              and g.get("parent_loop", "") in closed_set)
print(orphans)
PY
)"

    if [[ "$orphan_count" -gt 0 ]]; then
      echo "D136 FAIL: $orphan_count orphaned gaps (open gap linked to closed loop)" >&2
      errors=$((errors + 1))
    fi
  fi
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
