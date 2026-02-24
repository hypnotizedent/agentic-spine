#!/usr/bin/env bash
# TRIAGE: Domain canonical roots: portfolio and migration plan must only reference roots defined in domain.canonical.roots.yaml.
# D200: Domain canonical roots lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
violations=0

fail_v() {
  echo "  VIOLATION: $*" >&2
  violations=$((violations + 1))
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "D200 FAIL: missing command: $1" >&2; exit 1; }
}

need_cmd yq

ROOTS_FILE="$ROOT/ops/bindings/domain.canonical.roots.yaml"
PORTFOLIO_FILE="$ROOT/ops/bindings/domain.portfolio.registry.yaml"
PLAN_DIR="$ROOT/docs/governance"

# --- Precondition: canonical roots binding must exist ---
if [[ ! -f "$ROOTS_FILE" ]]; then
  echo "D200 FAIL: canonical roots binding missing: $ROOTS_FILE" >&2
  exit 1
fi

# --- Load canonical roots ---
canonical_roots=""
while IFS= read -r root; do
  [[ -z "$root" || "$root" == "null" ]] && continue
  canonical_roots="${canonical_roots}${root}"$'\n'
done < <(yq e '.roots[].domain' "$ROOTS_FILE" 2>/dev/null)

if [[ -z "$canonical_roots" ]]; then
  echo "D200 FAIL: no canonical roots found in $ROOTS_FILE" >&2
  exit 1
fi

is_canonical() {
  local domain="$1"
  while IFS= read -r root; do
    [[ -z "$root" ]] && continue
    case "$domain" in
      "$root"|*."$root") return 0 ;;
    esac
  done <<< "$canonical_roots"
  return 1
}

checks=0

# --- Check 1: Portfolio domains must all be canonical roots ---
if [[ -f "$PORTFOLIO_FILE" ]]; then
  checks=$((checks + 1))
  while IFS= read -r domain; do
    [[ -z "$domain" || "$domain" == "null" ]] && continue
    if ! is_canonical "$domain"; then
      fail_v "non-canonical domain in portfolio: $domain"
    fi
  done < <(yq e '.domains[].domain' "$PORTFOLIO_FILE" 2>/dev/null)
fi

# --- Check 2: Portfolio wave domain lists must all be canonical ---
if [[ -f "$PORTFOLIO_FILE" ]]; then
  checks=$((checks + 1))
  while IFS= read -r domain; do
    [[ -z "$domain" || "$domain" == "null" ]] && continue
    if ! is_canonical "$domain"; then
      fail_v "non-canonical domain in portfolio wave: $domain"
    fi
  done < <(yq e '.waves[].domains[]' "$PORTFOLIO_FILE" 2>/dev/null)
fi

# --- Check 3: Migration plan tasks must only reference canonical domains ---
checks=$((checks + 1))
for taskfile in "$PLAN_DIR"/generated/W*_DOMAIN_MIGRATION_TASKS_*.yaml; do
  [[ -f "$taskfile" ]] || continue
  while IFS= read -r domain; do
    [[ -z "$domain" || "$domain" == "null" || "$domain" == "all" ]] && continue
    if ! is_canonical "$domain"; then
      fail_v "non-canonical domain in $(basename "$taskfile"): $domain"
    fi
  done < <(yq e '.tasks[].domain' "$taskfile" 2>/dev/null)
done

# --- Check 4: Migration plan doc must not contain non-canonical domain literals ---
checks=$((checks + 1))
PLAN_DOC="$PLAN_DIR/DOMAIN_PLATFORM_MIGRATION_PLAN.md"
if [[ -f "$PLAN_DOC" ]]; then
  while IFS= read -r root; do
    [[ -z "$root" ]] && continue
    # Build a pattern that matches domain roots but not subdomains of canonical roots
    # We check that any .com/.co/.works domain in the doc is canonical
  done <<< "$canonical_roots"

  # Extract domain-like references from the plan doc.
  # Filter: must look like a real domain root (2+ label parts, TLD at end, no path fragments).
  # Exclude known infrastructure/third-party domains and file-path fragments (.contract.yaml, .stack.co, etc).
  while IFS= read -r domain_ref; do
    [[ -z "$domain_ref" ]] && continue
    if ! is_canonical "$domain_ref"; then
      fail_v "non-canonical domain in migration plan: $domain_ref"
    fi
  done < <(grep -oE '\b[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.(com|co|works)\b' "$PLAN_DOC" 2>/dev/null \
    | grep -vE '\.(contract|stack|providers|policy|templates|delivery|sync|global|inventory|routing)\.' \
    | grep -vE '(cloudflare\.com|namecheap\.com|shopify\.com|resend\.com|amazonaws\.com|amazonses\.com|pages\.dev|registrar-servers\.com|microsoft\.com)' \
    | sort -u)
fi

# --- Result ---
if [[ $violations -gt 0 ]]; then
  echo "D200 FAIL: domain canonical roots lock: $violations violation(s) detected" >&2
  exit 1
fi

echo "D200 PASS: domain canonical roots lock valid (checks=$checks, violations=0)"
