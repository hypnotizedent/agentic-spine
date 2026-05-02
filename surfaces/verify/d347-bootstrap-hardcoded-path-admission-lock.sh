#!/usr/bin/env bash
# TRIAGE: Remove machine-specific absolute host paths from spine bootstrap entrypoint scripts. Use path tokens and runtime bindings only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/runtime.bootstrap.contract.yaml"
INIT_SCRIPT="$ROOT/ops/plugins/core/session/bin/spine-init"
DOCTOR_SCRIPT="$ROOT/ops/plugins/core/session/bin/spine-doctor"

fail() { echo "D347 FAIL: $*" >&2; exit 1; }

# yq is required to read the contract's required_runtime_tools list.
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONTRACT" ]] || fail "missing bootstrap contract: $CONTRACT"

# Read the canonical required_runtime_tools list from the contract and validate
# every listed tool is available on the host. This replaces hardcoded
# `command -v rg` checks with contract-driven validation. Adding or removing a
# tool from runtime.bootstrap.contract.yaml#bootstrap_preconditions.required_runtime_tools
# changes which tools D347 checks. No new gate; canonical source is the contract.
mapfile -t required_runtime_tools < <(
  yq e -r '.bootstrap_preconditions.required_runtime_tools[]?' "$CONTRACT" 2>/dev/null || true
)
(( ${#required_runtime_tools[@]} > 0 )) || fail "contract missing bootstrap_preconditions.required_runtime_tools list"
missing_tools=()
for tool in "${required_runtime_tools[@]}"; do
  [[ -n "$tool" && "$tool" != "null" ]] || continue
  command -v "$tool" >/dev/null 2>&1 || missing_tools+=("$tool")
done
if (( ${#missing_tools[@]} > 0 )); then
  fail "required runtime tool(s) missing on host: ${missing_tools[*]} (declared in $CONTRACT bootstrap_preconditions.required_runtime_tools)"
fi

[[ -x "$INIT_SCRIPT" ]] || fail "missing/non-executable script: $INIT_SCRIPT"
[[ -x "$DOCTOR_SCRIPT" ]] || fail "missing/non-executable script: $DOCTOR_SCRIPT"

mapfile -t prohibited_literals < <(
  yq e -r '.path_abstraction_policy.prohibited_literals_for_new_runtime_writes[]?' "$CONTRACT" 2>/dev/null || true
)

(( ${#prohibited_literals[@]} > 0 )) || fail "contract missing prohibited path literals list"

violations=0
for literal in "${prohibited_literals[@]}"; do
  [[ -n "$literal" && "$literal" != "null" ]] || continue
  hits="$(rg -n --fixed-strings "$literal" "$INIT_SCRIPT" "$DOCTOR_SCRIPT" 2>/dev/null || true)"
  if [[ -n "$hits" ]]; then
    echo "  literal detected in bootstrap entrypoints: $literal" >&2
    echo "$hits" >&2
    violations=$((violations + 1))
  fi
done

if [[ "$violations" -gt 0 ]]; then
  fail "$violations prohibited absolute path literal(s) found in bootstrap scripts"
fi

echo "D347 PASS: bootstrap entrypoints are free of prohibited host-specific absolute paths"
