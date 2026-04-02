#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SCRIPT="$ROOT/ops/plugins/core/lifecycle/bin/git-stage-commit-scoped"

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

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label (expected to contain '$needle')"
  fi
}

create_repo() {
  local repo="$1"
  git init "$repo" >/dev/null
  git -C "$repo" config user.name "Test User"
  git -C "$repo" config user.email "test@example.com"
  printf 'base-a\n' > "$repo/a.txt"
  printf 'base-b\n' > "$repo/b.txt"
  printf 'base-c\n' > "$repo/c.txt"
  git -C "$repo" add a.txt b.txt c.txt
  git -C "$repo" commit -m "base" >/dev/null
  git -C "$repo" branch -M main >/dev/null
}

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo "git-stage-commit-scoped tests"
echo "═══════════════════════════════"

echo ""
echo "── T1: mixed root-main landing is rejected ──"
REPO1="$TMPDIR_BASE/repo-mixed"
create_repo "$REPO1"
printf 'allowed-change\n' >> "$REPO1/a.txt"
printf 'outside-change\n' >> "$REPO1/b.txt"
set +e
T1_OUT="$(env SPINE_ROOT="$REPO1" "$SCRIPT" --path a.txt --message "slice" 2>&1)"
T1_RC=$?
set -e
assert_eq "$(python3 -c "print(1 if int('$T1_RC') > 0 else 0)")" "1" "T1.1: command fails on mixed root-main dirt"
assert_contains "$T1_OUT" "mixed or unrelated dirty state" "T1.2: failure explains mixed root-main rejection"
assert_eq "$(git -C "$REPO1" rev-list --count HEAD)" "1" "T1.3: no commit is created on rejection"
assert_eq "$(git -C "$REPO1" diff --cached --name-only | wc -l | tr -d ' ')" "0" "T1.4: rejection leaves index unchanged"

echo ""
echo "── T2: immutable-source landing accepts exact stash slice ──"
REPO2="$TMPDIR_BASE/repo-treeish"
create_repo "$REPO2"
printf 'slice-a\n' >> "$REPO2/a.txt"
printf 'slice-c\n' >> "$REPO2/c.txt"
git -C "$REPO2" stash push -m "slice source" >/dev/null
assert_eq "$(git -C "$REPO2" stash list | wc -l | tr -d ' ')" "1" "T2.1: source stash exists before landing"
T2_OUT="$(env SPINE_ROOT="$REPO2" "$SCRIPT" --source-treeish 'stash@{0}' --path a.txt --message "land slice" 2>&1)"
assert_contains "$T2_OUT" "status: committed" "T2.2: immutable-source landing commits successfully"
assert_contains "$T2_OUT" "lane_type: root_main_integration" "T2.3: receipt reports root-main lane"
assert_contains "$T2_OUT" "source_treeish: stash@{0}" "T2.4: receipt reports source treeish"
assert_contains "$T2_OUT" "pre_lifecycle_state: clean" "T2.5: clean entry is enforced"
assert_contains "$T2_OUT" "post_lifecycle_state: clean" "T2.6: repo returns to clean after commit"
assert_eq "$(git -C "$REPO2" stash list | wc -l | tr -d ' ')" "1" "T2.7: source stash remains intact"
assert_contains "$(git -C "$REPO2" stash list)" "slice source" "T2.8: source stash identity is preserved"
assert_eq "$(git -C "$REPO2" show --pretty=format: --name-only HEAD | tr -d '\n')" "a.txt" "T2.9: commit lands only the allowlisted slice"
assert_eq "$(tail -n 1 "$REPO2/c.txt")" "base-c" "T2.10: non-allowlisted file is not extracted from source treeish"

echo ""
echo "───────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
