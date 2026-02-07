# LOOP-GOV-CLI-TOOL-DISCOVERY-20260207

> **Status:** open
> **Severity:** medium
> **Owner:** @ronny
> **Created:** 2026-02-07
> **Blocked by:** none

## Problem Statement

An agent was asked to generate a QR code using `qrencode` — a tool that is:
- Installed via Homebrew
- Registered in `ops/bindings/maker.tools.inventory.yaml`
- Probed and enabled

The agent could not find it. It searched the workbench repo, MCP server catalogs, and file contents — but never discovered the maker tools binding. The tool was correctly registered but **invisible to agents**.

## Root Cause

Five missing links in the agent-to-tool discovery chain:

| # | Gap | Where it should be |
|---|-----|--------------------|
| 1 | Maker tools binding is domain-scoped | `ops/bindings/maker.tools.inventory.yaml` has no cross-domain visibility — agents don't know to look there for general CLI tools |
| 2 | No context injection for available tools | `docs/brain/generate-context.sh` doesn't exist yet (referenced in brain README but never created) |
| 3 | SESSION_PROTOCOL.md silent on tool discovery | No step says "check bindings for available tools" |
| 4 | MACBOOK_SSOT stopped at package-manager level | Lists Homebrew as infrastructure but doesn't inventory installed packages |
| 5 | No drift gate validates tool discoverability | D40 validates maker binding YAML parses but doesn't ensure cross-domain discovery works |

## Canonical Plan

### Phase 1: Create `ops/bindings/cli.tools.inventory.yaml`

**Purpose:** Cross-domain tool catalog that agents consult for "what CLI tools are available?"

**Schema:**
```yaml
version: 1
updated: "2026-02-07"

# Cross-domain CLI tool discovery index.
# Agents: consult this file when asked to use a CLI tool.
# Tools registered here are available on the local workstation.
#
# Adding tool N+1:
#   1. Add entry here (or in domain-specific binding like maker.tools.inventory.yaml)
#   2. If domain-specific, add a cross-ref entry here with source_binding
#   3. Install (brew/pip/apt)
#   4. Verify: ops cap run cli.tools.status
#
# This file does NOT replace domain-specific bindings.
# It provides a single lookup surface for agents across all domains.

tools:
  # ── Cross-refs from maker.tools.inventory.yaml ──
  - id: qrencode
    category: encoding
    description: "QR code generation (PNG/SVG/terminal)"
    probe: "command -v qrencode"
    source_binding: "ops/bindings/maker.tools.inventory.yaml"
    cross_domain: true

  - id: zint
    category: encoding
    description: "50+ barcode formats (Code128, EAN, DataMatrix, QR, UPC)"
    probe: "command -v zint"
    source_binding: "ops/bindings/maker.tools.inventory.yaml"
    cross_domain: true

  - id: imagemagick
    category: imaging
    description: "Image compositing, resize, annotate, convert"
    probe: "command -v magick"
    source_binding: "ops/bindings/maker.tools.inventory.yaml"
    cross_domain: true

  # ── General CLI tools (no domain-specific binding) ──
  # Add entries here for Homebrew/pip/apt tools that agents may need.
  # Use `brew list` to audit what's installed and decide what to register.
  #
  # Example:
  # - id: jq
  #   category: data
  #   description: "JSON processor"
  #   probe: "command -v jq"
  #   install_method: brew
  #   cross_domain: true
```

**Key design decisions:**
- Does NOT duplicate full entries from domain bindings — uses `source_binding` cross-ref
- `cross_domain: true` means "agents should find this regardless of task domain"
- Probe-only for cross-refs (full install details live in source binding)
- General tools get full entries here (like `maker.tools.inventory.yaml` format)

**Acceptance criteria:**
- [ ] File parses with `yq e '.' ops/bindings/cli.tools.inventory.yaml`
- [ ] All probes return 0 for enabled tools
- [ ] No duplicate entries (cross-refs point to source binding)

---

### Phase 2: Create `docs/brain/generate-context.sh`

**Purpose:** Auto-generate `context.md` at session start, including available tools.

**Behavior:**
```bash
#!/usr/bin/env bash
set -euo pipefail

SP="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OUT="$SP/docs/brain/context.md"

{
  echo "# Agent Context (auto-generated)"
  echo ""
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""

  # Section 1: Rules
  echo "## Rules"
  cat "$SP/docs/brain/rules.md"
  echo ""

  # Section 2: Open loops
  echo "## Open Loops"
  "$SP/bin/ops" loops list --open 2>/dev/null || echo "(could not fetch loops)"
  echo ""

  # Section 3: Available CLI tools
  echo "## Available CLI Tools"
  echo ""
  echo "The following tools are installed and available on this workstation."
  echo "Consult \`ops/bindings/cli.tools.inventory.yaml\` for the full catalog."
  echo ""

  TOOLS_FILE="$SP/ops/bindings/cli.tools.inventory.yaml"
  if [[ -f "$TOOLS_FILE" ]] && command -v yq >/dev/null 2>&1; then
    yq e '.tools[] | .id + " — " + .description' "$TOOLS_FILE" 2>/dev/null \
      | while read -r line; do echo "- $line"; done
  else
    echo "(cli.tools.inventory.yaml not found or yq not installed)"
  fi
  echo ""

  # Section 4: Memory (last handoff)
  if [[ -f "$SP/docs/brain/memory.md" ]]; then
    echo "## Last Handoff"
    tail -20 "$SP/docs/brain/memory.md"
    echo ""
  fi

} > "$OUT"

echo "Context written to $OUT"
```

**Acceptance criteria:**
- [ ] Script is executable (`chmod +x`)
- [ ] Produces `docs/brain/context.md` with tool availability section
- [ ] Hotkeys (Ctrl+0/2/3) call this script before launching agent
- [ ] Tools section lists all entries from `cli.tools.inventory.yaml`

---

### Phase 3: Create D44 drift gate (`d44-cli-tools-discovery-lock.sh`)

**Purpose:** Validate that the CLI tool discovery chain is intact.

**Checks:**
1. `ops/bindings/cli.tools.inventory.yaml` exists and parses
2. All cross-ref `source_binding` files exist
3. All probes for `cross_domain: true` tools return 0
4. `docs/brain/generate-context.sh` exists and is executable (when created)

**Template:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# D44: CLI Tools Discovery Lock
# Purpose: validate agent tool discovery chain is intact.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INVENTORY="$ROOT/ops/bindings/cli.tools.inventory.yaml"

fail() { echo "D44 FAIL: $*" >&2; exit 1; }

# 1. Inventory exists and parses
[[ -f "$INVENTORY" ]] || fail "cli.tools.inventory.yaml missing"
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
yq e '.' "$INVENTORY" >/dev/null 2>&1 || fail "cli.tools.inventory.yaml invalid YAML"

# 2. Cross-ref source bindings exist
SOURCES="$(yq e '.tools[] | select(.source_binding) | .source_binding' "$INVENTORY" 2>/dev/null | sort -u)"
for src in $SOURCES; do
  [[ -f "$ROOT/$src" ]] || fail "source binding missing: $src"
done

# 3. Probes pass for cross-domain tools
PROBES="$(yq e '.tools[] | select(.cross_domain == true) | .id + "|" + .probe' "$INVENTORY" 2>/dev/null)"
for entry in $PROBES; do
  TOOL_ID="${entry%%|*}"
  PROBE="${entry#*|}"
  eval "$PROBE" >/dev/null 2>&1 || fail "probe failed for $TOOL_ID: $PROBE"
done

echo "D44 PASS: cli tools discovery chain intact"
```

**Acceptance criteria:**
- [ ] Gate wired into `drift-gate.sh` after D43
- [ ] Passes when inventory + probes are correct
- [ ] Fails if inventory missing, source binding missing, or probe fails

---

### Phase 4: Update `SESSION_PROTOCOL.md` + `brain/rules.md`

**SESSION_PROTOCOL.md changes:**

Add to "Session steps > 2. Load context":
```markdown
   - Check available CLI tools: review `ops/bindings/cli.tools.inventory.yaml` or
     the "Available CLI Tools" section in `.brain/context.md`. If a user asks you
     to use a tool, check this inventory before searching the filesystem or web.
```

**brain/rules.md changes:**

Add entry to the Commands section:
```markdown
# Available tools
cat ops/bindings/cli.tools.inventory.yaml  # What CLI tools are installed
```

Add to Entry Points table:
```markdown
| CLI tools | ops/bindings/cli.tools.inventory.yaml |
```

**Acceptance criteria:**
- [ ] SESSION_PROTOCOL.md has tool discovery step
- [ ] rules.md references cli.tools.inventory.yaml
- [ ] An agent following SESSION_PROTOCOL would find qrencode within 1 lookup

---

### Phase 5: Log GAP-OP-014

**Entry for `ops/bindings/operational.gaps.yaml`:**

```yaml
  - id: GAP-OP-014
    discovered_by: "LOOP-GOV-CLI-TOOL-DISCOVERY-20260207"
    discovered_at: "2026-02-07"
    type: agent-behavior
    doc: null
    description: |
      Agent could not discover qrencode despite it being registered in
      maker.tools.inventory.yaml. The tool is domain-scoped (maker plugin)
      with no cross-domain discovery path. Session protocol, brain context,
      and rules all lack tool discovery guidance. Agent searched workbench
      repo, MCP catalogs, and file contents but never found the binding.
    severity: medium
    status: fixed
    fixed_in: "LOOP-GOV-CLI-TOOL-DISCOVERY-20260207"
    notes: |
      Fixed by: cli.tools.inventory.yaml (cross-domain catalog),
      generate-context.sh (tool injection into agent context),
      D44 drift gate (discovery chain validation),
      SESSION_PROTOCOL.md + rules.md updates (agent guidance).
```

---

### Phase 6: Verification

1. `ops verify` passes (all gates including new D44)
2. Agent discovery test: a new agent session should see "Available CLI Tools" in context and find qrencode in < 1 lookup
3. `generate-context.sh` produces context.md with tool section
4. GAP-OP-014 logged and status=fixed

---

## Execution Order

```
P5 (log gap)  ─── can be done immediately (no dependencies)
P1 (binding)  ─── can be done immediately
P2 (context)  ─── depends on P1 (reads the binding)
P3 (D44 gate) ─── depends on P1 (validates the binding)
P4 (docs)     ─── depends on P1 (references the binding)
P6 (verify)   ─── depends on P1-P5 all complete
```

Parallelizable: P1 + P5 can run together. P2 + P3 + P4 can run together after P1.

## What This Prevents

After this loop closes, any agent in any context will:
1. See available CLI tools in their startup context (generate-context.sh)
2. Know to check `cli.tools.inventory.yaml` when asked about tools (SESSION_PROTOCOL)
3. Find cross-domain tools regardless of which binding registered them (cross-refs)
4. Have the discovery chain validated by drift gate D44 on every verify

No more "I can't find qrencode" moments.
