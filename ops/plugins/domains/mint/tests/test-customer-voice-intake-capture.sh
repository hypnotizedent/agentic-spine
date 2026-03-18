#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/../bin"
FIXTURES_DIR="$SCRIPT_DIR/fixtures/voice"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
export SPINE_STATE="$TMPDIR/state"

echo "TEST: customer-voice-intake-capture"

# Load fixture
PAYLOAD=$(cat "$FIXTURES_DIR/vapi-end-of-call-report.sample.json")
PAYLOAD_B64=$(echo "$PAYLOAD" | base64)

# Test dry-run with JSON output
echo "  - dry-run with JSON envelope"
RESULT=$("$BIN_DIR/customer-voice-intake-capture" --payload-base64 "$PAYLOAD_B64" --dry-run --json)
echo "$RESULT" | jq -e '.status == "ok"' >/dev/null || { echo "FAIL: Expected ok status"; exit 1; }
echo "$RESULT" | jq -e '.data.dry_run == true' >/dev/null || { echo "FAIL: Expected dry_run true"; exit 1; }
echo "$RESULT" | jq -e '.data.channel == "phone"' >/dev/null || { echo "FAIL: Expected phone channel"; exit 1; }
RECORD_PATH="$(echo "$RESULT" | jq -r '.data.record_path')"
EVIDENCE_PATH="$(echo "$RESULT" | jq -r '.data.evidence_path')"
[[ ! -f "$RECORD_PATH" ]] || { echo "FAIL: Dry-run should not write record"; exit 1; }
[[ ! -f "$EVIDENCE_PATH" ]] || { echo "FAIL: Dry-run should not write evidence"; exit 1; }
echo "    ✓ JSON envelope valid"

# Test actual capture
echo "  - live capture"
RESULT=$("$BIN_DIR/customer-voice-intake-capture" --payload-base64 "$PAYLOAD_B64" --json)
echo "$RESULT" | jq -e '.status == "ok"' >/dev/null || { echo "FAIL: Expected ok status"; exit 1; }
INTERACTION_ID=$(echo "$RESULT" | jq -r '.data.interaction_id')
RECORD_PATH="$(echo "$RESULT" | jq -r '.data.record_path')"
EVIDENCE_PATH="$(echo "$RESULT" | jq -r '.data.evidence_path')"
[[ -f "$RECORD_PATH" ]] || { echo "FAIL: Expected record file"; exit 1; }
[[ -f "$EVIDENCE_PATH" ]] || { echo "FAIL: Expected evidence file"; exit 1; }
echo "$RESULT" | jq -e '.data.operator_followup_required == false' >/dev/null || { echo "FAIL: Expected operator_followup_required false"; exit 1; }
echo "    ✓ Created interaction: $INTERACTION_ID"

echo "PASS: customer-voice-intake-capture"
