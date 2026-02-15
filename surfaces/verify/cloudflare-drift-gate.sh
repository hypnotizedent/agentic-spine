#!/usr/bin/env bash
# TRIAGE: Check Cloudflare SSOT docs for legacy references. Update or remove stale entries.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CF_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-status"

# 1) must exist
if [ ! -f "$CF_SCRIPT" ]; then
  echo "FAIL: missing $CF_SCRIPT"
  exit 1
fi

# 2) denylist: legacy/runtime smells (cloudflare surface must never reference these)
DENY_RE='(ronny-ops|/ronny-ops|~/ronny-ops|LaunchAgents|\.plist\b|cron\b|~/agent\b|state/|receipts/|~/logs\b|/logs/)'

# Search in cloudflare plugin surface + capability registry only
TARGETS=(
  "$ROOT/ops/plugins/cloudflare"
)

HITS="$(grep -RInE --binary-files=without-match "$DENY_RE" "${TARGETS[@]}" 2>/dev/null || true)"
if [ -n "$HITS" ]; then
  echo "FAIL: cloudflare surface contains legacy/runtime smells:"
  echo "$HITS"
  exit 1
fi

# Check only cloudflare capability definitions (avoid unrelated capability noise).
if command -v yq >/dev/null 2>&1; then
  CF_CAPS="$(yq e -o=json '.capabilities | with_entries(select(.key | test("^cloudflare\\.")))' "$ROOT/ops/capabilities.yaml" 2>/dev/null || true)"
  if [[ -n "${CF_CAPS:-}" ]] && echo "$CF_CAPS" | grep -nE --binary-files=without-match "$DENY_RE" >/dev/null 2>&1; then
    echo "FAIL: cloudflare capability definitions contain legacy/runtime smells:"
    echo "$CF_CAPS" | grep -nE --binary-files=without-match "$DENY_RE"
    exit 1
  fi
fi

# 3) enforce read-only: no POST/PUT/PATCH/DELETE patterns in cloudflare-status
MUT_RE='(-X[[:space:]]+(POST|PUT|PATCH|DELETE)|\bPOST\b|\bPUT\b|\bPATCH\b|\bDELETE\b)'
MUT="$(grep -nE --binary-files=without-match "$MUT_RE" "$CF_SCRIPT" 2>/dev/null || true)"
if [ -n "$MUT" ]; then
  echo "FAIL: cloudflare-status appears to mutate (must be read-only):"
  echo "$MUT"
  exit 1
fi

# 4) ensure token is never printed (guardrail)
# Look for echo/print statements that would output token values
# Allow: echo "TOKEN not present" (error messages about missing token)
# Block: echo $CLOUDFLARE_API_TOKEN, echo "token=$TOKEN", printf "%s" "$TOKEN"
LEAK1="$(grep -nE '^\s*echo\s+.*\$CLOUDFLARE' "$CF_SCRIPT" 2>/dev/null | grep -v 'not present\|missing\|STOP\|>&2' || true)"
LEAK2="$(grep -nE '^\s*echo\s+.*\$\{CLOUDFLARE' "$CF_SCRIPT" 2>/dev/null || true)"
LEAK3="$(grep -nE '^\s*printf?\s+.*\$.*TOKEN' "$CF_SCRIPT" 2>/dev/null || true)"
LEAK4="$(grep -nE '^\s*print\s+.*\$.*TOKEN' "$CF_SCRIPT" 2>/dev/null || true)"
if [ -n "$LEAK1$LEAK2$LEAK3$LEAK4" ]; then
  echo "FAIL: potential token leak patterns in cloudflare-status:"
  echo "$LEAK1$LEAK2$LEAK3$LEAK4"
  exit 1
fi

echo "PASS: D14 cloudflare drift gate"
