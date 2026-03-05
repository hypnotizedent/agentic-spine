#!/usr/bin/env bash
# TRIAGE: Keep domain docs routed to workbench and spine files as pointer stubs. Update ops/bindings/domain.docs.routes.yaml when moving domain docs.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
WORKBENCH="${WORKBENCH_ROOT:-$HOME/code/workbench}"
ROUTES="$ROOT/ops/bindings/domain.docs.routes.yaml"
BOUNDARY="$ROOT/ops/bindings/fabric.boundary.contract.yaml"

fail() {
  echo "D122 FAIL: $*" >&2
  exit 1
}

[[ -f "$ROUTES" ]] || fail "missing route binding: $ROUTES"
[[ -f "$BOUNDARY" ]] || fail "missing boundary contract: $BOUNDARY"
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"

yq e '.' "$ROUTES" >/dev/null 2>&1 || fail "invalid YAML: $ROUTES"
yq e '.' "$BOUNDARY" >/dev/null 2>&1 || fail "invalid YAML: $BOUNDARY"

stub_marker="$(yq e -r '.docs_boundary.spine_stub_marker' "$BOUNDARY")"
[[ -n "$stub_marker" && "$stub_marker" != "null" ]] || fail "docs_boundary.spine_stub_marker missing"

# Ensure every route is complete and points to real files.
while IFS=$'\t' read -r domain src_rel dst_rel stub_rel; do
  [[ -z "$src_rel" || -z "$dst_rel" || -z "$stub_rel" ]] && fail "route entry has empty fields"

  src="$ROOT/$src_rel"
  dst="$WORKBENCH/$dst_rel"
  stub="$ROOT/$stub_rel"

  [[ -f "$src" ]] || fail "missing spine source stub: $src_rel"
  [[ -f "$dst" ]] || fail "missing workbench target doc: $dst_rel"
  [[ -f "$stub" ]] || fail "missing spine route stub: $stub_rel"

  grep -q "^${stub_marker}$" "$src" || fail "spine source is not marked stub: $src_rel"
  grep -q "^${stub_marker}$" "$stub" || fail "domain route stub missing marker: $stub_rel"

done < <(yq e -r '.routes[] | [.domain, .spine_source, .workbench_target, .spine_stub] | @tsv' "$ROUTES")

# Ensure every stub file under docs/governance/domains is registered in routes.
while IFS= read -r rel_stub; do
  [[ -z "$rel_stub" ]] && continue
  if ! grep -q "^${stub_marker}$" "$ROOT/$rel_stub"; then
    continue
  fi
  match_count="$(yq e -r '.routes[].spine_stub' "$ROUTES" | grep -Fxc "$rel_stub" || true)"
  if [[ "$match_count" -eq 0 ]]; then
    fail "unregistered domain stub in docs/governance/domains: $rel_stub"
  fi
done < <(cd "$ROOT" && find docs/governance/domains -type f -name '*.md' ! -name 'README.md' | sort)

echo "D122 PASS: domain docs routing lock enforced"
