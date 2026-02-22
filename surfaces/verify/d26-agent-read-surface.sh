#!/usr/bin/env bash
# TRIAGE: Check agent read surfaces (AGENTS.md, CLAUDE.md) for stale references.
set -euo pipefail

# D26: Agent Read Surface Lock
# Enforces canonical startup read docs + host/service update routing.
# Also enforces external repo front-door redirects and blocks legacy 00_CLAUDE
# references in active surfaces.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINDING="$ROOT/ops/bindings/agent.read.surface.yaml"

fail() { echo "D26 FAIL: $*" >&2; exit 1; }

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

expand_home() {
  local path="$1"
  if [[ "$path" == "~"* ]]; then
    printf '%s\n' "${HOME}${path:1}"
  else
    printf '%s\n' "$path"
  fi
}

require_tool yq
require_tool rg

[[ -f "$BINDING" ]] || fail "binding not found: $BINDING"
yq e '.' "$BINDING" >/dev/null 2>&1 || fail "binding is not valid YAML"

WB_ROOT="${WORKBENCH_ROOT:-$(expand_home "$(yq e '.workspaces.workbench' "$BINDING")")}"
MM_ROOT="${MINT_MODULES_ROOT:-$(expand_home "$(yq e '.workspaces.mint_modules' "$BINDING")")}"

[[ -d "$WB_ROOT" ]] || fail "workbench workspace missing: $WB_ROOT"
[[ -d "$MM_ROOT" ]] || fail "mint-modules workspace missing: $MM_ROOT"

# 1) Startup read surface files must exist in spine.
while IFS= read -r rel; do
  [[ -z "${rel:-}" || "${rel:-}" == "null" ]] && continue
  [[ -f "$ROOT/$rel" ]] || fail "startup read surface missing: $rel"
done < <(yq e '.startup_read_surface[]' "$BINDING")

# 2) Host/service route files must exist in spine.
while IFS= read -r rel; do
  [[ -z "${rel:-}" || "${rel:-}" == "null" ]] && continue
  [[ -f "$ROOT/$rel" ]] || fail "host detail route missing: $rel"
done < <(yq e '.host_fact_routes.host_detail[]' "$BINDING")

for key in identity services; do
  rel="$(yq e ".host_fact_routes.${key}" "$BINDING")"
  [[ -n "${rel:-}" && "${rel:-}" != "null" ]] || fail "missing host_fact_routes.${key} in binding"
  [[ -f "$ROOT/$rel" ]] || fail "route file missing (${key}): $rel"
done

# 3) Governance index must reference startup read surface paths.
GOV_INDEX="$ROOT/docs/governance/GOVERNANCE_INDEX.md"
[[ -f "$GOV_INDEX" ]] || fail "missing governance index: $GOV_INDEX"
while IFS= read -r rel; do
  [[ -z "${rel:-}" || "${rel:-}" == "null" ]] && continue
  rg -q --fixed-strings "$rel" "$GOV_INDEX" || fail "governance index missing startup surface reference: $rel"
done < <(yq e '.startup_read_surface[]' "$BINDING")

# 4) SSOT update template must reference all host/service route files.
SSOT_TEMPLATE="$ROOT/docs/governance/SSOT_UPDATE_TEMPLATE.md"
[[ -f "$SSOT_TEMPLATE" ]] || fail "missing SSOT update template: $SSOT_TEMPLATE"
for rel in \
  "$(yq e '.host_fact_routes.identity' "$BINDING")" \
  "$(yq e '.host_fact_routes.services' "$BINDING")"; do
  base="$(basename "$rel")"
  rg -q --fixed-strings "$base" "$SSOT_TEMPLATE" || fail "SSOT update template missing route reference: $base"
done
while IFS= read -r rel; do
  [[ -z "${rel:-}" || "${rel:-}" == "null" ]] && continue
  base="$(basename "$rel")"
  rg -q --fixed-strings "$base" "$SSOT_TEMPLATE" || fail "SSOT update template missing host detail reference: $base"
done < <(yq e '.host_fact_routes.host_detail[]' "$BINDING")

# 5) External entrypoint files must exist and redirect to spine session protocol.
ep_count="$(yq e '.external_entrypoints | length' "$BINDING")"
[[ "$ep_count" =~ ^[0-9]+$ ]] || fail "external_entrypoints length parse error"
(( ep_count > 0 )) || fail "external_entrypoints list is empty"

for ((i=0; i<ep_count; i++)); do
  repo_key="$(yq e ".external_entrypoints[$i].repo" "$BINDING")"
  rel="$(yq e ".external_entrypoints[$i].path" "$BINDING")"
  must_ref="$(yq e ".external_entrypoints[$i].must_reference" "$BINDING")"
  [[ -n "$repo_key" && "$repo_key" != "null" ]] || fail "external_entrypoints[$i].repo missing"
  [[ -n "$rel" && "$rel" != "null" ]] || fail "external_entrypoints[$i].path missing"
  [[ -n "$must_ref" && "$must_ref" != "null" ]] || fail "external_entrypoints[$i].must_reference missing"

  case "$repo_key" in
    workbench) base="$WB_ROOT" ;;
    mint_modules) base="$MM_ROOT" ;;
    *) fail "unsupported repo key in binding: $repo_key" ;;
  esac

  target="$base/$rel"
  [[ -f "$target" ]] || fail "external entrypoint missing: $target"
  rg -q --fixed-strings "$must_ref" "$target" || fail "external entrypoint missing redirect reference: $target"
done

# 6) Forbid legacy start-file terms in active surfaces.
while IFS= read -r term; do
  [[ -z "${term:-}" || "${term:-}" == "null" ]] && continue
  legacy_a="docs"
  legacy_b="legacy"
  hits="$(
    rg -n --hidden --fixed-strings "$term" \
      "$ROOT/bin" \
      "$ROOT/docs/core" \
      "$ROOT/docs/governance" \
      "$ROOT/ops/commands" \
      "$ROOT/ops/plugins" \
      "$ROOT/ops/runtime" \
      "$ROOT/surfaces" \
      "$WB_ROOT" "$MM_ROOT" \
      --glob '!**/.git/**' \
      --glob '!**/.archive/**' \
      --glob '!**/.archive-immutable/**' \
      --glob '!**/archive/**' \
      --glob "!**/${legacy_a}/${legacy_b}/**" \
      --glob '!**/docs/governance/_audits/**' \
      --glob '!**/docs/governance/_archive/**' \
      --glob '!**/docs/governance/_receipts_meta/**' \
      --glob '!**/runtime/**' \
      --glob '!**/infra/data/**' \
      --glob '!**/receipts/**' \
      --glob '!**/mailroom/**' \
      --glob '!**/node_modules/**' 2>/dev/null || true
  )"
  [[ -z "$hits" ]] || fail "forbidden term '$term' found in active surfaces"
done < <(yq e '.forbidden_terms[]?' "$BINDING")

echo "D26 PASS: agent read surface drift locked"
