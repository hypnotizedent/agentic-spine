#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
INFISICAL_AGENT="$ROOT/ops/plugins/providers/bin/infisical-agent.sh"
CHECKS=(
  "$ROOT/ops/plugins/infra/secrets/bin/secrets-binding"
  "$ROOT/ops/plugins/infra/secrets/bin/secrets-auth-status"
  "$ROOT/ops/plugins/infra/secrets/bin/secrets-namespace-status"
  "$ROOT/ops/plugins/infra/secrets/bin/secrets-enforcement-status"
)

[[ -x "$INFISICAL_AGENT" ]] || {
  echo "G14 FAIL: missing Infisical agent: $INFISICAL_AGENT" >&2
  exit 2
}

failures=0

for script in "${CHECKS[@]}"; do
  echo "==> $(basename "$script")"
  [[ -x "$script" ]] || {
    echo "G14 FAIL: missing secrets probe: $script" >&2
    failures=$((failures + 1))
    echo
    continue
  }
  set +e
  "$script"
  rc=$?
  set -e
  echo
  if [[ "$rc" -ne 0 ]]; then
    failures=$((failures + 1))
  fi
done

echo "==> representative secret fetch"
set +e
"$INFISICAL_AGENT" get-cached infrastructure prod UNIFI_HOME_API_KEY >/dev/null 2>&1
fetch_rc=$?
set -e

if [[ "$fetch_rc" -ne 0 ]]; then
  echo "G14 FAIL: representative runtime secret fetch failed" >&2
  failures=$((failures + 1))
else
  echo "representative secret fetch: PASS"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "G14 FAIL: secrets availability checks failed=$failures" >&2
  exit 1
fi

echo "G14 PASS: secrets availability healthy"
