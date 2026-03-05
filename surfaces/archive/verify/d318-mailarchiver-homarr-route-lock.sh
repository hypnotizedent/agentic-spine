#!/usr/bin/env bash
# TRIAGE: keep canonical mail-archiver + homarr hostnames locked in DOMAIN_ROUTING_REGISTRY and Cloudflare tunnel ingress.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SECRETS_EXEC="$ROOT/ops/plugins/secrets/bin/secrets-exec"
ROUTING_REGISTRY="$ROOT/docs/governance/DOMAIN_ROUTING_REGISTRY.yaml"
INGRESS_SCRIPT="$ROOT/ops/plugins/cloudflare/bin/cloudflare-tunnel-ingress-status"

MAIL_HOST="mail-archive.ronny.works"
MAIL_SERVICE="http://mail-archiver:5100"
HOMARR_HOST="homarr.ronny.works"
HOMARR_SERVICE="http://100.123.207.64:7575"

fail() {
  echo "D318 FAIL: $*" >&2
  exit 1
}

[[ -x "$SECRETS_EXEC" ]] || fail "missing executable: $SECRETS_EXEC"
[[ -x "$INGRESS_SCRIPT" ]] || fail "missing executable: $INGRESS_SCRIPT"
[[ -f "$ROUTING_REGISTRY" ]] || fail "missing registry: $ROUTING_REGISTRY"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 - "$ROUTING_REGISTRY" "$MAIL_HOST" "$HOMARR_HOST" <<'PY' || fail "registry missing locked hostnames/routing_layer"
from __future__ import annotations
import sys
import yaml

path, mail_host, homarr_host = sys.argv[1], sys.argv[2].lower(), sys.argv[3].lower()
with open(path, "r", encoding="utf-8") as f:
    doc = yaml.safe_load(f) or {}

required = {
    mail_host: "mail-archiver",
    homarr_host: "homarr",
}
seen = {}
for zone in (doc.get("zones") or []):
    if not isinstance(zone, dict):
        continue
    for row in (zone.get("hostnames") or []):
        if not isinstance(row, dict):
            continue
        host = str(row.get("hostname", "")).strip().lower()
        if host not in required:
            continue
        if str(row.get("routing_layer", "")).strip() != "cloudflare_tunnel":
            raise SystemExit(1)
        if str(row.get("service", "")).strip() != required[host]:
            raise SystemExit(1)
        seen[host] = True

if set(seen.keys()) != set(required.keys()):
    raise SystemExit(1)
PY

INGRESS_OUT="$("$SECRETS_EXEC" -- env SPINE_SECRETS_INJECTED=1 "$INGRESS_SCRIPT" 2>/dev/null)" || fail "unable to read tunnel ingress"
echo "$INGRESS_OUT" | grep -q -- "- ${MAIL_HOST} -> ${MAIL_SERVICE}" || fail "tunnel ingress missing ${MAIL_HOST} -> ${MAIL_SERVICE}"
echo "$INGRESS_OUT" | grep -q -- "- ${HOMARR_HOST} -> ${HOMARR_SERVICE}" || fail "tunnel ingress missing ${HOMARR_HOST} -> ${HOMARR_SERVICE}"

echo "D318 PASS: mail-archiver and homarr route lock valid (registry + tunnel ingress)"
