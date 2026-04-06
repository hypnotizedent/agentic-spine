#!/usr/bin/env bash
set -euo pipefail

# Front-Door Enforcement Hook (PreToolUse: Edit, Write)
#
# Blocks governed-path mutations without session admission context.
# This is the toolchain enforcement point that makes governed mutation
# stop being optional when it goes through Claude Code.
#
# Governed paths: ops/, bin/, surfaces/
# Admission check: SPINE_ENTRY_PACKET_PATH env + file exists,
#   OR recent entry packet in $SPINE_STATE/entry-packets/ (<4h)
# Allowlisted: everything outside governed paths, all read-only tools
#
# Contract: ops/bindings/session.admission.contract.yaml
# Gate: D75 (gap registry), pre-commit hooks (git), this hook (toolchain)

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || true)

# Only enforce on Edit and Write
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) echo '{}'; exit 0 ;;
esac

# Extract file path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || true)
[[ -n "$FILE_PATH" ]] || { echo '{}'; exit 0; }

# Resolve spine root from hook location
SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Strip spine root to get relative path
RELATIVE_PATH="${FILE_PATH#"$SPINE_ROOT"/}"
# If path didn't change, file is outside the repo — allow
[[ "$RELATIVE_PATH" != "$FILE_PATH" ]] || { echo '{}'; exit 0; }

# Check if file is under a governed path
GOVERNED=0
case "$RELATIVE_PATH" in
  ops/*|bin/*|surfaces/*)
    GOVERNED=1
    ;;
esac

[[ "$GOVERNED" -eq 1 ]] || { echo '{}'; exit 0; }

# ── Admission check ──

# Check 1: SPINE_ENTRY_PACKET_PATH env var (inherited from parent shell or terminal launcher)
if [[ -n "${SPINE_ENTRY_PACKET_PATH:-}" && -f "$SPINE_ENTRY_PACKET_PATH" ]]; then
  echo '{}'; exit 0
fi

# Check 2: Recent entry packet file (session.v3.attach ran during or before this session)
SPINE_STATE="${SPINE_STATE:-/Users/ronnyworks/code/.runtime/spine/state}"
ENTRY_PACKET_DIR="$SPINE_STATE/entry-packets"
if [[ -d "$ENTRY_PACKET_DIR" ]]; then
  recent_packet=$(find "$ENTRY_PACKET_DIR" -maxdepth 1 -name "*.entry.packet.yaml" -mmin -240 -print -quit 2>/dev/null || true)
  if [[ -n "$recent_packet" ]]; then
    echo '{}'; exit 0
  fi
fi

# ── Not admitted — block with remediation ──
REASON="GOVERNED MUTATION BLOCKED: session admission required.

You are attempting to edit \`${RELATIVE_PATH}\`, which is under a governed spine path (\`ops/\`, \`bin/\`, or \`surfaces/\`).

Governed mutations through the toolchain require an active session admission.

Remediation — run session.v3.attach to establish admission:

  ./bin/ops cap run session.v3.attach -- --allow-no-loop

After attach, governed mutations will be allowed for 4 hours.

If this is the next eligible controller-issued secondary-terminal mutation to
\`ops/\`, \`bin/\`, or \`surfaces/\`, it must use the admitted repo-local workflow:

  ./bin/ops cap run session.interactive.dispatch -- --governed-repo-mutation --summary '...' --governed-path ops/... --first-command '...'

Rollout status / re-measure trigger:

  ./bin/ops cap run session.interactive.status -- --governed-repo-mutation-summary

This enforcement exists because governed spine work must enter through the front door, not bypass the engine. See: ops/bindings/session.admission.contract.yaml"

jq -n --arg reason "$REASON" '{"decision": "block", "reason": $reason}'
