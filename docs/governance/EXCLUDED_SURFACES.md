---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: exclusion-rules
---

# Explicitly Excluded Surfaces

The following config surfaces are **out of scope** for spine governance and drift gates:

## Application Internals
- mint-os/**  (application-level configs, dependency artifacts)
- node_modules/**
- vendor/**
- dist/**

Rationale: App internals, not operator or system truth.

## Unowned Directories
These directories exist in the repo but no terminal role claims write authority.
They are excluded from terminal role ownership and verify lane coverage.

- **fixtures/** — Test fixtures and sample data. Not operator or system truth.
- **.archive/** — Archived artifacts from prior spine iterations. Read-only reference, not active governance.
- **.planning/** — Ephemeral planning scratch space. Not committed to governance contracts.

> Source: `ops/bindings/terminal.role.contract.yaml` (`excluded_surfaces` section)
