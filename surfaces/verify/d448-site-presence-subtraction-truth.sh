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

fail() { echo "D448 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

[[ -x "$SITE_PRESENCE" ]] || fail "missing executable site-presence-status"

python3 - "$ROOT" "$CAPS" "$SNAPSHOT" "$MASTER" "$SITE_PRESENCE" <<'PY'
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

proc = subprocess.run([str(site_presence), "--site", "home", "--json"], text=True, capture_output=True)
if proc.returncode != 0:
    fail(proc.stderr.strip() or proc.stdout.strip() or "site.presence.status sample failed")
payload = json.loads(proc.stdout)
if payload.get("canonical_authority") != "site.presence.status":
    fail("site.presence.status payload missing canonical authority")
rows = payload.get("rows") or []
if not rows:
    fail("site.presence.status --site home emitted no rows")
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
]
missing = [field for field in required if field not in rows[0]]
if missing:
    fail(f"site.presence.status row missing fields: {', '.join(missing)}")
for row in rows:
    presence_id = row.get("presence_id") or "<unknown>"
    if row.get("actions_allowed", {}).get("may_create_node") is not False:
        fail(f"{presence_id}: site.presence.status must not allow node creation")
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
proc_all = subprocess.run([str(site_presence), "--json"], text=True, capture_output=True)
if proc_all.returncode != 0:
    fail(f"site.presence.status --json (all sites) must succeed: {proc_all.stderr.strip()[:200]} (PACKET-1115)")
all_payload = json.loads(proc_all.stdout)
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
# (t) Leaf carrier — file demoted from authoritative to compatibility_projection,
#     declares subordinate_to site.profile.contract.yaml, must NOT carry an
#     unqualified `authority` field (use evidence_lineage instead).
# (u) Parent carrier — home.authority.contract.yaml row redirects to site.profile
#     via subordinate_to AND to site.presence.status via replacement_readback,
#     scope ends in _compatibility_evidence. Three-field lock on the parent.
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
        if not scope_value.endswith("_compatibility_evidence"):
            fail(f"home.authority.contract.yaml inventories[home.unifi.network.inventory.yaml] scope must end in _compatibility_evidence, got {scope_value!r} (PACKET-1145)")
        if unifi_entry.get("subordinate_to") != "ops/bindings/site.profile.contract.yaml":
            fail("home.authority.contract.yaml inventories[home.unifi.network.inventory.yaml] must declare subordinate_to=ops/bindings/site.profile.contract.yaml (PACKET-1145)")
        if unifi_entry.get("replacement_readback") != "site.presence.status":
            fail("home.authority.contract.yaml inventories[home.unifi.network.inventory.yaml] must declare replacement_readback=site.presence.status (PACKET-1145)")

print("D448 PASS: site presence readback exists, old network/device authority is demoted, presence cannot create node admission, site.profile first-class HI primitive is locked through site.presence.status consumption (PACKET-1115), and home.unifi.network.inventory.yaml authority claims subtracted at both leaf and parent (PACKET-1145)")
PY
