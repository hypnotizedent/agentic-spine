#!/usr/bin/env bash
set -euo pipefail
# media-radarr-bridge-test — Verify Radarr bridge capabilities via fake MCP server stub.
#
# Tests T1-T14 covering: bridge call parsing, argument mapping, preview/apply
# semantics, --json envelopes, and missing-arg failures for all 6 radarr caps.

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

# helper: reset capture between tests
reset_capture() { : > "$CAPTURE"; }

# helper: last captured tool name
captured_tool()  { tail -1 "$CAPTURE" | jq -r '.tool'; }
# helper: captured arguments JSON
captured_args()  { tail -1 "$CAPTURE" | jq -r '.arguments'; }

echo "media-radarr-bridge Tests"
echo "════════════════════════════════════════"

# ── T1: Bridge helper parses valid JSON-RPC response ─────────────────────────
echo ""; echo "T1: bridge helper parses valid JSON-RPC response"
reset_capture
(
  source "$LIB_DIR/media-agent-bridge.sh"
  out="$(media_agent_call "test_tool" '{"key":"val"}')"
  echo "$out" | grep -q "STUB: test_tool" || exit 1
) && pass "bridge helper returns tool text" || fail "bridge helper parse"

# ── T2: Bridge helper fails on invalid JSON / launcher missing ───────────────
echo ""; echo "T2: bridge helper fails on missing launcher"
(
  MEDIA_AGENT_LAUNCHER="/nonexistent/path" \
    bash -c 'source "'"$LIB_DIR"'/media-agent-bridge.sh"; media_agent_call "x" "{}"' >/dev/null 2>&1
) && fail "should have failed on missing launcher" || pass "bridge fails on missing launcher"

# ── T3: radarr-search maps --query to search_content type=movie ──────────────
echo ""; echo "T3: radarr-search maps --query to search_content type=movie"
reset_capture
(
  out="$("$BIN_DIR/media-radarr-search" --query "Inception" 2>&1)"
  [[ "$(captured_tool)" == "search_content" ]] || exit 1
  captured_args | jq -e '.query == "Inception" and .type == "movie"' >/dev/null || exit 1
) && pass "radarr-search tool+args correct" || fail "radarr-search mapping"

# ── T4: radarr-get maps --movie-id to get_movie_details with movieId ─────────
echo ""; echo "T4: radarr-get --movie-id maps to get_movie_details movieId"
reset_capture
(
  "$BIN_DIR/media-radarr-get" --movie-id 42 >/dev/null 2>&1
  [[ "$(captured_tool)" == "get_movie_details" ]] || exit 1
  captured_args | jq -e '.movieId == 42' >/dev/null || exit 1
) && pass "radarr-get --movie-id correct" || fail "radarr-get --movie-id mapping"

# ── T5: radarr-get maps --title to get_movie_details with title ──────────────
echo ""; echo "T5: radarr-get --title maps to get_movie_details title"
reset_capture
(
  "$BIN_DIR/media-radarr-get" --title "The Matrix" >/dev/null 2>&1
  [[ "$(captured_tool)" == "get_movie_details" ]] || exit 1
  captured_args | jq -e '.title == "The Matrix"' >/dev/null || exit 1
) && pass "radarr-get --title correct" || fail "radarr-get --title mapping"

# ── T6: radarr-history maps --movie-id to get_movie_history ──────────────────
echo ""; echo "T6: radarr-history --movie-id maps to get_movie_history movieId"
reset_capture
(
  "$BIN_DIR/media-radarr-history" --movie-id 77 >/dev/null 2>&1
  [[ "$(captured_tool)" == "get_movie_history" ]] || exit 1
  captured_args | jq -e '.movieId == 77' >/dev/null || exit 1
) && pass "radarr-history --movie-id correct" || fail "radarr-history mapping"

# ── T7: radarr-request preview does NOT invoke mutation ──────────────────────
echo ""; echo "T7: radarr-request preview does NOT invoke mutation"
reset_capture
(
  "$BIN_DIR/media-radarr-request" --tmdb-id 550 >/dev/null 2>&1
  # Capture should be empty -- no MCP call made
  [[ ! -s "$CAPTURE" ]] || exit 1
) && pass "radarr-request preview skips MCP" || fail "radarr-request preview invoked MCP"

# ── T8: radarr-request --apply maps to request_movie ─────────────────────────
echo ""; echo "T8: radarr-request --apply maps to request_movie"
reset_capture
(
  "$BIN_DIR/media-radarr-request" --tmdb-id 550 --apply >/dev/null 2>&1
  [[ "$(captured_tool)" == "request_movie" ]] || exit 1
  captured_args | jq -e '.tmdbId == 550' >/dev/null || exit 1
) && pass "radarr-request --apply correct" || fail "radarr-request --apply mapping"

# ── T9: radarr-research preview does NOT invoke mutation ─────────────────────
echo ""; echo "T9: radarr-research preview does NOT invoke mutation"
reset_capture
(
  "$BIN_DIR/media-radarr-research" --movie-id 99 >/dev/null 2>&1
  [[ ! -s "$CAPTURE" ]] || exit 1
) && pass "radarr-research preview skips MCP" || fail "radarr-research preview invoked MCP"

# ── T10: radarr-research --apply maps to search_movie_by_id ──────────────────
echo ""; echo "T10: radarr-research --apply maps to search_movie_by_id"
reset_capture
(
  "$BIN_DIR/media-radarr-research" --movie-id 99 --apply >/dev/null 2>&1
  [[ "$(captured_tool)" == "search_movie_by_id" ]] || exit 1
  captured_args | jq -e '.movieId == 99' >/dev/null || exit 1
) && pass "radarr-research --apply correct" || fail "radarr-research --apply mapping"

# ── T11: radarr-remove preview does NOT invoke mutation ──────────────────────
echo ""; echo "T11: radarr-remove preview does NOT invoke mutation"
reset_capture
(
  "$BIN_DIR/media-radarr-remove" --movie-id 33 >/dev/null 2>&1
  [[ ! -s "$CAPTURE" ]] || exit 1
) && pass "radarr-remove preview skips MCP" || fail "radarr-remove preview invoked MCP"

# ── T12: radarr-remove --apply maps to remove_movie ──────────────────────────
echo ""; echo "T12: radarr-remove --apply maps to remove_movie"
reset_capture
(
  "$BIN_DIR/media-radarr-remove" --movie-id 33 --apply >/dev/null 2>&1
  [[ "$(captured_tool)" == "remove_movie" ]] || exit 1
  captured_args | jq -e '.movieId == 33' >/dev/null || exit 1
) && pass "radarr-remove --apply correct" || fail "radarr-remove --apply mapping"

# ── T13: --json output for each cap has required fields ──────────────────────
echo ""; echo "T13: --json output for each cap has required fields"
reset_capture
T13_OK=true
for spec in \
  "search:--query Tenet" \
  "get:--movie-id 1" \
  "history:--movie-id 1" \
  "request:--tmdb-id 100 --apply" \
  "research:--movie-id 1 --apply" \
  "remove:--movie-id 1 --apply"; do
  cap="${spec%%:*}"
  args="${spec#*:}"
  # shellcheck disable=SC2086
  out="$("$BIN_DIR/media-radarr-$cap" --json $args 2>&1)" || true
  if ! echo "$out" | jq -e 'has("capability") and has("tool") and has("text")' >/dev/null 2>&1; then
    echo "  $cap --json missing required fields" >&2
    T13_OK=false
  fi
done
# Also check preview --json for mutators
for spec in \
  "request:--tmdb-id 100" \
  "research:--movie-id 1" \
  "remove:--movie-id 1"; do
  cap="${spec%%:*}"
  args="${spec#*:}"
  # shellcheck disable=SC2086
  out="$("$BIN_DIR/media-radarr-$cap" --json $args 2>&1)" || true
  if ! echo "$out" | jq -e 'has("capability") and has("tool") and has("text")' >/dev/null 2>&1; then
    echo "  $cap preview --json missing required fields" >&2
    T13_OK=false
  fi
done
$T13_OK && pass "all --json outputs have capability+tool+text" || fail "--json envelope missing fields"

# ── T14: Missing required args fail clearly ──────────────────────────────────
echo ""; echo "T14: missing required args fail clearly"
T14_OK=true
# search without --query
if "$BIN_DIR/media-radarr-search" 2>/dev/null; then
  echo "  search: should fail without --query" >&2; T14_OK=false
fi
# get without --movie-id or --title
if "$BIN_DIR/media-radarr-get" 2>/dev/null; then
  echo "  get: should fail without --movie-id/--title" >&2; T14_OK=false
fi
# history without --movie-id or --title
if "$BIN_DIR/media-radarr-history" 2>/dev/null; then
  echo "  history: should fail without --movie-id/--title" >&2; T14_OK=false
fi
# request without --tmdb-id
if "$BIN_DIR/media-radarr-request" --apply 2>/dev/null; then
  echo "  request: should fail without --tmdb-id" >&2; T14_OK=false
fi
# research without --movie-id
if "$BIN_DIR/media-radarr-research" --apply 2>/dev/null; then
  echo "  research: should fail without --movie-id" >&2; T14_OK=false
fi
# remove without --movie-id
if "$BIN_DIR/media-radarr-remove" --apply 2>/dev/null; then
  echo "  remove: should fail without --movie-id" >&2; T14_OK=false
fi
$T14_OK && pass "all caps reject missing required args" || fail "missing arg handling"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $TOTAL)"
exit "$FAIL"
