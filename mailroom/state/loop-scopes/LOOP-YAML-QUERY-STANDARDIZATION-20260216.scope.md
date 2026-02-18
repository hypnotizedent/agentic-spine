---
loop_id: LOOP-YAML-QUERY-STANDARDIZATION-20260216
opened: 2026-02-16
status: closed
closed_at: "2026-02-18"
owner: "@ronny"
severity: medium
scope: yaml-query-standardization
---

# Loop Scope: YAML Query Standardization (yq → yaml_query + jq)

## Vision (Owner Intent)

Replace bare `yq` calls with a canonical `yaml_query` helper that bridges YAML→JSON via `yq -o=json` and delegates all expression logic to `jq`. Eliminates the boolean-false trap, null-coalescing surprises, and `select()` vs `has()` divergence across 262 call sites.

## Deliverables

1. **`ops/lib/yaml.sh`** — shared helper exposing `yaml_query` and `yaml_query -e`
   - `yq -o=json` for conversion, `jq -r` for expression evaluation
   - Normalizes `"null"` → `""`, preserves boolean `false` literally
   - `-e` flag for existence checks (exit code 0/1)
   - **STATUS: COMPLETE (2026-02-18)**

2. **Phase 1 migration** — convert the 3 highest-value libs:
   - `ops/lib/resolve-policy.sh` (22 yq calls, boolean trap central) — **MIGRATED**
   - `ops/lib/registry.sh` (service discovery lookups) — **MIGRATED**
   - `ops/commands/cap.sh` (capability metadata loading) — **MIGRATED (simple field reads)**
   - **STATUS: COMPLETE (2026-02-18)**

3. **Drift gate** — new gate enforcing `yaml_query` usage in new/modified scripts
   - Allowlist existing files for gradual backfill
   - Grep for bare `yq e` / `yq -r` outside the helper

4. **Backfill** — organic migration of drift gates and caps as files are touched

## Out of Scope

- Removing `yq` entirely (still needed as the YAML→JSON bridge)
- Bulk-converting all 262 files in one pass
- Changing the `yq` vendor or version

## Known Risks

- macOS bash 3.2 compatibility (no associative arrays) — helper must be POSIX-safe
- `yq -o=json` adds a conversion step — negligible for single-file reads, test with large YAMLs
- Gate allowlist maintenance until backfill completes

## Context

- Discussion: 2026-02-16 session (yq expression reliability on macOS)
- Related memory: MEMORY.md gotchas (yq boolean, has() vs select, Edit replace_all)

## Closeout Evidence (2026-02-18)

- Helper landed: `ops/lib/yaml.sh` present with `yaml_query` and `yaml_query -e`.
- Phase-1 migration verified in target libs:
  - `ops/lib/resolve-policy.sh`: 23 `yaml_query` calls
  - `ops/lib/registry.sh`: 2 `yaml_query` calls
  - `ops/commands/cap.sh`: 19 `yaml_query` calls (simple field reads migrated)
- Lane certification pre/post:
  - Pre-write lane gate: `CAP-20260217-232052__lane.standard.run__Rqsla40071`
  - AOF post-mutation verify gate reused for session cert baseline: `CAP-20260217-233219__verify.core.run__Rdvxm21297`, `CAP-20260217-233301__verify.domain.run__Rcpzf34367`
- Closure scope for this loop intentionally bounded to helper + phase-1 migration deliverables.
