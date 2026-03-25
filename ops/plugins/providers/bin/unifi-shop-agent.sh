#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "${SCRIPT_DIR}/../../../.." && pwd)}"
INFISICAL_AGENT="${SPINE_ROOT}/ops/plugins/providers/bin/infisical-agent.sh"
HELPER="${SCRIPT_DIR}/unifi-shop-api-query"
source "$SPINE_ROOT/ops/plugins/infra/lib/workbench-paths.sh"
TARGET="$(workbench_repo_root)/scripts/agents/unifi-shop-agent.sh"

inject_shop_creds() {
  if [[ -x "$INFISICAL_AGENT" ]]; then
    UNIFI_SHOP_USER="${UNIFI_SHOP_USER:-$(SPINE_ROOT="$SPINE_ROOT" SPINE_REPO="$SPINE_ROOT" SPINE_CODE="$SPINE_ROOT" "$INFISICAL_AGENT" get-cached infrastructure prod UNIFI_SHOP_USER 2>/dev/null || true)}"
    UNIFI_SHOP_PASSWORD="${UNIFI_SHOP_PASSWORD:-$(SPINE_ROOT="$SPINE_ROOT" SPINE_REPO="$SPINE_ROOT" SPINE_CODE="$SPINE_ROOT" "$INFISICAL_AGENT" get-cached infrastructure prod UNIFI_SHOP_PASSWORD 2>/dev/null || true)}"
    UNIFI_SHOP_API_KEY="${UNIFI_SHOP_API_KEY:-$(SPINE_ROOT="$SPINE_ROOT" SPINE_REPO="$SPINE_ROOT" SPINE_CODE="$SPINE_ROOT" "$INFISICAL_AGENT" get-cached infrastructure prod UNIFI_SHOP_API_KEY 2>/dev/null || true)}"
    export UNIFI_SHOP_USER UNIFI_SHOP_PASSWORD UNIFI_SHOP_API_KEY
  fi
}

case "${1:-}" in
  auth|clients)
    [[ -x "$HELPER" ]] || { echo "ERROR: governed unifi-shop helper missing: $HELPER" >&2; exit 1; }
    exec "$HELPER" "$@"
    ;;
esac

[[ -f "$TARGET" ]] || { echo "ERROR: workbench unifi-shop agent missing: $TARGET" >&2; exit 1; }
inject_shop_creds
exec bash "$TARGET" "$@"
