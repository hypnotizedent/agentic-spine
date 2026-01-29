#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${ROOT}/runs"

usage() {
  cat <<EOF
Usage: $0 <RUN_ID>

Calls the z.ai API (glm-4.7) with the contents of runs/<RUN_ID>/request.txt,
writes the response to runs/<RUN_ID>/result.txt, and emits result & usage
metadata for the caller. ZAI_API_KEY must already be exported (e.g.
source ~/ronny-ops/scripts/load-secrets.sh).
EOF
  exit 1
}

run_id="${1:-}"
[[ -n "${run_id}" ]] || usage

run_dir="${RUNS}/${run_id}"
request_file="${run_dir}/request.txt"
result_file="${run_dir}/result.txt"

[[ -f "${request_file}" ]] || { echo "FAIL: missing request file: ${request_file}"; exit 1; }
[[ -n "${ZAI_API_KEY:-}" ]] || { echo "FAIL: ZAI_API_KEY is not set; source ~/ronny-ops/scripts/load-secrets.sh" >&2; exit 1; }

payload=$(python3 - "$request_file" <<'PY'
import json, sys

with open(sys.argv[1], encoding="utf-8") as fh:
    request = fh.read()

payload = {
    "model": "glm-4.7",
    "messages": [
        {
            "role": "system",
            "content": "You are a deterministic task runner that answers literally and concisely."
        },
        {"role": "user", "content": request}
    ],
    "temperature": 0,
    "max_tokens": 400,
    "top_p": 1,
    "presence_penalty": 0,
    "frequency_penalty": 0
}
print(json.dumps(payload))
PY
)

response_file="$(mktemp)"
trap 'rm -f "${response_file}"' EXIT

curl -sS -X POST \
  -H "Authorization: Bearer ${ZAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data-binary "${payload}" \
  "https://api.z.ai/api/paas/v4/chat/completions" >"${response_file}"

python3 - "${response_file}" "${result_file}" <<'PY'
import json, sys

response_path = sys.argv[1]
result_path = sys.argv[2]

with open(response_path, encoding="utf-8") as fh:
    data = json.load(fh)

if "error" in data:
    error = data["error"]
    message = error.get("message", "(no message)")
    raise SystemExit(f"FAIL: z.ai reported an error: {message}")

choices = data.get("choices", [])
if not choices:
    raise SystemExit("FAIL: z.ai response missing choices")

message = choices[0].get("message", {}).get("content", "")
if not message:
    raise SystemExit("FAIL: z.ai returned an empty response")

if not message.endswith("\n"):
    message += "\n"

with open(result_path, "w", encoding="utf-8") as out:
    out.write(message)

usage = data.get("usage", {})
print(f"RESULT={result_path}")
if usage:
    total = usage.get("total_tokens")
    if total is not None:
        print(f"USAGE_TOTAL_TOKENS={total}")
    prompt = usage.get("prompt_tokens")
    if prompt is not None:
        print(f"USAGE_PROMPT_TOKENS={prompt}")
    completion = usage.get("completion_tokens")
    if completion is not None:
        print(f"USAGE_COMPLETION_TOKENS={completion}")
PY
