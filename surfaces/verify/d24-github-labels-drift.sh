#!/usr/bin/env bash
set -euo pipefail

# D24: GitHub Labels Surface Lock
# Ensures the labels capability is read-only, non-leaky, and spine-native.
#
# FORBID:
#   - Mutation commands (gh label create/delete/edit)
#   - Legacy smells (ronny-ops, ~/agent)
#   - Secret leak patterns
#
# ALLOW:
#   - gh label list (read-only)
#   - yq parsing of .github/labels.yml

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { echo "D24 FAIL: $*" >&2; exit 1; }

# 1) Verify .github/labels.yml exists
[[ -f "$ROOT/.github/labels.yml" ]] || fail ".github/labels.yml not found"

# 2) Verify github-labels-status script exists
GL_SCRIPT="$ROOT/ops/plugins/github/bin/github-labels-status"
[[ -f "$GL_SCRIPT" ]] || fail "github-labels-status script not found"

# Scope: labels script + github plugin surface
FILES=(
  "$GL_SCRIPT"
)

# 3) Deny mutation commands (gh label create/delete/edit)
MUT_RE='gh\s+label\s+(create|delete|edit)'
if grep -nE "$MUT_RE" "${FILES[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "mutation commands detected (gh label create/delete/edit)"
fi

# 4) Deny legacy smells
DENY_RE='(ronny-ops|~/agent\b|/agent/|\$HOME/agent)'
if grep -nE "$DENY_RE" "${FILES[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "legacy coupling detected (ronny-ops or ~/agent)"
fi

# 5) Deny secret leak patterns
LEAK_RE='(echo|printf).*(TOKEN|SECRET|API_KEY|PASSWORD|BEARER)'
if grep -nEi "$LEAK_RE" "${FILES[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "potential secret printing detected"
fi

echo "D24 PASS: github labels surface drift locked"
