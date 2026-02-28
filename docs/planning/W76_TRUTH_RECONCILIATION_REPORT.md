# W76 Truth Reconciliation Report

wave_id: W76_HOLISTIC_CANONICAL_CLOSURE_20260228
branch: codex/w76-holistic-canonical-closure-20260228

| claim_id | claim | observed_truth | action | evidence |
|---|---|---|---|---|
| W76-T1 | D160 gate collision (plugin parity vs communications queue) | TRUE | Renamed queue gate script to D292, kept plugin parity on D160, registered D292 in registry/topology/profiles. | `surfaces/verify/d292-communications-queue-pipeline-lock.sh`, `ops/bindings/gate.registry.yaml`, `ops/bindings/gate.execution.topology.yaml` |
| W76-T2 | GAP-OP-1024..1028 references were phantom | TRUE | Backfilled canonical entries in `operational.gaps.yaml` with status/parent_loop/regression_lock_id. | `ops/bindings/operational.gaps.yaml`, `bash surfaces/verify/d284-gap-reference-integrity-lock.sh` |
| W76-T3 | D83 proposal marker parity failing | TRUE | Added missing `.applied` marker for CP-20260226-041700 proposal. | `mailroom/outbox/proposals/CP-20260226-041700__bridge-canonical-upgrade-mobile-capabilities/.applied`, `bash surfaces/verify/d83-proposal-queue-health-lock.sh` |
| W76-T4 | D111 freshness stale | TRUE | Attempted smoke reindex; gate remains blocked by runtime smoke execution failures. | `bash surfaces/verify/d111-rag-embedding-smoke-preflight.sh`, `ops/plugins/rag/bin/rag-reindex-smoke` |
| W76-T5 | HA gates had silent pass/skip precondition risk | TRUE | Hardened D113/D114/D118/D120 with explicit precondition enforcement (`HA_GATE_MODE=enforce|report`), default enforce. | `surfaces/verify/d113-*.sh`, `d114-*.sh`, `d118-*.sh`, `d120-*.sh` |
| W76-T6 | D114 hardcoded automation count drift risk | TRUE | Replaced static expected count with canonical ledger-derived count from `ha.automations.ledger.yaml`. | `surfaces/verify/d114-ha-automation-stability.sh` |
| W76-T7 | Mint CI lacked digital-proofs in full flows | TRUE | Added digital-proofs test/audit/build/push flow coverage in CI. | `mint-modules/.gitea/workflows/ci.yaml` |
| W76-T8 | Target Dockerfiles lacked shared-auth COPY parity | TRUE | Added shared-auth COPY flow to artwork/order-intake/quote-page/finance-adapter/shopify-module Dockerfiles. | `mint-modules/*/Dockerfile` (target five) |
| W76-T9 | Spine mint inventory parity incomplete | TRUE | Added missing mint module services to SERVICE_REGISTRY, VM 213 services list, and stack runtime path normalization. | `docs/governance/SERVICE_REGISTRY.yaml`, `ops/bindings/vm.lifecycle.yaml`, `docs/governance/STACK_REGISTRY.yaml` |
| W76-T10 | CI guard coverage incomplete | TRUE | Wired required seven additional guard scripts into CI guards job. | `mint-modules/.gitea/workflows/ci.yaml` |
| W76-T11 | Module contract lifecycle status incomplete | TRUE | Added `status: deployed` for deployed module contracts and normalized scaffolded outlier module IDs. | `mint-modules/*/module.contract.yaml` |
| W76-T12 | Planning index was stub-level | TRUE | Expanded planning index to full alphabetical coverage. | `mint-modules/docs/PLANNING/INDEX.md` |
| W76-T13 | Legacy/cosmetic normalization debt remained | TRUE | Added legacy tombstone header, removed stale empty worktree dir, added package READMEs, added shared-types test script, comms->communications filename normalization, cloudflare inventory YAML normalization, AGENTS metadata freshness update. | Multiple files in spine/mint |
