#!/usr/bin/env bash
# Resolve the L2 secrets control-plane root without trusting ambient target repo.

secrets__canonical_dir() {
  local raw="${1:-}"
  [[ -n "$raw" ]] || return 1
  raw="${raw/#\~/$HOME}"
  [[ -d "$raw" ]] || return 1
  (cd "$raw" 2>/dev/null && pwd -P)
}

secrets__root_has_contract() {
  local root="${1:-}"
  [[ -n "$root" ]] || return 1
  [[ -f "$root/ops/bindings/secrets.binding.yaml" ]] || return 1
  [[ -d "$root/ops/plugins/infra/secrets/bin" ]] || return 1
  [[ -x "$root/ops/plugins/providers/bin/infisical-agent.sh" ]] || return 1
}

secrets_resolve_control_root() {
  local helper_dir=""
  local script_root=""
  local candidate=""
  local resolved=""

  helper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  script_root="$(cd "$helper_dir/../../../../.." && pwd -P)"

  for candidate in \
    "$script_root" \
    "${SPINE_CODE:-}" \
    "${SPINE_ROOT:-}" \
    "$HOME/code/agentic-spine" \
    "${SPINE_REPO:-}" \
    "${SPINE_TARGET_REPO:-}"
  do
    resolved="$(secrets__canonical_dir "$candidate" 2>/dev/null || true)"
    [[ -n "$resolved" ]] || continue
    if secrets__root_has_contract "$resolved"; then
      printf '%s\n' "$resolved"
      return 0
    fi
  done

  printf '%s\n' "$script_root"
}

secrets_bind_control_root() {
  local root=""
  root="$(secrets_resolve_control_root)"
  export SPINE_REPO="$root"
  export SPINE_ROOT="$root"
  export SPINE_CODE="$root"
}
