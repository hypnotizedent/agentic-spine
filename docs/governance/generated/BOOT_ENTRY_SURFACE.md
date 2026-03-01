# Boot Entry Surface (Generated)

Source contract: `ops/bindings/entry.boot.surface.contract.yaml`

## Mandatory Startup Block

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.start
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
