#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${ROOT}/runs"
STATUS_BIN="${ROOT}/plugins/providers/bin/providers-status"
ENV_BIN="${ROOT}/plugins/providers/bin/providers-launch-env"

usage() {
  cat <<EOF
Usage: $0 <RUN_ID>

Selects an engine provider via \$SPINE_ENGINE_PROVIDER and executes the matching
provider script with <RUN_ID>.

Provider selection:
  - auto (default): use the configured spine engine chain and fall through on runtime failures
  - openai | zai | anthropic | local_lmstudio | local_echo
Legacy aliases kept for compatibility:
  - claude -> anthropic
  - local  -> local_echo
EOF
  exit 1
}

run_id="${1:-}"
[[ -n "${run_id}" ]] || usage
[[ -x "${STATUS_BIN}" ]] || { echo "FAIL: provider status script missing: ${STATUS_BIN}" >&2; exit 1; }
[[ -x "${ENV_BIN}" ]] || { echo "FAIL: provider env script missing: ${ENV_BIN}" >&2; exit 1; }

provider_requested="${SPINE_ENGINE_PROVIDER:-auto}"
status_json="$(${STATUS_BIN} --surface spine_engine --provider "${provider_requested}" --json)"
mapfile -t ready_candidates < <(printf '%s\n' "${status_json}" | jq -r '.candidates[] | select(.ready == true) | .id')

if [[ "${#ready_candidates[@]}" -eq 0 ]]; then
  checked="$(printf '%s\n' "${status_json}" | jq -r '[.candidates[].id] | join(",")')"
  echo "FAIL: no ready providers for spine_engine (requested=${provider_requested}, checked=${checked:-<none>})" >&2
  exit 1
fi

provider_used=""
output=""
last_error=""

for candidate in "${ready_candidates[@]}"; do
  eval "$(${ENV_BIN} --tool spine_engine --provider "${candidate}")"

  case "${SPINE_PROVIDER_BACKEND:-}" in
    openai_compatible)
      provider_script="${ROOT}/engine/openai.sh"
      ;;
    anthropic)
      provider_script="${ROOT}/engine/claude.sh"
      ;;
    local_echo)
      provider_script="${ROOT}/engine/local_echo.sh"
      ;;
    *)
      echo "FAIL: unsupported engine backend for provider ${candidate}: ${SPINE_PROVIDER_BACKEND:-unknown}" >&2
      exit 1
      ;;
  esac

  [[ -x "${provider_script}" ]] || { echo "FAIL: engine script missing or not executable: ${provider_script}" >&2; exit 1; }

  if output="$(${provider_script} "${run_id}" 2>&1)"; then
    provider_used="${candidate}"
    break
  fi

  last_error="${output}"
  echo "WARN: provider ${candidate} failed, trying next candidate" >&2
  echo "WARN: ${output}" >&2
  unset SPINE_PROVIDER_SELECTED SPINE_PROVIDER_MODEL SPINE_PROVIDER_BACKEND OPENAI_API_KEY OPENAI_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_BASE_URL SPINE_PROVIDER_EXTRA_HEADERS_JSON SPINE_PROVIDER_ALLOW_ANON || true
  output=""
done

if [[ -z "${provider_used}" ]]; then
  echo "${last_error}" >&2
  exit 1
fi

printf 'PROVIDER_REQUESTED=%s\n' "${provider_requested}"
printf 'PROVIDER_USED=%s\n' "${provider_used}"
printf 'PROVIDER_MODEL=%s\n' "${SPINE_PROVIDER_MODEL:-unknown}"
printf '%s\n' "${output}"
