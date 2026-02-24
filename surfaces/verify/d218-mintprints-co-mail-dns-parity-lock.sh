#!/usr/bin/env bash
# TRIAGE: Enforce mintprints.co Resend + Stalwart mail DNS records unchanged (MX/SPF/DKIM/DMARC).
# D218: mintprints-co-mail-dns-parity-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SECRETS_EXEC="$ROOT/ops/plugins/secrets/bin/secrets-exec"

# Re-exec under secrets injection
if [[ -z "${SPINE_SECRETS_INJECTED:-}" ]]; then
  export SPINE_SECRETS_INJECTED=1
  exec "$SECRETS_EXEC" -- "$0" "$@"
fi

CF_API="${CLOUDFLARE_API_BASE:-https://api.cloudflare.com/client/v4}"
ZONE_ID="8455a1754ffe2f296d74e985a89069f3"

[[ -n "${CLOUDFLARE_API_TOKEN:-}" ]] || { echo "D218 SKIP: CLOUDFLARE_API_TOKEN missing"; exit 0; }

DNS_RAW="$(curl -fsS \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "${CF_API}/zones/${ZONE_ID}/dns_records?per_page=100" 2>/dev/null)" || { echo "D218 SKIP: CF API unreachable"; exit 0; }

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
    ("MX", "mintprints.co"): "inbound-smtp.us-east-1.amazonaws.com",
    ("MX", "send.mintprints.co"): "feedback-smtp.us-east-1.amazonses.com",
    ("MX", "spine.mintprints.co"): "mail.spine.mintprints.co",
    ("A", "mail.spine.mintprints.co"): "100.115.16.37",
}

# Substring-match TXT records
expected_txt = {
    ("TXT", "mintprints.co"): "v=spf1 include:_spf.resend.com",
    ("TXT", "send.mintprints.co"): "v=spf1 include:amazonses.com",
    ("TXT", "spine.mintprints.co"): "v=spf1",
    ("TXT", "resend._domainkey.mintprints.co"): "MIGfMA0GCSqGSIb3",
    ("TXT", "stalwart._domainkey.spine.mintprints.co"): "v=DKIM1",
    ("TXT", "_dmarc.mintprints.co"): "v=DMARC1",
    ("TXT", "_dmarc.spine.mintprints.co"): "v=DMARC1",
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
  echo "D218 FAIL: mintprints.co mail dns parity lock: $VIOLATION_COUNT violation(s) in $CHECK_COUNT check(s)" >&2
  exit 1
fi

echo "D218 PASS: mintprints.co mail dns parity lock valid (checks=$CHECK_COUNT, violations=0)"
