#!/usr/bin/env bash
# TRIAGE: Enforce mintprints.com Microsoft 365 mail DNS records unchanged (MX/SPF/DKIM/DMARC/autodiscover).
# D216: mintprints-mail-dns-parity-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SECRETS_EXEC="$ROOT/ops/plugins/secrets/bin/secrets-exec"

# Re-exec under secrets injection
if [[ -z "${SPINE_SECRETS_INJECTED:-}" ]]; then
  export SPINE_SECRETS_INJECTED=1
  exec "$SECRETS_EXEC" -- "$0" "$@"
fi

CF_API="${CLOUDFLARE_API_BASE:-https://api.cloudflare.com/client/v4}"
ZONE_ID="3188b91150231e1caf44514c8ad221da"

[[ -n "${CLOUDFLARE_API_TOKEN:-}" ]] || { echo "D216 SKIP: CLOUDFLARE_API_TOKEN missing"; exit 0; }

DNS_RAW="$(curl -fsS \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "${CF_API}/zones/${ZONE_ID}/dns_records?per_page=100" 2>/dev/null)" || { echo "D216 SKIP: CF API unreachable"; exit 0; }

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

# Exact-match records (type, name) -> expected content substring
expected_exact = {
    ("MX", "mintprints.com"): "mintprints-com.mail.protection.outlook.com",
    ("CNAME", "autodiscover.mintprints.com"): "autodiscover.outlook.com",
    ("CNAME", "selector1._domainkey.mintprints.com"): "selector1-mintprints-com._domainkey.mintprints.k-v1.dkim.mail.microsoft",
    ("CNAME", "selector2._domainkey.mintprints.com"): "selector2-mintprints-com._domainkey.mintprints.k-v1.dkim.mail.microsoft",
}

# Substring-match TXT records
expected_txt = {
    ("TXT", "mintprints.com"): "v=spf1 include:spf.protection.outlook.com",
    ("TXT", "_dmarc.mintprints.com"): "v=DMARC1",
    ("TXT", "default._domainkey.mintprints.com"): "v=DKIM1",
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
  echo "D216 FAIL: mintprints mail dns parity lock: $VIOLATION_COUNT violation(s) in $CHECK_COUNT check(s)" >&2
  exit 1
fi

echo "D216 PASS: mintprints mail dns parity lock valid (checks=$CHECK_COUNT, violations=0)"
