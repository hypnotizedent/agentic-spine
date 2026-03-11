---
description: View or create GitHub issue
argument-hint: <number or "new">
allowed-tools: Bash(gh:*)
---

If argument is a number:
`gh issue view $ARGUMENTS --repo hypnotizedent/agentic-spine`

If argument is "new" or empty:
Ask the user for:
- Title
- Description of the problem or feature
- Which pillar (mint-os, infrastructure, media-stack, finance, home-assistant, immich)

Then create: `gh issue create --repo hypnotizedent/agentic-spine --title "..." --body "..." --label "<pillar>"`

GitHub issues are optional. Mailroom loops + receipts are the canonical work state.
