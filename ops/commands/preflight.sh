#!/usr/bin/env bash
# ops preflight - print governance banner + registry hints
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/lib" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Best-effort: refresh the generated context snapshot so agents don't load stale rules.
BRAIN_DIR="$REPO_ROOT/docs/brain"
if [[ -x "$BRAIN_DIR/generate-context.sh" ]]; then
  "$BRAIN_DIR/generate-context.sh" >/dev/null 2>&1 || true
fi

source "$LIB_DIR/governance.sh"
source "$LIB_DIR/registry.sh"

GOV_HASH="$(compute_governance_hash)"
MAP_HASH="$(compute_map_hash)"
SEC_STATUS="$(check_secrets_cache)"
DOC_COUNT="$(count_governance_docs)"

REPO_GIT_OK=0
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  REPO_GIT_OK=1
fi

preflight_fail=0
gate_domain_fail=0
parity_status="unknown"
parity_detail=""
worktree_status="unknown"
worktree_detail=""
isolation_status="unknown"
isolation_detail=""
selected_gate_domain="${OPS_GATE_DOMAIN:-core}"
domain_source="default(core)"
if [[ -n "${OPS_GATE_DOMAIN:-}" ]]; then
  domain_source="OPS_GATE_DOMAIN"
fi
DRIFT_CERTIFIER="$REPO_ROOT/ops/plugins/verify/bin/drift-gates-certify"

if [[ "$REPO_GIT_OK" -eq 1 ]]; then
  # Remote parity (origin/main == github/main). This is the primary anti split-brain stop signal.
  D62="$REPO_ROOT/surfaces/verify/d62-git-remote-parity-lock.sh"
  if [[ -x "$D62" ]]; then
    if out="$("$D62" 2>&1)"; then
      parity_status="OK"
      parity_detail="$out"
    else
      parity_status="DRIFT"
      parity_detail="$out"
      preflight_fail=1
    fi
  else
    parity_status="WARN"
    parity_detail="WARN: D62 not present/executable"
  fi

  # Worktree hygiene (stale/dirty/orphaned codex worktrees).
  D48="$REPO_ROOT/surfaces/verify/d48-codex-worktree-hygiene.sh"
  if [[ -x "$D48" ]]; then
    if out="$("$D48" 2>&1)"; then
      worktree_status="OK"
      worktree_detail="$out"
    else
      worktree_status="WARN"
      worktree_detail="$out"
    fi
  else
    worktree_status="WARN"
    worktree_detail="WARN: D48 not present/executable"
  fi

  # Worktree/session isolation policy (D140).
  D140="$REPO_ROOT/surfaces/verify/d140-worktree-session-isolation.sh"
  if [[ -x "$D140" ]]; then
    if out="$("$D140" 2>&1)"; then
      isolation_status="OK"
      isolation_detail="$out"
    else
      isolation_status="BLOCKED"
      isolation_detail="$out"
      preflight_fail=1
    fi
  else
    isolation_status="WARN"
    isolation_detail="WARN: D140 not present/executable"
  fi
fi

echo
cat <<BANNER
╔═══════════════════════════════════════════════════════════╗
║ GOV_LOADED ✅  (${DOC_COUNT} docs in manifest)                    ║
║ gov=${GOV_HASH} | map=${MAP_HASH} | secrets=${SEC_STATUS} ║
╚═══════════════════════════════════════════════════════════╝
BANNER

if [[ -n "$CURRENT_ISSUE" ]]; then
  echo "📌 Active Issue: #${CURRENT_ISSUE}"
  echo "📁 Worktree: ${CURRENT_WORKTREE:-main}"
fi

echo "Services:"
API_URL="$(get_service_health_url mint-os-api 2>/dev/null || echo 'unknown')"
MINIO_URL="$(get_service_health_url minio 2>/dev/null || echo 'unknown')"
[ -n "$API_URL" ] && echo "  mint-os-api → $API_URL"
[ -n "$MINIO_URL" ] && echo "  minio → $MINIO_URL"

echo
export GOV_LOADED=1
export GOV_HASH
export MAP_HASH

# Branch hygiene hint (prevents silent drift on main).
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  current_branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -n "${current_branch:-}" ]]; then
    echo "Git:"
    echo "  branch: $current_branch"
    if [[ "$current_branch" == "main" ]]; then
      echo "  note: mutating capabilities are blocked on main (set OPS_ALLOW_MAIN_MUTATION=1 to override)."
    fi
    echo "  remote parity (D62): $parity_status"
    if [[ -n "${parity_detail:-}" ]]; then
      echo "    ${parity_detail}" | sed 's/^/    /'
    fi
    echo "  worktrees (D48): $worktree_status"
    if [[ -n "${worktree_detail:-}" ]]; then
      echo "    ${worktree_detail}" | sed 's/^/    /'
    fi
    echo "  isolation (D140): $isolation_status"
    if [[ -n "${isolation_detail:-}" ]]; then
      echo "    ${isolation_detail}" | sed 's/^/    /'
    fi

    hooks_path="$(git -C "$REPO_ROOT" config --get core.hooksPath 2>/dev/null || true)"
    hook_file="$REPO_ROOT/.githooks/pre-commit"
    if [[ "${hooks_path:-}" != ".githooks" ]]; then
      echo "  hooks: WARN (core.hooksPath is not .githooks)"
      echo "    fix: ./bin/ops hooks install"
	    else
	      if [[ -x "$hook_file" ]]; then
	        echo "  hooks: OK (.githooks/pre-commit installed)"
	      else
	        echo "  hooks: WARN (.githooks/pre-commit missing or not executable)"
	        echo "    fix: ./bin/ops hooks install"
	      fi
	    fi
	    echo
	  fi
	fi

echo "Gate Domains:"
echo "  selected: ${selected_gate_domain} (${domain_source})"
echo "  commands:"
echo "    ./bin/ops cap run verify.drift_gates.certify --list-domains"
echo "    ./bin/ops cap run verify.drift_gates.certify --domain <name> --brief"
echo "    ./bin/ops cap run verify.pack.list"
echo "    ./bin/ops cap run verify.pack.run <agent_id|domain>"

if [[ -x "$DRIFT_CERTIFIER" ]]; then
  if domain_list_out="$("$DRIFT_CERTIFIER" --list-domains 2>&1)"; then
    domain_list_csv="$(echo "$domain_list_out" | tr '\n' ',' | sed -E 's/,+$//' | sed -E 's/,/, /g')"
    echo "  available: ${domain_list_csv:-<none>}"
    if domain_brief_out="$("$DRIFT_CERTIFIER" --domain "$selected_gate_domain" --brief 2>&1)"; then
      echo "  pack:"
      echo "$domain_brief_out" | sed 's/^/    /'
    else
      echo "  pack: WARN (selected domain brief unavailable; non-blocking)"
      echo "$domain_brief_out" | sed 's/^/    /'
      if ! echo "$domain_brief_out" | grep -qi "unknown domain"; then
        gate_domain_fail=1
      fi
    fi
  else
    echo "  available: WARN (could not load domain registry)"
    echo "$domain_list_out" | sed 's/^/    /'
    gate_domain_fail=1
  fi
else
  echo "  available: WARN (missing certifier executable: $DRIFT_CERTIFIER)"
  gate_domain_fail=1
fi
echo

if [[ "$preflight_fail" -eq 1 || "$gate_domain_fail" -eq 1 ]]; then
  cat <<'STOP'
╔═══════════════════════════════════════════════════════════╗
║ STOP: PREFLIGHT BLOCKERS DETECTED                         ║
║                                                           ║
║ Resolve before starting new work.                          ║
╚═══════════════════════════════════════════════════════════╝
STOP
  if [[ "$preflight_fail" -eq 1 ]]; then
    echo "  - Remote authority (origin reachable; mirror drift warns)"
    echo "  - Worktree/session isolation policy (D140)"
  fi
  if [[ "$gate_domain_fail" -eq 1 ]]; then
    echo "  - Gate domain discoverability surface is broken"
  fi
  echo "  Override (not recommended): OPS_PREFLIGHT_ALLOW_DEGRADED=1"
  if [[ "${OPS_PREFLIGHT_ALLOW_DEGRADED:-0}" != "1" ]]; then
    exit 1
  fi
fi
