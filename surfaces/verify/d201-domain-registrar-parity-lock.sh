#!/usr/bin/env bash
# TRIAGE: Domain registrar parity: namecheap-registered canonical domains must have registrar snapshot with lock, nameservers, and expiry fields.
# D201: Domain registrar parity lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
violations=0

fail_v() {
  echo "  VIOLATION: $*" >&2
  violations=$((violations + 1))
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "D201 FAIL: missing command: $1" >&2; exit 1; }
}

need_cmd yq
need_cmd jq

ROOTS_FILE="$ROOT/ops/bindings/domain.canonical.roots.yaml"
SNAPSHOT="$ROOT/mailroom/outbox/domains/namecheap-domains-status.json"
PORTFOLIO_FILE="$ROOT/ops/bindings/domain.portfolio.registry.yaml"

# --- Precondition: canonical roots binding must exist ---
if [[ ! -f "$ROOTS_FILE" ]]; then
  echo "D201 FAIL: canonical roots binding missing: $ROOTS_FILE" >&2
  exit 1
fi

# --- Precondition: snapshot must exist ---
if [[ ! -f "$SNAPSHOT" ]]; then
  echo "D201 SKIP: registrar snapshot missing (run domains.namecheap.status first): $SNAPSHOT" >&2
  exit 0
fi

# --- Precondition: portfolio must exist (for registrar scoping) ---
if [[ ! -f "$PORTFOLIO_FILE" ]]; then
  echo "D201 FAIL: portfolio registry missing: $PORTFOLIO_FILE" >&2
  exit 1
fi

# --- Load canonical roots ---
canonical_roots=""
while IFS= read -r root; do
  [[ -z "$root" || "$root" == "null" ]] && continue
  canonical_roots="${canonical_roots}${root}"$'\n'
done < <(yq e '.roots[].domain' "$ROOTS_FILE" 2>/dev/null)

if [[ -z "$canonical_roots" ]]; then
  echo "D201 FAIL: no canonical roots found in $ROOTS_FILE" >&2
  exit 1
fi

checks=0

# --- Check 1: Each namecheap-registered canonical root exists in snapshot ---
checks=$((checks + 1))
while IFS= read -r root; do
  [[ -z "$root" ]] && continue
  registrar=$(yq e ".domains[] | select(.domain == \"$root\") | .registrar" "$PORTFOLIO_FILE" 2>/dev/null)
  [[ "$registrar" != "namecheap" ]] && continue
  exists=$(jq -r --arg d "$root" '.domains[] | select(.domain == $d) | .domain' "$SNAPSHOT" 2>/dev/null)
  if [[ -z "$exists" ]]; then
    fail_v "canonical domain missing from snapshot: $root"
  fi
done <<< "$canonical_roots"

# --- Check 2: Each namecheap-registered canonical root has registrar_lock ---
checks=$((checks + 1))
while IFS= read -r root; do
  [[ -z "$root" ]] && continue
  registrar=$(yq e ".domains[] | select(.domain == \"$root\") | .registrar" "$PORTFOLIO_FILE" 2>/dev/null)
  [[ "$registrar" != "namecheap" ]] && continue
  lock=$(jq -r --arg d "$root" '.domains[] | select(.domain == $d) | .registrar_lock // ""' "$SNAPSHOT" 2>/dev/null)
  if [[ -z "$lock" || "$lock" == "null" ]]; then
    fail_v "missing registrar_lock for: $root"
  fi
done <<< "$canonical_roots"

# --- Check 3: Each namecheap-registered canonical root has nameservers ---
checks=$((checks + 1))
while IFS= read -r root; do
  [[ -z "$root" ]] && continue
  registrar=$(yq e ".domains[] | select(.domain == \"$root\") | .registrar" "$PORTFOLIO_FILE" 2>/dev/null)
  [[ "$registrar" != "namecheap" ]] && continue
  ns_count=$(jq -r --arg d "$root" '.domains[] | select(.domain == $d) | .nameservers | length' "$SNAPSHOT" 2>/dev/null)
  if [[ -z "$ns_count" || "$ns_count" == "0" ]]; then
    fail_v "missing nameservers for: $root"
  fi
done <<< "$canonical_roots"

# --- Check 4: Each namecheap-registered canonical root has expiry_date ---
checks=$((checks + 1))
while IFS= read -r root; do
  [[ -z "$root" ]] && continue
  registrar=$(yq e ".domains[] | select(.domain == \"$root\") | .registrar" "$PORTFOLIO_FILE" 2>/dev/null)
  [[ "$registrar" != "namecheap" ]] && continue
  expiry=$(jq -r --arg d "$root" '.domains[] | select(.domain == $d) | .expiry_date // ""' "$SNAPSHOT" 2>/dev/null)
  if [[ -z "$expiry" || "$expiry" == "null" ]]; then
    fail_v "missing expiry_date for: $root"
  fi
done <<< "$canonical_roots"

# --- Result ---
if [[ $violations -gt 0 ]]; then
  echo "D201 FAIL: domain registrar parity lock: $violations violation(s) detected (checks=$checks)" >&2
  exit 1
fi

echo "D201 PASS: domain registrar parity lock valid (checks=$checks, violations=0)"
