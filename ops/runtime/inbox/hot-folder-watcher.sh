#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# hot-folder-watcher.sh - Real-time prompt dispatch pipeline with traceability
# ═══════════════════════════════════════════════════════════════════════════
#
# Issue: #643
# Purpose: Watch mailroom/inbox/queued for prompt files, process through lanes,
#          dispatch to Claude API, write traced results to outbox.
#
# Usage:
#   ./hot-folder-watcher.sh              # Run watcher (foreground)
#   ./hot-folder-watcher.sh --setup      # Create all folders
#   ./hot-folder-watcher.sh --test       # Drop a test file and verify
#   ./hot-folder-watcher.sh --status     # Show queue counts + recent ledger
#
# Lanes:
#   queued/  → running/  → done/ | failed/ | parked/
#
# Dependencies:
#   - fswatch (brew install fswatch)
#   - jq (brew install jq)
#   - ANTHROPIC_API_KEY in environment
#
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Ensure Homebrew tools are available (needed for rg when run from launchd)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────
# SPINE paths (canonical)
SPINE="${SPINE_REPO:-$HOME/code/agentic-spine}"
INBOX="${SPINE_INBOX:-$SPINE/mailroom/inbox}"
OUTBOX="${SPINE_OUTBOX:-$SPINE/mailroom/outbox}"
STATE_DIR="${SPINE_STATE:-$SPINE/mailroom/state}"
LOG_DIR="${SPINE_LOGS:-$SPINE/mailroom/logs}"

# Lane folders (prompt lifecycle)
QUEUED="${INBOX}/queued"
RUNNING="${INBOX}/running"
DONE="${INBOX}/done"
FAILED="${INBOX}/failed"
PARKED="${INBOX}/parked"

# Repo paths
REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
BRAIN_RULES="${REPO}/docs/brain/rules.md"

# Model config
MODEL="${CLAUDE_MODEL:-claude-sonnet-4-20250514}"
MAX_TOKENS="${CLAUDE_MAX_TOKENS:-4096}"

# State files
LOG_FILE="${LOG_DIR}/hot-folder-watcher.log"
LEDGER="${STATE_DIR}/ledger.csv"
LOCK_DIR="${STATE_DIR}/locks/agent-inbox.lock"
PID_FILE="${STATE_DIR}/agent-inbox.pid"

# RAG traceability (populated by retrieve_context, consumed by build_packet/process_file)
RAG_SOURCES_YAML=""
RAG_CONTEXT=""

# Packet built by build_packet (avoids subshell)
SUPERVISOR_PACKET=""

# ─────────────────────────────────────────────────────────────────────────────
# Lock Management (prevents multiple instances)
# ─────────────────────────────────────────────────────────────────────────────
acquire_lock() {
    mkdir -p "$(dirname "$LOCK_DIR")"

    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo $$ > "$PID_FILE"
        trap release_lock EXIT INT TERM
        return 0
    else
        if [[ -f "$PID_FILE" ]]; then
            local old_pid
            old_pid="$(cat "$PID_FILE" 2>/dev/null || echo "")"
            if [[ -n "$old_pid" ]] && ! kill -0 "$old_pid" 2>/dev/null; then
                echo "Removing stale lock (PID $old_pid no longer running)"
                rm -rf "$LOCK_DIR"
                if mkdir "$LOCK_DIR" 2>/dev/null; then
                    echo $$ > "$PID_FILE"
                    trap release_lock EXIT INT TERM
                    return 0
                fi
            fi
        fi
        echo "ERROR: Another instance is running (lock: $LOCK_DIR)"
        return 1
    fi
}

release_lock() {
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    rm -f "$PID_FILE" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$ts] $*" | tee -a "$LOG_FILE"
}

notify() {
    osascript -e "display notification \"$1\" with title \"Agent Pipeline\"" 2>/dev/null || true
}

check_dependencies() {
    local missing=()
    command -v fswatch >/dev/null || missing+=("fswatch")
    command -v jq >/dev/null || missing+=("jq")
    command -v curl >/dev/null || missing+=("curl")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing dependencies: ${missing[*]}"
        echo "Install with: brew install ${missing[*]}"
        exit 1
    fi

    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        if command -v security >/dev/null 2>&1; then
            ANTHROPIC_API_KEY="$(security find-generic-password -a "$USER" -s "anthropic-api-key" -w 2>/dev/null)" || true
            export ANTHROPIC_API_KEY
        fi
        if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
            echo "ERROR: ANTHROPIC_API_KEY not set"
            exit 1
        fi
    fi
}

setup_folders() {
    mkdir -p "$QUEUED" "$RUNNING" "$DONE" "$FAILED" "$PARKED"
    mkdir -p "$OUTBOX" "$LOG_DIR" "$STATE_DIR" "${STATE_DIR}/locks"

    # Initialize ledger if not exists
    if [[ ! -f "$LEDGER" ]]; then
        echo "run_id,created_at,started_at,finished_at,status,prompt_file,result_file,error,context_used" > "$LEDGER"
    fi

    log "Setup complete"
    echo "✅ Folders created:"
    echo "   Queued:   $QUEUED"
    echo "   Running:  $RUNNING"
    echo "   Done:     $DONE"
    echo "   Failed:   $FAILED"
    echo "   Parked:   $PARKED"
    echo "   Outbox:   $OUTBOX"
    echo "   Logs:     $LOG_DIR"
    echo "   State:    $STATE_DIR"
    echo "   Ledger:   $LEDGER"
}

# ─────────────────────────────────────────────────────────────────────────────
# Run Key Identity
# ─────────────────────────────────────────────────────────────────────────────
derive_run_key() {
    local basename="$1"
    echo "${basename%.*}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Ledger Management (append-only)
# ─────────────────────────────────────────────────────────────────────────────
ledger_append() {
    local run_id="$1"
    local status="$2"
    local prompt_file="$3"
    local result_file="${4:-}"
    local error="${5:-}"
    local context_used="${6:-none}"

    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    local started_at=""
    local finished_at=""

    case "$status" in
        running)
            started_at="$now"
            ;;
        done|failed|parked)
            finished_at="$now"
            ;;
    esac

    # Escape commas in error messages
    error="${error//,/;}"

    echo "${run_id},${now},${started_at},${finished_at},${status},${prompt_file},${result_file},${error},${context_used}" >> "$LEDGER"
}

# ─────────────────────────────────────────────────────────────────────────────
# Receipt Writer (universal proof format)
# ─────────────────────────────────────────────────────────────────────────────
write_receipt() {
    local run_key="$1"
    local run_id="$2"
    local status="$3"
    local prompt_file="$4"
    local result_file="$5"
    local model="$6"
    local context_used="$7"
    local error="${8:-}"

    local receipt_dir="${SPINE}/receipts/sessions/R${run_key}"
    mkdir -p "$receipt_dir"

    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Compute hashes if files exist
    local prompt_hash=""
    local result_hash=""
    [[ -f "${DONE}/${prompt_file}" ]] && prompt_hash="$(shasum -a 256 "${DONE}/${prompt_file}" 2>/dev/null | cut -d' ' -f1)"
    [[ -f "${FAILED}/${prompt_file}" ]] && prompt_hash="$(shasum -a 256 "${FAILED}/${prompt_file}" 2>/dev/null | cut -d' ' -f1)"
    [[ -f "${OUTBOX}/${result_file}" ]] && result_hash="$(shasum -a 256 "${OUTBOX}/${result_file}" 2>/dev/null | cut -d' ' -f1)"

    cat > "${receipt_dir}/receipt.md" <<EOF
# Receipt: ${run_key}

| Field | Value |
|-------|-------|
| Run ID | \`${run_id}\` |
| Run Key | \`${run_key}\` |
| Status | ${status} |
| Generated | ${now} |
| Model | ${model} |
| Context | ${context_used} |

## Inputs

| File | Hash |
|------|------|
| ${prompt_file} | \`${prompt_hash:-n/a}\` |

## Outputs

| File | Hash |
|------|------|
| ${result_file} | \`${result_hash:-n/a}\` |

## Ledger

Entry appended to: \`mailroom/state/ledger.csv\`

## Error

${error:-None}

---

_Receipt written by hot-folder-watcher.sh_
EOF

    log "RECEIPT: ${receipt_dir}/receipt.md"
}

# ─────────────────────────────────────────────────────────────────────────────
# Secret Detection
# ─────────────────────────────────────────────────────────────────────────────
contains_secrets() {
    local file="$1"
    if grep -qiE '(api[_-]?key|secret|password|token|bearer|auth)[[:space:]]*[=:][[:space:]]*[^$]' "$file" 2>/dev/null; then
        return 0
    fi
    if grep -qE 'sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|xoxb-[0-9]+-[a-zA-Z0-9]+' "$file" 2>/dev/null; then
        return 0
    fi
    return 1
}

quarantine_file() {
    local file="$1"
    local run_id="$2"
    local basename
    basename="$(basename "$file")"
    mv "$file" "${PARKED}/${basename}"

    ledger_append "$run_id" "parked" "$basename" "" "parked:secrets_detected" "none"
    log "PARKED: $basename (potential secrets detected)"
    notify "⚠️ File parked: $basename"
}

# ─────────────────────────────────────────────────────────────────────────────
# RAG-lite: Explicit, Traceable Retrieval
# ─────────────────────────────────────────────────────────────────────────────
retrieve_context() {
    local prompt_file="$1"
    local files_used=""

    # Reset globals
    RAG_SOURCES_YAML=""
    RAG_CONTEXT=""

    # Only retrieve if RAG:ON is present
    if ! grep -q "RAG:ON" "$prompt_file" 2>/dev/null; then
        return
    fi

    # Extract QUERY: line if present, otherwise skip retrieval
    # Note: Uses sed instead of grep -P for macOS compatibility
    local query
    query="$(sed -n 's/^QUERY:[[:space:]]*//p' "$prompt_file" 2>/dev/null | head -1)"

    if [[ -z "$query" ]]; then
        log "RAG:ON found but no QUERY: line - skipping retrieval"
        return
    fi

    log "RAG retrieval: query='$query'"

    # Search in docs (bounded, deterministic)
    local search_dirs=("$REPO/docs")
    [[ -d "$REPO/modules" ]] && search_dirs+=("$REPO/modules")

    local matches
    matches="$(rg -l -i "$query" "${search_dirs[@]}" --type md 2>/dev/null | head -3)" || true

    if [[ -n "$matches" ]]; then
        log "RAG matched $(echo "$matches" | wc -l | tr -d ' ') files"
        # Build sources YAML block for outbox traceability
        local query_escaped="${query//\"/\\\"}"
        RAG_SOURCES_YAML="## Retrieved Sources (RAG-lite)\n\n"
        RAG_SOURCES_YAML+="\`\`\`yaml\n"
        RAG_SOURCES_YAML+="query: \"${query_escaped}\"\n"
        RAG_SOURCES_YAML+="scope: [docs, modules]\n"
        RAG_SOURCES_YAML+="limits: \"3 files / 50 lines each\"\n"
        RAG_SOURCES_YAML+="files:\n"

        while IFS= read -r match_file; do
            local rel_path="${match_file#$REPO/}"
            RAG_SOURCES_YAML+="  - path: ${rel_path}\n"
            RAG_SOURCES_YAML+="    lines: 1-50\n"
        done <<< "$matches"
        RAG_SOURCES_YAML+="\`\`\`\n"

        # Build context for prompt injection (stored in global RAG_CONTEXT)
        files_used="$(echo "$matches" | tr '\n' ';' | sed 's/;$//')"

        RAG_CONTEXT="## Retrieved Context (RAG-lite)\n"
        RAG_CONTEXT+="Query: $query\n"
        RAG_CONTEXT+="Files: $files_used\n"
        RAG_CONTEXT+="\`\`\`\n"

        local line_count=0
        while IFS= read -r match_file; do
            if [[ $line_count -lt 200 ]]; then
                RAG_CONTEXT+="--- ${match_file} ---\n"
                local file_content
                file_content="$(head -50 "$match_file" 2>/dev/null)" || true
                RAG_CONTEXT+="$file_content\n"
                line_count=$((line_count + 50))
            fi
        done <<< "$matches"

        RAG_CONTEXT+="\`\`\`\n\n"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Build Supervisor Packet
# ─────────────────────────────────────────────────────────────────────────────
build_packet() {
    local prompt_file="$1"
    local run_id="$2"

    # Reset global packet
    SUPERVISOR_PACKET=""

    # Header
    SUPERVISOR_PACKET+="# SUPERVISOR PACKET\n"
    SUPERVISOR_PACKET+="Run ID: ${run_id}\n"
    SUPERVISOR_PACKET+="Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)\n"
    SUPERVISOR_PACKET+="Source: $(basename "$prompt_file")\n\n"

    # Governance reference
    SUPERVISOR_PACKET+="## Governance Reference\n"
    SUPERVISOR_PACKET+="Follow the Supervisor Checklist at: docs/governance/SUPERVISOR_CHECKLIST.md\n"
    SUPERVISOR_PACKET+="Agent contract: docs/governance/AGENTS_GOVERNANCE.md\n"
    SUPERVISOR_PACKET+="Key rules: No Issue = No Work, Verify → Plan → Implement, Receipts required.\n\n"

    # Brain rules if available
    if [[ -f "$BRAIN_RULES" ]]; then
        SUPERVISOR_PACKET+="## Operating Rules\n"
        SUPERVISOR_PACKET+="\`\`\`\n"
        SUPERVISOR_PACKET+="$(cat "$BRAIN_RULES")\n"
        SUPERVISOR_PACKET+="\`\`\`\n\n"
    fi

    # RAG context (if requested) - retrieve_context sets globals RAG_CONTEXT and RAG_SOURCES_YAML
    retrieve_context "$prompt_file"
    if [[ -n "$RAG_CONTEXT" ]]; then
        SUPERVISOR_PACKET+="$RAG_CONTEXT"
    fi

    # User prompt
    SUPERVISOR_PACKET+="## Prompt\n\n"
    SUPERVISOR_PACKET+="$(cat "$prompt_file")\n"
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatch to Claude API
# ─────────────────────────────────────────────────────────────────────────────
dispatch_to_claude() {
    local packet="$1"
    local response

    local escaped_packet
    escaped_packet="$(echo "$packet" | jq -Rs .)"

    response=$(curl -s "https://api.anthropic.com/v1/messages" \
        -H "x-api-key: ${ANTHROPIC_API_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "{
            \"model\": \"${MODEL}\",
            \"max_tokens\": ${MAX_TOKENS},
            \"messages\": [{
                \"role\": \"user\",
                \"content\": ${escaped_packet}
            }]
        }" 2>&1)

    if echo "$response" | jq -e '.content[0].text' >/dev/null 2>&1; then
        echo "$response" | jq -r '.content[0].text'
    else
        echo "ERROR: API call failed"
        echo "$response" | jq -r '.error.message // .' 2>/dev/null || echo "$response"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Process a single file (with lane transitions)
# ─────────────────────────────────────────────────────────────────────────────
process_file() {
    local file="$1"
    local basename
    basename="$(basename "$file")"
    local run_key
    run_key="$(derive_run_key "$basename")"

    # Reset RAG sources (prevents leak from previous run if early return)
    RAG_SOURCES_YAML=""

    # Runtime identity: run_id == run_key for ledger/receipt/outbox consistency.
    local run_id
    run_id="$run_key"

    log "Processing: $basename (run_id: $run_id)"

    # Skip if not a prompt file
    if [[ ! "$file" =~ \.(md|txt)$ ]]; then
        log "Skipped (not .md/.txt): $basename"
        return
    fi

    # Skip partial writes
    sleep 0.5
    if ! [[ -f "$file" ]]; then
        log "Skipped (file disappeared): $basename"
        return
    fi

    # Move to running/
    mv "$file" "${RUNNING}/${basename}"
    local running_file="${RUNNING}/${basename}"

    # Log start in ledger
    ledger_append "$run_id" "running" "$basename"

    # Secret detection
    if contains_secrets "$running_file"; then
        quarantine_file "$running_file" "$run_id"
        return
    fi

    # Determine context_used
    local context_used="none"
    if grep -q "RAG:ON" "$running_file" 2>/dev/null; then
        if grep -q "^QUERY:" "$running_file" 2>/dev/null; then
            context_used="rag-lite"
        fi
    fi

    # Build packet (sets SUPERVISOR_PACKET and RAG_SOURCES_YAML globals)
    build_packet "$running_file" "$run_id"

    # Dispatch
    local response
    local outfile="${OUTBOX}/${run_key}__RESULT.md"
    local packet_text
    packet_text="$(printf '%b' "$SUPERVISOR_PACKET")"

    if response="$(dispatch_to_claude "$packet_text")"; then
        # Write success result
        {
            echo "# Result: ${run_id}"
            echo ""
            echo "| Field | Value |"
            echo "|-------|-------|"
            echo "| Run ID | \`${run_id}\` |"
            echo "| Source | \`${basename}\` |"
            echo "| Status | done |"
            echo "| Generated | $(date -u +%Y-%m-%dT%H:%M:%SZ) |"
            echo "| Model | ${MODEL} |"
            echo "| Context | ${context_used} |"
            echo ""
            # Inject RAG sources if retrieval was used
            if [[ -n "$RAG_SOURCES_YAML" ]]; then
                printf '%b\n' "$RAG_SOURCES_YAML"
                echo ""
            fi
            echo "---"
            echo ""
            echo "$response"
        } > "$outfile"

        # Move to done/
        mv "$running_file" "${DONE}/${basename}"

        # Log completion
        ledger_append "$run_id" "done" "$basename" "$(basename "$outfile")" "" "$context_used"

        # Write universal receipt
        write_receipt "$run_key" "$run_id" "done" "$basename" "$(basename "$outfile")" "$MODEL" "$context_used"

        log "SUCCESS: $basename → $(basename "$outfile")"
        notify "✅ Response ready: ${run_id}"
    else
        # Write error result
        {
            echo "# Result: ${run_id}"
            echo ""
            echo "| Field | Value |"
            echo "|-------|-------|"
            echo "| Run ID | \`${run_id}\` |"
            echo "| Source | \`${basename}\` |"
            echo "| Status | failed |"
            echo "| Generated | $(date -u +%Y-%m-%dT%H:%M:%SZ) |"
            echo "| Model | ${MODEL} |"
            echo ""
            echo "---"
            echo ""
            echo "## Error"
            echo ""
            echo "\`\`\`"
            echo "$response"
            echo "\`\`\`"
        } > "$outfile"

        # Move to failed/
        mv "$running_file" "${FAILED}/${basename}"

        # Log failure
        local error_summary
        error_summary="$(echo "$response" | head -1 | cut -c1-100)"
        ledger_append "$run_id" "failed" "$basename" "$(basename "$outfile")" "$error_summary" "$context_used"

        # Write universal receipt
        write_receipt "$run_key" "$run_id" "failed" "$basename" "$(basename "$outfile")" "$MODEL" "$context_used" "$error_summary"

        log "FAILED: $basename - $error_summary"
        notify "❌ Dispatch failed: ${run_id}"
    fi
}

count_lane_files() {
    local lane_dir="$1"
    find "$lane_dir" -maxdepth 1 -type f \
        ! -name '.keep' \
        ! -name '.DS_Store' \
        ! -name '.*.swp' \
        2>/dev/null | wc -l | tr -d ' '
}

drain_existing_queue() {
    local drained=0
    local queued_file=""

    while IFS= read -r queued_file; do
        [[ -n "$queued_file" ]] || continue
        process_file "$queued_file"
        drained=$((drained + 1))
    done < <(find "$QUEUED" -maxdepth 1 -type f \
        ! -name '.*' \
        \( -name '*.md' -o -name '*.txt' \) \
        | sort)

    log "Startup drain complete: ${drained} file(s) processed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Watch loop (only watches queued/)
# ─────────────────────────────────────────────────────────────────────────────
watch_inbox() {
    if ! acquire_lock; then
        exit 1
    fi

    log "Starting watcher on: $QUEUED"
    log "Lock acquired: $LOCK_DIR (PID: $$)"
    echo "🔄 Watching: $QUEUED"
    echo "   Press Ctrl+C to stop"
    echo "   Lock: $LOCK_DIR"
    echo "   Ledger: $LEDGER"

    drain_existing_queue

    fswatch -0 --event Created --event Updated "$QUEUED" | while IFS= read -r -d '' file; do
        # Skip directories and hidden files
        [[ -f "$file" ]] || continue
        [[ "$(basename "$file")" != .* ]] || continue

        process_file "$file"
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Status command (dashboard)
# ─────────────────────────────────────────────────────────────────────────────
show_status() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  AGENT PIPELINE STATUS"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Counts
    local queued_count running_count done_count failed_count parked_count
    queued_count="$(count_lane_files "$QUEUED")"
    running_count="$(count_lane_files "$RUNNING")"
    done_count="$(count_lane_files "$DONE")"
    failed_count="$(count_lane_files "$FAILED")"
    parked_count="$(count_lane_files "$PARKED")"

    echo "  Queued:   $queued_count"
    echo "  Running:  $running_count"
    echo "  Done:     $done_count"
    echo "  Failed:   $failed_count"
    echo "  Parked:   $parked_count"
    echo ""

    # Watcher status
    echo "───────────────────────────────────────────────────────────"
    echo "  WATCHER"
    echo "───────────────────────────────────────────────────────────"
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null)"
        if kill -0 "$pid" 2>/dev/null; then
            echo "  Status:   Running (PID: $pid)"
        else
            echo "  Status:   Stale lock (PID $pid not running)"
        fi
    else
        echo "  Status:   Not running"
    fi
    echo ""

    # Recent ledger
    echo "───────────────────────────────────────────────────────────"
    echo "  RECENT RUNS (last 5)"
    echo "───────────────────────────────────────────────────────────"
    if [[ -f "$LEDGER" ]]; then
        tail -5 "$LEDGER" | while IFS=, read -r run_id created_at started_at finished_at status prompt_file result_file error context_used; do
            [[ "$run_id" == "run_id" ]] && continue
            printf "  %-20s %-8s %s\n" "$run_id" "$status" "$prompt_file"
        done
    else
        echo "  (no ledger yet)"
    fi
    echo ""

    # Latest outbox
    echo "───────────────────────────────────────────────────────────"
    echo "  LATEST RESULT"
    echo "───────────────────────────────────────────────────────────"
    local latest
    latest="$(ls -t "$OUTBOX"/*_RESULT.md 2>/dev/null | head -1)"
    if [[ -n "$latest" ]]; then
        echo "  File: $(basename "$latest")"
        echo "  Time: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$latest" 2>/dev/null || stat -c '%y' "$latest" 2>/dev/null | cut -d. -f1)"
    else
        echo "  (no results yet)"
    fi
    echo ""
    echo "═══════════════════════════════════════════════════════════"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test mode
# ─────────────────────────────────────────────────────────────────────────────
run_test() {
    echo "🧪 Running E2E test..."

    setup_folders

    # Create test file in queued/
    local test_file="${QUEUED}/test-$(date +%s).md"
    echo "What is 2+2? Reply with just the number." > "$test_file"
    echo "   Created: $test_file"

    # Process it
    process_file "$test_file"

    # Check results
    local latest_response
    latest_response=$(ls -t "${OUTBOX}"/*_RESULT.md 2>/dev/null | head -1)

    if [[ -n "$latest_response" ]]; then
        echo ""
        echo "   Response: $latest_response"
        echo ""
        echo "─── Result Header ───"
        head -15 "$latest_response"
        echo "─────────────────────"
        echo ""

        # Check file moved to done/
        if ls "${DONE}"/*.md >/dev/null 2>&1; then
            echo "   ✅ Prompt moved to done/"
        else
            echo "   ⚠️  Prompt not in done/ (check failed/)"
        fi

        # Show ledger
        echo ""
        echo "─── Ledger (last 3) ───"
        tail -3 "$LEDGER"
        echo "───────────────────────"
        echo ""
        echo "✅ Test PASSED"
    else
        echo "❌ Test FAILED: No response file created"
        exit 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
main() {
    case "${1:-}" in
        --setup)
            setup_folders
            ;;
        --test)
            check_dependencies
            run_test
            ;;
        --status)
            show_status
            ;;
        --help|-h)
            echo "Usage: $0 [--setup|--test|--status|--help]"
            echo ""
            echo "  (no args)  Start the watcher daemon"
            echo "  --setup    Create all lane folders"
            echo "  --test     Run E2E test"
            echo "  --status   Show queue counts + recent ledger"
            echo ""
            echo "Lanes: queued/ → running/ → done/ | failed/ | parked/"
            echo ""
            echo "Environment:"
            echo "  ANTHROPIC_API_KEY  Required for API calls"
            echo "  SPINE_INBOX        Override inbox path (default: $SPINE/mailroom/inbox)"
            echo "  SPINE_OUTBOX       Override outbox path (default: $SPINE/mailroom/outbox)"
            echo "  SPINE_STATE        Override state path (default: $SPINE/mailroom/state)"
            echo "  CLAUDE_MODEL       Override model (default: claude-sonnet-4-20250514)"
            echo ""
            echo "RAG-lite:"
            echo "  Add 'RAG:ON' to prompt to enable retrieval"
            echo "  Add 'QUERY: <search terms>' to specify what to search for"
            ;;
        "")
            check_dependencies
            setup_folders
            watch_inbox
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run with --help for usage"
            exit 1
            ;;
    esac
}

main "$@"
