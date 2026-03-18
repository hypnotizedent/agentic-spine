#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
SEARCH="$ROOT/ops/plugins/domains/communications/bin/communications-mail-archiver-search"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$SEARCH" ]] || fail "missing communications-mail-archiver-search executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

contract="$tmp/communications.stack.contract.yaml"
linkage="$tmp/mail.archiver.account.linkage.contract.yaml"
ssh_targets="$tmp/ssh.targets.yaml"
fake_status="$tmp/fake-ssh-target-status"
fake_ssh="$tmp/ssh"
stdin_capture="$tmp/stdin.txt"

cat >"$contract" <<'YAML'
mail_archiver:
  monitoring:
    machine_status_target:
      ssh_target: communications-stack
  database:
    container: mail-archiver-db
    db_name: MailArchiver
YAML

cat >"$linkage" <<'YAML'
accounts:
  - mailbox: team@mintprints.com
    db_account_id: 5
  - mailbox: ronny@mintprints.com
    db_account_id: 3
YAML

cat >"$ssh_targets" <<'YAML'
ssh:
  defaults:
    user: root
    port: 22
    connect_timeout_sec: 5
    batch_mode: true
    strict_host_key_checking: no
    user_known_hosts_file: /dev/null
  targets:
    - id: communications-stack
      host: 127.0.0.1
      user: ubuntu
YAML

cat >"$fake_status" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{"status":"ok","targets":[{"id":"communications-stack","effective_host":"127.0.0.1","status":"ok","path_used":"direct"}]}
JSON
EOF
chmod +x "$fake_status"

cat >"$fake_ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat >"${FAKE_SSH_STDIN_CAPTURE:?}"
cat <<'JSON'
{"row_id":"88","mailbox":"team@mintprints.com","internet_message_id":"<hist@example.com>","subject":"Cove Brewery follow-up","body_text":"Historic row","body_html":"","from_raw":"Customer <customer@example.com>","to_raw":"team@mintprints.com","cc_raw":"","received_utc":"2026-03-16T12:00:00Z","has_attachments":"false"}
JSON
EOF
chmod +x "$fake_ssh"

json_out="$(
  PATH="$tmp:$PATH" \
  COMMUNICATIONS_STACK_CONTRACT="$contract" \
  MAIL_ARCHIVER_LINKAGE_CONTRACT="$linkage" \
  SSH_TARGETS_FILE="$ssh_targets" \
  COMMUNICATIONS_SSH_TARGET_STATUS_BIN="$fake_status" \
  FAKE_SSH_STDIN_CAPTURE="$stdin_capture" \
  "$SEARCH" --query 'cove brewery' --mailbox team@mintprints.com --mailbox ronny@mintprints.com --top 3 --json
)"

[[ "$(echo "$json_out" | jq -r '.data.messages | length')" == "1" ]] || fail "expected one archived message from fake remote query"
[[ "$(echo "$json_out" | jq -r '.data.messages[0].subject')" == "Cove Brewery follow-up" ]] || fail "remote archived subject should survive parsing"
[[ "$(cat "$stdin_capture")" == *"cove brewery"* ]] || fail "remote SQL should be embedded in the SSH-delivered shell script"
[[ "$(cat "$stdin_capture")" == *'IN (5,3)'* || "$(cat "$stdin_capture")" == *'IN (3,5)'* ]] || fail "remote SQL should include governed mailbox account ids"

pass "communications-mail-archiver-search embeds the live SQL in the remote shell script and parses archived rows"
