# TASK: Customer Quote Submit (E2E evidence)
MODE: SPINE
STAGE: RUN
OUTCOME: "Capture browser+server evidence for quote submit and decide if incident exists."

## REQUEST
Do this EXACTLY and save artifacts under runs/<RUN_ID>/evidence/:

1) Write a checklist file:
   - runs/<RUN_ID>/evidence/checklist.md
   Include:
   - URL: https://customer.mintprints.co/quote
   - What to click: fill fields, click Submit
   - What evidence to capture: network request, response code/body, console errors

2) Write a placeholder decision file:
   - runs/<RUN_ID>/decision.md
   With:
   - Status: INVESTIGATING
   - Hypothesis: submit fails due to API/route/CORS/runtime

3) Print the next instruction for Terminal B:
   "Tail the customer container logs while Ronny submits the form."

Return exactly:
- RUN_ID
- Paths written
