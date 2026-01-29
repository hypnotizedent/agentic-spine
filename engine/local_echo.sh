#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${ROOT}/runs"

usage() {
  cat <<USAGE
Usage: $0 <RUN_ID>

Reads \`runs/<RUN_ID>/request.txt\` and echoes the same content into
\`runs/<RUN_ID>/result.txt\` so the local engine mirrors the request.
USAGE
  exit 1
}

run_id="${1:-}"
[[ -n "${run_id}" ]] || usage

run_dir="${RUNS}/${run_id}"
request_file="${run_dir}/request.txt"
result_file="${run_dir}/result.txt"

[[ -f "${request_file}" ]] || { echo "FAIL: missing request file: ${request_file}"; exit 1; }

mkdir -p "${run_dir}"
cat "${request_file}" > "${result_file}"
chmod 644 "${result_file}"

echo "${result_file}"
