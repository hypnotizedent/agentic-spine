---
loop_id: LOOP-NETWORK-SECURITY-OPS-WORKER-SPEC-20260303
created: 2026-03-03
status: active
owner: "@ronny"
scope: agentic-spine
objective: Capture a governed, executable specification for network security hardening across DNS authority, VLAN segmentation, threat detection, and stack discovery — design-only, no runtime implementation.
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
---

# Loop Scope: Network Security Ops Worker Spec

## Problem Statement

The spine has strong network inventory, SSH lifecycle, and Tailscale governance surfaces, but there is no dedicated contract bundle for network security operations that can:

1. Enforce DNS authority (recursive resolution via Unbound, DoH fallback, local DNS overrides).
2. Segment traffic via VLANs with inter-VLAN firewall rules and mDNS governance.
3. Detect and respond to threats via tuned IDS/IPS, CrowdSec, and honeypot observation.
4. Maintain a self-healing, queryable knowledge base of self-hosted tools and external resources for future product decisions.

Without this, network security remains ad-hoc UDR configuration, Pi-hole is not truly authoritative (no DNS bypass prevention), home network is flat (GAP-OP-1030), and no intrusion detection or collaborative threat intelligence exists.

## Deliverables

1. End-to-end execution plan artifact under `mailroom/state/plans/` covering DNS authority, VLAN architecture, threat detection, and stack discovery — with phased rollout aligned to the existing `mint-network-security-plan.docx`.
2. Contract pack specification including:
   - DNS authority contract (Unbound, DoH, local DNS, bypass prevention)
   - VLAN topology contract (subnet design, isolation rules, tagging strategy)
   - Firewall rule baseline contract (inter-VLAN rules, RFC1918 block pattern)
   - mDNS governance contract (reflection policy, cross-VLAN discovery)
   - Threat detection contract (IDS/IPS tuning, CrowdSec, honeypot isolation)
   - Stack discovery contract (source registry, refresh cadence, query interface)
3. Governance pack specification including:
   - Planned capability surface
   - Planned drift gates
   - Verify route and evidence expectations
   - Cross-domain ownership boundaries (infra/network/observability/cloudflare)
4. Connector matrix for existing network capabilities and adjacent domains.
5. Activation runbook with go/no-go checks and phased rollout gating.

## Acceptance Criteria

1. The plan is executable as written: each phase has entry conditions, outputs, and promotion gates.
2. DNS authority enforcement is concrete: Unbound config, Pi-hole upstream, firewall bypass prevention.
3. VLAN design aligns with existing UDR capabilities and absorbs GAP-OP-1030 and GAP-OP-1108.
4. Threat detection is layered: Suricata tuning → CrowdSec → Cowrie (with VLAN dependency).
5. Stack discovery is spine-native: sources.yaml SSOT, capability-driven refresh, agent-queryable.
6. Governance deltas are listed with target files and status labels (proposed, planned, active transition path).

## Constraints

1. No runtime implementation in this loop (no new plugin binaries, capabilities, drift scripts, or production schedulers).
2. No destructive network changes; design only.
3. Spec must align with existing spine governance: capability-first execution, receipts, loop/plan lifecycle, and role/runtime controls.
4. VLAN implementation is blocked on home site visit (LOOP-HOME-CANONICAL-REALIGNMENT-20260302).

## Phases

1. Step 0: Discovery and topology alignment (completed in-session via conversation + docx analysis).
2. Step 1: Spec capture in loop + plan artifacts (this loop).
3. Step 2: Deferred promotion to implementation loop(s) after operator approval.

## Evidence Paths

1. `mailroom/state/loop-scopes/LOOP-NETWORK-SECURITY-OPS-WORKER-SPEC-20260303.scope.md`
2. `mailroom/state/plans/PLAN-NETWORK-SECURITY-OPS-WORKER-20260303.md`
3. `mailroom/state/plans/index.yaml` (plan registration entry)
