#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
TOOLS_PY="$ROOT/../workbench/agents/microsoft/tools/microsoft_tools.py"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$TOOLS_PY" ]] || fail "missing microsoft tools script"

result_json="$(python3 - <<'PY' "$TOOLS_PY"
import argparse
import importlib.machinery
import importlib.util
import json
import sys
from pathlib import Path

tools_path = Path(sys.argv[1])
loader = importlib.machinery.SourceFileLoader("microsoft_tools_module", str(tools_path))
spec = importlib.util.spec_from_loader("microsoft_tools_module", loader)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


class FakeClient:
    def __init__(self) -> None:
        self.requests = []

    def request(self, method, path, *, query=None, payload=None, extra_headers=None, expected=(200, 201, 202, 204)):
        self.requests.append(
            {
                "method": method,
                "path": path,
                "query": query or {},
                "payload": payload,
                "headers": extra_headers or {},
            }
        )
        if path == "/me/mailFolders":
            return {
                "value": [
                    {
                        "id": "inbox-id",
                        "displayName": "Inbox",
                        "totalItemCount": 12,
                        "childFolderCount": 0,
                        "unreadItemCount": 3,
                    },
                    {
                        "id": "junk-id",
                        "displayName": "Junk Email",
                        "totalItemCount": 4,
                        "childFolderCount": 0,
                        "unreadItemCount": 4,
                    },
                ]
            }
        if path == "/me/mailFolders/junk-id/messages":
            return {
                "value": [
                    {
                        "id": "MSG-1",
                        "subject": "Advisors Needed",
                        "from": {"emailAddress": {"address": "sales@boardsi.com"}},
                        "receivedDateTime": "2026-03-17T07:00:00Z",
                        "isRead": False,
                        "bodyPreview": "Your profile is a good fit.",
                        "conversationId": "CONV-1",
                        "parentFolderId": "junk-id",
                    }
                ]
            }
        if path == "/me/mailFolders" and payload == {"displayName": "Supplier Marketing"}:
            return {
                "id": "supplier-id",
                "displayName": "Supplier Marketing",
                "totalItemCount": 0,
                "childFolderCount": 0,
                "unreadItemCount": 0,
            }
        raise AssertionError(path)

    def request_full_url(self, method, url, *, expected=(200,)):
        raise AssertionError(f"unexpected pagination request: {url}")


client = FakeClient()
folders = module.mail_folders(client, argparse.Namespace(mailbox="team@mintprints.com"))
folder_messages = module.mail_folder_messages(
    client,
    argparse.Namespace(mailbox="team@mintprints.com", folder="junk", top=5, order="oldest_first"),
)
folder_ensured = module.mail_folder_ensure(
    client,
    argparse.Namespace(mailbox="team@mintprints.com", display_name="Supplier Marketing", parent_folder=""),
)
assert folders["total_folders"] == 2
assert folders["total_messages"] == 16
assert folder_messages["folderDisplayName"] == "Junk Email"
assert folder_messages["folderId"] == "junk-id"
assert folder_messages["order"] == "oldest_first"
assert folder_messages["value"][0]["id"] == "MSG-1"
assert folder_ensured["displayName"] == "Supplier Marketing"
assert folder_ensured["created"] is True
message_requests = [request for request in client.requests if request["path"] == "/me/mailFolders/junk-id/messages"]
create_requests = [request for request in client.requests if request["path"] == "/me/mailFolders" and request["payload"] == {"displayName": "Supplier Marketing"}]
assert message_requests, client.requests
assert message_requests[-1]["query"]["$orderby"] == "receivedDateTime asc"
assert create_requests, client.requests
print(json.dumps({"folders": folders, "folder_messages": folder_messages, "folder_ensured": folder_ensured}))
PY
)"

echo "$result_json" | jq -e '.folders.total_folders == 2' >/dev/null || fail "mail_folders should enumerate folders"
echo "$result_json" | jq -e '.folder_messages.folderDisplayName == "Junk Email"' >/dev/null || fail "mail_folder_messages should resolve folder aliases"
echo "$result_json" | jq -e '.folder_messages.value | length == 1' >/dev/null || fail "mail_folder_messages should return folder-scoped messages"
echo "$result_json" | jq -e '.folder_ensured.displayName == "Supplier Marketing"' >/dev/null || fail "mail_folder_ensure should create missing folders"
pass "microsoft folder capabilities enumerate folders and list folder-scoped messages"
