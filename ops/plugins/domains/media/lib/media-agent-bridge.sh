#!/usr/bin/env bash
# media-agent-bridge.sh — Thin MCP bridge for spine→workbench media-agent tool calls
# Source this file, then call: media_agent_call <tool_name> <arguments_json>
#
# Environment:
#   MEDIA_AGENT_LAUNCHER — override path to workbench media-agent run.sh
#   MEDIA_AGENT_TIMEOUT  — override call timeout in seconds (default: 90)

MEDIA_AGENT_LAUNCHER="${MEDIA_AGENT_LAUNCHER:-/Users/ronnyworks/code/workbench/agents/media/tools/run.sh}"
MEDIA_AGENT_TIMEOUT="${MEDIA_AGENT_TIMEOUT:-90}"

media_agent_call() {
  local tool_name="$1"
  local arguments_json="$2"
  [[ -z "$arguments_json" ]] && arguments_json='{}'

  if [[ ! -x "$MEDIA_AGENT_LAUNCHER" ]]; then
    echo "BRIDGE_FAIL: launcher missing or not executable: $MEDIA_AGENT_LAUNCHER" >&2
    return 1
  fi

  python3 - "$tool_name" "$arguments_json" "$MEDIA_AGENT_LAUNCHER" "$MEDIA_AGENT_TIMEOUT" <<'PYEOF'
import sys, json, re, subprocess

tool_name = sys.argv[1]
try:
    arguments = json.loads(sys.argv[2])
except json.JSONDecodeError:
    print(json.dumps({"bridge_error": True, "message": "invalid arguments JSON"}))
    sys.exit(1)
launcher = sys.argv[3]
timeout = int(sys.argv[4])

messages = "\n".join([
    json.dumps({"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"spine-bridge","version":"1.0.0"}},"id":0}),
    json.dumps({"jsonrpc":"2.0","method":"notifications/initialized"}),
    json.dumps({"jsonrpc":"2.0","method":"tools/call","params":{"name":tool_name,"arguments":arguments},"id":1}),
])

try:
    proc = subprocess.run([launcher], input=messages, capture_output=True, text=True, timeout=timeout)
except FileNotFoundError:
    print(json.dumps({"bridge_error": True, "message": f"launcher not found: {launcher}"}))
    sys.exit(1)
except subprocess.TimeoutExpired:
    print(json.dumps({"bridge_error": True, "message": f"launcher timed out after {timeout}s"}))
    sys.exit(1)

data = proc.stdout
if not data:
    stderr_tail = (proc.stderr or "")[-500:]
    print(json.dumps({"bridge_error": True, "message": f"no output (exit={proc.returncode})", "stderr": stderr_tail}))
    sys.exit(1)

parts = re.split(r'Content-Length:\s*\d+\r?\n\r?\n', data)
for part in parts:
    part = part.strip()
    if not part:
        continue
    # Handle potential trailing data after JSON
    brace_depth = 0
    end = 0
    for i, ch in enumerate(part):
        if ch == '{': brace_depth += 1
        elif ch == '}': brace_depth -= 1
        if brace_depth == 0 and i > 0:
            end = i + 1
            break
    if end > 0:
        part = part[:end]
    try:
        obj = json.loads(part)
    except json.JSONDecodeError:
        continue
    if obj.get('id') != 1:
        continue
    if 'error' in obj:
        err = obj['error']
        print(json.dumps({"bridge_error": True, "code": err.get("code"), "message": err.get("message", "unknown")}))
        sys.exit(1)
    result = obj.get('result', {})
    is_error = result.get('isError', False)
    content = result.get('content', [])
    text_parts = []
    for item in content:
        if item.get('type') == 'text':
            text_parts.append(item.get('text', ''))
    text = "\n".join(text_parts)
    if is_error:
        print(json.dumps({"bridge_error": True, "tool_error": True, "message": text}))
        sys.exit(1)
    print(text)
    sys.exit(0)

print(json.dumps({"bridge_error": True, "message": "no response with id=1 in output"}))
sys.exit(1)
PYEOF
}
