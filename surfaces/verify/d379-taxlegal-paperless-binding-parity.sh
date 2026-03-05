#!/usr/bin/env bash
# TRIAGE: Paperless binding parity failure. Ensure ingest capability exists with contract wiring, and source lock entries have required fields (paperless_document_id, content_sha256).
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

HITS=0
CHECKS=0
err() {
  echo "  FAIL: $*" >&2
  HITS=$((HITS + 1))
}
pass() {
  CHECKS=$((CHECKS + 1))
}

# ── Check 1: Binding contract exists ─────────────────────────────────────
CONTRACT="$ROOT/ops/bindings/taxlegal.paperless.binding.contract.yaml"
if [[ -f "$CONTRACT" ]]; then
  pass
else
  err "binding contract missing: ops/bindings/taxlegal.paperless.binding.contract.yaml"
fi

# ── Check 2: Ingest capability registered in capabilities.yaml ───────────
CAP_FILE="$ROOT/ops/capabilities.yaml"
if [[ -f "$CAP_FILE" ]] && grep -q 'taxlegal\.source\.ingest:' "$CAP_FILE" 2>/dev/null; then
  pass
else
  err "taxlegal.source.ingest not found in ops/capabilities.yaml"
fi

# ── Check 3: Recall capability registered in capabilities.yaml ───────────
if [[ -f "$CAP_FILE" ]] && grep -q 'taxlegal\.source\.recall:' "$CAP_FILE" 2>/dev/null; then
  pass
else
  err "taxlegal.source.recall not found in ops/capabilities.yaml"
fi

# ── Check 4: Ingest capability registered in capability_map.yaml ─────────
MAP_FILE="$ROOT/ops/bindings/capability_map.yaml"
if [[ -f "$MAP_FILE" ]] && grep -q 'taxlegal\.source\.ingest:' "$MAP_FILE" 2>/dev/null; then
  pass
else
  err "taxlegal.source.ingest not found in ops/bindings/capability_map.yaml"
fi

# ── Check 5: Recall capability registered in capability_map.yaml ─────────
if [[ -f "$MAP_FILE" ]] && grep -q 'taxlegal\.source\.recall:' "$MAP_FILE" 2>/dev/null; then
  pass
else
  err "taxlegal.source.recall not found in ops/bindings/capability_map.yaml"
fi

# ── Check 6: Ingest script exists and is executable ──────────────────────
INGEST_SCRIPT="$ROOT/ops/plugins/taxlegal/bin/taxlegal-source-ingest"
if [[ -x "$INGEST_SCRIPT" ]]; then
  pass
else
  err "ingest script missing or not executable: ops/plugins/taxlegal/bin/taxlegal-source-ingest"
fi

# ── Check 7: Recall script exists and is executable ──────────────────────
RECALL_SCRIPT="$ROOT/ops/plugins/taxlegal/bin/taxlegal-source-recall"
if [[ -x "$RECALL_SCRIPT" ]]; then
  pass
else
  err "recall script missing or not executable: ops/plugins/taxlegal/bin/taxlegal-source-recall"
fi

# ── Check 8: Source lock entries have required fields ────────────────────
CASE_CONTRACT="$ROOT/ops/bindings/taxlegal.case.lifecycle.contract.yaml"
CASE_BASE="$ROOT/runtime/domain-state/taxlegal/cases"
if command -v yq >/dev/null 2>&1 && [[ -f "$CASE_CONTRACT" ]]; then
  case_root="$(yq -r '.case_pathing.root // ""' "$CASE_CONTRACT" 2>/dev/null || true)"
  if [[ -n "$case_root" && "$case_root" != "null" ]]; then
    CASE_BASE="$ROOT/$case_root"
  fi
fi
if [[ -d "$CASE_BASE" ]] && command -v yq &>/dev/null; then
  for lock_file in "$CASE_BASE"/*/source-registry.lock.yaml; do
    [[ -f "$lock_file" ]] || continue
    SOURCE_COUNT="$(yq -r '.sources | length' "$lock_file" 2>/dev/null || echo "0")"
    if [[ "$SOURCE_COUNT" -gt 0 ]]; then
      # Check each source entry for required fields
      for idx in $(seq 0 $((SOURCE_COUNT - 1))); do
        SRC_ID="$(yq -r ".sources[$idx].source_id // \"\"" "$lock_file" 2>/dev/null)"
        DOC_ID="$(yq -r ".sources[$idx].paperless_document_id // \"\"" "$lock_file" 2>/dev/null)"
        SHA256="$(yq -r ".sources[$idx].content_sha256 // \"\"" "$lock_file" 2>/dev/null)"

        if [[ -z "$DOC_ID" || "$DOC_ID" == "null" ]]; then
          err "source $SRC_ID in $(basename "$(dirname "$lock_file")") missing paperless_document_id"
        fi
        if [[ -z "$SHA256" || "$SHA256" == "null" ]]; then
          err "source $SRC_ID in $(basename "$(dirname "$lock_file")") missing content_sha256"
        fi
      done
    fi
    pass
  done
else
  # No cases yet — pass vacuously
  pass
fi

# ── Check 9: Contract references correct secret path ────────────────────
if [[ -f "$CONTRACT" ]] && command -v yq &>/dev/null; then
  SECRET_PATH="$(yq -r '.document_home.secret_path // ""' "$CONTRACT" 2>/dev/null)"
  if [[ "$SECRET_PATH" == "/spine/services/paperless" ]]; then
    pass
  else
    err "contract secret_path is '$SECRET_PATH', expected '/spine/services/paperless'"
  fi
else
  pass
fi

# ── Check 10: Agent registry lists both capabilities ─────────────────────
AGENT_REG="$ROOT/ops/bindings/agents.registry.yaml"
if [[ -f "$AGENT_REG" ]]; then
  if grep -q 'taxlegal\.source\.ingest' "$AGENT_REG" 2>/dev/null && \
     grep -q 'taxlegal\.source\.recall' "$AGENT_REG" 2>/dev/null; then
    pass
  else
    err "agent registry missing taxlegal.source.ingest or taxlegal.source.recall"
  fi
else
  err "agents.registry.yaml not found"
fi

# ── Result ───────────────────────────────────────────────────────────────
TOTAL=$((CHECKS + HITS))
if [[ "$HITS" -gt 0 ]]; then
  echo "D379 FAIL: $HITS/$TOTAL checks failed"
  exit 1
fi

echo "D379 PASS: taxlegal-paperless-binding-parity ($TOTAL/$TOTAL)"
exit 0
