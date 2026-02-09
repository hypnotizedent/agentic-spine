---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-09
scope: portability-assumptions
---

# Portability Assumptions

Purpose: make the spine portable by documenting the environment assumptions it makes about the controller machine, filesystem layout, tools, and network access.

This doc exists so failures look like "assumption violated" instead of "mystery breakage".

## Invariants (Spine Runtime)

- **Runtime root (authoritative):** `SPINE_REPO=$HOME/code/agentic-spine`
  - Mailroom: `$SPINE_REPO/mailroom/`
  - Receipts: `$SPINE_REPO/receipts/sessions/`
- **Code root (worktree-safe):** `SPINE_CODE=<where bin/ops lives>`
  - `ops cap run` executes capabilities from `SPINE_CODE`
  - Drift gates must pass even if `SPINE_CODE` is a git worktree
- **External repos are never runtime dependencies:**
  - Workbench is **tooling/reference only** (see `docs/governance/WORKBENCH_TOOLING_INDEX.md`)
  - ronny-ops is **deprecated junkyard** (read-only harvesting only)

## Required Paths

Expected layout under `$HOME/code/`:

- `~/code/agentic-spine` (governance + runtime)
- `~/code/workbench` (tooling + product surface)
- `~/code/mint-modules` (product modules)

Expected local credentials/config:

- `~/.config/infisical/credentials` (preferred; allows rotated values to override shell env)
- `~/Library/LaunchAgents/com.ronny.agent-inbox.plist` (mailroom watcher entrypoint on macOS)

## Required Tools (Controller Machine)

The controller machine (MacBook) is assumed to have:

- `bash` (scripts are bash-first; assume POSIX-ish environment)
- `git`
- `jq`
- `yq` (mikefarah/yq; required for YAML parsing)
- `ssh` + `scp`
- `curl`
- `python3` (used for small reducer/inspection scripts)
- `docker` (for local checks only; most docker ops are remote)
- `infisical` CLI (secrets injection; required by `secrets.exec`)
- `launchctl` (mailroom watcher supervision on macOS)

## Network Assumptions

- **Tailscale is required** for consistent VM reachability.
  - `ops/bindings/ssh.targets.yaml` is the SSOT for target IPs/users.
  - Do not assume LAN reachability; assume Tailscale IPs are the default control plane.
- **SSH is the primary remote execution channel.**
  - Capabilities that operate on remote hosts must resolve hosts via spine bindings, not ad-hoc `~/.ssh/config` aliases.
- **DNS is not guaranteed.**
  - Some scripts may reference hostnames like `nas`; if resolution fails, use Tailscale IPs or update bindings/host resolution deliberately (with receipts).

## Platform Assumptions

- **Controller:** macOS (LaunchAgents + `launchctl` watcher model).
- **VMs:** Linux (Ubuntu-style), with Docker Engine + Docker Compose v2 available.
- **Hypervisor:** Proxmox exists in the estate, but the spine should not assume direct Proxmox API access unless a capability declares it.

## Known Portability Gotchas

- **Path case sensitivity:** `/code` vs `/Code` matters (D42 enforces).
- **Manual-approval capabilities prompt for stdin** (`read -p`). If running non-interactively, pipe `yes` explicitly.
- **Worktrees:** `SPINE_REPO` must remain the canonical runtime root. Only `SPINE_CODE` is allowed to vary via git worktrees (D48).
- **Secrets:** never print env values; run secret-bearing commands via `secrets.exec` so receipts stay safe.

