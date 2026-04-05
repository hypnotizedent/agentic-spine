#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SCRIPT="$ROOT/ops/plugins/core/lifecycle/bin/git-worktree-hygiene"
POLICY="$ROOT/ops/bindings/git.worktree.hygiene.policy.yaml"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

json_field_equals() {
  local file="$1"
  local expression="$2"
  local expected="$3"
  local label="$4"
  local actual
  actual="$(
    python3 - "$file" "$expression" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
expression = sys.argv[2]
print(eval(expression, {"__builtins__": {}}, {"payload": payload}))
PY
  )" || {
    fail "$label"
    return
  }

  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label"
  fi
}

json_remote_branch_classification() {
  local file="$1"
  local branch="$2"
  local expected="$3"
  local label="$4"
  local actual
  actual="$(
    python3 - "$file" "$branch" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
branch = sys.argv[2]
for item in payload["remote_branches"]:
    if item["branch"] == branch:
        print(item["classification"])
        raise SystemExit(0)
raise SystemExit(2)
PY
  )" || {
    fail "$label"
    return
  }

  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label"
  fi
}

json_actions_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if python3 - "$file" "$needle" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
needle = sys.argv[2]
raise SystemExit(0 if any(needle in action for action in payload["actions"]) else 1)
PY
  then
    pass "$label"
  else
    fail "$label"
  fi
}

json_actions_not_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if python3 - "$file" "$needle" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
needle = sys.argv[2]
raise SystemExit(1 if any(needle in action for action in payload["actions"]) else 0)
PY
  then
    pass "$label"
  else
    fail "$label"
  fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
remote="$tmpdir/origin.git"
repo="$tmpdir/repo"
wt="$tmpdir/wt-prunable"
dry_json="$tmpdir/dry.json"
apply_json="$tmpdir/apply.json"

git init --bare "$remote" >/dev/null
git init "$repo" >/dev/null
git -C "$repo" config user.name "Codex Test"
git -C "$repo" config user.email "codex-test@example.com"

echo "seed" > "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -m "seed main" >/dev/null
git -C "$repo" branch -M main
git -C "$repo" remote add origin "$remote"
git -C "$repo" push -u origin main >/dev/null
git -C "$repo" fetch origin >/dev/null

git -C "$repo" checkout -b codex/WAVE-20260405-01 >/dev/null
echo "landed wave" >> "$repo/README.md"
git -C "$repo" commit -am "landed wave" >/dev/null
git -C "$repo" push -u origin codex/WAVE-20260405-01 >/dev/null
git -C "$repo" fetch origin --prune >/dev/null
git -C "$repo" checkout main >/dev/null
git -C "$repo" merge --ff-only codex/WAVE-20260405-01 >/dev/null
git -C "$repo" push origin main >/dev/null
git -C "$repo" fetch origin --prune >/dev/null

git -C "$repo" checkout -b codex/WAVE-20260405-02 >/dev/null
echo "unlanded wave" >> "$repo/UNLANDED.md"
git -C "$repo" add UNLANDED.md
git -C "$repo" commit -m "unlanded wave" >/dev/null
git -C "$repo" push -u origin codex/WAVE-20260405-02 >/dev/null
git -C "$repo" fetch origin --prune >/dev/null
git -C "$repo" checkout main >/dev/null

git -C "$repo" checkout -b codex/preserve-on-main-test >/dev/null
echo "preserve" >> "$repo/PRESERVE.md"
git -C "$repo" add PRESERVE.md
git -C "$repo" commit -m "preserve branch" >/dev/null
git -C "$repo" push -u origin codex/preserve-on-main-test >/dev/null
git -C "$repo" fetch origin --prune >/dev/null
git -C "$repo" checkout main >/dev/null

git -C "$repo" checkout -b codex/v3-prunable-worktree >/dev/null
echo "prunable worktree" >> "$repo/WORKTREE.md"
git -C "$repo" add WORKTREE.md
git -C "$repo" commit -m "prunable worktree" >/dev/null
git -C "$repo" push -u origin codex/v3-prunable-worktree >/dev/null
git -C "$repo" fetch origin --prune >/dev/null
git -C "$repo" checkout main >/dev/null
git -C "$repo" merge --ff-only codex/v3-prunable-worktree >/dev/null
git -C "$repo" push origin main >/dev/null
git -C "$repo" fetch origin --prune >/dev/null
git -C "$repo" worktree add "$wt" codex/v3-prunable-worktree >/dev/null

echo "git worktree hygiene tests"
echo "════════════════════════════════════════"

python3 "$SCRIPT" --root "$repo" --policy "$POLICY" --json > "$dry_json"
json_field_equals "$dry_json" 'payload["mode"]' "dry_run" "dry-run is default"
json_field_equals "$dry_json" 'payload["summary"]["remote_branches"]["prunable_landed"]' "2" "dry-run finds prunable landed items"
json_remote_branch_classification "$dry_json" "codex/WAVE-20260405-01" "prunable_landed" "landed wave is prunable"
json_remote_branch_classification "$dry_json" "codex/WAVE-20260405-02" "unknown" "unlanded wave is refused"
json_remote_branch_classification "$dry_json" "codex/preserve-on-main-test" "preserve" "preserve branch stays preserved"

if git -C "$repo" ls-remote --heads origin codex/WAVE-20260405-01 | grep -Fq 'codex/WAVE-20260405-01'; then
  pass "dry-run does not delete landed wave branch"
else
  fail "dry-run does not delete landed wave branch"
fi

python3 "$SCRIPT" --root "$repo" --policy "$POLICY" --apply --json > "$apply_json"
json_actions_contains "$apply_json" "deleted_remote_branch=codex/WAVE-20260405-01" "apply prunes landed wave branch"
json_actions_contains "$apply_json" "removed_worktree=" "apply removes prunable landed worktree"
json_actions_not_contains "$apply_json" "deleted_remote_branch=codex/WAVE-20260405-02" "apply refuses unlanded wave prune"
json_actions_not_contains "$apply_json" "deleted_remote_branch=codex/preserve-on-main-test" "apply refuses preserve branch prune"

if ! git -C "$repo" ls-remote --heads origin codex/WAVE-20260405-01 | grep -Fq 'codex/WAVE-20260405-01'; then
  pass "landed wave branch deleted on apply"
else
  fail "landed wave branch deleted on apply"
fi

if git -C "$repo" ls-remote --heads origin codex/WAVE-20260405-02 | grep -Fq 'codex/WAVE-20260405-02'; then
  pass "unlanded wave branch is retained"
else
  fail "unlanded wave branch is retained"
fi

if git -C "$repo" ls-remote --heads origin codex/preserve-on-main-test | grep -Fq 'codex/preserve-on-main-test'; then
  pass "preserve branch is retained"
else
  fail "preserve branch is retained"
fi

if [[ ! -d "$wt" ]]; then
  pass "prunable landed worktree removed on apply"
else
  fail "prunable landed worktree removed on apply"
fi

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
