# BOOT ENTRY SURFACE (generated)
source_contract: ops/bindings/entry.boot.surface.contract.yaml
contract_updated: 2026-03-22
startup_command_count: 2
post_work_verify_count: 2
release_certification_count: 1

## Mandatory Startup Block

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.v3.attach -- --allow-no-loop
```

## Post-Work Verify

```bash
./bin/ops cap run verify.run -- fast
./bin/ops cap run verify.run -- domain <domain>
```

## Release Certification

```bash
./bin/ops cap run verify.release.run
```
