#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
RUNNER="$ROOT/ops/plugins/core/ops/bin/operator-hygiene-reconcile"

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

set_old_mtime() {
  python3 - "$1" <<'PY'
import os
import sys
import time
from pathlib import Path

path = Path(sys.argv[1])
ts = time.time() - (45 * 86400)
os.utime(path, (ts, ts))
PY
}

echo "operator hygiene reconcile tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

CLAUDE_ROOT="$TMPDIR_BASE/claude"
CODEX_ROOT="$TMPDIR_BASE/codex"
REPO_ROOT="$TMPDIR_BASE/mint-modules"
ARCHIVE_ROOT="$TMPDIR_BASE/archive"
EVIDENCE_ROOT="$TMPDIR_BASE/evidence"
mkdir -p "$CLAUDE_ROOT/session-env/empty-one" \
         "$CLAUDE_ROOT/debug" \
         "$CLAUDE_ROOT/file-history" \
         "$CLAUDE_ROOT/telemetry" \
         "$CLAUDE_ROOT/transcripts" \
         "$CLAUDE_ROOT/projects/project-a/subagents" \
         "$CODEX_ROOT/sessions/2026/01" \
         "$CODEX_ROOT/sessions/2026/03" \
         "$REPO_ROOT/quotes/dist" \
         "$REPO_ROOT/payment/node_modules/pkg" \
         "$REPO_ROOT/shipping/build"

printf 'old-debug\n' > "$CLAUDE_ROOT/debug/old.log"
printf 'old-file-history\n' > "$CLAUDE_ROOT/file-history/old.json"
printf 'old-telemetry\n' > "$CLAUDE_ROOT/telemetry/old.json"
printf 'old-transcript\n' > "$CLAUDE_ROOT/transcripts/old.txt"
printf 'old-project-history\n' > "$CLAUDE_ROOT/projects/project-a/subagents/agent-a.jsonl"
printf 'old-codex\n' > "$CODEX_ROOT/sessions/2026/01/session.jsonl"
printf 'current-codex\n' > "$CODEX_ROOT/sessions/2026/03/session.jsonl"
printf 'generated-output\n' > "$REPO_ROOT/quotes/dist/out.js"
printf '{"name":"payment"}\n' > "$REPO_ROOT/payment/package.json"
printf '{"lockfileVersion":3}\n' > "$REPO_ROOT/payment/package-lock.json"
printf 'module export = 1;\n' > "$REPO_ROOT/payment/node_modules/pkg/index.js"
printf 'tracked build\n' > "$REPO_ROOT/shipping/build/tracked.txt"

set_old_mtime "$CLAUDE_ROOT/debug/old.log"
set_old_mtime "$CLAUDE_ROOT/file-history/old.json"
set_old_mtime "$CLAUDE_ROOT/telemetry/old.json"
set_old_mtime "$CLAUDE_ROOT/transcripts/old.txt"
set_old_mtime "$CLAUDE_ROOT/projects/project-a/subagents/agent-a.jsonl"
set_old_mtime "$CODEX_ROOT/sessions/2026/01/session.jsonl"
set_old_mtime "$CODEX_ROOT/sessions/2026/01"
set_old_mtime "$REPO_ROOT/quotes/dist/out.js"
set_old_mtime "$REPO_ROOT/quotes/dist"
set_old_mtime "$REPO_ROOT/payment/node_modules/pkg/index.js"
set_old_mtime "$REPO_ROOT/payment/node_modules"
set_old_mtime "$REPO_ROOT/shipping/build/tracked.txt"
set_old_mtime "$REPO_ROOT/shipping/build"

git init "$REPO_ROOT" >/dev/null
git -C "$REPO_ROOT" config user.name "Test User"
git -C "$REPO_ROOT" config user.email "test@example.com"
git -C "$REPO_ROOT" add shipping/build/tracked.txt payment/package.json payment/package-lock.json
git -C "$REPO_ROOT" commit -m "base" >/dev/null
git -C "$REPO_ROOT" branch -M main >/dev/null

CONTRACT="$TMPDIR_BASE/operator.hygiene.contract.yaml"
cat > "$CONTRACT" <<YAML
status: authoritative
owner: "@test"
last_verified: 2026-03-21
scope: operator-hygiene-test
version: 1
updated_at: "2026-03-21"
paths:
  archive_root: "$ARCHIVE_ROOT"
tool_history:
  policies:
    - id: claude.session_env.empty
      status: active
      kind: empty_dir_prune
      root: "$CLAUDE_ROOT/session-env"
      execute_by_default: true
    - id: claude.debug.retention
      status: active
      kind: aged_file_delete
      root: "$CLAUDE_ROOT/debug"
      retention_days: 30
      execute_by_default: true
    - id: claude.file_history.retention
      status: active
      kind: aged_file_delete
      root: "$CLAUDE_ROOT/file-history"
      retention_days: 30
      execute_by_default: true
    - id: claude.telemetry.retention
      status: active
      kind: aged_file_delete
      root: "$CLAUDE_ROOT/telemetry"
      retention_days: 30
      execute_by_default: true
    - id: claude.transcripts.retention
      status: active
      kind: aged_file_archive_delete
      root: "$CLAUDE_ROOT/transcripts"
      retention_days: 30
      execute_by_default: true
      archive_prefix: "claude-transcripts"
    - id: claude.projects.retention
      status: active
      kind: aged_file_report
      root: "$CLAUDE_ROOT/projects"
      retention_days: 30
      execute_by_default: false
    - id: codex.sessions.retention
      status: active
      kind: month_dir_archive_delete
      root: "$CODEX_ROOT/sessions"
      retention_days: 30
      execute_by_default: true
      archive_prefix: "codex-sessions"
dev_artifacts:
  policies:
    - id: mint-modules.dev_artifacts
      status: active
      root: "$REPO_ROOT"
      generated_dir_names: [dist, build]
      generated_retention_days: 14
      execute_generated_cleanup: true
      dependency_dir_names: [node_modules]
      dependency_manifest_names: [package-lock.json]
      dependency_strategy: report_only
      dependency_rehydrate_command: "npm ci"
YAML

echo ""
echo "── T1: report-only classifies safe cleanup vs report-only debt ──"
REPORT_JSON="$TMPDIR_BASE/report.json"
SPINE_EVIDENCE_ROOT="$EVIDENCE_ROOT" "$RUNNER" --contract "$CONTRACT" --json > "$REPORT_JSON"
assert_eq "$(json_eval "$REPORT_JSON" 'payload["summary"]["candidate_count"]')" "9" "report-only counts tool + generated + dependency candidates"
assert_eq "$(json_eval "$REPORT_JSON" 'payload["summary"]["report_only_candidates"]')" "2" "report-only counts Claude projects + node_modules"
assert_eq "$(json_eval "$REPORT_JSON" 'payload["summary"]["blocked_count"]')" "1" "tracked build output is blocked"
assert_eq "$(json_eval "$REPORT_JSON" 'next(row for row in payload["rows"] if row["id"] == "claude.projects.retention")["candidate_count"]')" "1" "Claude project history is report-only candidate"
assert_eq "$(json_eval "$REPORT_JSON" 'len(next(row for row in payload["rows"] if row["id"] == "mint-modules.dev_artifacts")["dependency_candidates"])')" "1" "node_modules is classified as dependency candidate"
assert_eq "$(json_eval "$REPORT_JSON" 'len(next(row for row in payload["rows"] if row["id"] == "mint-modules.dev_artifacts")["generated_candidates"])')" "1" "untracked generated output becomes cleanup candidate"
assert_eq "$(json_eval "$REPORT_JSON" 'len(next(row for row in payload["rows"] if row["id"] == "mint-modules.dev_artifacts")["blocked_generated"])')" "1" "tracked build output stays blocked"

echo ""
echo "── T2: execute cleans safe classes and preserves report-only artifacts ──"
EXECUTE_JSON="$TMPDIR_BASE/execute.json"
SPINE_EVIDENCE_ROOT="$EVIDENCE_ROOT" "$RUNNER" --contract "$CONTRACT" --execute --json > "$EXECUTE_JSON"
assert_eq "$(json_eval "$EXECUTE_JSON" 'payload["summary"]["deleted_count"]')" "7" "execute deletes safe files/dirs plus generated output"
assert_eq "$(json_eval "$EXECUTE_JSON" 'payload["summary"]["archived_count"]')" "2" "execute archives transcript and old Codex month"
if [[ ! -d "$CLAUDE_ROOT/session-env/empty-one" ]]; then pass "empty Claude session env removed"; else fail "empty Claude session env removed"; fi
if [[ ! -f "$CLAUDE_ROOT/debug/old.log" ]]; then pass "old Claude debug log deleted"; else fail "old Claude debug log deleted"; fi
if [[ ! -f "$CLAUDE_ROOT/transcripts/old.txt" ]]; then pass "old Claude transcript removed after archive"; else fail "old Claude transcript removed after archive"; fi
if [[ -f "$CLAUDE_ROOT/projects/project-a/subagents/agent-a.jsonl" ]]; then pass "Claude project history preserved"; else fail "Claude project history preserved"; fi
if [[ ! -d "$CODEX_ROOT/sessions/2026/01" && -d "$CODEX_ROOT/sessions/2026/03" ]]; then pass "old Codex month archived and current month preserved"; else fail "old Codex month archived and current month preserved"; fi
if [[ ! -d "$REPO_ROOT/quotes/dist" ]]; then pass "untracked generated dist deleted"; else fail "untracked generated dist deleted"; fi
if [[ -d "$REPO_ROOT/payment/node_modules" ]]; then pass "node_modules preserved for report-only strategy"; else fail "node_modules preserved for report-only strategy"; fi
if [[ -d "$REPO_ROOT/shipping/build" ]]; then pass "tracked build output preserved"; else fail "tracked build output preserved"; fi
assert_eq "$(find "$ARCHIVE_ROOT" -type f | wc -l | tr -d ' ')" "2" "two archives created"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
