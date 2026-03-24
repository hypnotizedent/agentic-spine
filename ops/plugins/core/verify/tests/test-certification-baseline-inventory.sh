#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SCRIPT="$ROOT/ops/plugins/core/verify/bin/certification-baseline-inventory"
source "${SPINE_ROOT:-$ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

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

echo "certification baseline inventory tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

make_repo() {
  local repo="$1"
  git init -q "$repo"
  git -C "$repo" config user.name "Test User"
  git -C "$repo" config user.email "test@example.com"
}

seed_repo() {
  local repo="$1"
  mkdir -p "$repo/docs/reference/generated" "$repo/ops/bindings" "$repo/docs/agents"
  cat > "$repo/docs/reference/generated/demo.md" <<'MD'
---
status: generated
authority_state: projection
projection_of: [ops/bindings/demo.yaml]
---
MD
  cat > "$repo/ops/bindings/demo.yaml" <<'YAML'
---
status: authoritative
owner: "@test"
YAML
  cat > "$repo/docs/agents/plain.md" <<'MD'
# plain doc
MD
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "seed"
}

SPINE_REPO="$tmpdir/spine"
FOUNDATION_REPO="$tmpdir/foundation"
make_repo "$SPINE_REPO"
make_repo "$FOUNDATION_REPO"
seed_repo "$SPINE_REPO"
seed_repo "$FOUNDATION_REPO"

json_out="$tmpdir/report.json"
md_out="$tmpdir/report.md"
"$SCRIPT" \
  --repo spine="$SPINE_REPO" \
  --repo foundation="$FOUNDATION_REPO" \
  --json-out "$json_out" \
  --markdown-out "$md_out" >/dev/null

assert_eq "$(python3 - "$json_out" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
print(payload["combined"]["tracked_files"])
PY
)" "6" "combined tracked file count"

assert_eq "$(python3 - "$json_out" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
print(payload["combined"]["classification_counts"].get("projection", 0))
PY
)" "2" "projection count"

assert_eq "$(python3 - "$json_out" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
print(payload["combined"]["classification_counts"].get("authority", 0))
PY
)" "2" "authority count"

assert_eq "$(python3 - "$json_out" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
print(payload["combined"]["classification_counts"].get("projection-candidate", 0))
PY
)" "0" "projection-candidate count"

assert_eq "$(python3 - "$json_out" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
print(payload["combined"]["inline_certification_allowed"])
PY
)" "2" "inline certification allowed count"

assert_eq "$(python3 - "$json_out" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
print(payload["repos"][0]["tracked_files"])
PY
)" "3" "spine repo tracked count"

assert_eq "$(python3 - "$json_out" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
print(payload["repos"][1]["tracked_files"])
PY
)" "3" "foundation repo tracked count"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
