#!/usr/bin/env bash
# D416: launchd-topology-integrity-lock
# Replaces retired D297 (runtime-script-registry-name-parity-lock)
# and D298 (orphan-runtime-script-detection-lock).
#
# Enforces:
#   1. Registry → template file: every scheduler registry label has a template on disk
#   2. Template → registry: every plist template has a matching registry entry
#   3. Label ↔ filename: plist internal Label matches filename convention
#   4. Registry consistency: no stale/orphaned template_path references
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"
TEMPLATE_DIR="$ROOT/ops/plugins/infra/host/launchd"

ERRORS=0
CHECKS=0

err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
pass_check() { CHECKS=$((CHECKS + 1)); }

need_cmd() { command -v "$1" >/dev/null 2>&1 || { err "missing command: $1"; return 1; }; }
need_file() { [[ -f "$1" ]] || { err "missing file: $1"; return 1; }; }

need_cmd yq || exit 1
need_file "$REGISTRY" || exit 1
[[ -d "$TEMPLATE_DIR" ]] || { err "missing template dir: $TEMPLATE_DIR"; exit 1; }

# --- Check 1: Registry → template file parity ---
# Every active registry label with template_source=spine must point to an existing template file.
while IFS=$'\t' read -r label template_path; do
  if [[ -z "$template_path" || "$template_path" == "null" ]]; then
    err "registry label '$label' has no template_path"
  elif [[ ! -f "$ROOT/$template_path" ]]; then
    err "registry label '$label' points to missing template: $template_path"
  else
    pass_check
  fi
done < <(yq e -r '.labels[] | select(.state == "active") | [.label, .template_path] | @tsv' "$REGISTRY" 2>/dev/null)

# --- Check 2: Template → registry reverse parity ---
# Every plist template in the template dir must have a matching registry entry.
for plist_file in "$TEMPLATE_DIR"/*.plist; do
  [[ -f "$plist_file" ]] || continue
  label="$(basename "$plist_file" .plist)"
  match="$(yq e -r ".labels[] | select(.label == \"$label\") | .label" "$REGISTRY" 2>/dev/null)"
  if [[ -z "$match" ]]; then
    err "template '$label' has no matching registry entry"
  else
    pass_check
  fi
done

# --- Check 3: Label ↔ filename parity ---
# The internal Label key in each plist must match the filename.
for plist_file in "$TEMPLATE_DIR"/*.plist; do
  [[ -f "$plist_file" ]] || continue
  expected_label="$(basename "$plist_file" .plist)"
  # plutil or PlistBuddy may not be available in all envs; try both
  if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
    actual_label="$(/usr/libexec/PlistBuddy -c "Print :Label" "$plist_file" 2>/dev/null || echo "")"
  elif command -v plutil >/dev/null 2>&1; then
    actual_label="$(plutil -extract Label raw "$plist_file" 2>/dev/null || echo "")"
  else
    # Skip check if no plist reader is available
    continue
  fi
  if [[ -z "$actual_label" ]]; then
    err "template '$expected_label' has no Label key"
  elif [[ "$expected_label" != "$actual_label" ]]; then
    err "template label mismatch: file='$expected_label' Label='$actual_label'"
  else
    pass_check
  fi
done

# --- Check 4: Registry template_path consistency ---
# No registry entry should reference a template_path outside the canonical template dir.
while IFS=$'\t' read -r label template_path; do
  if [[ -n "$template_path" && "$template_path" != "null" ]]; then
    case "$template_path" in
      ops/plugins/infra/host/launchd/*) pass_check ;;
      *) err "registry label '$label' has non-canonical template_path: $template_path" ;;
    esac
  fi
done < <(yq e -r '.labels[] | select(.state == "active") | [.label, .template_path] | @tsv' "$REGISTRY" 2>/dev/null)

# --- Result ---
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D416 FAIL: $ERRORS error(s) in $CHECKS successful checks"
  exit 1
fi

echo "D416 PASS: launchd topology integrity ($CHECKS checks)"
exit 0
