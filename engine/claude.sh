#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${ROOT}/runs"

usage() {
  cat <<EOF
Usage: $0 <RUN_ID>

Simulates the Claude provider by reading runs/<RUN_ID>/request.txt, wrapping
the request in a short acknowledgment, and writing the text back to
runs/<RUN_ID>/result.txt for downstream verification.
EOF
  exit 1
}

run_id="${1:-}"
[[ -n "${run_id}" ]] || usage

run_dir="${RUNS}/${run_id}"
request_file="${run_dir}/request.txt"
result_file="${run_dir}/result.txt"

if [[ ! -f "${request_file}" ]]; then
  echo "FAIL: missing request file: ${request_file}"
  exit 1
fi

mkdir -p "${run_dir}"
{
  echo "CLAUDE SIMULATED RESPONSE"
  cat "${request_file}"
} >"${result_file}"

chmod 644 "${result_file}"
echo "RESULT=${result_file}"
