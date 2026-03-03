#!/usr/bin/env bash
# TRIAGE: D333 communications-mail-archiver-stabilization-lock
# Enforces: continuation packet exists, overlap assets restored, backup contract wired
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

# ── 1. Continuation packet exists ──
PACKET="$ROOT/mailroom/state/orchestration/LOOP-MAIL-ARCHIVER-POST-SYNC-STABILIZATION-20260302/packet.yaml"
if [[ -f "$PACKET" ]]; then
  ok "continuation packet exists"
  # Validate required fields
  LOOP_ID="$(yq e '.loop_id // ""' "$PACKET" 2>/dev/null || echo "")"
  if [[ -z "$LOOP_ID" || "$LOOP_ID" == "null" ]]; then
    err "packet missing loop_id"
  else
    ok "packet loop_id: $LOOP_ID"
  fi
  PRECOND_COUNT="$(yq e '.preconditions | length' "$PACKET" 2>/dev/null || echo "0")"
  if [[ "$PRECOND_COUNT" -lt 1 ]]; then
    err "packet missing preconditions"
  else
    ok "packet preconditions: $PRECOND_COUNT"
  fi
  WAVE_COUNT="$(yq e '.wave_plan | length' "$PACKET" 2>/dev/null || echo "0")"
  if [[ "$WAVE_COUNT" -lt 1 ]]; then
    err "packet missing wave_plan"
  else
    ok "packet wave_plan: $WAVE_COUNT waves"
  fi
else
  err "continuation packet not found at $PACKET"
fi

# ── 2. Overlap cleanup capability scripts exist ──
OVERLAP_PLAN="$ROOT/ops/plugins/communications/bin/communications-mail-archiver-overlap-plan"
IMPORT_REMOTE="$ROOT/ops/plugins/communications/bin/communications-mail-archiver-import-eml-remote"

if [[ -f "$OVERLAP_PLAN" ]]; then
  ok "overlap plan capability script exists"
  if [[ ! -x "$OVERLAP_PLAN" ]]; then
    err "overlap plan script not executable"
  fi
else
  err "overlap plan script missing: $OVERLAP_PLAN"
fi

if [[ -f "$IMPORT_REMOTE" ]]; then
  ok "import eml remote capability script exists"
  if [[ ! -x "$IMPORT_REMOTE" ]]; then
    err "import eml remote script not executable"
  fi
else
  err "import eml remote script missing: $IMPORT_REMOTE"
fi

# ── 3. Alias boundary contract exists ──
ALIAS_CONTRACT="$ROOT/ops/bindings/mail.archiver.alias.boundary.contract.yaml"
if [[ -f "$ALIAS_CONTRACT" ]]; then
  ok "alias boundary contract exists"
  ALIAS_VERSION="$(yq e '.version // 0' "$ALIAS_CONTRACT" 2>/dev/null || echo "0")"
  if [[ "$ALIAS_VERSION" -lt 1 ]]; then
    err "alias boundary contract version missing or invalid"
  else
    ok "alias boundary contract version: $ALIAS_VERSION"
  fi
else
  err "alias boundary contract missing: $ALIAS_CONTRACT"
fi

# ── 4. Backup schedule has pg_dump job ──
BACKUP_SCHEDULE="$ROOT/ops/bindings/backup.schedule.yaml"
if [[ -f "$BACKUP_SCHEDULE" ]]; then
  PGDUMP_ENABLED="$(yq e '.jobs[] | select(.id == "mail-archiver-db-pgdump-daily") | .enabled' "$BACKUP_SCHEDULE" 2>/dev/null || echo "false")"
  if [[ "$PGDUMP_ENABLED" == "true" ]]; then
    ok "pg_dump daily job enabled in backup schedule"
  else
    err "pg_dump daily job not enabled in backup schedule"
  fi
else
  err "backup schedule binding missing"
fi

# ── 5. Backup inventory has mail-archiver target ──
BACKUP_INVENTORY="$ROOT/ops/bindings/backup.inventory.yaml"
if [[ -f "$BACKUP_INVENTORY" ]]; then
  MA_TARGET="$(yq e '.targets[] | select(.name == "vm-214-communications-stack-primary") | .name' "$BACKUP_INVENTORY" 2>/dev/null || echo "")"
  if [[ -n "$MA_TARGET" && "$MA_TARGET" != "null" ]]; then
    ok "mail-archiver backup target registered in inventory"
  else
    err "mail-archiver backup target (vm-214-communications-stack-primary) missing from inventory"
  fi
  MA_APP="$(yq e '.targets[] | select(.name == "app-mail-archiver") | .name' "$BACKUP_INVENTORY" 2>/dev/null || echo "")"
  if [[ -n "$MA_APP" && "$MA_APP" != "null" ]]; then
    ok "mail-archiver app-level backup target registered in inventory"
  else
    err "mail-archiver app-level backup target (app-mail-archiver) missing from inventory"
  fi
else
  err "backup inventory binding missing"
fi

# ── 6. Account linkage contract exists and is authoritative ──
LINKAGE="$ROOT/ops/bindings/mail.archiver.account.linkage.contract.yaml"
if [[ -f "$LINKAGE" ]]; then
  LINKAGE_STATUS="$(head -5 "$LINKAGE" | grep -o 'authoritative\|draft' || echo "unknown")"
  if [[ "$LINKAGE_STATUS" == "authoritative" ]]; then
    ok "account linkage contract is authoritative"
  else
    err "account linkage contract status: $LINKAGE_STATUS (expected authoritative)"
  fi
else
  err "account linkage contract missing"
fi

# ── Result ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D333 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D333 PASS"
exit 0
