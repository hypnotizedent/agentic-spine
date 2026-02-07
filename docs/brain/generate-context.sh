#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# generate-context.sh — Build agent context for session start
# ═══════════════════════════════════════════════════════════════
#
# Called by hotkeys (Ctrl+0/2/3) before launching an agent.
# Produces docs/brain/context.md with rules, open loops,
# available CLI tools, and last handoff.
#
# ═══════════════════════════════════════════════════════════════

SP="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OUT="$SP/docs/brain/context.md"

{
  echo "# Agent Context (auto-generated)"
  echo ""
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""

  # ── Section 1: Rules ──
  echo "## Rules"
  echo ""
  if [[ -f "$SP/docs/brain/rules.md" ]]; then
    cat "$SP/docs/brain/rules.md"
  else
    echo "(rules.md not found)"
  fi
  echo ""

  # ── Section 2: Open Loops ──
  echo "## Open Loops"
  echo ""
  if [[ -x "$SP/bin/ops" ]]; then
    "$SP/bin/ops" loops list --open 2>/dev/null || echo "(could not fetch loops)"
  else
    echo "(ops not available)"
  fi
  echo ""

  # ── Section 3: Available CLI Tools ──
  echo "## Available CLI Tools"
  echo ""
  echo "The following tools are installed on this workstation."
  echo "Full catalog: \`ops/bindings/cli.tools.inventory.yaml\`"
  echo ""

  TOOLS_FILE="$SP/ops/bindings/cli.tools.inventory.yaml"
  if [[ -f "$TOOLS_FILE" ]] && command -v yq >/dev/null 2>&1; then
    yq e '.tools[] | "- **" + .id + "** — " + .description' "$TOOLS_FILE" 2>/dev/null
  else
    echo "(cli.tools.inventory.yaml not found or yq not installed)"
  fi
  echo ""

  # ── Section 4: Last Handoff ──
  if [[ -f "$SP/docs/brain/memory.md" ]]; then
    echo "## Last Handoff"
    echo ""
    tail -20 "$SP/docs/brain/memory.md"
    echo ""
  fi

} > "$OUT"

echo "Context written to $OUT"
