# W75 Freshness Report (20260228)

## Baseline
- run_key: `CAP-20260228-063917__verify.freshness.reconcile__Rcrcr58070`
- freshness_gates_total: `68`
- unresolved_count: `0`

## Weekly Maintenance Runs
- reconcile run_key: `CAP-20260228-064138__verify.freshness.reconcile__Rgq8h91331`
- hygiene-weekly run_key: `CAP-20260228-064229__verify.pack.run__R8hcn26199`
- hygiene-weekly summary: `pass=71 fail=0`

## Final Verification Snapshot
- hygiene-weekly run_key: `CAP-20260228-064823__verify.pack.run__R6ru838641`
- hygiene-weekly summary: `pass=71 fail=0`
- unresolved_count final: `0`

## Recovery Pass
- required: `no`
- reason: baseline + maintenance runs remained fully green.

Result: freshness unresolved did not worsen (`0 -> 0`).
