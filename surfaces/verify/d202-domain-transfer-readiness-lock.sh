#!/usr/bin/env bash
# TRIAGE: Domain transfer readiness: domains marked transfer_ready must have Cloudflare nameservers active in registrar snapshot.
# D202: Domain transfer readiness lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
violations=0

fail_v() {
  echo "  VIOLATION: $*" >&2
  violations=$((violations + 1))
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "D202 FAIL: missing command: $1" >&2; exit 1; }
}

need_cmd yq
need_cmd jq

PORTFOLIO_FILE="$ROOT/ops/bindings/domain.portfolio.registry.yaml"
SNAPSHOT="$ROOT/mailroom/outbox/domains/namecheap-domains-status.json"

# --- Precondition: portfolio must exist ---
if [[ ! -f "$PORTFOLIO_FILE" ]]; then
  echo "D202 FAIL: portfolio registry missing: $PORTFOLIO_FILE" >&2
  exit 1
fi

# --- Precondition: snapshot must exist ---
if [[ ! -f "$SNAPSHOT" ]]; then
  echo "D202 SKIP: registrar snapshot missing (run domains.namecheap.status first): $SNAPSHOT" >&2
  exit 0
fi

checks=0

# --- Check 1: Domains with transfer_ready=false must NOT have Cloudflare NS ---
# (This is informational — the real guard is Check 2)

# --- Check 2: No domain may be marked transfer_ready=true unless current NS are Cloudflare ---
checks=$((checks + 1))
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  domain=$(echo "$line" | cut -d'|' -f1)
  transfer_ready=$(echo "$line" | cut -d'|' -f2)

  [[ -z "$domain" || "$domain" == "null" ]] && continue

  # Only check domains marked transfer_ready: true
  if [[ "$transfer_ready" == "true" ]]; then
    # Verify nameservers in snapshot are Cloudflare
    ns_json=$(jq -r --arg d "$domain" '.domains[] | select(.domain == $d) | .nameservers // []' "$SNAPSHOT" 2>/dev/null)
    if [[ -z "$ns_json" || "$ns_json" == "[]" || "$ns_json" == "null" ]]; then
      fail_v "$domain marked transfer_ready=true but no nameservers in snapshot"
      continue
    fi
    # Check each nameserver contains cloudflare
    non_cf=$(echo "$ns_json" | jq -r '.[] | select(test("cloudflare") | not)' 2>/dev/null)
    if [[ -n "$non_cf" ]]; then
      fail_v "$domain marked transfer_ready=true but has non-Cloudflare nameservers: $non_cf"
    fi
  fi
done < <(yq e '.domains[] | .domain + "|" + (.transfer_ready // "null" | tostring)' "$PORTFOLIO_FILE" 2>/dev/null)

# --- Check 3: Domains with transfer_ready=false must have non-CF NS (consistency) ---
checks=$((checks + 1))
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  domain=$(echo "$line" | cut -d'|' -f1)
  transfer_ready=$(echo "$line" | cut -d'|' -f2)

  [[ -z "$domain" || "$domain" == "null" ]] && continue

  if [[ "$transfer_ready" == "false" ]]; then
    ns_json=$(jq -r --arg d "$domain" '.domains[] | select(.domain == $d) | .nameservers // []' "$SNAPSHOT" 2>/dev/null)
    if [[ -z "$ns_json" || "$ns_json" == "[]" || "$ns_json" == "null" ]]; then
      continue  # No snapshot data, skip
    fi
    # All NS should be non-Cloudflare if transfer_ready=false
    all_cf=$(echo "$ns_json" | jq -r '[.[] | test("cloudflare")] | all' 2>/dev/null)
    if [[ "$all_cf" == "true" ]]; then
      fail_v "$domain marked transfer_ready=false but nameservers are already Cloudflare — update transfer_ready to true"
    fi
  fi
done < <(yq e '.domains[] | .domain + "|" + (.transfer_ready // "null" | tostring)' "$PORTFOLIO_FILE" 2>/dev/null)

# --- Result ---
if [[ $violations -gt 0 ]]; then
  echo "D202 FAIL: domain transfer readiness lock: $violations violation(s) detected (checks=$checks)" >&2
  exit 1
fi

echo "D202 PASS: domain transfer readiness lock valid (checks=$checks, violations=0)"
