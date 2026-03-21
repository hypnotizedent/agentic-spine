#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
SYNC_BIN="$ROOT/ops/plugins/infra/host/bin/operator-storage-surface-sync"

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

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

HOME="$TMPDIR_BASE/home"
mkdir -p "$HOME"

MINT_ROOT="$HOME/Operator Sync/Mint/operator-drop"
ARCHIVE_ROOT="$HOME/Operator Sync/Archives"
mkdir -p "$MINT_ROOT" "$ARCHIVE_ROOT/Legacy" "$HOME/Library/LaunchAgents"

MINT_HELPER="$TMPDIR_BASE/mint-helper.sh"
cat > "$MINT_HELPER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "move" ]]; then
  src="${2:?}"
  rm -rf "$src"
  cat <<OUT
status: moved
receipt: /tmp/mint-helper-receipt.yaml
OUT
  exit 0
fi
echo "unsupported" >&2
exit 2
EOF
chmod +x "$MINT_HELPER"

ARCHIVE_HELPER="$TMPDIR_BASE/archive-helper.sh"
cat > "$ARCHIVE_HELPER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "move" ]]; then
  route="${3:?}"
  src="${4:?}"
  rm -rf "$src"
  cat <<OUT
status: moved
receipt: /tmp/archive-${route}-receipt.yaml
OUT
  exit 0
fi
echo "unsupported" >&2
exit 2
EOF
chmod +x "$ARCHIVE_HELPER"

RCLONE_STUB="$TMPDIR_BASE/rclone"
cat > "$RCLONE_STUB" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
shift || true
case "$cmd" in
  lsf)
    target="${1:-}"
    if [[ "$target" == *"Existing Folder"* ]]; then
      exit 0
    fi
    exit 1
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$RCLONE_STUB"

CONTRACT="$TMPDIR_BASE/operator.storage.surface.contract.yaml"
cat > "$CONTRACT" <<EOF
bootstrap:
  sync_launch_agent_label: com.ronny.operator-storage-surface-sync
surfaces:
  mintfiles:
    assisted_move_surface:
      helper_bin_path: "$MINT_HELPER"
    watched_outbox_surface:
      enabled: true
      mode: watched_outbox_sync
      local_root: "$MINT_ROOT"
      conflicts_root: "$HOME/Operator Sync/.conflicts/Mint"
      journal_root: "$TMPDIR_BASE/journal/mint"
      sync_command_path: "$MINT_HELPER"
      remote_root: mintfiles:artwork-intake/operator-drop
  archives:
    assisted_move_surface:
      helper_bin_path: "$ARCHIVE_HELPER"
    watched_outbox_surface:
      enabled: true
      mode: watched_outbox_sync
      local_root: "$ARCHIVE_ROOT"
      conflicts_root: "$HOME/Operator Sync/.conflicts/Archives"
      journal_root: "$TMPDIR_BASE/journal/archive"
      sync_command_path: "$ARCHIVE_HELPER"
      routes:
        - id: Legacy
          local_root: "$ARCHIVE_ROOT/Legacy"
          remote_root: archives-ronny-projects:ronny-projects/Legacy
EOF

mkdir -p "$MINT_ROOT/New Mint Folder" "$MINT_ROOT/Existing Folder" "$ARCHIVE_ROOT/Legacy/New Archive Folder"
printf 'payload\n' > "$MINT_ROOT/New Mint Folder/README.txt"
printf 'payload\n' > "$MINT_ROOT/Existing Folder/README.txt"
printf 'payload\n' > "$ARCHIVE_ROOT/Legacy/New Archive Folder/README.txt"

echo "operator storage surface sync tests"
echo "════════════════════════════════════════"

echo ""
echo "── T1: run-once processes new outbox items and quarantines destination conflicts ──"
t1_out="$(
  OPERATOR_STORAGE_SURFACE_CONTRACT="$CONTRACT" \
  OPERATOR_STORAGE_SYNC_RCLONE_BIN="$RCLONE_STUB" \
  "$SYNC_BIN" run-once --brief
)"
assert_contains "$t1_out" "status=warn" "run-once warns when conflicts were quarantined"
assert_contains "$t1_out" "mint_conflicts=1" "mint conflict count surfaced"
assert_contains "$t1_out" "archives_pending=0" "archive pending drained"
[[ ! -e "$MINT_ROOT/New Mint Folder" ]] && pass "mint synced item removed from outbox" || fail "mint synced item removed from outbox"
[[ -d "$HOME/Operator Sync/.conflicts/Mint/operator-drop/Existing Folder" ]] && pass "conflicting mint folder quarantined" || fail "conflicting mint folder quarantined"
[[ ! -e "$ARCHIVE_ROOT/Legacy/New Archive Folder" ]] && pass "archive synced item removed from outbox" || fail "archive synced item removed from outbox"

echo ""
echo "── T2: status reports enabled watched outbox surfaces and launch agent posture ──"
t2_out="$(
  OPERATOR_STORAGE_SURFACE_CONTRACT="$CONTRACT" \
  OPERATOR_STORAGE_SYNC_RCLONE_BIN="$RCLONE_STUB" \
  "$SYNC_BIN" status --json
)"
assert_contains "$t2_out" "\"enabled_surfaces\": 2" "two watched outbox surfaces enabled"
assert_contains "$t2_out" "\"state\": \"missing\"" "missing launch agent is visible"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
