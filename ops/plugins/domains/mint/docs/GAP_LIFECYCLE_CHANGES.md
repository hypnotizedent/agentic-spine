# Gap Lifecycle Management Changes

## Overview

Modified `quote-prepare` to implement proper gap lifecycle management, making the capability truly resumable. Gaps are now removed when conditions improve or change, preventing accumulation of stale gaps across repeated runs.

## Changes Made

### 1. Customer Resolution Gap Removal

**Location:** Lines 173-283 in `ops/plugins/domains/mint/bin/quote-prepare`

**Before:**
- Gaps were only added, never removed
- Repeated runs accumulated duplicate gaps
- No transition logic when customer state changed

**After:**
- When `identity_state` is already `resolved`: removes ALL customer-related gaps
- When customer resolves successfully (`exact_match`/`normalized_match`): removes ALL customer-related gaps
- When customer state changes (e.g., `new_customer` → `ambiguous`): removes gaps of other customer types
- Each customer condition preserves only its specific gap type

**Gap Types Managed:**
- `customer_new` - New customer requires registration
- `customer_ambiguous` - Multiple customer matches found
- `customer_unresolved` - Customer resolution failed or service unavailable

### 2. Stock Check Gap Removal

**Location:** Lines 285-324 in `ops/plugins/domains/mint/bin/quote-prepare`

**Before:**
- `stock_identifiers_missing` gaps accumulated on every run
- No removal when stock check completed

**After:**
- When `stock_check_state` is `completed`: removes ALL stock-related gaps
- When service is available but identifiers missing: removes other stock gap types, keeps `stock_identifiers_missing`
- When service is unavailable: removes stale gaps (transient condition doesn't warrant persistent gap)

**Gap Types Managed:**
- `stock_identifiers_missing` - Line items need canonical product codes
- Other stock gap types (when added in future)

### 3. Pricing Gap Removal

**Location:** Lines 326-366 in `ops/plugins/domains/mint/bin/quote-prepare`

**Before:**
- `pricing_inputs_insufficient` gaps accumulated on every run
- No removal when pricing completed

**After:**
- When `pricing_state` is `completed`: removes ALL pricing-related gaps
- When service is available but inputs insufficient: removes other pricing gap types, keeps `pricing_inputs_insufficient`
- When service is unavailable: removes stale gaps (transient condition)

**Gap Types Managed:**
- `pricing_inputs_insufficient` - Line items need complete pricing inputs
- Other pricing gap types (when added in future)

## Implementation Pattern

All gap removal uses regex pattern matching to target gap families:

```bash
# Remove all gaps of a specific prefix
yq -i 'del(.open_gaps[] | select(.gap_type | test("^customer_")))' "$PACKET_FILE"

# Remove all gaps except a specific type
yq -i 'del(.open_gaps[] | select(.gap_type | test("^customer_") and .gap_type != "customer_new"))' "$PACKET_FILE"
```

## Testing

**Test Script:** `ops/plugins/domains/mint/tests/test-quote-resumability.sh`

**Tests:**
1. **Gap removal when resolved** - Verifies gaps are removed when customer identity becomes resolved
2. **No duplicate gaps** - Verifies repeated runs don't create duplicate gaps (≤1 customer gap after 3 runs)
3. **Gap type changes** - Verifies old gap types are removed when conditions change

**Test Results:** All 3 tests PASS

## Benefits

1. **True Resumability:** Operators can re-run `quote-prepare` on same packet without gap pollution
2. **Accurate State:** `open_gaps` array reflects current truth, not historical accumulation
3. **Clean State Transitions:** Gap type changes when underlying condition changes
4. **Operator Confidence:** No manual gap cleanup needed between runs

## Non-Breaking Changes

- Receipt tracking unchanged
- Packet index logic unchanged
- Integration call patterns unchanged
- State determination logic unchanged (but more accurate with clean gaps)

## Next Steps (Subwave B)

Gap lifecycle now honest. Next wave will add:
- Real customer resolution integration (when customer-resolve.ts is accessible)
- Real stock check integration (when line items have canonical identifiers)
- Real pricing integration (when line items have complete decoration inputs)

These integration improvements will work correctly with the gap lifecycle foundation.
