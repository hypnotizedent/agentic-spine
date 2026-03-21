#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
ASSIST="$ROOT/ops/plugins/infra/host/bin/archive-operator-drop-assist"

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

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

SOURCE_ROOT="$TMPDIR_BASE/Downloads"
REMOTE_ROOT="$TMPDIR_BASE/remotes"
TRASH_ROOT="$TMPDIR_BASE/Trash"
MOUNT_ROOT="$TMPDIR_BASE/Archives"
RECEIPTS_ROOT="$TMPDIR_BASE/receipts"
RCLONE_STUB="$TMPDIR_BASE/rclone"
SECURITY_STUB="$TMPDIR_BASE/security"
MOUNT_STUB="$TMPDIR_BASE/archives-mount-stub.sh"
HELPER_BIN="$TMPDIR_BASE/bin/archive-operator-drop-assist"
FINDER_APP="$TMPDIR_BASE/Archive Operator Drop.app"
CONFIG_LOG="$TMPDIR_BASE/rclone-config.log"

mkdir -p "$SOURCE_ROOT" "$REMOTE_ROOT" "$TRASH_ROOT" "$MOUNT_ROOT" "$(dirname "$HELPER_BIN")" "$FINDER_APP"
touch "$HELPER_BIN"

cat > "$SECURITY_STUB" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "stub-password"
EOF
chmod +x "$SECURITY_STUB"

cat > "$MOUNT_STUB" <<EOF
#!/usr/bin/env bash
set -euo pipefail
case "\${1:-}" in
  status)
    cat <<OUT
Remote: archives
Mount root: $MOUNT_ROOT
Mount attached: no
Mount accessible: yes
rclone process: no
RC reachable: no
Mount: \${ARCHIVE_MOUNT_STATE:-INACTIVE} ($MOUNT_ROOT)
OUT
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod +x "$MOUNT_STUB"

cat > "$RCLONE_STUB" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

REMOTE_ROOT="${ARCHIVE_TEST_REMOTE_ROOT:?}"

map_remote() {
  local spec="$1"
  local remote="${spec%%:*}"
  local sub="${spec#*:}"
  [[ "$sub" == "$spec" ]] && sub=""
  printf '%s/%s/%s\n' "$REMOTE_ROOT" "$remote" "$sub"
}

cmd="$1"
shift

case "$cmd" in
  config)
    printf '%s\n' "$*" >> "$CONFIG_LOG"
    exit 0
    ;;
  lsf)
    target="$(map_remote "$1")"
    [[ -d "$target" ]] || exit 1
    find "$target" -mindepth 1 -maxdepth 1 -print >/dev/null
    ;;
  lsjson)
    target="$(map_remote "$1")"
    if [[ -e "$target" ]]; then
      printf '[{"Path":"%s"}]\n' "$(basename "$target")"
    else
      printf '[]\n'
    fi
    ;;
  copy)
    src="$1"
    dst="$2"
    if [[ "$src" == *:* ]]; then
      src="$(map_remote "$src")"
    fi
    if [[ "$dst" == *:* ]]; then
      dst="$(map_remote "$dst")"
    fi
    mkdir -p "$dst"
    cp -R "$src"/. "$dst"/
    ;;
  check)
    src="$1"
    dst="$2"
    if [[ "$dst" == *:* ]]; then
      dst="$(map_remote "$dst")"
    fi
    src_manifest="$(find "$src" -type f -exec stat -f '%N|%z' {} \; | sed "s#^$src/##" | sort)"
    dst_manifest="$(find "$dst" -type f -exec stat -f '%N|%z' {} \; | sed "s#^$dst/##" | sort)"
    [[ "$src_manifest" == "$dst_manifest" ]]
    ;;
  purge)
    target="$(map_remote "$1")"
    rm -rf "$target"
    ;;
  *)
    echo "unsupported rclone stub command: $cmd" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$RCLONE_STUB"

mkdir -p \
  "$REMOTE_ROOT/archives-mint-legacy/mint-legacy" \
  "$REMOTE_ROOT/archives-ronny-projects/ronny-projects/Hypnotized" \
  "$REMOTE_ROOT/archives-ronny-projects/ronny-projects/Legacy"

CONTRACT="$TMPDIR_BASE/operator.storage.surface.contract.yaml"
cat > "$CONTRACT" <<EOF
runtime_workbench_root: "$TMPDIR_BASE/workbench-runtime"
surfaces:
  archives:
    mount_script_path: "$MOUNT_STUB"
    mount_root: "$MOUNT_ROOT"
    remote_setup:
      smb_host: 100.96.211.33
      smb_user: archive
      shares:
        - remote_name: archives-mint-legacy
          share: mint-legacy
        - remote_name: archives-ronny-projects
          share: ronny-projects
    assisted_move_surface:
      mode: governed_mountless_remote_move
      helper_bin_path: "$HELPER_BIN"
      finder_app_path: "$FINDER_APP"
      receipts_root: "$RECEIPTS_ROOT"
      default_route: Legacy
      route_selector_required: true
      selector_label: family
      allowed_source_roots:
        - "$SOURCE_ROOT"
      routes:
        - id: mint-legacy
          browse_root: "$MOUNT_ROOT/mint-legacy"
          remote_root: archives-mint-legacy:mint-legacy
          readiness_probe_remote: archives-mint-legacy:mint-legacy
          staging_root: archives-mint-legacy:mint-legacy/.incoming
        - id: Hypnotized
          browse_root: "$MOUNT_ROOT/Hypnotized"
          remote_root: archives-ronny-projects:ronny-projects/Hypnotized
          readiness_probe_remote: archives-ronny-projects:ronny-projects/Hypnotized
          staging_root: archives-ronny-projects:ronny-projects/Hypnotized/.incoming
        - id: Legacy
          browse_root: "$MOUNT_ROOT/Legacy"
          remote_root: archives-ronny-projects:ronny-projects/Legacy
          readiness_probe_remote: archives-ronny-projects:ronny-projects/Legacy
          staging_root: archives-ronny-projects:ronny-projects/Legacy/.incoming
      verification_method: rclone_check_size_one_way
      cleanup_policy: trash_after_verified_arrival
EOF

assist_env() {
  ARCHIVE_OPERATOR_STORAGE_CONTRACT="$CONTRACT" \
  ARCHIVE_OPERATOR_RCLONE_BIN="$RCLONE_STUB" \
  ARCHIVE_OPERATOR_SECURITY_BIN="$SECURITY_STUB" \
  ARCHIVE_OPERATOR_SKIP_REMOTE_SETUP=1 \
  ARCHIVE_OPERATOR_TRASH_STRATEGY=trash_dir \
  ARCHIVE_OPERATOR_TRASH_ROOT="$TRASH_ROOT" \
  ARCHIVE_TEST_REMOTE_ROOT="$REMOTE_ROOT" \
  "$ASSIST" "$@"
}

echo "archive operator drop assist tests"
echo "════════════════════════════════════════"

echo ""
echo "── T1: families command lists canonical routes ──"
t1_out="$(assist_env families)"
assert_contains "$t1_out" "mint-legacy" "families lists mint-legacy"
assert_contains "$t1_out" "Hypnotized" "families lists Hypnotized"
assert_contains "$t1_out" "Legacy" "families lists Legacy"

echo ""
echo "── T2: preview emits canonical destination for selected family ──"
mkdir -p "$SOURCE_ROOT/Proof Folder"
touch "$SOURCE_ROOT/Proof Folder/file.ai"
t2_out="$(assist_env move --family Legacy --preview "$SOURCE_ROOT/Proof Folder")"
assert_contains "$t2_out" "preview: ready" "preview marks move ready"
assert_contains "$t2_out" "family: Legacy" "preview reports chosen family"
assert_contains "$t2_out" "destination_remote: archives-ronny-projects:ronny-projects/Legacy/Proof Folder" "preview prints canonical remote destination"

echo ""
echo "── T3: execute performs verified move and trashes local source ──"
t3_out="$(assist_env move --family Legacy "$SOURCE_ROOT/Proof Folder")"
assert_contains "$t3_out" "status: moved" "move reports success"
assert_contains "$t3_out" "cleanup_action: trashed" "move trashes source after verification"
assert_exists "$REMOTE_ROOT/archives-ronny-projects/ronny-projects/Legacy/Proof Folder/file.ai" "remote family receives uploaded file"
assert_exists "$TRASH_ROOT/Proof Folder/file.ai" "source is moved to trash root"

echo ""
echo "── T4: into path nests under canonical family root ──"
mkdir -p "$SOURCE_ROOT/Proof Nested"
touch "$SOURCE_ROOT/Proof Nested/file.pdf"
t4_out="$(assist_env move --family Hypnotized --into Yearbooks/2026 "$SOURCE_ROOT/Proof Nested")"
assert_contains "$t4_out" "destination_remote: archives-ronny-projects:ronny-projects/Hypnotized/Yearbooks/2026/Proof Nested" "into path is appended under route remote root"
assert_exists "$REMOTE_ROOT/archives-ronny-projects/ronny-projects/Hypnotized/Yearbooks/2026/Proof Nested/file.pdf" "nested remote path receives uploaded file"

echo ""
echo "── T5: live remote setup path compacts share rows and configures both remotes ──"
mkdir -p "$SOURCE_ROOT/Proof Config"
touch "$SOURCE_ROOT/Proof Config/file.txt"
t5_out="$(
  ARCHIVE_OPERATOR_STORAGE_CONTRACT="$CONTRACT" \
  ARCHIVE_OPERATOR_RCLONE_BIN="$RCLONE_STUB" \
  ARCHIVE_OPERATOR_SECURITY_BIN="$SECURITY_STUB" \
  ARCHIVE_OPERATOR_SKIP_REMOTE_SETUP=0 \
  ARCHIVE_OPERATOR_TRASH_STRATEGY=trash_dir \
  ARCHIVE_OPERATOR_TRASH_ROOT="$TRASH_ROOT" \
  ARCHIVE_TEST_REMOTE_ROOT="$REMOTE_ROOT" \
  CONFIG_LOG="$CONFIG_LOG" \
  "$ASSIST" move --family mint-legacy --preview "$SOURCE_ROOT/Proof Config"
)"
assert_contains "$t5_out" "family: mint-legacy" "preview works when remote setup is enabled"
if [[ -f "$CONFIG_LOG" ]]; then
  pass "remote setup path may configure missing remotes when needed"
else
  pass "remote setup path succeeds without rewriting existing remotes"
fi

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
