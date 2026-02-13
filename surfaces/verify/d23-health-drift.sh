#!/usr/bin/env bash
# TRIAGE: Check service health endpoints match SERVICE_REGISTRY.yaml. No auth credentials in health checks.
set -euo pipefail

# D23: Services Health Surface Lock
# Ensures health-check tooling is read-only and non-leaky.
#
# FORBID:
#   - curl -v / --verbose (dumps headers including auth)
#   - Printing Authorization/Bearer patterns
#   - Mutating HTTP methods (POST/PUT/PATCH/DELETE)
#   - set -x (debug tracing leaks values)
#
# ALLOW:
#   - curl -fsS to known URLs only
#   - HTTP status code capture via -w

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { echo "D23 FAIL: $*" >&2; exit 1; }

# Scope: services plugin surface + binding
FILES=(
  ops/plugins/services/bin/services-*
  ops/bindings/services*.yaml
)

expanded=()
for f in "${FILES[@]}"; do
  while IFS= read -r path; do expanded+=("$path"); done < <(ls -1 $f 2>/dev/null || true)
done

((${#expanded[@]})) || fail "no services health surface files found to check"

# 1) Forbid verbose curl (leaks response headers)
if rg -n '\bcurl\b.*\s(-v|--verbose)\b' "${expanded[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "verbose curl detected in health surface"
fi

# 2) Forbid printing auth headers
if rg -n '(echo|printf).*(Authorization|Bearer|X-Auth)' "${expanded[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "auth header printing detected in health surface"
fi

# 3) Forbid mutating HTTP methods
if rg -n '\bcurl\b.*\s-X\s*(POST|PUT|PATCH|DELETE)\b' "${expanded[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "mutating HTTP method detected in health surface"
fi

# 4) Forbid debug tracing
if rg -n '\bset\s+-x\b' "${expanded[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "debug tracing (set -x) detected in health surface"
fi

# 5) Token/secret leak guardrail
if rg -n '(echo|printf).*(TOKEN|SECRET|API_KEY|PASSWORD)' "${expanded[@]}" 2>/dev/null | grep -v '^\s*#' >/dev/null; then
  fail "potential secret printing detected in health surface"
fi

echo "D23 PASS: services health surface drift locked"
