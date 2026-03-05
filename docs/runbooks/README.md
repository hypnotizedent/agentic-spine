# Spine Runbooks

Operational recovery runbooks by domain. These are execution docs (not governance specs).

Use this triage order:

1. Query telemetry: `./bin/ops cap run spine.log.query -- --since-hours 24 --status failed`
2. Run fast verify: `./bin/ops cap run verify.run -- fast`
3. Run domain verify: `./bin/ops cap run verify.run -- domain <domain>`
4. Follow the domain runbook in `docs/runbooks/domains/<domain>.md`

