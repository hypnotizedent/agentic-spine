#!/usr/bin/env bash
# TRIAGE: Remove competing truth documents. Only one canonical doc per topic in docs/governance/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { echo "D16 FAIL: $*" >&2; exit 1; }

cd "$ROOT"

# A) _imports must not exist at repo root
if [ -d "$ROOT/_imports" ]; then
  fail "_imports/ exists at repo root; move to docs/legacy/_imports or .archive/_imports"
fi

# B) Ensure canonical pointer exists
[ -f "$ROOT/docs/core/CANONICAL_DOCS.md" ] || fail "missing docs/core/CANONICAL_DOCS.md"

# C) Forbid ronny-ops legacy coupling markers outside quarantine areas
# Only forbid explicit ronny-ops patterns, not spine runtime patterns
# Allowed: docs/legacy/**, docs/governance/**, docs/brain/**, .archive/**
FORBID_RE='(ronny-ops|LaunchAgents|launchd|\.plist)'

# Scan docs excluding docs/core, docs/legacy, docs/governance, docs/brain
if rg -n -S "$FORBID_RE" docs \
  -g'!docs/core/**' -g'!docs/legacy/**' -g'!docs/governance/**' -g'!docs/brain/**' -g'!docs/planning/**' \
  >/dev/null 2>&1; then
  echo "D16 FAIL: forbidden ronny-ops markers found in docs outside docs/core + docs/legacy + docs/governance + docs/brain + docs/planning" >&2
  rg -n -S "$FORBID_RE" docs -g'!docs/core/**' -g'!docs/legacy/**' -g'!docs/governance/**' -g'!docs/brain/**' -g'!docs/planning/**' | head -80 >&2
  exit 1
fi

echo "D16 PASS"
