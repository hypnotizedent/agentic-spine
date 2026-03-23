#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

repo="$tmpdir/repo"
state_root="$tmpdir/state"
mkdir -p "$repo" "$state_root"

git init -b main "$repo" >/dev/null
git -C "$repo" config user.name "Test User"
git -C "$repo" config user.email "test@example.com"
touch "$repo/.gitkeep"

set +e
output="$(
  cd "$repo" && \
    SPINE_STATE="$state_root" \
    "$ROOT/bin/ops" cap run friction.ingest -- \
      --source test \
      --capability friction.ingest \
      --expected "should file friction without main override" \
      --actual "test run" \
      --severity low \
      --json 2>&1
)"
status=$?
set -e

if [[ "$status" -ne 0 ]]; then
  echo "$output" >&2
  echo "FAIL: friction.ingest should succeed on main without governed override" >&2
  exit 1
fi

grep -Fq "POLICY GUARD: allowlisted bootstrap/governance capability 'friction.ingest'" <<<"$output" || {
  echo "$output" >&2
  echo "FAIL: policy guard exemption not reported" >&2
  exit 1
}

grep -Fq "MUTATION CONTEXT GUARD: allowlisted bootstrap/control-plane capability 'friction.ingest'" <<<"$output" || {
  echo "$output" >&2
  echo "FAIL: mutation context guard exemption not reported" >&2
  exit 1
}

grep -Fq '"status": "ok"' <<<"$output" || {
  echo "$output" >&2
  echo "FAIL: friction.ingest JSON payload missing ok status" >&2
  exit 1
}

queue_file="$state_root/friction-queue.ndjson"
[[ -f "$queue_file" ]] || {
  echo "FAIL: expected queue file at $queue_file" >&2
  exit 1
}

grep -Fq '"capability": "friction.ingest"' "$queue_file" || {
  cat "$queue_file" >&2
  echo "FAIL: queue file missing friction.ingest record" >&2
  exit 1
}

echo "PASS: friction.ingest bypasses main-branch mutation ceremony and queues friction"
