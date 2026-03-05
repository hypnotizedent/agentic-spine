#!/usr/bin/env bash
# TRIAGE: keep prompt lineage contract + capability triad + EXEC receipt emission in deterministic parity.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROMPT_REGISTRY="$ROOT/ops/bindings/prompt.registry.yaml"
CAP_FILE="$ROOT/ops/capabilities.yaml"
MAP_FILE="$ROOT/ops/bindings/capability_map.yaml"
DISPATCH_FILE="$ROOT/ops/bindings/routing.dispatch.yaml"
MANIFEST_FILE="$ROOT/ops/plugins/MANIFEST.yaml"
EMITTER="$ROOT/ops/plugins/evidence/bin/receipts-exec-emit"
PROMPT_STATUS="$ROOT/ops/plugins/evidence/bin/prompt-registry-status"
SCHEMA="$ROOT/ops/bindings/orchestration.exec_receipt.schema.json"

fail() {
  echo "D349 FAIL: $*" >&2
  exit 1
}

for file in "$PROMPT_REGISTRY" "$CAP_FILE" "$MAP_FILE" "$DISPATCH_FILE" "$MANIFEST_FILE" "$SCHEMA"; do
  [[ -f "$file" ]] || fail "missing required file: ${file#$ROOT/}"
done
[[ -x "$EMITTER" ]] || fail "missing emitter executable: ${EMITTER#$ROOT/}"
[[ -x "$PROMPT_STATUS" ]] || fail "missing prompt status executable: ${PROMPT_STATUS#$ROOT/}"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v jq >/dev/null 2>&1 || fail "missing dependency: jq"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

yq -e '.defaults.prompt_set_id' "$PROMPT_REGISTRY" >/dev/null 2>&1 || fail "prompt registry missing defaults.prompt_set_id"
yq -e '.defaults.version' "$PROMPT_REGISTRY" >/dev/null 2>&1 || fail "prompt registry missing defaults.version"
yq -e '.defaults.source_refs | length > 0' "$PROMPT_REGISTRY" >/dev/null 2>&1 || fail "prompt registry defaults.source_refs must be non-empty"

yq -e '.capabilities."prompt.registry.status"' "$CAP_FILE" >/dev/null 2>&1 || fail "capabilities.yaml missing prompt.registry.status"
yq -e '.capabilities."prompt.registry.status"' "$MAP_FILE" >/dev/null 2>&1 || fail "capability_map.yaml missing prompt.registry.status"
yq -e '.dispatch."prompt.registry.status"' "$DISPATCH_FILE" >/dev/null 2>&1 || fail "routing.dispatch.yaml missing prompt.registry.status"
yq -e '.plugins[] | select(.name == "evidence") | .capabilities[] | select(. == "prompt.registry.status")' "$MANIFEST_FILE" >/dev/null 2>&1 || fail "MANIFEST evidence plugin missing prompt.registry.status capability"
yq -e '.plugins[] | select(.name == "evidence") | .scripts[] | select(. == "bin/prompt-registry-status")' "$MANIFEST_FILE" >/dev/null 2>&1 || fail "MANIFEST evidence plugin missing prompt-registry-status script"

status_payload="$("$PROMPT_STATUS" --capability spine.init --json 2>/dev/null)" || fail "prompt.registry.status failed for spine.init"
jq -e '.summary.status == "ok"' >/dev/null <<<"$status_payload" || fail "prompt.registry.status returned non-ok summary"
jq -e '.prompt_lineage.prompt_set_id != ""' >/dev/null <<<"$status_payload" || fail "prompt.registry.status missing prompt_set_id"
jq -e '.prompt_lineage.version != ""' >/dev/null <<<"$status_payload" || fail "prompt.registry.status missing version"
jq -e '.prompt_lineage.source_hash | test("^([0-9a-f]{64}|none)$")' >/dev/null <<<"$status_payload" || fail "prompt.registry.status returned invalid source_hash"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
sample_json="$tmpdir/receipt.exec.json"

"$EMITTER" \
  --task-id "prompt.registry.status" \
  --terminal-id "SPINE-CONTROL-01" \
  --lane "control" \
  --status "done" \
  --files-changed "ops/bindings/prompt.registry.yaml" \
  --run-keys "CAP-20260305-010101__prompt.registry.status__Rtest0001" \
  --ready-for-verify "true" \
  --timestamp-utc "2026-03-05T01:01:01Z" \
  --prompt-set-id "spine-core-governance" \
  --prompt-version "2026-03-05.1" \
  --prompt-source-refs "AGENTS.md,CLAUDE.md" \
  --prompt-source-hash "none" \
  --prompt-source-hashes "AGENTS.md=missing,CLAUDE.md=missing" \
  --prompt-registry-path "ops/bindings/prompt.registry.yaml" \
  --prompt-resolution "defaults" \
  --json-out "$sample_json" \
  >/dev/null

python3 - "$sample_json" <<'PY'
import json
import re
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
prompt = payload.get("prompt_lineage")
if not isinstance(prompt, dict):
    raise SystemExit("missing prompt_lineage object")
required = ["prompt_set_id", "version", "source_refs", "source_hash", "registry_path", "resolution"]
for key in required:
    if key not in prompt:
        raise SystemExit(f"prompt_lineage missing required field: {key}")
if not re.match(r"^([0-9a-f]{64}|none)$", str(prompt.get("source_hash", ""))):
    raise SystemExit("prompt_lineage.source_hash invalid")
if prompt.get("resolution") not in {"capability_override", "defaults", "missing_registry", "invalid_registry"}:
    raise SystemExit("prompt_lineage.resolution invalid")
if not isinstance(prompt.get("source_hashes", {}), dict):
    raise SystemExit("prompt_lineage.source_hashes must be an object")
print("ok")
PY

echo "D349 PASS: prompt lineage contract, capability triad, and EXEC receipt emission are in parity"
