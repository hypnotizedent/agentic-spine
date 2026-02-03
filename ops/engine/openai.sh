#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${ROOT}/runs"

usage() {
  cat <<EOF
Usage: openai.sh <RUN_ID>

Calls the OpenAI chat completions API with model zai-coding-plan/glm-4.7,
temperature 0, and max_tokens 200. The request text comes from
runs/<RUN_ID>/request.txt. It prints RESULT=<path> plus optional USAGE_*
lines to let the caller track token usage.
EOF
  exit 1
}

run_id="${1:-}"
[[ -n "${run_id}" ]] || usage

run_dir="${RUNS}/${run_id}"
request_file="${run_dir}/request.txt"
result_file="${run_dir}/result.txt"
response_file="${run_dir}/openai_response.json"

[[ -f "${request_file}" ]] || { echo "FAIL: missing request file: ${request_file}" >&2; exit 1; }

key="${OPENAI_API_KEY:-}"
[[ -n "${key}" ]] || { echo "FAIL: OPENAI_API_KEY is not set" >&2; exit 1; }

base="${OPENAI_BASE_URL:-${OPENAI_API_BASE:-https://api.openai.com/v1}}"
endpoint="${base%/}/chat/completions"

payload="$(python3 - "${request_file}" <<'PY'
import json, sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    request = fh.read().strip()

data = {
    "model": "gpt-4o-mini",
    "temperature": 0,
    "max_tokens": 200,
    "messages": [
        {"role": "system", "content": "You are a concise assistant that obeys instructions literally."},
        {"role": "user", "content": request}
    ],
}
print(json.dumps(data))
PY
)"

http_code="$(
  curl -sS -o "${response_file}" -w "%{http_code}" \
    -H "Authorization: Bearer ${key}" \
    -H "Content-Type: application/json" \
    --data-binary "${payload}" \
    "${endpoint}" || true
)"

if [[ "${http_code}" != "200" ]]; then
  err_msg="$(python3 - "${response_file}" <<'PY'
import json, sys

path = sys.argv[1]
try:
    payload = json.load(open(path, "r", encoding="utf-8"))
except Exception as exc:
    raise SystemExit(f"<non-JSON: {exc}>")

msg = payload.get("error", {}).get("message")
if msg:
    print(msg)
else:
    print("<non-200 HTTP response>")
PY
)"
  echo "FAIL: openai returned HTTP ${http_code}: ${err_msg}" >&2
  exit 1
fi

python3 - "${response_file}" "${result_file}" <<'PY'
import json, sys

resp_path, out_path = sys.argv[1], sys.argv[2]
with open(resp_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

choices = data.get("choices", [])
if not choices:
    raise SystemExit("FAIL: openai response missing choices")

content = choices[0].get("message", {}).get("content", "")
with open(out_path, "w", encoding="utf-8") as out_f:
    out_f.write(content.strip() + "\n")

usage = data.get("usage", {}) or {}
def emit(name, value):
    if isinstance(value, int):
        print(f"{name}={value}")

emit("USAGE_INPUT_TOKENS", usage.get("prompt_tokens"))
emit("USAGE_OUTPUT_TOKENS", usage.get("completion_tokens"))
emit("USAGE_TOTAL_TOKENS", usage.get("total_tokens"))
PY

echo "RESULT=${result_file}"
