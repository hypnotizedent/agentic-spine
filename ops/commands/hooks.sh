#!/usr/bin/env bash
set -euo pipefail

# ops hooks — install/status for repo-local git hooks.
#
# Canonical model (PACKET-690 first-class closure):
#   .githooks/ is the single canonical home.
#   `git config core.hooksPath .githooks` makes git invoke it directly.
#   No shim files in .git/hooks/ — shim model retired by PACKET-690.
#
# Worktrees share core.hooksPath (set on the primary's git dir) and each
# worktree has its own .githooks/ via tracked source, so a single
# `core.hooksPath=.githooks` setting routes correctly for primary AND all
# worktrees. This script reports against the CURRENT working tree (via
# `git rev-parse --show-toplevel`), so running it from a worktree verifies
# that worktree's hooks; same status surface for both.
#
# Status policy:
#   OK   — core.hooksPath=.githooks AND .githooks/{pre-commit,commit-msg}
#          executable AND validator smoke classification works.
#   WARN — install never ran here (hooksPath unset/wrong) OR hook files
#          missing/non-executable OR validator smoke failed. Each WARN
#          prints an explicit fix instruction; WARN is NEVER normal.
#
# Usage:
#   ops hooks status
#   ops hooks install

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

cmd="${1:-}"
shift || true

usage() {
  cat <<'EOF'
ops hooks

Usage:
  ops hooks status   Show whether hooks are installed for this repo
  ops hooks install  Configure git to use .githooks/ and ensure required hooks are executable
EOF
}

hooks_path="$(git -C "$REPO_ROOT" config --get core.hooksPath 2>/dev/null || true)"
pre_hook="$REPO_ROOT/.githooks/pre-commit"
# commit-msg hook (PACKET-675): L1 engine packet-label governance enforced
# at the forge commit boundary. Calls packet.label.validate via cap.sh so
# reads route to storage_evidence_node, not consumer-host projection.
commit_msg_hook="$REPO_ROOT/.githooks/commit-msg"

# Run a tiny read-only smoke classification through the local validator
# binary. Proves the validator is callable and parses arguments — not
# just that the file exists. Called from `status`. Cheap (no SSH); use
# `ops cap run packet.label.validate` for the cap-routed canonical path.
#
# The validator prints "SPINE_STATE not set; skipping" to stderr and
# exits 0 when --spine-state is empty, so we deliberately pass an empty
# state to keep the smoke local-only and read-only.
validator_smoke() {
  local validator_bin="$REPO_ROOT/ops/plugins/core/lifecycle/bin/packet-label-validate"
  if [[ ! -x "$validator_bin" ]]; then
    echo "validator: WARN ($validator_bin missing or not executable)"
    return 1
  fi
  local out rc
  set +e
  out="$("$validator_bin" --commit-msg-text "smoke test no PACKET tokens" --spine-state "" 2>&1)"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    echo "validator: OK (smoke classification through $validator_bin returns exit 0)"
    return 0
  fi
  echo "validator: WARN (smoke classification failed: rc=$rc; output: $out)"
  return 1
}

case "$cmd" in
  status)
    overall_ok=1
    echo "repo: $REPO_ROOT"
    echo "hooksPath: ${hooks_path:-<unset>}"
    if [[ "${hooks_path:-}" == ".githooks" ]]; then
      echo "status: OK (core.hooksPath=.githooks)"
    else
      echo "status: WARN (core.hooksPath is '${hooks_path:-<unset>}'; canonical is '.githooks'). Fix: run 'ops hooks install'."
      overall_ok=0
    fi
    if [[ -x "$pre_hook" ]]; then
      echo "pre-commit: OK ($pre_hook executable)"
    else
      echo "pre-commit: WARN ($pre_hook missing or not executable). Fix: run 'ops hooks install'."
      overall_ok=0
    fi
    if [[ -x "$commit_msg_hook" ]]; then
      echo "commit-msg: OK ($commit_msg_hook executable; calls packet.label.validate)"
    else
      echo "commit-msg: WARN ($commit_msg_hook missing or not executable). Fix: run 'ops hooks install'."
      overall_ok=0
    fi
    if validator_smoke; then
      :
    else
      overall_ok=0
    fi
    echo "pre-push: not implemented (enforcement via verify, not hook)"
    if [[ $overall_ok -eq 1 ]]; then
      echo "overall: OK"
    else
      echo "overall: WARN (see fix instructions above; WARN is never normal)"
    fi
    ;;
  install)
    mkdir -p "$REPO_ROOT/.githooks"
    if [[ -f "$pre_hook" ]]; then
      chmod +x "$pre_hook" || true
    fi
    if [[ -f "$commit_msg_hook" ]]; then
      chmod +x "$commit_msg_hook" || true
    fi
    git -C "$REPO_ROOT" config core.hooksPath .githooks

    echo "Installed: core.hooksPath=.githooks"
    if [[ -x "$pre_hook" ]]; then
      echo "pre-commit: OK"
    else
      echo "pre-commit: WARN (missing or not executable): $pre_hook"
      exit 1
    fi
    if [[ -x "$commit_msg_hook" ]]; then
      echo "commit-msg: OK (PACKET-NN governance via packet.label.validate)"
    else
      echo "commit-msg: WARN (missing or not executable): $commit_msg_hook"
      # commit-msg missing is a WARN, not a hard fail at install time —
      # repo may be at an older commit before PACKET-675 landed.
    fi
    echo "pre-push: not implemented (enforcement via verify, not hook)"
    ;;
  -h|--help|"")
    usage
    exit 0
    ;;
  *)
    echo "ERROR: unknown subcommand: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
