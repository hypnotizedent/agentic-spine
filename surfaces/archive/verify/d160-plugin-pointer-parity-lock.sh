#!/usr/bin/env bash
# TRIAGE: Maintain ops/bindings/plugin.ownership.map.yaml ownership metadata, ensure migrated/pilot pointer paths remain valid, and keep plugin IDs unique.
# D160: Plugin pointer parity lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
MAP="$ROOT/ops/bindings/plugin.ownership.map.yaml"

fail() { echo "D160 FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
[[ -f "$MAP" ]] || fail "missing ownership map: $MAP"
yq e '.' "$MAP" >/dev/null 2>&1 || fail "ownership map is not valid YAML"

errors=0
err() { echo "  $*" >&2; errors=$((errors + 1)); }

# 1) no duplicate plugin IDs
while IFS= read -r dup; do
  [[ -z "$dup" ]] && continue
  err "duplicate plugin_id detected: $dup"
done < <(yq -r '.plugins[].plugin_id' "$MAP" | sort | uniq -d)

# 2) project_owned entries must declare target_repo + target_path
while IFS=$'\t' read -r plugin repo path; do
  [[ -z "$plugin" ]] && continue
  [[ -n "$repo" && "$repo" != "null" ]] || err "project_owned plugin '$plugin' missing target_repo"
  [[ -n "$path" && "$path" != "null" ]] || err "project_owned plugin '$plugin' missing target_path"
done < <(yq -r '.plugins[] | select(.class == "project_owned") | [.plugin_id, (.target_repo // "null"), (.target_path // "null")] | @tsv' "$MAP")

# 3) migrated entries require resolved target path to exist
while IFS=$'\t' read -r plugin repo path; do
  [[ -z "$plugin" ]] && continue
  if [[ -z "$repo" || "$repo" == "null" || -z "$path" || "$path" == "null" ]]; then
    err "migrated plugin '$plugin' missing target metadata"
    continue
  fi
  resolved="${repo%/}/${path#/}"
  [[ -e "$resolved" ]] || err "migrated plugin '$plugin' target path missing: $resolved"
done < <(yq -r '.plugins[] | select(.migration_state == "migrated") | [.plugin_id, (.target_repo // "null"), (.target_path // "null")] | @tsv' "$MAP")

# 4) pilot entries must declare proof receipt and receipt path must exist
while IFS=$'\t' read -r plugin receipt; do
  [[ -z "$plugin" ]] && continue
  if [[ -z "$receipt" || "$receipt" == "null" ]]; then
    err "pilot plugin '$plugin' missing pilot_proof_receipt"
    continue
  fi
  [[ -f "$ROOT/$receipt" ]] || err "pilot plugin '$plugin' missing proof receipt file: $receipt"
done < <(yq -r '.plugins[] | select(.migration_state == "pilot") | [.plugin_id, (.pilot_proof_receipt // "null")] | @tsv' "$MAP")

# 5) class and migration_state enums must remain bounded
while IFS=$'\t' read -r plugin class state; do
  [[ -z "$plugin" ]] && continue
  case "$class" in
    spine_native|project_owned) ;;
    *) err "plugin '$plugin' has invalid class: $class" ;;
  esac
  case "$state" in
    pending|pilot|migrated) ;;
    *) err "plugin '$plugin' has invalid migration_state: $state" ;;
  esac
done < <(yq -r '.plugins[] | [.plugin_id, .class, .migration_state] | @tsv' "$MAP")

if [[ "$errors" -gt 0 ]]; then
  fail "$errors pointer parity violation(s)"
fi

project_owned_count="$(yq -r '[.plugins[] | select(.class == "project_owned")] | length' "$MAP")"
pilot_count="$(yq -r '[.plugins[] | select(.migration_state == "pilot")] | length' "$MAP")"
migrated_count="$(yq -r '[.plugins[] | select(.migration_state == "migrated")] | length' "$MAP")"

echo "D160 PASS: plugin pointer parity lock valid (project_owned=$project_owned_count pilot=$pilot_count migrated=$migrated_count)"
