#!/usr/bin/env bash
# TRIAGE: Keep balanced policy active and enforce proposal-only writes whenever multiple sessions are active.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BOUNDARY="$ROOT/ops/bindings/fabric.boundary.contract.yaml"
PROFILE="$ROOT/ops/bindings/tenant.profile.yaml"
RESOLVER="$ROOT/ops/lib/resolve-policy.sh"
CAP_RUNNER="$ROOT/ops/commands/cap.sh"
SESSIONS_DIR="$ROOT/mailroom/state/sessions"

fail() {
  echo "D123 FAIL: $*" >&2
  exit 1
}

[[ -f "$BOUNDARY" ]] || fail "missing boundary contract: $BOUNDARY"
[[ -f "$PROFILE" ]] || fail "missing active tenant profile: $PROFILE"
[[ -f "$RESOLVER" ]] || fail "missing resolver: $RESOLVER"
[[ -f "$CAP_RUNNER" ]] || fail "missing cap runner: $CAP_RUNNER"
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"

yq e '.' "$BOUNDARY" >/dev/null 2>&1 || fail "invalid YAML: $BOUNDARY"
yq e '.' "$PROFILE" >/dev/null 2>&1 || fail "invalid YAML: $PROFILE"

required_preset="$(yq e -r '.balanced_policy.required_preset // "balanced"' "$BOUNDARY")"
required_multi_session_writes="$(yq e -r '.balanced_policy.required_multi_agent_writes_when_multi_session // "proposal-only"' "$BOUNDARY")"

source "$RESOLVER"
resolve_policy_knobs

[[ "$RESOLVED_POLICY_PRESET" == "$required_preset" ]] || fail "policy preset must be '$required_preset' (resolved: $RESOLVED_POLICY_PRESET)"

profile_preset="$(yq e -r '.policy.preset // ""' "$PROFILE")"
[[ "$profile_preset" == "$required_preset" ]] || fail "tenant profile policy.preset must be '$required_preset'"

profile_multi_session="$(yq e -r '.policy.overrides.multi_agent_writes_when_multi_session // ""' "$PROFILE")"
[[ "$profile_multi_session" == "$required_multi_session_writes" ]] || fail "tenant profile must set policy.overrides.multi_agent_writes_when_multi_session to '$required_multi_session_writes'"

grep -q 'multi_agent_writes_when_multi_session' "$RESOLVER" || fail "resolve-policy.sh must wire multi_agent_writes_when_multi_session"
grep -q 'RESOLVED_MULTI_AGENT_WRITES_WHEN_MULTI_SESSION' "$CAP_RUNNER" || fail "cap.sh must enforce RESOLVED_MULTI_AGENT_WRITES_WHEN_MULTI_SESSION"

active_sessions=0
if [[ -d "$SESSIONS_DIR" ]]; then
  for session_dir in "$SESSIONS_DIR"/SES-*; do
    [[ -d "$session_dir" ]] || continue
    manifest="$session_dir/session.yaml"
    [[ -f "$manifest" ]] || continue
    pid="$(sed -n 's/^pid:[[:space:]]*//p' "$manifest" | head -1)"
    [[ -n "$pid" ]] || continue
    if kill -0 "$pid" 2>/dev/null; then
      active_sessions=$((active_sessions + 1))
    fi
  done
fi

if [[ "$active_sessions" -gt 1 ]]; then
  [[ "$required_multi_session_writes" == "proposal-only" ]] || fail "multi-session write contract must remain proposal-only"
fi

echo "D123 PASS: balanced policy safety lock enforced"
