#!/usr/bin/env bash
# TRIAGE: keep one authoritative source per concern with explicit projection/tombstoned markers.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-$HOME/code/workbench}"
MINT_ROOT="${MINT_ROOT:-$HOME/code/mint-modules}"
CONTRACT="$ROOT/ops/bindings/authority.concerns.yaml"

fail() {
  echo "D275 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"

yq e '.' "$CONTRACT" >/dev/null 2>&1 || fail "invalid YAML: $CONTRACT"

errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

mapfile -t concerns < <(yq e -r '.concerns | keys | .[]' "$CONTRACT")
[[ "${#concerns[@]}" -gt 0 ]] || err "contract has no concerns"

declare -A authoritative_paths=()

for concern in "${concerns[@]}"; do
  authoritative_count=0
  non_authoritative_count=0
  source_count=0

  while IFS=$'\t' read -r path state marker; do
    [[ -n "$path" ]] || continue
    source_count=$((source_count + 1))

    case "$state" in
      authoritative)
        authoritative_count=$((authoritative_count + 1))
        authoritative_paths["$path"]=1
        ;;
      projection|tombstoned)
        non_authoritative_count=$((non_authoritative_count + 1))
        ;;
      *)
        err "$concern has invalid state '$state' for path '$path'"
        ;;
    esac

    if [[ ! -f "$path" ]]; then
      err "$concern missing source path: $path"
      continue
    fi

    if [[ -z "$marker" || "$marker" == "null" ]]; then
      err "$concern source '$path' missing required_marker"
      continue
    fi

    if ! rg -n --fixed-strings "$marker" "$path" >/dev/null 2>&1; then
      err "$concern source '$path' missing marker '$marker'"
    fi
  done < <(yq e -r ".concerns.\"$concern\".sources[] | [(.path // \"\"), (.state // \"\"), (.required_marker // \"\")] | @tsv" "$CONTRACT")

  if [[ "$source_count" -eq 0 ]]; then
    err "$concern has zero sources"
    continue
  fi

  if [[ "$authoritative_count" -ne 1 ]]; then
    err "$concern must have exactly one authoritative source (found $authoritative_count)"
  fi

  if [[ "$non_authoritative_count" -lt 1 ]]; then
    err "$concern must declare projection/tombstoned sources"
  fi
done

if [[ "$(yq e -r '.policy.require_concern_map_update_for_new_authoritative_surface // false' "$CONTRACT")" == "true" ]]; then
  mapfile -t discovered_authoritative < <(
    rg -l \
      -g '*.yaml' \
      -g '*.md' \
      -e '^[[:space:]#-]*authority_state:[[:space:]]*authoritative([[:space:]]|$)' \
      -e '^[[:space:]#-]*gate_metadata_authority:[[:space:]]*authoritative([[:space:]]|$)' \
      "$ROOT/docs" "$ROOT/ops" "$WORKBENCH_ROOT" "$MINT_ROOT" 2>/dev/null \
      | sort -u
  )

  for path in "${discovered_authoritative[@]}"; do
    [[ -n "${authoritative_paths[$path]:-}" ]] || err "authoritative marker exists outside concern map: $path"
  done
fi

if [[ "$errors" -gt 0 ]]; then
  fail "$errors violation(s)"
fi

echo "D275 PASS: authority concern map enforced (concerns=${#concerns[@]})"
