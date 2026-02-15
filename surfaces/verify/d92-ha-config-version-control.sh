#!/usr/bin/env bash
# TRIAGE: Ensure HA config files are extracted to workbench. Run ha.config.extract to populate.
# D92: HA config version control
# Enforces: workbench/infra/homeassistant/config/ exists with required HA config files.
# Freshness: files must be < 30 days old.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
WORKBENCH="${WORKBENCH_ROOT:-$HOME/code/workbench}"
CONFIG_DIR="$WORKBENCH/infra/homeassistant/config"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

# ── 1. Config directory exists ──
if [[ ! -d "$CONFIG_DIR" ]]; then
  err "workbench/infra/homeassistant/config/ directory does not exist"
  echo "D92 FAIL: $ERRORS check(s) failed"
  exit 1
fi

# ── 2. Required files exist and are non-empty ──
REQUIRED_FILES=(
  configuration.yaml
  automations.yaml
  scripts.yaml
  scenes.yaml
)

for file in "${REQUIRED_FILES[@]}"; do
  filepath="$CONFIG_DIR/$file"
  if [[ ! -f "$filepath" ]]; then
    err "$file does not exist in workbench HA config"
  elif [[ ! -s "$filepath" ]]; then
    err "$file is empty"
  else
    ok "$file exists and is non-empty"
  fi
done

# ── 3. Freshness check (< 30 days) ──
if [[ -f "$CONFIG_DIR/configuration.yaml" ]]; then
  file_age_days=$(( ($(date +%s) - $(stat -f %m "$CONFIG_DIR/configuration.yaml")) / 86400 ))
  if [[ "$file_age_days" -gt 30 ]]; then
    err "configuration.yaml is ${file_age_days} days old (max 30). Run: ./bin/ops cap run ha.config.extract"
  else
    ok "configuration.yaml freshness: ${file_age_days}d (max 30)"
  fi
fi

# ── Result ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D92 FAIL: $ERRORS check(s) failed"
  exit 1
fi
exit 0
