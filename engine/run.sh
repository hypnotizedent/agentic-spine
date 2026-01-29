#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${ROOT}/runs"

usage() {
  cat <<EOF
Usage: $0 <RUN_ID>

Selects an engine provider (local|claude|openai) via \$SPINE_ENGINE_PROVIDER
and executes the provider script with <RUN_ID>.

Defaults to 'local' and currently only the local provider is implemented.
EOF
  exit 1
}

run_id="${1:-}"
[[ -n "${run_id}" ]] || usage

provider="${SPINE_ENGINE_PROVIDER:-local}"

case "${provider}" in
  local)
    provider_script="${ROOT}/engine/local_echo.sh"
    ;;
  claude)
    provider_script="${ROOT}/engine/claude.sh"
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

"${provider_script}" "${run_id}"
