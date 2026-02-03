#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${ROOT}/runs"

usage() {
  cat <<'EOF'
Usage: zai.sh <RUN_ID>

Calls z.ai via either the official z.ai endpoint (when ZAI_API_KEY is set)
or any OpenAI-compatible host when only OPENAI_API_KEY/base variables are present.
EOF
  exit 1
}

run_id="${1:-}"
[[ -n "${run_id}" ]] || usage

run_dir="${RUNS}/${run_id}"
request_file="${run_dir}/request.txt"
result_file="${run_dir}/result.txt"
response_file="${run_dir}/zai_response.json"

[[ -f "${request_file}" ]] || { echo "FAIL: missing request file: ${request_file}" >&2; exit 1; }

key="${ZAI_API_KEY:-}"
[[ -n "${key}" ]] || { echo "FAIL: ZAI_API_KEY is required for the z.ai provider" >&2; exit 1; }
endpoint="https://api.z.ai/api/paas/v4/chat/completions"

payload="$(python3 - "${request_file}" <<'PY'
import json, sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    request = fh.read().strip()

data = {
    "model": "zai-coding-plan/glm-4.7",
    "temperature": 0,
    "max_tokens": 200,
    "messages": [
        {"role": "system", "content": "You are a concise, deterministic assistant."},
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
  echo "FAIL: z.ai(OpenAI-compatible) returned HTTP ${http_code}: ${err_msg}" >&2
  exit 1
fi

python3 - "${response_file}" "${result_file}" <<'PY'
import json, sys

resp_path, out_path = sys.argv[1], sys.argv[2]
with open(resp_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

choices = data.get("choices", [])
if not choices:
    raise SystemExit("FAIL: z.ai response missing choices")

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
