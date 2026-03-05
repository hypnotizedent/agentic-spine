#!/usr/bin/env bash
# TRIAGE: Enforce mintprints.com tunnel ingress rules exist with correct service targets.
# D215: mintprints-tunnel-ingress-lock
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

[[ -n "${CLOUDFLARE_API_TOKEN:-}" ]] || { echo "D215 SKIP: CLOUDFLARE_API_TOKEN missing"; exit 0; }
[[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]] || { echo "D215 SKIP: CLOUDFLARE_ACCOUNT_ID missing"; exit 0; }

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
)" || { echo "D215 SKIP: tunnel not found in binding"; exit 0; }

URL="${CF_API}/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}/configurations"
RESPONSE="$(curl -fsS \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "$URL" 2>/dev/null)" || { echo "D215 SKIP: CF API unreachable"; exit 0; }

RESULT="$(echo "$RESPONSE" | python3 -c '
import json, sys
data = json.load(sys.stdin)
cfg = data.get("result", {}).get("config", {})
ingress = cfg.get("ingress", [])

expected = {
    "mintprints.com": "http://quote-page:3341",
    "www.mintprints.com": "http://quote-page:3341",
    "customer.mintprints.com": "http://quote-page:3341",
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
  echo "D215 FAIL: mintprints tunnel ingress lock: $VIOLATION_COUNT violation(s) in $CHECK_COUNT check(s)" >&2
  exit 1
fi

echo "D215 PASS: mintprints tunnel ingress lock valid (checks=$CHECK_COUNT, violations=0)"
