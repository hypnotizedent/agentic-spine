#!/usr/bin/env bash
set -euo pipefail

# Canonical locations
SPINE_DIR="$HOME/code/agentic-spine"
EVID_BASE="$SPINE_DIR/runs"
RUN_ID="${1:-R$(date +%Y%m%d-%H%M%S)}"

EVID_DIR="$EVID_BASE/$RUN_ID/evidence"
mkdir -p "$EVID_DIR"

note() { printf "\n== %s ==\n" "$*" | tee -a "$EVID_DIR/final-proof.md"; }

# ---- Proof 1: Spine health ----
note "Proof 1: Spine health"
(
  cd "$SPINE_DIR"
  ./cli/bin/spine smoke | tee "$EVID_DIR/spine_smoke.txt"
  ./cli/bin/spine status | tee "$EVID_DIR/spine_status.txt"
  # Use a reasonable default cap; override if you want.
  SPINE_BUDGET_MAX_TOTAL_TOKENS="${SPINE_BUDGET_MAX_TOTAL_TOKENS:-120}" \
    plugins/budget/bin/budget | tee "$EVID_DIR/spine_budget.txt"
) | tee -a "$EVID_DIR/final-proof.md" >/dev/null

# ---- Proof 2: HTTP health ----
note "Proof 2: Customer + API uptime (HTTP 200)"
bash -lc 'set -euo pipefail; for u in "https://customer.mintprints.co/quote" "https://mintprints-api.ronny.works/health"; do echo "== $u"; curl -sS -o /dev/null -w "%{http_code}\n" "$u" || true; done' \
  | tee "$EVID_DIR/http_health.txt" | tee -a "$EVID_DIR/final-proof.md" >/dev/null

# ---- Proof 3: Dashboard API email logs (tailing is done in Terminal B) ----
note "Proof 3: Email proof (dashboard-api logs)"
cat > "$EVID_DIR/terminal_b_watch.md" <<'MD'
Terminal B (watch while submitting a quote):

ssh docker-host "docker logs -f mint-os-dashboard-api --since 2m 2>&1 | grep -E '\[Email\]|Sent new_quote|Sent customer_confirmation|\\(id: '"
MD
cat "$EVID_DIR/terminal_b_watch.md" | tee -a "$EVID_DIR/final-proof.md" >/dev/null

# ---- Proof 4: MinIO tail ----
note "Proof 4: MinIO tail (customer-artwork)"
ssh docker-host 'docker exec minio mc ls local/customer-artwork/ --recursive | tail -10' \
  | tee "$EVID_DIR/minio_tail_customer_artwork.txt" | tee -a "$EVID_DIR/final-proof.md" >/dev/null

# ---- Proof 5: Quote files endpoint spot-check ----
note "Proof 5: Quote files endpoint (presigned url present)"
cat > "$EVID_DIR/quote_files_spotcheck.md" <<'MD'
Spot-check command (fill QUOTE_ID):

QUOTE_ID=<paste_quote_numeric_id>
curl -sS "https://mintprints-api.ronny.works/api/quotes/${QUOTE_ID}/files" | jq .

PASS CRITERIA:
- .success == true
- .files[0].url != null
- url contains "https://files.ronny.works/customer-artwork/"
MD
cat "$EVID_DIR/quote_files_spotcheck.md" | tee -a "$EVID_DIR/final-proof.md" >/dev/null

note "RUN_ID=$RUN_ID"
echo "Evidence directory: $EVID_DIR" | tee -a "$EVID_DIR/final-proof.md" >/dev/null
