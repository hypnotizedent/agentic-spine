#!/usr/bin/env bash
set -euo pipefail
# media-sonarr-bridge-test — Verify Sonarr bridge capabilities via fake MCP server stub.
#
# Tests T1-T16 covering: argument mapping, type=tv enforcement, preview/apply
# semantics, --json envelopes, and missing-arg failures for all 4 sonarr caps.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/../bin"
LIB_DIR="$SCRIPT_DIR/../lib"

PASS=0; FAIL=0; TOTAL=0
pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); echo "FAIL: $1" >&2; }

command -v python3 >/dev/null 2>&1 || { echo "MISSING_DEP: python3" >&2; exit 2; }
command -v jq      >/dev/null 2>&1 || { echo "MISSING_DEP: jq" >&2; exit 2; }

# ── Fake MCP server stub ─────────────────────────────────────────────────────
WORK_DIR="$(mktemp -d)"
CAPTURE="$WORK_DIR/capture.jsonl"
FAKE_SERVER="$WORK_DIR/fake_mcp_server.py"
FAKE_LAUNCHER="$WORK_DIR/launcher.sh"
trap 'rm -rf "$WORK_DIR"' EXIT

cat > "$FAKE_SERVER" <<'PYEOF'
import sys, json, os
capture = os.environ.get("MCP_CAPTURE", "/dev/null")
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        msg = json.loads(line)
    except Exception:
        continue
    method = msg.get("method", "")
    mid = msg.get("id")
    if method == "initialize":
        resp = json.dumps({"jsonrpc":"2.0","id":mid,"result":{"protocolVersion":"2024-11-05","serverInfo":{"name":"fake-mcp","version":"0.0.1"},"capabilities":{}}})
        body = resp.encode()
        sys.stdout.write(f"Content-Length: {len(body)}\r\n\r\n{resp}")
        sys.stdout.flush()
    elif method == "tools/call":
        params = msg.get("params", {})
        tool = params.get("name", "unknown")
        args = params.get("arguments", {})
        with open(capture, "a") as f:
            f.write(json.dumps({"tool": tool, "arguments": args}) + "\n")
        text = f"STUB: {tool} called with {json.dumps(args)}"
        resp = json.dumps({"jsonrpc":"2.0","id":mid,"result":{"content":[{"type":"text","text":text}],"isError":False}})
        body = resp.encode()
        sys.stdout.write(f"Content-Length: {len(body)}\r\n\r\n{resp}")
        sys.stdout.flush()
PYEOF

cat > "$FAKE_LAUNCHER" <<SHEOF
#!/usr/bin/env bash
exec python3 "$FAKE_SERVER"
SHEOF
chmod +x "$FAKE_LAUNCHER"

export MEDIA_AGENT_LAUNCHER="$FAKE_LAUNCHER"
export MCP_CAPTURE="$CAPTURE"

reset_capture() { : > "$CAPTURE"; }
captured_tool()  { tail -1 "$CAPTURE" | jq -r '.tool'; }
captured_args()  { tail -1 "$CAPTURE" | jq -r '.arguments'; }

echo "media-sonarr-bridge Tests"
echo "════════════════════════════════════════"

# ── T1: sonarr-search maps --query to search_content type=tv ─────────────────
echo ""; echo "T1: sonarr-search maps --query to search_content type=tv"
reset_capture
(
  out="$("$BIN_DIR/media-sonarr-search" --query "Breaking Bad" 2>&1)"
  [[ "$(captured_tool)" == "search_content" ]] || exit 1
  captured_args | jq -e '.query == "Breaking Bad" and .type == "tv"' >/dev/null || exit 1
) && pass "sonarr-search tool+args correct" || fail "sonarr-search mapping"

# ── T2: sonarr-search forces type=tv (not movie) ─────────────────────────────
echo ""; echo "T2: sonarr-search forces type=tv"
reset_capture
(
  "$BIN_DIR/media-sonarr-search" --query "test" >/dev/null 2>&1
  captured_args | jq -e '.type == "tv"' >/dev/null || exit 1
) && pass "type=tv enforced" || fail "type=tv not enforced"

# ── T3: sonarr-get maps --series-id to get_show_details with seriesId ────────
echo ""; echo "T3: sonarr-get --series-id maps to get_show_details seriesId"
reset_capture
(
  "$BIN_DIR/media-sonarr-get" --series-id 42 >/dev/null 2>&1
  [[ "$(captured_tool)" == "get_show_details" ]] || exit 1
  captured_args | jq -e '.seriesId == 42' >/dev/null || exit 1
) && pass "sonarr-get --series-id correct" || fail "sonarr-get --series-id mapping"

# ── T4: sonarr-get maps --title to get_show_details with title ───────────────
echo ""; echo "T4: sonarr-get --title maps to get_show_details title"
reset_capture
(
  "$BIN_DIR/media-sonarr-get" --title "The Office" >/dev/null 2>&1
  [[ "$(captured_tool)" == "get_show_details" ]] || exit 1
  captured_args | jq -e '.title == "The Office"' >/dev/null || exit 1
) && pass "sonarr-get --title correct" || fail "sonarr-get --title mapping"

# ── T5: sonarr-history maps --series-id to get_episode_history ────────────────
echo ""; echo "T5: sonarr-history --series-id maps to get_episode_history"
reset_capture
(
  "$BIN_DIR/media-sonarr-history" --series-id 77 >/dev/null 2>&1
  [[ "$(captured_tool)" == "get_episode_history" ]] || exit 1
  captured_args | jq -e '.seriesId == 77' >/dev/null || exit 1
) && pass "sonarr-history --series-id correct" || fail "sonarr-history mapping"

# ── T6: sonarr-history passes --limit ─────────────────────────────────────────
echo ""; echo "T6: sonarr-history passes --limit"
reset_capture
(
  "$BIN_DIR/media-sonarr-history" --series-id 77 --limit 5 >/dev/null 2>&1
  captured_args | jq -e '.seriesId == 77 and .limit == 5' >/dev/null || exit 1
) && pass "sonarr-history --limit correct" || fail "sonarr-history --limit mapping"

# ── T7: sonarr-request preview does NOT invoke mutation ───────────────────────
echo ""; echo "T7: sonarr-request preview does NOT invoke mutation"
reset_capture
(
  "$BIN_DIR/media-sonarr-request" --tvdb-id 81189 >/dev/null 2>&1
  [[ ! -s "$CAPTURE" ]] || exit 1
) && pass "sonarr-request preview skips MCP" || fail "sonarr-request preview invoked MCP"

# ── T8: sonarr-request --apply maps to request_show ──────────────────────────
echo ""; echo "T8: sonarr-request --apply maps to request_show"
reset_capture
(
  "$BIN_DIR/media-sonarr-request" --tvdb-id 81189 --apply >/dev/null 2>&1
  [[ "$(captured_tool)" == "request_show" ]] || exit 1
  captured_args | jq -e '.tvdbId == 81189' >/dev/null || exit 1
) && pass "sonarr-request --apply correct" || fail "sonarr-request --apply mapping"

# ── T9: sonarr-request --apply with --quality-profile-id ─────────────────────
echo ""; echo "T9: sonarr-request --apply with --quality-profile-id"
reset_capture
(
  "$BIN_DIR/media-sonarr-request" --tvdb-id 81189 --quality-profile-id 4 --apply >/dev/null 2>&1
  captured_args | jq -e '.tvdbId == 81189 and .qualityProfileId == 4' >/dev/null || exit 1
) && pass "sonarr-request --quality-profile-id correct" || fail "sonarr-request qp mapping"

# ── T10: --json output for each cap has required fields ──────────────────────
echo ""; echo "T10: --json output has required fields"
reset_capture
T10_OK=true
for spec in \
  "sonarr-search:--query Tenet" \
  "sonarr-get:--series-id 1" \
  "sonarr-history:--series-id 1" \
  "sonarr-request:--tvdb-id 100 --apply"; do
  cap="${spec%%:*}"
  args="${spec#*:}"
  # shellcheck disable=SC2086
  out="$("$BIN_DIR/media-$cap" --json $args 2>&1)" || true
  if ! echo "$out" | jq -e 'has("capability") and has("tool") and has("text")' >/dev/null 2>&1; then
    echo "  $cap --json missing required fields" >&2
    T10_OK=false
  fi
done
# Preview --json for mutator
out="$("$BIN_DIR/media-sonarr-request" --tvdb-id 100 --json 2>&1)" || true
if ! echo "$out" | jq -e 'has("capability") and has("tool") and has("text") and .applied == false' >/dev/null 2>&1; then
  echo "  sonarr-request preview --json missing fields or applied!=false" >&2
  T10_OK=false
fi
$T10_OK && pass "all --json outputs have capability+tool+text" || fail "--json envelope missing fields"

# ── T11: sonarr-search --json includes query and type ─────────────────────────
echo ""; echo "T11: sonarr-search --json includes query and type"
reset_capture
(
  out="$("$BIN_DIR/media-sonarr-search" --query "Lost" --json 2>&1)"
  echo "$out" | jq -e '.query == "Lost" and .type == "tv"' >/dev/null || exit 1
) && pass "search --json query+type present" || fail "search --json missing query/type"

# ── T12: sonarr-history --json includes series_id ─────────────────────────────
echo ""; echo "T12: sonarr-history --json includes series_id"
reset_capture
(
  out="$("$BIN_DIR/media-sonarr-history" --series-id 55 --json 2>&1)"
  echo "$out" | jq -e '.series_id == 55' >/dev/null || exit 1
) && pass "history --json series_id present" || fail "history --json missing series_id"

# ── T13: sonarr-request preview --json has mode=preview + applied=false ──────
echo ""; echo "T13: sonarr-request preview --json has mode=preview + applied=false"
(
  out="$("$BIN_DIR/media-sonarr-request" --tvdb-id 999 --json 2>&1)"
  echo "$out" | jq -e '.mode == "preview" and .applied == false and .tvdb_id == 999' >/dev/null || exit 1
) && pass "request preview mode correct" || fail "request preview mode wrong"

# ── T14: sonarr-request apply --json has mode=apply + applied=true ───────────
echo ""; echo "T14: sonarr-request apply --json has mode=apply + applied=true"
reset_capture
(
  out="$("$BIN_DIR/media-sonarr-request" --tvdb-id 999 --apply --json 2>&1)"
  echo "$out" | jq -e '.mode == "apply" and .applied == true and .tvdb_id == 999' >/dev/null || exit 1
) && pass "request apply mode correct" || fail "request apply mode wrong"

# ── T15: Missing required args fail clearly ───────────────────────────────────
echo ""; echo "T15: missing required args fail clearly"
T15_OK=true
if "$BIN_DIR/media-sonarr-search" 2>/dev/null; then
  echo "  search: should fail without --query" >&2; T15_OK=false
fi
if "$BIN_DIR/media-sonarr-get" 2>/dev/null; then
  echo "  get: should fail without --series-id/--title" >&2; T15_OK=false
fi
if "$BIN_DIR/media-sonarr-history" 2>/dev/null; then
  echo "  history: should fail without --series-id" >&2; T15_OK=false
fi
if "$BIN_DIR/media-sonarr-request" --apply 2>/dev/null; then
  echo "  request: should fail without --tvdb-id" >&2; T15_OK=false
fi
$T15_OK && pass "all caps reject missing required args" || fail "missing arg handling"

# ── T16: Bridge failure surfaces clearly ──────────────────────────────────────
echo ""; echo "T16: bridge failure surfaces clearly"
(
  MEDIA_AGENT_LAUNCHER="/nonexistent/path" \
    "$BIN_DIR/media-sonarr-search" --query "test" >/dev/null 2>&1
) && fail "should have failed on missing launcher" || pass "bridge failure surfaced"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $TOTAL)"
exit "$FAIL"
