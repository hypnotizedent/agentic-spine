#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/Users/ronnyworks/code/agentic-spine}"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import yaml

root = Path(sys.argv[1])

caps = yaml.safe_load((root / "ops/capabilities.yaml").read_text())
catalog = yaml.safe_load((root / "ops/bindings/capability.domain.catalog.yaml").read_text())
home_bundle = yaml.safe_load((root / "ops/bindings/domains/home-assistant.bundle.yaml").read_text())
tax_bundle = yaml.safe_load((root / "ops/bindings/domains/tax-legal.bundle.yaml").read_text())
home_doc = (root / "docs/governance/domains/home-assistant.md").read_text()
tax_doc = (root / "docs/governance/domains/tax-legal.md").read_text()

cap_map = caps["capabilities"]
home_caps = [cap_id for cap_id, cfg in cap_map.items() if cfg.get("domain") == "home-assistant"]
tax_caps = [cap_id for cap_id, cfg in cap_map.items() if cfg.get("domain") == "tax-legal"]
ha_domain_caps = [cap_id for cap_id, cfg in cap_map.items() if cfg.get("domain") == "ha"]
taxlegal_domain_caps = [cap_id for cap_id, cfg in cap_map.items() if cfg.get("domain") == "taxlegal"]

if len(home_caps) != 39:
    raise SystemExit(f"expected 39 home-assistant capabilities, found {len(home_caps)}")
if len(tax_caps) != 8:
    raise SystemExit(f"expected 8 tax-legal capabilities, found {len(tax_caps)}")
if ha_domain_caps:
    raise SystemExit(f"unexpected domain=ha capabilities: {ha_domain_caps[:5]}")
if taxlegal_domain_caps:
    raise SystemExit(f"unexpected domain=taxlegal capabilities: {taxlegal_domain_caps[:5]}")
if any(not (cap.startswith("ha.") or cap.startswith("ha-")) for cap in home_caps):
    raise SystemExit("home-assistant capabilities must preserve ha runtime ids")
if any(not cap.startswith("taxlegal.") for cap in tax_caps):
    raise SystemExit("tax-legal capabilities must preserve taxlegal runtime ids")

entries = {entry["domain_id"]: entry for entry in catalog["domains"]}
home_entry = entries["home-assistant"]
tax_entry = entries["tax-legal"]

if home_entry["owner_path"] != "ops/plugins/domains/ha/":
    raise SystemExit(f"unexpected home-assistant owner_path: {home_entry['owner_path']}")
if home_entry["owner_repo"] != str(root):
    raise SystemExit(f"unexpected home-assistant owner_repo: {home_entry['owner_repo']}")
if sorted(home_entry["prefixes"]) != ["ha-inventory-", "ha."]:
    raise SystemExit(f"unexpected home-assistant prefixes: {home_entry['prefixes']}")
if tax_entry["owner_path"] != "ops/plugins/domains/taxlegal/":
    raise SystemExit(f"unexpected tax-legal owner_path: {tax_entry['owner_path']}")
if tax_entry["prefixes"] != ["taxlegal."]:
    raise SystemExit(f"unexpected tax-legal prefixes: {tax_entry['prefixes']}")

if home_bundle["domain"] != "home-assistant":
    raise SystemExit("home-assistant bundle domain mismatch")
if tax_bundle["domain"] != "tax-legal":
    raise SystemExit("tax-legal bundle domain mismatch")

home_note = "Runtime namespace: capability ids remain `ha.*` or `ha-inventory-*`"
tax_note = "Runtime namespace: capability ids remain `taxlegal.*`"
if home_note not in home_doc:
    raise SystemExit("home-assistant runtime namespace note missing")
if tax_note not in tax_doc:
    raise SystemExit("tax-legal runtime namespace note missing")

for unexpected in [
    root / "ops/bindings/domains/ha.bundle.yaml",
    root / "ops/bindings/domains/taxlegal.bundle.yaml",
]:
    if unexpected.exists():
        raise SystemExit(f"unexpected alternate canonical bundle present: {unexpected}")

print("PASS: canonical labels remain home-assistant and tax-legal")
print("PASS: runtime ids and directories remain ha/taxlegal")
print("PASS: home-assistant bundle/doc surfaces now exist locally")
PY
