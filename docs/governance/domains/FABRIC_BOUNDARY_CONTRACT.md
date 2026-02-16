---
status: authoritative
owner: "@ronny"
last_verified: "2026-02-16"
scope: fabric-domain-boundary
---

# Fabric Boundary Contract

Spine is the fabric control plane. Domain behavior/docs are externalized to workbench.

Canonical bindings:
- `ops/bindings/fabric.boundary.contract.yaml`
- `ops/bindings/domain.docs.routes.yaml`

Enforcement gates:
- `surfaces/verify/d121-fabric-boundary-lock.sh`
- `surfaces/verify/d122-domain-doc-route-lock.sh`
- `surfaces/verify/d123-strict-migration-policy-lock.sh`
