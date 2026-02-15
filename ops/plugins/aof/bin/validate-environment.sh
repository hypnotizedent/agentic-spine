#!/usr/bin/env bash
# aof.validate — Validate .environment.yaml and .identity.yaml structure.
set -euo pipefail

ENV_FILE=".environment.yaml"
IDENTITY_FILE=".identity.yaml"
STRICT=0

usage() {
  cat <<'EOF'
Usage:
  validate-environment.sh [--environment-file <path>] [--identity-file <path>] [--strict]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment-file) ENV_FILE="${2:-}"; shift 2 ;;
    --identity-file) IDENTITY_FILE="${2:-}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

command -v yq >/dev/null 2>&1 || { echo "ERROR: yq is required"; exit 1; }

ERR=0
WARN=0
err() { echo "ERROR: $*" >&2; ERR=$((ERR + 1)); }
warn() { echo "WARN: $*" >&2; WARN=$((WARN + 1)); }
ok() { echo "OK: $*"; }

[[ -f "$ENV_FILE" ]] || err "environment file not found: $ENV_FILE"
[[ -f "$IDENTITY_FILE" ]] || warn "identity file not found: $IDENTITY_FILE"
[[ "$ERR" -gt 0 ]] && exit 1

# Environment contract checks
yq e '.' "$ENV_FILE" >/dev/null || err "invalid YAML: $ENV_FILE"
version="$(yq -r '.version // ""' "$ENV_FILE")"
[[ "$version" == "1.0" ]] || warn "environment.version expected '1.0' (got '$version')"

name="$(yq -r '.environment.name // ""' "$ENV_FILE")"
[[ "$name" =~ ^[a-z0-9-]+$ ]] || err "environment.name must be kebab-case"
tier="$(yq -r '.environment.tier // ""' "$ENV_FILE")"
case "$tier" in
  production|product|lab|minimal|ephemeral) ok "environment.tier: $tier" ;;
  *) err "environment.tier invalid: '$tier'" ;;
esac

preflight_count="$(yq -r '.contracts.preflight | length // 0' "$ENV_FILE" 2>/dev/null || echo 0)"
if [[ "$preflight_count" -gt 0 ]]; then
  ok "contracts.preflight has $preflight_count steps"
else
  warn "contracts.preflight should define at least one step"
fi

# Optional identity checks when identity file exists
if [[ -f "$IDENTITY_FILE" ]]; then
  yq e '.' "$IDENTITY_FILE" >/dev/null || err "invalid YAML: $IDENTITY_FILE"
  node_id="$(yq -r '.identity.node_id // ""' "$IDENTITY_FILE")"
  [[ "$node_id" =~ ^[a-z0-9-]+$ ]] || err "identity.node_id must be kebab-case"
  spine_version="$(yq -r '.identity.spine_version // ""' "$IDENTITY_FILE")"
  [[ "$spine_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || warn "identity.spine_version should match vMAJOR.MINOR.PATCH"

  env_ref="$(yq -r '.identity.environment // ""' "$IDENTITY_FILE")"
  if [[ -n "$env_ref" && -n "$name" && "$env_ref" != "$name" ]]; then
    warn "identity.environment ('$env_ref') differs from environment.name ('$name')"
  fi
fi

echo ""
if [[ "$ERR" -gt 0 ]]; then
  echo "VALIDATION FAILED: $ERR error(s), $WARN warning(s)"
  exit 1
fi

if [[ "$STRICT" -eq 1 && "$WARN" -gt 0 ]]; then
  echo "VALIDATION FAILED (strict): 0 errors, $WARN warning(s)"
  exit 1
fi

echo "VALIDATION PASSED: 0 errors, $WARN warning(s)"
