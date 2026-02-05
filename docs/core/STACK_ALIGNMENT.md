# STACK_ALIGNMENT

> **Status:** authoritative
> **Last verified:** 2026-02-04

> **Purpose:** Spine agents understand stacks without needing to open the workbench monolith.
>
> This document summarizes the stack landscape so spine-native capabilities
> can reference stacks by ID and know what they contain.

---

## Stacks at a Glance

The canonical list lives in `docs/governance/STACK_REGISTRY.yaml`.
This document provides human-readable context for key stacks.

---

## automation-stack (Proxmox VM 202)

| Key | Value |
|-----|-------|
| stack_id | `automation-stack` |
| VM | Proxmox VM 202 |
| Services | n8n, Ollama, Open WebUI |
| Deploy | Manual on VM (not compose-managed via this repo) |
| Status | active |

**What it does:**
- **n8n** — Workflow automation (webhooks, scheduled jobs, integrations)
- **Ollama** — Local LLM inference
- **Open WebUI** — Chat frontend for Ollama models

**Spine relevance:**
This stack is not deployed via spine compose files. It is listed in STACK_REGISTRY for inventory
completeness. Agents should not attempt to manage it via `docker.compose.status`.

---

## dashy (inactive)

| Key | Value |
|-----|-------|
| stack_id | `dashy` |
| Path | `infrastructure/dashy` |
| Status | inactive |

Dashboard service. Currently not running. Compose file exists for reference only.

---

## storage / MinIO

| Key | Value |
|-----|-------|
| stack_id | `storage` |
| Path | `infrastructure/storage` |
| Status | active |

MinIO object storage. Used by Mint OS for artwork files, uploads, and backups.

**Known buckets** (from workbench INFRASTRUCTURE_MAP):
- `artwork` — artwork processing pipeline
- `uploads` — customer uploads
- `backups` — scheduled backup targets

Bucket definitions are managed in the workbench monolith (`~/Code/workbench`), not in the spine.
The spine only monitors storage health via `docker.compose.status`.

---

## How to Reference Stacks

When writing capabilities or documentation, reference stacks by `stack_id`:

```yaml
# In capability notes or bindings
stack: storage          # matches STACK_REGISTRY.yaml stack_id
stack: automation-stack # matches STACK_REGISTRY.yaml stack_id
```

Stack IDs are stable identifiers. Paths and compose files may change;
the `stack_id` in STACK_REGISTRY.yaml is the durable key.

---

## Workbench Infrastructure Reference

> **External Reference (Read-Only)**
>
> Workbench infrastructure docs are **not spine-governed**. For a centralized
> list of workbench entry points, see:
>
> → **[WORKBENCH_TOOLING_INDEX.md](../governance/WORKBENCH_TOOLING_INDEX.md)**
>
> Or query directly: `cd ~/Code/workbench && mint ask "question"`

---

## Cross-References

| Document | Relationship |
|----------|--------------|
| `docs/governance/STACK_REGISTRY.yaml` | Canonical machine-readable stack list |
| `ops/capabilities.yaml` (`docker.compose.status`) | Runtime compose health per stack |
| `docs/core/DEVICE_IDENTITY_SSOT.md` | Device/VM identity (where stacks run) |
| `docs/core/AGENTIC_GAP_MAP.md` | Extraction coverage tracking (23 asset groups) |
| `docs/governance/WORKBENCH_TOOLING_INDEX.md` | External tooling references (read-only) |
