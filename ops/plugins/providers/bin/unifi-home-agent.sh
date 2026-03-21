#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "${SCRIPT_DIR}/../../../.." && pwd)}"
INFISICAL_AGENT="${SPINE_ROOT}/ops/plugins/providers/bin/infisical-agent.sh"
HELPER="${SCRIPT_DIR}/unifi-home-api-query"
TARGET="${WORKBENCH_ROOT:-$HOME/code/workbench}/scripts/agents/unifi-home-agent.sh"

inject_home_creds() {
  if [[ -x "$INFISICAL_AGENT" ]]; then
    UNIFI_HOME_USER="${UNIFI_HOME_USER:-$(SPINE_ROOT="$SPINE_ROOT" SPINE_REPO="$SPINE_ROOT" SPINE_CODE="$SPINE_ROOT" "$INFISICAL_AGENT" get-cached infrastructure prod UNIFI_HOME_USER 2>/dev/null || true)}"
    UNIFI_HOME_PASSWORD="${UNIFI_HOME_PASSWORD:-$(SPINE_ROOT="$SPINE_ROOT" SPINE_REPO="$SPINE_ROOT" SPINE_CODE="$SPINE_ROOT" "$INFISICAL_AGENT" get-cached infrastructure prod UNIFI_HOME_PASSWORD 2>/dev/null || true)}"
    UNIFI_HOME_API_KEY="${UNIFI_HOME_API_KEY:-$(SPINE_ROOT="$SPINE_ROOT" SPINE_REPO="$SPINE_ROOT" SPINE_CODE="$SPINE_ROOT" "$INFISICAL_AGENT" get-cached infrastructure prod UNIFI_HOME_API_KEY 2>/dev/null || true)}"
    export UNIFI_HOME_USER UNIFI_HOME_PASSWORD UNIFI_HOME_API_KEY
  fi
}

case "${1:-}" in
  auth|clients)
    [[ -x "$HELPER" ]] || { echo "ERROR: governed unifi-home helper missing: $HELPER" >&2; exit 1; }
    exec "$HELPER" "$@"
    ;;
esac

[[ -f "$TARGET" ]] || { echo "ERROR: workbench unifi-home agent missing: $TARGET" >&2; exit 1; }
inject_home_creds
exec bash "$TARGET" "$@"
