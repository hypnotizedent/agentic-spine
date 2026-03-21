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
         "$CLAUDE_ROOT/projects/workspace-a/project-old/tool-results" \
         "$CLAUDE_ROOT/projects/workspace-a/project-old/session-memory" \
         "$CLAUDE_ROOT/projects/workspace-a/project-live/tool-results" \
         "$CLAUDE_ROOT/projects/workspace-a/memory" \
         "$CODEX_ROOT/sessions/2026/01" \
         "$CODEX_ROOT/sessions/2026/03" \
         "$REPO_ROOT/payment/node_modules/pkg" \
         "$REPO_ROOT/payment/src" \
         "$REPO_ROOT/pricing/node_modules/pkg" \
         "$REPO_ROOT/pricing/src"

printf 'old-debug\n' > "$CLAUDE_ROOT/debug/old.log"
printf 'old-file-history\n' > "$CLAUDE_ROOT/file-history/old.json"
printf 'old-telemetry\n' > "$CLAUDE_ROOT/telemetry/old.json"
printf 'old-transcript\n' > "$CLAUDE_ROOT/transcripts/old.txt"
printf 'old-project-history\n' > "$CLAUDE_ROOT/projects/workspace-a/project-old/session-memory/summary.md"
printf 'old-tool-result\n' > "$CLAUDE_ROOT/projects/workspace-a/project-old/tool-results/tool.txt"
printf 'live-tool-result\n' > "$CLAUDE_ROOT/projects/workspace-a/project-live/tool-results/tool.txt"
printf 'workspace-memory\n' > "$CLAUDE_ROOT/projects/workspace-a/memory/state.json"
printf 'old-codex\n' > "$CODEX_ROOT/sessions/2026/01/session.jsonl"
printf 'current-codex\n' > "$CODEX_ROOT/sessions/2026/03/session.jsonl"
printf '{"name":"payment"}\n' > "$REPO_ROOT/payment/package.json"
printf '{"lockfileVersion":3}\n' > "$REPO_ROOT/payment/package-lock.json"
printf 'export const payment = 1;\n' > "$REPO_ROOT/payment/src/index.ts"
printf 'module.exports = 1;\n' > "$REPO_ROOT/payment/node_modules/pkg/index.js"
printf '{"name":"pricing"}\n' > "$REPO_ROOT/pricing/package.json"
printf '{"lockfileVersion":3}\n' > "$REPO_ROOT/pricing/package-lock.json"
printf 'export const pricing = 1;\n' > "$REPO_ROOT/pricing/src/index.ts"
printf 'module.exports = 2;\n' > "$REPO_ROOT/pricing/node_modules/pkg/index.js"

set_old_mtime "$CLAUDE_ROOT/debug/old.log"
set_old_mtime "$CLAUDE_ROOT/file-history/old.json"
set_old_mtime "$CLAUDE_ROOT/telemetry/old.json"
set_old_mtime "$CLAUDE_ROOT/transcripts/old.txt"
set_old_mtime "$CLAUDE_ROOT/projects/workspace-a/project-old/session-memory/summary.md"
set_old_mtime "$CLAUDE_ROOT/projects/workspace-a/project-old/tool-results/tool.txt"
set_old_mtime "$CODEX_ROOT/sessions/2026/01/session.jsonl"
set_old_mtime "$CODEX_ROOT/sessions/2026/01"
set_old_mtime "$REPO_ROOT/payment/package.json"
set_old_mtime "$REPO_ROOT/payment/package-lock.json"
set_old_mtime "$REPO_ROOT/payment/src/index.ts"
set_old_mtime "$REPO_ROOT/payment/node_modules/pkg/index.js"
set_old_mtime "$REPO_ROOT/payment/node_modules"

git init "$REPO_ROOT" >/dev/null
git -C "$REPO_ROOT" config user.name "Test User"
git -C "$REPO_ROOT" config user.email "test@example.com"
OLD_GIT_DATE="$(python3 - <<'PY'
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc) - timedelta(days=45)).strftime('%Y-%m-%dT%H:%M:%SZ'))
PY
)"
git -C "$REPO_ROOT" add payment/package.json payment/package-lock.json payment/src/index.ts pricing/package.json pricing/package-lock.json pricing/src/index.ts
GIT_AUTHOR_DATE="$OLD_GIT_DATE" GIT_COMMITTER_DATE="$OLD_GIT_DATE" git -C "$REPO_ROOT" commit -m "base" >/dev/null
git -C "$REPO_ROOT" branch -M main >/dev/null
printf 'export const pricing = 2;\n' > "$REPO_ROOT/pricing/src/index.ts"
git -C "$REPO_ROOT" add pricing/src/index.ts
git -C "$REPO_ROOT" commit -m "touch pricing" >/dev/null

CONTRACT="$TMPDIR_BASE/operator.hygiene.contract.yaml"
cat > "$CONTRACT" <<YAML
status: authoritative
owner: "@test"
last_verified: 2026-03-21
scope: operator-hygiene-test
version: 2
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
      kind: aged_project_tree_archive_compact
      governance_class: retained_memory
      root: "$CLAUDE_ROOT/projects"
      retention_days: 30
      execute_by_default: true
      project_tree_glob: "*/*"
      ignore_names: [memory]
      stub_filename: "ARCHIVED_PROJECT_MEMORY.yaml"
      archive_prefix: "claude-project-memory"
      severity_tiers:
        warn:
          candidate_count: 2
          candidate_bytes: 1048576
          oldest_age_days: 90
        fail:
          candidate_count: 5
          candidate_bytes: 5242880
          oldest_age_days: 120
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
      governance_class: cold_rehydrateable
      root: "$REPO_ROOT"
      generated_dir_names: [dist, build]
      generated_retention_days: 14
      execute_generated_cleanup: true
      dependency_dir_names: [node_modules]
      dependency_manifest_names: [package-lock.json]
      dependency_strategy: cold_rehydrateable
      dependency_rehydrate_command: "npm ci"
      dependency_heat:
        hot_days: 7
        warm_days: 30
      severity_tiers:
        warn:
          generated_candidate_count: 1
          blocked_generated_count: 1
          blocked_dependency_count: 1
          cold_dependency_count: 2
          cold_dependency_bytes: 1048576
        fail:
          generated_candidate_count: 5
          blocked_generated_count: 3
          blocked_dependency_count: 2
          cold_dependency_count: 4
          cold_dependency_bytes: 5242880
YAML

echo ""
echo "── T1: retained-memory and cold-rehydrateable rows stay PASS below budget ──"
SELECTED_JSON="$TMPDIR_BASE/selected.json"
SPINE_EVIDENCE_ROOT="$EVIDENCE_ROOT" "$RUNNER" --contract "$CONTRACT" --id claude.projects.retention --id mint-modules.dev_artifacts --json > "$SELECTED_JSON"
assert_eq "$(json_eval "$SELECTED_JSON" 'payload["summary"]["status"]')" "pass" "selected posture stays PASS below warn tiers"
assert_eq "$(json_eval "$SELECTED_JSON" 'payload["summary"]["retained_memory_candidates"]')" "1" "retained_memory summary count tracks compactable project trees"
assert_eq "$(json_eval "$SELECTED_JSON" 'payload["summary"]["cold_rehydrateable_candidates"]')" "1" "cold_rehydrateable summary count tracks cold node_modules only"
assert_eq "$(json_eval "$SELECTED_JSON" 'next(row for row in payload["rows"] if row["id"] == "claude.projects.retention")["status"]')" "pass" "Claude project compaction row passes below budget"
assert_eq "$(json_eval "$SELECTED_JSON" 'next(row for row in payload["rows"] if row["id"] == "claude.projects.retention")["governance_class"]')" "retained_memory" "Claude project row carries retained_memory class"
assert_eq "$(json_eval "$SELECTED_JSON" 'next(row for row in payload["rows"] if row["id"] == "mint-modules.dev_artifacts")["status"]')" "pass" "cold node_modules row passes below budget"
assert_eq "$(json_eval "$SELECTED_JSON" 'len(next(row for row in payload["rows"] if row["id"] == "mint-modules.dev_artifacts")["dependency_candidates"])')" "1" "only cold node_modules becomes recommendation"
assert_eq "$(json_eval "$SELECTED_JSON" 'len(next(row for row in payload["rows"] if row["id"] == "mint-modules.dev_artifacts")["hot_dependencies"])')" "1" "recent module stays hot inventory not recommendation"

mkdir -p "$REPO_ROOT/quotes/dist" \
         "$REPO_ROOT/shipping/build" \
         "$REPO_ROOT/legacy/node_modules/pkg" \
         "$REPO_ROOT/legacy/src"
printf 'generated-output\n' > "$REPO_ROOT/quotes/dist/out.js"
printf 'tracked build\n' > "$REPO_ROOT/shipping/build/tracked.txt"
printf '{"name":"shipping"}\n' > "$REPO_ROOT/shipping/package.json"
printf 'export const shipping = 1;\n' > "$REPO_ROOT/shipping/src.ts"
printf '{"name":"legacy"}\n' > "$REPO_ROOT/legacy/package.json"
printf 'export const legacy = 1;\n' > "$REPO_ROOT/legacy/src/index.ts"
printf 'module.exports = 3;\n' > "$REPO_ROOT/legacy/node_modules/pkg/index.js"
git -C "$REPO_ROOT" add shipping/build/tracked.txt shipping/package.json shipping/src.ts
git -C "$REPO_ROOT" commit -m "track build artifact for hygiene test" >/dev/null
set_old_mtime "$REPO_ROOT/quotes/dist/out.js"
set_old_mtime "$REPO_ROOT/quotes/dist"
set_old_mtime "$REPO_ROOT/shipping/build/tracked.txt"
set_old_mtime "$REPO_ROOT/shipping/build"
set_old_mtime "$REPO_ROOT/legacy/src/index.ts"
set_old_mtime "$REPO_ROOT/legacy/node_modules/pkg/index.js"
set_old_mtime "$REPO_ROOT/legacy/node_modules"

echo ""
echo "── T2: generated/blocked artifacts are surfaced without changing heat semantics ──"
REPORT_JSON="$TMPDIR_BASE/report.json"
SPINE_EVIDENCE_ROOT="$EVIDENCE_ROOT" "$RUNNER" --contract "$CONTRACT" --json > "$REPORT_JSON"
assert_eq "$(json_eval "$REPORT_JSON" 'next(row for row in payload["rows"] if row["id"] == "mint-modules.dev_artifacts")["status"]')" "warn" "generated and blocked artifacts push dev-artifact row into warn tier"
assert_eq "$(json_eval "$REPORT_JSON" 'len(next(row for row in payload["rows"] if row["id"] == "mint-modules.dev_artifacts")["generated_candidates"])')" "1" "untracked generated output becomes cleanup candidate"
assert_eq "$(json_eval "$REPORT_JSON" 'len(next(row for row in payload["rows"] if row["id"] == "mint-modules.dev_artifacts")["blocked_generated"])')" "1" "tracked build output stays blocked"
assert_eq "$(json_eval "$REPORT_JSON" 'len(next(row for row in payload["rows"] if row["id"] == "mint-modules.dev_artifacts")["blocked_dependencies"])')" "1" "missing lockfile stays blocked, not rehydrateable"
assert_eq "$(json_eval "$REPORT_JSON" 'next(row for row in payload["rows"] if row["id"] == "mint-modules.dev_artifacts")["dependency_candidates"][0]["heat"]')" "cold" "cold recommendation exposes heat classification"
assert_eq "$(json_eval "$REPORT_JSON" 'next(row for row in payload["rows"] if row["id"] == "mint-modules.dev_artifacts")["hot_dependencies"][0]["heat"]')" "hot" "hot dependency inventory exposes heat classification"

echo ""
echo "── T3: execute compacts project memory, archives history, and preserves rehydrateable deps ──"
EXECUTE_JSON="$TMPDIR_BASE/execute.json"
SPINE_EVIDENCE_ROOT="$EVIDENCE_ROOT" "$RUNNER" --contract "$CONTRACT" --execute --json > "$EXECUTE_JSON"
if [[ -f "$CLAUDE_ROOT/projects/workspace-a/project-old/ARCHIVED_PROJECT_MEMORY.yaml" ]]; then pass "old Claude project replaced with searchable stub"; else fail "old Claude project replaced with searchable stub"; fi
if [[ ! -f "$CLAUDE_ROOT/projects/workspace-a/project-old/tool-results/tool.txt" ]]; then pass "old Claude project payload removed after archive"; else fail "old Claude project payload removed after archive"; fi
if [[ -f "$CLAUDE_ROOT/projects/workspace-a/project-live/tool-results/tool.txt" ]]; then pass "recent Claude project stays live"; else fail "recent Claude project stays live"; fi
assert_eq "$(json_eval "$EXECUTE_JSON" 'next(row for row in payload["rows"] if row["id"] == "claude.projects.retention")["compacted_count"]')" "1" "execute compacts one old project tree"
assert_eq "$(find "$ARCHIVE_ROOT" -name '*.tar.gz' | wc -l | tr -d ' ')" "3" "transcript, codex month, and old project were archived"
if [[ -f "$ARCHIVE_ROOT/claude.projects.retention/archive-index.jsonl" ]]; then pass "archive index recorded compacted project"; else fail "archive index recorded compacted project"; fi
if [[ ! -f "$CLAUDE_ROOT/transcripts/old.txt" ]]; then pass "old Claude transcript removed after archive"; else fail "old Claude transcript removed after archive"; fi
if [[ ! -d "$CODEX_ROOT/sessions/2026/01" && -d "$CODEX_ROOT/sessions/2026/03" ]]; then pass "old Codex month archived and current month preserved"; else fail "old Codex month archived and current month preserved"; fi
if [[ ! -d "$REPO_ROOT/quotes/dist" ]]; then pass "untracked generated dist deleted"; else fail "untracked generated dist deleted"; fi
if [[ -d "$REPO_ROOT/payment/node_modules" && -d "$REPO_ROOT/pricing/node_modules" ]]; then pass "rehydrateable node_modules preserved"; else fail "rehydrateable node_modules preserved"; fi
if [[ -d "$REPO_ROOT/legacy/node_modules" ]]; then pass "blocked legacy node_modules preserved"; else fail "blocked legacy node_modules preserved"; fi
if [[ -d "$REPO_ROOT/shipping/build" ]]; then pass "tracked build output preserved"; else fail "tracked build output preserved"; fi

echo ""
echo "── T4: stub keeps recovery explicit and searchable ──"
STUB="$CLAUDE_ROOT/projects/workspace-a/project-old/ARCHIVED_PROJECT_MEMORY.yaml"
assert_eq "$(python3 - <<'PY' "$STUB"
import sys, yaml
payload = yaml.safe_load(open(sys.argv[1], encoding='utf-8'))
print(payload['status'])
PY
)" "archived" "project stub marks archived status"
assert_eq "$(python3 - <<'PY' "$STUB"
import sys, yaml
payload = yaml.safe_load(open(sys.argv[1], encoding='utf-8'))
print(payload['governance_class'])
PY
)" "retained_memory" "project stub keeps retained_memory governance class"
assert_eq "$(python3 - <<'PY' "$STUB"
import sys, yaml
payload = yaml.safe_load(open(sys.argv[1], encoding='utf-8'))
print('tar -xzf' in payload['restore_command'])
PY
)" "True" "project stub contains explicit restore command"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
