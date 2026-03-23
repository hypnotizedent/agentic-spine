#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

HELPER="${SPINE_ROOT}/ops/plugins/core/lifecycle/bin/gate-recurrence-convert"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

evidence_root="$tmpdir/evidence/spine/sessions"
state_root="$tmpdir/state"
queue_file="$state_root/friction-queue.ndjson"
lock_file="$state_root/locks/friction-queue.lock"
stub_ingest="$tmpdir/friction-ingest-stub.sh"
stub_log="$tmpdir/friction-ingest.log"

mkdir -p "$evidence_root" "$state_root/locks"

cat > "$stub_ingest" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${FRICTION_INGEST_LOG:?}"
loop_id=""
queue=""
stdin_file="$(mktemp)"
trap 'rm -f "$stdin_file"' EXIT

while (($#)); do
  case "$1" in
    --queue)
      queue="$2"
      shift 2
      ;;
    --lock-file)
      shift 2
      ;;
    --source)
      shift 2
      ;;
    --loop-id)
      loop_id="$2"
      shift 2
      ;;
    --auto-reconcile|--stdin-jsonl|--json)
      shift
      ;;
    *)
      shift
      ;;
  esac
done

cat >"$stdin_file"
count="$(grep -c '^{\"' "$stdin_file" 2>/dev/null || true)"
printf '{"status":"ok","loop_id":"%s","queue":"%s","items":%s}\n' "$loop_id" "$queue" "${count:-0}"
printf '%s|%s|%s\n' "$loop_id" "$queue" "$(tr '\n' ' ' <"$stdin_file")" >>"$log_file"
EOF
chmod +x "$stub_ingest"

make_receipt_dir() {
  local name="$1"
  local dir="$evidence_root/$name"
  mkdir -p "$dir"
  cat > "$dir/output.txt"
}

make_receipt_dir "RCAP-20260322-0001__spine.verify__one" <<'EOF'
D83 FAIL: proposal queue recurrence
D75 FAIL: gap registry recurrence
D377 FAIL: mailroom recurrence
EOF

make_receipt_dir "RCAP-20260322-0002__spine.verify__two" <<'EOF'
D396 FAIL: boring root recurrence
D331 FAIL: closeout recurrence
D399 FAIL: mailbox recurrence
EOF

json="$(
  FRICTION_INGEST_LOG="$stub_log" \
  "$HELPER" \
    --evidence-root "$evidence_root" \
    --queue "$queue_file" \
    --lock-file "$lock_file" \
    --threshold 1 \
    --friction-ingest-cmd "$stub_ingest" \
    --json
)"

python3 - <<'PY' "$json" "$stub_log"
import json
import sys
from pathlib import Path

payload = json.loads(sys.argv[1])
log_path = Path(sys.argv[2])

assert payload["status"] == "ok", payload
assert payload["auto_reconcile"] is True, payload
assert payload["loops"]["LOOP-MAILROOM-EXTERNALIZATION-CLOSEOUT-20260323"]["item_count"] == 2, payload
assert payload["loops"]["LOOP-UNFINISHED-WORK-LIFECYCLE-CLOSEOUT-20260323"]["item_count"] == 3, payload
assert payload["loops"]["LOOP-CROSS-DOMAIN-LIVE-ENFORCEMENT-SCOPING-20260323"]["item_count"] == 1, payload

log_lines = [line for line in log_path.read_text(encoding="utf-8").splitlines() if line.strip()]
assert len(log_lines) == 3, log_lines
assert any("LOOP-MAILROOM-EXTERNALIZATION-CLOSEOUT-20260323" in line for line in log_lines), log_lines
assert any("LOOP-UNFINISHED-WORK-LIFECYCLE-CLOSEOUT-20260323" in line for line in log_lines), log_lines
assert any("LOOP-CROSS-DOMAIN-LIVE-ENFORCEMENT-SCOPING-20260323" in line for line in log_lines), log_lines
PY

echo "PASS: gate-recurrence-convert turns repeated gate failures into loop-scoped friction items"
