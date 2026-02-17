#!/usr/bin/env bash
# TRIAGE: Validate dynamic briefing delivery path (spine.context + session hook).
# D65: Agent briefing context lock (WS-5 retirement model)
#
# Enforces:
# 1) Canonical governance brief exists and is non-empty.
# 2) Dynamic context script exists (spine-context).
# 3) Session-entry hook is wired to dynamic context.
# 4) Legacy sync hook exists only as retired compatibility shim.
# 5) AGENTS.md + CLAUDE.md keep governance markers (non-breaking surface contract).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail() { echo "D65 FAIL: $*" >&2; exit 1; }

BRIEF_FILE="docs/governance/AGENT_GOVERNANCE_BRIEF.md"
CONTEXT_SCRIPT="ops/plugins/context/bin/spine-context"
SESSION_HOOK="ops/hooks/session-entry-hook.sh"
SYNC_HOOK="ops/hooks/sync-agent-surfaces.sh"

# 1) Canonical brief must exist and remain non-empty.
[[ -f "$BRIEF_FILE" ]] || fail "missing governance brief: $BRIEF_FILE"
[[ -s "$BRIEF_FILE" ]] || fail "governance brief is empty: $BRIEF_FILE"

for section in \
  "## Commit & Branch Rules" \
  "## Capability Gotchas" \
  "## Path & Reference Constraints" \
  "## Verify & Receipts" \
  "## Quick Commands"; do
  grep -qF "$section" "$BRIEF_FILE" || fail "governance brief missing section: $section"
done

# 2) Dynamic context capability script must exist and be executable.
[[ -x "$CONTEXT_SCRIPT" ]] || fail "dynamic context script missing or not executable: $CONTEXT_SCRIPT"

# 3) Session-entry hook must resolve briefing via dynamic context path.
[[ -f "$SESSION_HOOK" ]] || fail "missing session hook: $SESSION_HOOK"
grep -qF "spine-context" "$SESSION_HOOK" || fail "session hook not wired to spine-context"
grep -qF "spine.context" "$SESSION_HOOK" || fail "session hook missing spine.context dynamic context reference"

# 4) Legacy sync hook allowed only as retired shim (no active sync dependency).
[[ -f "$SYNC_HOOK" ]] || fail "missing compatibility shim: $SYNC_HOOK"
grep -qF "RETIRED" "$SYNC_HOOK" || fail "legacy sync hook is still active (missing RETIRED marker)"

# 5) Surface files must exist and keep governance marker contract.
for file in AGENTS.md CLAUDE.md; do
  [[ -f "$file" ]] || fail "missing surface file: $file"
  grep -q '<!-- GOVERNANCE_BRIEF -->' "$file" || fail "$file missing <!-- GOVERNANCE_BRIEF --> marker"
  grep -q '<!-- /GOVERNANCE_BRIEF -->' "$file" || fail "$file missing <!-- /GOVERNANCE_BRIEF --> marker"
done

echo "D65 PASS: dynamic briefing delivery lock valid (spine.context path)"
