#!/usr/bin/env bash
# TRIAGE: Enforce lifecycle transaction integration for cloudflare.service.publish. All active public services must declare publish_via_capability and the lifecycle contract must wire the approved_to_executed hook.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SERVICE_CONTRACT="$ROOT/ops/bindings/service.onboarding.contract.yaml"
LIFECYCLE_CONTRACT="$ROOT/ops/bindings/platform.extension.lifecycle.contract.yaml"
BINDING_DEFAULTS="$ROOT/ops/bindings/platform.extension.binding.defaults.yaml"
CAPABILITIES_FILE="$ROOT/ops/capabilities.yaml"

fail() {
  echo "D334 FAIL: $*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

for f in "$SERVICE_CONTRACT" "$LIFECYCLE_CONTRACT" "$BINDING_DEFAULTS" "$CAPABILITIES_FILE"; do
  [[ -f "$f" ]] || fail "missing required file: $f"
done

result="$(python3 - "$SERVICE_CONTRACT" "$LIFECYCLE_CONTRACT" "$BINDING_DEFAULTS" "$CAPABILITIES_FILE" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

service_path, lifecycle_path, defaults_path, caps_path = (Path(p) for p in sys.argv[1:5])


def load(p: Path) -> dict:
    with p.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


service_contract = load(service_path)
lifecycle_contract = load(lifecycle_path)
binding_defaults = load(defaults_path)
capabilities = load(caps_path)

issues: list[str] = []

# 1. Check that cloudflare.service.lifecycle.publish capability exists
caps_map = capabilities.get("capabilities") or capabilities
if "cloudflare.service.lifecycle.publish" not in caps_map:
    issues.append("cloudflare.service.lifecycle.publish capability not registered in capabilities.yaml")

# 2. Check lifecycle_hooks in lifecycle contract
lifecycle_hooks = lifecycle_contract.get("lifecycle_hooks")
if not isinstance(lifecycle_hooks, dict):
    issues.append("lifecycle contract missing lifecycle_hooks section")
else:
    service_hooks = lifecycle_hooks.get("service_type")
    if not isinstance(service_hooks, dict):
        issues.append("lifecycle contract missing lifecycle_hooks.service_type section")
    else:
        on_transition = service_hooks.get("on_transition")
        if not isinstance(on_transition, dict):
            issues.append("lifecycle contract missing lifecycle_hooks.service_type.on_transition")
        else:
            a2e = on_transition.get("approved_to_executed")
            if not isinstance(a2e, list):
                issues.append("lifecycle contract missing approved_to_executed hook list")
            else:
                found = any(
                    isinstance(h, dict)
                    and str(h.get("capability", "")).strip()
                    == "cloudflare.service.lifecycle.publish"
                    for h in a2e
                )
                if not found:
                    issues.append(
                        "approved_to_executed hook missing cloudflare.service.lifecycle.publish entry"
                    )

# 3. Check binding defaults has lifecycle_publish_enforcement
per_type = binding_defaults.get("per_type_policy") or {}
svc_policy = per_type.get("service") or {}
lpe = svc_policy.get("lifecycle_publish_enforcement")
if not isinstance(lpe, dict):
    issues.append("binding defaults missing lifecycle_publish_enforcement for service type")
elif not lpe.get("enabled"):
    issues.append("binding defaults lifecycle_publish_enforcement is not enabled")

# 4. Check all active public services declare publish_via_capability
public_services = []
missing_cap = []
for svc in service_contract.get("services") or []:
    if not isinstance(svc, dict):
        continue
    svc_id = str(svc.get("id", "")).strip()
    svc_status = str(svc.get("status", "")).strip()
    if svc_status != "active":
        continue
    intent = str(svc.get("exposure_intent", "private")).strip().lower()
    if intent != "public":
        continue
    public_services.append(svc_id)
    pub_cap = str(svc.get("publish_via_capability", "")).strip()
    if pub_cap != "cloudflare.service.publish":
        missing_cap.append(f"{svc_id} (publish_via_capability={pub_cap or 'unset'})")

if missing_cap:
    issues.append(
        f"public services missing publish_via_capability=cloudflare.service.publish: {', '.join(missing_cap)}"
    )

payload = {
    "gate": "D334",
    "status": "FAIL" if issues else "PASS",
    "public_service_count": len(public_services),
    "missing_capability_count": len(missing_cap),
    "issues": issues,
}

print(json.dumps(payload))
sys.exit(1 if issues else 0)
PY
)"

status="$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['status'])")"
public_count="$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['public_service_count'])")"
missing_count="$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['missing_capability_count'])")"
issues_text="$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print('; '.join(d['issues']) if d['issues'] else 'none')")"

if [[ "$status" == "PASS" ]]; then
  echo "D334 PASS: service-lifecycle-publish-enforcement (public_services=$public_count, lifecycle_hooks=wired, binding_defaults=enabled, issues=0)"
else
  echo "D334 FAIL: service-lifecycle-publish-enforcement (public_services=$public_count, missing_cap=$missing_count, issues: $issues_text)" >&2
  exit 1
fi
