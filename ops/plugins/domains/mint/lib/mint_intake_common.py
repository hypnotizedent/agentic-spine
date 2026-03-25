"""
Mint Domain — Shared Pipeline Utilities

DB connection, query helpers, asset routing, confidence scoring, and
extraction helpers for the governed Mint OS pipeline. Used by intake,
quoting, history, and outbound capabilities.

Authority:
  - Schema: ops/plugins/domains/mint/schema/mint.core.schema.sql
  - Runtime boundary: ops/plugins/domains/mint/contracts/mint.runtime.boundary.yaml
  - Storage lifecycle: ops/plugins/domains/mint/storage/mint.storage.lifecycle.yaml
"""
from __future__ import annotations

import os
import re
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MINT_RUNTIME_ROOT = Path(os.environ.get("MINT_RUNTIME_ROOT", os.path.expanduser("~/.runtime/mint")))
MINT_DB_PATH = MINT_RUNTIME_ROOT / "state" / "mint.db"

GARMENT_MARKERS = (
    "t-shirt", "tee", "tees", "shirt", "shirts",
    "hoodie", "hoodies", "sweatshirt", "sweatshirts",
    "polo", "polos", "tank", "tanks", "tank top",
    "long sleeve", "long-sleeve", "jacket", "jackets",
    "hat", "hats", "cap", "caps", "beanie",
    "bag", "bags", "tote",
)

DECORATION_MARKERS = (
    "screen print", "screenprint", "screen-print",
    "dtg", "direct to garment",
    "dtf", "direct to film",
    "embroidery", "embroider", "embroidered",
    "vinyl", "heat transfer", "heat-transfer",
    "sublimation", "sublimated",
)

SIZE_PATTERN = re.compile(
    r"\b((?:youth\s+)?(?:XXS|XS|S|M|L|XL|2XL|3XL|4XL|5XL))\b",
    re.IGNORECASE,
)

QUANTITY_PATTERN = re.compile(
    r"\b(\d{1,5})\s*(?:pcs?|pieces?|units?|shirts?|tees?|hoodies?|each)?\b",
    re.IGNORECASE,
)

COLOR_MARKERS = (
    "black", "white", "navy", "royal", "red", "heather grey", "heather gray",
    "charcoal", "sport grey", "sport gray", "forest green", "maroon",
    "gold", "orange", "purple", "pink", "light blue", "ash", "sand",
    "natural", "kelly green", "carolina blue", "indigo",
)

ARTWORK_EXTENSIONS = (".ai", ".eps", ".pdf", ".png", ".svg", ".psd", ".jpg", ".jpeg", ".tiff", ".tif")


# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------

def get_db_path() -> Path:
    """Resolve the canonical Mint DB path."""
    return Path(os.environ.get("MINT_DB_PATH", str(MINT_DB_PATH)))


def get_db_connection() -> sqlite3.Connection:
    """Return a SQLite connection to the Mint database with governed defaults."""
    db_path = get_db_path()
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA foreign_keys = ON")
    conn.row_factory = sqlite3.Row
    return conn


def init_db(conn: sqlite3.Connection) -> None:
    """Initialize the Mint database from the canonical schema DDL."""
    schema_path = Path(__file__).resolve().parents[1] / "schema" / "mint.core.schema.sql"
    if not schema_path.exists():
        raise FileNotFoundError(f"Canonical schema not found: {schema_path}")
    ddl = schema_path.read_text()
    # SQLite executescript ignores PRAGMA in some contexts, set them explicitly
    conn.executescript(ddl)


def generate_id() -> str:
    """Generate a UUID4 string for entity IDs."""
    return str(uuid.uuid4())


# ---------------------------------------------------------------------------
# Timestamp
# ---------------------------------------------------------------------------

def now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------------
# Confidence Scoring
# ---------------------------------------------------------------------------

def score_field(value: Any, markers_found: int = 0, explicit: bool = False) -> dict[str, Any]:
    """
    Assign a confidence score to an extracted field.
    Returns {"value": ..., "confidence": float, "level": str}.

    Rules:
      - explicit structured data (e.g., email address) → high (0.95)
      - marker-matched with 2+ hits → high (0.85)
      - marker-matched with 1 hit → medium (0.65)
      - inferred/guessed → low (0.35)
      - missing → none (0.0)
    """
    if value is None or value == "" or value == []:
        return {"value": value, "confidence": 0.0, "level": "none"}
    if explicit:
        return {"value": value, "confidence": 0.95, "level": "high"}
    if markers_found >= 2:
        return {"value": value, "confidence": 0.85, "level": "high"}
    if markers_found == 1:
        return {"value": value, "confidence": 0.65, "level": "medium"}
    return {"value": value, "confidence": 0.35, "level": "low"}


# ---------------------------------------------------------------------------
# Email Extraction Helpers
# ---------------------------------------------------------------------------

def extract_sender_info(message: dict[str, Any]) -> dict[str, Any]:
    """Extract customer identity from email sender fields."""
    from_field = message.get("from") or {}
    email_addr = from_field.get("emailAddress") or {}
    name = (email_addr.get("name") or "").strip()
    email = (email_addr.get("address") or "").strip().lower()

    return {
        "name": score_field(name, explicit=bool(name)),
        "email": score_field(email, explicit=bool(email)),
        "company": score_field(extract_company_from_email(email), markers_found=1 if email else 0),
    }


def extract_company_from_email(email: str) -> str:
    """Infer company name from email domain (skip common providers)."""
    if not email or "@" not in email:
        return ""
    domain = email.split("@", 1)[1].lower()
    skip = {"gmail.com", "yahoo.com", "outlook.com", "hotmail.com", "icloud.com",
            "aol.com", "protonmail.com", "me.com", "live.com", "msn.com"}
    if domain in skip:
        return ""
    return domain.split(".")[0].title()


def extract_line_items_from_body(body: str) -> list[dict[str, Any]]:
    """
    Parse line item candidates from email body text.
    Returns list of extracted items with confidence scores.
    Never blocks on uncertainty — scores everything and proceeds.
    """
    body_lower = body.lower()
    items: list[dict[str, Any]] = []

    # Find garment references
    garment_hits = [m for m in GARMENT_MARKERS if m in body_lower]
    decoration_hits = [m for m in DECORATION_MARKERS if m in body_lower]
    color_hits = [m for m in COLOR_MARKERS if m in body_lower]
    sizes = SIZE_PATTERN.findall(body)
    quantities = QUANTITY_PATTERN.findall(body)

    # Build a single line item from detected signals (basic extraction)
    # More sophisticated parsing (multi-line-item, table parsing) is a future wave
    if garment_hits or quantities:
        item: dict[str, Any] = {
            "garment_type": score_field(
                garment_hits[0] if garment_hits else None,
                markers_found=len(garment_hits),
            ),
            "quantity": score_field(
                int(quantities[0]) if quantities else None,
                markers_found=len(quantities),
            ),
            "sizes": score_field(
                [s.upper() for s in sizes] if sizes else None,
                markers_found=len(sizes),
            ),
            "color": score_field(
                color_hits[0] if color_hits else None,
                markers_found=len(color_hits),
            ),
            "decoration_method": score_field(
                decoration_hits[0] if decoration_hits else None,
                markers_found=len(decoration_hits),
            ),
        }
        items.append(item)

    return items


def extract_artwork_refs(message: dict[str, Any]) -> list[dict[str, Any]]:
    """
    Identify artwork references from message attachments and inline links.
    Returns list of artwork refs with type and confidence.
    """
    refs: list[dict[str, Any]] = []

    # Check attachments
    attachments = message.get("attachments") or []
    for att in attachments:
        name = (att.get("name") or "").strip()
        content_type = (att.get("contentType") or "").lower()
        size = att.get("size") or 0
        att_id = att.get("id") or ""

        is_artwork = any(name.lower().endswith(ext) for ext in ARTWORK_EXTENSIONS)
        refs.append({
            "type": "attachment",
            "filename": score_field(name, explicit=True),
            "is_artwork": score_field(is_artwork, explicit=True),
            "content_type": content_type,
            "size_bytes": size,
            "attachment_id": att_id,
        })

    # Check body for links to files
    body = (message.get("body") or {}).get("content") or message.get("bodyPreview") or ""
    url_pattern = re.compile(r'https?://\S+\.(?:ai|eps|pdf|png|svg|psd|jpg|jpeg|tiff|tif)\b', re.IGNORECASE)
    for url in url_pattern.findall(body):
        refs.append({
            "type": "link",
            "url": score_field(url, explicit=True),
            "is_artwork": score_field(True, explicit=True),
        })

    return refs


# ---------------------------------------------------------------------------
# Asset Routing (Hot Storage)
# ---------------------------------------------------------------------------

def hot_artwork_path(order_id: str, artwork_id: str) -> Path:
    """
    Resolve the deterministic Hot storage path for artwork.
    Pattern: $MINT_RUNTIME_ROOT/hot/artwork/{order_id}/{artwork_id}/
    """
    return MINT_RUNTIME_ROOT / "hot" / "artwork" / order_id / artwork_id


def hot_mockup_path(order_id: str, line_item_id: str) -> Path:
    """
    Resolve the deterministic Hot storage path for mockups.
    Pattern: $MINT_RUNTIME_ROOT/hot/mockups/{order_id}/{line_item_id}/
    """
    return MINT_RUNTIME_ROOT / "hot" / "mockups" / order_id / line_item_id


def route_asset_to_hot(data: bytes, filename: str, order_id: str, artwork_id: str) -> Path:
    """
    Write an asset to the governed Hot storage path.
    Returns the absolute path where the file was written.
    """
    target_dir = hot_artwork_path(order_id, artwork_id)
    target_dir.mkdir(parents=True, exist_ok=True)
    target_file = target_dir / filename
    target_file.write_bytes(data)
    return target_file


# ---------------------------------------------------------------------------
# Database Query Helpers (Read-Only)
# ---------------------------------------------------------------------------

def row_to_dict(row: sqlite3.Row | None) -> dict[str, Any] | None:
    """Convert a sqlite3.Row to a plain dict."""
    if row is None:
        return None
    return dict(row)


def rows_to_list(rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
    """Convert a list of sqlite3.Row to a list of dicts."""
    return [dict(r) for r in rows]


def get_customer(conn: sqlite3.Connection, customer_id: str) -> dict[str, Any] | None:
    """Fetch a customer by ID."""
    return row_to_dict(conn.execute(
        "SELECT * FROM customer WHERE customer_id = ?", (customer_id,)
    ).fetchone())


def get_customer_by_email(conn: sqlite3.Connection, email: str) -> dict[str, Any] | None:
    """Fetch a customer by email address."""
    return row_to_dict(conn.execute(
        "SELECT * FROM customer WHERE email = ?", (email.lower(),)
    ).fetchone())


def get_customer_orders(conn: sqlite3.Connection, customer_id: str) -> list[dict[str, Any]]:
    """Fetch all orders for a customer, most recent first."""
    return rows_to_list(conn.execute(
        'SELECT * FROM "order" WHERE customer_id = ? ORDER BY created_at DESC',
        (customer_id,)
    ).fetchall())


def get_order(conn: sqlite3.Connection, order_id: str) -> dict[str, Any] | None:
    """Fetch a single order by ID."""
    return row_to_dict(conn.execute(
        'SELECT * FROM "order" WHERE order_id = ?', (order_id,)
    ).fetchone())


def get_order_line_items(conn: sqlite3.Connection, order_id: str) -> list[dict[str, Any]]:
    """Fetch line items for an order with garment details joined."""
    return rows_to_list(conn.execute(
        """SELECT li.*, g.style_number, g.brand, g.color, g.category,
                  g.sizes_available, g.unit_cost_cents, g.supplier
           FROM line_item li
           JOIN garment g ON li.garment_id = g.garment_id
           WHERE li.order_id = ?
           ORDER BY li.created_at""",
        (order_id,)
    ).fetchall())


def get_line_item_decorations(conn: sqlite3.Connection, line_item_id: str) -> list[dict[str, Any]]:
    """Fetch decorations for a line item with artwork details joined."""
    return rows_to_list(conn.execute(
        """SELECT d.*, a.filename AS artwork_filename, a.file_format,
                  a.storage_path AS artwork_storage_path, a.storage_tier AS artwork_tier
           FROM decoration d
           JOIN artwork a ON d.artwork_id = a.artwork_id
           WHERE d.line_item_id = ?
           ORDER BY d.placement""",
        (line_item_id,)
    ).fetchall())


def get_customer_artwork(conn: sqlite3.Connection, customer_id: str) -> list[dict[str, Any]]:
    """Fetch artwork library for a customer, most recent first."""
    return rows_to_list(conn.execute(
        "SELECT * FROM artwork WHERE customer_id = ? ORDER BY created_at DESC",
        (customer_id,)
    ).fetchall())


def get_order_mockups(conn: sqlite3.Connection, order_id: str) -> list[dict[str, Any]]:
    """Fetch all mockups for an order via line items."""
    return rows_to_list(conn.execute(
        """SELECT m.*, li.order_id
           FROM mockup m
           JOIN line_item li ON m.line_item_id = li.line_item_id
           WHERE li.order_id = ?
           ORDER BY m.created_at DESC""",
        (order_id,)
    ).fetchall())


def get_customer_aggregate(conn: sqlite3.Connection, customer_id: str) -> dict[str, Any]:
    """Compute aggregate customer stats: order count, lifetime value, preferences."""
    row = conn.execute(
        """SELECT
             COUNT(*) AS total_orders,
             SUM(CASE WHEN lifecycle_state = 'fulfilled' THEN 1 ELSE 0 END) AS fulfilled_orders,
             SUM(CASE WHEN lifecycle_state = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
             MIN(created_at) AS first_order_at,
             MAX(created_at) AS last_order_at
           FROM "order" WHERE customer_id = ?""",
        (customer_id,)
    ).fetchone()
    stats = dict(row) if row else {}

    # Lifetime value from line items
    value_row = conn.execute(
        """SELECT COALESCE(SUM(li.line_total_cents), 0) AS lifetime_value_cents
           FROM line_item li
           JOIN "order" o ON li.order_id = o.order_id
           WHERE o.customer_id = ? AND o.lifecycle_state IN ('fulfilled', 'production', 'approved')""",
        (customer_id,)
    ).fetchone()
    stats["lifetime_value_cents"] = dict(value_row)["lifetime_value_cents"] if value_row else 0

    # Preferred garment types
    pref_rows = conn.execute(
        """SELECT g.category, g.brand, COUNT(*) AS usage_count
           FROM line_item li
           JOIN garment g ON li.garment_id = g.garment_id
           JOIN "order" o ON li.order_id = o.order_id
           WHERE o.customer_id = ?
           GROUP BY g.category, g.brand
           ORDER BY usage_count DESC
           LIMIT 5""",
        (customer_id,)
    ).fetchall()
    stats["preferred_garments"] = rows_to_list(pref_rows)

    # Preferred decoration methods
    dec_rows = conn.execute(
        """SELECT d.method, COUNT(*) AS usage_count
           FROM decoration d
           JOIN line_item li ON d.line_item_id = li.line_item_id
           JOIN "order" o ON li.order_id = o.order_id
           WHERE o.customer_id = ?
           GROUP BY d.method
           ORDER BY usage_count DESC
           LIMIT 5""",
        (customer_id,)
    ).fetchall()
    stats["preferred_decoration_methods"] = rows_to_list(dec_rows)

    return stats
