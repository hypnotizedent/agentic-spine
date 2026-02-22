---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
verification_method: live-system-inspection
scope: workstation-infrastructure
github_issue: "#625"
---

# MACBOOK SSOT

> **This is the SINGLE SOURCE OF TRUTH for the MacBook workstation.**
>
> Covers: Hardware specs, local services, RAG stack, developer tooling, and verification.
> For device identity and Tailscale config, see [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md).
>
> **Last Verified:** February 13, 2026

---

## Quick Reference

| Item | Value |
|------|-------|
| Tailscale IP | 100.85.186.7 |
| Hostname | macbook |
| Model | MacBook Pro M4 Max (Mac16,6) |
| RAG API | http://100.71.17.29:3002 (remote: ai-consolidation VM 207) |
| Ollama | http://localhost:11434 |

---

## Hardware Specifications

| Component | Specification | Verified |
|-----------|---------------|----------|
| **Model** | MacBook Pro (Mac16,6) | 2026-02-05 |
| **Model Number** | Z1FD000AJLL/A | 2026-02-05 |
| **Serial** | MFJW7N645G | 2026-02-05 |
| **Chip** | Apple M4 Max | 2026-02-05 |
| **CPU Cores** | 16 (12 performance + 4 efficiency) | 2026-02-05 |
| **Memory** | 48GB Unified | 2026-02-05 |
| **Storage** | 926GB SSD (11GB used, 15GB available system) | 2026-02-05 |
| **OS** | macOS Sequoia 15.x | - |
| **Firmware** | 13822.61.10 | 2026-02-05 |

### Network Configuration

| Interface | IP | Notes |
|-----------|-----|-------|
| Tailscale | 100.85.186.7 | Primary access method |
| Local | Dynamic | Depends on network |
| Docker | 172.17.0.0/16 | Docker Desktop bridge |

---

## Workstation Services Matrix

### Docker Containers (Docker Desktop)

| Container | Image | Status | Port | Purpose |
|-----------|-------|--------|------|---------|
| anythingllm | mintplexlabs/anythingllm | Stopped (migrated to `ai-consolidation`) | 3002 | RAG interface |
| qdrant | qdrant/qdrant | Stopped (migrated to `ai-consolidation`) | 6333-6334 | Vector database |
| files-api | files-api-files-api | Up (unhealthy) | 3500 | Local dev API |
| files-api-postgres | postgres:15-alpine | Up (healthy) | 5432 | Local dev DB |
| minio | minio/minio:latest | Created (stopped) | - | Object storage (dev) |
| github-mcp-server | ghcr.io/github/github-mcp-server | Up | - | MCP GitHub tool |

**Health Summary:**
- Healthy: 1 (files-api-postgres)
- Unhealthy: 1 (files-api - needs investigation)
- Stopped: 3 (anythingllm, qdrant, minio)

### Native Services (Homebrew)

| Service | Status | Port | Purpose |
|---------|--------|------|---------|
| ollama | Started | 11434 | LLM inference (embeddings, chat) |
| cloudflared | None | - | Available but not running |
| postgresql@14 | None | - | Available but not running |
| unbound | None | - | Available but not running |

### RAG Stack

| Component | Type | Port | Health Check |
|-----------|------|------|--------------|
| Ollama | Native (Homebrew) | 11434 | `curl http://localhost:11434/api/tags` |
| AnythingLLM | Remote (VM 207) | 3002 | `curl http://100.71.17.29:3002/api/ping` |
| Qdrant | Remote (VM 207) | 6333 | `curl http://100.71.17.29:6333/healthz` |

**Storage Paths:**
- AnythingLLM (VM 207): `/opt/stacks/ai-consolidation/anythingllm_storage/`
- Qdrant (VM 207): `/opt/stacks/ai-consolidation/qdrant_storage/`

---

## Developer Tooling

### CLI Tools

| Tool | Purpose | Config Location |
|------|---------|-----------------|
| Claude Code | AI-assisted development | `~/.claude/` |
| Ollama | Local LLM inference | `~/.ollama/` |
| Docker Desktop | Container runtime | `~/.docker/` |
| Homebrew | Package manager | `/opt/homebrew/` |

### Code Repositories

| Repository | Path | Purpose |
|------------|------|---------|
| agentic-spine | `~/code/agentic-spine/` | Spine runtime (this repo) |
| workbench | `~/code/workbench/` | Workbench monolith |
| mint-modules | `~/code/mint-modules/` | Mint OS modules |

### SSH Configuration

| Host | User | Key | Notes |
|------|------|-----|-------|
| docker-host | docker-host | ~/.ssh/id_ed25519 | VM 200 |
| proxmox-home | root | ~/.ssh/id_ed25519 | Proxmox home (Beelink) |
| pve | root | ~/.ssh/id_ed25519 | Proxmox shop |
| nas | ronadmin | ~/.ssh/id_ed25519 | Synology NAS 918+ |
| automation-stack | ubuntu | ~/.ssh/id_ed25519 | VM 202 |
| infra-core | ubuntu | ~/.ssh/id_ed25519 | VM 204 |
| observability | ubuntu | ~/.ssh/id_ed25519 | VM 205 |
| dev-tools | ubuntu | ~/.ssh/id_ed25519 | VM 206 |
| ai-consolidation | ubuntu | ~/.ssh/id_ed25519 | VM 207 |
| download-stack | ubuntu | ~/.ssh/id_ed25519 | VM 209 |
| streaming-stack | ubuntu | ~/.ssh/id_ed25519 | VM 210 |
| vault | root | ~/.ssh/id_ed25519 | Vaultwarden (home VM 102) |
| ha | hassio | ~/.ssh/id_ed25519 | Home Assistant |
| pihole-home | root | ~/.ssh/id_ed25519 | Pi-hole DNS (home LXC 105) |
| immich | ubuntu | ~/.ssh/id_ed25519 | Photo server (shop VM 203) |

Soft-decommissioned history (not active SSH expectations): `download-home`.

**Config location:** `~/.ssh/config` + `~/code/workbench/dotfiles/ssh/config.d/`

### Hotkeys / Shortcuts

### Managed Configs

<!-- BEGIN AUTO CONFIGS -->
| Config | Path | Desired Source | Status |
|--------|------|----------------|--------|
| `hammerspoon` | `/Users/ronnyworks/.hammerspoon` | `/Users/ronnyworks/code/workbench/dotfiles/hammerspoon/.hammerspoon` | `ok` |
| `raycast-scripts` | `/Users/ronnyworks/.raycast-scripts` | `/Users/ronnyworks/code/workbench/dotfiles/raycast` | `ok` |
| `codex-config` | `/Users/ronnyworks/.codex/config.toml` | `/Users/ronnyworks/code/workbench/dotfiles/codex/config.toml` | `ok` |
| `opencode-config` | `/Users/ronnyworks/.config/opencode/opencode.json` | `/Users/ronnyworks/code/workbench/dotfiles/opencode/opencode.json` | `ok` |
| `opencode-instructions` | `/Users/ronnyworks/.config/opencode/OPENCODE.md` | `/Users/ronnyworks/code/workbench/dotfiles/opencode/OPENCODE.md` | `ok` |
| `opencode-omo-config` | `/Users/ronnyworks/.config/opencode/oh-my-opencode.json` | `/Users/ronnyworks/code/workbench/dotfiles/opencode/oh-my-opencode.json` | `ok` |
| `opencode-commands` | `/Users/ronnyworks/.config/opencode/commands` | `/Users/ronnyworks/code/workbench/dotfiles/opencode/commands` | `ok` |
<!-- END AUTO CONFIGS -->

#### Hammerspoon

<!-- BEGIN AUTO HOTKEYS -->
| Hotkey | Action | Source |
|--------|--------|--------|
| **Ctrl+Shift+L** | Launch Codex — SPINE-CONTROL-01 (solo, no LOOP_ID prompt) | `~/.hammerspoon/` |
| **Ctrl+Shift+A** | Attach Orchestrator C (Codex) to LOOP_ID | `~/.hammerspoon/` |
| **Ctrl+Shift+S** | Launch Claude — SPINE-AUDIT-01 (solo) | `~/.hammerspoon/` |
| **Ctrl+Shift+T** | Enqueue a mailroom task (optional prompt) + show watcher status | `~/.hammerspoon/` |
| **Ctrl+Shift+C** | Launch Codex — DOMAIN-HA-01 (solo) | `~/.hammerspoon/` |
| **Ctrl+Shift+O** | Launch OpenCode — DEPLOY-MINT-01 (solo) | `~/.hammerspoon/` |
| **Ctrl+Shift+E** | Closeout prompt → clipboard | `~/.hammerspoon/` |
| **Ctrl+Shift+P** | Native worker picker (hs.chooser from terminal.role.contract.yaml) | `~/.hammerspoon/` |
<!-- END AUTO HOTKEYS -->

#### Raycast

<!-- BEGIN AUTO RAYCAST -->
| Tool | Script | Command |
|------|--------|---------|
| **Raycast** | `Claude Code` | `SPINE_HOTKEY_ORCH_MODE=capability SPINE_HOTKEY_ALLOW_FALLBACK=0 /Users/ronnyworks/code/workbench/scripts/root/spine_terminal_entry.sh --role solo --tool claude` |
| **Raycast** | `Codex Full Auto` | `SPINE_HOTKEY_ORCH_MODE=capability SPINE_HOTKEY_ALLOW_FALLBACK=0 /Users/ronnyworks/code/workbench/scripts/root/spine_terminal_entry.sh --role solo --tool codex` |
| **Raycast** | `OpenCode` | `SPINE_HOTKEY_ORCH_MODE=capability SPINE_HOTKEY_ALLOW_FALLBACK=0 /Users/ronnyworks/code/workbench/scripts/root/spine_terminal_entry.sh --role solo --tool opencode` |
| **Raycast** | `Spine Start Routine` | `SPINE_HOTKEY_ORCH_MODE=capability SPINE_HOTKEY_ALLOW_FALLBACK=0 /Users/ronnyworks/code/workbench/scripts/root/spine_terminal_entry.sh --role solo --tool verify` |
<!-- END AUTO RAYCAST -->

#### OpenCode Command Surface

| Command | Contract | Source |
|---------|----------|--------|
| `/ralph-loop` | Governed autonomous loop shim | `~/.config/opencode/commands/ralph-loop.md` |
| `/ralphloop` | Alias shim for `/ralph-loop` | `~/.config/opencode/commands/ralphloop.md` |
| `/ulw` | Governed ultrawork loop shim | `~/.config/opencode/commands/ulw.md` |

#### Other

| Tool | Hotkey / Script | Action | Source |
|------|-----------------|--------|--------|
| **Espanso** | `;sup`, `;ctx`, `;issue`, `;ask` | Text expansion snippets | `~/.config/espanso/match/` |
| **Maccy** | `Cmd+Shift+V` | Clipboard history | macOS app settings |
| **Stream Deck** | (physical) | Home Assistant + infrastructure buttons | physical audit required |

**Config Locations:**
- Hammerspoon: `~/.hammerspoon/`
- Raycast scripts: `dotfiles/raycast/` → `~/.raycast-scripts`
- Espanso: `~/.config/espanso/match/claude.yml`

---

## Backup Configuration

### Time Machine

| Target | Status | Notes |
|--------|--------|-------|
| Local disk | Active | Primary backup |

### Cloud Sync

| Service | Directories | Status |
|---------|-------------|--------|
| iCloud | Documents, Desktop | Active |
| Git remotes | All repos | Manual push |

### Critical Paths (Not Backed Up Automatically)

| Path | Contents | Backup Method |
|------|----------|---------------|
| `~/.claude/` | Claude Code config | Manual / git |
| `~/.ssh/` | SSH keys | Manual |
| (none) | RAG data is remote on VM 207 (`/opt/stacks/ai-consolidation/*`) | See VM backup policy |

---

## Drift Gates (MacBook Scope)

The following spine drift gates enforce MacBook + workbench invariants:

| Gate | Name | Scope |
|------|------|-------|
| D72 | MacBook hotkey SSOT lock | Raycast/Hammerspoon launchers match MACBOOK_SSOT |
| D73 | OpenCode governed entry lock | OpenCode config + launcher path + model contract |
| D74 | Billing/provider lane lock | z.ai default, LaunchAgent template invariants |
| D76 | Home-surface hygiene lock | Plaintext secrets, forbidden roots, uppercase paths at ~/ |
| D77 | Workbench contract lock | Plist allowlist, runtime-dir ban, bare tool-exec detection |
| D78 | Workbench path lock | Uppercase code-dir + legacy-repo-name drift in active surfaces |
| D79 | Workbench script allowlist lock | Governed script surface vs spine binding |
| D80 | Workbench authority-trace lock | Legacy naming violations via authority-trace --strict |

## Verification Commands

```bash
# MacBook drift invariants (host + workbench alignment)
cd ~/code/agentic-spine
./bin/ops cap run host.macbook.drift.check

# Identity check
tailscale ip -4
# Expected: 100.85.186.7

# Docker health
docker ps --format '{{.Names}}: {{.Status}}'

# RAG API (remote)
# curl -s http://100.71.17.29:3002/api/ping
# curl -s http://localhost:11434/api/tags | jq '.models | length'
# curl -s http://100.71.17.29:6333/healthz

# Homebrew services
brew services list

# Disk space
df -h /
```

---

## Scheduled Tasks (launchd)

**LaunchAgents** (`~/Library/LaunchAgents/`):

| Plist | Schedule | Script | Purpose | Status |
|-------|----------|--------|---------|--------|
| `homebrew.mxcl.ollama.plist` | On login | — | Ollama auto-start | ACTIVE |
| `com.ronny.vzdump-tier1-offsite.plist` | Sun 03:30 | `sync-vzdump-tier1-offsite.sh` | Tier 1 VM offsite sync | ACTIVE |
| `com.ronny.macos-sync-critical.plist` | Sun 04:00 | `macos-sync-critical.sh` | MacBook critical folders | ACTIVE |
| `com.ronny.ha-offsite-sync.plist` | Sun 04:30 | `sync-ha-offsite.sh` | Home Assistant offsite (vzdump replaced) | RETIRED |
| `com.ronny.secrets-verify.plist` | Daily 08:00 | `secrets_verify.sh` | Validate secrets inventory | ACTIVE |
| `com.ronny.monitoring-verify.plist` | Every 15m | `monitoring_verify.sh` | Validate monitoring | ACTIVE |
| `com.ronnyworks.minio-mount.plist` | On login | rclone nfsmount | Mount MinIO via rclone | ACTIVE |
| `com.ronny.agent-inbox.plist` | On login | `hot-folder-watcher.sh` | Spine mailroom watcher (fswatch) | ACTIVE |
| `com.ronny.docker-tunnel.plist` | On login | SSH -L 2375 | Docker tunnel to docker-host | ACTIVE |
| `com.ronny.ha-baseline-refresh.plist` | Sun 05:00 | `ha-baseline-refresh.sh` | Weekly HA SSOT baseline refresh | ACTIVE |
| `com.ronny.policy-autotune-weekly.plist` | Mon 09:10 | `policy-autotune-weekly.sh` | Weekly policy autotune: observe -> auto-propose (submit only) -> human apply | STAGED |
| `com.ronny.spine-daily-briefing.plist` | Daily 08:00 | `spine-daily-briefing.sh` | Daily spine situational briefing artifact | ACTIVE |
| `com.ronny.spine-briefing-email-daily.plist` | Daily 08:05 | `spine-briefing-email-daily.sh` | Route briefing summary into communications send pipeline | ACTIVE |
| `com.ronny.slo-evidence-daily.plist` | Daily 23:59 | `slo-evidence-daily.sh` | Daily SLO evidence capture | ACTIVE |
| `com.ronny.n8n-snapshot-daily.plist` | Daily 03:00 | `n8n-snapshot-daily.sh` | Daily n8n workflow snapshot | ACTIVE |
| `com.ronny.alerting-probe-cycle.plist` | Every 15m | `alerting-probe-cycle.sh` | Continuous alert probe + dispatch cycle | ACTIVE |
| `com.ronny.mcp-runtime-anti-drift-cycle.plist` | Every 30m | `mcp-runtime-anti-drift-cycle.sh` | Scheduled anti-drift checks for MCP runtime parity + D148 core verify enforcement | ACTIVE |
| `com.ronny.immich-reconcile-weekly.plist` | Sun 02:00 | `immich-reconcile-weekly.sh` | Weekly duplicate scan for immich reconciliation | ACTIVE |
| `com.ronny.finance-action-queue-monthly.plist` | Day 1 09:00 | `finance-action-queue-monthly.sh` | Monthly finance compliance/action queue generation | ACTIVE |
| `com.ronny.streamdeck.ha.plist` | On login | `streamdeck_ha_controller.py` | Stream Deck HA button controller | ACTIVE |
| `works.ronny.smb-paperless.plist` | On login | osascript SMB mount | Paperless SMB share on docker-host | ACTIVE |

**Other auto-start:**
- Docker Desktop: Auto-start on login
- Time Machine: Hourly (system managed)

**Crontab:** None (no crontab for ronnyworks). All scheduling via launchd.

**Source:** Spine runtime launchd templates in `ops/runtime/launchd/` + live launchctl verification, verified 2026-02-21.

---

## Known Issues

| Issue | Status | Notes |
|-------|--------|-------|
| files-api unhealthy | OPEN | Container running but health check failing |
| minio not started | INFO | Created but never launched |
| RAG paused for foundational work | INFO | Will resume after spine stabilization |

---

## Open Loops

No open baseline loops. `OL_MACBOOK_BASELINE_FINISH` closed 2026-02-07.

**Previously unverified items — resolved 2026-02-07:**
- Hammerspoon: Hotkey bindings are centralized in workbench and auto-synced into this SSOT (see AUTO blocks above).
- Stream Deck: HA controller runs via `com.ronny.streamdeck.ha.plist` (Python script using Infisical for `HA_API_TOKEN`). Physical button layout is managed in Stream Deck app — not scriptable/auditable from CLI.

---

## Evidence / Receipts

### 2026-02-05 Live System Inspection

| Item | Value |
|------|-------|
| Method | `system_profiler SPHardwareDataType`, `docker ps`, `brew services list` |
| Result | Hardware specs verified, 7 containers (5 running, 2 stopped) |

### 2026-02-07 Baseline Completion Audit

| Item | Value |
|------|-------|
| Method | `launchctl list`, `plutil -p`, `crontab -l`, `cat ~/.hammerspoon/init.lua` |
| Result | 11 custom LaunchAgents verified (4 newly documented), no crontab, Hammerspoon hotkeys verified and SSOT auto-sync wired |
| Loop closed | `OL_MACBOOK_BASELINE_FINISH` |

### Related Capability Receipts

| Capability | Receipt | Status |
|------------|---------|--------|
| nodes.status | `RCAP-20260205-155125__nodes.status__Rzvvh72648` | FAIL (media-stack deferred) |
| services.health.status | `RCAP-20260205-155156__services.health.status__R5omv73468` | 5/5 OK |

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) | Device naming, Tailscale IPs, tier classification |
| [SHOP_SERVER_SSOT.md](SHOP_SERVER_SSOT.md) | Shop infrastructure (VMs this connects to) |
| [MINILAB_SSOT.md](MINILAB_SSOT.md) | Home infrastructure |
| [SSOT_UPDATE_TEMPLATE.md](SSOT_UPDATE_TEMPLATE.md) | How to update this document |
