---
id: LOOP-BRIDGE-PUBLIC-HTTPS-20260215
status: closed
opened: 2026-02-15
owner: "@ronny"
gaps:
  - GAP-OP-445
  - GAP-OP-446
  - GAP-OP-447
  - GAP-OP-448
---

# LOOP: Mailroom Bridge Public HTTPS Rollout

## Objective

Enable a secure public HTTPS path for mailroom bridge access so hosted mobile runtimes (Claude iOS/claude.ai) can reach spine without tailnet DNS dependency.

## Problem Statement

Current bridge access is tailnet-only (`http://macbook.taile9480.ts.net`), which fails from hosted runtimes even when the skill and local spine are healthy.

## Deliverables

1. Canonical public bridge endpoint contract (URL + auth + fallback order).
2. Bridge status surface that reports both public and tailnet reachability.
3. Governance docs updated for Cloudflare Tunnel public path and security model.
4. Skill dual-URL strategy: public HTTPS primary, tailnet secondary, offline final fallback.

## Acceptance Criteria

1. Public URL health endpoint responds from hosted runtime.
2. Auth-required endpoints (`/loops/open`, `/rag/ask`, `/cap/run`) remain token-gated.
3. Skill routes to public URL first and no longer blocks on tailnet DNS failure.
4. `spine.verify` remains green after rollout.

## Constraints

1. Keep bridge listener bound to localhost.
2. No anonymous access to non-health endpoints.
3. Public exposure must preserve governed bridge contract and receipt behavior.
