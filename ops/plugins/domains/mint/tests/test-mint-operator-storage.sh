#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
STATUS_BIN="$ROOT/ops/plugins/domains/mint/bin/mint-operator-storage-status"
SYNC_BIN="$ROOT/ops/plugins/domains/mint/bin/mint-operator-drop-sync"
CONTRACT="$ROOT/ops/bindings/mint.operator.storage.contract.yaml"
REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"
PLIST="$ROOT/ops/plugins/infra/host/launchd/com.ronny.mint-operator-drop-sync.plist"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (missing: $needle)"
  fi
}

echo "mint operator storage governance tests"
echo "════════════════════════════════════════"

echo ""
echo "── T1: contract and launchd wiring are governed ──"
assert_contains "$(cat "$CONTRACT")" "mode: direct_remote_sync" "contract promotes direct remote sync"
assert_contains "$(cat "$CONTRACT")" "role: convenience_only" "contract demotes FUSE mount to convenience only"
assert_contains "$(cat "$REGISTRY")" "com.ronny.mint-operator-drop-sync" "launchd registry includes governed sync label"
assert_contains "$(cat "$REGISTRY")" "com.ronnyworks.mintfiles.mount" "launchd registry still tracks convenience mount"
assert_contains "$(cat "$REGISTRY")" "contract_required: true" "registry now requires contract coverage"
assert_contains "$(cat "$PLIST")" "runtime-scheduler/ops/plugins/core/bin/mint-operator-drop-sync-cycle.sh" "plist runs from managed runtime worktree"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

LOCAL_INBOX="$TMPDIR_BASE/Desktop/Operator Drop"
REMOTE_ROOT="$TMPDIR_BASE/remote"
STATE_ROOT="$TMPDIR_BASE/state"
LOCKS_ROOT="$TMPDIR_BASE/locks"
MINT_ROOT="$TMPDIR_BASE/mint-modules"
mkdir -p "$LOCAL_INBOX/Job 1001" "$REMOTE_ROOT/artwork-intake" "$STATE_ROOT" "$LOCKS_ROOT" "$MINT_ROOT/bin"
printf 'logo-data\n' > "$LOCAL_INBOX/Job 1001/logo.ai"

RCLONE_BIN="$TMPDIR_BASE/rclone"
cat > "$RCLONE_BIN" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REMOTE_ROOT="${REMOTE_ROOT:?}"
cmd="${1:-}"
case "$cmd" in
  lsf)
    target="${2#*:}"
    [[ -d "$REMOTE_ROOT/$target" ]] || exit 1
    ls -1 "$REMOTE_ROOT/$target"
    ;;
  copy)
    src="${2:?}"
    dest="${3#*:}"
    mkdir -p "$REMOTE_ROOT/$dest"
    cp -R "$src"/. "$REMOTE_ROOT/$dest"/
    ;;
  *)
    echo "unsupported rclone subcommand: $cmd" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$RCLONE_BIN"

MINTCTL_BIN="$MINT_ROOT/bin/mintctl"
cat > "$MINTCTL_BIN" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MINTCTL_LOG:?}"
exit 0
EOF
chmod +x "$MINTCTL_BIN"

TEST_CONTRACT="$TMPDIR_BASE/mint.operator.storage.contract.yaml"
cat > "$TEST_CONTRACT" <<EOF
---
status: authoritative
owner: "@test"
last_verified: 2026-03-21
scope: mint-operator-storage
---
critical_path:
  mode: direct_remote_sync
local_inbox:
  path: "$LOCAL_INBOX"
remote_target:
  rclone_remote: mintfiles
  bucket: artwork-intake
  prefix: operator-drop
  health_probe_path: artwork-intake
  contimeout: 2s
  timeout: 10s
  retries: 1
  low_level_retries: 1
  create_empty_src_dirs: true
ingest:
  mint_repo_root: "$MINT_ROOT"
  mintctl_command: ./bin/mintctl morpheus intake
  folder_flag: --folder
  source_flag: --source
convenience_mount:
  launch_agent_label: com.ronnyworks.mintfiles.mount
  mountpoint: "$TMPDIR_BASE/MinIO"
automation:
  sync_launchd_label: com.ronny.mint-operator-drop-sync
runtime_state:
  state_root: "$STATE_ROOT"
  sync_history_file: "$STATE_ROOT/sync-history.tsv"
EOF

echo ""
echo "── T2: status reports pending Desktop inbox work ──"
t2_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_RCLONE_BIN="$RCLONE_BIN" \
  MINTCTL_LOG="$TMPDIR_BASE/mintctl.log" \
  SPINE_STATE="$STATE_ROOT" \
  SPINE_LOCKS="$LOCKS_ROOT" \
  "$STATUS_BIN" --brief
)"
assert_contains "$t2_out" "status=warn" "status warns while pending folders exist"
assert_contains "$t2_out" "pending=1" "status reports pending folder count"
assert_contains "$t2_out" "remote=ok" "status reports direct remote reachability"

echo ""
echo "── T3: sync uploads, ingests, and deletes local source ──"
t3_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_RCLONE_BIN="$RCLONE_BIN" \
  MINTCTL_BIN="$MINTCTL_BIN" \
  MINTCTL_LOG="$TMPDIR_BASE/mintctl.log" \
  SPINE_STATE="$STATE_ROOT" \
  SPINE_LOCKS="$LOCKS_ROOT" \
  "$SYNC_BIN" --execute --json
)"
assert_contains "$t3_out" "\"status\":\"ok\"" "sync returns ok JSON payload"
if [[ -f "$REMOTE_ROOT/artwork-intake/operator-drop/Job 1001/logo.ai" ]]; then
  pass "sync copied folder to direct MinIO target"
else
  fail "sync copied folder to direct MinIO target"
fi
if [[ ! -d "$LOCAL_INBOX/Job 1001" ]]; then
  pass "sync removed local source folder after verified ingest"
else
  fail "sync removed local source folder after verified ingest"
fi
assert_contains "$(cat "$TMPDIR_BASE/mintctl.log")" "morpheus intake --folder Job 1001" "sync invokes targeted ingest"
assert_contains "$(cat "$STATE_ROOT/sync-history.tsv")" "synced" "sync records runtime history"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
