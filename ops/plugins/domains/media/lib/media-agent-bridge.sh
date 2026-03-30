#!/usr/bin/env bash
# media-agent-bridge.sh — Thin MCP bridge for spine→workbench media-agent tool calls
# Source this file, then call: media_agent_call <tool_name> <arguments_json>
#
# Environment:
#   MEDIA_AGENT_LAUNCHER — override path to workbench media-agent run.sh
#   MEDIA_AGENT_TIMEOUT  — override call timeout in seconds (default: 90)

MEDIA_AGENT_LAUNCHER="${MEDIA_AGENT_LAUNCHER:-/Users/ronnyworks/code/workbench/agents/media/tools/run.sh}"
MEDIA_AGENT_TIMEOUT="${MEDIA_AGENT_TIMEOUT:-90}"

# Governed bridge context: allows mutating tools through the MCP governance gate.
# Only the spine bridge helper sets this; ad hoc MCP callers remain blocked.
export SPINE_GOVERNED_BRIDGE=1

# Media-home Tailscale IP fallback for spine→workbench bridge calls.
# The MCP server defaults to LAN 10.0.0.106 which is unreachable from
# the Mac. Export Tailscale IPs only if not already set.
export RADARR_URL="${RADARR_URL:-http://100.113.72.41:7878}"
export SONARR_URL="${SONARR_URL:-http://100.113.72.41:8989}"
export LIDARR_URL="${LIDARR_URL:-http://100.113.72.41:8686}"

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

msgs = [
    json.dumps({"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"spine-bridge","version":"1.0.0"}},"id":0}),
    json.dumps({"jsonrpc":"2.0","method":"notifications/initialized"}),
    json.dumps({"jsonrpc":"2.0","method":"tools/call","params":{"name":tool_name,"arguments":arguments},"id":1}),
]

import threading, time

try:
    proc = subprocess.Popen([launcher], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
except FileNotFoundError:
    print(json.dumps({"bridge_error": True, "message": f"launcher not found: {launcher}"}))
    sys.exit(1)

collected = {"stdout": "", "stderr": ""}

def read_stdout():
    collected["stdout"] = proc.stdout.read()

def read_stderr():
    collected["stderr"] = proc.stderr.read()

t_out = threading.Thread(target=read_stdout, daemon=True)
t_err = threading.Thread(target=read_stderr, daemon=True)
t_out.start()
t_err.start()

try:
    for msg in msgs:
        proc.stdin.write(msg + "\n")
        proc.stdin.flush()
        time.sleep(0.05)
    # Give server time to process tools/call before closing stdin
    time.sleep(1.0)
    proc.stdin.close()
    proc.wait(timeout=timeout)
except subprocess.TimeoutExpired:
    proc.kill()
    print(json.dumps({"bridge_error": True, "message": f"launcher timed out after {timeout}s"}))
    sys.exit(1)
except BrokenPipeError:
    pass

t_out.join(timeout=5)
t_err.join(timeout=5)

data = collected["stdout"]
if not data:
    stderr_tail = collected["stderr"][-500:]
    print(json.dumps({"bridge_error": True, "message": f"no output (exit={proc.returncode})", "stderr": stderr_tail}))
    sys.exit(1)

def extract_response(obj):
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

# Strategy 1: line-delimited JSON (most MCP servers)
for line in data.split('\n'):
    line = line.strip()
    if not line or not line.startswith('{'):
        continue
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        continue
    if obj.get('id') == 1:
        extract_response(obj)

# Strategy 2: Content-Length framing (LSP-style)
parts = re.split(r'Content-Length:\s*\d+\r?\n\r?\n', data)
for part in parts:
    part = part.strip()
    if not part:
        continue
    brace_depth = 0
    end = 0
    for i, ch in enumerate(part):
        if ch == '{':
            brace_depth += 1
        elif ch == '}':
            brace_depth -= 1
        if brace_depth == 0 and i > 0:
            end = i + 1
            break
    if end > 0:
        part = part[:end]
    try:
        obj = json.loads(part)
    except json.JSONDecodeError:
        continue
    if obj.get('id') == 1:
        extract_response(obj)

print(json.dumps({"bridge_error": True, "message": "no response with id=1 in output"}))
sys.exit(1)
PYEOF
}
