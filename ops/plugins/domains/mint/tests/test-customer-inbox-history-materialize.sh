#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
MATERIALIZE="$ROOT/ops/plugins/domains/mint/bin/customer-inbox-history-materialize"
CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.history.materialize.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$MATERIALIZE" ]] || fail "missing customer-inbox-history-materialize executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_INBOX_HISTORY_MATERIALIZE_CONTRACT="$CONTRACT"
mkdir -p "$SPINE_ROOT" "$SPINE_STATE"

fixture="$tmp/archive.json"
cat >"$fixture" <<'JSON'
{
  "data": {
    "messages": [
      {
        "id": "mailarchiver:501",
        "archivedRowId": "501",
        "archiveMailbox": "team@mintprints.com",
        "internetMessageId": "<green-001@example.com>",
        "subject": "Re: Green School Student T-shirts",
        "receivedDateTime": "2026-01-12 13:35:00",
        "from": {"emailAddress": {"address": "lilperez@fiu.edu", "name": "Lilian Perez"}},
        "toRecipients": [{"emailAddress": {"address": "info@mintprints.com", "name": "Mint Prints Team"}}],
        "ccRecipients": [],
        "rawHeaders": "Message-ID: <green-001@example.com>\nIn-Reply-To: <green-000@example.com>\nReferences: <green-root@example.com> <green-000@example.com>\nThread-Topic: Green School Student T-shirts",
        "body": {"contentType": "Text", "content": "Following up on the Green School shirt design."},
        "bodyPreview": "Following up on the Green School shirt design.",
        "hasAttachments": false
      },
      {
        "id": "mailarchiver:502",
        "archivedRowId": "502",
        "archiveMailbox": "team@mintprints.com",
        "internetMessageId": "<green-002@example.com>",
        "subject": "Re: Green School Student T-shirts",
        "receivedDateTime": "2026-01-15 02:31:13",
        "from": {"emailAddress": {"address": "info@mintprints.com", "name": "Mint Prints Team"}},
        "toRecipients": [{"emailAddress": {"address": "lilperez@fiu.edu", "name": "Lilian Perez"}}],
        "ccRecipients": [],
        "body": {"contentType": "HTML", "content": "<div>We can help clean the design.</div>"},
        "bodyPreview": "We can help clean the design.",
        "hasAttachments": true
      },
      {
        "id": "mailarchiver:502b",
        "archivedRowId": "502b",
        "archiveMailbox": "team@mintprints.com",
        "internetMessageId": "green-002@example.com",
        "subject": "Re: Green School Student T-shirts",
        "receivedDateTime": "2026-01-15 02:31:14",
        "from": {"emailAddress": {"address": "info@mintprints.com", "name": "Mint Prints Team"}},
        "toRecipients": [{"emailAddress": {"address": "lilperez@fiu.edu", "name": "Lilian Perez"}}],
        "ccRecipients": [],
        "body": {"contentType": "HTML", "content": "<div>We can help clean the design.</div>"},
        "bodyPreview": "We can help clean the design.",
        "hasAttachments": true
      },
      {
        "id": "mailarchiver:503",
        "archivedRowId": "503",
        "archiveMailbox": "team@mintprints.com",
        "internetMessageId": "<green-003@example.com>",
        "subject": "Re: Green School Student T-shirts",
        "receivedDateTime": "2026-03-16 17:27:08",
        "from": {"emailAddress": {"address": "lilperez@fiu.edu", "name": "Lilian Perez"}},
        "toRecipients": [{"emailAddress": {"address": "team@mintprints.com", "name": "Mint Team"}}],
        "ccRecipients": [],
        "body": {"contentType": "Text", "content": "Could we still have it cleaned up?"},
        "bodyPreview": "Could we still have it cleaned up?",
        "hasAttachments": false
      }
    ]
  }
}
JSON

export MINT_CUSTOMER_HISTORY_MATERIALIZE_FIXTURE_JSON="$fixture"
export MINT_CUSTOMER_HISTORY_MATERIALIZE_FAKE_OUTLOOK_ROOT="$tmp/outlook"

preview_json="$("$MATERIALIZE" --query 'Green School Student T-shirts' --mailbox team@mintprints.com --top 10 --json)"
[[ "$(echo "$preview_json" | jq -r '.status')" == "preview" ]] || fail "preview should stay preview"
[[ "$(echo "$preview_json" | jq -r '.archived_message_count')" == "4" ]] || fail "preview should see four archived rows"
[[ "$(echo "$preview_json" | jq -r '.folder_path')" == "Recovered History/Green School Student T-shirts" ]] || fail "preview should derive a stable recovered folder path"

apply_json="$("$MATERIALIZE" --query 'Green School Student T-shirts' --mailbox team@mintprints.com --top 10 --apply --json)"
[[ "$(echo "$apply_json" | jq -r '.status')" == "applied" ]] || fail "apply should report applied"
[[ "$(echo "$apply_json" | jq -r '.materialized_count')" == "3" ]] || fail "apply should materialize only the three unique messages"
[[ "$(echo "$apply_json" | jq -r '.skipped_existing_count')" == "1" ]] || fail "first apply should skip the duplicate archive row"

target_dir="$tmp/outlook/Recovered History/Green School Student T-shirts"
[[ -d "$target_dir" ]] || fail "fake outlook folder should be created"
eml_count="$(find "$target_dir" -name '*.eml' | wc -l | tr -d ' ')"
[[ "$eml_count" == "3" ]] || fail "expected three materialized .eml files"

sample_file="$(find "$target_dir" -name '*.eml' | sort | head -n 1)"
grep -F 'Subject: Re: Green School Student T-shirts' "$sample_file" >/dev/null || fail "materialized message should preserve subject"
grep -F 'From: Lilian Perez <lilperez@fiu.edu>' "$sample_file" >/dev/null || fail "materialized message should preserve sender header"
grep -F 'In-Reply-To: <green-000@example.com>' "$sample_file" >/dev/null || fail "materialized message should preserve thread reply header"
grep -F 'References: <green-root@example.com> <green-000@example.com>' "$sample_file" >/dev/null || fail "materialized message should preserve references header"

attachment_file="$(find "$target_dir" -name '*green-002*' -o -name '*.eml' | sort | sed -n '2p')"
grep -F 'Attachment payloads are not retained in the current mail-archiver model.' "$attachment_file" >/dev/null || fail "attachment-bearing archived mail should include the restore warning"

rerun_json="$("$MATERIALIZE" --query 'Green School Student T-shirts' --mailbox team@mintprints.com --top 10 --apply --json)"
[[ "$(echo "$rerun_json" | jq -r '.materialized_count')" == "0" ]] || fail "rerun should not create duplicates"
[[ "$(echo "$rerun_json" | jq -r '.skipped_existing_count')" == "4" ]] || fail "rerun should skip all archived rows once the unique keys are present"

rm "$(find "$target_dir" -name '*.eml' | sort | head -n 1)"

repair_json="$("$MATERIALIZE" --query 'Green School Student T-shirts' --mailbox team@mintprints.com --top 10 --apply --json)"
[[ "$(echo "$repair_json" | jq -r '.materialized_count')" == "1" ]] || fail "apply should recreate missing live folder items even when runtime index is stale"
[[ "$(find "$target_dir" -name '*.eml' | wc -l | tr -d ' ')" == "3" ]] || fail "repair rerun should restore the missing file"

pass "customer-inbox-history-materialize rebuilds archived thread scaffolds, preserves thread headers, and repairs missing live items"
