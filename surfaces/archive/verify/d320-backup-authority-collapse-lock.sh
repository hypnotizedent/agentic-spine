#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-$HOME/code/workbench}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

[[ -d "$WORKBENCH_ROOT" ]] || fail "missing workbench root: $WORKBENCH_ROOT"

BACKUP_BINDING="$ROOT/ops/bindings/backup.inventory.yaml"
WORKBENCH_BACKUP_DOC="$WORKBENCH_ROOT/docs/infrastructure/domains/backup/BACKUP_GOVERNANCE.md"
WORKBENCH_BACKUP_JSON="$WORKBENCH_ROOT/infra/data/backup_inventory.json"
WORKBENCH_FINANCE_DOC="$WORKBENCH_ROOT/docs/brain-lessons/FINANCE_BACKUP_RESTORE.md"
WORKBENCH_BACKUP_SCRIPTS_DIR="$WORKBENCH_ROOT/scripts/root/backup"

[[ -f "$BACKUP_BINDING" ]] || fail "missing spine backup inventory"
[[ -f "$WORKBENCH_BACKUP_DOC" ]] || fail "missing workbench backup governance doc"
[[ -f "$WORKBENCH_BACKUP_JSON" ]] || fail "missing workbench backup inventory json"
[[ -f "$WORKBENCH_FINANCE_DOC" ]] || fail "missing finance backup doc"
[[ -d "$WORKBENCH_BACKUP_SCRIPTS_DIR" ]] || fail "missing workbench backup scripts dir"

if rg -n "Seeded from workbench SSOT" "$BACKUP_BINDING" >/dev/null; then
  fail "spine backup inventory still advertises workbench SSOT"
fi

if rg -n "^status: authoritative$" "$WORKBENCH_BACKUP_DOC" >/dev/null; then
  fail "workbench backup governance doc still marked authoritative"
fi

if ! rg -n "Canonical authority:.*agentic-spine/ops/bindings/backup.inventory.yaml" "$WORKBENCH_BACKUP_DOC" >/dev/null; then
  fail "workbench backup governance doc missing canonical spine authority note"
fi

if rg -n "Data: infra/data/backup_inventory.json|SSOT: infra/data/backup_inventory.json|SSOT: docs/runbooks/BACKUP_GOVERNANCE.md" "$WORKBENCH_BACKUP_SCRIPTS_DIR" >/dev/null; then
  fail "active workbench backup scripts still advertise workbench backup SSOT"
fi

if ! rg -n '"authority_state": "reference_only"' "$WORKBENCH_BACKUP_JSON" >/dev/null; then
  fail "workbench backup inventory json missing reference_only marker"
fi

if rg -n "app-firefly.*disabled|enabled: false" "$WORKBENCH_FINANCE_DOC" >/dev/null; then
  fail "finance backup restore doc still contradicts canonical spine inventory"
fi

pass "backup authority collapse lock"
