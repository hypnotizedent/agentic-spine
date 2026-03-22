#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init
MAILBOX_EXEC="$ROOT/ops/plugins/providers/microsoft/bin/microsoft-cap-exec"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (missing: $needle)"
  fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.wt/agentic-spine/test-lane/.git"
mkdir -p "$tmpdir/.wt/workbench/test-lane/agents/microsoft/tools"

cat >"$tmpdir/.wt/workbench/test-lane/agents/microsoft/tools/microsoft_tools.py" <<'PY'
#!/usr/bin/env python3
import json
import sys
from pathlib import Path

print(json.dumps({
    "tool_path": str(Path(__file__).resolve()),
    "argv": sys.argv[1:],
}))
PY
chmod +x "$tmpdir/.wt/workbench/test-lane/agents/microsoft/tools/microsoft_tools.py"

cat >"$tmpdir/fake-secrets-exec" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--" ]]; then
    shift
    break
  fi
  shift
done
exec "$@"
SH
chmod +x "$tmpdir/fake-secrets-exec"

cat >"$tmpdir/fake-token-exec" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exec "$@"
SH
chmod +x "$tmpdir/fake-token-exec"

out="$(
  SPINE_TARGET_REPO="$tmpdir/.wt/agentic-spine/test-lane" \
  SPINE_WORKSPACE_ROOT="$tmpdir" \
  SECRETS_EXEC="$tmpdir/fake-secrets-exec" \
  TOKEN_EXEC="$tmpdir/fake-token-exec" \
  MAILBOX_RECEIPT_ROOT="$tmpdir/receipts" \
  "$MAILBOX_EXEC" mail_get --message-id msg-1 --mailbox team@mintprints.com
)"

assert_contains "$out" "$tmpdir/.wt/workbench/test-lane/agents/microsoft/tools/microsoft_tools.py" "paired workbench tool path selected from target-lane peer"
assert_contains "$out" "\"mail_get\"" "operation forwarded to resolved tool"

echo "tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
