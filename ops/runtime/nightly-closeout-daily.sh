#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: nightly closeout dry-run with findings notification.
# LaunchAgent: com.ronny.nightly-closeout-daily

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CLOSEOUT_CMD="${SPINE_ROOT}/ops/commands/nightly-closeout.sh"
CONTRACT="${SPINE_ROOT}/ops/bindings/nightly.closeout.contract.yaml"
RECEIPT_ROOT="${SPINE_ROOT}/receipts/nightly-closeout"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

to_int_or_neg1() {
  local value="${1:-}"
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "$value"
  else
    echo "-1"
  fi
}

extract_classification_count() {
  local file="$1"
  local key="$2"
  sed -nE "s/^- ${key}: ([0-9]+)$/\\1/p" "$file" 2>/dev/null | head -1
}

run_nightly_closeout_dry_run() {
  local output_file summary_env latest_summary classification_md
  local loops_open gaps_open orphaned_gaps branch_candidates worktree_candidates stale_candidates
  local loops_n gaps_n orphaned_n branch_n worktree_n stale_n

  [[ -x "$CLOSEOUT_CMD" ]] || {
    echo "[nightly-closeout-daily] missing closeout command: $CLOSEOUT_CMD" >&2
    return 2
  }

  output_file="$(mktemp)"
  set +e
  "$CLOSEOUT_CMD" --mode dry-run | tee "$output_file"
  local closeout_rc=${PIPESTATUS[0]}
  set -e

  if [[ "$closeout_rc" -ne 0 ]]; then
    rm -f "$output_file"
    return "$closeout_rc"
  fi

  summary_env="$(awk -F= '/^artifact.summary_env=/{print $2}' "$output_file" | tail -1)"
  if [[ -z "$summary_env" || ! -f "$summary_env" ]]; then
    latest_summary="$(find "$RECEIPT_ROOT" -type f -name summary.env 2>/dev/null | sort | tail -1 || true)"
    summary_env="$latest_summary"
  fi
  rm -f "$output_file"

  if [[ -z "$summary_env" || ! -f "$summary_env" ]]; then
    echo "[nightly-closeout-daily] WARN: summary.env not found; skipping findings notification"
    return 0
  fi

  loops_open="$(sed -nE 's/^loops_open=(.*)$/\1/p' "$summary_env" | head -1)"
  gaps_open="$(sed -nE 's/^gaps_open=(.*)$/\1/p' "$summary_env" | head -1)"
  orphaned_gaps="$(sed -nE 's/^orphaned_gaps=(.*)$/\1/p' "$summary_env" | head -1)"
  classification_md="$(sed -nE 's/^classification_md=(.*)$/\1/p' "$summary_env" | head -1)"

  branch_candidates="$(extract_classification_count "$classification_md" "prune_candidates_branches_count")"
  worktree_candidates="$(extract_classification_count "$classification_md" "prune_candidates_worktrees_count")"
  stale_candidates="$(extract_classification_count "$classification_md" "stale_path_candidates_count")"

  loops_n="$(to_int_or_neg1 "$loops_open")"
  gaps_n="$(to_int_or_neg1 "$gaps_open")"
  orphaned_n="$(to_int_or_neg1 "$orphaned_gaps")"
  branch_n="$(to_int_or_neg1 "$branch_candidates")"
  worktree_n="$(to_int_or_neg1 "$worktree_candidates")"
  stale_n="$(to_int_or_neg1 "$stale_candidates")"

  if (( loops_n > 0 || orphaned_n > 0 || branch_n > 0 || worktree_n > 0 || stale_n > 0 )); then
    spine_enqueue_email_intent \
      "nightly-closeout" \
      "warn" \
      "nightly-closeout dry-run found actionable items" \
      "loops_open=${loops_open:-unknown} gaps_open=${gaps_open:-unknown} orphaned_gaps=${orphaned_gaps:-unknown} branch_candidates=${branch_candidates:-unknown} worktree_candidates=${worktree_candidates:-unknown} stale_path_candidates=${stale_candidates:-unknown} summary_env=${summary_env}" \
      "nightly-closeout-daily"
  fi

  # ── Auto-apply decision ──
  # When auto_apply.enabled is true in contract AND the dry-run classification
  # contains only safe classes (no HOLD/AMBIGUOUS/BLOCKED items), run apply
  # automatically. Otherwise, leave for manual operator review.
  local auto_apply_enabled="false"
  if command -v yq >/dev/null 2>&1 && [[ -f "$CONTRACT" ]]; then
    auto_apply_enabled="$(yq e -r '.auto_apply.enabled // false' "$CONTRACT" 2>/dev/null || echo "false")"
  fi

  local auto_apply_safe
  auto_apply_safe="$(sed -nE 's/^auto_apply_safe=(.*)$/\1/p' "$summary_env" | head -1)"

  local total_candidates=$(( branch_n + worktree_n + stale_n ))

  if [[ "$auto_apply_enabled" == "true" ]]; then
    if [[ "$auto_apply_safe" == "true" && "$total_candidates" -gt 0 ]]; then
      echo "[nightly-closeout-daily] AUTO-APPLY: classification is safe (0 held/ambiguous), $total_candidates candidates"
      echo "[nightly-closeout-daily] AUTO-APPLY: executing apply mode"
      set +e
      "$CLOSEOUT_CMD" --mode apply
      local apply_rc=$?
      set -e
      if [[ "$apply_rc" -eq 0 ]]; then
        echo "[nightly-closeout-daily] AUTO-APPLY: apply completed successfully"
        spine_enqueue_email_intent \
          "nightly-closeout" \
          "info" \
          "nightly-closeout auto-apply completed" \
          "branch_candidates=${branch_candidates:-0} worktree_candidates=${worktree_candidates:-0} stale_path_candidates=${stale_candidates:-0} summary_env=${summary_env}" \
          "nightly-closeout-daily"
      else
        echo "[nightly-closeout-daily] AUTO-APPLY: apply failed (rc=$apply_rc), leaving for manual review"
        spine_enqueue_email_intent \
          "nightly-closeout" \
          "error" \
          "nightly-closeout auto-apply FAILED" \
          "rc=$apply_rc summary_env=${summary_env}" \
          "nightly-closeout-daily"
      fi
    elif [[ "$auto_apply_safe" != "true" ]]; then
      echo "[nightly-closeout-daily] AUTO-APPLY: SKIPPED (held/ambiguous items present, requires manual review)"
    else
      echo "[nightly-closeout-daily] AUTO-APPLY: SKIPPED (0 candidates to clean up)"
    fi
  else
    echo "[nightly-closeout-daily] AUTO-APPLY: disabled in contract (auto_apply.enabled=false)"
  fi

  return 0
}

echo "[nightly-closeout-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
spine_job_run "nightly-closeout-daily:nightly.closeout.dry-run" run_nightly_closeout_dry_run
echo "[nightly-closeout-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

