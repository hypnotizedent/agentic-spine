# TASK: Receipt Smoke (deterministic check)
MODE: SPINE
STAGE: SMOKE
OUTCOME: "Verify that the receipt pipeline captures a simple 3-line echo."

## REQUEST
Return exactly three lines. Each line must match the text below (no quotes):
1) RECEIPT SMOKE PASS
2) NO EXTRA LINES
3) DONE
