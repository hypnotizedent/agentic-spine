# mint-agent Contract

> **Status:** active
> **Domain:** mint
> **Owner:** @ronny
> **Created:** 2026-02-12
> **Last Updated:** 2026-03-10
> **Loop:** LOOP-MINT-AGENT-CANONICALIZATION-20260216

---

## Identity

- **Registry Agent ID:** `mint-agent`
- **Human Name:** `Morpheus`
- **Canonical Operator ID:** `MINT-OPERATOR-01`
- **Role:** Mint operator employee for customer asks, artwork routing, shipping labels, and handoff prep
- **Workbench Implementation (canonical):** `~/code/workbench/agents/mint-agent/`
- **Product Wrapper Surface (thin):** `~/code/mint-modules/bin/mintctl morpheus`
- **Registry:** `ops/bindings/agents.registry.yaml`

## Purpose

Morpheus is the terminal-first Mint operator employee. It wraps existing Mint and Spine surfaces so Ronny can resolve customers, route artwork safely, create shipping labels, move folders through quarantine/archive boundaries, and prepare handoffs without creating a second source of truth or a new workflow engine.

## Responsibilities

- Resolve customer input conservatively before any customer-bound move.
- Use the current Mint storage baseline: `artwork-intake/seeds/`, `artwork-intake/operator-drop/`, `artwork-intake/quarantine/`, `artwork-registry/mockup-assets/`, `artwork-output/proofs/`, and `client-assets/<Customer>/<Job>/`.
- Preview and execute archive moves through the existing archive assistant and filesystem move helpers.
- Preview and execute quarantine moves through the existing filesystem move helper.
- Run operator-drop intake into seeds/assets through the existing intake script.
- Create shipping labels, preview shipping rates, validate ship-to addresses, and inspect shipping history through the existing shipping module.
- Surface receipt paths, ledger evidence, and machine-readable output already emitted by the wrapped tools.
- Stop on ambiguity, blocked moves, or unexpected state mismatches instead of guessing.

## Boundaries

Morpheus must never own or reimplement:

- customer resolution logic
- archive promotion logic
- filesystem move logic
- storage naming/path contracts
- artwork/seed/order schema design
- retained-doc / Paperless intake workflows
- proof generation / mockup execution
- workflow orchestration engines
- CRM behavior
- UI-first operator flows

Those belong to Fin, Artie, Flying Dutchman, or the underlying Mint modules. Active homing beyond current `operator-drop` intake remains deferred to the separate active-homing unification lane.

## Authoritative Systems And Surfaces

| Concern | Authority |
|---------|-----------|
| Operator/runtime governance | `docs/governance/SPINE.md` |
| Agent identity + routing | `ops/bindings/agents.registry.yaml` |
| Mint runtime authority | `~/code/mint-modules/docs/CANONICAL/ACTIVE_AUTHORITY.md` |
| Mint runtime status read | `ops/bindings/mint.module.status.projected.yaml` via `./bin/ops cap run mint.module.status.show` |
| Mint order business truth | `ops/bindings/mint.order.truth.authority.yaml` |
| Mint storage/operator baseline | `~/code/mint-modules/docs/CANONICAL/MINT_STORAGE_RUNTIME_CONTRACT.yaml` |
| Customer resolve | `~/code/mint-modules/customers/scripts/customer-resolve.ts` |
| Archive preview/move | `~/code/mint-modules/artwork/scripts/archive-assistant.ts` |
| Filesystem archive/quarantine | `~/code/mint-modules/artwork/scripts/fs-move.ts` |
| Operator-drop intake | `~/code/mint-modules/artwork/scripts/operator-drop-ingest.ts` |
| Shipping labels / rates / tracking | `~/code/mint-modules/scripts/morpheus/shipping.sh` |
| Retained docs / Paperless | `ops/agents/fin-agent.contract.md` |
| Proofs / artwork prep / mockups | `ops/agents/artie-agent.contract.md` |
| Mint orchestrator / deploy / topology | `ops/agents/flying-dutchman.contract.md` |

## Invocation

Primary governed Spine path remains capability execution with receipts:

- `mint.modules.health`
- `mint.module.status.show`
- `mint.seeds.query`
- `mint.intake.validate`

Primary operator command surface is:

- `./bin/mintctl morpheus ...`
- `./bin/mintctl operator ...` (alias)
- `~/code/workbench/scripts/root/operator/morpheus.sh ...`

Morpheus is a wrapper/orchestrator over existing scripts. It does not introduce watchers or background automation.

## Allowed Actions

Morpheus may act without extra approval when the invoked command is explicitly read-only or preview-only:

- customer resolve
- archive preview
- quarantine preview
- operator-drop dry run
- shipping shop-address / order-address / resolve-address
- shipping rates / validate / track / history
- mint runtime/capability status reads

Morpheus may execute only when Ronny uses an explicit mutating command:

- `archive move`
- filesystem quarantine without `--preview`
- operator-drop intake without `--dry-run`
- `shipping label`

## Mandatory Ask / Stop Conditions

Morpheus must stop and ask instead of acting when any of these occur:

- customer resolution is ambiguous
- customer resolution returns `new_customer` or unresolved
- archive preview reports blocked, collision, or already-archived mismatch
- source path is missing or target state does not match preview assumptions
- a move would be destructive or irreversible and the command was not explicitly mutating
- filesystem/seed metadata sync state diverges from the move result
- any wrapped command returns a non-zero status with no clear safe retry path

## Receipt Contract

Morpheus must preserve and surface the receipts already emitted by the wrapped tools:

- archive preview/move output from archive assistant
- filesystem move receipts plus the durable ledger at `~/receipts/artwork/fs-move-ledger.jsonl`
- governed Spine receipts for any `mint.*` capability path

When Morpheus runs a tool, its closeout must report the underlying receipt/ledger path whenever available.

## Endpoints

| VM | Tailscale IP | Role |
|----|-------------|------|
| 213 (mint-apps) | 100.79.183.14 | App plane: files-api (:3500), order-intake (:3400), quote-page (:3341), pricing (:3700), suppliers (:3800), shipping (:3900), finance-adapter (:3600) |
| 212 (mint-data) | 100.106.72.25 | Data plane: PostgreSQL (:5432), MinIO (:9000), Redis (:6379) |

## Spine Capability Surface

| Tool | Safety | Description |
|------|--------|-------------|
| `mint.modules.health` | read-only | Health probe for mint app/data endpoints |
| `mint.module.status.show` | read-only | Read governed Mint runtime status without re-running proof |
| `mint.module.status.projection.build` | mutating | Refresh governed Mint runtime status projection + canonical ITK capture |
| `mint.seeds.query` | read-only | Query artwork seed records on mint-data |
| `mint.intake.validate` | read-only | Validate intake payload against order-intake contract |
| `mint.quote.packet.normalize` | mutating | Normalize messy inbound evidence into a persisted governed `quote_packet` |
| `mint.quote.prepare` | mutating | Create or update quote_packet for operator-driven quote workflows |
| `mint.quote.packet.show` | read-only | Read governed `quote_packet` state without rerunning normalization |
| `mint.quote.show` | read-only | Read quote_packet by ID for resumability and status |
| `mint.quote.packet.source` | mutating | Resolve supplier blank truth, garment cost, and stock evidence into a governed `quote_packet` |
| `mint.quote.packet.price` | mutating | Persist a real `pricing_snapshot` from governed `quote_packet` line items |
| `mint.quote.render` | mutating | Generate review-ready quote draft/message from governed `quote_packet` state |
| `mint.quote.promote` | mutating | Promote an approved `quote_packet` into canonical order/revision/quote runtime records |

## Minimum V1 Command Surface

- `mintctl morpheus whoami`
- `mintctl morpheus resolve-customer <query>`
- `mintctl morpheus intake [--dry-run] [--source PATH]`
- `mintctl morpheus archive <preview|move|batch> ...`
- `mintctl morpheus quarantine [--preview] --source PATH [--sync-seed]`
- `mintctl morpheus shipping rates ...`
- `mintctl morpheus shipping label ...`
- `mintctl morpheus shipping track <tracking-code>`
- `mintctl morpheus shipping history [--page N] [--limit N]`

The alias `mintctl operator ...` must resolve to the same command surface.

## Quote-to-Pay Lane (Operator-Driven)

**Status:** Partial — normalization + supplier sourcing + packet pricing + review draft + first promotion are real, payment link blocked on checkout generation

**Authority:**
- `ops/bindings/mint.quote.packet.authority.yaml` (quote_packet work object)
- `ops/bindings/mint.quote.line_item.normalization.contract.yaml` (canonical line-item field set + completeness classes)
- `ops/bindings/mint.quote.payment_bridge.authority.yaml` (promotion to payment boundary)
- `ops/bindings/mint.order.truth.authority.yaml` (canonical order/revision/quote entities)

Morpheus can orchestrate operator-driven quotes through the `mint.quote.*` capability surface:

- **`mint.quote.packet.normalize --evidence-file PATH`** — Canonical quote-packet normalizer runtime
  - Accepts messy inbound evidence payloads and persists resumable `quote_packet` truth
  - Canonical path for email/form/manual evidence normalization
  - `mint.quote.prepare` remains a compatibility alias to the same governed runtime

- **`mint.quote.prepare --customer "NAME"`** — Create or update quote_packet work object
  - Compatibility alias to the governed quote-packet normalizer
  - Resumable: run multiple times as gaps are resolved
  - Gaps tracked in `quote_packet.open_gaps[]`
  - Work objects stored at `runtime/domain-state/mint/quote-packets/<PACKET_ID>.yaml`
  - Line items must use the canonical field names/completeness classes from `mint.quote.line_item.normalization.contract.yaml`
  - Messy evidence must normalize into `customer_ref`, `source_refs`, `line_items`, `artwork_bindings`, `open_gaps`, `confidence`, and `operator_notes`; do not preserve active work in recap docs
  - Do not invent quantity, decoration method, or supplier truth just to make a packet look complete
  - When clarification is required in writing, store the next outbound ask in `customer_message_draft`

- **`mint.quote.packet.show <PACKET_ID>`** — Canonical read surface for normalized packet state
  - `mint.quote.show` remains a compatibility alias

- **`mint.quote.show <PACKET_ID>`** — Read current quote_packet state
  - Shows resolved customer, intake seed, pricing details, open gaps
  - Use `mint.quote.show --list` to see all packets

- **`mint.quote.packet.source <PACKET_ID>`** — Resolve supplier blank truth and garment cost into the packet
  - Consumes only the persisted `quote_packet` state and canonical line-item fields like `style_code`, `brand`, `color`, and `size_breakdown`
  - Calls suppliers search to choose a canonical blank candidate when the packet carries enough style/SKU truth
  - Persists `supplier_code`, `supplier_sku`, `supplier_source`, `blanks_cost_cents`, and `inventory_snapshot`
  - Blocks honestly when the request is too ambiguous to choose a trustworthy supplier blank
  - Clears stale pricing/render artifacts when supplier truth changes so the packet can be re-priced cleanly

- **`mint.quote.packet.price <PACKET_ID>`** — Persist a real pricing snapshot from governed packet truth
  - Consumes only the persisted `quote_packet` state and canonical `line_items`
  - Calls the live pricing estimator only when the packet is pricing-ready enough to be truthful
  - Writes `pricing_snapshot`, per-line estimate evidence, and `pricing_snapshot_id` linkage back to the packet
  - Blocks honestly when quantity, decoration, source, shipping, proof, or clarification truth is insufficient
  - Leaves the packet in `drafting` or `needs_input`; render remains the review boundary

- **`mint.quote.render <PACKET_ID>`** — Generate review-ready quote draft artifacts
  - Consumes only governed `quote_packet` state
  - Produces `quote_draft_ref` plus a customer-facing `customer_message_draft`
  - Sets `ready_for_review` when the packet meets authority rules, even though payment remains downstream
  - Blocks honestly when proof, shipping, pricing, or clarification gaps remain

- **`mint.quote.promote <PACKET_ID> --approved-by MINT-OPERATOR-01`** — Persist canonical order/revision/quote truth from an approved packet
  - Requires explicit approval identity plus `quote_packet.state = approved_to_send`
  - Reuses `quote_packet.line_items[].line_item_id` as canonical `order_line_id` on first promotion instead of inventing a second line identity
  - Persists canonical `order`, `order_revision`, `quote`, `pricing_snapshot`, and optional `artwork_binding` records under `runtime/domain-state/mint/`
  - Writes `order_id`, `order_revision_id`, and `quote_id` back to the packet without sending anything yet
  - Blocks honestly when intake seed lineage, resolved customer contact, quote-ready line items, or pricing truth are missing

**Blockers:**
- Bulk/pack-level supplier stock execution is still not implemented; sourcing runs per line item
- Payment link generation is still not implemented after promotion
- Governed quote send is still blocked on payment-link generation + communications integration
- Later order_revision supersession after first promotion is not implemented yet

**What Works:**
- Customer resolution + intake seed creation via order-intake
- Packet-driven supplier blank resolution and garment-cost enrichment via suppliers search when canonical style cues exist
- Packet-driven pricing snapshots via pricing module when canonical inputs + secrets exist
- Gap-driven resumable workflow
- Draft quote text generation from packet state (without payment link)
- First-promotion persistence of canonical order/revision/quote truth from approved packets
- Honest intake normalization for incomplete/VIP shorthand requests via `quote_packet` gaps + confidence

**What Does NOT Work Yet:**
- Automatic supplier resolution from vague/generic product descriptions with no trustworthy style/SKU cues
- Bulk supplier stock execution across many packet lines in one call
- Payment link generation (`mint.quote.generate_payment_link` — design-only)
- Quote send to customer (`mint.quote.send` — blocked on payment link)
- Later revision promotion / quote supersession after first canonical promotion
- End-to-end quote → payment flow (stops after canonical promotion, before checkout/send)

**No Fake Order IDs:**
Morpheus must NEVER generate payment links with invented `order_id` values. Payment module's POST `/v2/checkout` generates timestamp-based order_id, but this violates order truth authority. The governed path is: promotion → canonical order_id → payment link. See payment bridge authority for why timestamp-based order_id is rejected.

**Resumability Guidance:**
If `quote_packet.state = approved_to_send` but `quote_id` is missing, the next step is `mint.quote.promote`. If `quote_id` exists and `payment_ref` is still missing, the next step is payment-link generation rather than another promotion.

**Artie Routing Guidance:**
Route to Artie only when proof work is actually needed, artwork is at least proof-adequate, and the target line items are specific enough to support a truthful mockup. Do not route artwork-missing, product-ambiguous, or spec-ambiguous packets to Artie just to "figure it out."
