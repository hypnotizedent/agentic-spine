#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/Users/ronnyworks/code/agentic-spine}"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import yaml

root = Path(sys.argv[1])

caps = yaml.safe_load((root / "ops/capabilities.yaml").read_text())["capabilities"]
catalog = yaml.safe_load((root / "ops/bindings/capability.domain.catalog.yaml").read_text())
home_bundle = yaml.safe_load((root / "ops/bindings/domains/home-assistant.bundle.yaml").read_text())
tax_bundle = yaml.safe_load((root / "ops/bindings/domains/tax-legal.bundle.yaml").read_text())
home_doc = (root / "docs/governance/domains/home-assistant.md").read_text()
tax_doc = (root / "docs/governance/domains/tax-legal.md").read_text()

entries = {entry["domain_id"]: entry for entry in catalog["domains"]}

home_caps = sorted(cap_id for cap_id, cfg in caps.items() if cfg.get("domain") == "home-assistant")
tax_caps = sorted(cap_id for cap_id, cfg in caps.items() if cfg.get("domain") == "tax-legal")
home_domain_external = sorted(
    cap_id
    for cap_id, cfg in caps.items()
    if cfg.get("domain") == "home-assistant" and cfg.get("plane") == "domain_external"
)
tax_domain_external = sorted(
    cap_id
    for cap_id, cfg in caps.items()
    if cfg.get("domain") == "tax-legal" and cfg.get("plane") == "domain_external"
)
home_fabric = sorted(cap_id for cap_id in home_caps if cap_id not in home_domain_external)
tax_fabric = sorted(cap_id for cap_id in tax_caps if cap_id not in tax_domain_external)

if len(home_caps) != 39:
    raise SystemExit(f"expected 39 home-assistant capabilities, found {len(home_caps)}")
if len(tax_caps) != 8:
    raise SystemExit(f"expected 8 tax-legal capabilities, found {len(tax_caps)}")
if len(home_domain_external) != 38:
    raise SystemExit(f"expected 38 home-assistant domain_external capabilities, found {len(home_domain_external)}")
if tax_domain_external:
    raise SystemExit(f"expected 0 tax-legal domain_external capabilities, found {tax_domain_external}")
if home_fabric != ["ha.identity.mutation.contract.status"]:
    raise SystemExit(f"unexpected home-assistant fabric set: {home_fabric}")
expected_tax_fabric = [
    "taxlegal.case.intake",
    "taxlegal.case.status",
    "taxlegal.deadlines.refresh",
    "taxlegal.deadlines.status",
    "taxlegal.packet.generate",
    "taxlegal.research.answer",
    "taxlegal.source.ingest",
    "taxlegal.source.recall",
]
if tax_fabric != expected_tax_fabric:
    raise SystemExit(f"unexpected tax-legal fabric set: {tax_fabric}")

home_entry = entries["home-assistant"]
tax_entry = entries["tax-legal"]
if sorted(home_entry["capabilities"]) != home_domain_external:
    raise SystemExit("home-assistant catalog capability list drifted from domain_external truth")
if tax_entry["capabilities"] != []:
    raise SystemExit("tax-legal catalog should stay empty while its governed capabilities remain fabric-only")

if home_bundle["capability_membership"]["total_governed"] != len(home_caps):
    raise SystemExit("home-assistant bundle total_governed mismatch")
if home_bundle["capability_membership"]["catalog_domain_external"] != len(home_domain_external):
    raise SystemExit("home-assistant bundle catalog_domain_external mismatch")
if home_bundle["capability_membership"]["fabric_capabilities"] != home_fabric:
    raise SystemExit("home-assistant bundle fabric capability list mismatch")

if tax_bundle["capability_membership"]["total_governed"] != len(tax_caps):
    raise SystemExit("tax-legal bundle total_governed mismatch")
if tax_bundle["capability_membership"]["catalog_domain_external"] != 0:
    raise SystemExit("tax-legal bundle catalog_domain_external mismatch")
if sorted(tax_bundle["capability_membership"]["fabric_capabilities"]) != expected_tax_fabric:
    raise SystemExit("tax-legal bundle fabric capability list mismatch")

if "Total governed capabilities with `domain: home-assistant`: `39`" not in home_doc:
    raise SystemExit("home-assistant governed membership note missing")
if "Fabric capability kept outside the domain-external catalog: `ha.identity.mutation.contract.status`" not in home_doc:
    raise SystemExit("home-assistant fabric note missing")
if "Total governed capabilities with `domain: tax-legal`: `8`" not in tax_doc:
    raise SystemExit("tax-legal governed membership note missing")
if "`taxlegal.source.recall`" not in tax_doc:
    raise SystemExit("tax-legal fabric membership list missing")

verify_core = sorted(
    cap_id
    for cap_id, cfg in caps.items()
    if cap_id.startswith("verify.") and cfg.get("domain") == "core"
)
verify_none = sorted(
    cap_id
    for cap_id, cfg in caps.items()
    if cap_id.startswith("verify.") and cfg.get("domain") == "none"
)
if len(verify_core) != 18:
    raise SystemExit(f"expected 18 verify.* capabilities in core, found {len(verify_core)}")
if verify_none:
    raise SystemExit(f"verify.* capabilities must no longer remain in domain none: {verify_none}")
if any(not cap_id.startswith("verify.") for cap_id in verify_core):
    raise SystemExit("verify capability ids changed unexpectedly")

none_count = sum(1 for cfg in caps.values() if isinstance(cfg, dict) and cfg.get("domain") == "none")
if none_count > 188:
    raise SystemExit(f"domain:none count grew beyond tranche-3 ceiling of 188, found {none_count}")

maker_caps = sorted(cap_id for cap_id, cfg in caps.items() if cap_id.startswith("maker.") and cfg.get("domain") == "none")
if maker_caps != ["maker.label.print", "maker.qr.generate", "maker.tools.status"]:
    raise SystemExit(f"maker deferrals changed unexpectedly: {maker_caps}")

print("PASS: home-assistant and tax-legal governed membership parity is explicit")
print("PASS: verify.* bounded slice moved from domain none to core")
print("PASS: stale maker.* capabilities remain deferred")
PY
