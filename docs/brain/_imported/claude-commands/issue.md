---
description: View or create GitHub issue
argument-hint: <number or "new">
allowed-tools: Bash(gh:*)
---

If argument is a number:
`gh issue view $ARGUMENTS --repo hypnotizedent/ronny-ops`

If argument is "new" or empty:
Ask the user for:
- Title
- Description of the problem or feature
- Which pillar (mint-os, infrastructure, media-stack, finance, home-assistant, immich)

Then create: `gh issue create --repo hypnotizedent/ronny-ops --title "..." --body "..." --label "<pillar>"`

Remember: NO GITHUB ISSUE = NO WORK
