#!/usr/bin/env bash
# TRIAGE: Root-path secrets must remain zero; namespace status must be strict OK.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN="$ROOT/ops/plugins/secrets/bin/secrets-namespace-status"

fail() { echo "D212 FAIL: $*" >&2; exit 1; }

[[ -x "$PLUGIN" ]] || fail "missing plugin: ops/plugins/secrets/bin/secrets-namespace-status"

TMP="$(mktemp)"
set +e
"$PLUGIN" >"$TMP" 2>&1
RC=$?
set -e
if [[ "$RC" -ne 0 ]]; then
  sed -n '1,120p' "$TMP" >&2 || true
  rm -f "$TMP"
  fail "secrets-namespace-status exited non-zero (${RC})"
fi

if ! rg -q '^status:\s+OK$' "$TMP"; then
  sed -n '1,120p' "$TMP" >&2 || true
  rm -f "$TMP"
  fail "namespace status must be strict OK"
fi

rm -f "$TMP"
echo "D212 PASS: runtime namespace lock strict OK"
