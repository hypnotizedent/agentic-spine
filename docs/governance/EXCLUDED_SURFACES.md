---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-05
scope: exclusion-rules
---

# Explicitly Excluded Surfaces

The following config surfaces are **out of scope** for /Code admission:

- mint-os/**  (application-level configs, dependency artifacts)
- node_modules/**
- vendor/**
- dist/**

Rationale:
These represent app internals, not operator or system truth.
