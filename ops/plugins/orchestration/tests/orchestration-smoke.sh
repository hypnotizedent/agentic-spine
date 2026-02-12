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

case_wrong_branch_rejected
case_base_sha_mismatch_rejected
case_forbidden_file_rejected
case_out_of_sequence_rejected
case_happy_path_validate_integrate

echo ""
echo "tests_passed: $pass_count"
echo "tests_failed: $fail_count"

if [[ "$fail_count" -ne 0 ]]; then
  exit 1
fi
