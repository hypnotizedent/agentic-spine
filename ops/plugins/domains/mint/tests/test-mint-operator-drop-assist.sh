#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
ASSIST="$ROOT/ops/plugins/domains/mint/bin/mint-operator-drop-assist"

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

assert_exists() {
  local path="$1" label="$2"
  if [[ -e "$path" ]]; then
    pass "$label"
  else
    fail "$label (missing path: $path)"
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

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

REMOTE_ROOT="$TMPDIR_BASE/remote"
RECEIPTS_ROOT="$TMPDIR_BASE/receipts"
TRASH_ROOT="$TMPDIR_BASE/Trash"
SOURCE_PARENT="$TMPDIR_BASE/source"
MOUNT_ROOT="$TMPDIR_BASE/MinIO"
RCLONE_BIN="$TMPDIR_BASE/rclone"
FAKE_MOUNT_SCRIPT="$TMPDIR_BASE/mintfiles-mount.sh"
TEST_CONTRACT="$TMPDIR_BASE/mint.operator.storage.contract.yaml"

mkdir -p \
  "$REMOTE_ROOT/artwork-intake" \
  "$RECEIPTS_ROOT" \
  "$TRASH_ROOT" \
  "$SOURCE_PARENT" \
  "$MOUNT_ROOT"

cat > "$RCLONE_BIN" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REMOTE_ROOT="${REMOTE_ROOT:?}"
cmd="${1:-}"
shift || true

strip_remote() {
  local path="$1"
  printf '%s\n' "${path#*:}"
}

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --*)
      if [[ $# -gt 1 && "$2" != --* ]]; then
        shift 2
      else
        shift
      fi
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

case "$cmd" in
  lsf)
    target="$(strip_remote "${args[0]}")"
    if [[ -d "$REMOTE_ROOT/$target" ]]; then
      find "$REMOTE_ROOT/$target" -mindepth 1 -maxdepth 1 -print >/dev/null
      exit 0
    fi
    exit 1
    ;;
  lsjson)
    target="$(strip_remote "${args[0]}")"
    if [[ -d "$REMOTE_ROOT/$target" ]]; then
      shopt -s nullglob dotglob
      entries=("$REMOTE_ROOT/$target"/*)
      shopt -u nullglob dotglob
      if [[ ${#entries[@]} -eq 0 ]]; then
        printf '[]\n'
      else
        printf '[\n'
        first=1
        for entry in "${entries[@]}"; do
          name="$(basename "$entry")"
          if [[ "$first" -eq 1 ]]; then
            first=0
          else
            printf ',\n'
          fi
          printf '  {"Path":"%s"}' "$name"
        done
        printf '\n]\n'
      fi
    else
      printf '[]\n'
    fi
    ;;
  copy)
    src="${args[0]}"
    dest="${args[1]}"
    if [[ "$src" == *:* && "$dest" == *:* ]]; then
      src_path="$REMOTE_ROOT/$(strip_remote "$src")"
      dest_path="$REMOTE_ROOT/$(strip_remote "$dest")"
      mkdir -p "$dest_path"
      cp -R "$src_path"/. "$dest_path"/
    elif [[ "$src" == *:* ]]; then
      src_path="$REMOTE_ROOT/$(strip_remote "$src")"
      mkdir -p "$dest"
      cp -R "$src_path"/. "$dest"/
    else
      dest_path="$REMOTE_ROOT/$(strip_remote "$dest")"
      mkdir -p "$dest_path"
      cp -R "$src"/. "$dest_path"/
    fi
    ;;
  check)
    src="${args[0]}"
    dest="${args[1]}"
    if [[ "$dest" == *:* ]]; then
      dest_path="$REMOTE_ROOT/$(strip_remote "$dest")"
    else
      dest_path="$dest"
    fi
    diff -ruN "$src" "$dest_path" >/dev/null
    ;;
  purge)
    target="${args[0]}"
    rm -rf "$REMOTE_ROOT/$(strip_remote "$target")"
    ;;
  *)
    echo "unsupported rclone subcommand: $cmd" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$RCLONE_BIN"

cat > "$FAKE_MOUNT_SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cat <<OUT
Remote: mintfiles
Mount root: $MOUNT_ROOT
Mount attached: no
Mount accessible: no
rclone process: no
RC reachable: no
Mount: INACTIVE ($MOUNT_ROOT)
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
  mode: direct_remote_operator_drop
canonical_operator_drop:
  path: "$MOUNT_ROOT/artwork-intake/operator-drop"
  browse_mount_path: "$MOUNT_ROOT/artwork-intake/operator-drop"
  remote: mintfiles:artwork-intake/operator-drop
  bucket: artwork-intake
  prefix: operator-drop
legacy_desktop_inbox:
  path: "$TMPDIR_BASE/Desktop/Operator Drop"
remote_target:
  rclone_remote: mintfiles
  health_probe_path: artwork-intake
mount_surface:
  role: optional_browse_surface
  launch_agent_label: com.ronnyworks.mintfiles.mount
  launchd_template: ops/plugins/infra/host/launchd/com.ronnyworks.mintfiles.mount.plist
  mount_script_path: "$FAKE_MOUNT_SCRIPT"
  mountpoint: "$MOUNT_ROOT"
  operator_drop_path: "$MOUNT_ROOT/artwork-intake/operator-drop"
  required_visible_paths:
    - "$MOUNT_ROOT/artwork-intake"
assisted_move_surface:
  mode: governed_mountless_remote_move
  remote_destination: mintfiles:artwork-intake/operator-drop
  staging_prefix: artwork-intake/operator-drop/.incoming
  verification_method: rclone_check_size_one_way
  cleanup_policy: trash_after_verified_arrival
  receipts_root: "$RECEIPTS_ROOT"
  helper_bin_path: "$TMPDIR_BASE/bin/mint-operator-drop-assist"
  finder_app_path: "$TMPDIR_BASE/Applications/Mint Operator Drop.app"
  control_plane_root: "$ROOT"
  installer_script_path: "$TMPDIR_BASE/install.sh"
  boring_state_requires_entry_surface: false
EOF

echo "mint operator drop assist tests"
echo "════════════════════════════════════════"

SOURCE_ONE="$SOURCE_PARENT/Job 3001"
mkdir -p "$SOURCE_ONE"
printf 'alpha\n' > "$SOURCE_ONE/art.ai"

t1_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_ASSIST_RCLONE_BIN="$RCLONE_BIN" \
  MINT_OPERATOR_ASSIST_TRASH_STRATEGY=trash_dir \
  MINT_OPERATOR_ASSIST_TRASH_ROOT="$TRASH_ROOT" \
  "$ASSIST" move --preview "$SOURCE_ONE"
)"
assert_contains "$t1_out" "preview: ready" "preview returns ready status"
assert_contains "$t1_out" "destination_remote: mintfiles:artwork-intake/operator-drop/Job 3001" "preview prints remote destination"
assert_exists "$SOURCE_ONE" "preview leaves source untouched"

t2_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_ASSIST_RCLONE_BIN="$RCLONE_BIN" \
  MINT_OPERATOR_ASSIST_TRASH_STRATEGY=trash_dir \
  MINT_OPERATOR_ASSIST_TRASH_ROOT="$TRASH_ROOT" \
  "$ASSIST" move "$SOURCE_ONE"
)"
assert_contains "$t2_out" "status: moved" "execute reports moved"
assert_exists "$REMOTE_ROOT/artwork-intake/operator-drop/Job 3001/art.ai" "execute uploads to remote destination"
assert_not_exists "$SOURCE_ONE" "execute removes source from original location"
assert_exists "$TRASH_ROOT/Job 3001" "execute moves source into trash"

SOURCE_TWO="$SOURCE_PARENT/Job 3001"
mkdir -p "$SOURCE_TWO"
printf 'beta\n' > "$SOURCE_TWO/other.ai"
set +e
t3_out="$(
  cd "$ROOT" && \
  REMOTE_ROOT="$REMOTE_ROOT" \
  MINT_OPERATOR_STORAGE_CONTRACT="$TEST_CONTRACT" \
  MINT_OPERATOR_ASSIST_RCLONE_BIN="$RCLONE_BIN" \
  MINT_OPERATOR_ASSIST_TRASH_STRATEGY=trash_dir \
  MINT_OPERATOR_ASSIST_TRASH_ROOT="$TRASH_ROOT" \
  "$ASSIST" move "$SOURCE_TWO" 2>&1
)"
t3_status=$?
set -e
if [[ "$t3_status" -ne 0 ]]; then
  pass "conflicting destination returns non-zero"
else
  fail "conflicting destination returns non-zero"
fi
assert_contains "$t3_out" "destination already exists" "conflict is surfaced"
assert_exists "$SOURCE_TWO" "conflict leaves source untouched"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
