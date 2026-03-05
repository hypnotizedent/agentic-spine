#!/usr/bin/env bash
# Temporary runtime switch for spine.verify.
# Mode is controlled by ops/bindings/spine.verify.runtime.yaml.
set -euo pipefail

SP="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RT="${SPINE_REPO:-$SP}"
cd "$SP"

RUNTIME_BINDING="$SP/ops/bindings/spine.verify.runtime.yaml"
MODE="full"
REASON=""
EXPIRES_AT=""

if [[ -f "$RUNTIME_BINDING" ]]; then
  MODE="$(yq e -r '.mode // "full"' "$RUNTIME_BINDING" 2>/dev/null || echo full)"
  REASON="$(yq e -r '.reason // ""' "$RUNTIME_BINDING" 2>/dev/null || true)"
  EXPIRES_AT="$(yq e -r '.expires_at // ""' "$RUNTIME_BINDING" 2>/dev/null || true)"
fi

case "$MODE" in
  full)
    exec "$SP/surfaces/verify/drift-gate.sh" "$@"
    ;;
  core_only)
    echo "=== SPINE VERIFY (TEMPORARY CORE-ONLY MODE) ==="
    [[ -n "$REASON" ]] && echo "reason: $REASON"
    [[ -n "$EXPIRES_AT" ]] && echo "expires_at: $EXPIRES_AT"
    echo "mode: core_only"
    echo "release/nightly full verify remains available via: ./bin/ops cap run verify.release.run"
    echo
    exec "$SP/ops/plugins/verify/bin/verify-topology" core "$@"
    ;;
  *)
    echo "FAIL: invalid spine.verify mode in $RUNTIME_BINDING: $MODE" >&2
    echo "Expected: full | core_only" >&2
    exit 1
    ;;
esac

