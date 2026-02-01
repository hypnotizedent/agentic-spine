# TASK: Incident - customer quote route broken
MODE: SPINE
STAGE: RUN
OUTCOME: "Restore /quote route and confirm with 3 proofs."

## REQUEST
We need to debug why https://customer.mintprints.co/quote routes to the homepage.

Produce:
1) Likely root-cause buckets (route missing vs rewrite vs proxy vs wrong deployment)
2) Exact commands to run to identify which bucket is true
3) Definition of done (3 proofs)
