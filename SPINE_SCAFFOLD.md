```bash
#!/usr/bin/env bash
#
# ════════════════════════════════════════════════════════════════
# SPINE SCAFFOLD — AGENTIC-SPINE (SSOT)
# Paste this into any new model session (Claude Code / ChatGPT / etc).
# Last updated: 2026-02-10
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
# LEGACY_REPO="$HOME/ronny-ops"           # LEGACY ONLY — NEVER RUNTIME
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
#   ~/agent, ~/runs, ~/log, ~/logs MUST NOT exist.
#   (~/agent may be a symlink → mailroom/ only)
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
# 4) CAPABILITY SURFACE (145 governed capabilities)
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
# 5) DRIFT GATES (50 active checks: D1-D57, with gaps)
# ────────────────────────────────────────────────────────────────
# D1  Top-level directory policy     D2  No runs/ trace
# D3  Entrypoint smoke               D4  Watcher launchd check
# D5  No legacy ~/agent coupling     D6  Receipts exist
# D7  Executables bounded             D8  No backup clutter
# D9  Receipt stamps                  D10 Logs under mailroom/
# D11 ~/agent symlink validation      D12 CORE_LOCK.md exists
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
# D57 Infra identity cohesion lock
#
# ────────────────────────────────────────────────────────────────
# 6) BINDINGS (ops/bindings/)
# ────────────────────────────────────────────────────────────────
# 28 YAML binding files including:
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
# - No promoting ronny-ops to runtime
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
