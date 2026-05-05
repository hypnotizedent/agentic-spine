#!/usr/bin/env bash
set -euo pipefail

# D448: Site Presence Subtraction Truth
# Purpose: canonical site presence readback must exist, and old UniFi/home
# device surfaces must not remain peer current presence authority.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAPS="$ROOT/ops/capabilities.yaml"
SNAPSHOT="$ROOT/ops/bindings/snapshot.surface.contract.yaml"
MASTER="$ROOT/ops/bindings/master.inventory.registry.yaml"
SITE_PRESENCE="$ROOT/ops/plugins/infra/bin/site-presence-status"
CATALOG="$ROOT/ops/bindings/capability.domain.catalog.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"

fail() { echo "D448 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

[[ -x "$SITE_PRESENCE" ]] || fail "missing executable site-presence-status"

python3 - "$ROOT" "$CAPS" "$SNAPSHOT" "$MASTER" "$SITE_PRESENCE" "$CATALOG" "$MANIFEST" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

import yaml

root = Path(sys.argv[1])
caps_path = Path(sys.argv[2])
snapshot_path = Path(sys.argv[3])
master_path = Path(sys.argv[4])
site_presence = Path(sys.argv[5])
catalog_path = Path(sys.argv[6])
manifest_path = Path(sys.argv[7])


def fail(message: str) -> None:
    print(f"D448 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail(f"invalid YAML mapping: {path}")
    return data


caps = load_yaml(caps_path)
cap = (caps.get("capabilities") or {}).get("site.presence.status")
if not isinstance(cap, dict):
    fail("site.presence.status missing from ops/capabilities.yaml")
if cap.get("safety") != "read-only":
    fail("site.presence.status must be read-only")
if cap.get("script_path") != "./ops/plugins/infra/bin/site-presence-status":
    fail("site.presence.status script_path must point at site-presence-status")

snapshot = load_yaml(snapshot_path)
surfaces = ((snapshot.get("data_heartbeat") or {}).get("surfaces") or [])
by_id = {row.get("surface_id"): row for row in surfaces if isinstance(row, dict)}

canonical = by_id.get("site.presence.readback")
if not isinstance(canonical, dict):
    fail("snapshot.surface.contract.yaml missing site.presence.readback")
if canonical.get("authority_layer") != "L2_readmodel":
    fail("site.presence.readback must be L2_readmodel")
if canonical.get("refresh_binding") != "site.presence.status":
    fail("site.presence.readback must refresh from site.presence.status")

for surface_id in [
    "home.device.registry",
    "network.unifi.home.clients.observed",
    "network.unifi.shop.clients.observed",
]:
    row = by_id.get(surface_id)
    if not isinstance(row, dict):
        fail(f"missing {surface_id} in snapshot surface contract")
    if row.get("authority_layer") in {"L1_authority", "L2_authority"}:
        fail(f"{surface_id} still reads as peer authority")
    text = f"{row.get('consumer_policy', '')} {row.get('subtraction_disposition', '')}"
    if "site_presence" not in text and "site.presence.status" not in text:
        fail(f"{surface_id} demotion must name site presence replacement")

home_registry_surface = by_id.get("home.device.registry") or {}
if home_registry_surface.get("refresh_binding") != "site.presence.status":
    fail("home.device.registry refresh_binding must point at site.presence.status, not stale registry reconcile (PACKET-1275)")
proof = home_registry_surface.get("heartbeat", {}).get("proof_channel", {})
if proof.get("ref") != "site.presence.status":
    fail("home.device.registry heartbeat proof must point at replacement site.presence.status readback (PACKET-1275)")

master = load_yaml(master_path)
rows = master.get("rows") or []
master_by_id = {row.get("id"): row for row in rows if isinstance(row, dict)}
if not isinstance(master_by_id.get("authority.site.presence.readback"), dict):
    fail("master inventory missing authority.site.presence.readback row")
for old_id in [
    "authority.home.device.registry",
    "authority.network.unifi.home.clients.observed",
    "authority.network.unifi.shop.clients.observed",
]:
    row = master_by_id.get(old_id)
    if not isinstance(row, dict):
        fail(f"master inventory missing {old_id}")
    authority = row.get("authority") or {}
    if authority.get("expected_authority_state") == "authoritative":
        fail(f"{old_id} still authoritative in master inventory")

for rel in [
    "ops/bindings/home.device.registry.yaml",
    "ops/bindings/network.unifi.home.clients.observed.yaml",
    "ops/bindings/network.unifi.shop.clients.observed.yaml",
]:
    text = (root / rel).read_text(encoding="utf-8")
    if "site.presence.status" not in text:
        fail(f"{rel} must name site.presence.status as replacement")

# PACKET-1270: lock home.device.registry.yaml file-local authority scope.
# Snapshot/master inventory already demote this registry to compatibility
# evidence; the file itself must also carry the same first-class Site
# Intelligence boundary so it cannot be read as current presence, profile,
# admission, placement, role, or recovery authority.
home_device_path = root / "ops/bindings/home.device.registry.yaml"
home_device_doc = yaml.safe_load(home_device_path.read_text(encoding="utf-8")) or {}
if home_device_doc.get("status") != "folded_legacy_input":
    fail("home.device.registry.yaml status must be folded_legacy_input (PACKET-1301)")
if home_device_doc.get("superseded_for_site_presence_by") != "site.presence.status":
    fail("home.device.registry.yaml must declare superseded_for_site_presence_by=site.presence.status (PACKET-1270)")
if home_device_doc.get("folded_into_first_class_system") != "site.presence.status":
    fail("home.device.registry.yaml must declare folded_into_first_class_system=site.presence.status (PACKET-1301)")
if home_device_doc.get("subordinate_to") != "ops/bindings/site.profile.contract.yaml":
    fail("home.device.registry.yaml must declare subordinate_to=ops/bindings/site.profile.contract.yaml (PACKET-1270)")
home_device_scope = home_device_doc.get("authority_scope") or {}
if not isinstance(home_device_scope, dict) or not home_device_scope:
    fail("home.device.registry.yaml must declare authority_scope block (PACKET-1270)")
HOME_DEVICE_REQUIRED_OWNS = {
    "home_declared_device_folded_input",
    "home_device_categorization_vocabulary",
    "home_network_observed_clients_folded_input",
    "home_dhcp_reservation_folded_input",
}
home_device_owns = set(home_device_scope.get("owns") or [])
missing_home_device_owns = HOME_DEVICE_REQUIRED_OWNS - home_device_owns
if missing_home_device_owns:
    fail(f"home.device.registry.yaml authority_scope.owns missing evidence entries: {sorted(missing_home_device_owns)} (PACKET-1270)")
HOME_DEVICE_REQUIRED_DOES_NOT_DECIDE = {
    "current_site_presence",
    "site_profile_authority",
    "physical_machine_identity",
    "node_admission",
    "node_activation",
    "role_assignment",
    "node_placement",
    "node_recovery_readback",
    "recovery_action_authority",
}
home_device_dnd = set(home_device_scope.get("does_not_decide") or [])
missing_home_device_dnd = HOME_DEVICE_REQUIRED_DOES_NOT_DECIDE - home_device_dnd
if missing_home_device_dnd:
    fail(f"home.device.registry.yaml authority_scope.does_not_decide missing boundary entries: {sorted(missing_home_device_dnd)} (PACKET-1270)")

# PACKET-1272: DHCP audit/status surfaces may consume registry DHCP
# reservation intent, but must not teach registries as Site Intelligence or
# current presence authority.
dhcp_caps = caps.get("capabilities") or {}
for cap_name in ["network.home.dhcp.audit", "network.shop.dhcp.audit"]:
    cap_doc = dhcp_caps.get(cap_name) or {}
    desc = cap_doc.get("description") or ""
    if "folded DHCP reservation intent" not in desc:
        fail(f"{cap_name} description must name folded DHCP reservation intent (PACKET-1301)")
    if "site.presence.status remains current Site Intelligence authority" not in desc:
        fail(f"{cap_name} description must point current Site Intelligence authority at site.presence.status (PACKET-1301)")
    if "against home.device.registry.yaml" in desc or "against shop.device.registry.yaml" in desc:
        fail(f"{cap_name} description must not teach registry-as-audit-authority grammar (PACKET-1272)")

reservation_status_desc = (dhcp_caps.get("network.home.dhcp.reservation.status") or {}).get("description") or ""
if "DHCP reservation truth" in reservation_status_desc:
    fail("network.home.dhcp.reservation.status description must not claim generic DHCP truth (PACKET-1274)")
if "folded DHCP intent" not in reservation_status_desc or "site.presence.status remains current Site Intelligence authority" not in reservation_status_desc:
    fail("network.home.dhcp.reservation.status description must bind to folded DHCP intent under site.presence.status (PACKET-1301)")

snapshot_caps = {
    "network.home.unifi.clients.snapshot": "home UniFi observed-client folded input",
    "network.unifi.clients.snapshot": "shop UniFi observed-client folded input",
}
for cap_name, phrase in snapshot_caps.items():
    desc = (dhcp_caps.get(cap_name) or {}).get("description") or ""
    if phrase not in desc:
        fail(f"{cap_name} description must identify observed-client folded input (PACKET-1301)")
    if "site.presence.status remains current Site Intelligence authority" not in desc:
        fail(f"{cap_name} description must point current Site Intelligence authority at site.presence.status (PACKET-1301)")
    if "visibility cannot create node admission" not in desc:
        fail(f"{cap_name} description must subtract visibility-implies-admission grammar (PACKET-1274)")
    for forbidden in ["compatibility projection evidence", "evidence only"]:
        if forbidden in desc:
            fail(f"{cap_name} description must not teach old evidence-only subsystem grammar: {forbidden!r} (PACKET-1301)")

# PACKET-1275: telemetry-proven dead cap families must not remain as
# current catalog, capability, manifest, wrapper-script, refresh-binding, or
# governance-doc authority. The receipt audit behind the packet showed these
# names were either never live/never ran or stale historical wrappers replaced
# by first-class site.presence.status and bounded DHCP/readback caps.
dead_cap_names = {
    "network.home.device.registry.reconcile",
    "network.home.dhcp.dns.set",
    "network.home.dhcp.reservation.create",
    "network.home.wifi.create",
    "network.shop.audit.canonical",
    "network.shop.audit.status",
    "network.shop.dhcp.reservation.create",
    "network.shop.pihole.normalize",
}
allowed_current_texts = {
    "ops/bindings/capability.domain.catalog.yaml": catalog_path.read_text(encoding="utf-8"),
    "ops/capabilities.yaml": caps_path.read_text(encoding="utf-8"),
    "ops/plugins/MANIFEST.yaml": manifest_path.read_text(encoding="utf-8"),
    "ops/bindings/snapshot.surface.contract.yaml": snapshot_path.read_text(encoding="utf-8"),
    "docs/governance/SHOP_SERVER_SSOT.md": (root / "docs/governance/SHOP_SERVER_SSOT.md").read_text(encoding="utf-8"),
}
for rel, text in allowed_current_texts.items():
    present = sorted(name for name in dead_cap_names if name in text)
    if present:
        fail(f"{rel} still carries telemetry-subtracted cap names {present} (PACKET-1275)")
for name in dead_cap_names:
    if name in dhcp_caps:
        fail(f"{name} must not be live in ops/capabilities.yaml after Site Intelligence subtraction (PACKET-1275)")

dead_wrapper_paths = [
    "ops/plugins/infra/network/bin/network-home-dhcp-dns-set",
    "ops/plugins/infra/network/bin/network-home-dhcp-reservation-create",
    "ops/plugins/infra/network/bin/network-home-wifi-create",
    "ops/plugins/infra/network/bin/network-shop-audit-canonical",
    "ops/plugins/infra/network/bin/network-shop-audit-status",
    "ops/plugins/infra/network/bin/network-shop-dhcp-reservation-create",
    "ops/plugins/infra/network/bin/network-shop-pihole-normalize",
]
existing_dead_wrappers = [rel for rel in dead_wrapper_paths if (root / rel).exists()]
if existing_dead_wrappers:
    fail(f"dead unregistered Site Intelligence/network wrapper scripts still tracked: {existing_dead_wrappers} (PACKET-1275)")

shop_ssot_text = allowed_current_texts["docs/governance/SHOP_SERVER_SSOT.md"]
for phrase in ["site.presence.status", "node.admission.status", "network.shop.dhcp.audit"]:
    if phrase not in shop_ssot_text:
        fail(f"SHOP_SERVER_SSOT.md verification must teach current first-class readback {phrase} (PACKET-1275)")

# PACKET-1284: telemetry showed infra.shop.readmodel.generate had zero
# canonical receipts. Do not keep teaching or registering it as a parallel
# shop/site readmodel now that first-class Site Intelligence readbacks are the
# operator-facing truth.
shop_readmodel_retired_name = "infra.shop.readmodel.generate"
if shop_readmodel_retired_name in dhcp_caps:
    fail("infra.shop.readmodel.generate must not remain live in ops/capabilities.yaml (PACKET-1284)")
shop_readmodel_script = root / "ops/plugins/infra/bin/infra-shop-readmodel-generate"
if shop_readmodel_script.exists():
    fail("infra-shop-readmodel-generate script must remain subtracted (PACKET-1284)")
shop_readmodel_texts = {
    "ops/capabilities.yaml": caps_path.read_text(encoding="utf-8"),
    "ops/plugins/MANIFEST.yaml": manifest_path.read_text(encoding="utf-8"),
    "docs/governance/SHOP_SERVER_SSOT.md": shop_ssot_text,
    "docs/governance/DEVICE_IDENTITY_SSOT.md": (root / "docs/governance/DEVICE_IDENTITY_SSOT.md").read_text(encoding="utf-8"),
}
for rel, text in shop_readmodel_texts.items():
    if shop_readmodel_retired_name in text or "infra-shop-readmodel-generate" in text:
        fail(f"{rel} still teaches retired shop readmodel generator (PACKET-1284)")

dhcp_script_expectations = [
    (
        "ops/plugins/infra/network/bin/network-home-dhcp-audit",
        [
            "folded DHCP intent",
            "canonical_site_presence: $SITE_PRESENCE_AUTHORITY",
            "intent_source: ops/bindings/home.device.registry.yaml",
            "folded_into_first_class_system",
        ],
    ),
    (
        "ops/plugins/infra/network/bin/network-shop-dhcp-audit",
        [
            "folded DHCP intent",
            "canonical_site_presence: $SITE_PRESENCE_AUTHORITY",
            "intent_source: ops/bindings/shop.device.registry.yaml",
            "folded_into_first_class_system",
        ],
    ),
    (
        "ops/plugins/infra/network/bin/network-home-dhcp-reservation-status",
        [
            "folded DHCP reservation intent",
            'SITE_PRESENCE_AUTHORITY = "site.presence.status"',
            "device not found in folded DHCP intent sources",
        ],
    ),
    (
        "ops/plugins/infra/network/bin/network-home-unifi-clients-snapshot",
        [
            "folded observation input",
            "SITE_PRESENCE_AUTHORITY=\"site.presence.status\"",
            "FOLDED_ROLE=\"folded_observation_input\"",
            ".canonical_site_presence",
            ".folded_into_first_class_system",
        ],
    ),
    (
        "ops/plugins/infra/network/bin/network-unifi-clients-snapshot",
        [
            "folded observation input",
            "SITE_PRESENCE_AUTHORITY=\"site.presence.status\"",
            "FOLDED_ROLE=\"folded_observation_input\"",
            ".canonical_site_presence",
            ".folded_into_first_class_system",
        ],
    ),
]
for rel, required_fragments in dhcp_script_expectations:
    text = (root / rel).read_text(encoding="utf-8")
    if "against device registry" in text:
        fail(f"{rel} must not teach DHCP audit against generic device registry (PACKET-1272)")
    for fragment in required_fragments:
        if fragment not in text:
            fail(f"{rel} missing DHCP/Site Intelligence boundary fragment {fragment!r} (PACKET-1272)")
    if rel.endswith("-dhcp-audit"):
        if 'SPINE_REPO="$SPINE_ROOT"' not in text or 'SPINE_CODE="$SPINE_ROOT"' not in text:
            fail(f"{rel} must bind Infisical lookup to the canonical spine root instead of ambient SPINE_REPO (PACKET-1312)")

shop_dhcp_text = (root / "ops/plugins/infra/network/bin/network-shop-dhcp-audit").read_text(encoding="utf-8")
for fragment in ['.data | type == "array"', "yaml.safe_dump", "unregistered_clients"]:
    if fragment not in shop_dhcp_text:
        fail(f"network-shop-dhcp-audit must use hardened YAML/unregistered-client path fragment {fragment!r} (PACKET-1308)")

for cap_name, cap_doc in sorted(dhcp_caps.items()):
    if not cap_name.startswith("host.operator-hardware."):
        continue
    desc = cap_doc.get("description") or ""
    if "site.presence.status is Site Intelligence read authority" not in desc:
        fail(f"{cap_name} must teach host.operator-hardware is not Site Intelligence read authority (PACKET-1308)")

backup_status_desc = (dhcp_caps.get("backup.status") or {}).get("description") or ""
if "NOT primary estate truth" not in backup_status_desc or "backup.estate.readback.status" not in backup_status_desc:
    fail("backup.status capability must remain drilldown only; backup.estate.readback.status owns estate truth (PACKET-1308)")

projection_contract = yaml.safe_load((root / "ops/bindings/domain.projection.contract.yaml").read_text(encoding="utf-8")) or {}
projection_rows = projection_contract.get("projections") or projection_contract.get("rows") or []
projection_by_id = {row.get("id"): row for row in projection_rows if isinstance(row, dict)}
for projection_id in [
    "projection.network.unifi.home.clients.observed",
    "projection.network.unifi.shop.clients.observed",
]:
    projection = projection_by_id.get(projection_id) or {}
    markers = projection.get("required_markers") or []
    marker_pairs = {(m.get("key"), m.get("equals")) for m in markers if isinstance(m, dict)}
    if ("superseded_for_site_presence_by", "site.presence.status") not in marker_pairs:
        fail(f"{projection_id} must require superseded_for_site_presence_by=site.presence.status (PACKET-1274)")

# One all-sites JSON sample feeds both the home-row assertions and the
# site-profile assertions below. This keeps the first-class readback intact
# while avoiding duplicate site.presence.status subprocess rebuilds.
proc_all = subprocess.run([str(site_presence), "--json"], text=True, capture_output=True)
if proc_all.returncode != 0:
    fail(f"site.presence.status --json (all sites) must succeed: {proc_all.stderr.strip()[:200]}")
all_payload = json.loads(proc_all.stdout)
if all_payload.get("canonical_authority") != "site.presence.status":
    fail("site.presence.status payload missing canonical authority")
system = all_payload.get("first_class_system") or {}
if system.get("name") != "first_class_site_intelligence":
    fail("site.presence.status payload must emit first_class_system.name=first_class_site_intelligence (PACKET-1301)")
stages = {row.get("stage") for row in (system.get("lifecycle") or []) if isinstance(row, dict)}
for required_stage in ["site_profile", "topology", "presence", "node_admission", "bootstrap", "provisioning"]:
    if required_stage not in stages:
        fail(f"site.presence.status first_class_system.lifecycle missing stage {required_stage!r} (PACKET-1301)")
folded_inputs = all_payload.get("folded_legacy_inputs") or []
folded_paths = {row.get("path") for row in folded_inputs if isinstance(row, dict)}
for required_path in [
    "ops/bindings/home.device.registry.yaml",
    "ops/bindings/network.unifi.home.clients.observed.yaml",
    "ops/bindings/network.unifi.shop.clients.observed.yaml",
    "ops/bindings/home.unifi.network.inventory.yaml",
    "ops/bindings/shop.device.registry.yaml",
    "ops/bindings/home.storage.map.yaml",
    "ops/bindings/shop.storage.map.yaml",
]:
    if required_path not in folded_paths:
        fail(f"site.presence.status folded_legacy_inputs missing {required_path} (PACKET-1301)")
for item in folded_inputs:
    if isinstance(item, dict) and item.get("standalone_operator_surface") is not False:
        fail(f"folded legacy input must not remain standalone operator surface: {item} (PACKET-1301)")

for rel in ["ops/bindings/home.storage.map.yaml", "ops/bindings/shop.storage.map.yaml"]:
    storage_map = yaml.safe_load((root / rel).read_text(encoding="utf-8")) or {}
    if storage_map.get("subordinate_to") != "ops/bindings/storage.scaffold.authority.yaml":
        fail(f"{rel} must declare subordinate_to=ops/bindings/storage.scaffold.authority.yaml (PACKET-1308)")
    if storage_map.get("superseded_for_storage_truth_by") != "payload.custody.status":
        fail(f"{rel} must declare superseded_for_storage_truth_by=payload.custody.status (PACKET-1308)")
    if storage_map.get("superseded_for_payload_custody_by") != "payload.custody.status":
        fail(f"{rel} must declare superseded_for_payload_custody_by=payload.custody.status (PACKET-1308)")
freshness_summary = all_payload.get("freshness_summary") or {}
if "stale" not in freshness_summary:
    fail("site.presence.status must emit freshness_summary with stale input count (PACKET-1301 honesty)")
profile_summary = all_payload.get("profile_summary") or {}
if not isinstance(profile_summary.get("unverified_fields_by_site"), dict):
    fail("site.presence.status must emit profile_summary.unverified_fields_by_site (PACKET-1301 honesty)")
all_rows_for_convergence = [row for row in (all_payload.get("rows") or []) if isinstance(row, dict)]
if not all_rows_for_convergence:
    fail("site.presence.status --json emitted no rows")
CONVERGENCE_REQUIRED = {
    "network_visibility_proof",
    "identity_state",
    "hardware_class",
    "bootstrap_state",
    "storage_tier",
    "storage_scaffold_class",
    "storage_custody_state",
    "storage_evidence_ref",
    "backup_posture",
}
NETWORK_VISIBILITY = {"udr_observed", "declared_only", "unifi_snapshot_stale", "none"}
IDENTITY_STATES = {"unknown", "declared", "ssh_target", "candidate", "admitted", "excluded"}
BOOTSTRAP_STATES = {"unknown", "unprovisioned", "first_touch_claimed", "bootstrapped", "post_boot_normalized"}
for row in all_rows_for_convergence:
    presence_id = row.get("presence_id") or "<unknown>"
    missing_convergence = sorted(CONVERGENCE_REQUIRED - set(row.keys()))
    if missing_convergence:
        fail(f"{presence_id}: site.presence.status row missing convergence fields {missing_convergence} (PACKET-1308)")
    source_paths = {item.get("path") for item in (row.get("source_surfaces") or []) if isinstance(item, dict)}
    if row.get("network_visibility_proof") not in NETWORK_VISIBILITY:
        fail(f"{presence_id}: invalid network_visibility_proof={row.get('network_visibility_proof')!r} (PACKET-1308)")
    if row.get("identity_state") not in IDENTITY_STATES:
        fail(f"{presence_id}: invalid identity_state={row.get('identity_state')!r} (PACKET-1308)")
    if row.get("bootstrap_state") not in BOOTSTRAP_STATES:
        fail(f"{presence_id}: invalid bootstrap_state={row.get('bootstrap_state')!r} (PACKET-1308)")
    if row.get("identity_state") == "admitted" and "node.admission.status" not in source_paths:
        fail(f"{presence_id}: identity_state=admitted must source node.admission.status (PACKET-1308)")
    if row.get("identity_state") == "ssh_target" and "ops/bindings/ssh.targets.yaml" not in source_paths:
        fail(f"{presence_id}: identity_state=ssh_target must source ops/bindings/ssh.targets.yaml (PACKET-1308)")
    if row.get("bootstrap_state") != "unknown" and "node.admission.status" not in source_paths:
        fail(f"{presence_id}: non-unknown bootstrap_state must source node.admission.status (PACKET-1308)")
    if row.get("storage_custody_state") != "unknown" and "payload.custody.status" not in source_paths:
        fail(f"{presence_id}: non-unknown storage_custody_state must source payload.custody.status (PACKET-1308)")
    if row.get("backup_posture") != "unknown" and "backup.estate.readback.status" not in source_paths:
        fail(f"{presence_id}: non-unknown backup_posture must source backup.estate.readback.status (PACKET-1308)")
    subject = row.get("subject") or {}
    if subject.get("subject_kind") == "unknown_observed":
        if row.get("match_state") != "observed_only_unknown_identity":
            fail(f"{presence_id}: unknown_observed row must use observed_only_unknown_identity match_state (PACKET-1308)")
        if row.get("actions_allowed", {}).get("may_create_node") is not False:
            fail(f"{presence_id}: unknown_observed row must not allow node creation (PACKET-1308)")
rows = [row for row in (all_payload.get("rows") or []) if isinstance(row, dict) and row.get("site") == "home"]
if not rows:
    fail("site.presence.status --json emitted no home-site rows")
required = [
    "presence_id",
    "site",
    "network_scope",
    "subject",
    "identity",
    "presence_state",
    "match_state",
    "proof_channels",
    "freshness",
    "source_surfaces",
    "actions_allowed",
    "subtraction_caption",
    "network_visibility_proof",
    "identity_state",
    "hardware_class",
    "bootstrap_state",
    "storage_tier",
    "storage_scaffold_class",
    "storage_custody_state",
    "storage_evidence_ref",
    "backup_posture",
]
missing = [field for field in required if field not in rows[0]]
if missing:
    fail(f"site.presence.status row missing fields: {', '.join(missing)}")
for row in rows:
    presence_id = row.get("presence_id") or "<unknown>"
    if row.get("actions_allowed", {}).get("may_create_node") is not False:
        fail(f"{presence_id}: site.presence.status must not allow node creation")
    for action in ["may_admit_node", "may_bootstrap_subject", "may_provision_subject"]:
        if row.get("actions_allowed", {}).get(action) is not False:
            fail(f"{presence_id}: site.presence.status must not allow {action} (PACKET-1301)")
    subject = row.get("subject") or {}
    admission_state = subject.get("node_admission_state", "not_node")
    subject_kind = subject.get("subject_kind")
    sources = row.get("source_surfaces") or []
    source_paths = {item.get("path") for item in sources if isinstance(item, dict)}
    if admission_state != "not_node" and "node.admission.status" not in source_paths:
        fail(f"{presence_id}: non-not_node admission state must be joined from node.admission.status")
    if subject_kind in {"candidate_node", "admitted_node"} and "node.admission.status" not in source_paths:
        fail(f"{presence_id}: node-like subject_kind must be joined from node.admission.status")
    if admission_state == "admitted" and subject_kind != "admitted_node":
        fail(f"{presence_id}: admitted node admission state must read back as admitted_node")
    if "network.unifi" in " ".join(str(path) for path in source_paths) and admission_state == "admitted" and "node.admission.status" not in source_paths:
        fail(f"{presence_id}: network observation must not imply admitted node truth")

# PACKET-1115: site.profile first-class HI primitive lock.
# Asserts (a) contract exists+parses+correct-scope, (b) extension_set rows
# carry required fields, (c) site_id ⊆ topology ∪ extension_set (gate READS
# extension_set from contract — not hardcoded here), (d) sentinel "unknown"
# present, (e) required row fields present, (f) topology_origin_reason
# non-empty when origin != topology.sites, (g) two-direction unverified rule,
# (h) all-sites JSON has top-level site_profiles block, (i) site_profiles
# keys match contract sites, (j) every row has profile_ref, (k) every
# profile_ref ∈ contract sites, (l) sentinel rule: profile_ref==unknown ONLY
# when row.site==unknown, (m) human readback teaches Site Profiles section.
#
# extension_set is single source of truth in the contract; gate must not
# duplicate it. unverified is allowed only where intentionally declared via
# unverified_fields list.

site_profile_path = root / "ops/bindings/site.profile.contract.yaml"
if not site_profile_path.exists():
    fail("ops/bindings/site.profile.contract.yaml missing (PACKET-1115)")
site_profile_doc = yaml.safe_load(site_profile_path.read_text(encoding="utf-8")) or {}
if site_profile_doc.get("scope") != "hardware-intelligence-site-profile-ssot":
    fail("site.profile.contract.yaml scope must be hardware-intelligence-site-profile-ssot (PACKET-1115)")
if "no per-site inventory authority" not in site_profile_path.read_text(encoding="utf-8"):
    fail("site.profile.contract.yaml shop notes must subtract per-site shop UniFi inventory authority gap (PACKET-1308)")

blueprint = yaml.safe_load((root / "ops/bindings/operator.blueprint.admission.yaml").read_text(encoding="utf-8")) or {}
bpa016 = next((row for row in (blueprint.get("entries") or []) if isinstance(row, dict) and row.get("id") == "BPA-016"), None)
if not isinstance(bpa016, dict):
    fail("operator.blueprint.admission.yaml missing BPA-016 (PACKET-1308)")
if bpa016.get("decision") != "materialize" or bpa016.get("status") != "proved":
    fail("BPA-016 must read decision=materialize and status=proved after Site Intelligence convergence (PACKET-1308)")
if "materialization_gap" in bpa016:
    fail("BPA-016 must not retain materialization_gap after convergence closeout (PACKET-1308)")
if "materialization_closeout" not in bpa016:
    fail("BPA-016 must carry materialization_closeout after convergence closeout (PACKET-1308)")

# (b) extension_set rows carry required fields
extension_set = site_profile_doc.get("extension_set") or []
if not isinstance(extension_set, list) or not extension_set:
    fail("site.profile.contract.yaml extension_set must be a non-empty list (PACKET-1115)")
EXTENSION_REQUIRED = {"site_id", "topology_origin", "topology_origin_reason"}
for ext in extension_set:
    if not isinstance(ext, dict):
        fail("site.profile extension_set entries must be mappings (PACKET-1115)")
    miss = EXTENSION_REQUIRED - set(ext.keys())
    if miss:
        fail(f"site.profile extension_set entry missing fields {sorted(miss)} (PACKET-1115)")

# (n) extension_set site_ids unique
extension_id_list = [e["site_id"] for e in extension_set]
if len(extension_id_list) != len(set(extension_id_list)):
    dupes = sorted({sid for sid in extension_id_list if extension_id_list.count(sid) > 1})
    fail(f"site.profile extension_set has duplicate site_ids: {dupes} (PACKET-1115)")
extension_ids = set(extension_id_list)
extension_by_id = {e["site_id"]: e for e in extension_set}

# (c) cross-reference rule: profile.site_id ⊆ topology.sites[].id ∪ extension_set
topology_doc = yaml.safe_load((root / "ops/bindings/topology.sites.yaml").read_text(encoding="utf-8")) or {}
topology_ids = {s.get("id") for s in (topology_doc.get("sites") or []) if isinstance(s, dict)}
profile_rows = site_profile_doc.get("sites") or []
if not profile_rows:
    fail("site.profile.contract.yaml sites: must be non-empty (PACKET-1115)")

# (o) profile sites_ids unique
profile_id_list = [r.get("site_id") for r in profile_rows if isinstance(r, dict)]
if len(profile_id_list) != len(set(profile_id_list)):
    dupes = sorted({sid for sid in profile_id_list if profile_id_list.count(sid) > 1})
    fail(f"site.profile.sites has duplicate site_ids: {dupes} (PACKET-1115)")
profile_ids = set(profile_id_list)

allowed_ids = topology_ids | extension_ids
unauthorized = profile_ids - allowed_ids
if unauthorized:
    fail(f"site.profile.site_id outside topology ∪ extension_set: {sorted(unauthorized)} (PACKET-1115)")

# (p) extension_set IDs disjoint from topology.sites[].id
overlap = extension_ids & topology_ids
if overlap:
    fail(f"site.profile extension_set overlaps topology.sites[].id: {sorted(overlap)} (PACKET-1115; extension_set must be disjoint)")

# (d) Sentinel row present
if "unknown" not in profile_ids:
    fail("site.profile.contract.yaml must contain sentinel row site_id=unknown (PACKET-1115)")

# (s) extension_set MUST contain "unknown" with topology_origin: sentinel
if "unknown" not in extension_ids:
    fail("site.profile.contract.yaml extension_set must contain unknown sentinel entry (PACKET-1115)")
unknown_ext = extension_by_id["unknown"]
if unknown_ext.get("topology_origin") != "sentinel":
    fail(f"site.profile extension_set unknown entry must have topology_origin=sentinel (PACKET-1115; got {unknown_ext.get('topology_origin')!r})")

# (e) Required row fields per profile
PROFILE_REQUIRED = {"site_id", "site_role", "network_profile", "power_profile",
                    "operational_priority", "topology_origin", "unverified_fields"}
for prow in profile_rows:
    miss = PROFILE_REQUIRED - set(prow.keys())
    if miss:
        fail(f"site.profile row {prow.get('site_id')!r} missing fields {sorted(miss)} (PACKET-1115)")

# (f) topology_origin_reason required when topology_origin != topology.sites
for prow in profile_rows:
    origin = prow.get("topology_origin")
    reason = prow.get("topology_origin_reason") or ""
    if origin != "topology.sites" and not reason:
        fail(f"site.profile row {prow.get('site_id')!r} topology_origin={origin!r} requires non-empty topology_origin_reason (PACKET-1115)")

# (q) if profile.site_id ∈ topology.sites[].id, topology_origin MUST be
#     "topology.sites" and topology_origin_reason MUST be empty
for prow in profile_rows:
    sid = prow.get("site_id")
    origin = prow.get("topology_origin")
    reason = prow.get("topology_origin_reason") or ""
    if sid in topology_ids:
        if origin != "topology.sites":
            fail(f"site.profile row {sid!r} is in topology.sites but topology_origin={origin!r} (PACKET-1115; must be 'topology.sites')")
        if reason != "":
            fail(f"site.profile row {sid!r} is in topology.sites but topology_origin_reason={reason!r} (PACKET-1115; must be empty)")

# (r) if profile.site_id ∈ extension_set, topology_origin and
#     topology_origin_reason MUST exactly match the extension_set entry
for prow in profile_rows:
    sid = prow.get("site_id")
    if sid in extension_ids:
        ext_entry = extension_by_id[sid]
        ext_origin = ext_entry.get("topology_origin")
        ext_reason = ext_entry.get("topology_origin_reason") or ""
        row_origin = prow.get("topology_origin")
        row_reason = prow.get("topology_origin_reason") or ""
        if row_origin != ext_origin:
            fail(f"site.profile row {sid!r} topology_origin={row_origin!r} != extension_set entry {ext_origin!r} (PACKET-1115; must exactly match)")
        if row_reason != ext_reason:
            fail(f"site.profile row {sid!r} topology_origin_reason={row_reason!r} != extension_set entry {ext_reason!r} (PACKET-1115; must exactly match)")

# (g) Two-direction unverified rule
HI_FIELDS = {"site_role", "network_profile", "power_profile", "operational_priority"}
for prow in profile_rows:
    sid = prow.get("site_id")
    unv_fields = set(prow.get("unverified_fields") or [])
    for field in HI_FIELDS:
        value = prow.get(field)
        in_unv = field in unv_fields
        if in_unv and value != "unverified":
            fail(f"site.profile row {sid!r} field {field}: declared unverified but value={value!r} (PACKET-1115; two-direction rule)")
        if (not in_unv) and value == "unverified":
            fail(f"site.profile row {sid!r} field {field}: value=unverified but field not declared in unverified_fields (PACKET-1115; two-direction rule)")

# (h)+(i) site.presence.status all-sites JSON emits site_profiles matching contract
emitted_profiles = all_payload.get("site_profiles")
if not isinstance(emitted_profiles, dict) or not emitted_profiles:
    fail("site.presence.status must emit non-empty top-level site_profiles block (PACKET-1115)")
if set(emitted_profiles.keys()) != profile_ids:
    fail(f"site.presence site_profiles keys must equal contract sites: contract={sorted(profile_ids)} emitted={sorted(emitted_profiles.keys())} (PACKET-1115)")

# (j) every row has profile_ref
all_rows = all_payload.get("rows") or []
miss_pref = [r.get("presence_id") for r in all_rows if "profile_ref" not in r]
if miss_pref:
    fail(f"site.presence rows missing profile_ref: {miss_pref[:5]} (PACKET-1115)")

# (k) every profile_ref ∈ site_profiles keys
bad_pref = [(r.get("presence_id"), r.get("profile_ref")) for r in all_rows if r.get("profile_ref") not in emitted_profiles]
if bad_pref:
    fail(f"site.presence rows have profile_ref outside site_profiles: {bad_pref[:5]} (PACKET-1115)")

# (l) Sentinel rule: profile_ref==unknown ONLY when row.site==unknown
sentinel_misuse = [
    (r.get("presence_id"), r.get("site"))
    for r in all_rows
    if r.get("profile_ref") == "unknown" and r.get("site") != "unknown"
]
if sentinel_misuse:
    fail(f"site.presence rows fell back to profile_ref:unknown but row.site is not unknown: {sentinel_misuse[:5]} (PACKET-1115; sentinel only valid for unknown rows)")

# (m) Human readback teaches Site Profiles section
proc_h = subprocess.run([str(site_presence)], text=True, capture_output=True)
if proc_h.returncode != 0:
    fail(f"site.presence.status (human readback) must succeed (PACKET-1115)")
if "Site Profiles:" not in proc_h.stdout:
    fail("site.presence.status human readback must teach 'Site Profiles:' section (PACKET-1115)")

# PACKET-1145: lock both authority carriers for home.unifi.network.inventory.yaml.
# (t) Leaf carrier — file folded from authoritative/compatibility projection
#     declares subordinate_to site.profile.contract.yaml, must NOT carry an
#     unqualified `authority` field (use evidence_lineage instead).
# (u) Parent carrier — home.authority.contract.yaml row redirects to site.profile
#     via subordinate_to AND to site.presence.status via replacement_readback,
#     scope names folded_legacy_projection. Three-field lock on the parent.
# Subtracts authority, not evidence; UDR API readback content preserved.

home_unifi_path = root / "ops/bindings/home.unifi.network.inventory.yaml"
if home_unifi_path.exists():
    leaf = yaml.safe_load(home_unifi_path.read_text(encoding="utf-8")) or {}
    if leaf.get("status") == "authoritative":
        fail("home.unifi.network.inventory.yaml status must not be authoritative; HI doctrine: site.profile is canonical interpreter (PACKET-1145)")
    if leaf.get("subordinate_to") != "ops/bindings/site.profile.contract.yaml":
        fail("home.unifi.network.inventory.yaml must declare subordinate_to=ops/bindings/site.profile.contract.yaml (PACKET-1145)")
    if "authority" in leaf:
        fail("home.unifi.network.inventory.yaml must not declare unqualified 'authority' field (use evidence_lineage instead) (PACKET-1145)")

home_auth_path = root / "ops/bindings/home.authority.contract.yaml"
if home_auth_path.exists():
    home_auth = yaml.safe_load(home_auth_path.read_text(encoding="utf-8")) or {}
    inventories = home_auth.get("inventories") or []
    unifi_entry = next(
        (e for e in inventories if isinstance(e, dict) and e.get("path") == "ops/bindings/home.unifi.network.inventory.yaml"),
        None,
    )
    if unifi_entry is not None:
        scope_value = unifi_entry.get("scope") or ""
        if "folded_legacy_projection" not in scope_value:
            fail(f"home.authority.contract.yaml inventories[home.unifi.network.inventory.yaml] scope must name folded_legacy_projection, got {scope_value!r} (PACKET-1301)")
        if unifi_entry.get("subordinate_to") != "ops/bindings/site.profile.contract.yaml":
            fail("home.authority.contract.yaml inventories[home.unifi.network.inventory.yaml] must declare subordinate_to=ops/bindings/site.profile.contract.yaml (PACKET-1145)")
        if unifi_entry.get("replacement_readback") != "site.presence.status":
            fail("home.authority.contract.yaml inventories[home.unifi.network.inventory.yaml] must declare replacement_readback=site.presence.status (PACKET-1145)")

# PACKET-1215/PACKET-1308: lock Site Intelligence canonical-authority +
# evidence-boundary teaching.
# (v) JSON must not retain the legacy subtracted_peer_authority compatibility
#     key; folded_legacy_inputs is the canonical subtraction readback.
# (w) Human readback must teach the first-class lifecycle (Site Intelligence is
#     authority; topology stays separate; legacy inputs are folded).

if "subtracted_peer_authority" in all_payload:
    fail("site.presence.status JSON must not emit legacy subtracted_peer_authority; use folded_legacy_inputs (PACKET-1308)")

required_teaching_phrases = [
    "First-Class Site Intelligence Lifecycle:",
    "node_admission",
    "bootstrap",
    "provisioning",
    # PACKET-1329: header demoted from "(not operator-facing subsystems)" to
    # "(implementation detail, not operator first-read)" so a fresh agent
    # reads folded inputs as private/folded, never as a peer dashboard knob.
    "Folded legacy inputs (implementation detail, not operator first-read):",
    "Drilldown levers (only):",
    "ops/bindings/site.profile.contract.yaml",
    "ops/bindings/topology.sites.yaml",
]
for phrase in required_teaching_phrases:
    if phrase not in proc_h.stdout:
        fail(f"site.presence.status human readback must teach {phrase!r} (PACKET-1215)")

# PACKET-1329: minimal-lever model lock. site.presence.status must emit a
# closed set of authorized drilldown levers (branch_authority + bounded
# producers) so a fresh agent does not chase old peer dashboard knobs.
# Both JSON payload and human readback must agree on the closed set.
drilldown_levers_payload = all_payload.get("drilldown_levers")
if not isinstance(drilldown_levers_payload, list) or not drilldown_levers_payload:
    fail("site.presence.status JSON must emit non-empty drilldown_levers list (PACKET-1329)")
required_levers = {
    "node.admission.status",
    "payload.custody.status",
    "backup.estate.readback.status",
    "network.home.unifi.clients.snapshot",
    "network.unifi.clients.snapshot",
    "network.home.dhcp.audit",
    "network.shop.dhcp.audit",
}
emitted_levers = {row.get("lever") for row in drilldown_levers_payload if isinstance(row, dict)}
missing_levers = required_levers - emitted_levers
if missing_levers:
    fail(f"site.presence.status drilldown_levers missing {sorted(missing_levers)} (PACKET-1329)")
extra_levers = emitted_levers - required_levers
if extra_levers:
    fail(f"site.presence.status drilldown_levers must remain closed set; unexpected entries {sorted(extra_levers)} (PACKET-1329)")
for row in drilldown_levers_payload:
    kind = (row or {}).get("kind")
    if kind not in {"branch_authority", "bounded_producer"}:
        fail(f"site.presence.status drilldown_levers entry must declare kind in {{branch_authority, bounded_producer}}, got {kind!r} (PACKET-1329)")
fcs_block = all_payload.get("first_class_system") or {}
if fcs_block.get("operator_first_read") != "site.presence.status":
    fail("site.presence.status first_class_system.operator_first_read must be 'site.presence.status' (PACKET-1329)")
if fcs_block.get("drilldown_levers_policy") != "closed_set":
    fail("site.presence.status first_class_system.drilldown_levers_policy must be 'closed_set' (PACKET-1329)")
for lever in required_levers:
    if lever not in proc_h.stdout:
        fail(f"site.presence.status human readback must teach drilldown lever {lever!r} (PACKET-1329)")

# PACKET-1317: lock coverage reconciliation behavior in place.
# (x) freshness_summary must always emit canonical state keys (fresh, stale,
#     policy_missing, declared_only) — disappearing keys after a refresh
#     would silently hide stale debt; honest zero-counts stay visible.
# (y) freshness_from_surface must resolve actual fresh/stale state from
#     freshness_policy.max_age_hours rather than hardcoding stale; rows
#     observed within the policy window must read network_visibility_proof
#     != "unifi_snapshot_stale" when freshness state is "fresh".
# (z) network.shop.dhcp.audit must emit unregistered_classification with
#     the five canonical buckets so the unregistered-client set stops
#     floating as audit-only bloat. Folded-input role only — node admission
#     authority remains site.presence.status / node.admission.status.

# (x) canonical freshness keys
freshness_required_keys = {"fresh", "stale", "policy_missing", "declared_only"}
freshness_keys = set(freshness_summary.keys())
missing_freshness = freshness_required_keys - freshness_keys
if missing_freshness:
    fail(f"site.presence.status freshness_summary missing canonical keys {sorted(missing_freshness)} (PACKET-1317)")

# (y) network_visibility_proof must agree with freshness state
for row in all_rows_for_convergence:
    fstate = (row.get("freshness") or {}).get("state")
    nvp = row.get("network_visibility_proof")
    if fstate == "fresh" and nvp == "unifi_snapshot_stale":
        fail(f"{row.get('presence_id')}: freshness=fresh must not read network_visibility_proof=unifi_snapshot_stale (PACKET-1317)")
    if fstate == "stale" and nvp not in {"unifi_snapshot_stale", "declared_only", "none"}:
        fail(f"{row.get('presence_id')}: freshness=stale must read unifi_snapshot_stale (PACKET-1317; got {nvp!r})")

# Cap source must declare freshness_policy resolution and never hardcode
# state="stale" as the only return path.
sps_text = (root / "ops/plugins/infra/bin/site-presence-status").read_text(encoding="utf-8")
if "freshness_policy_resolved" not in sps_text:
    fail("site-presence-status must resolve freshness from freshness_policy (PACKET-1317)")
if 'state = "stale" if age_hours > float(max_age_hours) else "fresh"' not in sps_text:
    fail("site-presence-status freshness resolver must compare age_hours against max_age_hours (PACKET-1317)")

# (z) shop dhcp audit unregistered_classification
shop_dhcp_audit_path = root / "ops/bindings/shop.dhcp.audit.yaml"
if shop_dhcp_audit_path.exists():
    shop_audit = yaml.safe_load(shop_dhcp_audit_path.read_text(encoding="utf-8")) or {}
    classification = shop_audit.get("unregistered_classification")
    if not isinstance(classification, dict):
        fail("shop.dhcp.audit.yaml must emit unregistered_classification mapping (PACKET-1317)")
    bucket_keys = {
        "already_declared_other_key",
        "transient_non_node",
        "observed_only_unknown",
        "stale_snapshot_artifact",
        "candidate_pending_admission",
    }
    missing_buckets = bucket_keys - set(classification.keys())
    if missing_buckets:
        fail(f"shop.dhcp.audit.yaml unregistered_classification missing buckets {sorted(missing_buckets)} (PACKET-1317)")
    classified_total = sum(len(rows) for rows in classification.values() if isinstance(rows, list))
    declared_total = (shop_audit.get("summary") or {}).get("unregistered_clients") or 0
    if classified_total != declared_total:
        fail(f"shop.dhcp.audit.yaml classified count {classified_total} != unregistered_clients {declared_total} (PACKET-1317)")
    cls_summary = (shop_audit.get("summary") or {}).get("unregistered_classification") or {}
    if set(cls_summary.keys()) != bucket_keys:
        fail(f"shop.dhcp.audit.yaml summary.unregistered_classification keys must equal {sorted(bucket_keys)} (PACKET-1317)")
shop_dhcp_audit_text = (root / "ops/plugins/infra/network/bin/network-shop-dhcp-audit").read_text(encoding="utf-8")
for fragment in [
    "unregistered_classification",
    "already_declared_other_key",
    "transient_non_node",
    "observed_only_unknown",
    "stale_snapshot_artifact",
    "candidate_pending_admission",
]:
    if fragment not in shop_dhcp_audit_text:
        fail(f"network-shop-dhcp-audit must declare classification bucket {fragment!r} (PACKET-1317)")

print(
    "D448 PASS: site.presence.status is the single operator first-read for Site "
    "Intelligence; site profile, topology, presence, node admission, bootstrap, "
    "and provisioning boundaries hold; row fields network_visibility_proof, "
    "identity_state, hardware_class, bootstrap_state, storage_custody_state, and "
    "backup_posture compose without inferring node admission from network "
    "visibility; the drilldown lever set is closed (branch authorities and "
    "bounded producers only); remaining registries, UniFi observed snapshots, "
    "storage maps, and DHCP audits are non-authoritative folded/generated inputs "
    "with explicit producer or canonical consumer; retired cap names and "
    "wrappers stay absent from live grammar; freshness state is resolved from "
    "declared policy max_age_hours and the summary always emits canonical state "
    "keys; shop unregistered clients are classified into bounded folded-input "
    "buckets."
)
PY
