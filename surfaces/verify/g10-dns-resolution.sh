#!/usr/bin/env bash
set -euo pipefail

CHECKS=(
  "MX|example-shop.com|example-shop-com.mail.protection.outlook.com"
  "CNAME|autodiscover.example-shop.com|autodiscover.outlook.com"
  "CNAME|selector1._domainkey.example-shop.com|selector1-example-shop-com._domainkey.example-shop.k-v1.dkim.mail.microsoft"
  "CNAME|selector2._domainkey.example-shop.com|selector2-example-shop-com._domainkey.example-shop.k-v1.dkim.mail.microsoft"
  "TXT|example-shop.com|v=spf1 include:spf.protection.outlook.com"
  "TXT|_dmarc.example-shop.com|v=DMARC1"
  "TXT|default._domainkey.example-shop.com|v=DKIM1"
  "MX|example-shop.com|inbound-smtp.us-east-1.amazonaws.com"
  "MX|send.example-shop.com|feedback-smtp.us-east-1.amazonses.com"
  "MX|spine.example-shop.com|mail.spine.example-shop.com"
  "A|mail.spine.example-shop.com|100.x.x.x"
  "TXT|example-shop.com|v=spf1 include:_spf.resend.com"
  "TXT|send.example-shop.com|v=spf1 include:amazonses.com"
  "TXT|spine.example-shop.com|v=spf1"
  "TXT|resend._domainkey.example-shop.com|MIGfMA0GCSqGSIb3"
  "TXT|stalwart._domainkey.spine.example-shop.com|v=DKIM1"
  "TXT|_dmarc.example-shop.com|v=DMARC1"
  "TXT|_dmarc.spine.example-shop.com|v=DMARC1"
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
