#!/usr/bin/env bash
# TRIAGE: Update last_reviewed/last_verified dates on stale SSOTs (max 21 days).
# D58: SSOT freshness lock
# Fails when any SSOT in the registry has a last_reviewed date
# older than SSOT_FRESHNESS_DAYS (default: 21).
#
# Reads: docs/governance/SSOT_REGISTRY.yaml
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY="$SP/docs/governance/SSOT_REGISTRY.yaml"
THRESHOLD="${SSOT_FRESHNESS_DAYS:-21}"

[[ -f "$REGISTRY" ]] || { echo "  D58 FAIL: SSOT_REGISTRY.yaml not found" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "  D58 FAIL: python3 not found" >&2; exit 1; }

python3 - "$REGISTRY" "$SP/docs/governance" "$SP/ops/bindings" "$THRESHOLD" <<'PY'
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml

registry_path = Path(sys.argv[1])
gov_dir = Path(sys.argv[2])
bindings_dir = Path(sys.argv[3])
threshold = int(sys.argv[4])
now_epoch = int(datetime.now(timezone.utc).timestamp())

failures = []
warnings = []
stale_ssot_count = 0
stale_doc_count = 0
stale_binding_count = 0
missing_last_verified_count = 0


def parse_epoch_date(raw):
    if raw is None:
        return None
    value = str(raw).strip()
    if not value or value.lower() == "null":
        return None
    value = value.replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(value)
    except Exception:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return int(dt.timestamp())


with registry_path.open("r", encoding="utf-8") as handle:
    registry = yaml.safe_load(handle) or {}

for row in registry.get("ssots") or []:
    if not isinstance(row, dict):
        continue
    reviewed = row.get("last_reviewed")
    reviewed_epoch = parse_epoch_date(reviewed)
    if reviewed_epoch is None:
        continue
    age_days = (now_epoch - reviewed_epoch) // 86400
    if age_days > threshold:
        stale_ssot_count += 1
        failures.append(
            f"{row.get('id', 'unknown')}: last_reviewed={reviewed} ({age_days}d ago, threshold={threshold}d)"
        )

if gov_dir.is_dir():
    status_re = re.compile(r"^status:\s*(.+?)\s*$")
    lv_re = re.compile(r"^last_verified:\s*(.+?)\s*$")
    for docfile in sorted(gov_dir.glob("*.md")):
        with docfile.open("r", encoding="utf-8", errors="ignore") as handle:
            lines = [line.rstrip("\n") for _, line in zip(range(16), handle)]

        status = None
        for line in lines[:10]:
            m = status_re.match(line.strip())
            if m:
                status = m.group(1).strip().strip("\"'")
                break
        if status != "authoritative":
            continue

        lv = None
        for line in lines[:15]:
            m = lv_re.match(line.strip())
            if m:
                lv = m.group(1).strip().strip("\"'")
                break

        if not lv or lv.lower() == "null":
            missing_last_verified_count += 1
            warnings.append(f"{docfile.name} (authoritative) missing last_verified")
            continue

        lv_epoch = parse_epoch_date(lv)
        if lv_epoch is None:
            continue

        lv_age = (now_epoch - lv_epoch) // 86400
        if lv_age > threshold:
            stale_doc_count += 1
            failures.append(
                f"{docfile.name}: last_verified={lv} ({lv_age}d ago, threshold={threshold}d)"
            )

exempt_files = set()
exemptions_file = bindings_dir / "binding.freshness.exemptions.yaml"
if bindings_dir.is_dir() and exemptions_file.is_file():
    with exemptions_file.open("r", encoding="utf-8") as handle:
        exemptions = yaml.safe_load(handle) or {}
    for row in exemptions.get("exempt") or []:
        if isinstance(row, dict):
            name = (row.get("file") or "").strip()
            if name:
                exempt_files.add(name)

    updated_re = re.compile(r"^updated:\s*(.+?)\s*$")
    for binding in sorted(bindings_dir.glob("*.yaml")):
        bname = binding.name
        if bname == "binding.freshness.exemptions.yaml" or bname in exempt_files:
            continue

        with binding.open("r", encoding="utf-8", errors="ignore") as handle:
            lines = [line.rstrip("\n") for _, line in zip(range(20), handle)]

        updated = None
        for line in lines:
            m = updated_re.match(line.strip())
            if m:
                updated = m.group(1).strip().strip("\"'")
                break
        if not updated or updated.lower() == "null":
            continue

        updated_epoch = parse_epoch_date(updated)
        if updated_epoch is None:
            continue

        updated_age = (now_epoch - updated_epoch) // 86400
        if updated_age > threshold:
            stale_binding_count += 1
            failures.append(
                f"{bname}: updated={updated} ({updated_age}d ago, threshold={threshold}d)"
            )

for w in warnings:
    print(f"  WARN: {w}", file=sys.stderr)

if missing_last_verified_count > 0:
    print(
        f"  {missing_last_verified_count} authoritative docs missing last_verified (warning only)",
        file=sys.stderr,
    )

for f in failures:
    print(f"  D58 FAIL: {f}", file=sys.stderr)

if stale_ssot_count > 0:
    print(
        f"  {stale_ssot_count} SSOTs exceed freshness threshold of {threshold} days",
        file=sys.stderr,
    )
if stale_doc_count > 0:
    print(f"  {stale_doc_count} authoritative docs exceed freshness threshold", file=sys.stderr)
if stale_binding_count > 0:
    print(f"  {stale_binding_count} normative bindings exceed freshness threshold", file=sys.stderr)

if failures:
    print("D58 FAIL: SSOT freshness violations detected", file=sys.stderr)
    raise SystemExit(1)

print(f"D58 PASS: SSOT freshness valid (threshold={threshold}d)")
PY
