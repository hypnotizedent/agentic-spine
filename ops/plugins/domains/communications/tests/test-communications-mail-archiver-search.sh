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

fixture="$tmp/messages.json"
cat >"$fixture" <<'JSON'
{
  "messages": [
    {
      "id": "mailarchiver:101",
      "archiveMailbox": "team@mintprints.com",
      "internetMessageId": "<kyle-orig@example.com>",
      "receivedDateTime": "2026-03-13T16:16:00Z",
      "subject": "FW: Print Request",
      "from": {"emailAddress": {"address": "kyle@example.com", "name": "Kyle"}},
      "toRecipients": [{"emailAddress": {"address": "info@mintprints.com"}}],
      "ccRecipients": [],
      "rawHeaders": "Message-ID: <kyle-orig@example.com>\\nIn-Reply-To: <kyle-parent@example.com>\\nReferences: <kyle-parent@example.com>",
      "bodyPreview": "Client will have everything finalized by March 20.",
      "body": {"contentType": "Text", "content": "Client will have everything finalized by March 20."}
    },
    {
      "id": "mailarchiver:102",
      "archiveMailbox": "ronny@mintprints.com",
      "internetMessageId": "<kyle-followup@example.com>",
      "receivedDateTime": "2026-03-14T10:11:00Z",
      "subject": "Re: Print Request",
      "from": {"emailAddress": {"address": "kyle@example.com", "name": "Kyle"}},
      "toRecipients": [{"emailAddress": {"address": "ronny@mintprints.com"}}],
      "ccRecipients": [],
      "bodyPreview": "Still waiting on the final counts.",
      "body": {"contentType": "Text", "content": "Still waiting on the final counts."}
    },
    {
      "id": "mailarchiver:103",
      "archiveMailbox": "team@mintprints.com",
      "internetMessageId": "<other@example.com>",
      "receivedDateTime": "2026-03-14T11:11:00Z",
      "subject": "Different Customer",
      "from": {"emailAddress": {"address": "other@example.com", "name": "Other"}},
      "toRecipients": [{"emailAddress": {"address": "team@mintprints.com"}}],
      "ccRecipients": [],
      "bodyPreview": "Unrelated history",
      "body": {"contentType": "Text", "content": "Unrelated history"}
    }
  ]
}
JSON

export COMMUNICATIONS_MAIL_ARCHIVER_SEARCH_FIXTURE_JSON="$fixture"

json_out="$("$SEARCH" --query kyle@example.com --mailbox team@mintprints.com --mailbox ronny@mintprints.com --top 5 --include-raw-headers --json)"

[[ "$(echo "$json_out" | jq -r '.data.messages | length')" == "2" ]] || fail "expected two Kyle history hits"
[[ "$(echo "$json_out" | jq -r '.data.messages[0].archiveMailbox')" == "ronny@mintprints.com" ]] || fail "most recent archived mailbox should sort first"
[[ "$(echo "$json_out" | jq -r '.data.messages[1].archiveMailbox')" == "team@mintprints.com" ]] || fail "team archive should be retained"
[[ "$(echo "$json_out" | jq -r '.data.messages[1].body.content')" == "Client will have everything finalized by March 20." ]] || fail "body content should survive fixture search"
[[ "$(echo "$json_out" | jq -r '.data.messages[1].rawHeaders')" == *"In-Reply-To"* ]] || fail "raw headers should be available when requested"

pass "communications-mail-archiver-search filters mailbox-scoped archive history and can include raw headers for thread reconstruction"
