#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init
SCRIPT="$ROOT/ops/plugins/domains/mint/bin/customer-forwarded-attachment-resolve"

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
echo "Receipt: /tmp/${cap}.receipt.md"
case "$cap" in
  microsoft.mail.get)
    cat <<'JSON'
{"id":"MSG-SOURCE","subject":"PapaPalooza revision","bodyPreview":"Please use the attached latest art.","from":{"emailAddress":{"address":"customer@example.com","name":"Papa"}}}
JSON
    ;;
  communications.mail.search)
    cat <<'JSON'
{"data":{"microsoft":{"value":[{"id":"MSG-RELATED","subject":"older art","bodyPreview":"bad version","from":{"emailAddress":{"address":"customer@example.com","name":"Papa"}}}]}}}
JSON
    ;;
  microsoft.mail.attachments.list)
    message_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="${2:-}"; shift 2 ;;
        *) shift ;;
      esac
    done
    if [[ "$message_id" == "MSG-SOURCE" ]]; then
      cat <<'JSON'
{"value":[
  {"id":"ATT-GOOD","name":"papapalooza-final.pdf","contentType":"application/pdf","size":10,"isInline":false},
  {"id":"ATT-BAD","name":"papapalooza-old-proof.pdf","contentType":"application/pdf","size":10,"isInline":false}
]}
JSON
    else
      cat <<'JSON'
{"value":[{"id":"ATT-OLDER","name":"older-proof.pdf","contentType":"application/pdf","size":10,"isInline":false}]}
JSON
    fi
    ;;
  microsoft.mail.attachment.download)
    output_dir=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --output-dir) output_dir="${2:-}"; shift 2 ;;
        *) shift ;;
      esac
    done
    mkdir -p "$output_dir"
    printf 'pdf' >"$output_dir/papapalooza-final.pdf"
    cat <<JSON
{"output_file":"$output_dir/papapalooza-final.pdf","sha256":"abc123","name":"papapalooza-final.pdf"}
JSON
    ;;
  mint.artwork.place)
    cat <<'JSON'
{"status":"ok","resolved_target_key":"operator-drop/13825 Papa/2. Proofs","resolved_file_path":"/Users/test/MinIO/artwork-intake/operator-drop/13825 Papa/2. Proofs/papapalooza-final.pdf","record_file":"/tmp/place-record.json"}
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
  python3 "$SCRIPT" --message-id MSG-SOURCE --mailbox team@mintprints.com --context "13825 PapaPalooza" --json
)"
assert_contains "$json_out" "\"status\": \"selected\"" "forwarded attachment resolve selects one attachment"
assert_contains "$json_out" "\"attachment_name\": \"papapalooza-final.pdf\"" "best attachment chosen"
assert_contains "$json_out" "\"resolved_target_key\": \"operator-drop/13825 Papa/2. Proofs\"" "placement payload returned"

echo "tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
