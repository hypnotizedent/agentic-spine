#!/usr/bin/env bash
# TRIAGE: fix missing proxmox_alias/compose_targets parity in topology.sites.yaml before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SITES="$ROOT/ops/bindings/topology.sites.yaml"
SSH_TARGETS="$ROOT/ops/bindings/ssh.targets.yaml"
COMPOSE_TARGETS="$ROOT/ops/bindings/docker.compose.targets.yaml"

fail() {
  echo "D173 FAIL: $*" >&2
  exit 1
}

[[ -f "$SITES" ]] || fail "missing binding: $SITES"
[[ -f "$SSH_TARGETS" ]] || fail "missing binding: $SSH_TARGETS"
[[ -f "$COMPOSE_TARGETS" ]] || fail "missing binding: $COMPOSE_TARGETS"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$SITES" "$SSH_TARGETS" "$COMPOSE_TARGETS" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

sites_path = Path(sys.argv[1]).expanduser().resolve()
ssh_path = Path(sys.argv[2]).expanduser().resolve()
compose_path = Path(sys.argv[3]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


errors: list[str] = []
violations: list[tuple[str, str]] = []

try:
    sites_doc = load_yaml(sites_path)
    ssh_doc = load_yaml(ssh_path)
    compose_doc = load_yaml(compose_path)
except Exception as exc:
    print(f"D173 FAIL: unable to parse bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

for required in ("status", "owner", "last_verified", "scope", "sites"):
    if required not in sites_doc:
        errors.append(f"topology.sites contract missing required field: {required}")

sites = sites_doc.get("sites") if isinstance(sites_doc.get("sites"), list) else []
if not sites:
    errors.append("topology.sites sites[] must contain at least one site")

ssh_targets = ssh_doc.get("ssh", {}).get("targets", [])
ssh_ids = {
    str(entry.get("id", "")).strip()
    for entry in ssh_targets
    if isinstance(entry, dict) and str(entry.get("id", "")).strip()
}

compose_targets = compose_doc.get("targets") if isinstance(compose_doc.get("targets"), dict) else {}
compose_ids = {str(key).strip() for key in compose_targets.keys() if str(key).strip()}

for site in sites:
    if not isinstance(site, dict):
        errors.append("topology.sites sites[] entries must be mappings")
        continue

    site_id = str(site.get("id", "")).strip() or "unknown-site"
    for field in ("id", "status", "lan_cidr", "tailscale_anchor", "proxmox_alias", "vmid_range", "compose_targets", "notes"):
        value = site.get(field)
        if field == "compose_targets":
            if not isinstance(value, list):
                violations.append((f"sites/{site_id}", "compose_targets must be a list"))
            continue
        if not str(value or "").strip():
            violations.append((f"sites/{site_id}", f"missing required field: {field}"))

    proxmox_alias = str(site.get("proxmox_alias", "")).strip()
    if proxmox_alias and proxmox_alias not in ssh_ids:
        violations.append((f"sites/{site_id}", f"proxmox_alias not found in ssh.targets.yaml: {proxmox_alias}"))

    compose_list = site.get("compose_targets") if isinstance(site.get("compose_targets"), list) else []
    for target in compose_list:
        target_id = str(target).strip()
        if target_id and target_id not in compose_ids:
            violations.append((f"sites/{site_id}", f"compose_targets entry missing in docker.compose.targets.yaml: {target_id}"))

    status = str(site.get("status", "")).strip().lower()
    vmid_range = str(site.get("vmid_range", "")).strip()
    if status == "active" and not vmid_range:
        violations.append((f"sites/{site_id}", "active site missing vmid_range"))

if errors:
    for err in errors:
        print(f"D173 FAIL: contract :: {err}", file=sys.stderr)
    raise SystemExit(1)

if violations:
    for path, msg in violations:
        print(f"D173 FAIL: {path} :: {msg}", file=sys.stderr)
    print(f"D173 FAIL: site topology parity violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D173 PASS: site topology binding parity valid")
PY
