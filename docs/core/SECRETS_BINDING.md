# Secrets Binding (SSOT)

> **Status:** authoritative
> **Last verified:** 2026-02-04

Purpose: eliminate "which Infisical project?" confusion by defining ONE canonical binding for this spine.

## Rule
Agents never choose an Infisical project or environment.
They only read the spine binding and use governed capabilities.

## Binding source
Machine SSOT: `ops/bindings/secrets.binding.yaml`

This file contains ONLY non-secret metadata:
- provider
- api_url
- project (slug/name)
- environment
- base_path
- mapping (project -> path)

Auth (tokens / client secrets) is operator-provided via environment and must never be committed.

## Operational expectations
- `./bin/ops cap run secrets.binding` prints the active binding (non-secret).
- `./bin/ops cap run secrets.auth.status` returns STOP unless Infisical auth is configured.
- `./bin/ops cap run secrets.exec -- <cmd>` injects required secrets into a single command without printing values.

## Secrets canon

This repo ships a spine-native secrets surface. It is NOT dependent on ronny-ops.

**Binding (non-secret):**
- `ops/bindings/secrets.binding.yaml` (Infisical api_url + project + environment)
- `ops/bindings/cloudflare.inventory.yaml` (Cloudflare zone/tunnel metadata is now part of the core binding registry)

**Auth (operator-owned, outside repo):**
- `~/.config/infisical/credentials` (perm 600)
- Use `./bin/ops cap run secrets.auth.load` to validate and print the `source ...` one-liner.
- Use `./bin/ops cap run secrets.auth.status` to confirm auth vars are present (no values printed).

**Exec (inject without printing):**
- `./bin/ops cap run secrets.exec -- <cmd>`

**Capabilities:**
- `secrets.binding` (STOP=2 if binding incomplete)
- `secrets.auth.load` (STOP=2 if creds file missing/perm wrong; prints source line)
- `secrets.auth.status` (STOP=2 if auth vars missing)
- `secrets.exec` (STOP=2 if preconditions missing)
- `secrets.status` (summary check)

**Rule (standing):**
Any capability that touches an API must enforce `secrets.binding` + `secrets.auth.status` as preconditions (STOP=2 if missing) and be runnable only via `./bin/ops cap run ...`.
