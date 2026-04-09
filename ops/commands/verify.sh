#!/usr/bin/env bash
set -euo pipefail

# Always resolve from script location — ignore ambient SPINE_ROOT to prevent
# poisoned env vars from redirecting worktree execution to the primary checkout.
SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_RUN="$SPINE_ROOT/ops/plugins/core/verify/bin/verify-run"

usage() {
  cat <<'EOF'
Usage: ops verify [OPTION]

Health surfaces:
  ops verify                   Infrastructure baseline (17 gates) [default]
  ops verify --core-only       Same as default (compatibility alias)
  ops verify --engine-smoke    Engine plumbing smoke test
  ops verify --engine-honesty  Engine orchestration proof (dispatch, wave, telemetry)
  ops verify --binding-coherence  Capability references in bindings vs registry
  ops verify --full            Readiness: status + infra baseline + secrets
  ops verify --preflight       Governance banner + git health + gate domains
  ops verify --all             All checks combined

Runtime backbone (for scripts and automation):
  ops cap run verify.run -- <scope>
  Scopes: fast | infra | engine | honesty | domain <id> | release
EOF
}

_section() {
  echo
  echo "────────────────────────────────────────"
  echo "$1"
  echo "────────────────────────────────────────"
}

# ---------- ready checks (inlined from ready.sh) ----------

_verify_full() {
  local rc=0

  echo "========================================"
  echo "FULL READINESS CHECK"
  echo "========================================"

  _section "READY CHECK: ops status --brief"
  "$SPINE_ROOT/bin/ops" status --brief || rc=1

  _section "READY CHECK: spine.verify"
  "$VERIFY_RUN" fast || rc=1

  _section "READY CHECK: secrets.binding"
  "$SPINE_ROOT/bin/ops" cap run secrets.binding || rc=1

  _section "READY CHECK: secrets.auth.load"
  "$SPINE_ROOT/bin/ops" cap run secrets.auth.load || rc=1

  _section "READY CHECK: secrets.auth.status"
  set +e
  "$SPINE_ROOT/bin/ops" cap run secrets.auth.status
  local auth_rc=$?
  set -e

  if [[ $auth_rc -eq 0 ]]; then
    :
  elif [[ $auth_rc -eq 2 ]]; then
    echo
    echo "STOP (exit 2): Infisical auth is NOT hydrated in this terminal."
    echo
    echo "Run this once in *this same terminal*:"
    echo "  source \"\$HOME/.config/infisical/credentials\""
    echo
    echo "Then rerun:"
    echo "  ./bin/ops verify --full"
    exit 2
  else
    echo
    echo "FAIL: secrets.auth.status exited $auth_rc"
    rc=1
  fi

  _section "READY CHECK: secrets.projects.status"
  "$SPINE_ROOT/bin/ops" cap run secrets.projects.status || rc=1

  echo
  if [[ $rc -eq 0 ]]; then
    echo "READY: This terminal is cleared for API-touching capabilities."
  else
    echo "FAIL: One or more readiness checks failed."
  fi
  return $rc
}

# ---------- preflight checks (inlined from preflight.sh) ----------

_verify_preflight() {
  local REPO_ROOT="$SPINE_ROOT"
  local preflight_fail=0
  local gate_domain_fail=0

  # Best-effort: refresh generated context snapshot
  local BRAIN_DIR="$REPO_ROOT/docs/reference/brain"
  if [[ -x "$BRAIN_DIR/generate-context.sh" ]]; then
    "$BRAIN_DIR/generate-context.sh" >/dev/null 2>&1 || true
  fi

  # Governance hash
  local _gov_files GOV_HASH DOC_COUNT
  _gov_files="$(find "$REPO_ROOT/docs/governance" -name '*.md' -type f 2>/dev/null | LC_ALL=C sort)"
  if [[ -n "$_gov_files" ]]; then
    GOV_HASH="$(echo "$_gov_files" | xargs cat 2>/dev/null | shasum -a 256 | cut -c1-8)"
    DOC_COUNT="$(echo "$_gov_files" | wc -l | tr -d ' ')"
  else
    GOV_HASH="none"
    DOC_COUNT="0"
  fi

  # Capability map hash
  local _cap_file="$REPO_ROOT/ops/capabilities.yaml"
  local MAP_HASH
  if [[ -f "$_cap_file" ]]; then
    MAP_HASH="$(shasum -a 256 "$_cap_file" | cut -c1-8)"
  else
    MAP_HASH="none"
  fi

  # Secrets cache status
  local SEC_STATUS
  if [[ -n "${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID:-}" || -n "${INFISICAL_TOKEN:-}" ]]; then
    SEC_STATUS="OK"
  else
    SEC_STATUS="WARN(no-auth)"
  fi

  local REPO_GIT_OK=0
  if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    REPO_GIT_OK=1
  fi

  local parity_status="unknown"
  local parity_detail=""
  local isolation_status="unknown"
  local isolation_detail=""
  local selected_gate_domain="${OPS_GATE_DOMAIN:-core}"
  local domain_source="default(core)"
  if [[ -n "${OPS_GATE_DOMAIN:-}" ]]; then
    domain_source="OPS_GATE_DOMAIN"
  fi
  local DRIFT_CERTIFIER="$REPO_ROOT/ops/plugins/core/verify/bin/drift-gates-certify"

  if [[ "$REPO_GIT_OK" -eq 1 ]]; then
    # Remote authority: origin on Gitea must resolve; GitHub mirror drift is warn-only.
    local D62="$REPO_ROOT/surfaces/verify/d62-git-remote-parity-lock.sh"
    local out
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

    # Worktree/session isolation policy (D140).
    local D140="$REPO_ROOT/surfaces/verify/d140-worktree-session-isolation.sh"
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
║ GOV_LOADED   (${DOC_COUNT} docs in manifest)                      ║
║ gov=${GOV_HASH} | map=${MAP_HASH} | secrets=${SEC_STATUS} ║
╚═══════════════════════════════════════════════════════════╝
BANNER

  if [[ -n "${CURRENT_ISSUE:-}" ]]; then
    echo "Active Issue: #${CURRENT_ISSUE}"
    echo "Worktree: ${CURRENT_WORKTREE:-main}"
  fi

  echo
  export GOV_LOADED=1
  export GOV_HASH
  export MAP_HASH

  # Branch hygiene
  if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    local current_branch
    current_branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [[ -n "${current_branch:-}" ]]; then
      echo "Git:"
      echo "  branch: $current_branch"
      echo "  remote authority (D62): $parity_status"
      if [[ -n "${parity_detail:-}" ]]; then
        echo "    ${parity_detail}" | sed 's/^/    /'
      fi
      echo "  isolation (D140): $isolation_status"
      if [[ -n "${isolation_detail:-}" ]]; then
        echo "    ${isolation_detail}" | sed 's/^/    /'
      fi

      local hooks_path
      hooks_path="$(git -C "$REPO_ROOT" config --get core.hooksPath 2>/dev/null || true)"
      local hook_file="$REPO_ROOT/.githooks/pre-commit"
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
    local domain_list_out domain_list_csv domain_brief_out
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
      return 1
    fi
  fi
}

# ---------- all checks ----------

_verify_all() {
  local rc=0

  echo "╔═══════════════════════════════════════════════════════════╗"
  echo "║ COMPREHENSIVE VERIFY                                      ║"
  echo "╚═══════════════════════════════════════════════════════════╝"

  _section "PREFLIGHT"
  _verify_preflight || rc=1

  _section "STATUS"
  "$SPINE_ROOT/bin/ops" status --brief || rc=1

  _section "INFRASTRUCTURE BASELINE (17 gates)"
  "$VERIFY_RUN" fast || rc=1

  _section "SECRETS"
  "$SPINE_ROOT/bin/ops" cap run secrets.binding || rc=1
  "$SPINE_ROOT/bin/ops" cap run secrets.auth.load || rc=1
  set +e
  "$SPINE_ROOT/bin/ops" cap run secrets.auth.status
  local auth_rc=$?
  set -e
  if [[ $auth_rc -ne 0 ]]; then
    echo "WARN: secrets.auth.status exited $auth_rc (non-blocking for --all)"
    rc=1
  fi
  "$SPINE_ROOT/bin/ops" cap run secrets.projects.status || rc=1

  _section "ENGINE SMOKE"
  "$VERIFY_RUN" engine || rc=1

  _section "ENGINE HONESTY"
  "$VERIFY_RUN" honesty || rc=1

  echo
  echo "════════════════════════════════════════"
  if [[ $rc -eq 0 ]]; then
    echo "ALL CHECKS PASSED"
  else
    echo "SOME CHECKS FAILED (review output above)"
  fi
  echo "════════════════════════════════════════"
  return $rc
}

# ---------- dispatch ----------

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --core-only|"")
    echo "SPINE_ROOT=$SPINE_ROOT"
    echo "VERIFY_MODE=runtime-workload-gates"
    echo
    echo "Runtime verify: workload and infrastructure gates"
    exec "$VERIFY_RUN" fast
    ;;
  --engine-honesty)
    echo "SPINE_ROOT=$SPINE_ROOT"
    echo "VERIFY_MODE=engine-honesty"
    echo
    echo "Engine verify: orchestration proof (dispatch, wave, telemetry, close)"
    exec "$VERIFY_RUN" honesty
    ;;
  --engine-smoke)
    echo "SPINE_ROOT=$SPINE_ROOT"
    echo "VERIFY_MODE=engine-smoke"
    echo
    echo "Engine verify: platform plumbing smoke test"
    exec "$VERIFY_RUN" engine
    ;;
  --binding-coherence)
    echo "SPINE_ROOT=$SPINE_ROOT"
    echo "VERIFY_MODE=binding-coherence"
    echo
    exec "$SPINE_ROOT/ops/plugins/core/verify/bin/verify-binding-coherence"
    ;;
  --full)
    _verify_full
    ;;
  --preflight)
    _verify_preflight
    ;;
  --all)
    _verify_all
    ;;
  *)
    echo "ops verify: unknown argument '$1'" >&2
    echo >&2
    usage >&2
    exit 2
    ;;
esac
