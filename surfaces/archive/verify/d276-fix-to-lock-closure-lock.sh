#!/usr/bin/env bash
# TRIAGE: every closed P0/P1 W60 finding must carry root_cause + lock + owner + expiry + evidence.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
MATRIX="$ROOT/docs/planning/W60_FINDING_TRUTH_MATRIX.md"
MAPPING="$ROOT/docs/planning/W60_FIX_TO_LOCK_MAPPING.md"

fail() {
  echo "D276 FAIL: $*" >&2
  exit 1
}

[[ -f "$MATRIX" ]] || fail "missing matrix: $MATRIX"
[[ -f "$MAPPING" ]] || fail "missing mapping: $MAPPING"
command -v awk >/dev/null 2>&1 || fail "missing dependency: awk"

trim() {
  sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

mapfile -t required_ids < <(
  awk -F'|' '
    /^\| W60-F[0-9]+/ {
      fid=$2; sev=$7; action=$8;
      gsub(/^[ \t]+|[ \t]+$/, "", fid);
      gsub(/^[ \t]+|[ \t]+$/, "", sev);
      gsub(/^[ \t]+|[ \t]+$/, "", action);
      if ((sev=="P0" || sev=="P1") && (action=="fix_now" || action=="lock_only")) print fid;
    }
  ' "$MATRIX" | sort -u
)

[[ "${#required_ids[@]}" -gt 0 ]] || fail "no required P0/P1 fix rows found in W60 matrix"

errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

declare -A seen
while IFS='|' read -r _ fid root_cause lock_id owner expiry lock_evidence _rest; do
  fid="$(printf '%s' "$fid" | trim)"
  [[ "$fid" =~ ^W60-F[0-9]+$ ]] || continue
  seen["$fid"]=1

  root_cause="$(printf '%s' "$root_cause" | trim)"
  lock_id="$(printf '%s' "$lock_id" | trim)"
  owner="$(printf '%s' "$owner" | trim)"
  expiry="$(printf '%s' "$expiry" | trim)"
  lock_evidence="$(printf '%s' "$lock_evidence" | trim)"

  [[ -n "$root_cause" ]] || err "$fid missing root_cause"
  [[ -n "$lock_id" ]] || err "$fid missing regression_lock_id"
  [[ -n "$owner" ]] || err "$fid missing owner"
  [[ -n "$expiry" ]] || err "$fid missing expiry_check"
  [[ -n "$lock_evidence" ]] || err "$fid missing lock_evidence"

  if [[ "$lock_evidence" =~ ^(pending|tbd|TODO)$ ]]; then
    err "$fid lock_evidence must be concrete (run key or command), got '$lock_evidence'"
  fi
done < "$MAPPING"

for fid in "${required_ids[@]}"; do
  [[ -n "${seen[$fid]:-}" ]] || err "$fid missing in W60_FIX_TO_LOCK_MAPPING.md"
done

if [[ "$errors" -gt 0 ]]; then
  fail "$errors violation(s)"
fi

echo "D276 PASS: fix-to-lock closure evidence complete (required_rows=${#required_ids[@]})"
