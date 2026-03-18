#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
BIN="$ROOT/ops/plugins/domains/mint/bin/modules-health"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v grep >/dev/null 2>&1 || fail "grep required"
[[ -x "$BIN" ]] || fail "missing modules-health executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_spine="$tmp/spine"
fake_bin="$tmp/bin"
resolve_log="$tmp/resolve.log"
mkdir -p "$fake_spine/ops/lib" "$fake_spine/ops/bindings" "$fake_spine/ops/plugins/domains/mint/bin" "$fake_bin"

cp "$BIN" "$fake_spine/ops/plugins/domains/mint/bin/modules-health"
chmod +x "$fake_spine/ops/plugins/domains/mint/bin/modules-health"

touch \
  "$fake_spine/ops/bindings/ssh.targets.yaml" \
  "$fake_spine/ops/bindings/services.health.yaml" \
  "$fake_spine/ops/bindings/mint.probe.targets.yaml"

cat >"$fake_spine/ops/lib/ssh-resolve.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ssh_resolve_user() {
  printf 'ubuntu\n'
}

ssh_resolve_probe_host() {
  case "$1" in
    app-target) printf 'app-probe probe-direct\n' ;;
    data-target) printf 'data-probe probe-direct\n' ;;
    *) return 1 ;;
  esac
}

ssh_resolve_ssh_host_with_fallback() {
  printf 'data-ssh ssh-direct\n'
}
EOF

cat >"$fake_spine/ops/lib/mint-health-surface.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mint_probe_target_id() {
  case "$1" in
    app_plane) printf 'app-target\n' ;;
    data_plane) printf 'data-target\n' ;;
    *) return 1 ;;
  esac
}

mint_http_rows_tsv() {
  printf 'files-api\tapp_plane\n'
  printf 'quote-page\tapp_plane\n'
}

mint_service_enabled() {
  printf 'true\n'
}

mint_service_resolved_url() {
  local name="$1"
  printf '%s\n' "$name" >>"${FAKE_RESOLVE_LOG:?}"
  printf 'https://%s.test/health resolved-path\n' "$name"
}
EOF

cat >"$fake_bin/yq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

query=""
for arg in "$@"; do
  case "$arg" in
    -r|e) ;;
    *)
      if [[ -z "$query" ]]; then
        query="$arg"
      fi
      ;;
  esac
done

case "$query" in
  '.ssh.targets[] | select(.id == "app-target") | .host') printf 'app-host\n' ;;
  '.ssh.targets[] | select(.id == "data-target") | .host') printf 'data-host\n' ;;
  '.targets.app_plane.vm_id // "?"') printf '213\n' ;;
  '.targets.data_plane.vm_id // "?"') printf '212\n' ;;
  '.targets.data_plane.ssh_checks[] | [.id, .command] | @tsv') exit 0 ;;
  *) exit 0 ;;
esac
EOF

cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '200'
EOF

cat >"$fake_bin/ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF

chmod +x "$fake_spine/ops/lib/ssh-resolve.sh" "$fake_spine/ops/lib/mint-health-surface.sh" "$fake_bin/yq" "$fake_bin/curl" "$fake_bin/ssh"

out="$(
  env \
    PATH="$fake_bin:$PATH" \
    SPINE_ROOT="$fake_spine" \
    FAKE_RESOLVE_LOG="$resolve_log" \
    "$fake_spine/ops/plugins/domains/mint/bin/modules-health" files-api
)"

grep '^files-api$' "$resolve_log" >/dev/null || fail "filtered modules-health should resolve the requested component"
if grep '^quote-page$' "$resolve_log" >/dev/null; then
  fail "filtered modules-health should not resolve non-matching components"
fi
echo "$out" | grep '^files-api' >/dev/null || fail "filtered modules-health should probe the requested component"
if echo "$out" | grep '^quote-page' >/dev/null; then
  fail "filtered modules-health output should omit non-matching components"
fi

pass "modules-health applies the component filter before resolving Mint service URLs"

echo "modules-health filter tests"
