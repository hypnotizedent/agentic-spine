# Test: artie.mockup.asset.promote

## Manual Test Plan

### Setup
```bash
# Ensure suppliers module is running on VM 213
# Ensure SUPPLIERS_API_KEY is available via Infisical or environment

export SPINE_ROOT=/Users/ronnyworks/code/agentic-spine
```

### Test Case 1: Promote supplier image to review state
```bash
./bin/ops cap run artie.mockup.asset.promote -- \
  --supplier-code sanmar \
  --supplier-sku PC54 \
  --view front \
  --approval-state review
```

Expected:
- Queries `GET /api/v1/suppliers/sanmar/products/PC54`
- Downloads primary_image_url
- Saves to `runtime/domain-state/artie/mockup-assets/sanmar/PC54/{color}/front.png`
- Creates registry entry with:
  - `mockup_asset_id: sanmar-pc54-{color}-front-v1`
  - `promoted_from_supplier: true`
  - `quality_state: review`
  - `source_url: {primary_image_url}`
  - `supplier_product_id: {product_id}`

### Test Case 2: Promote to approved state
```bash
./bin/ops cap run artie.mockup.asset.promote -- \
  --supplier-code ssactive \
  --supplier-sku SP-2000 \
  --view back \
  --approval-state approved
```

Expected:
- Same as above but `quality_state: approved`
- `approved_by: {SPINE_TERMINAL_NAME or USER}`

### Test Case 3: Force replace existing entry
```bash
./bin/ops cap run artie.mockup.asset.promote -- \
  --supplier-code sanmar \
  --supplier-sku PC54 \
  --view front \
  --approval-state approved \
  --force
```

Expected:
- Replaces existing mockup_asset_id entry in registry

### Test Case 4: Error - product not found
```bash
./bin/ops cap run artie.mockup.asset.promote -- \
  --supplier-code sanmar \
  --supplier-sku NONEXISTENT \
  --view front
```

Expected:
- Exit with error: "Product not found: sanmar/NONEXISTENT"

### Test Case 5: Error - duplicate without --force
```bash
# Run same command twice without --force
./bin/ops cap run artie.mockup.asset.promote -- \
  --supplier-code sanmar \
  --supplier-sku PC54 \
  --view front

# Second run should fail
./bin/ops cap run artie.mockup.asset.promote -- \
  --supplier-code sanmar \
  --supplier-sku PC54 \
  --view front
```

Expected:
- Second run exits with: "Duplicate mockup_asset_id exists: sanmar-pc54-{color}-front-v1. Use --force to replace."

## Validation Checklist

- [ ] Script accepts all required args (--supplier-code, --supplier-sku, --view)
- [ ] Script queries suppliers API correctly
- [ ] Image downloads to correct path
- [ ] Registry entry has all V2 provenance fields
- [ ] Duplicate detection works
- [ ] --force flag allows replacement
- [ ] --approval-state controls quality_state
- [ ] approved_by is set when approval_state=approved
- [ ] Error handling for 404, 401, network errors works
- [ ] SUPPLIERS_API_KEY resolution from Infisical works
