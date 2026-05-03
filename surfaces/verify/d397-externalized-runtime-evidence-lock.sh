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

# Workbench roots — required only on workbench-owning hosts.
# PACKET-587: workbench root is set in /etc/spine/execution-host.env on
# workbench-owning Linux hosts (ai-consolidation execution_host) and defaulted
# from root.authority on Darwin (MacBook operator_console). Non-workbench hosts
# (pve storage_evidence_node, pve-r620 watcher_node) do NOT set the workbench
# root and must not fail this gate for paths they do not own.
# Per docs/governance/HOST_DRIFT_POLICY.md.
# PACKET-597: SPINE_WORKBENCH_ROOT is canonical; SPINE_FOUNDATION_ROOT is
# retained as one-release compat alias because the path resolves to workbench,
# not the archived agentic-foundation repo. Read either, prefer new.
WORKBENCH_ROOT="${SPINE_WORKBENCH_ROOT:-${SPINE_FOUNDATION_ROOT:-}}"
if [[ -n "$WORKBENCH_ROOT" && -d "$WORKBENCH_ROOT" ]]; then
  required_external_dirs+=(
    "$WORKBENCH_ROOT"
    "$WORKBENCH_ROOT/docs"
    "$WORKBENCH_ROOT/docs/agents"
    "$WORKBENCH_ROOT/docs/archive"
    "$WORKBENCH_ROOT/docs/product"
    "$WORKBENCH_ROOT/docs/reference"
    "$WORKBENCH_ROOT/ops/domains"
    "$WORKBENCH_ROOT/ops/infra"
  )
fi

for path in "${required_external_dirs[@]}"; do
  [[ -d "$path" ]] || fail "required externalized path missing: $path"
done

if [[ -n "$WORKBENCH_ROOT" && -d "$WORKBENCH_ROOT" ]]; then
  echo "D397 PASS: runtime/evidence and typed workbench source families stay externalized"
else
  echo "D397 PASS: runtime/evidence externalized (workbench paths skipped — host does not own workbench)"
fi
