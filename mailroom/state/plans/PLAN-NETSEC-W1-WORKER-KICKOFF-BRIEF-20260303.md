# PLAN-NETSEC-W1-WORKER-KICKOFF-BRIEF-20260303

> Canonical worker kickoff brief for Network Security Wave 1.
> Lane: mailroom planning (design-only).
> Authority anchor: `LOOP-NETWORK-SECURITY-OPS-WORKER-SPEC-20260303`.

## Containment Contract

This kickoff brief is intentionally stored in:

- `mailroom/state/plans/`

so planning artifacts, order locks, and packet dependencies remain in one governed container.

No implementation actions are authorized from this brief alone.

## Primary Artifacts

1. Program plan:
   - `mailroom/state/plans/PLAN-NETWORK-SECURITY-OPS-WORKER-20260303.md`
2. Order lock:
   - `mailroom/state/plans/PLAN-NETSEC-W1-ORDER-LOCK-20260303.md`
3. Loop scopes:
   - `mailroom/state/loop-scopes/LOOP-NETSEC-W1-DNS-AUTHORITY-STACK-20260303.scope.md`
   - `mailroom/state/loop-scopes/LOOP-NETSEC-W1-VLAN-SEGMENTATION-FIREWALL-20260303.scope.md`
   - `mailroom/state/loop-scopes/LOOP-NETSEC-W1-THREAT-DETECTION-OBSERVATION-20260303.scope.md`
   - `mailroom/state/loop-scopes/LOOP-NETSEC-W1-STACK-KNOWLEDGE-BASE-20260303.scope.md`
4. Source material:
   - `~/Desktop/mint-network-security-plan.docx` (9-phase rollout reference)

## Locked Sequence

1. `LOOP-NETSEC-W1-DNS-AUTHORITY-STACK-20260303`
2. `LOOP-NETSEC-W1-VLAN-SEGMENTATION-FIREWALL-20260303`
3. `LOOP-NETSEC-W1-THREAT-DETECTION-OBSERVATION-20260303`
4. `LOOP-NETSEC-W1-STACK-KNOWLEDGE-BASE-20260303` (independent)

## Gap Inventory

- DNS authority packet: `GAP-OP-1449..1453` (Unbound, DoH, local DNS, bypass prevention, Pi-hole gate)
- VLAN/firewall packet: `GAP-OP-1030` (absorbed), `GAP-OP-1108` (absorbed), `GAP-OP-1454..1456` (topology, firewall baseline, mDNS)
- Threat detection packet: `GAP-OP-1457..1459` (IDS tuning, CrowdSec, honeypot)
- Stack discovery packet: `GAP-OP-1460` (knowledge base)

## Worker Guardrails

1. No live network changes without explicit operator approval per wave.
2. DNS changes must be validated with `dig` and `nslookup` before DHCP commit.
3. VLAN deployment requires physical home site access.
4. IDS → IPS transition requires 48-hour soak in IDS-only mode.
5. Honeypot must be DMZ-isolated before exposure.
6. Stack discovery pipeline must not expose credentials or private data.

## Promotion Preflight (Future Worker)

```bash
./bin/ops cap run session.start
./bin/ops cap run planning.plans.list -- --owner @ronny --horizon later
./bin/ops cap run verify.run -- fast
./bin/ops cap run ssh.target.status
./bin/ops cap run network.shop.audit.status
```

## Drift Prevention

If execution artifacts appear outside the above loop/plan/gap set, file a gap before proceeding.

## Key Dependencies

1. `LOOP-HOME-CANONICAL-REALIGNMENT-20260302` — home site visit required for VLAN deployment.
2. Observability stack (VM 205) — must be healthy for Cowrie log pipeline and CrowdSec dashboards.
3. Cloudflare API access — required for CrowdSec bouncer integration.
4. `mint-network-security-plan.docx` — canonical source for phase configs (Unbound, Suricata rules, Cowrie compose).
