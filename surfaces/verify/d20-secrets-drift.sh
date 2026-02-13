#!/usr/bin/env bash
set -euo pipefail

# D20: Secrets Surface Lock
# Ensures secrets tooling is read-only and non-leaky.
#
# ALLOW:
#   - curl with Authorization header as INPUT only (never printed)
#   - Auth token exchange to allowlisted endpoint only (/api/v1/auth/universal-auth/login)
#   - Printing non-secret identifiers (INFISICAL_API_URL, CLIENT_ID)
#
# FORBID:
#   - Printing secret variables (TOKEN, CLIENT_SECRET, ACCESS_TOKEN)
#   - Printing Authorization/Bearer patterns (echo, printf, log)
#   - Verbose curl (-v, --verbose) which dumps headers
#   - Env dumping (printenv, env |, set |)
#   - Mutating Infisical CLI (secrets set/update/delete)
#   - Mutating HTTP to Infisical (except auth login)
#   - Writing .env files

fail() { echo "D20 FAIL: $*" >&2; exit 1; }

# Scope: read-only secrets surface + bindings.
# Guarded migration/cleanup tools are governed by D43 and excluded here.
FILES=(
  ops/plugins/secrets/bin/secrets-*
  ops/bindings/secrets*.yaml
)
EXCLUDED_FILES=(
  ops/plugins/secrets/bin/secrets-p1-root-cleanup
  ops/plugins/secrets/bin/secrets-cohort-copy-first
)

# Expand globs safely
expanded=()
for f in "${FILES[@]}"; do
  while IFS= read -r path; do
    skip=0
    for excluded in "${EXCLUDED_FILES[@]}"; do
      if [[ "$path" == "$excluded" ]]; then
        skip=1
        break
      fi
    done
    (( skip == 0 )) && expanded+=("$path")
  done < <(ls -1 $f 2>/dev/null || true)
done

((${#expanded[@]})) || fail "no secrets surface files found to check"

# ─────────────────────────────────────────────────────────────────────────────
# 1) Forbid PRINTING secret/token values
# ─────────────────────────────────────────────────────────────────────────────

# Forbidden variables in echo/printf context:
# INFISICAL_TOKEN, INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET, CLIENT_SECRET, ACCESS_TOKEN
if rg -n -e 'echo\s+.*\$(INFISICAL_TOKEN|INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET|CLIENT_SECRET|ACCESS_TOKEN)' \
        -e 'echo\s+.*\$\{(INFISICAL_TOKEN|INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET|CLIENT_SECRET|ACCESS_TOKEN)' \
        -e 'printf.*\$(INFISICAL_TOKEN|INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET|CLIENT_SECRET|ACCESS_TOKEN)' \
        -e 'printf.*\$\{(INFISICAL_TOKEN|INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET|CLIENT_SECRET|ACCESS_TOKEN)' \
        "${expanded[@]}" 2>/dev/null; then
  fail "printing of secret variables detected"
fi

# Forbid env dumping commands
if rg -n -e '\bprintenv\b' -e '\benv\s*\|' -e '\bset\s*\|' "${expanded[@]}" 2>/dev/null; then
  fail "env dumping command detected"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2) Forbid PRINTING Authorization/Bearer (allow only in curl -H context)
# ─────────────────────────────────────────────────────────────────────────────

# Any echo/printf of Authorization or Bearer is forbidden
for f in "${expanded[@]}"; do
  # Check for echo/printf containing Authorization or Bearer
  leaks=$(rg -n -e '^[^#]*(echo|printf).*Authorization' -e '^[^#]*(echo|printf).*Bearer' "$f" 2>/dev/null || true)
  if [[ -n "$leaks" ]]; then
    echo "$leaks"
    fail "printing Authorization/Bearer pattern detected in $f"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# 3) Forbid verbose curl (dumps headers including Authorization)
# ─────────────────────────────────────────────────────────────────────────────

if rg -n -e 'curl\s+.*(-v\b|--verbose|--trace)' "${expanded[@]}" 2>/dev/null; then
  fail "verbose curl detected (would dump Authorization headers)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4) Forbid mutating Infisical CLI operations
# ─────────────────────────────────────────────────────────────────────────────

if rg -n -e '\binfisical\b.*\b(secrets|projects)\b.*\b(set|update|delete|create)\b' "${expanded[@]}" 2>/dev/null; then
  fail "mutating infisical command detected"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5) Forbid mutating HTTP verbs (except allowlisted auth endpoint)
# ─────────────────────────────────────────────────────────────────────────────

# ONLY allow: POST to /api/v1/auth/universal-auth/login
# Forbid: all other POST/PUT/PATCH/DELETE to Infisical

for f in "${expanded[@]}"; do
  mutations=$(rg -n -e 'curl.*(-X|--request)\s*(POST|PUT|PATCH|DELETE)' "$f" 2>/dev/null || true)
  if [[ -n "$mutations" ]]; then
    # Filter out the ONLY allowed endpoint
    non_auth=$(echo "$mutations" | grep -v '/api/v1/auth/universal-auth/login' || true)
    if [[ -n "$non_auth" ]]; then
      # Check if targeting Infisical
      if echo "$non_auth" | grep -qiE '(infisical|secrets\.ronny\.works|INFISICAL_API_URL|/api/v[0-9]/)'; then
        echo "$non_auth"
        fail "mutating HTTP request toward Infisical detected in $f (only /api/v1/auth/universal-auth/login POST allowed)"
      fi
    fi
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# 6) Forbid .env writes/sync in secrets surface
# ─────────────────────────────────────────────────────────────────────────────

if rg -n -e '>\s*\.env\b' -e 'tee\s+.*\.env\b' -e '\bsync-secrets-to-env\b' -e '\bdotenv\s+sync\b' "${expanded[@]}" 2>/dev/null; then
  fail ".env write/sync behavior detected in secrets surface"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 7) Forbid raw secret literals in output commands
# ─────────────────────────────────────────────────────────────────────────────

if rg -n -e 'echo.*client_secret' -e 'echo.*access_token' -e 'echo.*refresh_token' \
        -e 'printf.*client_secret' -e 'printf.*access_token' -e 'printf.*refresh_token' \
        -e 'echo.*api_key' -e 'echo.*api_secret' \
        -e 'printf.*api_key' -e 'printf.*api_secret' \
        "${expanded[@]}" 2>/dev/null; then
  fail "literal secret pattern in output command detected"
fi

echo "D20 secrets drift gate... PASS"
