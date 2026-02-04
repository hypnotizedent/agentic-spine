# Cloudflare Binding (SSOT)

> **Status:** authoritative
> **Last verified:** 2026-02-04

## Purpose
Make Cloudflare metadata (zones, tunnels, guardrails) a spine-native binding so agents never guess names or IDs.

## Location
`ops/bindings/cloudflare.inventory.yaml`

## What it contains
- `provider`, `api_url`, `project`, `environment`
- `zones[]` (name + optional zone ID)
- `tunnels[]` (name + optional tunnel ID)
- `guardrails` (record limits, watch intervals)

## Enforcement
1. Capabilities that hit Cloudflare APIs MUST declare the binding as a prerequisite (`requires: [secrets.binding, secrets.auth.status, secrets.projects.status]`).
2. Drift gate D24 (see `surfaces/verify/d24-cloudflare-drift.sh`) cross-checks this binding against live names.
3. Update this file whenever a zone/tunnel is added, removed, or renamed.
