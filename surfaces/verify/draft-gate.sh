#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# draft-gate.sh - WIP / draft subject enforcement gate
# ═══════════════════════════════════════════════════════════════
#
# Scans recent commits on the current branch for WIP-style subjects
# that should not have passed commit ceremony.
#
# Checks: WIP:, wip:, fixup!, squash!, work-in-progress
#
# Exit: 0 = PASS, 1 = FAIL (WIP-style subjects found)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SP"

# Number of recent commits to scan (default: 20)
SCAN_DEPTH="${DRAFT_GATE_DEPTH:-20}"

FAIL=0
HITS=""

while IFS= read -r subject; do
  [[ -n "$subject" ]] || continue
  wip_pattern='^(WIP[: ]|wip[: ]|fixup[!]|squash[!]|FIXUP[!]|SQUASH[!]|[Ww]ork[ -][Ii]n[ -][Pp]rogress)'
  if [[ "$subject" =~ $wip_pattern ]]; then
    HITS="${HITS}  - ${subject}\n"
    FAIL=1
  fi
done < <(git log --oneline -n "$SCAN_DEPTH" --format='%s' 2>/dev/null)

if [[ "$FAIL" -eq 1 ]]; then
  echo "FAIL: WIP-style commit subjects found in recent history:"
  printf '%b' "$HITS"
  echo "Remediation: rewrite these subjects before merge."
  exit 1
fi

echo "PASS: no WIP-style subjects in last $SCAN_DEPTH commits"
exit 0
