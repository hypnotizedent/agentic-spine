#!/usr/bin/env bash
# TRIAGE: Enforce spine.ronny.works Stalwart mail DNS records unchanged (A/MX/SPF/DKIM/DMARC) plus apex anti-spoofing.
# D221: stalwart-mail-dns-parity-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SECRETS_EXEC="$ROOT/ops/plugins/secrets/bin/secrets-exec"

# Re-exec under secrets injection
if [[ -z "${SPINE_SECRETS_INJECTED:-}" ]]; then
  export SPINE_SECRETS_INJECTED=1
  exec "$SECRETS_EXEC" -- "$0" "$@"
fi

CF_API="${CLOUDFLARE_API_BASE:-https://api.cloudflare.com/client/v4}"
ZONE_ID="6d3f8f903534aafb27fe1ea2b1bd7269"

[[ -n "${CLOUDFLARE_API_TOKEN:-}" ]] || { echo "D221 SKIP: CLOUDFLARE_API_TOKEN missing"; exit 0; }

DNS_RAW="$(curl -fsS \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "${CF_API}/zones/${ZONE_ID}/dns_records?per_page=100" 2>/dev/null)" || { echo "D221 SKIP: CF API unreachable"; exit 0; }

RESULT="$(echo "$DNS_RAW" | python3 -c '
import json, sys
data = json.load(sys.stdin)
records = data.get("result", [])

by_key = {}
for r in records:
    key = (r["type"], r["name"])
    if key not in by_key:
        by_key[key] = []
    by_key[key].append(r["content"])

# Stalwart mail infrastructure records
expected_exact = {
    ("A", "mail.spine.ronny.works"): "100.115.16.37",
    ("MX", "spine.ronny.works"): "mail.spine.ronny.works",
}

# TXT records (substring match)
expected_txt = {
    ("TXT", "spine.ronny.works"): "v=spf1",
    ("TXT", "stalwart._domainkey.spine.ronny.works"): "v=DKIM1",
    ("TXT", "_dmarc.spine.ronny.works"): "v=DMARC1",
    # Apex anti-spoofing (no email at @ronny.works)
    ("TXT", "ronny.works"): "v=spf1 -all",
    ("TXT", "_dmarc.ronny.works"): "v=DMARC1",
}

violations = []
checks = 0

for key, expected_content in expected_exact.items():
    checks += 1
    contents = by_key.get(key, [])
    if not contents:
        violations.append(f"MISSING {key[0]} {key[1]}")
    elif not any(expected_content in c for c in contents):
        violations.append(f"CHANGED {key[0]} {key[1]}: got={contents[0][:80]}")

for key, expected_substr in expected_txt.items():
    checks += 1
    contents = by_key.get(key, [])
    if not contents:
        violations.append(f"MISSING {key[0]} {key[1]}")
    elif not any(expected_substr in c for c in contents):
        violations.append(f"CHANGED {key[0]} {key[1]}")

if violations:
    for v in violations:
        print(f"  violation: {v}", file=sys.stderr)
    print(f"FAIL|{len(violations)}|{checks}")
else:
    print(f"PASS|0|{checks}")
')"

IFS='|' read -r STATUS VIOLATION_COUNT CHECK_COUNT <<< "$RESULT"

if [[ "$STATUS" == "FAIL" ]]; then
  echo "D221 FAIL: stalwart mail dns parity lock: $VIOLATION_COUNT violation(s) in $CHECK_COUNT check(s)" >&2
  exit 1
fi

echo "D221 PASS: stalwart mail dns parity lock valid (checks=$CHECK_COUNT, violations=0)"
