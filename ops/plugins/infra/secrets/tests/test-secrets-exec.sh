#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
SECRETS_EXEC="$ROOT/ops/plugins/infra/secrets/bin/secrets-exec"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$SECRETS_EXEC" ]] || fail "missing secrets-exec executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_spine="$tmp/spine"
fake_bin="$tmp/bin"
mkdir -p "$fake_spine/ops/plugins/infra/secrets/bin" "$fake_spine/ops/plugins/providers/bin" "$fake_spine/ops/bindings" "$fake_bin"

cat >"$fake_spine/ops/bindings/secrets.binding.yaml" <<'EOF'
infisical:
  api_url: https://secrets.example.invalid
  internal_api_url: http://127.0.0.1:8088
  project: project-123
  environment: prod
  base_path: /spine
EOF

for helper in secrets-binding secrets-auth-status secrets-namespace-status secrets-enforcement-status; do
  cat >"$fake_spine/ops/plugins/infra/secrets/bin/$helper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
  chmod +x "$fake_spine/ops/plugins/infra/secrets/bin/$helper"
done

cat >"$fake_spine/ops/plugins/providers/bin/infisical-agent.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "auth-token" ]]; then
  printf 'token-123'
  exit 0
fi
echo "unsupported infisical-agent op: ${1:-}" >&2
exit 1
EOF
chmod +x "$fake_spine/ops/plugins/providers/bin/infisical-agent.sh"

cat >"$fake_bin/infisical" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

attempt_file="${TEST_ATTEMPT_FILE:?}"
count=0
if [[ -f "$attempt_file" ]]; then
  count="$(cat "$attempt_file")"
fi
count=$((count + 1))
printf '%s' "$count" >"$attempt_file"

mode="${TEST_INFISICAL_MODE:-transient_then_success}"
case "$mode" in
  transient_then_success)
    if [[ "$count" -eq 1 ]]; then
      echo 'error: CallGetRawSecretsV3: Unable to complete api request [err=Get "http://127.0.0.1:8088/api/v3/secrets/raw": read tcp 127.0.0.1:1->127.0.0.1:8088: read: connection reset by peer]' >&2
      echo 'Could not fetch secrets' >&2
      exit 1
    fi
    ;;
  permanent_failure)
    echo 'FAIL: binding missing project or environment' >&2
    exit 1
    ;;
  *)
    echo "unknown TEST_INFISICAL_MODE=$mode" >&2
    exit 1
    ;;
esac

while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--" ]]; then
    shift
    exec "$@"
  fi
  shift
done

echo "missing -- separator" >&2
exit 1
EOF
chmod +x "$fake_bin/infisical"

export PATH="$fake_bin:$PATH"
export SPINE_REPO="$fake_spine"
export TEST_ATTEMPT_FILE="$tmp/attempt-count"
export SECRETS_EXEC_QUIET=1
export SECRETS_EXEC_RETRY_MAX=3
export SECRETS_EXEC_RETRY_DELAY_SEC=0

output="$("$SECRETS_EXEC" -- bash -lc 'printf ok')"
[[ "$output" == "ok" ]] || fail "secrets-exec should return wrapped command output after transient retry"
[[ "$(cat "$TEST_ATTEMPT_FILE")" == "2" ]] || fail "transient failure should retry once before succeeding"

export TEST_INFISICAL_MODE=permanent_failure
printf '0' >"$TEST_ATTEMPT_FILE"
set +e
"$SECRETS_EXEC" -- bash -lc 'printf never' >/dev/null 2>"$tmp/permanent.err"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "permanent failure should not succeed"
[[ "$(cat "$TEST_ATTEMPT_FILE")" == "1" ]] || fail "permanent failure should not retry"
if grep -q 'transient Infisical fetch failure' "$tmp/permanent.err"; then
  fail "permanent failure should not emit retry warning"
fi

pass "secrets-exec retries transient Infisical fetch failures without retrying permanent errors"
