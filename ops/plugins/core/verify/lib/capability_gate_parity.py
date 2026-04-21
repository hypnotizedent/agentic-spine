#!/usr/bin/env python3
"""Capability-Gate Parity Checker.

Reads capabilities.yaml, gate.registry.yaml, gate.execution.topology.yaml,
and capability.domain.catalog.yaml to validate and classify every
gate<->capability relationship referenced via capability_refs in the gate
registry.

Outputs machine-readable JSON (--json) or a text summary.

Exit 0 if no mismatches/unknowns, exit 1 if any issues found.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[5]
CAPABILITIES_PATH = ROOT / "ops/capabilities.yaml"
GATE_REGISTRY_PATH = ROOT / "ops/bindings/gate.registry.yaml"
TOPOLOGY_PATH = ROOT / "ops/bindings/gate.execution.topology.yaml"
DOMAIN_CATALOG_PATH = ROOT / "ops/bindings/capability.domain.catalog.yaml"
SNAPSHOT_RETRIES = 2

# Every relation MUST be one of these types (fail-closed)
VALID_RELATIONS = frozenset({
    "primary_domain_match",
    "cross_domain_allowed",
    "domain_mismatch",
    "unknown_capability_domain",
    "unknown_gate_domain",
})


def load_yaml(path: Path) -> dict[str, Any]:
    for _ in range(SNAPSHOT_RETRIES):
        if not path.is_file():
            print(f"FAIL: missing YAML file: {path}", file=sys.stderr)
            sys.exit(1)
        try:
            before = path.stat()
            with path.open("r", encoding="utf-8") as fh:
                data = yaml.safe_load(fh) or {}
            after = path.stat()
        except Exception as exc:
            print(f"FAIL: unable to parse YAML {path}: {exc}", file=sys.stderr)
            sys.exit(1)
        if (
            before.st_mtime_ns == after.st_mtime_ns
            and before.st_size == after.st_size
            and before.st_ino == after.st_ino
            and before.st_dev == after.st_dev
        ):
            if not isinstance(data, dict):
                print(f"FAIL: expected mapping at YAML root: {path}", file=sys.stderr)
                sys.exit(1)
            return data
    print(f"FAIL: unstable YAML snapshot while reading {path}", file=sys.stderr)
    sys.exit(1)


def ensure_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def ensure_dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _path_signature(path: Path) -> tuple[int, int, int, int]:
    stat = path.stat()
    return (stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns)


def load_authority_snapshot(paths: list[Path]) -> dict[Path, dict[str, Any]]:
    """Load multiple authority YAML files under one stable snapshot window."""
    for _ in range(SNAPSHOT_RETRIES):
        before: dict[Path, tuple[int, int, int, int]] = {}
        data: dict[Path, dict[str, Any]] = {}
        for path in paths:
            if not path.is_file():
                print(f"FAIL: missing YAML file: {path}", file=sys.stderr)
                sys.exit(1)
            before[path] = _path_signature(path)
            data[path] = load_yaml(path)

        after = {path: _path_signature(path) for path in paths}
        if before == after:
            return data

    changed = ", ".join(str(path) for path in paths)
    print(f"FAIL: unstable multi-file YAML snapshot while reading: {changed}", file=sys.stderr)
    sys.exit(1)


def build_capability_set(capabilities_data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Return {cap_id: cap_entry} from capabilities.yaml."""
    caps = ensure_dict(capabilities_data.get("capabilities"))
    return {str(k): ensure_dict(v) for k, v in caps.items()}


def build_active_gates(registry_data: dict[str, Any]) -> list[dict[str, Any]]:
    """Return list of active (non-retired) gate entries."""
    gates = []
    for gate in ensure_list(registry_data.get("gates")):
        gate = ensure_dict(gate)
        if gate.get("retired", False):
            continue
        gates.append(gate)
    return gates


def build_gate_assignments(topology_data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Return {gate_id: assignment} from gate.execution.topology.yaml."""
    assignments = {}
    for entry in ensure_list(topology_data.get("gate_assignments")):
        entry = ensure_dict(entry)
        gid = str(entry.get("gate_id") or "")
        if gid:
            assignments[gid] = entry
    return assignments


def build_domain_metadata_set(topology_data: dict[str, Any]) -> set[str]:
    """Return set of domain_ids from topology domain_metadata."""
    domains = set()
    for entry in ensure_list(topology_data.get("domain_metadata")):
        entry = ensure_dict(entry)
        did = str(entry.get("domain_id") or "")
        if did:
            domains.add(did)
    return domains


def build_catalog_domain_set(catalog_data: dict[str, Any]) -> set[str]:
    """Return set of domain_ids from capability.domain.catalog.yaml."""
    domains = set()
    for entry in ensure_list(catalog_data.get("domains")):
        entry = ensure_dict(entry)
        did = str(entry.get("domain_id") or "")
        if did:
            domains.add(did)
    return domains


def classify_relation(
    cap_domain: str | None,
    gate_primary_domain: str | None,
    gate_secondary_domains: list[str],
    catalog_domains: set[str],
    topology_domains: set[str],
) -> str:
    """Classify a gate<->capability relation into exactly one type."""
    # Check unknowns first
    if not cap_domain or cap_domain not in catalog_domains:
        return "unknown_capability_domain"
    if not gate_primary_domain or gate_primary_domain not in topology_domains:
        return "unknown_gate_domain"

    # Domain matching
    if cap_domain == gate_primary_domain:
        return "primary_domain_match"
    if cap_domain in gate_secondary_domains:
        return "cross_domain_allowed"

    return "domain_mismatch"


def run_parity_check() -> dict[str, Any]:
    """Execute the full parity check and return structured results."""
    snapshot = load_authority_snapshot([
        CAPABILITIES_PATH,
        GATE_REGISTRY_PATH,
        TOPOLOGY_PATH,
        DOMAIN_CATALOG_PATH,
    ])

    capabilities_data = snapshot[CAPABILITIES_PATH]
    registry_data = snapshot[GATE_REGISTRY_PATH]
    topology_data = snapshot[TOPOLOGY_PATH]
    catalog_data = snapshot[DOMAIN_CATALOG_PATH]

    cap_set = build_capability_set(capabilities_data)
    active_gates = build_active_gates(registry_data)
    gate_assignments = build_gate_assignments(topology_data)
    topology_domains = build_domain_metadata_set(topology_data)
    catalog_domains = build_catalog_domain_set(catalog_data)

    gate_capability_rows: list[dict[str, Any]] = []
    domain_relation_rows: list[dict[str, Any]] = []
    missing_capabilities: list[str] = []
    gates_without_capability_refs: list[str] = []
    unknown_capability_domains: list[dict[str, str]] = []
    unknown_gate_domains: list[dict[str, str]] = []
    mismatches: list[dict[str, str]] = []
    domain_relation_counts: dict[str, int] = {}
    capabilities_referenced = 0

    seen_missing_caps: set[str] = set()
    seen_unknown_cap_domains: set[str] = set()
    seen_unknown_gate_domains: set[str] = set()

    for gate in active_gates:
        gate_id = str(gate.get("id") or "")
        if not gate_id:
            continue

        cap_refs = gate.get("capability_refs")
        if cap_refs is None:
            gates_without_capability_refs.append(gate_id)
            continue

        cap_refs = ensure_list(cap_refs)
        if not cap_refs:
            gates_without_capability_refs.append(gate_id)
            continue

        # Get gate domain info from topology
        assignment = gate_assignments.get(gate_id, {})
        gate_primary_domain = str(assignment.get("primary_domain") or "")
        gate_secondary_domains = [
            str(d) for d in ensure_list(assignment.get("secondary_domains"))
        ]

        for cap_id in cap_refs:
            cap_id = str(cap_id)
            capabilities_referenced += 1

            # Check capability exists
            if cap_id not in cap_set:
                if cap_id not in seen_missing_caps:
                    missing_capabilities.append(cap_id)
                    seen_missing_caps.add(cap_id)
                gate_capability_rows.append({
                    "gate_id": gate_id,
                    "capability_id": cap_id,
                    "gate_domain": gate_primary_domain,
                    "capability_domain": None,
                    "relation": "missing_capability",
                })
                continue

            # Get capability domain
            cap_entry = cap_set[cap_id]
            cap_domain = cap_entry.get("domain")
            if cap_domain is not None:
                cap_domain = str(cap_domain)

            # Classify relation
            relation = classify_relation(
                cap_domain,
                gate_primary_domain,
                gate_secondary_domains,
                catalog_domains,
                topology_domains,
            )

            # Fail-closed: every relation MUST be a known type
            if relation not in VALID_RELATIONS:
                print(
                    f"FAIL: unclassified relation for gate={gate_id} cap={cap_id}: {relation}",
                    file=sys.stderr,
                )
                sys.exit(1)

            gate_capability_rows.append({
                "gate_id": gate_id,
                "capability_id": cap_id,
                "gate_domain": gate_primary_domain,
                "capability_domain": cap_domain,
                "relation": relation,
            })

            domain_relation_rows.append({
                "gate_id": gate_id,
                "capability_id": cap_id,
                "relation": relation,
                "gate_domain": gate_primary_domain,
                "capability_domain": cap_domain,
            })

            domain_relation_counts[relation] = domain_relation_counts.get(relation, 0) + 1

            # Collect issues
            if relation == "unknown_capability_domain":
                key = cap_id
                if key not in seen_unknown_cap_domains:
                    unknown_capability_domains.append({
                        "capability_id": cap_id,
                        "domain": cap_domain or "",
                    })
                    seen_unknown_cap_domains.add(key)

            elif relation == "unknown_gate_domain":
                key = gate_id
                if key not in seen_unknown_gate_domains:
                    unknown_gate_domains.append({
                        "gate_id": gate_id,
                        "domain": gate_primary_domain,
                    })
                    seen_unknown_gate_domains.add(key)

            elif relation == "domain_mismatch":
                mismatches.append({
                    "gate_id": gate_id,
                    "capability_id": cap_id,
                    "gate_domain": gate_primary_domain,
                    "capability_domain": cap_domain or "",
                })

    return {
        "gate_capability_rows": gate_capability_rows,
        "missing_capabilities": missing_capabilities,
        "gates_without_capability_refs": gates_without_capability_refs,
        "capabilities_referenced": capabilities_referenced,
        "domain_relation_counts": domain_relation_counts,
        "domain_relation_rows": domain_relation_rows,
        "unknown_capability_domains": unknown_capability_domains,
        "unknown_gate_domains": unknown_gate_domains,
        "mismatches": mismatches,
    }


def has_issues(result: dict[str, Any]) -> bool:
    """Return True if any issues were found."""
    return bool(
        result["missing_capabilities"]
        or result["unknown_capability_domains"]
        or result["unknown_gate_domains"]
        or result["mismatches"]
    )


def print_text_summary(result: dict[str, Any]) -> None:
    """Print human-readable summary."""
    print("=== CAPABILITY-GATE PARITY ===")
    print(f"Capabilities referenced: {result['capabilities_referenced']}")
    print(f"Gates without capability_refs: {len(result['gates_without_capability_refs'])}")

    if result["domain_relation_counts"]:
        print()
        print("Domain relation breakdown:")
        for relation, count in sorted(result["domain_relation_counts"].items()):
            print(f"  {relation}: {count}")

    if result["missing_capabilities"]:
        print()
        print(f"Missing capabilities ({len(result['missing_capabilities'])}):")
        for cap_id in result["missing_capabilities"]:
            print(f"  - {cap_id}")

    if result["unknown_capability_domains"]:
        print()
        print(f"Unknown capability domains ({len(result['unknown_capability_domains'])}):")
        for entry in result["unknown_capability_domains"]:
            print(f"  - {entry['capability_id']} (domain: {entry['domain'] or 'none'})")

    if result["unknown_gate_domains"]:
        print()
        print(f"Unknown gate domains ({len(result['unknown_gate_domains'])}):")
        for entry in result["unknown_gate_domains"]:
            print(f"  - {entry['gate_id']} (domain: {entry['domain']})")

    if result["mismatches"]:
        print()
        print(f"Domain mismatches ({len(result['mismatches'])}):")
        for entry in result["mismatches"]:
            print(
                f"  - {entry['gate_id']} -> {entry['capability_id']}: "
                f"gate={entry['gate_domain']} cap={entry['capability_domain']}"
            )

    print()
    if has_issues(result):
        print("Capability-gate parity: FAIL")
    else:
        print("Capability-gate parity: PASS")


def main() -> None:
    json_mode = "--json" in sys.argv

    result = run_parity_check()

    if json_mode:
        json.dump(result, sys.stdout, indent=2)
        print()
    else:
        print_text_summary(result)

    sys.exit(1 if has_issues(result) else 0)


if __name__ == "__main__":
    main()
