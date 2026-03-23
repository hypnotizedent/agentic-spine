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

python3 - <<'PY' "$BIN"
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

bin_path = pathlib.Path(sys.argv[1])
root = bin_path.parents[4]

tmpdir = pathlib.Path(tempfile.mkdtemp(prefix="spine-mcp-live-"))
state_root = tmpdir / "state"
receipt_root = tmpdir / "receipts"
gaps_file = tmpdir / "operational.gaps.yaml"
run_key = "CAP-20260323-150000__verify.run__Rthinclient"
loop_id = "LOOP-TEST-MCP-PARITY-20260323"

try:
    (state_root / "loop-scopes").mkdir(parents=True, exist_ok=True)
    (receipt_root / f"R{run_key}").mkdir(parents=True, exist_ok=True)

    (state_root / "loop-scopes" / f"{loop_id}.scope.md").write_text(
        f"""---
loop_id: {loop_id}
created: 2026-03-23
status: active
owner: "@ronny"
scope: spine
priority: high
objective: Validate MCP thin-client parity.
---

# Loop Scope: {loop_id}
""",
        encoding="utf-8",
    )

    gaps_file.write_text(
        f"""gaps:
  - id: GAP-OP-TEST-MCP-1
    status: open
    severity: medium
    parent_loop: {loop_id}
    description: MCP parity progress should show this gap.
""",
        encoding="utf-8",
    )

    (receipt_root / f"R{run_key}" / "receipt.attestation.json").write_text(
        json.dumps(
            {
                "schema_version": "1.0",
                "request_id": run_key,
                "capability": "verify.run",
                "generated_at_utc": "2026-03-23T15:00:00Z",
                "loop_id": loop_id,
                "entry_packet_path": "",
                "entry_packet_hash": "none",
                "governance_version": "SPINE.md@2026-03-23",
                "execution_host": "Mac",
                "execution_mode": "capability",
                "runtime_role": "worker",
                "checks_passed": ["receipt_attestation_present"],
                "checks_failed": [],
                "receipts": {},
                "evidence_refs": {},
                "prompt_lineage": {},
                "verdict": "done",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    env = os.environ.copy()
    env["SPINE_ROOT"] = "/Users/ronnyworks/.wt/agentic-spine/control-plane"
    env["SPINE_STATE"] = str(state_root)
    env["SPINE_RECEIPTS"] = str(receipt_root)
    env["SPINE_GAPS_FILE"] = str(gaps_file)

    proc = subprocess.Popen(
        [str(bin_path)],
        cwd=str(root),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
    )

    def send(msg):
        proc.stdin.write(json.dumps(msg) + "\n")
        proc.stdin.flush()
        line = proc.stdout.readline()
        assert line, proc.stderr.read()
        return json.loads(line)

    init = send(
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "spine-mcp-test", "version": "1.0"},
            },
        }
    )
    assert init["result"]["serverInfo"]["name"] == "spine-mcp-gateway"

    proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}}) + "\n")
    proc.stdin.flush()

    tools = send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
    tool_names = {tool["name"] for tool in tools["result"]["tools"]}
    assert {
        "get_latest_loop",
        "get_loop_status",
        "get_loop_progress",
        "get_request_attestation",
    }.issubset(tool_names)

    latest = send(
        {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {"name": "get_latest_loop", "arguments": {}},
        }
    )
    latest_payload = json.loads(latest["result"]["content"][0]["text"])
    assert latest_payload["status"] == "done"
    assert latest_payload["data"]["loop"]["loop_id"] == loop_id

    status = send(
        {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": {"name": "get_loop_status", "arguments": {"loop_id": loop_id}},
        }
    )
    status_payload = json.loads(status["result"]["content"][0]["text"])
    assert status_payload["data"]["loop"]["status"] == "active"

    progress = send(
        {
            "jsonrpc": "2.0",
            "id": 5,
            "method": "tools/call",
            "params": {"name": "get_loop_progress", "arguments": {"loop_id": loop_id}},
        }
    )
    progress_payload = json.loads(progress["result"]["content"][0]["text"])
    assert progress_payload["data"]["progress"]["open_gaps"] == 1

    att = send(
        {
            "jsonrpc": "2.0",
            "id": 6,
            "method": "tools/call",
            "params": {"name": "get_request_attestation", "arguments": {"request_id": run_key}},
        }
    )
    att_payload = json.loads(att["result"]["content"][0]["text"])
    assert att_payload["data"]["attestation"]["request_id"] == run_key
    assert att_payload["data"]["attestation"]["verdict"] == "done"

    proc.terminate()
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        proc.kill()
        raise

    print("spine-mcp-serve broker tools with stale env")
finally:
    shutil.rmtree(tmpdir)
PY
