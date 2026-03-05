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
CAP_TIMEOUT_SEC="${D356_CAP_TIMEOUT_SEC:-90}"

fail() {
  echo "D356 FAIL: $*" >&2
  exit 1
}

[[ -x "$OPS_BIN" ]] || fail "missing ops runner: $OPS_BIN"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
command -v shasum >/dev/null 2>&1 || fail "missing dependency: shasum"

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
for cap in "${CAPABILITIES[@]}"; do
  echo "D356 INFO: running cap=${cap}"
  if python3 - "$OPS_BIN" "$cap" "$CAP_TIMEOUT_SEC" <<'PY'
import os
import signal
import subprocess
import sys
import time

ops_bin = sys.argv[1]
cap = sys.argv[2]
timeout_sec = int(sys.argv[3])

with open(os.devnull, "wb") as devnull:
    proc = subprocess.Popen(
        [ops_bin, "cap", "run", cap],
        stdout=devnull,
        stderr=devnull,
        preexec_fn=os.setsid,
    )
    try:
        proc.wait(timeout=timeout_sec)
        sys.exit(proc.returncode)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        time.sleep(2)
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        sys.exit(124)
PY
  then
    echo "D356 INFO: cap=${cap} rc=0"
    continue
  fi
  rc=$?
  echo "D356 INFO: cap=${cap} rc=${rc} (non-blocking for this gate)"
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
