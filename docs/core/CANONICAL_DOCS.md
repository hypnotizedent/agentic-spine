# Canonical Docs Contract

> **Status:** authoritative
> **Last verified:** 2026-02-04

This repository has a single canonical documentation surface:

- **CANONICAL**: docs/core/**, docs/governance/**, docs/contracts/**
- **NON-AUTHORITATIVE** (reference only): docs/reference/**, docs/legacy/**, docs/brain/**, .archive/**

## Conflict Rule

If any document outside `docs/core`, `docs/governance`, or `docs/contracts` conflicts with them, canonical surfaces win.
If `docs/core` and `docs/governance` conflict, follow `docs/governance/SPINE.md`.

## Agent Behavior

Agents must treat anything outside `docs/core`, `docs/governance`, and `docs/contracts` as non-binding reference material.

When in doubt, prefer `docs/core`, `docs/governance`, and `docs/contracts` over any other documentation source.
