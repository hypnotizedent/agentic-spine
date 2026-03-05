#!/usr/bin/env bash
# TRIAGE: Update ops/bindings/rag.workspace.contract.yaml to match RAG CLI defaults. Ensure workspace slug, eligible roots, and exclusion prefixes are aligned.
# D87: RAG workspace contract lock
# Ensures the RAG workspace contract binding exists and is consistent with
# the RAG CLI defaults (workspace slug, eligible roots, exclusion prefixes).
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/rag.workspace.contract.yaml"
RAG_SCRIPT="$ROOT/ops/plugins/rag/bin/rag"

fail() { echo "D87 FAIL: $*" >&2; exit 1; }

[[ -f "$CONTRACT" ]] || fail "rag.workspace.contract.yaml not found"
[[ -f "$RAG_SCRIPT" ]] || fail "rag script not found"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

ERRORS=0
err() { echo "  $*" >&2; ERRORS=$((ERRORS + 1)); }

# 1. Contract has required top-level keys
for key in workspace embedding index_policy sync_policy cutover_policy; do
  val="$(yq -r ".$key" "$CONTRACT")"
  if [[ -z "$val" || "$val" == "null" ]]; then
    err "Contract missing required key: $key"
  fi
done

# 2. Workspace slug in contract matches CLI default
contract_slug="$(yq -r '.workspace.slug' "$CONTRACT")"
cli_default_slug="$(grep 'RAG_WORKSPACE_SLUG:-' "$RAG_SCRIPT" | head -1 | sed 's/.*RAG_WORKSPACE_SLUG:-//' | sed 's/}.*//' | tr -d '"' | tr -d "'")"
if [[ "$contract_slug" != "$cli_default_slug" ]]; then
  err "Workspace slug mismatch: contract='$contract_slug' vs CLI default='$cli_default_slug'"
fi

# 3. Eligible roots in contract match build_manifest allowed_roots
contract_roots="$(yq -r '.index_policy.eligible_roots[]' "$CONTRACT")"
# build_manifest has: allowed_roots = [root / "docs", root / "ops", root / "surfaces"]
for expected_root in "docs/" "ops/" "surfaces/"; do
  found=false
  while IFS= read -r root_entry; do
    [[ "$root_entry" == "$expected_root" ]] && found=true && break
  done <<< "$contract_roots"
  if [[ "$found" != "true" ]]; then
    err "Contract index_policy.eligible_roots missing: $expected_root"
  fi
done

# 4. Contract exclusion prefixes are a subset of build_manifest exclusions
contract_exclusions="$(yq -r '.index_policy.exclusion_prefixes[]' "$CONTRACT")"
# Verify key exclusions are in the contract
for required_excl in "docs/legacy/" "docs/governance/_audits/" "docs/governance/_archived/" "receipts/" "mailroom/state/"; do
  found=false
  while IFS= read -r excl_entry; do
    [[ "$excl_entry" == "$required_excl" ]] && found=true && break
  done <<< "$contract_exclusions"
  if [[ "$found" != "true" ]]; then
    err "Contract index_policy.exclusion_prefixes missing: $required_excl"
  fi
done

# 5. Frontmatter requirements match build_manifest
fm_list="$(yq -r '.index_policy.frontmatter_required[]' "$CONTRACT")"
for req in "status:" "owner:" "last_verified:"; do
  found=false
  while IFS= read -r fm_entry; do
    [[ "$fm_entry" == "$req" ]] && found=true && break
  done <<< "$fm_list"
  if [[ "$found" != "true" ]]; then
    err "Contract index_policy.frontmatter_required missing: $req"
  fi
done

# 6. Sync policy timeout matches CLI upload_file timeout
contract_timeout="$(yq -r '.sync_policy.upload_timeout_sec' "$CONTRACT")"
cli_default_timeout="$(sed -nE 's/^[[:space:]]*LS_TIMEOUT="\$\{RAG_UPLOAD_TIMEOUT:-([0-9]+)\}".*/\1/p' "$RAG_SCRIPT" | head -1 || true)"
if [[ -z "${cli_default_timeout:-}" || ! "$cli_default_timeout" =~ ^[0-9]+$ ]]; then
  err "Could not resolve CLI upload timeout default (LS_TIMEOUT/RAG_UPLOAD_TIMEOUT) from rag script"
elif [[ "$contract_timeout" != "$cli_default_timeout" ]]; then
  err "Sync timeout mismatch: contract=${contract_timeout}s vs CLI default=${cli_default_timeout}s"
fi
if ! grep -q 'max-time "\$LS_TIMEOUT"' "$RAG_SCRIPT"; then
  err "CLI upload path does not use LS_TIMEOUT for curl max-time"
fi

# 7. Secrets filter enabled in contract matches CLI implementation
contract_secrets="$(yq -r '.index_policy.secrets_filter' "$CONTRACT")"
if [[ "$contract_secrets" != "true" ]]; then
  err "Contract index_policy.secrets_filter should be true"
fi
if ! grep -q 'contains_secret_material' "$RAG_SCRIPT"; then
  err "CLI missing contains_secret_material function but contract claims secrets_filter=true"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  fail "$ERRORS contract parity errors found"
fi

echo "D87 PASS: RAG workspace contract lock enforced (slug=$contract_slug)"
