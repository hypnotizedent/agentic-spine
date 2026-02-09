#!/usr/bin/env bash
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

"$AUDIT" >/dev/null 2>&1
exit $?

