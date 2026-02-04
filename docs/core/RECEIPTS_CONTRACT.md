# Receipts Contract (Authoritative)

> **Status:** authoritative
> **Last verified:** 2026-02-04

A receipt is a proof artifact written after every run.

## Location
receipts/sessions/<RUN_ID>/receipt.md

## Required fields
- RUN_ID
- UTC timestamp
- Command invoked
- Inputs (file paths)
- Outputs (file paths)
- Exit status (0/nonzero)
- Notes (<= 5 lines)

## Rule
If there is no receipt, the run did not happen.

A run is successful if `runs/<RUN_ID>/request.txt`, `runs/<RUN_ID>/result.txt`, and `receipts/sessions/<RUN_ID>/receipt.md` all exist; the receipt must document the provider chosen (requested vs. actual) and surface any provider error so failures are provable.
