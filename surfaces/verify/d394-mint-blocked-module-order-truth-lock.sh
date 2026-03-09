#!/usr/bin/env bash
# TRIAGE: Prevent blocked modules from violating canonical order truth authority.
# D394: mint-blocked-module-order-truth-lock
# Enforces order/quote/revision/artwork-binding model discipline before unblocking orders/quotes/digital-proofs.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
MINT_ROOT="${MINT_MODULES_ROOT:-$HOME/code/mint-modules}"
ORDER_TRUTH_AUTHORITY="$ROOT/ops/bindings/mint.order.truth.authority.yaml"
LIFECYCLE_AUTHORITY="$ROOT/ops/bindings/mint.module.lifecycle.authority.yaml"

fail() {
  echo "D394 FAIL: $*" >&2
  exit 1
}

# Verify authority files exist
[[ -f "$ORDER_TRUTH_AUTHORITY" ]] || fail "missing canonical order truth authority: $ORDER_TRUTH_AUTHORITY"
[[ -f "$LIFECYCLE_AUTHORITY" ]] || fail "missing module lifecycle authority: $LIFECYCLE_AUTHORITY"
[[ -d "$MINT_ROOT" ]] || fail "missing mint-modules repo: $MINT_ROOT"

command -v rg >/dev/null 2>&1 || fail "missing required dependency: rg"
command -v yq >/dev/null 2>&1 || fail "missing required dependency: yq"

BLOCKED_MODULES=("orders" "quotes" "digital-proofs")

# Rule 1: Blocked modules must acknowledge lifecycle authority state
for module in "${BLOCKED_MODULES[@]}"; do
  module_contract="$MINT_ROOT/$module/module.contract.yaml"
  [[ -f "$module_contract" ]] || fail "$module missing module.contract.yaml"

  # Check if module.contract.yaml status is inconsistent with being blocked
  module_status=$(yq -r '.status // "unknown"' "$module_contract")

  # digital-proofs wrongly claims "deployed" status
  if [[ "$module" == "digital-proofs" && "$module_status" == "deployed" ]]; then
    fail "$module claims status=deployed but lifecycle authority declares it blocked_on_order_truth"
  fi

  # orders/quotes should not claim active/deployed status while blocked
  if [[ "$module" == "orders" || "$module" == "quotes" ]]; then
    if [[ "$module_status" == "active" || "$module_status" == "deployed" ]]; then
      fail "$module claims status=$module_status but lifecycle authority declares it blocked_on_order_truth"
    fi
  fi
done

# Rule 2: orders SPEC must not conflate quote state with order lifecycle
orders_spec="$MINT_ROOT/orders/SPEC.md"
if [[ -f "$orders_spec" ]]; then
  # Check for state machine that uses "quote" as an order state
  if rg -q '^\s*-\s*.*quote\s*->\s*approved' "$orders_spec"; then
    fail "orders SPEC.md uses 'quote' as an order lifecycle state, violates canonical order truth (order != quote)"
  fi
fi

# Rule 3: quotes SPEC must not use "converted" state that implies quote becomes order
quotes_spec="$MINT_ROOT/quotes/SPEC.md"
if [[ -f "$quotes_spec" ]]; then
  # "converted" suggests quote transforms into order, but canonical authority says quotes are DERIVED from orders
  if rg -q 'converted' "$quotes_spec"; then
    fail "quotes SPEC.md uses 'converted' state, violates canonical authority (quotes are derived FROM orders, not converted TO orders)"
  fi
fi

# Rule 4: README files must not conflate artwork jobs with orders
orders_readme="$MINT_ROOT/orders/README.md"
if [[ -f "$orders_readme" ]]; then
  # Check for "jobs lifecycle" language that conflates jobs with orders
  if rg -qi 'jobs?\s+lifecycle' "$orders_readme"; then
    fail "orders README.md conflates 'jobs lifecycle' with orders domain (canonical authority: artwork_job_id != order_id)"
  fi
fi

# Rule 5: digital-proofs must acknowledge order_line_id and artwork_binding in contract
# ProofJob input must use canonical order_line_id, not raw folder paths
proofs_spec="$MINT_ROOT/digital-proofs/SPEC.md"
if [[ -f "$proofs_spec" ]]; then
  # Verify ProofJob contract mentions order_id (already present)
  rg -q '"order_id":\s*"string"' "$proofs_spec" || fail "digital-proofs SPEC.md ProofJob missing canonical order_id field"

  # Verify line_item field acknowledges canonical naming (should be order_line_id or acknowledge artwork_binding)
  if ! rg -q 'order_line_id|artwork_binding' "$proofs_spec"; then
    fail "digital-proofs SPEC.md must acknowledge order_line_id or artwork_binding (cannot rely on folder path heuristics)"
  fi
fi

# Rule 6: No primary use of forbidden legacy aliases in blocked module contracts
# Check SPEC and API docs for primary use of visual_id, job_order_reference, job_number
for module in "${BLOCKED_MODULES[@]}"; do
  for doc in "$MINT_ROOT/$module/SPEC.md" "$MINT_ROOT/$module/API.md"; do
    [[ -f "$doc" ]] || continue

    # Look for use as primary identifier (in type definitions, required fields, primary keys)
    # Allow as evidence/alias but not as canonical business identity
    if rg -q '^\s*-\s*`?visual_id`?(\s|:)|"visual_id":\s*"(uuid|string|primary)"' "$doc"; then
      fail "$(basename "$doc") in $module uses visual_id as primary identifier (canonical authority: use order_id, not visual_id)"
    fi

    if rg -q '^\s*-\s*`?job_order_reference`?(\s|:)|"job_order_reference":\s*"(uuid|string|primary)"' "$doc"; then
      fail "$(basename "$doc") in $module uses job_order_reference as primary identifier (canonical authority: evidence linkage only)"
    fi

    if rg -q '^\s*-\s*`?job_number`?(\s|:)|"job_number":\s*"(uuid|string|primary)"' "$doc"; then
      fail "$(basename "$doc") in $module uses job_number as primary identifier (canonical authority: artwork operational alias only)"
    fi
  done
done

# Rule 7: Verify canonical entity separation is acknowledged
# Check that blocked modules reference the order truth authority OR acknowledge canonical entities
for module in "${BLOCKED_MODULES[@]}"; do
  module_dir="$MINT_ROOT/$module"

  # At minimum, one of these acknowledgments must exist:
  # 1. Reference to order truth authority file
  # 2. Explicit mention of order_revision_id or pricing_snapshot_id (shows awareness of canonical model)
  # 3. DECISION.md that acknowledges blocking status

  has_authority_ref=false
  has_canonical_entities=false

  if rg -q 'mint\.order\.truth\.authority\.yaml|order_revision_id|pricing_snapshot_id' \
    "$module_dir/SPEC.md" "$module_dir/API.md" "$module_dir/DECISION.md" "$module_dir/README.md" 2>/dev/null; then
    has_canonical_entities=true
  fi

  if [[ "$has_canonical_entities" == "false" ]]; then
    fail "$module docs do not acknowledge canonical order truth entities (order_revision_id, pricing_snapshot_id, or reference to authority file)"
  fi
done

echo "D394 PASS: Blocked modules conform to canonical Mint order truth authority"
