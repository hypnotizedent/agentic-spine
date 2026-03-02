#!/usr/bin/env bash
# TRIAGE: restore Cloudflare read-path auth by validating token/key secrets and rerunning Cloudflare read/smoke capabilities successfully.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SECRETS_EXEC="$ROOT/ops/plugins/secrets/bin/secrets-exec"
ZONE_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-zone-list"
INGRESS_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-tunnel-ingress-status"
INVENTORY_SYNC_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-inventory-sync"
PORTFOLIO_STATUS_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-domains-portfolio-status"
SERVICE_PUBLISH_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-service-publish"
REGISTRAR_STATUS_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-registrar-status"

fail() {
  echo "D315 FAIL: $*" >&2
  exit 1
}

run_with_secrets() {
  "$SECRETS_EXEC" -- env SPINE_SECRETS_INJECTED=1 "$@"
}

[[ -x "$SECRETS_EXEC" ]] || fail "missing executable: $SECRETS_EXEC"
[[ -x "$ZONE_SCRIPT" ]] || fail "missing executable: $ZONE_SCRIPT"
[[ -x "$INGRESS_SCRIPT" ]] || fail "missing executable: $INGRESS_SCRIPT"
[[ -x "$INVENTORY_SYNC_SCRIPT" ]] || fail "missing executable: $INVENTORY_SYNC_SCRIPT"
[[ -x "$PORTFOLIO_STATUS_SCRIPT" ]] || fail "missing executable: $PORTFOLIO_STATUS_SCRIPT"
[[ -x "$SERVICE_PUBLISH_SCRIPT" ]] || fail "missing executable: $SERVICE_PUBLISH_SCRIPT"
[[ -x "$REGISTRAR_STATUS_SCRIPT" ]] || fail "missing executable: $REGISTRAR_STATUS_SCRIPT"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

ZONE_RAW="$(run_with_secrets "$ZONE_SCRIPT" --json 2>/dev/null)" || fail "cloudflare.zone.list read-path failed"
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

INGRESS_OUT="$(run_with_secrets "$INGRESS_SCRIPT" 2>/dev/null)" || fail "cloudflare.tunnel.ingress.status read-path failed"
echo "$INGRESS_OUT" | grep -q 'cloudflare.tunnel.ingress.status' || fail "unexpected ingress output header"

INVENTORY_OUT="$(run_with_secrets "$INVENTORY_SYNC_SCRIPT" 2>/dev/null)" || fail "cloudflare.inventory.sync failed"
echo "$INVENTORY_OUT" | grep -q 'cloudflare.inventory.sync' || fail "unexpected inventory sync output header"

PORTFOLIO_RAW="$(run_with_secrets "$PORTFOLIO_STATUS_SCRIPT" --json 2>/dev/null)" || fail "domains.portfolio.status failed"
python3 - <<'PY' "$PORTFOLIO_RAW" || fail "domains.portfolio.status JSON parse failed or returned empty set"
import json, re, sys
raw = sys.argv[1]
# Support both object-wrapped {"status":..,"domains":[...]} and flat array [...] formats
match = re.search(r"(?m)^\s*[\[{]", raw)
if not match:
    raise SystemExit(1)
# Find the actual [ or { character position (raw_decode doesn't skip whitespace)
bracket_pos = match.end() - 1
decoder = json.JSONDecoder()
doc, _ = decoder.raw_decode(raw[bracket_pos:])
if isinstance(doc, dict):
    rows = doc.get("domains", [])
    if doc.get("status") == "rate_limited":
        print("D315: portfolio status reports rate_limited", file=sys.stderr)
        raise SystemExit(1)
elif isinstance(doc, list):
    rows = doc
else:
    raise SystemExit(1)
if not isinstance(rows, list) or len(rows) == 0:
    raise SystemExit(1)
PY

set +e
SERVICE_PUBLISH_OUT="$(run_with_secrets "$SERVICE_PUBLISH_SCRIPT" --hostname test.mintprints.com --service http://127.0.0.1:9999 --dry-run --allow-unregistered 2>/dev/null)"
service_publish_rc=$?
set -e
if [[ "$service_publish_rc" -ne 0 ]]; then
  if [[ "$service_publish_rc" -eq 5 ]] && echo "$SERVICE_PUBLISH_OUT" | grep -q 'status: WARN (routing diff detected)'; then
    :
  else
    fail "cloudflare.service.publish --dry-run failed (rc=$service_publish_rc)"
  fi
fi
echo "$SERVICE_PUBLISH_OUT" | grep -q 'cloudflare.service.publish' || fail "unexpected service publish output header"
echo "$SERVICE_PUBLISH_OUT" | grep -q 'JSONDecodeError' && fail "service publish emitted JSONDecodeError"

REGISTRAR_RAW="$(run_with_secrets "$REGISTRAR_STATUS_SCRIPT" --json 2>/dev/null)" || fail "cloudflare.registrar.status failed"
python3 - <<'PY' "$REGISTRAR_RAW" || fail "cloudflare.registrar.status JSON parse failed or contains degraded row statuses"
import json, re, sys
raw = sys.argv[1]
match = re.search(r"(?m)^\s*\{", raw)
if not match:
    raise SystemExit(1)
start = raw.find("{", match.start())
if start < 0:
    raise SystemExit(1)
decoder = json.JSONDecoder()
doc, _ = decoder.raw_decode(raw[start:])
if not isinstance(doc, dict):
    raise SystemExit(1)
rows = doc.get("domains")
if not isinstance(rows, list) or len(rows) == 0:
    raise SystemExit(1)
# Reject degraded row statuses; allow not_at_cf_registrar as expected non-owner state
degraded = {"api_non_json", "api_error", "parse_error"}
for row in rows:
    if not isinstance(row, dict):
        continue
    status = str(row.get("status", ""))
    if status in degraded or status.startswith("http_"):
        domain = row.get("domain", "unknown")
        print(f"D315 degraded registrar row: domain={domain} status={status}", file=sys.stderr)
        raise SystemExit(1)
PY

echo "D315 PASS: Cloudflare read/smoke path healthy (zone.list + tunnel.ingress.status + inventory.sync + domains.portfolio.status + service.publish dry-run + registrar.status)"
