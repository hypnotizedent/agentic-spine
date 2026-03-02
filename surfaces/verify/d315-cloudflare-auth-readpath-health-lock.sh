#!/usr/bin/env bash
# TRIAGE: restore Cloudflare read-path auth by validating token/key secrets and rerunning cloudflare.zone.list + cloudflare.tunnel.ingress.status successfully.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SECRETS_EXEC="$ROOT/ops/plugins/secrets/bin/secrets-exec"
ZONE_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-zone-list"
INGRESS_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-tunnel-ingress-status"

fail() {
  echo "D315 FAIL: $*" >&2
  exit 1
}

[[ -x "$SECRETS_EXEC" ]] || fail "missing executable: $SECRETS_EXEC"
[[ -x "$ZONE_SCRIPT" ]] || fail "missing executable: $ZONE_SCRIPT"
[[ -x "$INGRESS_SCRIPT" ]] || fail "missing executable: $INGRESS_SCRIPT"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

ZONE_RAW="$("$SECRETS_EXEC" -- env SPINE_SECRETS_INJECTED=1 "$ZONE_SCRIPT" --json 2>/dev/null)" || fail "cloudflare.zone.list read-path failed"
python3 - <<'PY' "$ZONE_RAW" || fail "zone list JSON parse failed or returned empty set"
import json, re, sys
raw = sys.argv[1]
match = re.search(r"(?m)^\s*\[", raw)
if not match:
    raise SystemExit(1)
start = raw.find("[", match.start())
if start < 0:
    raise SystemExit(1)
decoder = json.JSONDecoder()
rows, _ = decoder.raw_decode(raw[start:])
if not isinstance(rows, list) or len(rows) == 0:
    raise SystemExit(1)
PY

INGRESS_OUT="$("$SECRETS_EXEC" -- env SPINE_SECRETS_INJECTED=1 "$INGRESS_SCRIPT" 2>/dev/null)" || fail "cloudflare.tunnel.ingress.status read-path failed"
echo "$INGRESS_OUT" | grep -q 'cloudflare.tunnel.ingress.status' || fail "unexpected ingress output header"

echo "D315 PASS: Cloudflare read-path auth healthy (zone.list + tunnel.ingress.status)"
