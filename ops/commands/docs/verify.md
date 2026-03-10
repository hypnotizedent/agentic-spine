---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: slash-command
---

# /verify - Canonical Verify

Run canonical spine verification and summarize failures with evidence.

## Actions

1. Run `./bin/ops cap run spine.verify` (canonical drift lock).
2. If failures exist, cite failing gate IDs and receipt/output paths.
3. For each failing gate, read the TRIAGE hint from the output.
4. Optionally run `./bin/ops verify --core-only` for compatibility checks.

## Output

Report:
- `Canonical Status`: PASS/FAIL
- `Failing Gates`: ordered by severity, with TRIAGE hints
- `Evidence`: receipt and output file paths
- `Next Action`: exact fix sequence based on triage hints
