#!/usr/bin/env bash
# TRIAGE: Projection files must remain generated-only with required lineage/generator markers in domain.projection.contract.yaml.
set -euo pipefail

ROOT_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="${SPINE_ROOT:-$ROOT_DEFAULT}"
if [[ ! -f "$ROOT/ops/bindings/domain.projection.contract.yaml" && -f "$ROOT_DEFAULT/ops/bindings/domain.projection.contract.yaml" ]]; then
  ROOT="$ROOT_DEFAULT"
fi
PROJECTION_CONTRACT="$ROOT/ops/bindings/domain.projection.contract.yaml"

fail() {
  echo "D339 FAIL: $*" >&2
  exit 1
}

[[ -f "$PROJECTION_CONTRACT" ]] || fail "missing projection contract: $PROJECTION_CONTRACT"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 - "$ROOT" "$PROJECTION_CONTRACT" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

root = Path(sys.argv[1]).expanduser().resolve()
contract_path = Path(sys.argv[2]).expanduser().resolve()


def load_yaml(path: Path) -> dict:
    try:
        with path.open("r", encoding="utf-8") as handle:
            doc = yaml.safe_load(handle) or {}
    except Exception as exc:
        raise ValueError(f"{path}: invalid YAML ({exc})") from exc
    if not isinstance(doc, dict):
        raise ValueError(f"{path}: YAML root must be a mapping")
    return doc


def as_list(value) -> list:
    return value if isinstance(value, list) else []


def as_dict(value) -> dict:
    return value if isinstance(value, dict) else {}


violations: list[str] = []

try:
    contract = load_yaml(contract_path)
except ValueError as exc:
    print(f"D339 FAIL: {exc}", file=sys.stderr)
    raise SystemExit(1)

entries = as_list(contract.get("projections"))
if not entries:
    print("D339 FAIL: projections[] is empty", file=sys.stderr)
    raise SystemExit(1)

seen_paths: set[str] = set()

for entry in entries:
    if not isinstance(entry, dict):
        violations.append("projection entry must be a mapping")
        continue

    proj_id = str(entry.get("id", "")).strip() or "unknown"
    output_path = str(entry.get("output_path", "")).strip()
    if not output_path:
        violations.append(f"{proj_id}: output_path missing")
        continue
    if output_path in seen_paths:
        violations.append(f"{proj_id}: duplicate output_path in contract: {output_path}")
    seen_paths.add(output_path)

    file_path = root / output_path
    if not file_path.exists():
        violations.append(f"{proj_id}: projection output missing on disk: {output_path}")
        continue

    generated_only = bool(entry.get("generated_only", False))
    if not generated_only:
        violations.append(f"{proj_id}: generated_only must be true")

    file_text = file_path.read_text(encoding="utf-8", errors="replace")
    lowered = file_text.lower()

    required_comment_markers = as_list(entry.get("required_comment_markers"))
    for marker in required_comment_markers:
        marker_text = str(marker).strip()
        if marker_text and marker_text.lower() not in lowered:
            violations.append(f"{proj_id}: missing required comment marker: {marker_text}")

    required_markers = as_list(entry.get("required_markers"))
    try:
        doc = load_yaml(file_path)
    except ValueError as exc:
        violations.append(f"{proj_id}: {exc}")
        continue

    for marker in required_markers:
        marker_map = as_dict(marker)
        key = str(marker_map.get("key", "")).strip()
        if not key:
            violations.append(f"{proj_id}: required_markers entry missing key")
            continue
        value = doc.get(key, None)
        presence = str(marker_map.get("presence", "")).strip()
        equals = marker_map.get("equals", None)

        if presence == "required":
            if value is None or (isinstance(value, str) and not value.strip()):
                violations.append(f"{proj_id}: required marker missing/empty in projection file: {key}")

        if equals is not None:
            if str(value) != str(equals):
                violations.append(
                    f"{proj_id}: marker mismatch for {key} (expected '{equals}', found '{value}')"
                )

if violations:
    for item in violations:
        print(f"D339 FAIL: {item}", file=sys.stderr)
    print(
        f"D339 FAIL: projection generated-only discipline violations ({len(violations)} finding(s))",
        file=sys.stderr,
    )
    raise SystemExit(1)

print(f"D339 PASS: generated-only projection discipline enforced (projections={len(entries)})")
PY
