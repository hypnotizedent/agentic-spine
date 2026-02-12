#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/../bin" && pwd)"

pass_count=0
fail_count=0

tmp_roots=()

cleanup() {
  for dir in "${tmp_roots[@]:-}"; do
    rm -rf "$dir" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT INT TERM

pass_case() {
  local name="$1"
  echo "PASS: $name"
  pass_count=$((pass_count + 1))
}

fail_case() {
  local name="$1"
  local reason="$2"
  echo "FAIL: $name - $reason"
  fail_count=$((fail_count + 1))
}

make_repo() {
  local root repo
  root="$(mktemp -d /tmp/orch-test.XXXXXX)"
  repo="$root/repo"
  tmp_roots+=("$root")

  mkdir -p "$repo/mailroom/state/orchestration"
  git init -q -b main "$repo"
  git -C "$repo" config user.name "Orchestration Test"
  git -C "$repo" config user.email "orchestration-test@example.com"

  echo "seed" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "seed"

  printf '%s\n' "$repo"
}

run_cap() {
  local repo="$1"
  shift
  SPINE_ROOT="$repo" "$@"
}

make_commit() {
  local repo="$1"
  local branch="$2"
  local path="$3"
  local content="$4"
  local message="$5"

  git -C "$repo" checkout -q -B "$branch" main
  mkdir -p "$(dirname "$repo/$path")"
  printf '%s\n' "$content" > "$repo/$path"
  git -C "$repo" add "$path"
  git -C "$repo" commit -q -m "$message"
  git -C "$repo" rev-parse HEAD
}

expect_fail_contains() {
  local name="$1"
  local pattern="$2"
  shift 2

  local output=""
  set +e
  output="$($@ 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    fail_case "$name" "expected failure but command succeeded"
    return
  fi
  if ! printf '%s' "$output" | rg -q "$pattern"; then
    fail_case "$name" "missing pattern '$pattern' in output: $output"
    return
  fi
  pass_case "$name"
}

expect_pass() {
  local name="$1"
  shift

  local output=""
  set +e
  output="$($@ 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    fail_case "$name" "expected success but failed: $output"
    return 1
  fi
  pass_case "$name"
  return 0
}

case_wrong_branch_rejected() {
  local repo base commit_other
  repo="$(make_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"

  run_cap "$repo" "$BIN_DIR/orchestration-loop-open" \
    --loop-id LOOP-T-WRONG-BRANCH \
    --apply-owner "$USER" \
    --repo "$repo" \
    --base-sha "$base" \
    --lanes lane-a \
    --sequence lane-a \
    --allow "lane-a:src/lane-a/**"

  make_commit "$repo" "worker/lane-a" "src/lane-a/ok.txt" "ok" "lane a commit" >/dev/null
  commit_other="$(make_commit "$repo" "worker/other" "src/lane-a/nope.txt" "nope" "other commit")"

  run_cap "$repo" "$BIN_DIR/orchestration-ticket-issue" \
    --loop-id LOOP-T-WRONG-BRANCH \
    --lane lane-a \
    --branch worker/lane-a >/dev/null

  expect_fail_contains "wrong branch rejected" "wrong branch" \
    run_cap "$repo" "$BIN_DIR/orchestration-handoff-validate" \
      --loop-id LOOP-T-WRONG-BRANCH --lane lane-a --commit "$commit_other"
}

case_base_sha_mismatch_rejected() {
  local repo base commit_lane main_new manifest
  repo="$(make_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"

  run_cap "$repo" "$BIN_DIR/orchestration-loop-open" \
    --loop-id LOOP-T-BASE-MISMATCH \
    --apply-owner "$USER" \
    --repo "$repo" \
    --base-sha "$base" \
    --lanes lane-a \
    --sequence lane-a \
    --allow "lane-a:src/lane-a/**"

  commit_lane="$(make_commit "$repo" "worker/lane-a" "src/lane-a/file.txt" "lane" "lane commit")"

  git -C "$repo" checkout -q main
  echo "new-main" > "$repo/new-main.txt"
  git -C "$repo" add new-main.txt
  git -C "$repo" commit -q -m "new main commit"
  main_new="$(git -C "$repo" rev-parse HEAD)"

  manifest="$repo/mailroom/state/orchestration/LOOP-T-BASE-MISMATCH/manifest.yaml"
  yq e -i ".base_sha = \"$main_new\"" "$manifest"

  run_cap "$repo" "$BIN_DIR/orchestration-ticket-issue" \
    --loop-id LOOP-T-BASE-MISMATCH \
    --lane lane-a \
    --branch worker/lane-a >/dev/null

  expect_fail_contains "base_sha mismatch rejected" "base_sha mismatch" \
    run_cap "$repo" "$BIN_DIR/orchestration-handoff-validate" \
      --loop-id LOOP-T-BASE-MISMATCH --lane lane-a --commit "$commit_lane"
}

case_forbidden_file_rejected() {
  local repo base commit_lane
  repo="$(make_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"

  run_cap "$repo" "$BIN_DIR/orchestration-loop-open" \
    --loop-id LOOP-T-FORBID \
    --apply-owner "$USER" \
    --repo "$repo" \
    --base-sha "$base" \
    --lanes lane-a \
    --sequence lane-a \
    --allow "lane-a:**" \
    --forbid "docs/**"

  commit_lane="$(make_commit "$repo" "worker/lane-a" "docs/blocked.md" "blocked" "blocked commit")"

  run_cap "$repo" "$BIN_DIR/orchestration-ticket-issue" \
    --loop-id LOOP-T-FORBID \
    --lane lane-a \
    --branch worker/lane-a >/dev/null

  expect_fail_contains "forbidden file touch rejected" "forbidden file touched" \
    run_cap "$repo" "$BIN_DIR/orchestration-handoff-validate" \
      --loop-id LOOP-T-FORBID --lane lane-a --commit "$commit_lane"
}

case_out_of_sequence_rejected() {
  local repo base commit_b
  repo="$(make_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"

  run_cap "$repo" "$BIN_DIR/orchestration-loop-open" \
    --loop-id LOOP-T-SEQUENCE \
    --apply-owner "$USER" \
    --repo "$repo" \
    --base-sha "$base" \
    --lanes lane-a,lane-b \
    --sequence lane-a,lane-b \
    --allow "lane-a:src/a/**" \
    --allow "lane-b:src/b/**"

  commit_b="$(make_commit "$repo" "worker/lane-b" "src/b/file.txt" "lane b" "lane b commit")"

  run_cap "$repo" "$BIN_DIR/orchestration-ticket-issue" \
    --loop-id LOOP-T-SEQUENCE \
    --lane lane-b \
    --branch worker/lane-b >/dev/null

  expect_fail_contains "out-of-sequence rejected" "out-of-sequence" \
    run_cap "$repo" "$BIN_DIR/orchestration-handoff-validate" \
      --loop-id LOOP-T-SEQUENCE --lane lane-b --commit "$commit_b"
}

case_terminal_entry_isolated_worktrees() {
  local repo base commit_d commit_e out_d out_e wt_d wt_e
  repo="$(make_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"

  run_cap "$repo" "$BIN_DIR/orchestration-loop-open" \
    --loop-id LOOP-T-ENTRY-ISOLATION \
    --apply-owner "$USER" \
    --repo "$repo" \
    --base-sha "$base" \
    --lanes D,E \
    --sequence D,E \
    --allow "D:src/d/**" \
    --allow "E:src/e/**" >/dev/null

  commit_d="$(make_commit "$repo" "worker/lane-d" "src/d/file.txt" "lane d" "lane d commit")"
  commit_e="$(make_commit "$repo" "worker/lane-e" "src/e/file.txt" "lane e" "lane e commit")"
  [[ -n "$commit_d" && -n "$commit_e" ]] || { fail_case "entry isolation setup" "missing lane commits"; return 1; }
  git -C "$repo" checkout -q main

  run_cap "$repo" "$BIN_DIR/orchestration-ticket-issue" \
    --loop-id LOOP-T-ENTRY-ISOLATION \
    --lane D \
    --branch worker/lane-d >/dev/null
  run_cap "$repo" "$BIN_DIR/orchestration-ticket-issue" \
    --loop-id LOOP-T-ENTRY-ISOLATION \
    --lane E \
    --branch worker/lane-e >/dev/null

  out_d="$(run_cap "$repo" "$BIN_DIR/orchestration-terminal-entry" \
    --loop-id LOOP-T-ENTRY-ISOLATION \
    --role worker \
    --lane D \
    --session-id TEST-D \
    --worktree "$repo" \
    --branch worker/lane-d 2>&1)"
  out_e="$(run_cap "$repo" "$BIN_DIR/orchestration-terminal-entry" \
    --loop-id LOOP-T-ENTRY-ISOLATION \
    --role worker \
    --lane E \
    --session-id TEST-E \
    --worktree "$repo" \
    --branch worker/lane-e 2>&1)"

  wt_d="$(printf '%s\n' "$out_d" | sed -n 's/^export SPINE_WORKTREE=//p' | tail -1)"
  wt_e="$(printf '%s\n' "$out_e" | sed -n 's/^export SPINE_WORKTREE=//p' | tail -1)"
  wt_d="${wt_d%\"}"
  wt_d="${wt_d#\"}"
  wt_e="${wt_e%\"}"
  wt_e="${wt_e#\"}"

  [[ -n "$wt_d" && -n "$wt_e" ]] || { fail_case "entry isolation" "missing SPINE_WORKTREE export"; return 1; }
  [[ "$wt_d" != "$wt_e" ]] || { fail_case "entry isolation" "D and E resolved same worktree: $wt_d"; return 1; }
  [[ -d "$wt_d" && -d "$wt_e" ]] || { fail_case "entry isolation" "resolved worktree path missing"; return 1; }

  pass_case "terminal entry resolves distinct per-lane worktrees"
}

case_terminal_entry_lane_branch_mismatch_rejected() {
  local repo base
  repo="$(make_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"

  run_cap "$repo" "$BIN_DIR/orchestration-loop-open" \
    --loop-id LOOP-T-ENTRY-MISMATCH \
    --apply-owner "$USER" \
    --repo "$repo" \
    --base-sha "$base" \
    --lanes D \
    --sequence D \
    --allow "D:src/d/**" >/dev/null

  make_commit "$repo" "worker/lane-d" "src/d/file.txt" "lane d" "lane d commit" >/dev/null
  git -C "$repo" checkout -q main
  run_cap "$repo" "$BIN_DIR/orchestration-ticket-issue" \
    --loop-id LOOP-T-ENTRY-MISMATCH \
    --lane D \
    --branch worker/lane-d >/dev/null

  expect_fail_contains "terminal entry wrong lane/branch rejected" "lane branch mismatch" \
    run_cap "$repo" "$BIN_DIR/orchestration-terminal-entry" \
      --loop-id LOOP-T-ENTRY-MISMATCH \
      --role worker \
      --lane D \
      --session-id TEST-MISMATCH \
      --worktree "$repo" \
      --branch worker/not-lane-d
}

case_happy_path_validate_integrate() {
  local repo base commit_a integration_file status
  repo="$(make_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"

  run_cap "$repo" "$BIN_DIR/orchestration-loop-open" \
    --loop-id LOOP-T-HAPPY \
    --apply-owner "$USER" \
    --repo "$repo" \
    --base-sha "$base" \
    --lanes lane-a \
    --sequence lane-a \
    --allow "lane-a:src/a/**" \
    --check "lane-a:true" >/dev/null

  commit_a="$(make_commit "$repo" "worker/lane-a" "src/a/ok.txt" "ok" "lane a commit")"

  run_cap "$repo" "$BIN_DIR/orchestration-ticket-issue" \
    --loop-id LOOP-T-HAPPY \
    --lane lane-a \
    --branch worker/lane-a >/dev/null

  expect_pass "happy path validate" \
    run_cap "$repo" "$BIN_DIR/orchestration-handoff-validate" \
      --loop-id LOOP-T-HAPPY --lane lane-a --commit "$commit_a" || return 1

  git -C "$repo" checkout -q main

  expect_pass "happy path integrate" \
    run_cap "$repo" "$BIN_DIR/orchestration-integrate" \
      --loop-id LOOP-T-HAPPY --lane lane-a --apply || return 1

  integration_file="$repo/mailroom/state/orchestration/LOOP-T-HAPPY/integrations/lane-a.yaml"
  [[ -f "$integration_file" ]] || { fail_case "happy path integrate artifact" "missing integration file"; return 1; }
  status="$(yq e -r '.status // ""' "$integration_file")"
  [[ "$status" == "applied" ]] || { fail_case "happy path integrate artifact" "unexpected status: $status"; return 1; }
  git -C "$repo" show --name-only --pretty=format: HEAD | rg -q "src/a/ok.txt" \
    || { fail_case "happy path integrate commit" "main missing cherry-picked file"; return 1; }

  pass_case "happy path validate + integrate"
}

case_related_repo_dirty_blocks_integrate() {
  local repo related base commit_a
  repo="$(make_repo)"
  related="$(make_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"

  # Create loop with related_repo
  run_cap "$repo" "$BIN_DIR/orchestration-loop-open" \
    --loop-id LOOP-T-RELATED-DIRTY \
    --apply-owner "$USER" \
    --repo "$repo" \
    --related-repo "$related" \
    --base-sha "$base" \
    --lanes lane-a \
    --sequence lane-a \
    --allow "lane-a:src/a/**" >/dev/null

  commit_a="$(make_commit "$repo" "worker/lane-a" "src/a/ok.txt" "ok" "lane a commit")"

  run_cap "$repo" "$BIN_DIR/orchestration-ticket-issue" \
    --loop-id LOOP-T-RELATED-DIRTY \
    --lane lane-a \
    --branch worker/lane-a >/dev/null

  expect_pass "related-repo validate passes" \
    run_cap "$repo" "$BIN_DIR/orchestration-handoff-validate" \
      --loop-id LOOP-T-RELATED-DIRTY --lane lane-a --commit "$commit_a" || return 1

  git -C "$repo" checkout -q main

  # Dirty the related repo
  echo "dirty" > "$related/dirty.txt"
  git -C "$related" add dirty.txt

  expect_fail_contains "related repo dirty blocks integrate" "related repo has staged changes" \
    run_cap "$repo" "$BIN_DIR/orchestration-integrate" \
      --loop-id LOOP-T-RELATED-DIRTY --lane lane-a --apply
}

case_related_repo_clean_integrate_passes() {
  local repo related base commit_a
  repo="$(make_repo)"
  related="$(make_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"

  run_cap "$repo" "$BIN_DIR/orchestration-loop-open" \
    --loop-id LOOP-T-RELATED-CLEAN \
    --apply-owner "$USER" \
    --repo "$repo" \
    --related-repo "$related" \
    --base-sha "$base" \
    --lanes lane-a \
    --sequence lane-a \
    --allow "lane-a:src/a/**" \
    --check "lane-a:true" >/dev/null

  commit_a="$(make_commit "$repo" "worker/lane-a" "src/a/ok.txt" "ok" "lane a commit")"

  run_cap "$repo" "$BIN_DIR/orchestration-ticket-issue" \
    --loop-id LOOP-T-RELATED-CLEAN \
    --lane lane-a \
    --branch worker/lane-a >/dev/null

  expect_pass "related-repo validate passes (clean)" \
    run_cap "$repo" "$BIN_DIR/orchestration-handoff-validate" \
      --loop-id LOOP-T-RELATED-CLEAN --lane lane-a --commit "$commit_a" || return 1

  git -C "$repo" checkout -q main

  expect_pass "related repo clean allows integrate" \
    run_cap "$repo" "$BIN_DIR/orchestration-integrate" \
      --loop-id LOOP-T-RELATED-CLEAN --lane lane-a --apply
}

case_wrong_branch_rejected
case_base_sha_mismatch_rejected
case_forbidden_file_rejected
case_out_of_sequence_rejected
case_terminal_entry_isolated_worktrees
case_terminal_entry_lane_branch_mismatch_rejected
case_happy_path_validate_integrate
case_related_repo_dirty_blocks_integrate
case_related_repo_clean_integrate_passes

echo ""
echo "tests_passed: $pass_count"
echo "tests_failed: $fail_count"

if [[ "$fail_count" -ne 0 ]]; then
  exit 1
fi
