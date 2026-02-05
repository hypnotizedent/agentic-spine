# Canonical Docs Contract

> **Status:** authoritative
> **Last verified:** 2026-02-04

This repository has a single canonical documentation surface:

- **CANONICAL**: docs/core/**, docs/governance/**
- **NON-AUTHORITATIVE** (reference only): docs/legacy/**, docs/brain/**, .archive/**

## Conflict Rule

If any document outside `docs/core` or `docs/governance` conflicts with them, **core/governance wins**.
If `docs/core` and `docs/governance` conflict, follow `docs/governance/SSOT_REGISTRY.yaml`.

## Agent Behavior

Agents must treat anything outside `docs/core` and `docs/governance` as non-binding reference material.

When in doubt, prefer `docs/core` and `docs/governance` over any other documentation source.
