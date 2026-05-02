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
  ".runtime"
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

# Core externalized roots — required on every host that runs spine
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
)

# Workbench foundation roots — required only on workbench-owning hosts.
# PACKET-587: SPINE_FOUNDATION_ROOT is set in /etc/spine/execution-host.env on
# workbench-owning Linux hosts (ai-consolidation execution_host) and defaulted
# from root.authority on Darwin (MacBook operator_console). Non-workbench hosts
# (pve storage_evidence_node, pve-r620 watcher_node) do NOT set
# SPINE_FOUNDATION_ROOT and must not fail this gate for paths they do not own.
# Per docs/governance/HOST_DRIFT_POLICY.md.
if [[ -n "${SPINE_FOUNDATION_ROOT:-}" && -d "$SPINE_FOUNDATION_ROOT" ]]; then
  required_external_dirs+=(
    "$SPINE_FOUNDATION_ROOT"
    "$SPINE_FOUNDATION_ROOT/docs"
    "$SPINE_FOUNDATION_ROOT/docs/agents"
    "$SPINE_FOUNDATION_ROOT/docs/archive"
    "$SPINE_FOUNDATION_ROOT/docs/product"
    "$SPINE_FOUNDATION_ROOT/docs/reference"
    "$SPINE_FOUNDATION_ROOT/ops/domains"
    "$SPINE_FOUNDATION_ROOT/ops/infra"
  )
fi

for path in "${required_external_dirs[@]}"; do
  [[ -d "$path" ]] || fail "required externalized path missing: $path"
done

if [[ -n "${SPINE_FOUNDATION_ROOT:-}" && -d "$SPINE_FOUNDATION_ROOT" ]]; then
  echo "D397 PASS: runtime/evidence and typed foundation source families stay externalized"
else
  echo "D397 PASS: runtime/evidence externalized (workbench-foundation paths skipped — host does not own workbench)"
fi
