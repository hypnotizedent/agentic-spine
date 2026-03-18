#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
PLACE="$ROOT/ops/plugins/domains/mint/bin/artwork-place"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$PLACE" ]] || fail "missing artwork-place executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_STATE="$tmp/state"
export MINIO_MOUNT_ROOT="$tmp/minio"
EXPECTED_MINIO_ROOT="$(python3 -c 'from pathlib import Path; import os; print(Path(os.environ["MINIO_MOUNT_ROOT"]).resolve())')"

mkdir -p "$tmp/src" "$MINIO_MOUNT_ROOT/artwork-intake/operator-drop/13823 PapaPalooza"
printf 'vector-pdf' >"$tmp/src/papapalooza.pdf"
printf 'existing' >"$MINIO_MOUNT_ROOT/artwork-intake/operator-drop/13823 PapaPalooza/papa Hughes Men.pdf"

placed_json="$("$PLACE" "$tmp/src/papapalooza.pdf" --context "Troy Papa's Raw Bar papapalooza" --json)"
placed_state="$(echo "$placed_json" | jq -r '.data.placement_state')"
placed_target="$(echo "$placed_json" | jq -r '.data.resolved_file_path')"
placed_key="$(echo "$placed_json" | jq -r '.data.canonical_object_key')"
placed_record="$(echo "$placed_json" | jq -r '.data.record_file')"
placed_index="$(echo "$placed_json" | jq -r '.data.index_file')"

[[ "$placed_state" == "placed" ]] || fail "existing target should place file"
[[ "$placed_target" == "$EXPECTED_MINIO_ROOT/artwork-intake/operator-drop/13823 PapaPalooza/1. Originals/papapalooza.pdf" ]] || fail "original artifact should land in governed originals folder"
[[ "$placed_key" == "artwork-intake/operator-drop/13823 PapaPalooza/1. Originals/papapalooza.pdf" ]] || fail "placement should return canonical object key"
[[ -f "$placed_target" ]] || fail "placed target file should exist"
[[ -f "$placed_record" ]] || fail "record file should exist"
[[ -f "$placed_index" ]] || fail "index file should exist"
grep -F '"placement_state": "placed"' "$placed_index" >/dev/null || fail "index should record placed state"
grep -F '"artifact_role": "original"' "$placed_record" >/dev/null || fail "record should preserve artifact role"

printf 'proof-file' >"$tmp/src/acme-proof.pdf"
proof_json="$("$PLACE" "$tmp/src/acme-proof.pdf" --context "Acme customer proof" --artifact-role proof --json)"
proof_target="$(echo "$proof_json" | jq -r '.data.resolved_file_path')"
[[ "$proof_target" == *"/artwork-intake/operator-drop/_staging/"*"/2. Proofs/acme-proof.pdf" ]] || fail "proof placement should use governed proof folder"
[[ -f "$proof_target" ]] || fail "proof target file should exist"

printf 'staged' >"$tmp/src/acme-proof.pdf"
staged_json="$("$PLACE" "$tmp/src/acme-proof.pdf" --context "Acme launch artwork" --json)"
staged_state="$(echo "$staged_json" | jq -r '.data.placement_state')"
staged_target="$(echo "$staged_json" | jq -r '.data.resolved_file_path')"
[[ "$staged_state" == "placed" ]] || fail "no-match flow should still place into staging"
[[ "$staged_target" == *"/artwork-intake/operator-drop/_staging/"* ]] || fail "no-match flow should use canonical staging prefix"
[[ "$staged_target" == *"/1. Originals/acme-proof.pdf" ]] || fail "staging target should land in 1. Originals"
[[ -f "$staged_target" ]] || fail "staged file should exist"

mkdir -p "$MINIO_MOUNT_ROOT/artwork-intake/operator-drop/13824 PapaPalooza Reprint"
printf 'variant' >"$MINIO_MOUNT_ROOT/artwork-intake/operator-drop/13824 PapaPalooza Reprint/notes.txt"
mkdir -p "$tmp/ambiguous"
printf 'ambiguous' >"$tmp/ambiguous/papapalooza.pdf"
ambiguous_json="$("$PLACE" "$tmp/ambiguous/papapalooza.pdf" --context "papapalooza" --json)"
ambiguous_state="$(echo "$ambiguous_json" | jq -r '.data.placement_state')"
ambiguous_question="$(echo "$ambiguous_json" | jq -r '.data.operator_question')"
[[ "$ambiguous_state" == "needs_operator_choice" ]] || fail "similar canonical folders should return a concise question"
[[ "$ambiguous_question" == Which\ canonical\ target* ]] || fail "ambiguous flow should ask one concise question"
pass "artwork-place resolves existing folders, stages canonically, and asks one question on ambiguity"
