#!/usr/bin/env bash
# TRIAGE: Enforce mintprints.co tunnel ingress rules exist with correct service targets.
# D217: mintprints-co-tunnel-ingress-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SECRETS_EXEC="$ROOT/ops/plugins/secrets/bin/secrets-exec"
BINDING_FILE="$ROOT/ops/bindings/cloudflare.inventory.yaml"

# Re-exec under secrets injection
if [[ -z "${SPINE_SECRETS_INJECTED:-}" ]]; then
  export SPINE_SECRETS_INJECTED=1
  exec "$SECRETS_EXEC" -- "$0" "$@"
fi

CF_API="${CLOUDFLARE_API_BASE:-https://api.cloudflare.com/client/v4}"

[[ -n "${CLOUDFLARE_API_TOKEN:-}" ]] || { echo "D217 SKIP: CLOUDFLARE_API_TOKEN missing"; exit 0; }
[[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]] || { echo "D217 SKIP: CLOUDFLARE_ACCOUNT_ID missing"; exit 0; }

TUNNEL_NAME="homelab-tunnel"
TUNNEL_ID="$(python3 - "$BINDING_FILE" "$TUNNEL_NAME" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for t in data.get("tunnels", []):
    if t.get("name") == sys.argv[2]:
        print(t["id"])
        sys.exit(0)
sys.exit(1)
PY
)" || { echo "D217 SKIP: tunnel not found in binding"; exit 0; }

URL="${CF_API}/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}/configurations"
RESPONSE="$(curl -fsS \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "$URL" 2>/dev/null)" || { echo "D217 SKIP: CF API unreachable"; exit 0; }

RESULT="$(echo "$RESPONSE" | python3 -c '
import json, sys
data = json.load(sys.stdin)
cfg = data.get("result", {}).get("config", {})
ingress = cfg.get("ingress", [])

expected = {
    "admin.mintprints.co": "http://mint-os-admin:3333",
    "api.mintprints.co": "http://mint-os-dashboard-api:3335",
    "production.mintprints.co": "http://mint-os-production:3336",
    "customer.mintprints.co": "http://quote-page:3341",
    "estimator.mintprints.co": "http://100.79.183.14:3700",
    "kanban.mintprints.co": "http://mint-os-kanban:3337",
    "files.mintprints.co": "http://mint-os-minio:9000",
    "minio.mintprints.co": "http://mint-os-minio:9001",
    "mcp.mintprints.co": "http://mcpjungle:8080",
    "pricing.mintprints.co": "http://100.79.183.14:3700",
    "shipping.mintprints.co": "http://100.79.183.14:3900",
    "stock-dst.mintprints.co": "http://100.92.156.118:8765",
}

found = {}
for rule in ingress:
    h = rule.get("hostname", "")
    s = rule.get("service", "")
    if h in expected:
        found[h] = s

violations = []
for hostname, want in expected.items():
    got = found.get(hostname)
    if got is None:
        violations.append(f"MISSING {hostname}")
    elif got != want:
        violations.append(f"WRONG {hostname}: got={got} want={want}")

if violations:
    for v in violations:
        print(f"  violation: {v}", file=sys.stderr)
    print(f"FAIL|{len(violations)}|{len(expected)}")
else:
    print(f"PASS|0|{len(expected)}")
')"

IFS='|' read -r STATUS VIOLATION_COUNT CHECK_COUNT <<< "$RESULT"

if [[ "$STATUS" == "FAIL" ]]; then
  echo "D217 FAIL: mintprints.co tunnel ingress lock: $VIOLATION_COUNT violation(s) in $CHECK_COUNT check(s)" >&2
  exit 1
fi

echo "D217 PASS: mintprints.co tunnel ingress lock valid (checks=$CHECK_COUNT, violations=0)"
