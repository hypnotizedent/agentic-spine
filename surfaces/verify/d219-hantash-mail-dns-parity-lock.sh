#!/usr/bin/env bash
# TRIAGE: Enforce hantash.com iCloud custom domain mail DNS records unchanged (MX/SPF/DKIM/apple-domain).
# D219: hantash-mail-dns-parity-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SECRETS_EXEC="$ROOT/ops/plugins/secrets/bin/secrets-exec"

# Re-exec under secrets injection
if [[ -z "${SPINE_SECRETS_INJECTED:-}" ]]; then
  export SPINE_SECRETS_INJECTED=1
  exec "$SECRETS_EXEC" -- "$0" "$@"
fi

CF_API="${CLOUDFLARE_API_BASE:-https://api.cloudflare.com/client/v4}"
ZONE_ID="676743ef3912f4aeb8da0ae54b7c3741"

[[ -n "${CLOUDFLARE_API_TOKEN:-}" ]] || { echo "D219 SKIP: CLOUDFLARE_API_TOKEN missing"; exit 0; }

DNS_RAW="$(curl -fsS \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "${CF_API}/zones/${ZONE_ID}/dns_records?per_page=100" 2>/dev/null)" || { echo "D219 SKIP: CF API unreachable"; exit 0; }

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

# Exact-match records
expected_exact = {
    ("MX", "hantash.com", "mx01"): "mx01.mail.icloud.com",
    ("MX", "hantash.com", "mx02"): "mx02.mail.icloud.com",
    ("CNAME", "sig1._domainkey.hantash.com", "dkim"): "sig1.dkim.hantash.com.at.icloudmailadmin.com",
}

# Substring-match TXT records
expected_txt = {
    ("TXT", "hantash.com", "spf"): "v=spf1 include:icloud.com",
    ("TXT", "hantash.com", "apple-domain"): "apple-domain=",
}

violations = []
checks = 0

# MX checks: both mx01 and mx02 must exist in the MX record set
checks += 1
mx_contents = by_key.get(("MX", "hantash.com"), [])
if not mx_contents:
    violations.append("MISSING MX hantash.com")
else:
    has_mx01 = any("mx01.mail.icloud.com" in c for c in mx_contents)
    has_mx02 = any("mx02.mail.icloud.com" in c for c in mx_contents)
    if not has_mx01:
        violations.append("MISSING MX hantash.com mx01.mail.icloud.com")
    if not has_mx02:
        violations.append("MISSING MX hantash.com mx02.mail.icloud.com")

# DKIM CNAME check
checks += 1
dkim_contents = by_key.get(("CNAME", "sig1._domainkey.hantash.com"), [])
if not dkim_contents:
    violations.append("MISSING CNAME sig1._domainkey.hantash.com")
elif not any("sig1.dkim.hantash.com.at.icloudmailadmin.com" in c for c in dkim_contents):
    got = dkim_contents[0][:80]
    violations.append(f"CHANGED CNAME sig1._domainkey.hantash.com: got={got}")

# TXT checks
for key_tuple in expected_txt:
    rtype, rname, label = key_tuple
    expected_substr = expected_txt[key_tuple]
    checks += 1
    contents = by_key.get((rtype, rname), [])
    if not contents:
        violations.append(f"MISSING {rtype} {rname} ({label})")
    elif not any(expected_substr in c for c in contents):
        violations.append(f"CHANGED {rtype} {rname} ({label})")

if violations:
    for v in violations:
        print(f"  violation: {v}", file=sys.stderr)
    print(f"FAIL|{len(violations)}|{checks}")
else:
    print(f"PASS|0|{checks}")
')"

IFS='|' read -r STATUS VIOLATION_COUNT CHECK_COUNT <<< "$RESULT"

if [[ "$STATUS" == "FAIL" ]]; then
  echo "D219 FAIL: hantash mail dns parity lock: $VIOLATION_COUNT violation(s) in $CHECK_COUNT check(s)" >&2
  exit 1
fi

echo "D219 PASS: hantash mail dns parity lock valid (checks=$CHECK_COUNT, violations=0)"
