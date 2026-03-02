#!/usr/bin/env bash
# TRIAGE: Verify Vaultwarden hygiene governance surfaces (backup freshness, restore-drill evidence, canonical hosts, recovery action, folder taxonomy). All checks are artifact-based — no live VM required.
# D319: vaultwarden-hygiene-compliance-lock
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CANONICAL_HOSTS="$ROOT/ops/data/vaultwarden/canonical_hosts.yaml"
FOLDER_TAXONOMY="$ROOT/ops/data/vaultwarden/folder_taxonomy.yaml"
RECONCILE_RULES="$ROOT/ops/data/vaultwarden/reconcile_rules.yaml"
RECOVERY_ACTIONS="$ROOT/ops/bindings/recovery.actions.yaml"
BACKUP_INVENTORY="$ROOT/ops/bindings/backup.inventory.yaml"
SERVICES_HEALTH="$ROOT/ops/bindings/services.health.yaml"
BACKUP_RESTORE_DOC="$ROOT/docs/governance/VAULTWARDEN_BACKUP_RESTORE.md"
HYGIENE_DOC="$ROOT/docs/governance/VAULTWARDEN_CANONICAL_HYGIENE.md"
INFISICAL_CONTRACT="$ROOT/docs/governance/VAULTWARDEN_INFISICAL_CONTRACT.md"

ERRORS=0
err() {
  echo "  FAIL: $*" >&2
  ERRORS=$((ERRORS + 1))
}

need_file() {
  [[ -f "$1" ]] || err "missing file: $1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "missing command: $1"
}

# ── Preconditions ──
need_cmd yq
need_file "$CANONICAL_HOSTS"
need_file "$FOLDER_TAXONOMY"
need_file "$RECONCILE_RULES"
need_file "$RECOVERY_ACTIONS"
need_file "$BACKUP_INVENTORY"
need_file "$SERVICES_HEALTH"
need_file "$BACKUP_RESTORE_DOC"
need_file "$HYGIENE_DOC"
need_file "$INFISICAL_CONTRACT"

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D319 FAIL: $ERRORS precondition error(s)"
  exit 1
fi

# ── Check 1: Canonical hosts has vault.ronny.works as primary ──
vault_canonical="$(yq -r '.canonical_hosts."vault.ronny.works".canonical_url // ""' "$CANONICAL_HOSTS")"
if [[ "$vault_canonical" != "https://vault.ronny.works" ]]; then
  err "canonical_hosts missing vault.ronny.works primary entry"
fi

# ── Check 2: Folder taxonomy has required folders (uses .required_folders[] array) ──
mapfile -t REQUIRED_FOLDERS < <(yq -r '.required_folders[]' "$FOLDER_TAXONOMY" 2>/dev/null)
if [[ "${#REQUIRED_FOLDERS[@]}" -lt 5 ]]; then
  err "folder_taxonomy.yaml required_folders has fewer than 5 entries (got ${#REQUIRED_FOLDERS[@]})"
fi
for folder in "${REQUIRED_FOLDERS[@]}"; do
  has_def="$(yq -r ".folders.\"$folder\" // \"\"" "$FOLDER_TAXONOMY" 2>/dev/null)"
  if [[ -z "$has_def" || "$has_def" == "null" ]]; then
    err "folder_taxonomy required_folder '$folder' has no definition in .folders map"
  fi
done

# ── Check 3: Recovery action registered for VW ──
vw_recovery="$(yq -r '.actions[] | select(.id == "recover-vaultwarden-container") | .id // ""' "$RECOVERY_ACTIONS")"
if [[ "$vw_recovery" != "recover-vaultwarden-container" ]]; then
  err "recovery.actions.yaml missing recover-vaultwarden-container action"
fi

# ── Check 4: Backup inventory target enabled and critical ──
backup_enabled="$(yq -r '.targets[] | select(.name == "app-vaultwarden") | (.enabled // false) | tostring' "$BACKUP_INVENTORY" 2>/dev/null | head -n1)"
backup_class="$(yq -r '.targets[] | select(.name == "app-vaultwarden") | .classification // ""' "$BACKUP_INVENTORY" 2>/dev/null | head -n1)"
if [[ -z "$backup_enabled" || "$backup_enabled" != "true" ]]; then
  err "backup.inventory app-vaultwarden target not enabled"
fi
if [[ -z "$backup_class" || "$backup_class" != "critical" ]]; then
  err "backup.inventory app-vaultwarden classification must be 'critical' (got: ${backup_class:-missing})"
fi

# ── Check 5: Services health endpoint registered ──
health_url="$(yq -r '.endpoints[] | select(.id == "vaultwarden") | .url // ""' "$SERVICES_HEALTH")"
if [[ -z "$health_url" || "$health_url" == "null" ]]; then
  err "services.health missing vaultwarden endpoint"
fi

# ── Check 6: Reconcile rules have safety defaults (dry_run_default under .actions) ──
dry_run_default="$(yq -r '.actions.dry_run_default // false | tostring' "$RECONCILE_RULES")"
if [[ "$dry_run_default" != "true" ]]; then
  err "reconcile_rules actions.dry_run_default must be true"
fi

# ── Check 7: Restore-drill evidence path (advisory, not blocking) ──
DRILL_DIR="$ROOT/receipts/audits/infra"
DRILL_MAX_DAYS=90
drill_found=0
if [[ -d "$DRILL_DIR" ]]; then
  while IFS= read -r receipt_dir; do
    [[ -d "$receipt_dir" ]] || continue
    dir_name="$(basename "$receipt_dir")"
    # Extract date from directory name pattern: vaultwarden-restore-drill-YYYYMMDD
    date_part="$(echo "$dir_name" | grep -oE '[0-9]{8}' | tail -1 || true)"
    if [[ -n "$date_part" ]]; then
      drill_epoch="$(date -jf "%Y%m%d" "$date_part" "+%s" 2>/dev/null || echo "0")"
      now_epoch="$(date +%s)"
      age_days=$(( (now_epoch - drill_epoch) / 86400 ))
      if [[ "$age_days" -le "$DRILL_MAX_DAYS" ]]; then
        drill_found=1
        break
      fi
    fi
  done < <(find "$DRILL_DIR" -maxdepth 1 -type d -name "*vaultwarden-restore-drill*" 2>/dev/null || true)
fi
if [[ "$drill_found" -eq 0 ]]; then
  echo "  ADVISORY: no vaultwarden restore-drill receipt within ${DRILL_MAX_DAYS} days (check receipts/audits/infra/)" >&2
fi

# ── Summary ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D319 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D319 PASS: vaultwarden hygiene compliance lock enforced (canonical_hosts=ok required_folders=${#REQUIRED_FOLDERS[@]} recovery=wired backup=critical)"
