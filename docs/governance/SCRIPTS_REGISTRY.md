# SCRIPTS REGISTRY (SPINE-NATIVE)

> **Status:** authoritative
> **Last verified:** 2026-02-04

Principle: only scripts listed here are allowed as official operator surfaces.

## Entry points
- bin/ops -> ops/ops

## Surfaces
### verify
- surfaces/verify/*.sh  (canonical health + drift checks)

## Rules
- No new script admitted without: inventory + sha256 + receipt + registry update.
- _imports/ content is read-only intake, never executed directly.
