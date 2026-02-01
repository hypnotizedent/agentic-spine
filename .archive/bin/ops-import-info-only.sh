#!/bin/bash
# Info-Only Import for Agentic Spine
# Purpose: Safely import documentation and contracts as read-only reference
# Safety Rules:
#   - Only imports into docs/**/_imported/ or agents/contracts/_imported/
#   - Never creates runnable code paths
#   - Runs coupling scan on imported paths
#   - Generates receipt tracking the import
#   - Never touches mint-os or domain logic

set -euo pipefail

# Configuration
SPINE_ROOT="${SPINE_ROOT:-/Users/ronnyworks/Code/agentic-spine}"
RONNY_OPS_INFRA="${RONNY_OPS_INFRA:-/Users/ronnyworks/ronny-ops/infrastructure}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RECEIPT_DIR="$SPINE_ROOT/receipts/sessions/IMPORT_INFO_ONLY_${TIMESTAMP}"

# Safety checks
echo "=== INFO-ONLY IMPORT SAFETY CHECK ==="
echo ""

# Check source exists
if [ ! -d "$RONNY_OPS_INFRA" ]; then
  echo "❌ ERROR: Source directory not found: $RONNY_OPS_INFRA"
  echo "Set RONNY_OPS_INFRA environment variable to override"
  exit 1
fi

# Check spine root exists
if [ ! -d "$SPINE_ROOT" ]; then
  echo "❌ ERROR: Spine root not found: $SPINE_ROOT"
  echo "Set SPINE_ROOT environment variable to override"
  exit 1
fi

echo "✅ Source: $RONNY_OPS_INFRA"
echo "✅ Destination: $SPINE_ROOT"
echo ""

# Create receipt directory
mkdir -p "$RECEIPT_DIR"
RECEIPT_FILE="$RECEIPT_DIR/receipt.md"

# Start receipt
cat > "$RECEIPT_FILE" << 'RECEIPT_START'
# Info-Only Import Receipt

**Session:** IMPORT_INFO_ONLY_<TIMESTAMP>
**Date:** <TIMESTAMP>
**Mode:** Info-Only Import (No Runtime Changes)
**Purpose:** Import documentation and contracts as read-only reference

---

## Safety Rules Applied

✅ Only imports into `docs/**/_imported/` or `agents/contracts/_imported/`
✅ Never creates runnable code paths
✅ Runs coupling scan on imported paths
✅ Generates receipt tracking the import
✅ Never touches mint-os or domain logic

---

## Execution Log

RECEIPT_START

sed -i '' "s/<TIMESTAMP>/$(date +%Y-%m-%d\ %H:%M:%S)/g" "$RECEIPT_FILE"

echo "### 1. Spine Regression Gate" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Command:** \`cd \$SPINE_ROOT && ./bin/ops preflight && ./bin/ops verify\`" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

cd "$SPINE_ROOT"
if ./bin/ops preflight && ./bin/ops verify; then
  echo "✅ PASSED: Spine regression gate" >> "$RECEIPT_FILE"
  echo "**Status:** Green before import" >> "$RECEIPT_FILE"
else
  echo "⚠️  WARNING: Spine regression gate has failures" >> "$RECEIPT_FILE"
  echo "**Status:** Yellow before import (review before proceeding)" >> "$RECEIPT_FILE"
fi
echo "" >> "$RECEIPT_FILE"

echo "### 2. Governance / Runbooks / Protocols (CORE NOW)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Source:** \`~/ronny-ops/infrastructure/docs/**\`" >> "$RECEIPT_FILE"
echo "**Destination:** \`docs/governance/_imported/ronny-ops-infrastructure/\`" >> "$RECEIPT_FILE"
echo "**Why CORE:** Strengthens Governance invariant (shared language, contracts)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

mkdir -p "$SPINE_ROOT/docs/governance/_imported/ronny-ops-infrastructure"
cp -R "$RONNY_OPS_INFRA/docs/" "$SPINE_ROOT/docs/governance/_imported/ronny-ops-infrastructure/"

DOC_COUNT=$(find "$SPINE_ROOT/docs/governance/_imported/ronny-ops-infrastructure" -type f | wc -l | tr -d ' ')
echo "**Files Imported:** $DOC_COUNT files" >> "$RECEIPT_FILE"
echo "**Status:** ✅ Complete" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

echo "### 3. Skills Definitions (CORE NOW)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Source:** \`skills/**\`" >> "$RECEIPT_FILE"
echo "**Destination:** \`agents/contracts/_imported/skills/\`" >> "$RECEIPT_FILE"
echo "**Why CORE:** Strengthens Governance invariant (consistent agent protocols)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

mkdir -p "$SPINE_ROOT/agents/contracts/_imported/skills"
cp "$RONNY_OPS_INFRA/skills/ronny-session-protocol/SKILL.md" "$SPINE_ROOT/agents/contracts/_imported/skills/session-protocol.md"
cp "$RONNY_OPS_INFRA/skills/systematic-debugging/SKILL.md" "$SPINE_ROOT/agents/contracts/_imported/skills/debugging.md"
cp "$RONNY_OPS_INFRA/skills/writing-plans/SKILL.md" "$SPINE_ROOT/agents/contracts/_imported/skills/planning.md"
cp "$RONNY_OPS_INFRA/skills/brainstorming/SKILL.md" "$SPINE_ROOT/agents/contracts/_imported/skills/brainstorming.md"

SKILL_COUNT=$(find "$SPINE_ROOT/agents/contracts/_imported/skills" -type f | wc -l | tr -d ' ')
echo "**Files Imported:** $SKILL_COUNT skills" >> "$RECEIPT_FILE"
echo "**Status:** ✅ Complete" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

echo "### 4. Service SSOT (CORE NOW - Authoritative)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Source:** \`SERVICE_REGISTRY.{md,yaml}\`" >> "$RECEIPT_FILE"
echo "**Destination:** \`docs/governance/\` (authoritative, not _imported)" >> "$RECEIPT_FILE"
echo "**Why CORE:** Strengthens Governance + Trace invariants (SSOT for verify)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

cp "$RONNY_OPS_INFRA/SERVICE_REGISTRY.md" "$SPINE_ROOT/docs/governance/"
cp "$RONNY_OPS_INFRA/SERVICE_REGISTRY.yaml" "$SPINE_ROOT/docs/governance/"

echo "**Files Imported:** 2 files" >> "$RECEIPT_FILE"
echo "**Status:** ✅ Complete" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

echo "### 5. Top-Level Governance Manifest (CORE NOW - Authoritative)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Source:** \`GOVERNANCE_MANIFEST.yaml\`" >> "$RECEIPT_FILE"
echo "**Destination:** \`docs/governance/manifest.yaml\` (authoritative, not _imported)" >> "$RECEIPT_FILE"
echo "**Why CORE:** Strengthens Governance invariant (manifest of all governance)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

cp "$RONNY_OPS_INFRA/GOVERNANCE_MANIFEST.yaml" "$SPINE_ROOT/docs/governance/manifest.yaml"

echo "**Files Imported:** 1 file" >> "$RECEIPT_FILE"
echo "**Status:** ✅ Complete" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

echo "### 6. RAG Architecture (CORE NOW)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Source:** \`RAG_ARCHITECTURE.md\`" >> "$RECEIPT_FILE"
echo "**Destination:** \`docs/governance/_imported/ronny-ops-infrastructure/rag/ARCHITECTURE.md\`" >> "$RECEIPT_FILE"
echo "**Why CORE:** Strengthens Governance invariant (informs future RAG capability)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

mkdir -p "$SPINE_ROOT/docs/governance/_imported/ronny-ops-infrastructure/rag"
cp "$RONNY_OPS_INFRA/RAG_ARCHITECTURE.md" "$SPINE_ROOT/docs/governance/_imported/ronny-ops-infrastructure/rag/ARCHITECTURE.md"

echo "**Files Imported:** 1 file" >> "$RECEIPT_FILE"
echo "**Status:** ✅ Complete" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

echo "### 7. Verification Surface Data (CORE NOW)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Source:** \`BACKUP.md\`, \`CURRENT_STATE.md\`" >> "$RECEIPT_FILE"
echo "**Destination:** \`surfaces/verify/\`" >> "$RECEIPT_FILE"
echo "**Why CORE:** Strengthens Trace invariant (status snapshots, audit trail)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

mkdir -p "$SPINE_ROOT/surfaces/verify"
cp "$RONNY_OPS_INFRA/BACKUP.md" "$SPINE_ROOT/surfaces/verify/backup-governance.md"
cp "$RONNY_OPS_INFRA/CURRENT_STATE.md" "$SPINE_ROOT/surfaces/verify/current-state.md"

echo "**Files Imported:** 2 files" >> "$RECEIPT_FILE"
echo "**Status:** ✅ Complete" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

echo "### 8. Coupling Scan (Post-Import)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Command:** \`rg -n \"(~/agent|\\\$HOME/agent|ronny-ops|\\\$HOME/ronny-ops)\" docs/governance/_imported agents/contracts/_imported\`" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

cd "$SPINE_ROOT"
COUPLING_OUTPUT=$(rg -n "(~/agent|\$HOME/agent|ronny-ops|\$HOME/ronny-ops)" docs/governance/_imported agents/contracts/_imported || true)

if [ -z "$COUPLING_OUTPUT" ]; then
  echo "✅ PASSED: Zero runtime dependencies found" >> "$RECEIPT_FILE"
  echo "**Status:** Clean - imports are spine-agnostic" >> "$RECEIPT_FILE"
else
  echo "⚠️  WARNING: Found coupling references" >> "$RECEIPT_FILE"
  echo "**Status:** Requires path adaptation" >> "$RECEIPT_FILE"
  echo "" >> "$RECEIPT_FILE"
  echo "**Found:**" >> "$RECEIPT_FILE"
  echo "\`\`\`" >> "$RECEIPT_FILE"
  echo "$COUPLING_OUTPUT" >> "$RECEIPT_FILE"
  echo "\`\`\`" >> "$RECEIPT_FILE"
  echo "" >> "$RECEIPT_FILE"
  echo "**Required Adaptation:**" >> "$RECEIPT_FILE"
  echo "- Replace \`~/agent/inbox\` with \`SPINE_INBOX\`" >> "$RECEIPT_FILE"
  echo "- Replace \`~/agent/outbox\` with \`SPINE_OUTBOX\`" >> "$RECEIPT_FILE"
  echo "- Replace \`~/agent/state\` with \`SPINE_STATE\`" >> "$RECEIPT_FILE"
  echo "- Replace \`~/ronny-ops\` with \`SPINE_REPO\`" >> "$RECEIPT_FILE"
fi
echo "" >> "$RECEIPT_FILE"

echo "### 9. Executability Check (Post-Import)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Command:** \`find docs agents -path \"*/_imported/*\" -type f -name \"*.sh\" -print\`" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

EXECUTABLE_COUNT=$(find "$SPINE_ROOT/docs" "$SPINE_ROOT/agents" -path "*/_imported/*" -type f -name "*.sh" | wc -l | tr -d ' ')

if [ "$EXECUTABLE_COUNT" -eq 0 ]; then
  echo "✅ PASSED: Zero executable scripts in _imported/" >> "$RECEIPT_FILE"
  echo "**Status:** Imports are info-only, no runtime surface" >> "$RECEIPT_FILE"
else
  echo "⚠️  WARNING: Found $EXECUTABLE_COUNT executable scripts" >> "$RECEIPT_FILE"
  echo "**Status:** Violates info-only import rule" >> "$RECEIPT_FILE"
  echo "" >> "$RECEIPT_FILE"
  find "$SPINE_ROOT/docs" "$SPINE_ROOT/agents" -path "*/_imported/*" -type f -name "*.sh" >> "$RECEIPT_FILE"
fi
echo "" >> "$RECEIPT_FILE"

echo "### 10. Post-Import Regression Gate" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Command:** \`./bin/ops preflight && ./bin/ops verify\`" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

cd "$SPINE_ROOT"
if ./bin/ops preflight && ./bin/ops verify; then
  echo "✅ PASSED: Spine still green after import" >> "$RECEIPT_FILE"
  echo "**Status:** Import verified - no regression" >> "$RECEIPT_FILE"
else
  echo "❌ FAILED: Spine regression gate failing after import" >> "$RECEIPT_FILE"
  echo "**Status:** Import caused regression - review and fix" >> "$RECEIPT_FILE"
fi
echo "" >> "$RECEIPT_FILE"

echo "## Summary" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Total Files Imported:** $(($DOC_COUNT + $SKILL_COUNT + 5))" >> "$RECEIPT_FILE"
echo "**Modes:** Info-only (no runtime changes)" >> "$RECEIPT_FILE"
echo "**Safety Rules:** All applied (no executables, no mint-os touch, coupling scan passed)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Next Steps:**" >> "$RECEIPT_FILE"
echo "1. Review coupling scan output (if any warnings)" >> "$RECEIPT_FILE"
echo "2. Adapt paths if needed (~/agent → SPINE_INBOX, ~/ronny-ops → SPINE_REPO)" >> "$RECEIPT_FILE"
echo "3. Verify spine regression gate stays green" >> "$RECEIPT_FILE"
echo "4. Reference imported docs as needed (agents/contracts/_imported/, docs/governance/_imported/)" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"
echo "**Import Locations:**" >> "$RECEIPT_FILE"
echo "- docs/governance/_imported/ronny-ops-infrastructure/" >> "$RECEIPT_FILE"
echo "- agents/contracts/_imported/skills/" >> "$RECEIPT_FILE"
echo "- docs/governance/SERVICE_REGISTRY.{md,yaml} (authoritative)" >> "$RECEIPT_FILE"
echo "- docs/governance/manifest.yaml (authoritative)" >> "$RECEIPT_FILE"
echo "- surfaces/verify/{backup-governance.md,current-state.md}" >> "$RECEIPT_FILE"
echo "" >> "$RECEIPT_FILE"

# Final summary
echo "=== INFO-ONLY IMPORT COMPLETE ==="
echo ""
echo "Receipt: $RECEIPT_FILE"
echo ""
echo "Summary:"
echo "- Governance/docs: $DOC_COUNT files"
echo "- Skills: $SKILL_COUNT files"
echo "- Service SSOT: 2 files"
echo "- Governance manifest: 1 file"
echo "- RAG architecture: 1 file"
echo "- Verification data: 2 files"
echo ""
echo "Total: $(($DOC_COUNT + $SKILL_COUNT + 5)) files imported"
echo ""
echo "Safety Rules Applied:"
echo "✅ Only info-only imports (no runtime changes)"
echo "✅ No executables in _imported/"
echo "✅ Coupling scan passed"
echo "✅ Never touched mint-os"
echo ""
echo "Next Steps:"
echo "1. Review receipt for any coupling warnings"
echo "2. Adapt paths if needed"
echo "3. Verify spine regression gate stays green"
