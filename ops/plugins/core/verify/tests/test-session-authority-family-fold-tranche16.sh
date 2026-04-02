#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"
ROUTING="$ROOT/ops/bindings/routing.dispatch.yaml"
CAPMAP="$ROOT/ops/bindings/capability_map.yaml"
PROMPT_REGISTRY="$ROOT/ops/bindings/prompt.registry.yaml"
PROMPT_LIBRARY="$ROOT/ops/bindings/prompt.library.contract.yaml"
COMM_PROTOCOL="$ROOT/ops/bindings/communication.protocol.contract.yaml"
TRANSLATOR_CONTRACT="$ROOT/ops/bindings/translator.authority.contract.yaml"

python3 - "$ROOT" "$MANIFEST" "$ROUTING" "$CAPMAP" "$PROMPT_REGISTRY" "$PROMPT_LIBRARY" "$COMM_PROTOCOL" "$TRANSLATOR_CONTRACT" <<'PY'
import sys
from pathlib import Path
import yaml

(
    root_arg,
    manifest_arg,
    routing_arg,
    capmap_arg,
    prompt_registry_arg,
    prompt_library_arg,
    comm_protocol_arg,
    translator_contract_arg,
) = sys.argv[1:]

root = Path(root_arg)
manifest = yaml.safe_load(Path(manifest_arg).read_text(encoding="utf-8"))
routing = yaml.safe_load(Path(routing_arg).read_text(encoding="utf-8"))
capmap = yaml.safe_load(Path(capmap_arg).read_text(encoding="utf-8"))
prompt_registry = Path(prompt_registry_arg).read_text(encoding="utf-8")
prompt_library = Path(prompt_library_arg).read_text(encoding="utf-8")
comm_protocol = Path(comm_protocol_arg).read_text(encoding="utf-8")
translator_contract = Path(translator_contract_arg).read_text(encoding="utf-8")

plugins = {plugin["name"]: plugin for plugin in manifest["plugins"]}

for removed in ("context", "handoff", "tenant"):
    assert removed not in plugins, f"{removed} plugin block should be removed"

session = plugins["session"]
authority = plugins["authority"]

for script in (
    "bin/prompt-library-bootstrap",
    "bin/spine-context",
    "bin/session-handoff-close",
    "bin/session-handoff-create",
    "bin/session-handoff-expire",
    "bin/session-handoff-get",
    "bin/session-handoff-list",
    "bin/session-handoff-status",
):
    assert script in session["scripts"], f"session missing script {script}"

for capability in (
    "prompt.library.bootstrap",
    "prompt.library.list",
    "spine.context",
    "session.handoff.close",
    "session.handoff.create",
    "session.handoff.expire",
    "session.handoff.get",
    "session.handoff.list",
    "session.handoff.status",
):
    assert capability in session["capabilities"], f"session missing capability {capability}"

for script in (
    "bin/stabilization-mode-status",
    "bin/tenant-profile-validate",
    "bin/tenant-provision-dry-run",
    "bin/tenant-storage-audit",
):
    assert script in authority["scripts"], f"authority missing script {script}"

for capability in (
    "stabilization.mode.status",
    "tenant.profile.validate",
    "tenant.provision.dry-run",
    "tenant.storage.audit",
):
    assert capability in authority["capabilities"], f"authority missing capability {capability}"

dispatch = routing["dispatch"]
for cap in (
    "prompt.library.bootstrap",
    "prompt.library.list",
    "spine.context",
    "session.handoff.close",
    "session.handoff.create",
    "session.handoff.expire",
    "session.handoff.get",
    "session.handoff.list",
    "session.handoff.status",
):
    target = dispatch[cap]["target"]
    assert target["plugin"] == "session", f"{cap} should route to session"
    assert target["plugin_path"] == "core/session", f"{cap} should live under core/session"

for cap in (
    "stabilization.mode.status",
    "tenant.profile.validate",
    "tenant.provision.dry-run",
    "tenant.storage.audit",
):
    target = dispatch[cap]["target"]
    assert target["plugin"] == "authority", f"{cap} should route to authority"
    assert target["plugin_path"] == "core/authority", f"{cap} should live under core/authority"

capabilities = capmap["capabilities"]
for cap in (
    "prompt.library.bootstrap",
    "prompt.library.list",
    "spine.context",
    "session.handoff.close",
    "session.handoff.create",
    "session.handoff.expire",
    "session.handoff.get",
    "session.handoff.list",
    "session.handoff.status",
):
    assert capabilities[cap]["plugin"] == "session", f"{cap} should map to session"

for cap in (
    "stabilization.mode.status",
    "tenant.profile.validate",
    "tenant.provision.dry-run",
    "tenant.storage.audit",
):
    assert capabilities[cap]["plugin"] == "authority", f"{cap} should map to authority"

for live_ref in (prompt_registry, prompt_library, comm_protocol, translator_contract):
    assert "ops/plugins/core/context/templates/" not in live_ref
    assert "ops/plugins/core/session/templates/" in live_ref

for old_path in (
    root / "ops/plugins/core/context",
    root / "ops/plugins/core/handoff",
    root / "ops/plugins/core/tenant",
):
    assert not old_path.exists(), f"legacy family path still exists: {old_path}"

for new_path in (
    root / "ops/plugins/core/session/bin/spine-context",
    root / "ops/plugins/core/session/bin/prompt-library-bootstrap",
    root / "ops/plugins/core/session/bin/session-handoff-create",
    root / "ops/plugins/core/authority/bin/tenant-profile-validate",
    root / "ops/plugins/core/authority/bin/tenant-provision-dry-run",
):
    assert new_path.exists(), f"expected moved file missing: {new_path}"

print("PASS: session/authority family fold is wired cleanly")
PY
