#!/usr/bin/env bash
# TRIAGE: restore Cloudflare read-path auth by validating token/key secrets and rerunning Cloudflare read/smoke capabilities successfully.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SECRETS_EXEC="$ROOT/ops/plugins/secrets/bin/secrets-exec"
CF_LIB="$ROOT/ops/plugins/cloudflare/lib/cloudflare-api.sh"
ZONE_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-zone-list"
INGRESS_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-tunnel-ingress-status"
INVENTORY_SYNC_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-inventory-sync"
PORTFOLIO_STATUS_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-domains-portfolio-status"
SERVICE_PUBLISH_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-service-publish"
REGISTRAR_STATUS_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-registrar-status"
TOKEN_HEALTH_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-token-health"

fail() {
  echo "D315 FAIL: $*" >&2
  exit 1
}

# Classify failure from script stderr/output for forensic triage.
# Emits: token_invalid, rate_limited, api_error, network_error, parse_error, or unknown.
classify_script_failure() {
  local output="${1:-}"
  local stderr_capture="${2:-}"
  local combined="${output} ${stderr_capture}"
  if echo "$combined" | grep -qiE 'status=(401|403)|token_invalid|class=token_invalid'; then
    echo "token_invalid"
  elif echo "$combined" | grep -qiE 'status=429|rate_limited|class=rate_limited'; then
    echo "rate_limited"
  elif echo "$combined" | grep -qiE 'status=000|network_error|class=network_error'; then
    echo "network_error"
  elif echo "$combined" | grep -qiE 'status=5[0-9][0-9]|api_error|class=api_error'; then
    echo "api_error"
  elif echo "$combined" | grep -qiE 'JSONDecodeError|parse|json'; then
    echo "parse_error"
  else
    echo "unknown"
  fi
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

# Check 0: Token health (non-blocking diagnostic — surfaces degraded token posture)
if [[ -x "$TOKEN_HEALTH_SCRIPT" ]]; then
  _th_stderr="$(mktemp)"
  trap 'rm -f "$_th_stderr" 2>/dev/null || true' EXIT
  _th_out="$(run_with_secrets "$TOKEN_HEALTH_SCRIPT" 2>"$_th_stderr")" || true
  _th_status="$(echo "$_th_out" | grep '^status:' | head -1 | sed 's/^status: *//')"
  if [[ "$_th_status" != "valid" ]]; then
    echo "D315 WARN: token health degraded (status=${_th_status:-unknown})" >&2
  fi
fi

# Check 1: Zone list
_zl_stderr="$(mktemp)"
trap 'rm -f "$_zl_stderr" "$_th_stderr" 2>/dev/null || true' EXIT
ZONE_RAW="$(run_with_secrets "$ZONE_SCRIPT" --json 2>"$_zl_stderr")" || {
  _class="$(classify_script_failure "$ZONE_RAW" "$(cat "$_zl_stderr" 2>/dev/null)")"
  fail "cloudflare.zone.list read-path failed (class=${_class})"
}
python3 - <<'PY' "$ZONE_RAW" || fail "zone list JSON parse failed or returned empty set (class=parse_error)"
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

# Check 2: Tunnel ingress status
_ti_stderr="$(mktemp)"
trap 'rm -f "$_ti_stderr" "$_zl_stderr" "$_th_stderr" 2>/dev/null || true' EXIT
INGRESS_OUT="$(run_with_secrets "$INGRESS_SCRIPT" 2>"$_ti_stderr")" || {
  _class="$(classify_script_failure "$INGRESS_OUT" "$(cat "$_ti_stderr" 2>/dev/null)")"
  fail "cloudflare.tunnel.ingress.status read-path failed (class=${_class})"
}
echo "$INGRESS_OUT" | grep -q 'cloudflare.tunnel.ingress.status' || fail "unexpected ingress output header (class=parse_error)"

# Check 3: Inventory sync
_is_stderr="$(mktemp)"
trap 'rm -f "$_is_stderr" "$_ti_stderr" "$_zl_stderr" "$_th_stderr" 2>/dev/null || true' EXIT
INVENTORY_OUT="$(run_with_secrets "$INVENTORY_SYNC_SCRIPT" 2>"$_is_stderr")" || {
  _class="$(classify_script_failure "$INVENTORY_OUT" "$(cat "$_is_stderr" 2>/dev/null)")"
  fail "cloudflare.inventory.sync failed (class=${_class})"
}
echo "$INVENTORY_OUT" | grep -q 'cloudflare.inventory.sync' || fail "unexpected inventory sync output header (class=parse_error)"

# Check 4: Domains portfolio status
_dp_stderr="$(mktemp)"
trap 'rm -f "$_dp_stderr" "$_is_stderr" "$_ti_stderr" "$_zl_stderr" "$_th_stderr" 2>/dev/null || true' EXIT
PORTFOLIO_RAW="$(run_with_secrets "$PORTFOLIO_STATUS_SCRIPT" --json 2>"$_dp_stderr")" || {
  _class="$(classify_script_failure "$PORTFOLIO_RAW" "$(cat "$_dp_stderr" 2>/dev/null)")"
  fail "domains.portfolio.status failed (class=${_class})"
}
python3 - <<'PY' "$PORTFOLIO_RAW" || fail "domains.portfolio.status JSON parse failed or returned empty set (class=parse_error)"
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

# Check 5: Service publish dry-run
set +e
_sp_stderr="$(mktemp)"
SERVICE_PUBLISH_OUT="$(run_with_secrets "$SERVICE_PUBLISH_SCRIPT" --hostname test.mintprints.com --service http://127.0.0.1:9999 --dry-run --allow-unregistered 2>"$_sp_stderr")"
service_publish_rc=$?
set -e
if [[ "$service_publish_rc" -ne 0 ]]; then
  if [[ "$service_publish_rc" -eq 5 ]] && echo "$SERVICE_PUBLISH_OUT" | grep -q 'status: WARN (routing diff detected)'; then
    :
  else
    _class="$(classify_script_failure "$SERVICE_PUBLISH_OUT" "$(cat "$_sp_stderr" 2>/dev/null)")"
    fail "cloudflare.service.publish --dry-run failed (rc=$service_publish_rc, class=${_class})"
  fi
fi
echo "$SERVICE_PUBLISH_OUT" | grep -q 'cloudflare.service.publish' || fail "unexpected service publish output header (class=parse_error)"
echo "$SERVICE_PUBLISH_OUT" | grep -q 'JSONDecodeError' && fail "service publish emitted JSONDecodeError (class=parse_error)"

# Check 6: Registrar status
_rs_stderr="$(mktemp)"
REGISTRAR_RAW="$(run_with_secrets "$REGISTRAR_STATUS_SCRIPT" --json 2>"$_rs_stderr")" || {
  _class="$(classify_script_failure "$REGISTRAR_RAW" "$(cat "$_rs_stderr" 2>/dev/null)")"
  fail "cloudflare.registrar.status failed (class=${_class})"
}
python3 - <<'PY' "$REGISTRAR_RAW" || fail "cloudflare.registrar.status JSON parse failed or contains degraded row statuses (class=parse_error)"
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

echo "D315 PASS: Cloudflare read/smoke path healthy (token.health + zone.list + tunnel.ingress.status + inventory.sync + domains.portfolio.status + service.publish dry-run + registrar.status)"
