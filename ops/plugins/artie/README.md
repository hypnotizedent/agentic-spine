# Artie Plugin

Artie plugin provides capabilities for proof generation, mockup asset management, and artwork preparation workflows.

## Capabilities

### artie.mockup.asset.promote

Promote supplier product images into the mockup registry with full provenance tracking.

**Safety:** mutating
**Approval:** manual
**Arg Protocol:** argparse

**Usage:**
```bash
./bin/ops cap run artie.mockup.asset.promote -- \
  --supplier-code SUPPLIER \
  --supplier-sku SKU \
  --view front|back \
  [--approval-state approved|review] \
  [--force]
```

**Arguments:**
- `--supplier-code`: Supplier code (sanmar, ssactive, as_colour)
- `--supplier-sku`: Exact supplier SKU
- `--view`: Mockup view (front, back)
- `--approval-state`: Approval state (approved, review) [default: review]
- `--force`: Replace existing entry if duplicate exists

**Workflow:**
1. Query suppliers module API: `GET /api/v1/suppliers/{code}/products/{sku}`
2. Extract: style_code, brand, color_name, product_family, primary_image_url
3. Download image from primary_image_url
4. Store in `runtime/domain-state/artie/mockup-assets/{supplier}/{style_code}/{color}/{view}.png`
5. Create registry entry in `ops/bindings/artie.mockup.assets.yaml` with full provenance

**Provenance Fields (V2):**
- `promoted_from_supplier: true`
- `source_url`: Original supplier image URL
- `supplier_product_id`: Supplier's product ID
- `promoted_at`: Promotion timestamp

**Example:**
```bash
./bin/ops cap run artie.mockup.asset.promote -- \
  --supplier-code sanmar \
  --supplier-sku PC54 \
  --view front \
  --approval-state review
```

**Output:**
```json
{
  "status": "success",
  "mockup_asset_id": "sanmar-pc54-white-front-v1",
  "asset_path": "/path/to/runtime/domain-state/artie/mockup-assets/sanmar/PC54/white/front.png",
  "registry_entry": {
    "mockup_asset_id": "sanmar-pc54-white-front-v1",
    "supplier": "sanmar",
    "style_code": "PC54",
    "color_name": "White",
    "product_family": "tee",
    "view": "front",
    "asset_ref": "artwork-registry/mockup-assets/sanmar/PC54/white/front.png",
    "source_type": "supplier_approved",
    "quality_state": "review",
    "placement_profile_id": "pc54.front.supplier-v1",
    "approved_at": "2026-03-10",
    "promoted_from_supplier": true,
    "source_url": "https://...",
    "supplier_product_id": "...",
    "promoted_at": "2026-03-10"
  }
}
```

## Implementation Details

**Plugin Structure:**
```
ops/plugins/artie/
├── bin/
│   └── mockup-asset-promote       # Bash wrapper
├── lib/
│   └── mockup_asset_promote.py    # Python implementation
├── tests/
│   └── test-mockup-asset-promote.md
└── README.md
```

**Dependencies:**
- Python 3
- yq (for YAML manipulation)
- Suppliers module API (VM 213:3800)
- SUPPLIERS_API_KEY (from Infisical or environment)

**API Integration:**
- Base URL: Resolved from `ops/bindings/services.health.yaml` or defaults to `http://192.168.1.213:3800`
- Endpoint: `GET /api/v1/suppliers/{supplier_code}/products/{sku}`
- Authentication: `X-API-Key` header

**Storage:**
- Registry: `ops/bindings/artie.mockup.assets.yaml`
- Assets: `runtime/domain-state/artie/mockup-assets/{supplier}/{style}/{color}/{view}.png`
  - Falls back to MINIO_ROOT if set
  - Uses asset_ref path for registry reference

**Error Handling:**
- 404: Product not found
- 401/403: Authentication failed
- Network errors: Connection/timeout failures
- Duplicate entry: Requires --force flag
- Missing required product fields: Validation error
