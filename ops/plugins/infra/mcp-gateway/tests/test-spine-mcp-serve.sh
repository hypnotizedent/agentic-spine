#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "${ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
BIN="$ROOT/ops/plugins/infra/mcp-gateway/bin/spine-mcp-serve"

python3 - <<'PY' "$BIN"
import importlib.machinery
import importlib.util
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
loader = importlib.machinery.SourceFileLoader("spine_mcp_serve", str(path))
spec = importlib.util.spec_from_loader("spine_mcp_serve", loader)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

small = "Run Key: R1\nReceipt: /tmp/r1\nok"
assert module._bounded_cap_output(small, "", full_output=False, max_chars=300) == small

large = "Run Key: RK\nReceipt: /tmp/receipt.md\nOutput: /tmp/output.txt\n" + ("x" * 500)
bounded = module._bounded_cap_output(large, "", full_output=False, max_chars=240)
assert "Run Key: RK" in bounded
assert "Receipt: /tmp/receipt.md" in bounded
assert "Output: /tmp/output.txt" in bounded
assert "truncated interactive cap_run output at 240 chars" in bounded

full = module._bounded_cap_output(large, "", full_output=True, max_chars=240)
assert full == large

module.load_capabilities = lambda: {"demo.cap": {"approval": "auto"}}
module.run_cmd = lambda args, stdin_text=None, timeout=600: (0, large, "")
default_out = module.run_capability("demo.cap", [], False, full_output=False, max_chars=220)
assert "truncated interactive cap_run output at 220 chars" in default_out

full_out = module.run_capability("demo.cap", [], False, full_output=True, max_chars=220)
assert full_out == large

bad_bool = module.handle_tools_call(
    {
        "jsonrpc": "2.0",
        "id": 1,
        "params": {"name": "cap_run", "arguments": {"name": "demo.cap", "full_output": "yes"}},
    }
)
assert bad_bool["result"]["isError"] is True
assert "full_output must be a boolean" in bad_bool["result"]["content"][0]["text"]

bad_int = module.handle_tools_call(
    {
        "jsonrpc": "2.0",
        "id": 2,
        "params": {"name": "cap_run", "arguments": {"name": "demo.cap", "max_chars": "big"}},
    }
)
assert bad_int["result"]["isError"] is True
assert "max_chars must be an integer" in bad_int["result"]["content"][0]["text"]

print("spine-mcp-serve tests")
PY
