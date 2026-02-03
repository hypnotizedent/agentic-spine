# Secrets Binding (SSOT)

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
- Future work (not yet implemented): `secrets.exec` injects required secrets into a single command without printing values.
