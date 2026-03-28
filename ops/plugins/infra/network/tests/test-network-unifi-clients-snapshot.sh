#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SHOP_SCRIPT="$ROOT/ops/plugins/infra/network/bin/network-unifi-clients-snapshot"
HOME_SCRIPT="$ROOT/ops/plugins/infra/network/bin/network-home-unifi-clients-snapshot"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fixture_root="$tmpdir/fixture-root"
state_root="$tmpdir/state"
domain_state_root="$tmpdir/domain-state"
mkdir -p "$fixture_root/ops/bindings" "$state_root" "$domain_state_root/snapshots"

cat > "$fixture_root/ops/bindings/network.unifi.shop.clients.observed.yaml" <<'EOF_SHOP'
status: authoritative
owner: '@ronny'
last_verified: '2026-03-24'
scope: network-unifi-shop-observed-clients
version: 1
updated_at: '2026-03-24'
generated_at: '2026-03-24T06:50:08Z'
source_capability: network.unifi.clients.snapshot
devices: []
EOF_SHOP

cat > "$fixture_root/ops/bindings/network.unifi.home.clients.observed.yaml" <<'EOF_HOME'
status: authoritative
owner: '@ronny'
last_verified: '2026-03-24'
scope: network-unifi-home-observed-clients
version: 1
updated_at: '2026-03-24'
generated_at: '2026-03-24T06:50:02Z'
source_capability: network.home.unifi.clients.snapshot
devices: []
EOF_HOME

agent_stub="$tmpdir/unifi-agent-stub.sh"
agent_log="$tmpdir/unifi-agent.log"
cat > "$agent_stub" <<'EOF_AGENT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${UNIFI_AGENT_LOG:?}"
printf '{"data":[{"mac":"aa:bb:cc:dd:ee:ff","ip":"192.168.1.2","name":"stub-client"}]}\n'
EOF_AGENT
chmod +x "$agent_stub"

common_env=(
  "SPINE_ROOT=$fixture_root"
  "SPINE_TARGET_REPO=$fixture_root"
  "SPINE_REPO=$fixture_root"
  "SPINE_CODE=$fixture_root"
  "SPINE_STATE=$state_root"
  "SPINE_DOMAIN_STATE=$domain_state_root"
  "UNIFI_AGENT_LOG=$agent_log"
)

shop_before_hash="$(shasum -a 256 "$fixture_root/ops/bindings/network.unifi.shop.clients.observed.yaml" | awk '{print $1}')"
shop_before_generated="$(yq e -r '.generated_at' "$fixture_root/ops/bindings/network.unifi.shop.clients.observed.yaml")"
env "${common_env[@]}" UNIFI_SHOP_AGENT_BIN="$agent_stub" "$SHOP_SCRIPT" --json >/dev/null
shop_after_hash="$(shasum -a 256 "$fixture_root/ops/bindings/network.unifi.shop.clients.observed.yaml" | awk '{print $1}')"
shop_runtime="$domain_state_root/snapshots/network.unifi.shop.clients.observed.yaml"
[[ "$shop_before_hash" == "$shop_after_hash" ]]
[[ -f "$shop_runtime" ]]
[[ "$(yq e -r '.generated_at' "$fixture_root/ops/bindings/network.unifi.shop.clients.observed.yaml")" == "$shop_before_generated" ]]
[[ "$(yq e -r '.generated_at' "$shop_runtime")" != "$shop_before_generated" ]]
grep -q '^clients --json$' "$agent_log"

home_before_hash="$(shasum -a 256 "$fixture_root/ops/bindings/network.unifi.home.clients.observed.yaml" | awk '{print $1}')"
home_before_generated="$(yq e -r '.generated_at' "$fixture_root/ops/bindings/network.unifi.home.clients.observed.yaml")"
env "${common_env[@]}" UNIFI_HOME_AGENT_BIN="$agent_stub" "$HOME_SCRIPT" >/dev/null
home_after_hash="$(shasum -a 256 "$fixture_root/ops/bindings/network.unifi.home.clients.observed.yaml" | awk '{print $1}')"
home_runtime="$domain_state_root/snapshots/network.unifi.home.clients.observed.yaml"
[[ "$home_before_hash" == "$home_after_hash" ]]
[[ -f "$home_runtime" ]]
[[ "$(yq e -r '.generated_at' "$fixture_root/ops/bindings/network.unifi.home.clients.observed.yaml")" == "$home_before_generated" ]]
[[ "$(yq e -r '.generated_at' "$home_runtime")" != "$home_before_generated" ]]
grep -q '^clients$' "$agent_log"

env "${common_env[@]}" UNIFI_SHOP_AGENT_BIN="$agent_stub" "$SHOP_SCRIPT" --apply >/dev/null
[[ "$(yq e -r '.generated_at' "$fixture_root/ops/bindings/network.unifi.shop.clients.observed.yaml")" != "$shop_before_generated" ]]

echo "PASS: UniFi snapshot wrappers keep tracked bindings clean in check mode"
