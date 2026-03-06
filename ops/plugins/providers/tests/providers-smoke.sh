#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
export SPINE_ROOT="$ROOT"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
STATUS="$ROOT/ops/plugins/providers/bin/providers-status"
ENV_BIN="$ROOT/ops/plugins/providers/bin/providers-launch-env"
SYNC="$ROOT/ops/plugins/providers/bin/providers-sync-managed-configs"

fail() {
  echo "providers-smoke FAIL: $*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "missing jq"
command -v python3 >/dev/null 2>&1 || fail "missing python3"

status_json="$($STATUS --surface opencode --json)"
echo "$status_json" | jq -e '.surface == "opencode"' >/dev/null || fail "status surface mismatch"
echo "$status_json" | jq -e '.candidates | length > 0' >/dev/null || fail "status candidates missing"

env_json="$(OPENAI_API_KEY=dummy $ENV_BIN --tool codex --provider openai --json)"
echo "$env_json" | jq -e '.CODEX_MODEL_PROVIDER == "spine_openai"' >/dev/null || fail "codex provider env missing"

workbench_tmp="$(mktemp -d)"
mkdir -p "$workbench_tmp/dotfiles/opencode" "$workbench_tmp/dotfiles/codex"
cat > "$workbench_tmp/dotfiles/opencode/opencode.json" <<'JSON'
{"$schema":"https://opencode.ai/config.json","provider":{},"agent":{"default":{"model":"openai/example"}},"mcp":{},"plugin":[],"instructions":[],"command":{},"permission":{},"watcher":{}}
JSON
cat > "$workbench_tmp/dotfiles/opencode/oh-my-opencode.json" <<'JSON'
{"agents":{"build":{"model":"openai/example"},"plan":{"model":"openai/example"}}}
JSON
cat > "$workbench_tmp/dotfiles/codex/config.toml" <<'TOML'
model = "gpt-5.4"
TOML

OPENAI_API_KEY=dummy "$SYNC" --tool codex --workbench-root "$workbench_tmp" >/dev/null
OPENAI_API_KEY=dummy "$SYNC" --tool opencode --provider openai --workbench-root "$workbench_tmp" >/dev/null
OPENAI_API_KEY=dummy "$SYNC" --tool opencode --provider openrouter --workbench-root "$workbench_tmp" >/dev/null

python3 - <<'PY' "$workbench_tmp/dotfiles/opencode/opencode.json" "$workbench_tmp/dotfiles/opencode/oh-my-opencode.json" "$workbench_tmp/dotfiles/codex/config.toml"
import json, pathlib, sys
opencode = json.loads(pathlib.Path(sys.argv[1]).read_text())
ohmy = json.loads(pathlib.Path(sys.argv[2]).read_text())
codex = pathlib.Path(sys.argv[3]).read_text()
assert opencode["provider"]["openai"]["options"]["apiKey"] == "{env:OPENAI_API_KEY}"
assert opencode["provider"]["openai"]["options"]["baseURL"] == "https://openrouter.ai/api/v1"
assert opencode["agent"]["default"]["model"].startswith("openai/")
assert ohmy["agents"]["build"]["model"].startswith("openai/")
assert "[model_providers.spine_openai]" in codex
print("providers-smoke PASS")
PY
