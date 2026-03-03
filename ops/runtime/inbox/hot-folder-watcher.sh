#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# hot-folder-watcher.sh - Real-time prompt dispatch pipeline with traceability
# ═══════════════════════════════════════════════════════════════════════════
#
# Issue: #643
# Purpose: Watch mailroom/inbox/queued for prompt files, process through lanes,
#          dispatch through configured provider lane, write traced results to outbox.
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
#   - Local provider endpoint (default): Ollama-compatible HTTP API
#   - Optional paid providers (z.ai / anthropic) via explicit override
#
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# LaunchAgents may not export HOME; derive it from SPINE_REPO/PWD for secrets/cache paths.
if [[ -z "${HOME:-}" ]]; then
    _home_probe="${SPINE_REPO:-$PWD}"
    export HOME="$(dirname "$(dirname "$_home_probe")")"
    unset _home_probe
fi

# Ensure user-local and Homebrew tools are available when run from launchd.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────
SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
source "$SPINE_REPO/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths

# SPINE paths (canonical)
SPINE="${SPINE_REPO}"
INBOX="${SPINE_INBOX}"
OUTBOX="${SPINE_OUTBOX}"
STATE_DIR="${SPINE_STATE}"
LOG_DIR="${SPINE_LOGS}"

# Lane folders (prompt lifecycle)
QUEUED="${INBOX}/queued"
RUNNING="${INBOX}/running"
DONE="${INBOX}/done"
FAILED="${INBOX}/failed"
PARKED="${INBOX}/parked"

# Repo paths
REPO="${SPINE_REPO}"
BRAIN_RULES="${REPO}/docs/brain/rules.md"

# Model/provider config
WATCHER_PROVIDER="${SPINE_WATCHER_PROVIDER:-local}"  # local | zai | anthropic
WATCHER_ALLOW_ANTHROPIC="${SPINE_WATCHER_ALLOW_ANTHROPIC:-0}"
WATCHER_ALLOW_PAID_PROVIDER="${SPINE_WATCHER_ALLOW_PAID_PROVIDER:-0}"
WATCHER_PAID_FALLBACK_PROVIDER="${SPINE_WATCHER_PAID_FALLBACK_PROVIDER:-zai}"
WATCHER_LOCAL_ENDPOINT="${SPINE_WATCHER_LOCAL_ENDPOINT:-http://127.0.0.1:11434}"
WATCHER_LOCAL_MODEL="${SPINE_WATCHER_LOCAL_MODEL:-llama3.2:3b}"
WATCHER_PAID_CIRCUIT_TTL_SECONDS="${SPINE_WATCHER_PAID_CIRCUIT_TTL_SECONDS:-21600}"
CIRCUIT_OPEN_FILE="${STATE_DIR}/watcher-paid-provider.circuit.open"

case "$WATCHER_PROVIDER" in
    local|zai|anthropic) ;;
    *)
        echo "ERROR: SPINE_WATCHER_PROVIDER must be 'local', 'zai', or 'anthropic' (got: $WATCHER_PROVIDER)"
        exit 1
        ;;
esac

if [[ "$WATCHER_PROVIDER" =~ ^(zai|anthropic)$ ]] && [[ "$WATCHER_ALLOW_PAID_PROVIDER" != "1" ]]; then
    echo "ERROR: paid watcher provider '$WATCHER_PROVIDER' requires SPINE_WATCHER_ALLOW_PAID_PROVIDER=1."
    exit 1
fi

if [[ "$WATCHER_PROVIDER" == "anthropic" && "$WATCHER_ALLOW_ANTHROPIC" != "1" ]]; then
    echo "ERROR: provider=anthropic is blocked by default. Set SPINE_WATCHER_ALLOW_ANTHROPIC=1 to override."
    exit 1
fi

case "$WATCHER_PROVIDER" in
    anthropic)
        MODEL="${CLAUDE_MODEL:-claude-sonnet-4-20250514}"
        MAX_TOKENS="${CLAUDE_MAX_TOKENS:-4096}"
        ;;
    zai)
        MODEL="${ZAI_MODEL:-glm-4.7-flash}"
        MAX_TOKENS="${ZAI_MAX_TOKENS:-4096}"
        ;;
    *)
        MODEL="${WATCHER_LOCAL_MODEL}"
        MAX_TOKENS="${SPINE_WATCHER_LOCAL_MAX_TOKENS:-4096}"
        ;;
esac

# State files
DIAG_LOG="${LOG_DIR}/hot-folder-watcher.log"
LOG_FILE="$DIAG_LOG"
LEDGER="${STATE_DIR}/ledger.csv"
LOCK_DIR="${STATE_DIR}/locks/agent-inbox.lock"
PID_FILE="${STATE_DIR}/agent-inbox.pid"

# RAG traceability (populated by retrieve_context, consumed by build_packet/process_file)
RAG_SOURCES_YAML=""
RAG_CONTEXT=""

# Packet built by build_packet (avoids subshell)
SUPERVISOR_PACKET=""

# Dispatch failure metadata (used to route failed vs parked lanes).
DISPATCH_ERROR_CLASS=""
DISPATCH_ERROR_REASON=""

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

is_paid_provider() {
    [[ "${1:-}" == "zai" || "${1:-}" == "anthropic" ]]
}

open_paid_provider_circuit() {
    local provider="$1"
    local reason="$2"
    mkdir -p "$(dirname "$CIRCUIT_OPEN_FILE")"
    {
        echo "opened_at_epoch=$(date +%s)"
        echo "opened_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "provider=$provider"
        echo "reason=$reason"
    } > "$CIRCUIT_OPEN_FILE"
    chmod 600 "$CIRCUIT_OPEN_FILE" 2>/dev/null || true
    log "PAID_PROVIDER_CIRCUIT: OPEN provider=$provider reason=$reason"
}

clear_paid_provider_circuit() {
    [[ -f "$CIRCUIT_OPEN_FILE" ]] || return 0
    rm -f "$CIRCUIT_OPEN_FILE"
    log "PAID_PROVIDER_CIRCUIT: CLOSED"
}

paid_provider_circuit_open() {
    [[ -f "$CIRCUIT_OPEN_FILE" ]] || return 1

    local opened_at_epoch=""
    opened_at_epoch="$(awk -F= '/^opened_at_epoch=/{print $2; exit}' "$CIRCUIT_OPEN_FILE" 2>/dev/null || true)"
    if [[ ! "$opened_at_epoch" =~ ^[0-9]+$ ]]; then
        return 0
    fi

    local now ttl age
    now="$(date +%s)"
    ttl="${WATCHER_PAID_CIRCUIT_TTL_SECONDS}"
    age=$((now - opened_at_epoch))
    if (( age >= ttl )); then
        clear_paid_provider_circuit
        return 1
    fi
    return 0
}

paid_provider_circuit_reason() {
    if [[ -f "$CIRCUIT_OPEN_FILE" ]]; then
        awk -F= '/^reason=/{print $2; exit}' "$CIRCUIT_OPEN_FILE" 2>/dev/null || true
    fi
}

is_paid_provider_exhaustion_error() {
    local raw="${1:-}"
    local lower
    lower="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
    [[ "$lower" == *"insufficient balance"* \
        || "$lower" == *"resource package"* \
        || "$lower" == *"too many authentication failures"* \
        || "$lower" == *"invalid access token"* ]]
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

    if [[ "$WATCHER_PROVIDER" == "local" ]]; then
        return
    fi

    if [[ "$WATCHER_PROVIDER" == "anthropic" ]]; then
        if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
            echo "ERROR: ANTHROPIC_API_KEY not set (provider=anthropic)"
            exit 1
        fi
        return
    fi

    # provider=zai (default)
    if [[ -z "${ZAI_API_KEY:-}" && -n "${Z_AI_API_KEY:-}" ]]; then
        export ZAI_API_KEY="$Z_AI_API_KEY"
    fi

    if [[ -z "${ZAI_API_KEY:-}" ]]; then
        local creds="${HOME}/.config/infisical/credentials"
        if [[ -f "$creds" ]]; then
            # shellcheck disable=SC1090
            source "$creds" >>"$DIAG_LOG" 2>&1 || true
        fi
    fi

    if [[ -z "${ZAI_API_KEY:-}" && -n "${Z_AI_API_KEY:-}" ]]; then
        export ZAI_API_KEY="$Z_AI_API_KEY"
    fi

    if [[ -z "${ZAI_API_KEY:-}" ]]; then
        local inf_agent="${SPINE}/ops/tools/infisical-agent.sh"
        if [[ -x "$inf_agent" ]]; then
            ZAI_API_KEY="$("$inf_agent" get-cached infrastructure prod Z_AI_API_KEY 2>>"$DIAG_LOG" || true)"
            if [[ -z "${ZAI_API_KEY:-}" ]]; then
                ZAI_API_KEY="$("$inf_agent" get-cached infrastructure prod ZAI_API_KEY 2>>"$DIAG_LOG" || true)"
            fi
            [[ -n "${ZAI_API_KEY:-}" ]] && export ZAI_API_KEY
        fi
    fi

    if [[ -z "${ZAI_API_KEY:-}" ]]; then
        echo "ERROR: ZAI_API_KEY not set (provider=zai). Expected ZAI_API_KEY or Z_AI_API_KEY via Infisical."
        exit 1
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
    [[ -f "${DONE}/${prompt_file}" ]] && prompt_hash="$(shasum -a 256 "${DONE}/${prompt_file}" 2>>"$DIAG_LOG" | cut -d' ' -f1)"
    [[ -f "${FAILED}/${prompt_file}" ]] && prompt_hash="$(shasum -a 256 "${FAILED}/${prompt_file}" 2>>"$DIAG_LOG" | cut -d' ' -f1)"
    [[ -f "${OUTBOX}/${result_file}" ]] && result_hash="$(shasum -a 256 "${OUTBOX}/${result_file}" 2>>"$DIAG_LOG" | cut -d' ' -f1)"

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
    if grep -qiE '(api[_-]?key|secret|password|token|bearer|auth)[[:space:]]*[=:][[:space:]]*[^$]' "$file" 2>>"$DIAG_LOG"; then
        return 0
    fi
    if grep -qE 'sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|xoxb-[0-9]+-[a-zA-Z0-9]+' "$file" 2>>"$DIAG_LOG"; then
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
    matches="$(rg -l -i "$query" "${search_dirs[@]}" --type md 2>>"$DIAG_LOG" | head -3)" || true

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
                file_content="$(head -50 "$match_file" 2>>"$DIAG_LOG")" || true
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
# Dispatch to model provider
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
        clear_paid_provider_circuit
        echo "$response" | jq -r '.content[0].text'
    else
        if is_paid_provider_exhaustion_error "$response"; then
            open_paid_provider_circuit "anthropic" "billing_exhausted_or_auth_failure"
        fi
        echo "ERROR: API call failed"
        echo "$response" | jq -r '.error.message // .' 2>>"$DIAG_LOG" || echo "$response"
        return 1
    fi
}

dispatch_to_zai() {
    local packet="$1"
    local response
    local attempt
    local max_attempts=3
    local backoff=2

    local escaped_packet
    escaped_packet="$(echo "$packet" | jq -Rs .)"

    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        response=$(curl -sS "https://api.z.ai/api/paas/v4/chat/completions" \
            -H "Authorization: Bearer ${ZAI_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"${MODEL}\",
                \"max_tokens\": ${MAX_TOKENS},
                \"temperature\": 0,
                \"messages\": [{
                    \"role\": \"user\",
                    \"content\": ${escaped_packet}
                }]
            }" 2>&1)

        if echo "$response" | jq -e '.choices[0].message' >/dev/null 2>&1; then
            clear_paid_provider_circuit
            echo "$response" | jq -r '(.choices[0].message.content // empty) as $c | if ($c|type=="string" and ($c|length)>0) then $c else (.choices[0].message.reasoning_content // "") end'
            return 0
        fi

        local err_msg
        err_msg="$(echo "$response" | jq -r '.error.message // empty' 2>>"$DIAG_LOG" || true)"
        if [[ "$attempt" -lt "$max_attempts" ]] && [[ "$err_msg" == *"Rate limit"* ]]; then
            sleep "$backoff"
            backoff=$((backoff * 2))
            continue
        fi

        if is_paid_provider_exhaustion_error "$response"; then
            open_paid_provider_circuit "zai" "billing_exhausted_or_auth_failure"
        fi
        echo "ERROR: z.ai API call failed"
        echo "$response" | jq -r '.error.message // .' 2>>"$DIAG_LOG" || echo "$response"
        return 1
    done
}

dispatch_to_local() {
    local packet="$1"
    local response
    local escaped_packet
    escaped_packet="$(echo "$packet" | jq -Rs .)"

    response="$(curl -sS "${WATCHER_LOCAL_ENDPOINT%/}/api/chat" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"${WATCHER_LOCAL_MODEL}\",
            \"stream\": false,
            \"messages\": [{
                \"role\": \"user\",
                \"content\": ${escaped_packet}
            }]
        }" 2>&1)" || {
        echo "ERROR: local watcher provider call failed (${WATCHER_LOCAL_ENDPOINT})"
        echo "$response" >>"$DIAG_LOG"
        return 1
    }

    if echo "$response" | jq -e '.message.content' >/dev/null 2>&1; then
        echo "$response" | jq -r '.message.content // ""'
        return 0
    fi

    echo "ERROR: local watcher provider response parse failed"
    echo "$response" >>"$DIAG_LOG"
    return 1
}

dispatch_to_paid_fallback() {
    local packet="$1"
    local fallback="${WATCHER_PAID_FALLBACK_PROVIDER:-zai}"
    if ! is_paid_provider "$fallback"; then
        echo "ERROR: invalid paid fallback provider: $fallback"
        return 1
    fi
    if [[ "$WATCHER_ALLOW_PAID_PROVIDER" != "1" ]]; then
        echo "ERROR: paid fallback disabled (set SPINE_WATCHER_ALLOW_PAID_PROVIDER=1)"
        return 1
    fi
    if [[ "$fallback" == "anthropic" && "$WATCHER_ALLOW_ANTHROPIC" != "1" ]]; then
        echo "ERROR: anthropic fallback blocked (set SPINE_WATCHER_ALLOW_ANTHROPIC=1)"
        return 1
    fi
    if [[ "$fallback" == "anthropic" ]]; then
        dispatch_to_claude "$packet"
    else
        dispatch_to_zai "$packet"
    fi
}

dispatch_to_model() {
    local packet="$1"
    local rc=1
    DISPATCH_ERROR_CLASS=""
    DISPATCH_ERROR_REASON=""

    if is_paid_provider "$WATCHER_PROVIDER" && paid_provider_circuit_open; then
        DISPATCH_ERROR_CLASS="paid_provider_circuit_open"
        DISPATCH_ERROR_REASON="$(paid_provider_circuit_reason)"
        echo "ERROR: paid provider circuit open (${DISPATCH_ERROR_REASON})"
        return 1
    fi

    case "$WATCHER_PROVIDER" in
        local)
            if dispatch_to_local "$packet"; then
                return 0
            fi
            if [[ "$WATCHER_ALLOW_PAID_PROVIDER" == "1" ]]; then
                if dispatch_to_paid_fallback "$packet"; then
                    return 0
                fi
                rc=$?
            fi
            ;;
        anthropic)
            if dispatch_to_claude "$packet"; then
                return 0
            fi
            rc=$?
            ;;
        *)
            if dispatch_to_zai "$packet"; then
                return 0
            fi
            rc=$?
            ;;
    esac

    if paid_provider_circuit_open; then
        DISPATCH_ERROR_CLASS="paid_provider_circuit_open"
        DISPATCH_ERROR_REASON="$(paid_provider_circuit_reason)"
    fi
    return "$rc"
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

    if response="$(dispatch_to_model "$packet_text")"; then
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
        local result_status="failed"
        local target_lane="$FAILED"
        if [[ "$DISPATCH_ERROR_CLASS" == "paid_provider_circuit_open" ]]; then
            result_status="parked"
            target_lane="$PARKED"
        fi

        # Write error result
        {
            echo "# Result: ${run_id}"
            echo ""
            echo "| Field | Value |"
            echo "|-------|-------|"
            echo "| Run ID | \`${run_id}\` |"
            echo "| Source | \`${basename}\` |"
            echo "| Status | ${result_status} |"
            echo "| Generated | $(date -u +%Y-%m-%dT%H:%M:%SZ) |"
            echo "| Model | ${MODEL} |"
            echo ""
            if [[ -n "$DISPATCH_ERROR_CLASS" ]]; then
                echo "| Dispatch Error Class | ${DISPATCH_ERROR_CLASS} |"
            fi
            if [[ -n "$DISPATCH_ERROR_REASON" ]]; then
                echo "| Dispatch Error Reason | ${DISPATCH_ERROR_REASON} |"
            fi
            echo ""
            echo "---"
            echo ""
            echo "## Error"
            echo ""
            echo "\`\`\`"
            echo "$response"
            echo "\`\`\`"
        } > "$outfile"

        # Move to failed/ or parked/
        mv "$running_file" "${target_lane}/${basename}"

        # Log completion
        local error_summary
        error_summary="$(echo "$response" | head -1 | cut -c1-100)"
        ledger_append "$run_id" "$result_status" "$basename" "$(basename "$outfile")" "$error_summary" "$context_used"

        # Write universal receipt
        write_receipt "$run_key" "$run_id" "$result_status" "$basename" "$(basename "$outfile")" "$MODEL" "$context_used" "$error_summary"

        if [[ "$result_status" == "parked" ]]; then
            log "PARKED: $basename - $error_summary"
            notify "⏸️ Dispatch parked: ${run_id}"
        else
            log "FAILED: $basename - $error_summary"
            notify "❌ Dispatch failed: ${run_id}"
        fi
    fi
}

count_lane_files() {
    local lane_dir="$1"
    find "$lane_dir" -maxdepth 1 -type f \
        ! -name '.keep' \
        ! -name '.DS_Store' \
        ! -name '.*.swp' \
        2>>"$DIAG_LOG" | wc -l | tr -d ' '
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
    echo "  Provider: $WATCHER_PROVIDER"
    if paid_provider_circuit_open; then
        echo "  Paid circuit: OPEN ($(paid_provider_circuit_reason))"
    else
        echo "  Paid circuit: closed"
    fi
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
            echo "  SPINE_WATCHER_PROVIDER  Provider: local (default), zai, or anthropic"
            echo "  SPINE_WATCHER_LOCAL_ENDPOINT  Local provider endpoint (default: http://127.0.0.1:11434)"
            echo "  SPINE_WATCHER_LOCAL_MODEL  Local provider model (default: llama3.2:3b)"
            echo "  SPINE_WATCHER_ALLOW_PAID_PROVIDER  Set 1 to allow paid providers"
            echo "  SPINE_WATCHER_PAID_FALLBACK_PROVIDER  Paid fallback when local fails (default: zai)"
            echo "  SPINE_WATCHER_PAID_CIRCUIT_TTL_SECONDS  Circuit TTL (default: 21600)"
            echo "  ZAI_API_KEY / Z_AI_API_KEY  Required when provider=zai or paid fallback=zai"
            echo "  ZAI_MODEL          Override z.ai model (default: glm-4.7-flash)"
            echo "  SPINE_INBOX        Override inbox path (default: $SPINE/mailroom/inbox)"
            echo "  SPINE_OUTBOX       Override outbox path (default: $SPINE/mailroom/outbox)"
            echo "  SPINE_STATE        Override state path (default: $SPINE/mailroom/state)"
            echo "  CLAUDE_MODEL       Override model when provider=anthropic or anthropic fallback"
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
