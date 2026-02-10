#!/usr/bin/env bash
#
# generate-scaffold.sh — Auto-generates SPINE_SCAFFOLD.md from live contracts
#
# Usage:
#   ./bin/generate-scaffold.sh > SPINE_SCAFFOLD.md
#
# Requirements: bash, grep, awk, wc, date
# No external dependencies (yq, python, etc.)
#
# set -eo pipefail

set -eo pipefail

# ═════════════════════════════════════════════════════════════════════════
# Paths & Config
# ═════════════════════════════════════════════════════════════════════════

SPINE_REPO="${1:-.}"
TIMESTAMP=$(date -u "+%Y-%m-%d")

# ═════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═════════════════════════════════════════════════════════════════════════

count_capabilities_by_namespace() {
    # Count capabilities in ops/capabilities.yaml by namespace (first component of name)
    # Format: namespace.subname -> count unique namespaces
    if [[ ! -f "$SPINE_REPO/ops/capabilities.yaml" ]]; then
        echo "0" && return
    fi

    grep -E '^\s+[a-z]+\.' "$SPINE_REPO/ops/capabilities.yaml" | \
        awk -F: '{print $1}' | \
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
        awk -F'.' '{print $1}' | \
        sort -u | \
        wc -l | \
        tr -d ' '
}

count_total_capabilities() {
    # Count total capability entries (lines matching "  name:")
    if [[ ! -f "$SPINE_REPO/ops/capabilities.yaml" ]]; then
        echo "0" && return
    fi

    grep -E '^  [a-z]+\.' "$SPINE_REPO/ops/capabilities.yaml" | wc -l | tr -d ' '
}

count_drift_gates() {
    # Count drift gate files: d*-*.sh in surfaces/verify/
    if [[ ! -d "$SPINE_REPO/surfaces/verify" ]]; then
        echo "0" && return
    fi

    find "$SPINE_REPO/surfaces/verify" -maxdepth 1 -name 'd[0-9]*-*.sh' -type f | wc -l | tr -d ' '
}

count_bindings() {
    # Count YAML binding files in ops/bindings/
    if [[ ! -d "$SPINE_REPO/ops/bindings" ]]; then
        echo "0" && return
    fi

    find "$SPINE_REPO/ops/bindings" -maxdepth 1 -name '*.yaml' -type f | wc -l | tr -d ' '
}

get_agents_md_preview() {
    # Extract key lines from AGENTS.md
    if [[ ! -f "$SPINE_REPO/AGENTS.md" ]]; then
        return
    fi

    # Get canonical path from AGENTS.md
    grep "Canonical runtime:" "$SPINE_REPO/AGENTS.md" | head -1 || echo "# (Canonical runtime info not found)"
}

# ═════════════════════════════════════════════════════════════════════════
# Collect Metrics
# ═════════════════════════════════════════════════════════════════════════

TOTAL_CAPS=$(count_total_capabilities)
NAMESPACES=$(count_capabilities_by_namespace)
DRIFT_GATES=$(count_drift_gates)
BINDING_FILES=$(count_bindings)

# ═════════════════════════════════════════════════════════════════════════
# Generate SPINE_SCAFFOLD.md
# ═════════════════════════════════════════════════════════════════════════

cat <<'SCAFFOLD_EOF'
```bash
#!/usr/bin/env bash
#
# ════════════════════════════════════════════════════════════════
# SPINE SCAFFOLD — AGENTIC-SPINE (SSOT)
# Paste this into any new model session (Claude Code / ChatGPT / etc).
SCAFFOLD_EOF

echo "# Last updated: $TIMESTAMP"

cat <<'SCAFFOLD_EOF'
# ════════════════════════════════════════════════════════════════
#
# GOAL (ONE SENTENCE):
# Build a regression-proof agentic core where any agent can enter,
# follow the same protocol, and never create drift or competing runtimes.
#
# ────────────────────────────────────────────────────────────────
# 0) AUTHORITY ORDER (NON-NEGOTIABLE)
# ────────────────────────────────────────────────────────────────
# 1) agentic-spine repo + gates  = TRUTH
# 2) receipts/ (RCAP-*/RS*)      = PROOF
# 3) chat output                  = IDEAS ONLY (never authoritative)
#
# If chat conflicts with repo contracts/gates: repo wins, chat is discarded.
#
# ────────────────────────────────────────────────────────────────
# 1) COORDINATES (LOCKED)
# ────────────────────────────────────────────────────────────────
# SPINE_REPO="$HOME/code/agentic-spine"
# WORKBENCH_REPO="$HOME/code/workbench"   # infrastructure docs + scripts
# LEGACY_REPO="$LEGACY_ROOT"             # LEGACY ONLY — NEVER RUNTIME
#
# Latest tag:     v0.1.24-spine-canon
# GitHub:         hypnotizedent/agentic-spine
#
# Canonical entrypoint:
#   ./bin/ops
#
# Canonical runtime:
#   mailroom/* + fswatch watcher (watches mailroom/inbox/queued)
#   Watcher managed by launchd: com.ronny.agent-inbox
#   Do not manually run hot-folder-watcher.sh; use launchd.
#
# NO HOME DRIFT ROOTS:
#   $HOME/<agent>, $HOME/runs, $HOME/log, $HOME/logs MUST NOT exist.
#   ($HOME/<agent> may be a symlink → mailroom/ only)
#
# ────────────────────────────────────────────────────────────────
# 2) IMMUTABLE CORE INVARIANTS
# ────────────────────────────────────────────────────────────────
# - No work happens outside the mailroom-governed runtime.
# - No results without receipts.
# - No new capability without ops cap allowlist.
# - No behavior change without fixtures + replay determinism.
# - If verify doesn't pass, it doesn't ship.
# - Secrets never appear in terminal output, receipts, logs, or chat.
#
# ────────────────────────────────────────────────────────────────
# 3) SESSION PROTOCOL (MUST FOLLOW)
# ────────────────────────────────────────────────────────────────
# VERIFY → PLAN → EXECUTE → RECEIPTS → CLOSEOUT
#
# FIRST ACTIONS (must pass or STOP):
#   cd "$SPINE_REPO"
#   ./bin/ops cap run spine.verify     # 50 drift gates (D1-D57)
#   ./bin/ops cap run spine.replay     # 5 fixture determinism checks
#   ./bin/ops cap run spine.status     # watcher + queue state
#
# If ANY fail: STOP. Fix spine core before doing any other work.
#
# ────────────────────────────────────────────────────────────────
# 4) CAPABILITY SURFACE (
SCAFFOLD_EOF

echo -n "$TOTAL_CAPS governed capabilities)"

cat <<'SCAFFOLD_EOF'
# ────────────────────────────────────────────────────────────────
# All privileged actions via: ./bin/ops cap run <name>
# Full list:                  ./bin/ops cap list
#
# SPINE HEALTH (5)
#   spine.verify             Drift gates (50 checks, D1-D57)
#   spine.replay             Replay determinism (5 fixtures)
#   spine.status             Watcher + queue status
#   spine.watcher.status     Canonical watcher status (launchd + PID + lock)
#   spine.watcher.restart    Restart launchd watcher [MUTATING]
#
# SECRETS (8) — Infisical-backed, no-leak guarantees
#   secrets.status           Configuration presence check
#   secrets.binding          Non-secret provider binding (SSOT)
#   secrets.auth.status      Auth presence (no values printed)
#   secrets.auth.load        Validate creds file, print source one-liner
#   secrets.projects.status  SSOT inventory vs live Infisical projects
#   secrets.inventory.status Read-only SSOT inventory (names + counts)
#   secrets.cli.status       Hash parity: canonical vs vendored agent scripts
#   secrets.exec             Inject secrets into a command [MUTATING]
#
# CLOUDFLARE (4) — requires secrets.binding + secrets.auth.status
#   cloudflare.status        Zones + DNS record counts
#   cloudflare.dns.status    DNS records per bound zone
#   cloudflare.tunnel.status Tunnel inventory + timestamps
#   cloudflare.inventory.sync Metadata vs live parity
#
# GITHUB (4) — requires secrets preconditions
#   github.status            Branch, HEAD, clean state, tags
#   github.queue.status      Open PR + issue counts
#   github.actions.status    Workflow run counts + latest conclusion
#   github.labels.status     Declared (.github/labels.yml) vs live parity
#
# SSH / NODES (2)
#   ssh.target.status        Connectivity for 11 declared targets
#   nodes.status             Alias for ssh.target.status
#
# DOCKER (1)
#   docker.compose.status    Per-stack compose status (read-only)
#
# SERVICES (1)
#   services.health.status   HTTP health probes for declared endpoints
#
# BACKUP (1)
#   backup.status            Inventory freshness + reason codes
#
# DOCS / EXTRACTION (3)
#   docs.status              Workbench docs extraction integrity
#   docs.lint                Spine docs hierarchy lint
#   infra.extraction.status  23 asset groups extraction coverage (%)
#
# MCP (1)
#   mcp.inventory.status     Workbench MCP inventory vs MCPJungle configs
#
# INFRASTRUCTURE / MONOLITH (5) — read-only exploration
#   infra.docker_ps          Running containers
#   infra.gh_issue           GitHub issue details
#   monolith.tree            Directory listing of ~/code
#   monolith.search          Ripgrep across ~/code
#   monolith.git_status      Git status of a repo
#
# BUDGET (1)
#   budget.check             Token budget vs receipt diagnostic
#
# ────────────────────────────────────────────────────────────────
# 5) DRIFT GATES (
SCAFFOLD_EOF

echo -n "$DRIFT_GATES active checks: D1-D65, with gaps)"

cat <<'SCAFFOLD_EOF'
# ────────────────────────────────────────────────────────────────
# D1  Top-level directory policy     D2  No runs/ trace
# D3  Entrypoint smoke               D4  Watcher launchd check
# D5  No legacy home agent coupling  D6  Receipts exist
# D7  Executables bounded             D8  No backup clutter
# D9  Receipt stamps                  D10 Logs under mailroom/
# D11 home agent symlink validation   D12 CORE_LOCK.md exists
# D13 API capability preconditions    D14 Cloudflare surface drift
# D15 GitHub Actions surface drift    D16 Docs quarantine
# D17 Root allowlist                  D18 Docker compose drift
# D19 Backup drift                    D22 Nodes drift
# D23 Health drift                    D24 GitHub labels drift
# D27 Fact duplication lock           D28 Archive runway lock
# D29 Active entrypoint lock          D30 Active config lock
# D31 Home output sink lock           D33 Extraction pause lock
# D34 Loop ledger integrity           D35 Infra relocation parity
# D36 Legacy exception hygiene        D38 Extraction hygiene
# D40 Maker tools drift               D41 Hidden-root governance
# D42 Code path case lock             D43 Secrets namespace lock
# D44 CLI tools discovery             D45 Naming consistency
# D47 Brain surface path lock         D48 Codex worktree hygiene
# D49 Agent discovery lock            D50 Gitea CI workflow lock
# D51 Caddy proto lock                D52 UDR6 gateway assertion
# D53 Change pack integrity           D54 SSOT IP parity lock
# D55 Secrets runtime readiness       D56 Agent entry surface lock
# D57 Infra identity cohesion lock    D58 SSOT freshness lock
# D59 Cross-registry completeness     D60 Deprecation sweeper
# D61 Session loop traceability       D62 Git remote parity lock
# D63 Capabilities metadata lock      D64 Git remote authority warn
# D65 Agent briefing sync lock
#
# ────────────────────────────────────────────────────────────────
# 6) BINDINGS (ops/bindings/)
# ────────────────────────────────────────────────────────────────
#
SCAFFOLD_EOF

echo "# $BINDING_FILES YAML binding files including:"

cat <<'SCAFFOLD_EOF'
# secrets.binding.yaml         Infisical connection
# secrets.inventory.yaml       Infisical projects catalog
# cloudflare.inventory.yaml    Zones + tunnel
# docker.compose.targets.yaml  Hosts + stacks
# ssh.targets.yaml             SSH targets (shop + home)
# services.health.yaml         HTTP health endpoints
# backup.inventory.yaml        VM backup targets
# extraction.mode.yaml         Extraction pause/active state
# operational.gaps.yaml        Tracked operational gaps
# cross-repo.authority.yaml    Spine vs workbench ownership
# agents.registry.yaml         Domain agent registry
# (see ops/bindings/ for full list)
#
# ────────────────────────────────────────────────────────────────
# 7) OPS CLI SURFACE (./bin/ops)
# ────────────────────────────────────────────────────────────────
# ops cap <cmd>        Governed capabilities (list, run, show)
# ops run [opts]       Enqueue work into mailroom
# ops loops <cmd>      Open Loop Engine (list, collect, close, summary)
# ops start <issue>    Per-issue worktree + session docs
# ops preflight        Governance banner + service registry hints
# ops lane <name>      Lane header (builder|runner|clerk)
# ops verify           Health-check declared services
# ops ready            Spine gates + secrets checks (API preflight)
# ops pr [...args]     Stage/commit/push + open PR
# ops close [issue]    Verify, confirm merge, update state, close issue
# ops ai [--bundle X]  Bundle governance docs for AI agents
#
# ────────────────────────────────────────────────────────────────
# 8) REPO STRUCTURE
# ────────────────────────────────────────────────────────────────
# agentic-spine/
# ├── bin/              Entrypoint (ops dispatcher)
# ├── docs/             Governance (core/, governance/, legacy/)
# │   ├── core/         CAPABILITIES_OVERVIEW, CORE_LOCK, STACK_ALIGNMENT
# │   └── governance/   SSOT_REGISTRY.yaml (32 entries), SSOTs, policies
# ├── fixtures/         Replay determinism (5 event fixtures + baselines)
# ├── mailroom/         Runtime (inbox/, outbox/, logs/, state/)
# │   └── state/        ledger.csv, loop-scopes/, locks/
# ├── ops/              Commands, plugins, bindings, runtime, tools
# │   ├── bindings/     28 YAML binding files
# │   ├── capabilities.yaml  Capability registry (145 entries)
# │   ├── commands/     CLI subcommands
# │   ├── plugins/      Surface plugins (cloudflare, github, secrets, ...)
# │   ├── runtime/      Inbox processor, watcher
# │   └── tools/        Canonical agent scripts
# ├── receipts/         Audit trail (sessions/, audits/, contract)
# └── surfaces/         Drift gates + verification scripts
#     └── verify/       drift-gate.sh v2.5 + per-surface gates (D1-D57)
#
# ────────────────────────────────────────────────────────────────
# 9) WHAT THE MODEL IS ALLOWED TO DO
# ────────────────────────────────────────────────────────────────
# - Propose bounded deltas (diff-shaped)
# - Add/modify capabilities only via ops cap allowlist
# - Define fixtures + expected outputs
# - Improve gates to prevent regression
# - Interpret receipts/outbox/ledger to derive next actions
# - Run any read-only capability without approval
# - Run mutating capabilities only with operator approval
#
# ────────────────────────────────────────────────────────────────
# 10) WHAT THE MODEL MUST NOT DO
# ────────────────────────────────────────────────────────────────
# - No second runtime, queue, or receipt system (ever)
# - No renaming core dirs (mailroom/, receipts/, surfaces/verify/)
# - No "manual receipts" as proof (proof = watcher+ops produced only)
# - No promoting legacy repos to runtime
# - No writing secrets into chat, git, receipts, or logs
# - No "one-off" shell commands that change infra outside capabilities
# - No alternate runtimes, mailrooms, receipts, or HOME drift roots
#
# ────────────────────────────────────────────────────────────────
# 11) WORK RULES
# ────────────────────────────────────────────────────────────────
# - NO OPEN LOOPS = NO WORK → ./bin/ops loops list --open
# - If uncertain: next step is READ-ONLY evidence command, not guesses
# - One objective per session
# - Always end with closeout: what changed + which receipts prove it
# - One bug. Traced. Fixed. Verified. Next.
#
# ════════════════════════════════════════════════════════════════
# END SPINE SCAFFOLD
# ════════════════════════════════════════════════════════════════
```
SCAFFOLD_EOF
