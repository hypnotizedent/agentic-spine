#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT=""
STATE_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$(cd "${2:-}" && pwd)"
      shift 2
      ;;
    --contract)
      CONTRACT="${2:-}"
      shift 2
      ;;
    --state-root)
      STATE_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--root <target-checkout>] [--contract <path>] [--state-root <path>]" >&2
      echo "Detects repo-local runtime path pollution and unapproved canonical state homes." >&2
      exit 0
      ;;
    *)
      echo "D423 FAIL: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

FAILURES=0
[[ -n "$CONTRACT" ]] || CONTRACT="$ROOT/ops/bindings/root.authority.contract.yaml"

# Check for repo-local mailroom directory
if [[ -e "$ROOT/mailroom" ]]; then
  echo "D423 FAIL: repo-local mailroom directory exists at $ROOT/mailroom/" >&2
  echo "  Runtime state must live outside the repo under governed runtime roots." >&2
  echo "  Operational task state lives under \$SPINE_STATE/agent-tasks; logical mailroom inbox/outbox paths resolve externally." >&2
  echo "  See: root.authority.contract.yaml" >&2
  FAILURES=$((FAILURES + 1))
fi

# Check for repo-local .runtime directory
if [[ -e "$ROOT/.runtime" ]]; then
  echo "D423 FAIL: repo-local .runtime directory exists at $ROOT/.runtime/" >&2
  echo "  Runtime state must live outside the repo under \$SPINE_RUNTIME_ROOT (logical)." >&2
  echo "  Canonical authority: pve /md1400/spine (storage_evidence_node)." >&2
  echo "  Consumer-host resolution (e.g., MacBook ~/code/.runtime/spine) is projection/cache only." >&2
  echo "  See: root.authority.contract.yaml#taxonomy.storage_evidence_node_canonical.file_plane_policy" >&2
  FAILURES=$((FAILURES + 1))
fi

# Check for loop scope files in wrong locations
if find "$ROOT" -path "$ROOT/.git" -prune -o -type f -path "*/mailroom/state/loop-scopes/*.scope.md" -print 2>/dev/null | grep -q .; then
  echo "D423 FAIL: loop scope files found in repo-local mailroom/state/" >&2
  echo "  Loop scopes must live in \$SPINE_STATE/loop-scopes/" >&2
  find "$ROOT" -path "$ROOT/.git" -prune -o -type f -path "*/mailroom/state/loop-scopes/*.scope.md" -print 2>/dev/null | sed 's/^/    /' >&2
  FAILURES=$((FAILURES + 1))
fi

# Check for domain-state files in wrong locations
if find "$ROOT" -path "$ROOT/.git" -prune -o -type f -path "*/.runtime/spine/state/domain-state/*" -print 2>/dev/null | grep -q .; then
  echo "D423 FAIL: domain-state files found in repo-local .runtime/" >&2
  echo "  Domain state must live under \$SPINE_STATE/domain-state/ (logical), never inside the repo." >&2
  echo "  Canonical authority: pve /md1400/spine/state/domain-state (storage_evidence_node)." >&2
  echo "  Consumer-host \$SPINE_STATE/domain-state is projection/cache only." >&2
  find "$ROOT" -path "$ROOT/.git" -prune -o -type f -path "*/.runtime/spine/state/domain-state/*" -print 2>/dev/null | sed 's/^/    /' >&2
  FAILURES=$((FAILURES + 1))
fi

STATE_HOME_FAILURES=0
if [[ -f "$CONTRACT" ]]; then
  set +e
  python3 - "$CONTRACT" "${STATE_ROOT:-}" <<'PY'
import sys
from pathlib import Path

import yaml

contract_path = Path(sys.argv[1])
state_arg = (sys.argv[2] or "").strip()
contract = yaml.safe_load(contract_path.read_text(encoding="utf-8")) or {}
storage = ((contract.get("taxonomy") or {}).get("storage_evidence_node_canonical") or {})
canonical_raw = ((storage.get("primary_canonical_subpaths") or {}).get("state") or "").strip()
policy = ((storage.get("file_plane_policy") or {}).get("state_home_approval") or {})

if not canonical_raw:
    print("D423 FAIL: root.authority.contract.yaml missing primary canonical state path", file=sys.stderr)
    raise SystemExit(1)
if not policy:
    print("D423 FAIL: root.authority.contract.yaml missing state_home_approval block", file=sys.stderr)
    raise SystemExit(1)

state_root = Path(state_arg) if state_arg else Path(canonical_raw)
if not state_root.exists():
    # Consumer hosts may not mount /md1400. spine.verify routes to the authority
    # host for canonical checks; direct local invocation stays repo-local only.
    raise SystemExit(0)

canonical = Path(canonical_raw)
if not state_arg:
    try:
        if state_root.resolve() != canonical.resolve():
            raise SystemExit(0)
    except FileNotFoundError:
        raise SystemExit(0)

approved_top = set(str(x) for x in (policy.get("approved_top_level_homes") or []))
approved_domain = set(str(x) for x in (policy.get("approved_domain_state_homes") or []))
retired_domain = set(str(x) for x in (policy.get("retired_domain_state_homes") or []))

top_dirs = sorted(p.name for p in state_root.iterdir() if p.is_dir())
domain_root = state_root / "domain-state"
domain_dirs = sorted(p.name for p in domain_root.iterdir() if p.is_dir()) if domain_root.is_dir() else []

unapproved_top = [name for name in top_dirs if name not in approved_top]
unapproved_domain = [name for name in domain_dirs if name not in approved_domain]
retired_present = [name for name in domain_dirs if name in retired_domain]

if unapproved_top or unapproved_domain or retired_present:
    print("D423 FAIL: unapproved canonical state home(s) detected", file=sys.stderr)
    print(f"  state_root: {state_root}", file=sys.stderr)
    if unapproved_top:
        print(f"  unapproved top-level homes: {', '.join(unapproved_top)}", file=sys.stderr)
    if unapproved_domain:
        print(f"  unapproved domain-state homes: {', '.join(unapproved_domain)}", file=sys.stderr)
    if retired_present:
        print(f"  retired domain-state homes present: {', '.join(retired_present)}", file=sys.stderr)
    print("  next: remove drift or record human-steward approval in root.authority.contract.yaml.", file=sys.stderr)
    raise SystemExit(1)
PY
  STATE_HOME_FAILURES=$?
  set -e
  if [[ "$STATE_HOME_FAILURES" -ne 0 ]]; then
    FAILURES=$((FAILURES + 1))
  fi
else
  echo "D423 FAIL: root authority contract missing at $CONTRACT" >&2
  FAILURES=$((FAILURES + 1))
fi

if [[ "$FAILURES" -gt 0 ]]; then
  echo "D423 FAIL: $FAILURES runtime path pollution issue(s) detected" >&2
  exit 1
fi

echo "D423 PASS: no repo-local runtime pollution or unapproved canonical state homes detected"
