#!/usr/bin/env bash
set -euo pipefail

CHECKS=(
  "MX|mintprints.com|mintprints-com.mail.protection.outlook.com"
  "CNAME|autodiscover.mintprints.com|autodiscover.outlook.com"
  "CNAME|selector1._domainkey.mintprints.com|selector1-mintprints-com._domainkey.mintprints.k-v1.dkim.mail.microsoft"
  "CNAME|selector2._domainkey.mintprints.com|selector2-mintprints-com._domainkey.mintprints.k-v1.dkim.mail.microsoft"
  "TXT|mintprints.com|v=spf1 include:spf.protection.outlook.com"
  "TXT|_dmarc.mintprints.com|v=DMARC1"
  "TXT|default._domainkey.mintprints.com|v=DKIM1"
  "MX|mintprints.co|inbound-smtp.us-east-1.amazonaws.com"
  "MX|send.mintprints.co|feedback-smtp.us-east-1.amazonses.com"
  "MX|spine.mintprints.co|mail.spine.mintprints.co"
  "A|mail.spine.mintprints.co|100.115.16.37"
  "TXT|mintprints.co|v=spf1 include:_spf.resend.com"
  "TXT|send.mintprints.co|v=spf1 include:amazonses.com"
  "TXT|spine.mintprints.co|v=spf1"
  "TXT|resend._domainkey.mintprints.co|MIGfMA0GCSqGSIb3"
  "TXT|stalwart._domainkey.spine.mintprints.co|v=DKIM1"
  "TXT|_dmarc.mintprints.co|v=DMARC1"
  "TXT|_dmarc.spine.mintprints.co|v=DMARC1"
  "MX|hantash.com|mx01.mail.icloud.com"
  "MX|hantash.com|mx02.mail.icloud.com"
  "CNAME|sig1._domainkey.hantash.com|sig1.dkim.hantash.com.at.icloudmailadmin.com"
  "TXT|hantash.com|v=spf1 include:icloud.com"
  "TXT|hantash.com|apple-domain="
)

command -v dig >/dev/null 2>&1 || {
  echo "G10 FAIL: missing dependency: dig" >&2
  exit 2
}

failures=0
passes=0

printf "%-8s %-40s %-8s %s\n" "type" "name" "status" "detail"

for check in "${CHECKS[@]}"; do
  IFS='|' read -r record_type record_name expected <<< "$check"
  answer="$(dig +time=3 +tries=1 +short "$record_type" "$record_name" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]\+$//')"
  if [[ -z "$answer" ]]; then
    printf "%-8s %-40s %-8s %s\n" "$record_type" "$record_name" "FAIL" "no public answer"
    failures=$((failures + 1))
    continue
  fi

  if [[ "$answer" == *"$expected"* ]]; then
    printf "%-8s %-40s %-8s %s\n" "$record_type" "$record_name" "PASS" "$expected"
    passes=$((passes + 1))
  else
    printf "%-8s %-40s %-8s %s\n" "$record_type" "$record_name" "FAIL" "expected '$expected' got '$answer'"
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -gt 0 ]]; then
  echo "G10 FAIL: DNS resolution checks failed=${failures}/$((passes + failures))" >&2
  exit 1
fi

echo "G10 PASS: DNS resolution checks passed (${passes})"
