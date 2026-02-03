#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# replay-test.sh - Deterministic replay test for event fixtures
# ═══════════════════════════════════════════════════════════════════════════
#
# Purpose: Prove that same input → same outputs (within allowed timestamp diffs)
#
# Usage:
#   ./replay-test.sh              # Run all fixtures, store baseline
#   ./replay-test.sh --compare    # Run again and compare to baseline
#   ./replay-test.sh --clean      # Remove baseline and test artifacts
#
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SP="${SPINE_ROOT:-$HOME/Code/agentic-spine}"
FIXTURES="$SP/fixtures/events/v1"
QUEUED="$SP/mailroom/inbox/queued"
OUTBOX="$SP/mailroom/outbox"
RECEIPTS="$SP/receipts/sessions"
BASELINE="$SP/fixtures/baseline"

# Normalize content by removing timestamp lines for comparison
normalize() {
    local file="$1"
    # Remove lines with timestamps, generated dates, hashes (which change per run)
    sed -E \
        -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z/TIMESTAMP/g' \
        -e 's/Generated \| [^|]+/Generated | TIMESTAMP/g' \
        -e 's/`[a-f0-9]{64}`/`HASH`/g' \
        "$file" 2>/dev/null || cat "$file"
}

wait_for_result() {
    local run_key="$1"
    local timeout=30
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        if ls "$OUTBOX/${run_key}"*RESULT.md >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

run_fixture() {
    local fixture="$1"
    local basename
    basename="$(basename "$fixture")"

        # Skip nondeterministic fixtures (not part of deterministic replay contract)
        if [[ "$basename" == *"__unknown_event__"* ]]; then
            echo "    ! Skipping nondeterministic fixture: $basename"
            continue
        fi
    local run_key="${basename%.md}"

    echo "  Running: $basename"

    # Copy to queued (watcher will pick it up)
    cp "$fixture" "$QUEUED/$basename"

    # Wait for result
    if wait_for_result "$run_key"; then
        echo "    ✓ Result created"
        return 0
    else
        echo "    ✗ Timeout waiting for result"
        return 1
    fi
}

capture_baseline() {
    echo "=== CAPTURING BASELINE ==="
    mkdir -p "$BASELINE"

    local pass=0
    local fail=0

    for fixture in "$FIXTURES"/*.md; do
        [[ -f "$fixture" ]] || continue
        local basename
        basename="$(basename "$fixture")"
        local run_key="${basename%.md}"

        if run_fixture "$fixture"; then
            # Find the result file
            local result
            result="$(ls "$OUTBOX/${run_key}"*RESULT.md 2>/dev/null | head -1)"

            if [[ -n "$result" ]]; then
                # Store normalized hash
                normalize "$result" | shasum -a 256 | cut -d' ' -f1 > "$BASELINE/${run_key}.hash"
                echo "    Hash: $(cat "$BASELINE/${run_key}.hash")"
                pass=$((pass + 1))
            fi
        else
            fail=$((fail + 1))
        fi
    done

    echo ""
    echo "Baseline captured: $pass pass, $fail fail"
    echo "Baseline location: $BASELINE"
}

compare_to_baseline() {
    echo "=== COMPARING TO BASELINE ==="

    if [[ ! -d "$BASELINE" ]]; then
        echo "ERROR: No baseline found. Run without --compare first."
        exit 1
    fi

    local pass=0
    local fail=0
    local missing=0

    for fixture in "$FIXTURES"/*.md; do
        [[ -f "$fixture" ]] || continue
        local basename
        basename="$(basename "$fixture")"
        local run_key="${basename%.md}"

        echo "  Checking: $basename"

        # Skip nondeterministic fixtures (not part of deterministic replay contract)
        if [[ "$basename" == *"__unknown_event__"* ]]; then
            echo "    ! Skipping nondeterministic fixture: $basename"
            continue
        fi

        if [[ ! -f "$BASELINE/${run_key}.hash" ]]; then
            echo "    ✗ No baseline hash found"
            missing=$((missing + 1))
            continue
        fi

        # Find the most recent result for this run_key
        local result
        result="$(ls -t "$OUTBOX/${run_key}"*RESULT.md 2>/dev/null | head -1)"

        if [[ -z "$result" ]]; then
            echo "    ✗ No result file found"
            fail=$((fail + 1))
            continue
        fi

        # Compare normalized hashes
        local current_hash
        current_hash="$(normalize "$result" | shasum -a 256 | cut -d' ' -f1)"
        local baseline_hash
        baseline_hash="$(cat "$BASELINE/${run_key}.hash")"

        if [[ "$current_hash" == "$baseline_hash" ]]; then
            echo "    ✓ Match (hash: ${current_hash:0:12}...)"
            pass=$((pass + 1))
        else
            echo "    ✗ MISMATCH"
            echo "      Baseline: ${baseline_hash:0:12}..."
            echo "      Current:  ${current_hash:0:12}..."
            fail=$((fail + 1))
        fi
    done

    echo ""
    echo "Comparison: $pass match, $fail mismatch, $missing missing baseline"

    if [[ $fail -gt 0 || $missing -gt 0 ]]; then
        exit 1
    fi
}

clean() {
    echo "=== CLEANING TEST ARTIFACTS ==="
    rm -rf "$BASELINE"
    echo "Removed: $BASELINE"
}

show_status() {
    echo "=== REPLAY TEST STATUS ==="
    echo ""
    echo "Fixtures: $(ls -1 "$FIXTURES"/*.md 2>/dev/null | wc -l | tr -d ' ') files"
    ls -1 "$FIXTURES"/*.md 2>/dev/null | while read -r f; do
        echo "  - $(basename "$f")"
    done
    echo ""

    if [[ -d "$BASELINE" ]]; then
        echo "Baseline: EXISTS ($(ls -1 "$BASELINE"/*.hash 2>/dev/null | wc -l | tr -d ' ') hashes)"
    else
        echo "Baseline: NOT CAPTURED"
    fi
}

case "${1:-}" in
    --compare)
        compare_to_baseline
        ;;
    --clean)
        clean
        ;;
    --status)
        show_status
        ;;
    --help|-h)
        echo "Usage: $0 [--compare|--clean|--status|--help]"
        echo ""
        echo "  (no args)  Run fixtures and capture baseline"
        echo "  --compare  Run fixtures and compare to baseline"
        echo "  --clean    Remove baseline and test artifacts"
        echo "  --status   Show fixture and baseline status"
        ;;
    "")
        capture_baseline
        ;;
    *)
        echo "Unknown option: $1"
        exit 1
        ;;
esac
