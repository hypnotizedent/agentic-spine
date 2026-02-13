#!/usr/bin/env bash
# TRIAGE: Ensure IPs match across DEVICE_IDENTITY, shop server SSOT, and bindings.
# D54 - SSOT IP parity lock (shop network)
#
# Pure local-file parity gate. No SSH, no ping.
# Fails when shop network bindings and SSOTs disagree.
#
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

AUDIT="$SP/ops/plugins/network/bin/network-shop-audit-status"

if [[ ! -x "$AUDIT" ]]; then
  echo "missing audit script: $AUDIT"
  exit 1
fi

echo "D54: checking shop network IP/SSOT parity via $AUDIT"
echo "  SSOTs: ops/bindings/shop-servers.yaml, docs/ssot/SHOP_SERVER_SSOT.md"

if ! "$AUDIT" 2>&1; then
  echo "D54 FAIL: IP parity mismatch detected"
  echo "  Hint: check ops/bindings/shop-servers.yaml and docs/ssot/SHOP_SERVER_SSOT.md for stale IPs"
  exit 1
fi

