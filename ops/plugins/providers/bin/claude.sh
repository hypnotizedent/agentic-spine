#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${ROOT}/runs"

usage() {
  cat <<EOF
Usage: $0 <RUN_ID>

Calls Anthropic Messages API using the active provider orchestration selection.
EOF
  exit 1
}

run_id="${1:-}"
[[ -n "${run_id}" ]] || usage

run_dir="${RUNS}/${run_id}"
request_file="${run_dir}/request.txt"
result_file="${run_dir}/result.txt"
response_file="${run_dir}/claude_response.json"

[[ -f "${request_file}" ]] || { echo "FAIL: missing request file: ${request_file}" >&2; exit 1; }

key="${ANTHROPIC_API_KEY:-}"
[[ -n "${key}" ]] || { echo "FAIL: ANTHROPIC_API_KEY is not set" >&2; exit 1; }

base="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
endpoint="${base%/}${SPINE_PROVIDER_CHAT_PATH:-/v1/messages}"
model="${SPINE_CLAUDE_MODEL:-${SPINE_PROVIDER_MODEL:-claude-sonnet-4-5-20250929}}"
max_tokens="${SPINE_ENGINE_MAX_TOKENS:-200}"

payload="$(SPINE_CLAUDE_MODEL="$model" SPINE_ENGINE_MAX_TOKENS="$max_tokens" python3 - "${request_file}" <<'PY'
import json, os, sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    request = fh.read().strip()

try:
    max_tokens = int(os.environ.get("SPINE_ENGINE_MAX_TOKENS", "200"))
except ValueError:
    max_tokens = 200

data = {
    "model": os.environ.get("SPINE_CLAUDE_MODEL", "claude-sonnet-4-5-20250929"),
    "max_tokens": max_tokens,
    "temperature": 0,
    "system": "You are a concise, deterministic assistant.",
    "messages": [{"role": "user", "content": request}],
}
print(json.dumps(data))
PY
)"

http_code="$(
  curl -sS -o "${response_file}" -w "%{http_code}" \
    -H "x-api-key: ${key}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
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
msg = payload.get("error", {}).get("message") if isinstance(payload.get("error"), dict) else None
if msg:
    print(msg)
else:
    print("<non-200 HTTP response>")
PY
)"
  echo "FAIL: anthropic returned HTTP ${http_code}: ${err_msg}" >&2
  exit 1
fi

python3 - "${response_file}" "${result_file}" <<'PY'
import json, sys

resp_path, out_path = sys.argv[1], sys.argv[2]
with open(resp_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

parts = []
for item in data.get("content", []) or []:
    if isinstance(item, dict) and item.get("type") == "text":
        parts.append(str(item.get("text", "")))
content = "\n".join(parts)

with open(out_path, "w", encoding="utf-8") as out_f:
    out_f.write(content.strip() + "\n")

usage = data.get("usage", {}) or {}
def emit(name, value):
    if isinstance(value, int):
        print(f"{name}={value}")

emit("USAGE_INPUT_TOKENS", usage.get("input_tokens"))
emit("USAGE_OUTPUT_TOKENS", usage.get("output_tokens"))
PY

echo "RESULT=${result_file}"
