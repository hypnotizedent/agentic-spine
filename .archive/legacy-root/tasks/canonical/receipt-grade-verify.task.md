# TASK: Receipt-grade Verification Pack (Canonical)

AUDIENCE: SUPERVISOR
MODE: TALK
SESSION TYPE: SPINE
PIPELINE STAGE: VERIFY
HORIZON: NOW

OUTCOME:
"After this run, we have receipt-grade proof that the quote intake pipeline is healthy end-to-end,
including email send confirmation with Resend message id, MinIO intake landing, and presigned file access."

STOP RULES:
- No code changes.
- No config changes.
- This task is VERIFY ONLY.

## REQUEST

Run all verification proofs below and produce a final-proof.md with pass/fail summary.

REQUIRED PROOFS (all must pass):
1) Spine core health:
   - spine smoke (2 tasks pass)
   - spine status last_exit=0
   - budget OK (cap respected)

2) Customer + API uptime:
   - https://customer.mintprints.co/quote returns 200
   - https://mintprints-api.ronny.works/health returns 200

3) Email proof (dashboard-api logs):
   - A quote submission occurs during the window
   - Logs include:
     [Email] Sent new_quote notification ... to info@mintprints.com (id: <resend_message_id>)
   - AND:
     [Email] Sent customer_confirmation ... (id: <resend_message_id>)

4) MinIO intake proof:
   - A NEW object appears in customer-artwork within the window (tail last 10)

5) Quote files endpoint proof:
   - Pick the most recent quote id (or a known id supplied)
   - GET /api/quotes/:id/files returns JSON where:
     - success: true
     - files[0].url is NOT null
     - url host is https://files.ronny.works
     - bucket segment includes /customer-artwork/

ARTIFACTS:
- Evidence file per proof section.
- A final-proof.md that summarizes pass/fail with exact commands + outputs.
