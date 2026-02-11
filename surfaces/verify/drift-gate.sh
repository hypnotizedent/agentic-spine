#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# drift-gate.sh - Constitutional drift detector (v2.6)
# ═══════════════════════════════════════════════════════════════
#
# Enforces the Minimal Spine Constitution.
# Run after any change. Must pass before merge.
#
# Exit: 0 = PASS, 1 = FAIL
#
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SP="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RT="${SPINE_REPO:-$SP}"
cd "$SP"
FAIL=0

pass(){ echo "PASS"; }
fail(){ echo "FAIL $*"; FAIL=1; }
warn(){ echo "WARN $*"; }

DRIFT_VERBOSE="${DRIFT_VERBOSE:-0}"

gate_script() {
  local script="$1"
  local tmp rc
  tmp="$(mktemp)"
  set +e
  bash "$script" >"$tmp" 2>&1
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    pass
    # Preserve advisory WARN lines (if any), but drop PASS noise from scripts.
    if grep -q '^WARN' "$tmp" 2>/dev/null; then
      grep '^WARN' "$tmp" 2>/dev/null || true
    fi
  else
    fail "$script failed (rc=$rc)"
    echo "  --- output (first 80 lines): $script ---"
    sed -n '1,80p' "$tmp" | sed 's/^/  /' || true
    echo "  --- end output ---"
  fi

  rm -f "$tmp" 2>/dev/null || true
}

echo "=== DRIFT GATE (v2.6) ==="

# D1: Top-level directory policy (9 allowed)
echo -n "D1 top-level dirs... "
EXTRA="$(ls -1d */ 2>/dev/null | rg -v '^(bin|docs|fixtures|mailroom|ops|receipts|surfaces)/$' || true)"
[[ -z "$EXTRA" ]] && pass || fail "extra dirs: $(echo "$EXTRA" | tr '\n' ' ')"

# D2: No runs/ trace
echo -n "D2 one trace (no runs/)... "
[[ ! -d runs ]] && pass || fail "runs/ exists"

# D3: Entrypoint smoke
echo -n "D3 entrypoint smoke... "
./bin/ops preflight >/dev/null 2>&1 && pass || fail "bin/ops preflight failed"

# D4: Watcher (launchd canonical; warn only, no fail)
echo -n "D4 watcher... "
WATCHER_PRINT="$(launchctl print "gui/$(id -u)/com.ronny.agent-inbox" 2>/dev/null || true)"
if [[ -n "$WATCHER_PRINT" ]]; then
  WATCHER_STATE="$(echo "$WATCHER_PRINT" | awk -F' = ' '/state =/{print $2; exit}')"
  WATCHER_PID="$(echo "$WATCHER_PRINT" | awk '/pid =/{print $3; exit}')"
  if [[ "$WATCHER_STATE" == "running" && -n "$WATCHER_PID" ]]; then
    pass
  else
    warn "(loaded but state=$WATCHER_STATE pid=${WATCHER_PID:-none})"
  fi
else
  WATCHER_INFO="$(launchctl list com.ronny.agent-inbox 2>/dev/null || true)"
  if [[ -n "$WATCHER_INFO" ]]; then
    WATCHER_PID="$(echo "$WATCHER_INFO" | sed -n 's/.*"PID" = \([0-9]*\).*/\1/p')"
    if [[ -n "$WATCHER_PID" ]]; then
      pass
    else
      warn "(loaded but no PID)"
    fi
  else
    warn "(launchd service not loaded)"
  fi
fi

# D5: No executable ~/agent coupling
echo -n "D5 no legacy coupling... "
COUPLE="$(rg -n '(\$HOME/agent|~/agent)' bin ops ops/runtime/inbox surfaces/verify 2>/dev/null \
  | rg -v '^[[:space:]]*#' \
  | rg -v 'foundation-gate.sh' \
  | rg -v 'drift-gate.sh' \
  | rg -v 'cloudflare-drift-gate.sh' \
  | rg -v 'github-actions-gate.sh' \
  | rg -v 'd18-docker-compose-drift.sh' \
  | rg -v 'd19-backup-drift.sh' \
  | rg -v 'd20-secrets-drift.sh' \
  | rg -v 'd22-nodes-drift.sh' \
  | rg -v 'd23-health-drift.sh' \
  | rg -v 'd24-github-labels-drift.sh' || true)"
[[ -z "$COUPLE" ]] && pass || fail "legacy coupling found"

# D6: Receipts exist (latest 5 have receipt.md)
echo -n "D6 receipts exist... "
MISSING=0
COUNT=0
for s in $(ls -1t "$RT/receipts/sessions" 2>/dev/null); do
  [[ -f "$RT/receipts/sessions/$s/receipt.md" ]] || MISSING=$((MISSING+1))
  COUNT=$((COUNT+1))
  [[ "$COUNT" -ge 5 ]] && break
done
[[ "$MISSING" -eq 0 ]] && pass || fail "$MISSING missing receipt.md"

# D7: Executables only in four zones
echo -n "D7 executables bounded... "
BAD="$(find . -type f -name "*.sh" \
  | rg -v '^\./(bin/|ops/|surfaces/verify/)' \
  | rg -v '^\./(_imports/|docs/|receipts/|mailroom/|\.git/|\.spine/|\.archive/|\.worktrees/)' || true)"
[[ -z "$BAD" ]] && pass || fail "out-of-bounds: $(echo "$BAD" | wc -l | tr -d ' ')"

# D8: No backup clutter
echo -n "D8 no backup clutter... "
BK="$(find bin ops -maxdepth 1 -type f 2>/dev/null | rg '\.bak|fix_bak' || true)"
[[ -z "$BK" ]] && pass || fail "backup files"

# D10: No spurious top-level logs (must be under mailroom/)
echo -n "D10 logs under mailroom... "
if [[ -d "$SP/logs" ]]; then
  fail "spurious \$SPINE/logs exists (should be mailroom/logs)"
else
  pass
fi

# D11: ~/agent must be symlink to mailroom (if exists)
echo -n "D11 home surface... "
if [[ -e "$HOME/agent" ]]; then
  if [[ -L "$HOME/agent" ]]; then
    TARGET="$(readlink "$HOME/agent")"
    if [[ "$TARGET" == *"agentic-spine/mailroom"* ]]; then
      pass
    else
      fail "~/agent symlink points to wrong target: $TARGET"
    fi
  else
    fail "~/agent is a directory (should be symlink to mailroom)"
  fi
else
  pass  # doesn't exist, that's fine
fi

# D12: CORE_LOCK.md must exist (repo validity marker)
echo -n "D12 core lock exists... "
[[ -f "$SP/docs/core/CORE_LOCK.md" ]] && pass || fail "docs/core/CORE_LOCK.md missing"

# D9: Receipt stamps (STRICT - required fields for all new receipts)
# Receipts created after core-v1.0 must have: Run ID, Generated, Status, Model, Inputs, Outputs
echo -n "D9 receipt stamps... "
LATEST=""
for s in $(ls -1t "$RT/receipts/sessions" 2>/dev/null); do
  LATEST="$s"
  break
done
if [[ -n "$LATEST" ]] && [[ -f "$RT/receipts/sessions/$LATEST/receipt.md" ]]; then
  STAMP_FILE="$RT/receipts/sessions/$LATEST/receipt.md"

  # Check for required fields (core-v1.0 contract)
  HAS_RUN_ID=$(rg -q "Run ID" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_GENERATED=$(rg -q "Generated" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_STATUS=$(rg -q "Status" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_MODEL=$(rg -q "Model" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_INPUTS=$(rg -q "Inputs" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_OUTPUTS=$(rg -q "Outputs" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)

  MISSING=""
  [[ "$HAS_RUN_ID" == "0" ]] && MISSING+="Run_ID "
  [[ "$HAS_GENERATED" == "0" ]] && MISSING+="Generated "
  [[ "$HAS_STATUS" == "0" ]] && MISSING+="Status "
  [[ "$HAS_MODEL" == "0" ]] && MISSING+="Model "
  [[ "$HAS_INPUTS" == "0" ]] && MISSING+="Inputs "
  [[ "$HAS_OUTPUTS" == "0" ]] && MISSING+="Outputs "

  if [[ -z "$MISSING" ]]; then
    pass
  else
    fail "latest receipt missing: $MISSING"
  fi
else
  warn "no receipts to check"
fi

# D13: API capability secrets preconditions (locked rule)
echo -n "D13 api capability preconditions... "
if [[ -x "$SP/surfaces/verify/api-preconditions.sh" ]]; then
  gate_script "$SP/surfaces/verify/api-preconditions.sh"
else
  warn "api-preconditions verifier not present"
fi

# D14: Cloudflare surface drift gate (no legacy smells, read-only)
echo -n "D14 cloudflare drift gate... "
if [[ -x "$SP/surfaces/verify/cloudflare-drift-gate.sh" ]]; then
  gate_script "$SP/surfaces/verify/cloudflare-drift-gate.sh"
else
  warn "cloudflare drift gate not present"
fi

# D15: GitHub Actions surface drift gate (no legacy smells, read-only, no leak fields)
echo -n "D15 github actions drift gate... "
if [[ -x "$SP/surfaces/verify/github-actions-gate.sh" ]]; then
  gate_script "$SP/surfaces/verify/github-actions-gate.sh"
else
  warn "github actions drift gate not present"
fi

# D16: Canonical docs quarantine (no competing truths)
echo -n "D16 docs quarantine... "
if [[ -x "$SP/surfaces/verify/d16-docs-quarantine.sh" ]]; then
  gate_script "$SP/surfaces/verify/d16-docs-quarantine.sh"
else
  warn "docs quarantine gate not present"
fi

# D17: Root allowlist (no agents/, _imports/, or other drift magnets at root)
echo -n "D17 root allowlist... "
if [[ -x "$SP/surfaces/verify/d17-root-allowlist.sh" ]]; then
  gate_script "$SP/surfaces/verify/d17-root-allowlist.sh"
else
  warn "root allowlist gate not present"
fi

# D18: Docker compose surface drift gate (read-only, no legacy smells)
echo -n "D18 docker compose drift gate... "
if [[ -x "$SP/surfaces/verify/d18-docker-compose-drift.sh" ]]; then
  gate_script "$SP/surfaces/verify/d18-docker-compose-drift.sh"
else
  warn "docker compose drift gate not present"
fi

# D19: Backup surface drift gate (read-only inventory, no legacy smells, no secret printing)
echo -n "D19 backup drift gate... "
if [[ -x "$SP/surfaces/verify/d19-backup-drift.sh" ]]; then
  gate_script "$SP/surfaces/verify/d19-backup-drift.sh"
else
  warn "backup drift gate not present"
fi

# D20 / D55: Secrets readiness (verbose runs subchecks; default runs composite)
if [[ "${DRIFT_VERBOSE}" == "1" ]]; then
  echo -n "D20 secrets drift gate... "
  if [[ -x "$SP/surfaces/verify/d20-secrets-drift.sh" ]]; then
    gate_script "$SP/surfaces/verify/d20-secrets-drift.sh"
  else
    warn "secrets drift gate not present"
  fi
else
  echo -n "D55 secrets runtime readiness lock... "
  if [[ -x "$SP/surfaces/verify/d55-secrets-runtime-readiness-lock.sh" ]]; then
    gate_script "$SP/surfaces/verify/d55-secrets-runtime-readiness-lock.sh"
  else
    warn "secrets runtime readiness lock gate not present"
  fi
fi

# D22: Nodes surface drift gate (read-only SSH, no credentials, no mutations)
echo -n "D22 nodes drift gate... "
if [[ -x "$SP/surfaces/verify/d22-nodes-drift.sh" ]]; then
  gate_script "$SP/surfaces/verify/d22-nodes-drift.sh"
else
  warn "nodes drift gate not present"
fi

# D23: Services health surface drift gate (no verbose curl, no auth printing)
echo -n "D23 health drift gate... "
if [[ -x "$SP/surfaces/verify/d23-health-drift.sh" ]]; then
  gate_script "$SP/surfaces/verify/d23-health-drift.sh"
else
  warn "health drift gate not present"
fi

# D24: GitHub labels drift gate
echo -n "D24 github labels drift gate... "
if [[ -x "$SP/surfaces/verify/d24-github-labels-drift.sh" ]]; then
  gate_script "$SP/surfaces/verify/d24-github-labels-drift.sh"
else
  warn "github labels drift gate not present"
fi

# D25: Secrets CLI canonical lock (verbose only; default runs via D55 composite)
if [[ "${DRIFT_VERBOSE}" == "1" ]]; then
  echo -n "D25 secrets cli canonical lock... "
  if [[ -x "$SP/surfaces/verify/d25-secrets-cli-canonical-lock.sh" ]]; then
    gate_script "$SP/surfaces/verify/d25-secrets-cli-canonical-lock.sh"
  else
    warn "secrets cli canonical lock gate not present"
  fi
fi

# D26 / D56: Agent entry surfaces (verbose runs subchecks; default runs composite)
if [[ "${DRIFT_VERBOSE}" == "1" ]]; then
  echo -n "D26 agent read surface drift... "
  if [[ -x "$SP/surfaces/verify/d26-agent-read-surface.sh" ]]; then
    gate_script "$SP/surfaces/verify/d26-agent-read-surface.sh"
  else
    warn "agent read surface drift gate not present"
  fi
else
  echo -n "D56 agent entry surface lock... "
  if [[ -x "$SP/surfaces/verify/d56-agent-entry-surface-lock.sh" ]]; then
    gate_script "$SP/surfaces/verify/d56-agent-entry-surface-lock.sh"
  else
    warn "agent entry surface lock gate not present"
  fi
fi

# D27: Fact duplication lock for startup/governance read surfaces
echo -n "D27 fact duplication lock... "
if [[ -x "$SP/surfaces/verify/d27-fact-duplication-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d27-fact-duplication-lock.sh"
else
  warn "fact duplication drift gate not present"
fi

# D28: Archive runway lock (active legacy absolute paths + extraction queue contract)
echo -n "D28 archive runway lock... "
if [[ -x "$SP/surfaces/verify/d28-legacy-path-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d28-legacy-path-lock.sh"
else
  warn "archive runway lock gate not present"
fi

# D29: Active entrypoint lock (launchd/cron in /Code must not execute from ronny-ops)
echo -n "D29 active entrypoint lock... "
if [[ -x "$SP/surfaces/verify/d29-active-entrypoint-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d29-active-entrypoint-lock.sh"
else
  warn "active entrypoint lock gate not present"
fi

# D30: Active config lock (legacy refs + plaintext token patterns)
echo -n "D30 active config lock... "
if [[ -x "$SP/surfaces/verify/d30-active-config-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d30-active-config-lock.sh"
else
  warn "active config lock gate not present"
fi

# D31: Home output sink lock (home-root logs/out/err not allowlisted)
echo -n "D31 home output sink lock... "
if [[ -x "$SP/surfaces/verify/d31-home-output-sink-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d31-home-output-sink-lock.sh"
else
  warn "home output sink lock gate not present"
fi

# D32: Codex instruction source lock (verbose only; default runs via D56 composite)
if [[ "${DRIFT_VERBOSE}" == "1" ]]; then
  echo -n "D32 codex instruction source lock... "
  if [[ -x "$SP/surfaces/verify/d32-codex-instruction-source-lock.sh" ]]; then
    gate_script "$SP/surfaces/verify/d32-codex-instruction-source-lock.sh"
  else
    warn "codex instruction source lock gate not present"
  fi
fi

# D33: Extraction pause lock (must stay paused during stabilization)
echo -n "D33 extraction pause lock... "
if [[ -x "$SP/surfaces/verify/d33-extraction-pause-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d33-extraction-pause-lock.sh"
else
  warn "extraction pause lock gate not present"
fi

# D34: Loop ledger integrity lock (summary must match deduped counts)
echo -n "D34 loop ledger integrity lock... "
if [[ -x "$SP/surfaces/verify/d34-loop-ledger-integrity-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d34-loop-ledger-integrity-lock.sh"
else
  warn "loop ledger integrity lock gate not present"
fi

# D35: Infra relocation parity lock (cross-SSOT consistency for service moves)
echo -n "D35 infra relocation parity lock... "
if [[ -x "$SP/surfaces/verify/d35-infra-relocation-parity-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d35-infra-relocation-parity-lock.sh"
else
  warn "infra relocation parity lock gate not present"
fi

# D36: Legacy exception hygiene lock (stale/near-expiry exceptions)
echo -n "D36 legacy exception hygiene lock... "
if [[ -x "$SP/surfaces/verify/d36-legacy-exception-hygiene-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d36-legacy-exception-hygiene-lock.sh"
else
  warn "legacy exception hygiene lock gate not present"
fi

# D37 / D57: Infra identity cohesion (verbose runs subchecks; default runs composite)
if [[ "${DRIFT_VERBOSE}" == "1" ]]; then
  echo -n "D37 infra placement policy lock... "
  if [[ -x "$SP/surfaces/verify/d37-infra-placement-policy-lock.sh" ]]; then
    gate_script "$SP/surfaces/verify/d37-infra-placement-policy-lock.sh"
  else
    warn "infra placement policy lock gate not present"
  fi
else
  echo -n "D57 infra identity cohesion lock... "
  if [[ -x "$SP/surfaces/verify/d57-infra-identity-cohesion-lock.sh" ]]; then
    gate_script "$SP/surfaces/verify/d57-infra-identity-cohesion-lock.sh"
  else
    warn "infra identity cohesion lock gate not present"
  fi
fi

# D38: Service extraction hygiene lock (EXTRACTION_PROTOCOL.md enforcement)
echo -n "D38 extraction hygiene lock... "
if [[ -x "$SP/surfaces/verify/d38-extraction-hygiene-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d38-extraction-hygiene-lock.sh"
else
  warn "extraction hygiene lock gate not present"
fi

# D39: Hypervisor identity lock (verbose only; default runs via D57 composite)
if [[ "${DRIFT_VERBOSE}" == "1" ]]; then
  echo -n "D39 infra hypervisor identity lock... "
  if [[ -x "$SP/surfaces/verify/d39-infra-hypervisor-identity-lock.sh" ]]; then
    gate_script "$SP/surfaces/verify/d39-infra-hypervisor-identity-lock.sh"
  else
    warn "infra hypervisor identity lock gate not present"
  fi
fi

# D40: Maker tools drift gate (binding validity, script hygiene)
echo -n "D40 maker tools drift gate... "
if [[ -x "$SP/surfaces/verify/d40-maker-tools-drift.sh" ]]; then
  gate_script "$SP/surfaces/verify/d40-maker-tools-drift.sh"
else
  warn "maker tools drift gate not present"
fi

# D41: Hidden-root governance lock (home-root inventory + forbidden pattern enforcement)
echo -n "D41 hidden-root governance lock... "
if [[ -x "$SP/surfaces/verify/d41-hidden-root-governance-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d41-hidden-root-governance-lock.sh"
else
  warn "hidden-root governance lock gate not present"
fi

# D42: Code path case lock (runtime scripts must use lowercase code path)
echo -n "D42 code path case lock... "
if [[ -x "$SP/surfaces/verify/d42-code-path-case-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d42-code-path-case-lock.sh"
else
  warn "code path case lock gate not present"
fi

# D43: Secrets namespace policy lock (policy + capability wiring)
echo -n "D43 secrets namespace lock... "
if [[ -x "$SP/surfaces/verify/d43-secrets-namespace-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d43-secrets-namespace-lock.sh"
else
  warn "secrets namespace lock gate not present"
fi

# D44: CLI tools discovery lock (inventory + cross-refs + probes)
echo -n "D44 cli tools discovery lock... "
if [[ -x "$SP/surfaces/verify/d44-cli-tools-discovery-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d44-cli-tools-discovery-lock.sh"
else
  warn "cli tools discovery lock gate not present"
fi

# D45: Naming consistency lock (cross-file identity surface verification)
echo -n "D45 naming consistency lock... "
if [[ -x "$SP/surfaces/verify/d45-naming-consistency-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d45-naming-consistency-lock.sh"
else
  warn "naming consistency lock gate not present"
fi

# D46: Claude instruction source lock (verbose only; default runs via D56 composite)
if [[ "${DRIFT_VERBOSE}" == "1" ]]; then
  echo -n "D46 claude instruction source lock... "
  if [[ -x "$SP/surfaces/verify/d46-claude-instruction-source-lock.sh" ]]; then
    gate_script "$SP/surfaces/verify/d46-claude-instruction-source-lock.sh"
  else
    warn "claude instruction source lock gate not present"
  fi
fi

# D47: Brain surface path lock (no .brain/ in runtime scripts)
echo -n "D47 brain surface path lock... "
if [[ -x "$SP/surfaces/verify/d47-brain-surface-path-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d47-brain-surface-path-lock.sh"
else
  warn "brain surface path lock gate not present"
fi

# D48: Codex worktree hygiene (codex/.worktrees)
echo -n "D48 codex worktree hygiene... "
if [[ -x "$SP/surfaces/verify/d48-codex-worktree-hygiene.sh" ]]; then
  gate_script "$SP/surfaces/verify/d48-codex-worktree-hygiene.sh"
else
  warn "codex worktree hygiene gate not present"
fi

# D49: Agent discovery lock (agents.registry.yaml + contracts)
echo -n "D49 agent discovery lock... "
if [[ -x "$SP/surfaces/verify/d49-agent-discovery-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d49-agent-discovery-lock.sh"
else
  warn "agent discovery lock gate not present"
fi

# D50: Gitea CI workflow lock (workflow file + drift-gate reference)
echo -n "D50 gitea ci workflow lock... "
if [[ -x "$SP/surfaces/verify/d50-gitea-ci-workflow-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d50-gitea-ci-workflow-lock.sh"
else
  warn "gitea ci workflow lock gate not present"
fi

# D51: Caddy proto lock (X-Forwarded-Proto on all Authentik upstreams)
echo -n "D51 caddy proto lock... "
if [[ -x "$SP/surfaces/verify/d51-caddy-proto-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d51-caddy-proto-lock.sh"
else
  warn "caddy proto lock gate not present"
fi

# D52: UDR6 gateway assertion (shop SSOT docs reference 192.168.1.0/24)
echo -n "D52 udr6 gateway assertion... "
if [[ -x "$SP/surfaces/verify/d52-udr6-gateway-assertion.sh" ]]; then
  gate_script "$SP/surfaces/verify/d52-udr6-gateway-assertion.sh"
else
  warn "udr6 gateway assertion gate not present"
fi

# D53: Change pack integrity lock (template + sequencing + companion files)
echo -n "D53 change pack integrity lock... "
if [[ -x "$SP/surfaces/verify/d53-change-pack-integrity-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d53-change-pack-integrity-lock.sh"
else
  warn "change pack integrity lock gate not present"
fi

# D54: SSOT IP parity lock (device identity ↔ shop server ↔ bindings)
echo -n "D54 ssot ip parity lock... "
if [[ -x "$SP/surfaces/verify/d54-ssot-ip-parity-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d54-ssot-ip-parity-lock.sh"
else
  warn "ssot ip parity lock gate not present"
fi

# D58: SSOT freshness lock (last_reviewed date enforcement)
echo -n "D58 ssot freshness lock... "
if [[ -x "$SP/surfaces/verify/d58-ssot-freshness-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d58-ssot-freshness-lock.sh"
else
  warn "ssot freshness lock gate not present"
fi

# D59: Cross-registry completeness lock (bidirectional host coverage)
echo -n "D59 cross-registry completeness lock... "
if [[ -x "$SP/surfaces/verify/d59-cross-registry-completeness-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d59-cross-registry-completeness-lock.sh"
else
  warn "cross-registry completeness lock gate not present"
fi

# D60: Deprecation sweeper (known deprecated terms in governance docs)
echo -n "D60 deprecation sweeper... "
if [[ -x "$SP/surfaces/verify/d60-deprecation-sweeper.sh" ]]; then
  gate_script "$SP/surfaces/verify/d60-deprecation-sweeper.sh"
else
  warn "deprecation sweeper gate not present"
fi

# D61: Session-loop traceability lock (closeout freshness)
echo -n "D61 session-loop traceability lock... "
if [[ -x "$SP/surfaces/verify/d61-session-loop-traceability-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d61-session-loop-traceability-lock.sh"
else
  warn "session-loop traceability lock gate not present"
fi

# D62: Git remote parity lock (origin/main == github/main)
echo -n "D62 git remote parity lock... "
if [[ -x "$SP/surfaces/verify/d62-git-remote-parity-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d62-git-remote-parity-lock.sh"
else
  warn "git remote parity lock gate not present"
fi

# D63: Capabilities metadata lock (registry integrity)
echo -n "D63 capabilities metadata lock... "
if [[ -x "$SP/surfaces/verify/d63-capabilities-metadata-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d63-capabilities-metadata-lock.sh"
else
  warn "capabilities metadata lock gate not present"
fi

# D64: Git remote authority warn (GitHub merges/PRs)
echo -n "D64 git remote authority warn... "
if [[ -x "$SP/surfaces/verify/d64-git-remote-authority-warn.sh" ]]; then
  gate_script "$SP/surfaces/verify/d64-git-remote-authority-warn.sh"
else
  warn "git remote authority warn gate not present"
fi

# D65: Agent briefing sync lock (AGENTS.md + CLAUDE.md match canonical brief)
echo -n "D65 agent briefing sync lock... "
if [[ -x "$SP/surfaces/verify/d65-agent-briefing-sync-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d65-agent-briefing-sync-lock.sh"
else
  warn "agent briefing sync lock gate not present"
fi

# D66: MCP server parity gate (local agents vs MCPJungle copies)
echo -n "D66 MCP server parity gate... "
if [[ -x "$SP/surfaces/verify/d66-mcp-parity-gate.sh" ]]; then
  gate_script "$SP/surfaces/verify/d66-mcp-parity-gate.sh"
else
  warn "MCP parity gate not present"
fi

# D67: Capability map lock (map covers all capabilities in registry)
echo -n "D67 capability map lock... "
if [[ -x "$SP/surfaces/verify/d67-capability-map-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d67-capability-map-lock.sh"
else
  warn "capability map lock not present"
fi

echo
[[ "$FAIL" -eq 0 ]] && echo "DRIFT GATE: PASS" || echo "DRIFT GATE: FAIL"
exit "$FAIL"
