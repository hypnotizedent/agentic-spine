#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
STATUS_BIN="$ROOT/ops/plugins/domains/mint/bin/mint-operator-storage-status"
CONTRACT="$ROOT/ops/bindings/mint.operator.storage.contract.yaml"
REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"
PLIST="$ROOT/ops/plugins/infra/host/launchd/com.ronnyworks.mintfiles.mount.plist"

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

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    fail "$label (unexpected: $needle)"
  else
    pass "$label"
  fi
}

echo "mint operator storage governance tests"
echo "════════════════════════════════════════"

echo ""
echo "── T1: contract and launchd wiring follow the real mount workflow ──"
assert_contains "$(cat "$CONTRACT")" "mode: mounted_operator_drop" "contract promotes mounted operator-drop as the critical path"
assert_contains "$(cat "$CONTRACT")" "path: ~/MinIO/artwork-intake/operator-drop" "contract pins canonical operator-drop mount path"
assert_contains "$(cat "$CONTRACT")" "path: ~/Desktop/Operator Drop" "contract tracks legacy Desktop residue path"
assert_contains "$(cat "$CONTRACT")" "mode: governed_assisted_move" "contract adds governed assisted move surface"
assert_contains "$(cat "$CONTRACT")" "helper_bin_path: ~/.local/bin/mint-operator-drop-assist" "contract pins local helper path"
assert_contains "$(cat "$CONTRACT")" "finder_app_path: ~/Applications/Mint Operator Drop.app" "contract pins Finder app path"
assert_contains "$(cat "$REGISTRY")" "com.ronnyworks.mintfiles.mount" "launchd registry tracks mintfiles mount"
assert_contains "$(cat "$REGISTRY")" "template_path: ops/plugins/infra/host/launchd/com.ronnyworks.mintfiles.mount.plist" "launchd registry points at spine template"
assert_contains "$(cat "$REGISTRY")" "monitor: true" "launchd registry monitors the mount label"
assert_not_contains "$(cat "$REGISTRY")" "com.ronny.mint-operator-drop-sync" "desktop sync label removed from launchd registry"
assert_contains "$(cat "$PLIST")" "mintfiles-mount.sh" "mintfiles mount template calls the mount helper"
assert_contains "$(cat "$PLIST")" "launchd-run" "mintfiles mount template uses launchd-run supervision"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

MOUNT_ROOT="$TMPDIR_BASE/MinIO"
DROP_ROOT="$MOUNT_ROOT/artwork-intake/operator-drop"
DESKTOP_ROOT="$TMPDIR_BASE/Desktop/Operator Drop"
REMOTE_ROOT="$TMPDIR_BASE/remote"
FAKE_MOUNT_SCRIPT="$TMPDIR_BASE/mintfiles-mount.sh"

mkdir -p "$REMOTE_ROOT/artwork-intake" "$MOUNT_ROOT"

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
  *)
    echo "unsupported rclone subcommand: $cmd" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$RCLONE_BIN"

cat > "$FAKE_MOUNT_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state="${FAKE_MOUNT_STATE:-INACTIVE}"
attached="${FAKE_MOUNT_ATTACHED:-no}"
accessible="${FAKE_MOUNT_ACCESSIBLE:-no}"
process="${FAKE_MOUNT_PROCESS:-no}"
rc="${FAKE_MOUNT_RC:-no}"
mount_root="${FAKE_MOUNT_ROOT:?}"

case "${1:-}" in
  status)
    cat <<OUT
Remote: mintfiles
Mount root: ${mount_root}
Mount attached: ${attached}
Mount accessible: ${accessible}
rclone process: ${process}
RC reachable: ${rc}
Mount: ${state} (${mount_root})
OUT
    ;;
  *)
    echo "unsupported fake mount command: ${1:-}" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$FAKE_MOUNT_SCRIPT"

TEST_CONTRACT="$TMPDIR_BASE/mint.operator.storage.contract.yaml"
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
  path: "$DESKTOP_ROOT"
remote_target:
  rclone_remote: mintfiles
  health_probe_path: artwork-intake
  contimeout: 2s
  timeout: 10s
  retries: 1
  low_level_retries: 1
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
  receipts_root: "$TMPDIR_BASE/receipts"
  helper_bin_path: "$TMPDIR_BASE/bin/mint-operator-drop-assist"
  finder_app_path: "$TMPDIR_BASE/Applications/Mint Operator Drop.app"
  control_plane_root: "$TMPDIR_BASE/control-plane"
  installer_script_path: "$TMPDIR_BASE/install-mint-operator-drop-surface.sh"
  boring_state_requires_entry_surface: true
EOF

echo ""
echo "── T2: inactive mount is a failure even if the remote is reachable ──"
t2_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_MOUNT_SCRIPT="$FAKE_MOUNT_SCRIPT" \
  MINT_OPERATOR_RCLONE_BIN="$RCLONE_BIN" \
  FAKE_MOUNT_ROOT="$MOUNT_ROOT" \
  "$STATUS_BIN" --brief
)"
assert_contains "$t2_out" "status=fail" "status fails when mount is inactive"
assert_contains "$t2_out" "mode=mounted_operator_drop" "brief status reports mounted operator-drop mode"
assert_contains "$t2_out" "remote=ok" "remote reachability still reports correctly"
assert_contains "$t2_out" "mount=INACTIVE" "mount state is surfaced explicitly"

echo ""
echo "── T3: active mount with canonical paths ready passes ──"
mkdir -p "$DROP_ROOT" "$MOUNT_ROOT/artwork-registry" "$MOUNT_ROOT/artwork-output" "$MOUNT_ROOT/client-assets"
mkdir -p "$TMPDIR_BASE/bin" "$TMPDIR_BASE/Applications/Mint Operator Drop.app"
touch "$TMPDIR_BASE/bin/mint-operator-drop-assist"
chmod +x "$TMPDIR_BASE/bin/mint-operator-drop-assist"
t3_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_MOUNT_SCRIPT="$FAKE_MOUNT_SCRIPT" \
  MINT_OPERATOR_RCLONE_BIN="$RCLONE_BIN" \
  FAKE_MOUNT_ROOT="$MOUNT_ROOT" \
  FAKE_MOUNT_STATE=ACTIVE \
  FAKE_MOUNT_ATTACHED=yes \
  FAKE_MOUNT_ACCESSIBLE=yes \
  FAKE_MOUNT_PROCESS=yes \
  FAKE_MOUNT_RC=yes \
  "$STATUS_BIN" --brief
)"
assert_contains "$t3_out" "status=ok" "status passes when mount and operator-drop are healthy"
assert_contains "$t3_out" "operator_drop=ready" "status reports canonical operator-drop ready"
assert_contains "$t3_out" "assist=ready" "status reports assisted move surface ready"
assert_contains "$t3_out" "desktop_legacy=absent" "status reports no Desktop residue"

echo ""
echo "── T4: dirty Desktop residue fails the canonical workflow ──"
mkdir -p "$DESKTOP_ROOT/Job 1001"
t4_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_MOUNT_SCRIPT="$FAKE_MOUNT_SCRIPT" \
  MINT_OPERATOR_RCLONE_BIN="$RCLONE_BIN" \
  FAKE_MOUNT_ROOT="$MOUNT_ROOT" \
  FAKE_MOUNT_STATE=ACTIVE \
  FAKE_MOUNT_ATTACHED=yes \
  FAKE_MOUNT_ACCESSIBLE=yes \
  FAKE_MOUNT_PROCESS=yes \
  FAKE_MOUNT_RC=yes \
  "$STATUS_BIN" --brief
)"
assert_contains "$t4_out" "status=fail" "status fails when legacy Desktop drift is present"
assert_contains "$t4_out" "desktop_legacy=dirty" "status classifies Desktop residue as dirty"
rm -rf "$DESKTOP_ROOT"

echo ""
echo "── T5: empty legacy Desktop folder is warning-only residue ──"
mkdir -p "$DESKTOP_ROOT"
t5_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_MOUNT_SCRIPT="$FAKE_MOUNT_SCRIPT" \
  MINT_OPERATOR_RCLONE_BIN="$RCLONE_BIN" \
  FAKE_MOUNT_ROOT="$MOUNT_ROOT" \
  FAKE_MOUNT_STATE=ACTIVE \
  FAKE_MOUNT_ATTACHED=yes \
  FAKE_MOUNT_ACCESSIBLE=yes \
  FAKE_MOUNT_PROCESS=yes \
  FAKE_MOUNT_RC=yes \
  "$STATUS_BIN" --brief
)"
assert_contains "$t5_out" "status=warn" "status warns on empty legacy Desktop folder"
assert_contains "$t5_out" "desktop_legacy=empty" "status reports empty legacy Desktop folder"

echo ""
echo "── T6: missing assisted move surface is warning-only when mount is healthy ──"
rm -rf "$TMPDIR_BASE/bin" "$TMPDIR_BASE/Applications/Mint Operator Drop.app"
t6_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_MOUNT_SCRIPT="$FAKE_MOUNT_SCRIPT" \
  MINT_OPERATOR_RCLONE_BIN="$RCLONE_BIN" \
  FAKE_MOUNT_ROOT="$MOUNT_ROOT" \
  FAKE_MOUNT_STATE=ACTIVE \
  FAKE_MOUNT_ATTACHED=yes \
  FAKE_MOUNT_ACCESSIBLE=yes \
  FAKE_MOUNT_PROCESS=yes \
  FAKE_MOUNT_RC=yes \
  "$STATUS_BIN" --brief
)"
assert_contains "$t6_out" "status=warn" "status warns when assisted move surface is not installed"
assert_contains "$t6_out" "assist=missing" "status reports assisted move surface missing"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
