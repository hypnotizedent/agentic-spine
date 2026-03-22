#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init
SCRIPT="$ROOT/ops/plugins/domains/mint/bin/customer-artwork-revision-prepare"

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

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fake_ops="$tmpdir/ops"
cat >"$fake_ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cap="$3"
shift 4 || true
case "$cap" in
  microsoft.mail.get)
    cat <<'JSON'
{"id":"MSG-SOURCE","subject":"Need one revision","bodyPreview":"Please move the text up a little.","from":{"emailAddress":{"address":"customer@example.com","name":"Customer"}}}
JSON
    ;;
  mint.customer.forwarded.attachment.resolve)
    cat <<'JSON'
{"status":"selected","selected_attachment":{"attachment_name":"proof.pdf","attachment_id":"ATT-1","message_id":"MSG-SOURCE"},"placement":{"resolved_file_path":"/Users/test/MinIO/artwork-intake/operator-drop/13825 Papa/2. Proofs/proof.pdf","resolved_target_key":"operator-drop/13825 Papa/2. Proofs"}}
JSON
    ;;
  *)
    echo "unsupported capability: $cap" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$fake_ops"

json_out="$(
  OPS_BIN="$fake_ops" \
  SPINE_STATE="$tmpdir/state" \
  python3 "$SCRIPT" --message-id MSG-SOURCE --mailbox team@mintprints.com --context "13825 Papa" --json
)"
assert_contains "$json_out" "\"status\": \"ok\"" "revision prepare succeeds"
assert_contains "$json_out" "\"handoff_state\": \"ready_for_artie\"" "revision handoff is ready"
assert_contains "$json_out" "\"resolved_target_key\": \"operator-drop/13825 Papa/2. Proofs\"" "selected artwork ref includes placed proof"

echo "tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
