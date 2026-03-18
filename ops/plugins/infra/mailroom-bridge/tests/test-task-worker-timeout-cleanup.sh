#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
WORKER_BIN="$ROOT/ops/plugins/infra/mailroom-bridge/bin/mailroom-task-worker"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "python3 required"
[[ -f "$WORKER_BIN" ]] || fail "mailroom task worker missing"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat >"$tmp/bin/ops" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
child_pid_file="${FAKE_CHILD_PID_FILE:?}"
(
  sleep 30
) &
child="$!"
echo "$child" >"$child_pid_file"
wait "$child"
SH
chmod +x "$tmp/bin/ops"

cat >"$tmp/fake-command" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
child_pid_file="${FAKE_DIRECT_CHILD_PID_FILE:?}"
(
  sleep 30
) &
child="$!"
echo "$child" >"$child_pid_file"
wait "$child"
SH
chmod +x "$tmp/fake-command"

result_json="$(WORKER_BIN_PATH="$WORKER_BIN" TEST_ROOT="$tmp" python3 - <<'PY'
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import time

worker_path = pathlib.Path(os.environ["WORKER_BIN_PATH"])
tmp_root = pathlib.Path(os.environ["TEST_ROOT"])
loader = importlib.machinery.SourceFileLoader("mailroom_task_worker_module", str(worker_path))
spec = importlib.util.spec_from_loader("mailroom_task_worker_module", loader)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)
module.ROOT = tmp_root

child_pid_file = tmp_root / "cap-child.pid"
direct_child_pid_file = tmp_root / "direct-child.pid"
env = os.environ.copy()
env["FAKE_CHILD_PID_FILE"] = str(child_pid_file)
env["FAKE_DIRECT_CHILD_PID_FILE"] = str(direct_child_pid_file)
os.environ["FAKE_CHILD_PID_FILE"] = str(child_pid_file)
os.environ["FAKE_DIRECT_CHILD_PID_FILE"] = str(direct_child_pid_file)

cap_result = module.run_ops_cap("spine.control.cycle", ["--json"], timeout=1)
time.sleep(0.5)
cap_child = int(child_pid_file.read_text(encoding="utf-8").strip())
cap_alive = os.system(f"kill -0 {cap_child} >/dev/null 2>&1") == 0

direct_result = module.run_command([str(tmp_root / "fake-command")], env=env, timeout=1)
time.sleep(0.5)
direct_child = int(direct_child_pid_file.read_text(encoding="utf-8").strip())
direct_alive = os.system(f"kill -0 {direct_child} >/dev/null 2>&1") == 0

print(json.dumps({
    "cap_result": cap_result,
    "cap_child_alive": cap_alive,
    "direct_result": direct_result,
    "direct_child_alive": direct_alive,
}))
PY
)"

echo "$result_json" | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["cap_result"]["timed_out"] is True; assert payload["cap_result"]["exit_code"] == 124; assert payload["cap_child_alive"] is False'
pass "run_ops_cap kills timed-out subprocess groups"

echo "$result_json" | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["direct_result"]["timed_out"] is True; assert payload["direct_result"]["exit_code"] == 124; assert payload["direct_child_alive"] is False'
pass "run_command kills timed-out subprocess groups"

echo "mailroom task worker timeout cleanup tests"
