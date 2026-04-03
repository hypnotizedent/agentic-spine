#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
UPDATE="$ROOT/ops/plugins/core/lifecycle/bin/loops-continuity-update"
BRIDGE="$ROOT/ops/plugins/core/lifecycle/bin/loops-authority-bridge"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (expected='$expected', got='$actual')"
  fi
}

assert_file_exists() {
  local file="$1" label="$2"
  if [[ -f "$file" ]]; then
    pass "$label"
  else
    fail "$label"
  fi
}

assert_not_exists() {
  local file="$1" label="$2"
  if [[ ! -e "$file" ]]; then
    pass "$label"
  else
    fail "$label"
  fi
}

json_eval() {
  local json_file="$1" expr="$2"
  python3 - "$json_file" "$expr" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
expr = sys.argv[2]
print(eval(expr, {"payload": payload}))
PY
}

scope_frontmatter_eval() {
  local scope_file="$1" expr="$2"
  python3 - "$scope_file" "$expr" <<'PY'
import sys
import yaml
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
lines = text.splitlines()
payload = {}
if lines and lines[0].strip() == "---":
    end_idx = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end_idx = idx
            break
    if end_idx is not None:
        payload = yaml.safe_load("\n".join(lines[1:end_idx])) or {}
expr = sys.argv[2]
print(eval(expr, {"payload": payload}))
PY
}

echo "loops authority repairs legacy scope residue"
echo "══════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT
STATE="$TMPDIR_BASE/state"
mkdir -p "$STATE/loop-scopes"

TARGET_LOOP_ID="LOOP-TEST-TARGET-20260403"
TARGET_SCOPE="$STATE/loop-scopes/${TARGET_LOOP_ID}.scope.md"
ARCHIVED_SCOPE="$STATE/archive/closed-loop-scopes/LOOP-TEST-LEGACY-CLOSED-20260221.scope.md"
ACTIVE_SCOPE="$STATE/loop-scopes/LOOP-TEST-LEGACY-ACTIVE-20260321.scope.md"
QUARANTINE_SCOPE="$STATE/quarantine/loop-scopes/LOOP-TEST-INVALID-AUTH-20260210.scope.md"
QUARANTINE_REASON="$STATE/quarantine/loop-scopes/LOOP-TEST-INVALID-AUTH-20260210.scope.md.reason.yaml"

cat > "$TARGET_SCOPE" <<EOF
---
loop_id: $TARGET_LOOP_ID
created: 2026-04-03
status: active
owner: "@ronny"
scope: spine
priority: high
horizon: now
execution_readiness: runnable
execution_mode: single_worker
objective: Drive projection so legacy residue repair can run.
next_action: ""
evidence_refs: []
---

# Loop Scope: $TARGET_LOOP_ID
EOF

cat > "$STATE/loop-scopes/LOOP-TEST-LEGACY-CLOSED-20260221.scope.md" <<'EOF'
# LOOP-TEST-LEGACY-CLOSED-20260221

> **Status:** closed
> **Created:** 2026-02-21
> **Owner:** @ronny

## Objective

Preserve a legacy closed scope so projection can normalize it into the archive.
EOF

cat > "$ACTIVE_SCOPE" <<'EOF'
# LOOP-TEST-LEGACY-ACTIVE-20260321

- status: active
- opened_at: 2026-03-21
- owner: codex

## Objective

Keep this legacy active loop live because it still exposes an explicit next action.

## Next Action

Resume the retained follow-on work from the normalized live scope.
EOF

cat > "$STATE/loop-scopes/LOOP-TEST-INVALID-AUTH-20260210.scope.md" <<'EOF'
---
status: authoritative
owner: "@ronny"
scope: loop-scope
loop_id: OL_BAD_TEST
---

# Loop Scope: OL_BAD_TEST
EOF

UPDATE_JSON="$TMPDIR_BASE/update.json"
env \
  SPINE_STATE="$STATE" \
  SPINE_CAP_RUN_KEY="CAP-20260403-TEST__loops.continuity.update__Rrepair01" \
  OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
  "$UPDATE" \
    --loop-id "$TARGET_LOOP_ID" \
    --next-action "Run the bounded scope repair pass to completion." \
    --no-joined-state \
    --json > "$UPDATE_JSON"

assert_eq "$(json_eval "$UPDATE_JSON" "payload['projection']['residue_repair']['detected']")" "3" "projection detects all legacy residue fixtures"
assert_eq "$(json_eval "$UPDATE_JSON" "payload['projection']['residue_repair']['repaired_archived']")" "1" "projection archives repairable terminal legacy scope"
assert_eq "$(json_eval "$UPDATE_JSON" "payload['projection']['residue_repair']['repaired_live']")" "1" "projection keeps repairable active legacy scope live"
assert_eq "$(json_eval "$UPDATE_JSON" "payload['projection']['residue_repair']['quarantined']")" "1" "projection quarantines invalid non-loop residue"

assert_file_exists "$ARCHIVED_SCOPE" "legacy closed scope is archived"
assert_not_exists "$STATE/loop-scopes/LOOP-TEST-LEGACY-CLOSED-20260221.scope.md" "legacy closed scope leaves live dir"
assert_eq "$(scope_frontmatter_eval "$ARCHIVED_SCOPE" "payload['status']")" "closed" "archived legacy scope gains canonical closed status"

assert_file_exists "$ACTIVE_SCOPE" "legacy active scope stays live"
assert_eq "$(scope_frontmatter_eval "$ACTIVE_SCOPE" "payload['status']")" "active" "legacy active scope gains canonical active status"
assert_eq "$(scope_frontmatter_eval "$ACTIVE_SCOPE" "payload['next_action']")" "Resume the retained follow-on work from the normalized live scope." "legacy active scope preserves next action"

assert_file_exists "$QUARANTINE_SCOPE" "invalid authoritative residue is quarantined"
assert_file_exists "$QUARANTINE_REASON" "invalid authoritative residue gets an exact reason file"
assert_not_exists "$STATE/loop-scopes/LOOP-TEST-INVALID-AUTH-20260210.scope.md" "invalid authoritative residue leaves live dir"

QUERY_JSON="$TMPDIR_BASE/query.json"
env SPINE_STATE="$STATE" python3 "$BRIDGE" query --id OL_BAD_TEST > "$QUERY_JSON"
assert_eq "$(json_eval "$QUERY_JSON" "payload['exists']")" "False" "invalid authoritative residue is not retained in loop authority"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
