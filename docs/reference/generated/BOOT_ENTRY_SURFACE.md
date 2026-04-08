# BOOT ENTRY SURFACE (generated)
authority_state: projection
projection_of: docs/governance/SESSION_PROTOCOL.md
source_contract: docs/governance/SESSION_PROTOCOL.md
contract_updated: 2026-04-07
startup_command_count: 2
post_work_verify_count: 2
release_certification_count: 1

## Mandatory Startup Block

```bash
cd ~/code/agentic-spine
cat NORTH_STAR.md docs/governance/SPINE.md docs/governance/SESSION_PROTOCOL.md
./bin/ops status --json
./bin/ops verify --core-only
./bin/ops cap list
```

## Post-Work Verify

```bash
./bin/ops verify --core-only
```

## Release Certification

```bash
./bin/ops verify --core-only
```
