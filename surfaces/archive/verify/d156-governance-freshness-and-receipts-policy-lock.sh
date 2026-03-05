#!/usr/bin/env bash
# TRIAGE: Add receipts archival policy/index entry and backfill missing governance freshness metadata.
# D156: governance freshness + receipts policy lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
POLICY_BINDING="$ROOT/ops/bindings/receipts.archival.policy.yaml"
POLICY_DOC="$ROOT/docs/governance/RECEIPTS_ARCHIVAL_POLICY_V1.md"
DOCS_INDEX="$ROOT/docs/governance/_index.yaml"
GOV_DOCS_ROOT="$ROOT/docs/governance"
COVERAGE_CHECKER="$ROOT/ops/plugins/evidence/bin/receipts-index-coverage"

fail() {
  echo "D156 FAIL: $*" >&2
  exit 1
}

[[ -f "$POLICY_BINDING" ]] || fail "missing policy binding: $POLICY_BINDING"
[[ -f "$POLICY_DOC" ]] || fail "missing policy document: $POLICY_DOC"
[[ -f "$DOCS_INDEX" ]] || fail "missing governance index: $DOCS_INDEX"
[[ -d "$GOV_DOCS_ROOT" ]] || fail "missing governance docs root: $GOV_DOCS_ROOT"
[[ -x "$COVERAGE_CHECKER" ]] || fail "missing or non-executable coverage checker: $COVERAGE_CHECKER"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

coverage_json=""
if ! coverage_json="$($COVERAGE_CHECKER --policy "$POLICY_BINDING" --json 2>&1)"; then
  echo "$coverage_json" >&2
  fail "coverage checker exceeded fail thresholds"
fi

python3 - "$POLICY_BINDING" "$POLICY_DOC" "$DOCS_INDEX" "$GOV_DOCS_ROOT" "$coverage_json" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

policy_binding = Path(sys.argv[1])
policy_doc = Path(sys.argv[2])
docs_index = Path(sys.argv[3])
gov_docs_root = Path(sys.argv[4])
coverage_raw = sys.argv[5]


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


errors: list[str] = []
warnings: list[str] = []

try:
    policy = load_yaml(policy_binding)
except Exception as exc:
    print(f"D156 FAIL: policy parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(policy, dict):
    errors.append("policy binding must parse to a map")
else:
    for key in (
        "retention_classes",
        "exempt_classes",
        "archive_target_layout",
        "defaults",
        "execution_requirements",
        "coverage_thresholds",
    ):
        if key not in policy:
            errors.append(f"policy binding missing required key: {key}")

try:
    index = load_yaml(docs_index)
except Exception as exc:
    print(f"D156 FAIL: docs index parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

documents = index.get("documents")
if not isinstance(documents, list):
    errors.append("docs/governance/_index.yaml documents must be a list")
    documents = []

policy_doc_name = policy_doc.name
if not any(isinstance(doc, dict) and str(doc.get("file", "")).strip() == policy_doc_name for doc in documents):
    errors.append(f"policy doc '{policy_doc_name}' not registered in docs/governance/_index.yaml")

scanned = 0
missing_last_verified: list[str] = []

for path in sorted(gov_docs_root.rglob("*.md")):
    rel = path.relative_to(gov_docs_root)

    if rel.parts and rel.parts[0] in {"generated", "_audits"}:
        continue

    # Archive pointer docs are explicitly excluded from freshness backfill requirements.
    lowered_name = rel.name.lower()
    if "archive" in lowered_name and "pointer" in lowered_name:
        continue

    scanned += 1
    text = path.read_text(encoding="utf-8")

    if not text.startswith("---\n"):
        missing_last_verified.append(str(rel))
        continue

    end_idx = text.find("\n---", 4)
    if end_idx == -1:
        missing_last_verified.append(str(rel))
        continue

    frontmatter = text[4:end_idx + 1]
    if "last_verified:" not in frontmatter:
        missing_last_verified.append(str(rel))

if missing_last_verified:
    preview = ", ".join(missing_last_verified[:10])
    errors.append(
        f"governance docs missing last_verified: {len(missing_last_verified)} file(s)"
        + (f" (sample: {preview})" if preview else "")
    )

try:
    coverage = json.loads(coverage_raw)
except Exception as exc:
    errors.append(f"coverage checker output is not valid JSON: {exc}")
    coverage = {}

coverage_percent = coverage.get("coverage_percent")
missing_entries = coverage.get("missing_entries_count")
watermark_age = coverage.get("watermark_age_hours")
coverage_status = str(coverage.get("status", "")).strip().lower()

if coverage_status not in {"pass", "warn", "fail"}:
    errors.append(f"coverage checker returned invalid status: {coverage_status or '<empty>'}")
elif coverage_status == "fail":
    errors.append("coverage checker reported fail status")
elif coverage_status == "warn":
    for warning in coverage.get("warnings") or []:
        warnings.append(str(warning))

if errors:
    for err in errors:
        print(f"  FAIL: {err}", file=sys.stderr)
    print(f"D156 FAIL: governance freshness and receipts policy violations ({len(errors)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

warn_suffix = f" warnings={len(warnings)}" if warnings else ""
print(
    "D156 PASS: governance freshness and receipts policy lock valid "
    f"(scanned={scanned} coverage={coverage_percent}% missing={missing_entries} watermark_age_h={watermark_age}{warn_suffix})"
)
PY
