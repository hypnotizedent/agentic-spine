#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${ROOT}/runs"

usage() {
  cat <<EOF
Usage: openai.sh <RUN_ID>

Calls an OpenAI-compatible chat completions endpoint using the active provider
selection from provider orchestration.
EOF
  exit 1
}

run_id="${1:-}"
[[ -n "${run_id}" ]] || usage

run_dir="${RUNS}/${run_id}"
request_file="${run_dir}/request.txt"
result_file="${run_dir}/result.txt"
response_file="${run_dir}/provider_response.json"

[[ -f "${request_file}" ]] || { echo "FAIL: missing request file: ${request_file}" >&2; exit 1; }

key="${OPENAI_API_KEY:-}"
allow_anon="${SPINE_PROVIDER_ALLOW_ANON:-0}"
[[ -n "${key}" || "${allow_anon}" == "1" ]] || { echo "FAIL: OPENAI_API_KEY is not set" >&2; exit 1; }

base="${OPENAI_BASE_URL:-${OPENAI_API_BASE:-https://api.openai.com/v1}}"
chat_path="${SPINE_PROVIDER_CHAT_PATH:-/chat/completions}"
endpoint="${base%/}${chat_path}"
model="${SPINE_PROVIDER_MODEL:-${SPINE_ENGINE_MODEL:-gpt-4.1-mini}}"
max_tokens="${SPINE_ENGINE_MAX_TOKENS:-200}"

payload="$(SPINE_PROVIDER_MODEL="$model" SPINE_ENGINE_MAX_TOKENS="$max_tokens" python3 - "${request_file}" <<'PY'
import json, os, sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    request = fh.read().strip()

try:
    max_tokens = int(os.environ.get("SPINE_ENGINE_MAX_TOKENS", "200"))
except ValueError:
    max_tokens = 200

data = {
    "model": os.environ.get("SPINE_PROVIDER_MODEL", "gpt-4.1-mini"),
    "temperature": 0,
    "max_tokens": max_tokens,
    "messages": [
        {"role": "system", "content": "You are a concise, deterministic assistant."},
        {"role": "user", "content": request},
    ],
}
print(json.dumps(data))
PY
)"

declare -a header_args
header_args=(-H "Content-Type: application/json")
if [[ -n "${key}" ]]; then
  header_args+=(-H "Authorization: Bearer ${key}")
fi
if [[ -n "${SPINE_PROVIDER_EXTRA_HEADERS_JSON:-}" ]]; then
  while IFS= read -r line; do
    [[ -n "${line}" ]] && header_args+=(-H "$line")
  done < <(python3 - <<'PY'
import json, os
for key, value in json.loads(os.environ.get("SPINE_PROVIDER_EXTRA_HEADERS_JSON", "{}") or "{}").items():
    print(f"{key}: {value}")
PY
)
fi

http_code="$(
  curl -sS -o "${response_file}" -w "%{http_code}" \
    "${header_args[@]}" \
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
  echo "FAIL: provider returned HTTP ${http_code}: ${err_msg}" >&2
  exit 1
fi

python3 - "${response_file}" "${result_file}" <<'PY'
import json, sys

resp_path, out_path = sys.argv[1], sys.argv[2]
with open(resp_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

choices = data.get("choices", [])
if not choices:
    raise SystemExit("FAIL: response missing choices")

message = choices[0].get("message", {}) or {}
content = message.get("content", "")
if isinstance(content, list):
    parts = []
    for item in content:
        if isinstance(item, dict) and item.get("type") == "text":
            parts.append(str(item.get("text", "")))
    content = "\n".join(parts)

with open(out_path, "w", encoding="utf-8") as out_f:
    out_f.write(str(content).strip() + "\n")

usage = data.get("usage", {}) or {}
def emit(name, value):
    if isinstance(value, int):
        print(f"{name}={value}")

emit("USAGE_INPUT_TOKENS", usage.get("prompt_tokens"))
emit("USAGE_OUTPUT_TOKENS", usage.get("completion_tokens"))
emit("USAGE_TOTAL_TOKENS", usage.get("total_tokens"))
PY

echo "RESULT=${result_file}"
