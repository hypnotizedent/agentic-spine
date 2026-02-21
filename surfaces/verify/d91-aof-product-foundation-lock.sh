#!/usr/bin/env bash
# TRIAGE: Ensure AOF product docs, bindings, and tenant capabilities exist and are correctly wired. Create missing artifacts using LOOP-AOF-V01-FOUNDATION pattern.
# D91: AOF product foundation lock
# Enforces: required product docs exist, required bindings have required keys/presets,
# tenant capabilities exist and are executable, docs discoverability is wired,
# and root AOF contracts pass strict validation.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

# ── 1. Required product docs ──
PRODUCT_DOCS=(
  "docs/product/AOF_PRODUCT_CONTRACT.md"
  "docs/product/AOF_ACCEPTANCE_GATES.md"
  "docs/product/AOF_DEPLOYMENT_PLAYBOOK.md"
  "docs/product/AOF_SUPPORT_SLO.md"
)

for doc in "${PRODUCT_DOCS[@]}"; do
  if [[ -f "$ROOT/$doc" ]]; then
    # Check frontmatter has required fields
    if ! grep -q '^status: authoritative' "$ROOT/$doc"; then
      err "$doc missing 'status: authoritative' frontmatter"
    else
      ok "$doc exists with valid frontmatter"
    fi
  else
    err "$doc does not exist"
  fi
done

# ── 2. Required bindings exist with required keys/presets ──
SCHEMA="$ROOT/ops/bindings/tenant.profile.schema.yaml"
PRESETS="$ROOT/ops/bindings/policy.presets.yaml"

if [[ -f "$SCHEMA" ]]; then
  # Check schema has required sections
  for section in identity secrets policy runtime surfaces evidence; do
    if ! grep -q "^  $section:" "$SCHEMA"; then
      err "tenant.profile.schema.yaml missing section: $section"
    else
      ok "tenant.profile.schema.yaml has section: $section"
    fi
  done
else
  err "ops/bindings/tenant.profile.schema.yaml does not exist"
fi

if [[ -f "$PRESETS" ]]; then
  # Check presets has required presets
  for preset in strict balanced permissive; do
    if ! grep -q "^  $preset:" "$PRESETS"; then
      err "policy.presets.yaml missing preset: $preset"
    else
      ok "policy.presets.yaml has preset: $preset"
    fi
  done
else
  err "ops/bindings/policy.presets.yaml does not exist"
fi

# ── 3. Tenant capabilities exist and are executable ──
CAPS_YAML="$ROOT/ops/capabilities.yaml"
CAP_MAP="$ROOT/ops/bindings/capability_map.yaml"

for cap in "tenant.profile.validate" "tenant.provision.dry-run"; do
  # Check registered in capabilities.yaml
  if grep -q "^  $cap:" "$CAPS_YAML" 2>/dev/null; then
    ok "$cap registered in capabilities.yaml"
  else
    err "$cap not registered in capabilities.yaml"
  fi

  # Check registered in capability_map.yaml
  if grep -q "^  $cap:" "$CAP_MAP" 2>/dev/null; then
    ok "$cap registered in capability_map.yaml"
  else
    err "$cap not registered in capability_map.yaml"
  fi
done

# Check scripts are executable
VALIDATE_SCRIPT="$ROOT/ops/plugins/tenant/bin/tenant-profile-validate"
DRYRUN_SCRIPT="$ROOT/ops/plugins/tenant/bin/tenant-provision-dry-run"

if [[ -x "$VALIDATE_SCRIPT" ]]; then
  ok "tenant-profile-validate is executable"
else
  err "ops/plugins/tenant/bin/tenant-profile-validate is not executable or does not exist"
fi

if [[ -x "$DRYRUN_SCRIPT" ]]; then
  ok "tenant-provision-dry-run is executable"
else
  err "ops/plugins/tenant/bin/tenant-provision-dry-run is not executable or does not exist"
fi

# Check MANIFEST.yaml has tenant plugin
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"
if grep -q 'name: tenant' "$MANIFEST" 2>/dev/null; then
  ok "tenant plugin registered in MANIFEST.yaml"
else
  err "tenant plugin not registered in MANIFEST.yaml"
fi

# ── 4. Docs discoverability ──
DOCS_README="$ROOT/docs/README.md"
GOV_INDEX="$ROOT/docs/governance/GOVERNANCE_INDEX.md"

if [[ -f "$DOCS_README" ]]; then
  if grep -q 'product/' "$DOCS_README" 2>/dev/null; then
    ok "docs/README.md references product/"
  else
    err "docs/README.md does not reference product/ directory"
  fi
else
  err "docs/README.md does not exist"
fi

# ── 5. Root AOF environment contract validation ──
AOF_VALIDATE_SCRIPT="$ROOT/ops/plugins/aof/bin/validate-environment.sh"
ENV_CONTRACT="$ROOT/.environment.yaml"
IDENTITY_CONTRACT="$ROOT/.identity.yaml"

if [[ -x "$AOF_VALIDATE_SCRIPT" ]]; then
  ok "aof.validate script exists"
else
  err "ops/plugins/aof/bin/validate-environment.sh is not executable or does not exist"
fi

if [[ -f "$ENV_CONTRACT" ]]; then
  ok ".environment.yaml exists"
else
  err ".environment.yaml does not exist"
fi

if [[ -f "$IDENTITY_CONTRACT" ]]; then
  ok ".identity.yaml exists"
else
  err ".identity.yaml does not exist"
fi

if [[ -x "$AOF_VALIDATE_SCRIPT" && -f "$ENV_CONTRACT" && -f "$IDENTITY_CONTRACT" ]]; then
  if validate_output="$("$AOF_VALIDATE_SCRIPT" --environment-file "$ENV_CONTRACT" --identity-file "$IDENTITY_CONTRACT" --strict 2>&1)"; then
    ok "aof.validate strict contract check passed"
  else
    err "aof.validate strict contract check failed"
    if [[ "${DRIFT_VERBOSE:-0}" == "1" ]]; then
      while IFS= read -r line; do
        [[ -n "$line" ]] && echo "    $line" >&2
      done <<<"$validate_output"
    fi
  fi
fi

# ── Result ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D91 FAIL: $ERRORS check(s) failed"
  exit 1
fi
exit 0
