-- ============================================================================
-- Mint OS Core Schema — Authoritative DDL
-- Authority: ops/plugins/domains/mint/schema/mint.schema.authority.yaml
-- Loop: LOOP-MINT-OS-FOUNDATION-20260325
-- ============================================================================
-- This schema defines the 7 canonical Mint business entities. All Mint-facing
-- modules MUST conform to these table shapes. No agent may execute CREATE TABLE
-- outside of governed schema migrations referencing this file.
--
-- Aligned with: ops/bindings/mint.order.truth.authority.yaml
-- Dialect: SQLite-compatible reference DDL (PostgreSQL runtime adds native UUID,
--          JSONB, and timestamp types — shape and constraints remain identical)
-- ============================================================================

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- ============================================================================
-- 1. CUSTOMER — Business counterparty
-- ============================================================================
-- Authority ref: mint.order.truth.authority.yaml → entity_model.customer_ref
-- Identity states: provisional (intake), resolved (verified for quoting/payment)
-- ============================================================================
CREATE TABLE customer (
    customer_id       TEXT PRIMARY KEY,                    -- UUID
    name              TEXT NOT NULL,
    email             TEXT,
    phone             TEXT,
    company           TEXT,
    identity_state    TEXT NOT NULL DEFAULT 'provisional'
                      CHECK (identity_state IN ('provisional', 'resolved')),
    source            TEXT CHECK (source IN ('shopify', 'direct', 'referral', 'email', 'phone', 'web_intake')),
    shopify_customer_id TEXT,
    notes             TEXT,
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX idx_customer_email ON customer(email);
CREATE INDEX idx_customer_shopify ON customer(shopify_customer_id);

-- ============================================================================
-- 2. GARMENT — Blank product catalog
-- ============================================================================
-- Represents a specific style/color combination from a supplier.
-- size_breakdown lives on line_item (per-order), sizes_available here is catalog truth.
-- ============================================================================
CREATE TABLE garment (
    garment_id        TEXT PRIMARY KEY,                    -- UUID
    style_number      TEXT NOT NULL,                       -- manufacturer SKU (e.g., "G500")
    brand             TEXT NOT NULL,                       -- Gildan, Bella+Canvas, Next Level, etc.
    description       TEXT,
    color             TEXT NOT NULL,
    sizes_available   TEXT NOT NULL,                       -- JSON array: ["S","M","L","XL","2XL"]
    unit_cost_cents   INTEGER,                             -- supplier cost in cents
    supplier          TEXT,
    supplier_sku      TEXT,                                -- supplier-specific SKU
    category          TEXT CHECK (category IN (
                        't-shirt', 'hoodie', 'polo', 'tank', 'long-sleeve',
                        'jacket', 'hat', 'bag', 'sweatshirt', 'other'
                      )),
    weight_oz         REAL,
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX idx_garment_style ON garment(style_number, color);
CREATE INDEX idx_garment_brand ON garment(brand);
CREATE INDEX idx_garment_supplier ON garment(supplier, supplier_sku);

-- ============================================================================
-- 3. ORDER — Governed business work item
-- ============================================================================
-- Authority ref: mint.order.truth.authority.yaml → entity_model.order
-- lifecycle_state and payment_state are orthogonal state machines.
-- Mutable fields: current_revision_id, active_quote_id, operator_notes, assignment.
-- ============================================================================
CREATE TABLE "order" (
    order_id          TEXT PRIMARY KEY,                    -- UUID (canonical)
    customer_id       TEXT NOT NULL REFERENCES customer(customer_id),
    current_revision_id TEXT,                              -- mutable → latest order_revision
    active_quote_id   TEXT,                                -- mutable → current active quote
    visual_id         TEXT,                                -- legacy display alias (non-canonical)
    shopify_order_id  TEXT,
    lifecycle_state   TEXT NOT NULL DEFAULT 'draft'
                      CHECK (lifecycle_state IN ('draft', 'quoted', 'approved', 'production', 'fulfilled', 'cancelled')),
    payment_state     TEXT NOT NULL DEFAULT 'unpaid'
                      CHECK (payment_state IN ('unpaid', 'partially_paid', 'paid', 'refunded')),
    due_date          TEXT,
    assignment        TEXT,                                -- mutable: assigned operator/agent
    operator_notes    TEXT,                                -- mutable working field
    intake_seed_refs  TEXT,                                -- JSON array of seed_id references
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX idx_order_customer ON "order"(customer_id);
CREATE INDEX idx_order_lifecycle ON "order"(lifecycle_state);
CREATE INDEX idx_order_shopify ON "order"(shopify_order_id);
CREATE INDEX idx_order_due ON "order"(due_date) WHERE due_date IS NOT NULL;

-- ============================================================================
-- 4. ARTWORK — Design file/asset
-- ============================================================================
-- Represents a versioned design asset. Artwork is customer-scoped and may be
-- reused across orders. Versioning via parent_artwork_id chain.
-- storage_tier tracks Hot/Warm/Cold lifecycle position.
-- ============================================================================
CREATE TABLE artwork (
    artwork_id        TEXT PRIMARY KEY,                    -- UUID
    customer_id       TEXT REFERENCES customer(customer_id),
    filename          TEXT NOT NULL,
    file_hash         TEXT,                                -- SHA256 content hash
    file_format       TEXT CHECK (file_format IN ('ai', 'eps', 'pdf', 'png', 'svg', 'psd', 'jpg', 'tiff')),
    width_px          INTEGER,
    height_px         INTEGER,
    dpi               INTEGER,
    color_mode        TEXT CHECK (color_mode IN ('cmyk', 'rgb', 'spot', 'mixed')),
    color_count       INTEGER,
    storage_path      TEXT NOT NULL,                       -- deterministic path per lifecycle yaml
    storage_tier      TEXT NOT NULL DEFAULT 'hot'
                      CHECK (storage_tier IN ('hot', 'warm', 'cold')),
    version           INTEGER NOT NULL DEFAULT 1,
    parent_artwork_id TEXT REFERENCES artwork(artwork_id), -- version chain
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX idx_artwork_customer ON artwork(customer_id);
CREATE INDEX idx_artwork_hash ON artwork(file_hash);
CREATE INDEX idx_artwork_tier ON artwork(storage_tier);

-- ============================================================================
-- 5. LINE ITEM — Garment + quantity within an order revision
-- ============================================================================
-- Authority ref: mint.order.truth.authority.yaml → identity_model.order_line_id
-- line_item_id is STABLE across order revisions for the same business line.
-- size_breakdown is per-order (not catalog truth — that's garment.sizes_available).
-- ============================================================================
CREATE TABLE line_item (
    line_item_id      TEXT PRIMARY KEY,                    -- UUID (stable across revisions)
    order_id          TEXT NOT NULL REFERENCES "order"(order_id),
    order_revision_id TEXT NOT NULL,                       -- which revision this belongs to
    garment_id        TEXT NOT NULL REFERENCES garment(garment_id),
    quantity          INTEGER NOT NULL CHECK (quantity > 0),
    size_breakdown    TEXT,                                -- JSON: {"S":10, "M":20, "L":15, "XL":5}
    unit_price_cents  INTEGER,
    line_total_cents  INTEGER,                             -- quantity * unit_price + decoration costs
    notes             TEXT,
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX idx_line_item_order ON line_item(order_id);
CREATE INDEX idx_line_item_revision ON line_item(order_revision_id);
CREATE INDEX idx_line_item_garment ON line_item(garment_id);

-- ============================================================================
-- 6. DECORATION — Print/embroidery/transfer applied to a line item
-- ============================================================================
-- Multi-relational: one line_item can have multiple decorations (front + back +
-- sleeve). Each decoration binds an artwork to a placement with a method.
-- This is the physical realization of mint.order.truth.authority → artwork_binding.
-- ============================================================================
CREATE TABLE decoration (
    decoration_id     TEXT PRIMARY KEY,                    -- UUID
    line_item_id      TEXT NOT NULL REFERENCES line_item(line_item_id),
    artwork_id        TEXT NOT NULL REFERENCES artwork(artwork_id),
    method            TEXT NOT NULL CHECK (method IN (
                        'screen_print', 'dtg', 'dtf', 'embroidery',
                        'vinyl', 'sublimation', 'heat_transfer'
                      )),
    placement         TEXT NOT NULL CHECK (placement IN (
                        'front', 'back', 'left_chest', 'right_chest',
                        'left_sleeve', 'right_sleeve', 'neck', 'hem',
                        'pocket', 'full_front', 'full_back', 'other'
                      )),
    color_count       INTEGER,
    width_inches      REAL,
    height_inches     REAL,
    setup_cost_cents  INTEGER,
    per_unit_cost_cents INTEGER,
    notes             TEXT,
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX idx_decoration_line_item ON decoration(line_item_id);
CREATE INDEX idx_decoration_artwork ON decoration(artwork_id);
CREATE INDEX idx_decoration_method ON decoration(method);

-- ============================================================================
-- 7. MOCKUP — Visual proof of artwork on garment
-- ============================================================================
-- Customer-facing proof image. Versioned via parent_mockup_id chain.
-- Approval gates quote send: no quote without an approved mockup.
-- ============================================================================
CREATE TABLE mockup (
    mockup_id         TEXT PRIMARY KEY,                    -- UUID
    line_item_id      TEXT NOT NULL REFERENCES line_item(line_item_id),
    decoration_id     TEXT REFERENCES decoration(decoration_id),
    artwork_id        TEXT NOT NULL REFERENCES artwork(artwork_id),
    garment_id        TEXT NOT NULL REFERENCES garment(garment_id),
    filename          TEXT NOT NULL,
    file_hash         TEXT,                                -- SHA256 content hash
    storage_path      TEXT NOT NULL,                       -- deterministic path per lifecycle yaml
    storage_tier      TEXT NOT NULL DEFAULT 'hot'
                      CHECK (storage_tier IN ('hot', 'warm', 'cold')),
    status            TEXT NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft', 'sent', 'approved', 'revision_requested', 'superseded')),
    approved_by       TEXT,
    approved_at       TEXT,
    version           INTEGER NOT NULL DEFAULT 1,
    parent_mockup_id  TEXT REFERENCES mockup(mockup_id),  -- version chain
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX idx_mockup_line_item ON mockup(line_item_id);
CREATE INDEX idx_mockup_artwork ON mockup(artwork_id);
CREATE INDEX idx_mockup_status ON mockup(status);
CREATE INDEX idx_mockup_tier ON mockup(storage_tier);
