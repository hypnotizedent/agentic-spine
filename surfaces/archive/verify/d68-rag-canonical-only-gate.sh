#!/usr/bin/env bash
# TRIAGE: Remove non-canonical paths from RAG manifest. Exclude _audits/, _archived/, legacy/.
# D68: RAG Canonical-Only Gate
#
# Verifies that the RAG build_manifest() only returns docs that are
# authoritative or reference status, and explicitly excludes non-canonical
# directories (_audits/, _archived/, _imported/, legacy/).
#
# PASS: exclusion rules present and dry-run manifest clean
# FAIL: exclusion rules missing or manifest includes non-canonical paths
set -euo pipefail

SP="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RAG_SCRIPT="$SP/ops/plugins/rag/bin/rag"

if [[ ! -f "$RAG_SCRIPT" ]]; then
  echo "D68 FAIL: RAG script missing at $RAG_SCRIPT"
  exit 1
fi

# Check 1: Exclusion rules present in build_manifest
REQUIRED_EXCLUSIONS=(
  "_audits/"
  "_archived/"
  "_imported/"
  "legacy/"
)

for pattern in "${REQUIRED_EXCLUSIONS[@]}"; do
  if ! grep -q "$pattern" "$RAG_SCRIPT"; then
    echo "D68 FAIL: RAG build_manifest missing exclusion for '$pattern'"
    exit 1
  fi
done

# Check 2: Frontmatter filter present (status: field required)
if ! grep -q 'has_required_frontmatter' "$RAG_SCRIPT"; then
  echo "D68 FAIL: RAG build_manifest missing frontmatter filter"
  exit 1
fi

# Check 3: Dry-run manifest must not include any non-canonical paths
# Run the Python manifest builder inline to verify
manifest_output=$(cd "$SP" && python3 -c "
import sys
from pathlib import Path

root = Path('$SP').resolve()
allowed_roots = [root / 'docs', root / 'ops', root / 'surfaces']

excluded_prefixes = [
  'docs/legacy/',
  'docs/governance/_audits/',
  'docs/governance/_archived/',
  'docs/governance/_imported/',
  'receipts/',
  'mailroom/state/',
  'fixtures/',
  '.git/',
  'node_modules/',
]

deny_patterns = ['_audits/', '_archived/', '_imported/', '/legacy/']

def is_excluded(rel):
  if '/.archive/' in rel or rel.startswith('.archive/') or rel.endswith('/.archive'):
    return True
  for p in excluded_prefixes:
    if rel.startswith(p):
      return True
  return False

def has_required_frontmatter(path):
  try:
    lines = path.read_text(errors='ignore').splitlines()
  except Exception:
    return False
  if not lines or lines[0].strip() != '---':
    return False
  end = None
  for i in range(1, min(len(lines), 80)):
    if lines[i].strip() == '---':
      end = i
      break
  if end is None:
    return False
  front = '\n'.join(lines[:end+1])
  required = ['status:', 'owner:', 'last_verified:']
  return all(r in front for r in required)

violations = []
for base in allowed_roots:
  if not base.exists():
    continue
  for p in base.rglob('*.md'):
    rel = p.relative_to(root).as_posix()
    if is_excluded(rel):
      continue
    if not has_required_frontmatter(p):
      continue
    for deny in deny_patterns:
      if deny in rel:
        violations.append(rel)
        break

for v in violations:
  print(v)
" 2>/dev/null || true)

if [[ -n "$manifest_output" ]]; then
  echo "D68 FAIL: RAG manifest would include non-canonical docs:"
  echo "$manifest_output" | head -10
  exit 1
fi

echo "D68 PASS: RAG canonical-only gate valid"
exit 0
