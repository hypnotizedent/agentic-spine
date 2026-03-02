#!/usr/bin/env bash
# TRIAGE: for any service with exposure_intent=public, populate Cloudflare publication fields and ensure hostnames are present in DOMAIN_ROUTING_REGISTRY cloudflare_tunnel authority.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SERVICE_CONTRACT="$ROOT/ops/bindings/service.onboarding.contract.yaml"
ROUTING_REGISTRY="$ROOT/docs/governance/DOMAIN_ROUTING_REGISTRY.yaml"

fail() {
  echo "D317 FAIL: $*" >&2
  exit 1
}

[[ -f "$SERVICE_CONTRACT" ]] || fail "missing binding: $SERVICE_CONTRACT"
[[ -f "$ROUTING_REGISTRY" ]] || fail "missing binding: $ROUTING_REGISTRY"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 - "$SERVICE_CONTRACT" "$ROUTING_REGISTRY" <<'PY'
from __future__ import annotations
import sys
import yaml

svc_path, route_path = sys.argv[1], sys.argv[2]

with open(svc_path, "r", encoding="utf-8") as f:
    svc_doc = yaml.safe_load(f) or {}
with open(route_path, "r", encoding="utf-8") as f:
    route_doc = yaml.safe_load(f) or {}

exposure_contract = svc_doc.get("exposure_contract") if isinstance(svc_doc.get("exposure_contract"), dict) else {}
default_intent = str(exposure_contract.get("default_intent", "private")).strip().lower() or "private"
allowed_intents = {
    str(x).strip().lower()
    for x in (exposure_contract.get("intents") or ["private", "internal", "public"])
    if str(x).strip()
}

route_hostnames = set()
for zone in (route_doc.get("zones") or []):
    if not isinstance(zone, dict):
        continue
    for row in (zone.get("hostnames") or []):
        if not isinstance(row, dict):
            continue
        if str(row.get("routing_layer", "")).strip() != "cloudflare_tunnel":
            continue
        h = str(row.get("hostname", "")).strip().lower()
        if h:
            route_hostnames.add(h)

issues: list[str] = []
services = svc_doc.get("services") if isinstance(svc_doc.get("services"), list) else []
for row in services:
    if not isinstance(row, dict):
        continue
    sid = str(row.get("id", "")).strip() or "<unknown>"
    status = str(row.get("status", "")).strip().lower()
    if status != "active":
        continue

    intent = str(row.get("exposure_intent", "")).strip().lower() or default_intent
    if intent not in allowed_intents:
        issues.append(f"{sid}: invalid exposure_intent '{intent}'")
        continue

    if intent != "public":
        continue

    hostnames = row.get("cloudflare_hostnames")
    zone = str(row.get("cloudflare_zone", "")).strip()
    publish_cap = str(row.get("publish_via_capability", "")).strip()

    if not isinstance(hostnames, list) or len(hostnames) == 0:
        issues.append(f"{sid}: cloudflare_hostnames must be non-empty for public intent")
        hostnames = []
    if not zone:
        issues.append(f"{sid}: cloudflare_zone required for public intent")
    if publish_cap != "cloudflare.service.publish":
        issues.append(f"{sid}: publish_via_capability must equal cloudflare.service.publish for public intent")

    for host in hostnames:
        hostname = str(host).strip().lower()
        if not hostname:
            issues.append(f"{sid}: cloudflare_hostnames contains empty hostname")
            continue
        if hostname not in route_hostnames:
            issues.append(f"{sid}: hostname missing from DOMAIN_ROUTING_REGISTRY cloudflare_tunnel set: {hostname}")

if issues:
    for item in issues:
        print(f"D317 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("D317 PASS: public service exposure declarations have canonical Cloudflare mappings")
PY
