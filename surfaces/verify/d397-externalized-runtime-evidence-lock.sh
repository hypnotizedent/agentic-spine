#!/usr/bin/env bash
# TRIAGE: fail if runtime/evidence roots or extracted source families drift back into agentic-spine.
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_ROOT/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths
ROOT="$SPINE_TARGET_REPO"

fail() {
  echo "D397 FAIL: $*" >&2
  exit 1
}

forbidden_repo_paths=(
  ".archive"
  ".spine"
  ".tmp"
  ".worktrees"
  "docs/product"
  "gates"
  "mailroom"
  "ops/staged"
  "receipts"
  "runtime"
)

for rel in "${forbidden_repo_paths[@]}"; do
  [[ ! -e "$ROOT/$rel" ]] || fail "forbidden repo-local hot path present: $rel"
done

required_external_dirs=(
  "$SPINE_RUNTIME_ROOT"
  "$SPINE_MAILROOM_ROOT"
  "$SPINE_STATE"
  "$SPINE_LOGS"
  "$SPINE_EVIDENCE_ROOT"
  "$SPINE_RECEIPTS"
  "$SPINE_VERIFY_ROOT"
  "$SPINE_DATA_ROOT"
  "$SPINE_BACKUPS_ROOT"
  "$SPINE_FOUNDATION_ROOT"
  "$SPINE_FOUNDATION_ROOT/docs"
  "$SPINE_FOUNDATION_ROOT/docs/agents"
  "$SPINE_FOUNDATION_ROOT/docs/archive"
  "$SPINE_FOUNDATION_ROOT/docs/product"
  "$SPINE_FOUNDATION_ROOT/docs/reference"
  "$SPINE_FOUNDATION_ROOT/ops/domains"
  "$SPINE_FOUNDATION_ROOT/ops/infra"
)

for path in "${required_external_dirs[@]}"; do
  [[ -d "$path" ]] || fail "required externalized path missing: $path"
done

echo "D397 PASS: runtime/evidence and typed foundation source families stay externalized"
