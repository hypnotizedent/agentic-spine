#!/usr/bin/env bash

set -euo pipefail

STATEFUL_GUARD_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STATEFUL_GUARD_BINDING="${STATEFUL_GUARD_BINDING:-$STATEFUL_GUARD_ROOT/ops/bindings/stateful.compose.guard.yaml}"

stateful_guard_binding_exists() {
  [[ -f "$STATEFUL_GUARD_BINDING" ]]
}

stateful_guard_stack_enabled() {
  local target="$1"
  local stack="$2"
  stateful_guard_binding_exists || return 1
  yq -e ".targets.\"$target\".stacks.\"$stack\".stateful == true" "$STATEFUL_GUARD_BINDING" >/dev/null 2>&1
}

stateful_guard_break_glass_phrase() {
  local target="$1"
  local stack="$2"
  yq -r ".targets.\"$target\".stacks.\"$stack\".break_glass_phrase // .defaults.break_glass_phrase // \"STATEFUL_BREAK_GLASS_ACK_20260308\"" \
    "$STATEFUL_GUARD_BINDING" 2>/dev/null
}

stateful_guard_reason() {
  local target="$1"
  local stack="$2"
  yq -r ".targets.\"$target\".stacks.\"$stack\".reason // \"stateful stack\"" \
    "$STATEFUL_GUARD_BINDING" 2>/dev/null
}

stateful_guard_paths_tsv() {
  local target="$1"
  local stack="$2"
  yq -r ".targets.\"$target\".stacks.\"$stack\".guard_paths[]? |
    [ .path,
      (.type // \"dir\"),
      ((.require_exists // true) | tostring),
      ((.require_nonempty // false) | tostring),
      (.description // \"\")
    ] | @tsv" "$STATEFUL_GUARD_BINDING" 2>/dev/null
}
