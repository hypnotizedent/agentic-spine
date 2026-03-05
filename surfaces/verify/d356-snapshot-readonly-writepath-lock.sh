#!/usr/bin/env bash
# TRIAGE: enforce no-write-on-read contract for snapshot/status capabilities.
# D356: snapshot-readonly-writepath-lock
set -euo pipefail

resolve_root() {
  if [[ -n "${SPINE_ROOT:-}" && -f "${SPINE_ROOT}/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$SPINE_ROOT"
    return 0
  fi
  local detected_root=""
  detected_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$detected_root" && -f "$detected_root/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$detected_root"
    return 0
  fi
  printf '%s\n' "$HOME/code/agentic-spine"
}

ROOT="$(resolve_root)"
OPS_BIN="$ROOT/bin/ops"
CAP_TIMEOUT_SEC="${D356_CAP_TIMEOUT_SEC:-25}"
CAP_PARALLEL_JOBS="${D356_CAP_PARALLEL_JOBS:-5}"

fail() {
  echo "D356 FAIL: $*" >&2
  exit 1
}

[[ -x "$OPS_BIN" ]] || fail "missing ops runner: $OPS_BIN"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
command -v shasum >/dev/null 2>&1 || fail "missing dependency: shasum"
[[ "$CAP_TIMEOUT_SEC" =~ ^[1-9][0-9]*$ ]] || fail "invalid D356_CAP_TIMEOUT_SEC=$CAP_TIMEOUT_SEC"
[[ "$CAP_PARALLEL_JOBS" =~ ^[1-9][0-9]*$ ]] || fail "invalid D356_CAP_PARALLEL_JOBS=$CAP_PARALLEL_JOBS"

TARGET_FILES=(
  "ops/bindings/ha.inventory.snapshot.yaml"
  "ops/bindings/home.dhcp.audit.yaml"
  "ops/bindings/media.content.snapshot.yaml"
  "ops/bindings/network.inventory.snapshot.yaml"
  "ops/bindings/z2m.devices.yaml"
)

CAPABILITIES=(
  "ha-inventory-snapshot-build"
  "network.home.dhcp.audit"
  "media-content-snapshot-refresh"
  "network-inventory-snapshot-build"
  "ha.z2m.devices.snapshot"
)

file_hash() {
  local path="$1"
  if [[ -f "$path" ]]; then
    shasum -a 256 "$path" | awk '{print $1}'
    return
  fi
  echo "missing"
}

BEFORE_HASHES=()
for rel in "${TARGET_FILES[@]}"; do
  BEFORE_HASHES+=("$(file_hash "$ROOT/$rel")")
done

echo "D356 INFO: exercising snapshot read/status capabilities in check mode"
python3 - "$OPS_BIN" "$CAP_TIMEOUT_SEC" "$CAP_PARALLEL_JOBS" "${CAPABILITIES[@]}" <<'PY' | while IFS=$'\t' read -r cap rc; do
import concurrent.futures
import os
import signal
import subprocess
import sys
import time

ops_bin = sys.argv[1]
timeout_sec = int(sys.argv[2])
parallel_jobs = int(sys.argv[3])
caps = sys.argv[4:]

def run_cap(cap):
    def safe_kill(sig):
        try:
            os.killpg(proc.pid, sig)
            return
        except (ProcessLookupError, PermissionError):
            pass
        try:
            if sig == signal.SIGKILL:
                proc.kill()
            else:
                proc.terminate()
        except ProcessLookupError:
            pass

    with open(os.devnull, "wb") as devnull:
        proc = subprocess.Popen(
            [ops_bin, "cap", "run", cap],
            stdout=devnull,
            stderr=devnull,
            preexec_fn=os.setsid,
        )
        try:
            proc.wait(timeout=timeout_sec)
            return cap, proc.returncode
        except subprocess.TimeoutExpired:
            safe_kill(signal.SIGTERM)
            time.sleep(1)
            safe_kill(signal.SIGKILL)
            return cap, 124

workers = max(1, min(parallel_jobs, len(caps)))
with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
    futures = [pool.submit(run_cap, cap) for cap in caps]
    for future in concurrent.futures.as_completed(futures):
        cap, rc = future.result()
        print(f"{cap}\t{rc}")
PY
  echo "D356 INFO: running cap=${cap}"
  if [[ "$rc" == "0" ]]; then
    echo "D356 INFO: cap=${cap} rc=0"
  else
    echo "D356 INFO: cap=${cap} rc=${rc} (non-blocking for this gate)"
  fi
done

violations=0
idx=0
for rel in "${TARGET_FILES[@]}"; do
  before="${BEFORE_HASHES[$idx]}"
  after="$(file_hash "$ROOT/$rel")"
  if [[ "$before" != "$after" ]]; then
    echo "D356 HIT: tracked snapshot mutated by read/status flow: $rel" >&2
    echo "  before=$before" >&2
    echo "  after=$after" >&2
    violations=$((violations + 1))
  fi
  idx=$((idx + 1))
done

if [[ "$violations" -gt 0 ]]; then
  fail "snapshot no-write-on-read violations=${violations}"
fi

echo "D356 PASS: snapshot read-only capabilities did not mutate tracked snapshot bindings"
