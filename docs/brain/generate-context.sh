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

  # ── Section 4: Available Capabilities ──
  echo "## Available Capabilities"
  echo ""
  echo "Capabilities are the spine's governed actions (SSOT: \`ops/capabilities.yaml\`)."
  echo ""
  echo "Discovery:"
  echo ""
  printf '%s\n' '```bash'
  echo "./bin/ops cap list"
  echo "./bin/ops cap show CAPABILITY_NAME"
  printf '%s\n' '```'
  echo ""

  CAPS_FILE="$SP/ops/capabilities.yaml"
  if [[ -f "$CAPS_FILE" ]] && command -v yq >/dev/null 2>&1; then
    caps_updated="$(yq e -r '.updated // ""' "$CAPS_FILE" 2>/dev/null || true)"
    [[ -n "${caps_updated:-}" ]] && echo "- Registry updated: \`${caps_updated}\`"

    if command -v git >/dev/null 2>&1 && git -C "$SP" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      last_change="$(git -C "$SP" log -n 1 --pretty=format:'%h %ad %s' --date=short -- ops/capabilities.yaml 2>/dev/null || true)"
      [[ -n "${last_change:-}" ]] && echo "- Last change: \`${last_change}\`"
    fi
    echo ""

    echo "### Namespace Counts"
    yq e -r '.capabilities | keys | .[]' "$CAPS_FILE" 2>/dev/null \
      | awk -F. '{print $1}' \
      | sort \
      | uniq -c \
      | sort -nr \
      | awk '{printf "- %s: %s\n", $2, $1}' \
      || echo "(unavailable)"
    echo ""

    echo "### Top Used (last 200 done capability runs)"
    LEDGER="$SP/mailroom/state/ledger.csv"
    if [[ -f "$LEDGER" ]] && command -v python3 >/dev/null 2>&1; then
      python3 - "$LEDGER" <<'PY'
import csv
import sys
from collections import Counter, deque

path = sys.argv[1]
rows = deque(maxlen=200)

try:
    with open(path, "r", encoding="utf-8") as f:
        r = csv.DictReader(f)
        for row in r:
            run_id = (row.get("run_id") or "").strip()
            status = (row.get("status") or "").strip().lower()
            cap = (row.get("prompt_file") or "").strip()
            if not run_id.startswith("CAP-"):
                continue
            if status != "done":
                continue
            if not cap:
                continue
            rows.append(cap)
except Exception:
    print("(unavailable)")
    sys.exit(0)

if not rows:
    print("(no recent capability runs)")
    sys.exit(0)

counts = Counter(rows)
for cap, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:10]:
    print(f"- {cap} ({n})")
PY
    else
      echo "(ledger.csv not found or python3 not installed)"
    fi
  else
    echo "(ops/capabilities.yaml not found or yq not installed)"
  fi
  echo ""

  # ── Section 5: Available Agents ──
  echo "## Available Agents"
  echo ""
  echo "Domain-specific agents handle application-layer problems."
  echo "Full registry: \`ops/bindings/agents.registry.yaml\`"
  echo ""

  AGENTS_FILE="$SP/ops/bindings/agents.registry.yaml"
  if [[ -f "$AGENTS_FILE" ]] && command -v yq >/dev/null 2>&1; then
    while IFS='|' read -r aid adomain adesc astatus; do
      [[ -z "$aid" ]] && continue
      if [[ "$astatus" == "pending" ]]; then
        echo "- **${aid}** [${adomain}] (implementation pending) — ${adesc}"
      else
        echo "- **${aid}** [${adomain}] — ${adesc}"
      fi
    done < <(yq e '.agents[] | .id + "|" + .domain + "|" + .description + "|" + .implementation_status' "$AGENTS_FILE" 2>/dev/null)
    echo ""
    echo "Routing: when a problem matches an agent domain, consult that agent first."
  else
    echo "(agents.registry.yaml not found or yq not installed)"
  fi
  echo ""

  # ── Section 6: Gate Reference Card ──
  echo "## Gate Reference Card"
  echo ""
  GATE_REGISTRY="$SP/ops/bindings/gate.registry.yaml"
  if [[ -f "$GATE_REGISTRY" ]] && command -v yq >/dev/null 2>&1; then
    gate_count="$(yq -r '.gates | length' "$GATE_REGISTRY" 2>/dev/null || echo "?")"
    echo "D1-D85 drift surface ($gate_count gates). Run \`/verify\` to check, \`/gates\` to browse, \`/triage\` on failure."
    echo ""
    echo "| Category | Gates | Focus |"
    echo "|----------|-------|-------|"
    yq -r '.categories[] | select(.id != "retired") | .id + "\t" + .description' "$GATE_REGISTRY" 2>/dev/null | while IFS=$'\t' read -r cat_id desc; do
      [[ -z "$cat_id" ]] && continue
      gates="$(yq -r "[.gates[] | select(.category == \"$cat_id\" and .retired != true) | .id] | join(\", \")" "$GATE_REGISTRY" 2>/dev/null || echo "?")"
      echo "| $cat_id | $gates | $desc |"
    done
    echo ""
    echo "Critical gates: $(yq -r '[.gates[] | select(.severity == "critical") | .id] | join(", ")' "$GATE_REGISTRY" 2>/dev/null || echo "?")"
  else
    echo "(gate.registry.yaml not found or yq not installed)"
  fi
  echo ""

  # ── Section 7: Capability Precondition Hints ──
  echo "## Capability Precondition Hints"
  echo ""
  echo "Before API work: \`./bin/ops cap run secrets.binding\` then \`./bin/ops cap run secrets.auth.status\`"
  echo ""
  echo "Common workflows:"
  echo "- Fix a bug: \`/fix\` (file gap -> claim -> fix -> verify -> close)"
  echo "- Triage gate failure: \`/triage\` (read gate script, extract TRIAGE hint)"
  echo "- Multi-agent writes: \`/propose\` (submit proposal, operator applies)"
  echo "- Multi-step work: \`/loop\` (create scope -> file gaps per phase -> execute)"
  echo "- Before changes: \`/check\` (proactive gate validation)"
  echo ""

  # ── Section 8: Last Handoff ──
  if [[ -f "$SP/docs/brain/memory.md" ]]; then
    echo "## Last Handoff"
    echo ""
    tail -20 "$SP/docs/brain/memory.md"
    echo ""
  fi

} > "$OUT"

echo "Context written to $OUT"
