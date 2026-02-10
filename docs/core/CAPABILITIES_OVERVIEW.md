# CAPABILITIES_OVERVIEW (core)

> **Status:** authoritative
> **Last verified:** 2026-02-10

This document defines **what agents are allowed to do** and **how** they do it inside `agentic-spine`.

## Canonical rule
All privileged actions are performed only through **governed capabilities**:

- `./bin/ops cap run <capability>`

No direct execution of legacy scripts. No manual credential handling in chat.

## Capability registry (SSOT)
The full, canonical capability registry is:

- `ops/capabilities.yaml`

Discovery:

```bash
./bin/ops cap list
./bin/ops cap show <capability>
```

Enforcement:
- `spine.verify` includes a capabilities metadata drift gate (D63) to prevent incomplete/invalid capability entries from landing.

### Stack alignment
For stack inventory context, see `docs/core/STACK_ALIGNMENT.md`.
The canonical stack list is `docs/governance/STACK_REGISTRY.yaml`.

## Prohibitions
- No printing or echoing secrets.
- No "one-off" shell commands that change infrastructure outside governed capabilities.
- No alternate runtimes, mailrooms, receipts, or HOME drift roots.

## Secrets canon

This repo ships a spine-native secrets surface. It is NOT dependent on the workbench monolith.

**Binding (non-secret):**
- `ops/bindings/secrets.binding.yaml` (Infisical api_url + project + environment)

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
