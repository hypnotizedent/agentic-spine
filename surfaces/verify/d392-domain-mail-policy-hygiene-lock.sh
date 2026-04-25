#!/usr/bin/env bash
# TRIAGE: All admitted domains must have anti-spoofing DNS records (SPF + DMARC)
# Gate: D392 domain-mail-policy-hygiene-lock
# Category: process-hygiene
# Ring: standard
# Severity: high
#
# Ensures all domains in the admitted portfolio have SPF and DMARC records configured.
# Prevents email spoofing and domain reputation damage from missing anti-spoofing controls.
#
# This gate parses domains.portfolio.status capability output and fails if any
# domain shows MISSING for SPF or DMARC.

set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Run domains.portfolio.status and capture output
output=$("$ROOT/bin/ops" cap run domains.portfolio.status 2>&1) || {
  echo "D392 FAIL: domains.portfolio.status capability failed" >&2
  exit 1
}

# Parse domains table for MISSING in SPF or DMARC columns
# The output format: DOMAIN ZONE REGISTRAR DNS# EXPIRES SPF DMARC
# SPF is in column $(NF-1), DMARC is in column $NF
# Extract just the domain table lines (those starting with a valid domain name)
domain_lines=$(echo "$output" | grep -E "^[a-z][a-z0-9.-]+\.(com|co|works|clothing|design)" || true)

# Check if any domain has MISSING in either SPF or DMARC column
# Match lines where either second-to-last field is MISSING (SPF) or last field is MISSING (DMARC)
failing_domains=$(echo "$domain_lines" | awk '{spf=$(NF-1); dmarc=$NF; if (spf == "MISSING" || dmarc == "MISSING") print $1}' || true)

# Count failures
failure_count=0
if [[ -n "$failing_domains" ]]; then
  failure_count=$(echo "$failing_domains" | wc -l | tr -d ' ')
fi

if [[ "$failure_count" -gt 0 ]]; then
  echo "D392 FAIL: domain(s) missing anti-spoofing DNS records" >&2
  echo "" >&2
  echo "All admitted domains must have SPF and DMARC records configured." >&2
  echo "Missing records create email spoofing risk and damage sender reputation." >&2
  echo "" >&2
  echo "Failing domains:" >&2
  echo "$failing_domains" | sed 's/^/  - /' >&2
  echo "" >&2
  echo "Fix: Add missing records via:" >&2
  echo "  ./bin/ops cap run cloudflare.dns.record.set -- --zone DOMAIN --type TXT --name DOMAIN --content \"v=spf1 -all\"" >&2
  echo "  ./bin/ops cap run cloudflare.dns.record.set -- --zone DOMAIN --type TXT --name _dmarc.DOMAIN --content \"v=DMARC1; p=reject;\"" >&2
  echo "" >&2
  echo "For domains that send mail, consult canonical mail policy before setting SPF." >&2
  exit 1
fi

echo "D392 PASS: all admitted domains have anti-spoofing DNS records"
exit 0
