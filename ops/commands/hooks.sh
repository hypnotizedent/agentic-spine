#!/usr/bin/env bash
set -euo pipefail

# ops hooks - install/status for repo-local git hooks
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
# commit-msg hook (PACKET-650 / PACKET-675): L1 engine packet-label
# governance enforced at the forge commit boundary. Calls the canonical
# packet.label.validate cap (cap.sh-routed) so the reads come from
# storage_evidence_node, not consumer-host projection.
commit_msg_hook="$REPO_ROOT/.githooks/commit-msg"

case "$cmd" in
  status)
    echo "hooksPath: ${hooks_path:-<unset>}"
    if [[ "${hooks_path:-}" == ".githooks" ]]; then
      echo "status: OK (core.hooksPath=.githooks)"
    else
      echo "status: WARN (core.hooksPath is not .githooks)"
    fi
    if [[ -x "$pre_hook" ]]; then
      echo "pre-commit: OK ($pre_hook executable)"
    else
      echo "pre-commit: WARN ($pre_hook missing or not executable)"
    fi
    if [[ -x "$commit_msg_hook" ]]; then
      echo "commit-msg: OK ($commit_msg_hook executable; calls packet.label.validate)"
    else
      echo "commit-msg: WARN ($commit_msg_hook missing or not executable)"
    fi
    echo "pre-push: not implemented (enforcement via verify, not hook)"
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

    # Install shim files into the primary .git/hooks/ so git invokes the
    # canonical .githooks/* across primary AND all worktrees (which share
    # core.hooksPath via the primary's git dir). PACKET-675 added commit-msg;
    # pre-commit shim is included for completeness in case a fresh checkout
    # hasn't had it installed yet.
    git_hooks_dir="$(git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null)/hooks"
    if [[ -n "$git_hooks_dir" && -d "$(dirname "$git_hooks_dir")" ]]; then
      mkdir -p "$git_hooks_dir"
      for shim_kind in pre-commit commit-msg; do
        shim_path="$git_hooks_dir/$shim_kind"
        # Only write if the file is missing or not yet pointing at the
        # canonical .githooks shim form (don't clobber operator edits).
        if [[ ! -f "$shim_path" ]] || ! grep -q "/.githooks/$shim_kind" "$shim_path" 2>/dev/null; then
          cat > "$shim_path" <<SHIMEOF
#!/usr/bin/env bash
set -euo pipefail

# Local non-authoritative shim (installed by 'ops hooks install').
# Policy lives in the tracked repo hook at .githooks/$shim_kind.

ROOT="\$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOK="\$ROOT/.githooks/$shim_kind"

if [[ ! -x "\$HOOK" ]]; then
  exit 0
fi

exec "\$HOOK" "\$@"
SHIMEOF
          chmod +x "$shim_path"
          echo "Installed shim: $shim_path"
        fi
      done
    fi

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
