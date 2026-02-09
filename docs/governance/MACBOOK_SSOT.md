---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-07
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
> **Last Verified:** February 7, 2026

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
| pve | root | ~/.ssh/id_ed25519 | Proxmox shop |
| docker-host | docker-host | ~/.ssh/id_ed25519 | VM 200 |
| proxmox-home | root | ~/.ssh/id_ed25519 | Proxmox home |
| automation-stack | automation | ~/.ssh/id_ed25519 | VM 202 |

**Config location:** `~/.ssh/config` + `~/code/workbench/dotfiles/ssh/config.d/`

### Hotkeys / Shortcuts

#### Hammerspoon

<!-- BEGIN AUTO HOTKEYS -->
| Hotkey | Action | Source |
|--------|--------|--------|
| **Ctrl+Shift+S** | Start routine (receipted) + launch Claude | `~/.hammerspoon/` |
| **Ctrl+Shift+T** | Enqueue a mailroom task (optional prompt) + show watcher status | `~/.hammerspoon/` |
| **Ctrl+Shift+C** | Launch Codex (bypass approvals + sandbox) in spine workdir | `~/.hammerspoon/` |
| **Ctrl+Shift+O** | Launch OpenCode in spine workdir (force GLM 4.7) | `~/.hammerspoon/` |
| **Ctrl+Shift+E** | Closeout prompt → clipboard | `~/.hammerspoon/` |
<!-- END AUTO HOTKEYS -->

#### Raycast

<!-- BEGIN AUTO RAYCAST -->
| Tool | Script | Command |
|------|--------|---------|
| **Raycast** | `Claude Code` | `cd ~/code/agentic-spine && claude --dangerously-skip-permissions --add-dir ~/code/workbench` |
| **Raycast** | `Codex Full Auto` | `codex -C ~/code/agentic-spine --add-dir ~/code/workbench --dangerously-bypass-approvals-and-sandbox` |
| **Raycast** | `OpenCode` | `cd ~/code/agentic-spine && opencode -m zai-coding-plan/glm-4.7 .` |
| **Raycast** | `Spine Start Routine` | `cd ~/code/agentic-spine && ./bin/ops cap run spine.watcher.status && ./bin/ops cap run loops.status && ./bin/ops cap run spine.verify` |
<!-- END AUTO RAYCAST -->

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

## Verification Commands

```bash
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
| `com.ronny.ha-offsite-sync.plist` | Sun 04:30 | `sync-ha-offsite.sh` | Home Assistant offsite | ACTIVE |
| `com.ronny.secrets-verify.plist` | Daily 08:00 | `secrets_verify.sh` | Validate secrets inventory | ACTIVE |
| `com.ronny.monitoring-verify.plist` | Every 15m | `monitoring_verify.sh` | Validate monitoring | ACTIVE |
| `com.ronnyworks.minio-mount.plist` | On login | rclone nfsmount | Mount MinIO via rclone | ACTIVE |
| `com.ronny.agent-inbox.plist` | On login | `hot-folder-watcher.sh` | Spine mailroom watcher (fswatch) | ACTIVE |
| `com.ronny.docker-tunnel.plist` | On login | SSH -L 2375 | Docker tunnel to docker-host | ACTIVE |
| `com.ronny.streamdeck.ha.plist` | On login | `streamdeck_ha_controller.py` | Stream Deck HA button controller | ACTIVE |
| `works.ronny.smb-paperless.plist` | On login | osascript SMB mount | Paperless SMB share on docker-host | ACTIVE |

**Other auto-start:**
- Docker Desktop: Auto-start on login
- Time Machine: Hourly (system managed)

**Crontab:** None (no crontab for ronnyworks). All scheduling via launchd.

**Source:** External schedule inventory (workbench tooling via `WORKBENCH_TOOLING_INDEX.md`), verified 2026-02-05.

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
