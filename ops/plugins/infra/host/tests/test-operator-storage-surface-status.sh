#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
STATUS_BIN="$ROOT/ops/plugins/infra/host/bin/operator-storage-surface-status"

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

echo "operator storage surface status tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

RUNTIME_ROOT="$TMPDIR_BASE/workbench-runtime"
ARCHIVES_ROOT="$TMPDIR_BASE/Archives"
mkdir -p "$RUNTIME_ROOT/.git" "$ARCHIVES_ROOT"

MINT_STATUS_STUB="$TMPDIR_BASE/mint-status-stub.sh"
cat > "$MINT_STATUS_STUB" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<JSON
{"status":"ok","critical_path":"direct_remote_operator_drop","mount_surface":{"status":"ACTIVE"}}
JSON
EOF
chmod +x "$MINT_STATUS_STUB"

ARCHIVES_STUB="$TMPDIR_BASE/archives-mount-stub.sh"
cat > "$ARCHIVES_STUB" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state="${ARCHIVE_MOUNT_STATE:-INACTIVE}"
root="${ARCHIVE_MOUNT_ROOT:?}"
case "${1:-}" in
  status)
    cat <<OUT
Remote: archives
Mount root: ${root}
Mount attached: no
Mount accessible: yes
rclone process: no
RC reachable: no
Mount: ${state} (${root})
OUT
    ;;
  *)
    echo "unsupported" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$ARCHIVES_STUB"

CONTRACT="$TMPDIR_BASE/operator.storage.surface.contract.yaml"
cat > "$CONTRACT" <<EOF
runtime_workbench_root: "$RUNTIME_ROOT"
surfaces:
  mintfiles:
    status_capability: mint.operator.storage.status
  archives:
    mount_script_path: "$ARCHIVES_STUB"
    mount_root: "$ARCHIVES_ROOT"
    allowed_local_entries_when_unmounted: []
    mount_health_policy:
      inactive: warn
      stale: fail
      local_fallback_entries: fail
EOF

echo ""
echo "── T1: inactive archive browse mount is warning-only when runtime root is ready ──"
t1_out="$(OPERATOR_STORAGE_SURFACE_CONTRACT="$CONTRACT" OPERATOR_STORAGE_MINT_STATUS_BIN="$MINT_STATUS_STUB" ARCHIVE_MOUNT_ROOT="$ARCHIVES_ROOT" ARCHIVE_MOUNT_STATE=INACTIVE "$STATUS_BIN" --brief)"
assert_contains "$t1_out" "status=warn" "overall status warns on inactive browse-only archive surface"
assert_contains "$t1_out" "runtime_root=ready" "runtime workbench root is reported ready"
assert_contains "$t1_out" "mint=ok" "mint slice is carried through"
assert_contains "$t1_out" "archives=warn" "archive surface warns while inactive"
assert_contains "$t1_out" "archives_entries=0" "no archive residue entries are reported"

echo ""
echo "── T2: active archive browse mount with no residue passes ──"
mkdir -p "$ARCHIVES_ROOT/mint-legacy" "$ARCHIVES_ROOT/Hypnotized" "$ARCHIVES_ROOT/Legacy"
t2_out="$(OPERATOR_STORAGE_SURFACE_CONTRACT="$CONTRACT" OPERATOR_STORAGE_MINT_STATUS_BIN="$MINT_STATUS_STUB" ARCHIVE_MOUNT_ROOT="$ARCHIVES_ROOT" ARCHIVE_MOUNT_STATE=ACTIVE "$STATUS_BIN" --brief)"
assert_contains "$t2_out" "status=ok" "overall status passes when both surfaces are ready"
assert_contains "$t2_out" "archives=ok" "archive surface passes when active"
rm -rf "$ARCHIVES_ROOT/mint-legacy" "$ARCHIVES_ROOT/Hypnotized" "$ARCHIVES_ROOT/Legacy"

echo ""
echo "── T3: local residue under inactive archive root fails ──"
mkdir -p "$ARCHIVES_ROOT/tool-history"
t3_out="$(OPERATOR_STORAGE_SURFACE_CONTRACT="$CONTRACT" OPERATOR_STORAGE_MINT_STATUS_BIN="$MINT_STATUS_STUB" ARCHIVE_MOUNT_ROOT="$ARCHIVES_ROOT" ARCHIVE_MOUNT_STATE=INACTIVE "$STATUS_BIN" --brief)"
assert_contains "$t3_out" "status=fail" "overall status fails on archive fallback residue"
assert_contains "$t3_out" "archives=fail" "archive surface fails when local residue blocks clean mount"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
