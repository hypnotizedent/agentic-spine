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

RELAY_ROOT="$TMPDIR_BASE/relay-source"
DIRECT_ROOT="$TMPDIR_BASE/direct-source"
DEST_ROOT="$TMPDIR_BASE/pve-root"
RECEIPTS_ROOT="$TMPDIR_BASE/receipts"
STAGE_ROOT="$TMPDIR_BASE/stage"
RCLONE_STUB="$TMPDIR_BASE/rclone"
SECURITY_STUB="$TMPDIR_BASE/security"

mkdir -p "$RELAY_ROOT/source/documents" "$DIRECT_ROOT/source/documents" "$DEST_ROOT/md1400/archive/live-share/ronny-projects/Legacy" "$DEST_ROOT/md1400/archive/live-share/ronny-projects/Hypnotized" "$DEST_ROOT/md1400/archive/live-share/mint-legacy" "$RECEIPTS_ROOT" "$STAGE_ROOT"

cat > "$SECURITY_STUB" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "stub-password"
EOF
chmod +x "$SECURITY_STUB"

cat > "$RCLONE_STUB" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "$RCLONE_STUB"

mkdir -p "$RELAY_ROOT/source/documents/Relay Folder" "$DIRECT_ROOT/source/documents/Direct Folder" "$RELAY_ROOT/source/documents/Blocked Folder"
printf 'relay-one\n' > "$RELAY_ROOT/source/documents/Relay Folder/file.txt"
printf 'direct-one\n' > "$DIRECT_ROOT/source/documents/Direct Folder/file.txt"
printf 'blocked-one\n' > "$RELAY_ROOT/source/documents/Blocked Folder/file.txt"

CONTRACT="$TMPDIR_BASE/operator.storage.surface.contract.yaml"
cat > "$CONTRACT" <<EOF
runtime_workbench_root: "$TMPDIR_BASE/workbench-runtime"
surfaces:
  archives:
    mount_root: "$TMPDIR_BASE/Archives"
    remote_setup:
      smb_host: 100.96.211.33
      smb_user: archive
      shares:
        - remote_name: archives-mint-legacy
          share: mint-legacy
        - remote_name: archives-ronny-projects
          share: ronny-projects
    assisted_move_surface:
      helper_bin_path: "$TMPDIR_BASE/bin/archive-operator-drop-assist"
      finder_app_path: "$TMPDIR_BASE/Archive Operator Drop.app"
      default_route: Legacy
      route_selector_required: true
      selector_label: family
      receipts_root: "$RECEIPTS_ROOT/move"
      routes:
        - id: mint-legacy
          browse_root: "$TMPDIR_BASE/Archives/mint-legacy"
          remote_root: archives-mint-legacy:mint-legacy
          readiness_probe_remote: archives-mint-legacy:mint-legacy
          staging_root: archives-mint-legacy:mint-legacy/.incoming
          canonical_host_binding: pve
          canonical_path: /md1400/archive/live-share/mint-legacy
        - id: Hypnotized
          browse_root: "$TMPDIR_BASE/Archives/Hypnotized"
          remote_root: archives-ronny-projects:ronny-projects/Hypnotized
          readiness_probe_remote: archives-ronny-projects:ronny-projects/Hypnotized
          staging_root: archives-ronny-projects:ronny-projects/Hypnotized/.incoming
          canonical_host_binding: pve
          canonical_path: /md1400/archive/live-share/ronny-projects/Hypnotized
        - id: Legacy
          browse_root: "$TMPDIR_BASE/Archives/Legacy"
          remote_root: archives-ronny-projects:ronny-projects/Legacy
          readiness_probe_remote: archives-ronny-projects:ronny-projects/Legacy
          staging_root: archives-ronny-projects:ronny-projects/Legacy/.incoming
          canonical_host_binding: pve
          canonical_path: /md1400/archive/live-share/ronny-projects/Legacy
    rehome_surface:
      receipts_root: "$RECEIPTS_ROOT/rehome"
      relay_stage_root: "$STAGE_ROOT"
      default_verify_mode: quick
      verify_modes:
        quick:
          manifest_basis: size_count
          delete_allowed: false
        strict:
          manifest_basis: sha256
          delete_allowed: false
        strict-delete:
          manifest_basis: sha256
          delete_allowed: true
      host_bindings:
        - id: relay-source
          transport: local_fixture
          fixture_root: "$RELAY_ROOT"
          allowed_source_roots:
            - /source/documents
          direct_remote_allowed: false
        - id: direct-source
          transport: local_fixture
          fixture_root: "$DIRECT_ROOT"
          allowed_source_roots:
            - /source/documents
          direct_remote_allowed: true
        - id: pve
          transport: local_fixture
          fixture_root: "$DEST_ROOT"
EOF

assist_env() {
  ARCHIVE_OPERATOR_STORAGE_CONTRACT="$CONTRACT" \
  ARCHIVE_OPERATOR_RCLONE_BIN="$RCLONE_STUB" \
  ARCHIVE_OPERATOR_SECURITY_BIN="$SECURITY_STUB" \
  "$ASSIST" "$@"
}

latest_rehome_receipt() {
  find "$RECEIPTS_ROOT/rehome" -name receipt.yaml -print | LC_ALL=C sort | tail -n 1
}

echo "archive operator rehome tests"
echo "════════════════════════════════════════"

echo ""
echo "── T1: preview selects relay-stage and emits canonical destination ──"
t1_out="$(assist_env rehome --family Legacy --source-host relay-source --source-path /source/documents/Relay\ Folder --preview)"
assert_contains "$t1_out" "status: preview" "preview reports preview status"
assert_contains "$t1_out" "transfer_strategy: relay_stage" "preview reports relay-stage strategy"
assert_contains "$t1_out" "final_canonical_archive_path: pve:/md1400/archive/live-share/ronny-projects/Legacy/Relay Folder" "preview prints canonical archive path"
assert_exists "$(latest_rehome_receipt)" "preview writes receipt packet"

echo ""
echo "── T2: strict relay rehome succeeds without source retirement ──"
t2_out="$(assist_env rehome --family Legacy --source-host relay-source --source-path /source/documents/Relay\ Folder --verify strict)"
assert_contains "$t2_out" "status: rehomed" "strict relay rehome reports success"
assert_contains "$t2_out" "verify_mode: strict" "strict relay rehome reports verify mode"
assert_exists "$DEST_ROOT/md1400/archive/live-share/ronny-projects/Legacy/Relay Folder/file.txt" "relay rehome writes into canonical destination"
assert_exists "$RELAY_ROOT/source/documents/Relay Folder/file.txt" "strict rehome keeps source when retire flag absent"

echo ""
echo "── T3: quick verify blocks retire-source with explicit receipt reason ──"
set +e
t3_out="$(assist_env rehome --family Legacy --source-host relay-source --source-path /source/documents/Blocked\ Folder --verify quick --retire-source 2>&1)"
t3_status=$?
set -e
if [[ "$t3_status" -ne 0 ]]; then
  pass "quick retire-source request is rejected"
else
  fail "quick retire-source request is rejected (unexpected exit 0)"
fi
assert_contains "$t3_out" "status: blocked" "blocked retire request reports blocked status"
assert_contains "$t3_out" "source_retirement_result: blocked" "blocked retire request reports blocked retirement"
assert_contains "$(cat "$(latest_rehome_receipt)")" "verify mode quick does not authorize source retirement" "receipt explains retirement rejection"

echo ""
echo "── T4: strict-delete direct rehome retires source after checksum parity ──"
t4_out="$(assist_env rehome --family Hypnotized --source-host direct-source --source-path /source/documents/Direct\ Folder --verify strict-delete --retire-source)"
assert_contains "$t4_out" "status: rehomed_and_retired_source" "strict-delete direct rehome reports retired source"
assert_contains "$t4_out" "transfer_strategy: direct_remote" "strict-delete direct rehome uses direct strategy"
assert_exists "$DEST_ROOT/md1400/archive/live-share/ronny-projects/Hypnotized/Direct Folder/file.txt" "direct rehome writes into canonical destination"
assert_not_exists "$DIRECT_ROOT/source/documents/Direct Folder" "strict-delete direct rehome removes source after parity"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
