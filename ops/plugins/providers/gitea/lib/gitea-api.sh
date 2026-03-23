#!/usr/bin/env bash
set -euo pipefail

GITEA_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SPINE_ROOT="$(cd "$GITEA_LIB_DIR/../../../../.." && pwd)"
if [[ -z "${SPINE_ROOT:-}" || ! -r "${SPINE_ROOT}/ops/lib/platform-control-surface.sh" ]]; then
  SPINE_ROOT="$DEFAULT_SPINE_ROOT"
fi

# shellcheck source=/Users/ronnyworks/code/agentic-spine/ops/lib/spine-paths.sh
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true

# shellcheck source=/Users/ronnyworks/code/agentic-spine/ops/lib/platform-control-surface.sh
source "$SPINE_ROOT/ops/lib/platform-control-surface.sh"

gitea_stop() {
  echo "STOP: $*" >&2
  exit 2
}

gitea_require_tool() {
  command -v "$1" >/dev/null 2>&1 || gitea_stop "missing dependency: $1"
}

gitea_repo_slug_from_origin() {
  local origin
  origin="$(git remote get-url origin 2>/dev/null || true)"
  [[ -n "$origin" ]] || return 1
  python3 - "$origin" <<'PY'
import re
import sys

origin = sys.argv[1]
patterns = (
    r"^ssh://git@[^/]+(?::\d+)?/([^/]+)/([^/]+)\.git$",
    r"^git@[^:]+:([^/]+)/([^/]+)\.git$",
    r"^https?://[^/]+/([^/]+)/([^/]+)\.git$",
)
for pattern in patterns:
    match = re.match(pattern, origin)
    if match:
        print(f"{match.group(1)}/{match.group(2)}")
        sys.exit(0)
sys.exit(1)
PY
}

gitea_repo_slug_resolve() {
  local explicit="${1:-}"
  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
    return 0
  fi
  if [[ -n "${SPINE_GITEA_REPO_SLUG:-}" ]]; then
    printf '%s\n' "$SPINE_GITEA_REPO_SLUG"
    return 0
  fi
  gitea_repo_slug_from_origin || gitea_stop "could not determine repo slug from origin; pass --repo owner/repo"
}

gitea_repo_owner() {
  local slug="$1"
  printf '%s\n' "${slug%%/*}"
}

gitea_repo_name() {
  local slug="$1"
  printf '%s\n' "${slug#*/}"
}

gitea_api_url_resolve() {
  if [[ -n "${SPINE_GITEA_API_URL:-}" ]]; then
    printf '%s\n' "${SPINE_GITEA_API_URL%/}"
    return 0
  fi
  local resolved backend
  resolved="$(control_surface_backend_resolved_url gitea 2 2>/dev/null || true)"
  backend="$(awk '{print $1}' <<<"$resolved")"
  if [[ -n "$backend" ]]; then
    printf '%s\n' "${backend%/}"
    return 0
  fi
  backend="$(control_surface_backend_url gitea 2>/dev/null || true)"
  [[ -n "$backend" ]] || gitea_stop "could not resolve Gitea API backend"
  printf '%s\n' "${backend%/}"
}

gitea_mutation_mode_resolve() {
  if [[ -n "${SPINE_GITEA_MUTATION_MODE:-}" ]]; then
    printf '%s\n' "$SPINE_GITEA_MUTATION_MODE"
    return 0
  fi
  control_surface_mutation_mode gitea
}

gitea_token_resolve() {
  if [[ -n "${GITEA_API_TOKEN:-}" ]]; then
    printf '%s\n' "$GITEA_API_TOKEN"
    return 0
  fi
  if [[ -n "${GITEA_TOKEN:-}" ]]; then
    printf '%s\n' "$GITEA_TOKEN"
    return 0
  fi
  local agent token
  agent="$SPINE_ROOT/ops/plugins/providers/bin/infisical-agent.sh"
  [[ -x "$agent" ]] || gitea_stop "missing Infisical agent: $agent"
  token="$("$agent" get infrastructure prod GITEA_API_TOKEN 2>/dev/null || true)"
  [[ -n "$token" ]] || gitea_stop "GITEA_API_TOKEN could not be resolved from Infisical"
  printf '%s\n' "$token"
}

gitea_require_mutation_capability() {
  local mutation_mode
  mutation_mode="$(gitea_mutation_mode_resolve)"
  [[ "$mutation_mode" == *capability* ]] || gitea_stop "gitea control surface does not permit governed capability mutation (mutation_mode=${mutation_mode:-unset})"
}

gitea_api_request() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local api_url token body_file http_code curl_args
  api_url="$(gitea_api_url_resolve)"
  token="$(gitea_token_resolve)"
  body_file="$(mktemp)"
  trap 'rm -f "$body_file"' RETURN

  curl_args=(
    -sS
    -X "$method"
    -H "Authorization: token $token"
    -H "Accept: application/json"
    -o "$body_file"
    -w "%{http_code}"
  )
  if [[ -n "$data" ]]; then
    curl_args+=(-H "Content-Type: application/json" --data "$data")
  fi

  http_code="$(curl "${curl_args[@]}" "${api_url}${path}")" || gitea_stop "Gitea API request failed for ${method} ${path}"
  if [[ ! "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    echo "FAIL: Gitea API ${method} ${path} returned HTTP ${http_code}" >&2
    sed -n '1,120p' "$body_file" >&2 || true
    exit 1
  fi
  cat "$body_file"
}
