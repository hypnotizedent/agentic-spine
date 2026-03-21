#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
ASSIST_BIN="$ROOT/ops/plugins/domains/mint/bin/mint-operator-drop-assist"

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

assert_not_exists() {
  local path="$1" label="$2"
  if [[ ! -e "$path" ]]; then
    pass "$label"
  else
    fail "$label (unexpected path: $path)"
  fi
}

assert_exists() {
  local path="$1" label="$2"
  if [[ -e "$path" ]]; then
    pass "$label"
  else
    fail "$label (missing path: $path)"
  fi
}

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

MOUNT_ROOT="$TMPDIR_BASE/MinIO"
DROP_ROOT="$MOUNT_ROOT/artwork-intake/operator-drop"
REMOTE_ROOT="$TMPDIR_BASE/remote"
RECEIPTS_ROOT="$TMPDIR_BASE/receipts"
TRASH_ROOT="$TMPDIR_BASE/Trash"
SOURCE_PARENT="$TMPDIR_BASE/source"
FAKE_MOUNT_SCRIPT="$TMPDIR_BASE/mintfiles-mount.sh"
RCLONE_BIN="$TMPDIR_BASE/rclone"
TEST_CONTRACT="$TMPDIR_BASE/mint.operator.storage.contract.yaml"

mkdir -p "$DROP_ROOT" "$MOUNT_ROOT/artwork-registry" "$MOUNT_ROOT/artwork-output" "$MOUNT_ROOT/client-assets" "$REMOTE_ROOT/artwork-intake" "$SOURCE_PARENT" "$TRASH_ROOT"

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
  *)
    exit 2
    ;;
esac
EOF
chmod +x "$RCLONE_BIN"

cat > "$FAKE_MOUNT_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state="${FAKE_MOUNT_STATE:-ACTIVE}"
mount_root="${FAKE_MOUNT_ROOT:?}"
cat <<OUT
Remote: mintfiles
Mount root: ${mount_root}
Mount attached: yes
Mount accessible: yes
rclone process: yes
RC reachable: yes
Mount: ${state} (${mount_root})
OUT
EOF
chmod +x "$FAKE_MOUNT_SCRIPT"

cat > "$TEST_CONTRACT" <<EOF
---
status: authoritative
owner: "@test"
last_verified: 2026-03-21
scope: mint-operator-storage
---
critical_path:
  mode: mounted_operator_drop
canonical_operator_drop:
  path: "$DROP_ROOT"
  bucket: artwork-intake
  prefix: operator-drop
legacy_desktop_inbox:
  path: "$TMPDIR_BASE/Desktop/Operator Drop"
remote_target:
  rclone_remote: mintfiles
  health_probe_path: artwork-intake
mount_surface:
  launch_agent_label: com.ronnyworks.mintfiles.mount
  launchd_template: ops/plugins/infra/host/launchd/com.ronnyworks.mintfiles.mount.plist
  mount_script_path: "$FAKE_MOUNT_SCRIPT"
  mountpoint: "$MOUNT_ROOT"
  operator_drop_path: "$DROP_ROOT"
  required_visible_paths:
    - "$MOUNT_ROOT/artwork-intake"
    - "$MOUNT_ROOT/artwork-registry"
    - "$MOUNT_ROOT/artwork-output"
    - "$MOUNT_ROOT/client-assets"
assisted_move_surface:
  mode: governed_assisted_move
  destination_root: "$DROP_ROOT"
  verification_method: rsync_checksum_dry_run
  cleanup_policy: trash_after_verified_arrival
  receipts_root: "$RECEIPTS_ROOT"
  helper_bin_path: "$TMPDIR_BASE/bin/mint-operator-drop-assist"
  finder_app_path: "$TMPDIR_BASE/Applications/Mint Operator Drop.app"
  control_plane_root: "$TMPDIR_BASE/control-plane"
  installer_script_path: "$TMPDIR_BASE/install-mint-operator-drop-surface.sh"
  boring_state_requires_entry_surface: false
EOF

echo "mint operator drop assist tests"
echo "════════════════════════════════════════"

SOURCE_ONE="$SOURCE_PARENT/Job 1001"
mkdir -p "$SOURCE_ONE"
printf 'alpha\n' > "$SOURCE_ONE/art.ai"

echo ""
echo "── T1: preview shows the planned move without mutating source or destination ──"
t1_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  FAKE_MOUNT_ROOT="$MOUNT_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_MOUNT_SCRIPT="$FAKE_MOUNT_SCRIPT" \
  MINT_OPERATOR_RCLONE_BIN="$RCLONE_BIN" \
  MINT_OPERATOR_ASSIST_TRASH_STRATEGY=trash_dir \
  MINT_OPERATOR_ASSIST_TRASH_ROOT="$TRASH_ROOT" \
  "$ASSIST_BIN" --preview "$SOURCE_ONE"
)"
assert_contains "$t1_out" "preview: ready" "preview returns ready status"
assert_contains "$t1_out" "destination: $DROP_ROOT/Job 1001" "preview prints canonical destination"
assert_exists "$SOURCE_ONE" "preview leaves source untouched"
assert_not_exists "$DROP_ROOT/Job 1001" "preview does not create destination"

echo ""
echo "── T2: execute moves the directory and trashes the source after verification ──"
t2_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  FAKE_MOUNT_ROOT="$MOUNT_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_MOUNT_SCRIPT="$FAKE_MOUNT_SCRIPT" \
  MINT_OPERATOR_RCLONE_BIN="$RCLONE_BIN" \
  MINT_OPERATOR_ASSIST_TRASH_STRATEGY=trash_dir \
  MINT_OPERATOR_ASSIST_TRASH_ROOT="$TRASH_ROOT" \
  "$ASSIST_BIN" "$SOURCE_ONE"
)"
assert_contains "$t2_out" "status: moved" "execute reports moved status"
assert_exists "$DROP_ROOT/Job 1001/art.ai" "execute creates canonical destination"
assert_not_exists "$SOURCE_ONE" "execute removes source from original location"
assert_exists "$TRASH_ROOT/Job 1001" "execute moves source into trash fallback"

echo ""
echo "── T3: conflicting destination fails closed ──"
SOURCE_TWO="$SOURCE_PARENT/Job 1001"
mkdir -p "$SOURCE_TWO"
printf 'beta\n' > "$SOURCE_TWO/other.ai"
set +e
t3_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  FAKE_MOUNT_ROOT="$MOUNT_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_MOUNT_SCRIPT="$FAKE_MOUNT_SCRIPT" \
  MINT_OPERATOR_RCLONE_BIN="$RCLONE_BIN" \
  MINT_OPERATOR_ASSIST_TRASH_STRATEGY=trash_dir \
  MINT_OPERATOR_ASSIST_TRASH_ROOT="$TRASH_ROOT" \
  "$ASSIST_BIN" "$SOURCE_TWO" 2>&1
)"
t3_status=$?
set -e
if [[ "$t3_status" -ne 0 ]]; then
  pass "conflicting destination returns non-zero"
else
  fail "conflicting destination returns non-zero"
fi
assert_contains "$t3_out" "destination already exists" "conflicting destination explains failure"
assert_exists "$SOURCE_TWO" "conflicting destination leaves source untouched"

echo ""
echo "── T4: inactive mount blocks the move before mutation ──"
SOURCE_THREE="$SOURCE_PARENT/Job 2002"
mkdir -p "$SOURCE_THREE"
printf 'gamma\n' > "$SOURCE_THREE/file.ai"
set +e
t4_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  FAKE_MOUNT_ROOT="$MOUNT_ROOT" \
  FAKE_MOUNT_STATE=INACTIVE \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_MOUNT_SCRIPT="$FAKE_MOUNT_SCRIPT" \
  MINT_OPERATOR_RCLONE_BIN="$RCLONE_BIN" \
  MINT_OPERATOR_ASSIST_TRASH_STRATEGY=trash_dir \
  MINT_OPERATOR_ASSIST_TRASH_ROOT="$TRASH_ROOT" \
  "$ASSIST_BIN" "$SOURCE_THREE" 2>&1
)"
t4_status=$?
set -e
if [[ "$t4_status" -ne 0 ]]; then
  pass "inactive mount returns non-zero"
else
  fail "inactive mount returns non-zero"
fi
assert_contains "$t4_out" "is not ACTIVE" "inactive mount is surfaced explicitly"
assert_exists "$SOURCE_THREE" "inactive mount leaves source untouched"
assert_not_exists "$DROP_ROOT/Job 2002" "inactive mount does not create destination"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
