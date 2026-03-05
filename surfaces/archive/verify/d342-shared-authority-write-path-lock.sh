#!/usr/bin/env bash
# TRIAGE: Enforce capability-governed write path for shared authority gaps state.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
D75_GATE="$ROOT/surfaces/verify/d75-gap-registry-mutation-lock.sh"

fail() {
  echo "D342 FAIL: $*" >&2
  exit 1
}

[[ -x "$D75_GATE" ]] || fail "missing dependency gate: $D75_GATE"

if ! "$D75_GATE" >/dev/null; then
  fail "gap registry mutation boundary violation (use capability surfaces only)"
fi

echo "D342 PASS: shared authority write path lock (D75 boundary enforced)"
