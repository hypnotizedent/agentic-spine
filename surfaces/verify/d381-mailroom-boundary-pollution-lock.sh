#!/usr/bin/env bash
set -euo pipefail

# D381: mailroom-boundary-pollution-lock
# Detects domain-specific runtime state written to mailroom/state/ where it
# doesn't belong. Domain data must live in runtime/domain-state/ (resolved
# via SPINE_DOMAIN_STATE) or its target service (Paperless, HA, etc).
#
# Mode: regression (warn-only) → flip to strict after migration complete.
# Strict mode: set D381_STRICT=1 to make violations fail the gate.

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$ROOT" ]] || { echo "SKIP: not in a git repo"; exit 0; }
cd "$ROOT"

STRICT="${D381_STRICT:-0}"

# Forbidden subdirectories under mailroom/state/ — domain data, not governance.
FORBIDDEN_DIRS=(
  "mailroom/state/cases"
  "mailroom/state/calendar-sync"
  "mailroom/state/communications"
  "mailroom/state/capacity"
  "mailroom/state/runtime-snapshots"
  "mailroom/state/cloudflare-control-plane"
  "mailroom/state/finance"
)

declare -a violations=()
for dir in "${FORBIDDEN_DIRS[@]}"; do
  if [[ -d "$ROOT/$dir" ]]; then
    count=$(find "$ROOT/$dir" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$count" -gt 0 ]]; then
      violations+=("$dir ($count files)")
    fi
  fi
done

# Also check for staged files targeting forbidden dirs (catches new pollution).
staged="$(git diff --cached --name-only --diff-filter=ACMRT 2>/dev/null || true)"
declare -a staged_violations=()
if [[ -n "$staged" ]]; then
  for dir in "${FORBIDDEN_DIRS[@]}"; do
    if echo "$staged" | grep -q "^${dir}/"; then
      staged_violations+=("$dir (staged)")
    fi
  done
fi

declare -a all_violations=()
for v in "${violations[@]-}"; do
  [[ -n "$v" ]] && all_violations+=("$v")
done
for v in "${staged_violations[@]-}"; do
  [[ -n "$v" ]] && all_violations+=("$v")
done

if [[ "${#all_violations[@]}" -eq 0 ]]; then
  echo "D381: PASS — no domain data in mailroom/state/"
  exit 0
fi

echo "D381: domain data found in mailroom/state/ (boundary violation)" >&2
for v in "${all_violations[@]}"; do
  echo "  - $v" >&2
done
echo "" >&2
echo "Remediation: move domain state to runtime/domain-state/ (resolved via SPINE_DOMAIN_STATE)." >&2
echo "  Cases → Paperless tags/custom fields" >&2
echo "  Calendar sync → runtime/domain-state/calendar/" >&2
echo "  Snapshots → runtime/domain-state/snapshots/" >&2
echo "  Capacity → runtime/domain-state/capacity/" >&2
echo "  Communications → runtime/domain-state/communications/" >&2
echo "  Cloudflare → runtime/domain-state/cloudflare/" >&2
echo "  Finance → runtime/domain-state/finance/" >&2

if [[ "$STRICT" == "1" ]]; then
  echo "" >&2
  echo "D381: FAIL (strict mode)" >&2
  exit 1
fi

echo "" >&2
echo "D381: WARN (regression mode — will become strict after migration)" >&2
exit 0
