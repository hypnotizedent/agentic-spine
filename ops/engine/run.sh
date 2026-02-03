#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${ROOT}/runs"

usage() {
  cat <<EOF
Usage: $0 <RUN_ID>

Selects an engine provider (local|claude|zai|openai) via \$SPINE_ENGINE_PROVIDER
and executes the provider script with <RUN_ID>.

Defaults to 'openai' with a Claude fallback in case the OpenAI call fails.
EOF
  exit 1
}

run_id="${1:-}"
[[ -n "${run_id}" ]] || usage

provider="${SPINE_ENGINE_PROVIDER:-openai}"

case "${provider}" in
  local)
    provider_script="${ROOT}/engine/local_echo.sh"
    ;;
  claude)
    provider_script="${ROOT}/engine/claude.sh"
    ;;
  zai)
    provider_script="${ROOT}/engine/zai.sh"
    ;;
  openai)
    provider_script="${ROOT}/engine/openai.sh"
    ;;
  *)
    echo "FAIL: unknown provider: ${provider}"
    exit 1
    ;;
esac

[[ -x "${provider_script}" ]] || { echo "FAIL: engine script missing or not executable: ${provider_script}"; exit 1; }

provider_requested="${provider}"
provider_used=""
provider_error=""
output=""

if [[ "${provider}" == "openai" ]]; then
  if output="$("${provider_script}" "${run_id}" 2>&1)"; then
    provider_used="openai"
  else
    provider_error="${output}"
    provider_used="claude"
    echo "[engine] OpenAI provider failed; falling back to Anthropic" >&2
    output="$("${ROOT}/engine/claude.sh" "${run_id}" 2>&1)"
  fi
else
  provider_used="${provider}"
  output="$("${provider_script}" "${run_id}" 2>&1)"
fi

printf 'PROVIDER_REQUESTED=%s\n' "${provider_requested}"
printf 'PROVIDER_USED=%s\n' "${provider_used}"
[[ -n "${provider_error}" ]] && printf 'PROVIDER_ERROR=%s\n' "${provider_error}"
printf '%s\n' "${output}"
