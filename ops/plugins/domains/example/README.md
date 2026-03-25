# Example Domain Plugin

This is a skeleton domain plugin for reference. Copy this directory to create your own domain.

## Structure

- `bin/` — Domain capability scripts (registered in `ops/capabilities.yaml`)
- `contracts/` — Domain-specific authority contracts
- `tests/` — Domain verification gates

## Registration

After creating your domain scripts, register them in:
- `ops/capabilities.yaml` — capability definitions
- `ops/bindings/capability_map.yaml` — capability-to-domain mapping
