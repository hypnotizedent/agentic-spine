# Receipts Contract (Authoritative)

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
