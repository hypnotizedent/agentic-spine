---
loop_id: LOOP-IMMICH-ORIGINAL-INGEST-YEARLY-20260216
opened: 2026-02-16
status: active
owner: "@ronny"
severity: high
scope: immich-migration-ingest
---

# Loop Scope: Immich Original-First Yearly Upload Ingest

## Vision (Owner Intent)

Upload the old Immich/home photo corpus into the active Immich instance with strict data-integrity rules:

1. Preserve **original photos/videos** with the **most metadata**.
2. Require metadata extraction and matching signals for all images: **pHash + SHA + EXIF**.
3. Upload in chronological batches: **year-by-year, oldest to newest**.
4. Use **Immich uploads only** (managed assets); **no external libraries**.

## Canonical Source + Target

- Source corpus (legacy): `pve:/tank/immich/photos` (top-level `Photos/` and `Videos/`).
- Active target instance: VM `203` (`immich`, `100.114.101.50:2283`), compose stack in `~/immich`.
- Target storage mode: Immich-managed upload storage at `UPLOAD_LOCATION` (no persistent external library bindings).

## Non-Negotiable Rules

1. **Original-first policy:** keep true originals with highest metadata completeness; do not prefer largest file size.
2. **Metadata integrity policy:** each imported image must have SHA fingerprinting, pHash generation, and EXIF extraction present/valid in Immich.
3. **Temporal ingest policy:** process one year at a time in ascending order, with explicit review between years.
4. **Upload-only policy:** all assets must be uploaded/imported into Immich-managed storage; external libraries are disallowed for final state.
5. **Anomaly gate per year:** duplicate/date anomalies must be reviewed before advancing to the next year.

## Anti-Failure Guardrails (from legacy audit)

1. **Single target lock:** all automation must target VM 203 (`100.114.101.50:2283`) only; abort if host mismatch.
2. **No external-library path:** external library setup/scan is prohibited for this loop.
3. **No delete path during ingest:** no trash/empty/delete operations are allowed while uploads are running.
4. **No heuristic-only keeper decisions:** never decide keep/delete from filename or date alone.
5. **Evidence-first decisions only:** keeper and anomaly decisions must be backed by SHA + pHash + EXIF evidence.
6. **Upload and cleanup are separate loops:** this loop ingests; post-ingest dedupe/remediation is a later controlled loop.
7. **Year checkpoint lock:** do not advance to next year without explicit per-year review signoff.
8. **Idempotent reruns:** rerunning a year must skip existing assets cleanly and produce the same manifest/report outputs.
9. **No default destructive args:** scripts must require explicit identifiers for any mutating cleanup operation (future loop).
10. **Canonical docs lock:** one active runbook path for operator steps; archive artifacts are reference-only.

## Delivery Phases

1. **Preflight + freeze**
- Confirm source inventory snapshots (counts, size, extension mix).
- Capture backup/snapshot points before first ingest run.

2. **Original selection + metadata readiness**
- Define deterministic original-selection rules prioritizing metadata richness and authenticity.
- Define quarantine rules for metadata-poor or malformed candidates.

3. **Yearly upload pipeline**
- Build year manifests from oldest year to newest year.
- Execute uploads for a single year at a time into Immich-managed storage.

4. **Yearly review and correction**
- Review duplicate/date anomalies and metadata extraction outcomes.
- Apply corrections before opening the next year manifest.

5. **Final reconciliation**
- Verify total uploaded counts and integrity metrics.
- Confirm no external library dependency remains in active workflow.

## Background Upload Operating Model

1. **One worker, one year at a time**
- A single background uploader process handles only one year manifest per run.
- Year order is strictly ascending (oldest -> newest).

2. **Deterministic queue**
- Queue file: ordered list of years pending/importing/completed/blocked.
- State file persists current year, cursor/progress, start time, last heartbeat.

3. **Artifacts per year**
- `manifest_<year>.csv`: source file inventory + SHA + pHash + EXIF summary fields.
- `upload_<year>.log`: uploader stdout/stderr log.
- `report_<year>.md`: counts, anomalies, errors, retries, completion verdict.

4. **Health + heartbeat**
- Background worker writes heartbeat timestamp every N minutes.
- If heartbeat stale, run state is `blocked` until operator review.

5. **Stop/resume behavior**
- Stop is graceful at file boundary.
- Resume uses same manifest and skip logic; no new manifest generation mid-run.

6. **Progress visibility**
- Operator checks one status command/view to see:
- current year, percent complete, uploaded count, skipped count, error count, ETA.
- last completed year and next queued year.

## Acceptance Criteria

1. Source corpus is fully represented in Immich-managed assets (no external library dependency).
2. For imported images, SHA + pHash + EXIF are present and queryable.
3. Ingest log proves year-by-year execution oldest->newest with review checkpoints.
4. Original-selection policy is documented and enforced; "largest file wins" is not used.
5. Residual anomalies are explicitly tracked before loop close.
6. Background uploader can be stopped/resumed without duplicate ingestion or manifest drift.
7. Progress can be checked at any time from queue/state/log artifacts without attaching to process internals.

## Review Notes (2026-02-16)

- Owner clarified that legacy API key references the old home Immich instance.
- This loop anchors implementation planning and execution to the above non-negotiables.
- Legacy audit confirmed prior failure modes: mixed endpoints, external-library drift, and destructive cleanup coupling.
