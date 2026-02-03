# Canonical Docs Contract

This repository has a single canonical documentation surface:

- **CANONICAL**: docs/core/**
- **NON-AUTHORITATIVE** (reference only): docs/legacy/**, docs/extract/**, .archive/**

## Conflict Rule

If any document outside `docs/core` conflicts with `docs/core`, **docs/core wins**.

## Agent Behavior

Agents must treat anything outside `docs/core` as non-binding reference material.

When in doubt, prefer `docs/core` over any other documentation source.
