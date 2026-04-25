#!/usr/bin/env python3
"""Core-gate triage for the spine-only verify set.

This helper classifies the declared core gate ids from
`ops/bindings/gate.execution.topology.yaml` into exactly one bucket:

- executable_now
- already_covered
- missing_implementation
- stale_target
- out_of_spine_scope

It is intentionally narrow:
- no topology mutation
- no registry mutation
- no new state files
- fail closed on any classification gap
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import yaml


CORE_ENGINE_COVERAGE = {
    "D3": {
        "surface_id": "verify-engine",
        "path": "ops/plugins/core/verify/bin/verify-engine",
        "coverage": "E1",
        "proof": "verify-engine E1 checks bin/ops entrypoint smoke",
    },
}

# D127 uses declare -A (bash 4+) which fails on macOS bash 3.2.
# Conceptually L1 (topology meta-integrity), excluded for runtime compat only.
OUT_OF_SPINE_SCOPE = {"D127"}


def repo_root() -> Path:
    return Path(__file__).resolve().parents[5]


def load_yaml(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def _gate_rows_by_id(registry: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = registry.get("gates")
    if not isinstance(rows, list):
        raise ValueError("gate.registry.yaml is missing the top-level gates list")
    out: dict[str, dict[str, Any]] = {}
    for row in rows:
        gate_id = row.get("id")
        if isinstance(gate_id, str):
            out[gate_id] = row
    return out


def _script_exists(root: Path, script_path: str | None) -> bool:
    if not script_path:
        return False
    return (root / script_path).is_file()


def classify_core_gates(root: Path | None = None) -> dict[str, Any]:
    root = root or repo_root()
    topology_path = root / "ops/bindings/gate.execution.topology.yaml"
    registry_path = root / "ops/bindings/gate.registry.yaml"

    topology = load_yaml(topology_path)
    registry = load_yaml(registry_path)
    gate_rows = _gate_rows_by_id(registry)

    declared_core_gate_ids = list(topology["core_mode"]["core_gate_ids"])

    buckets = {
        "executable_now": [],
        "already_covered": [],
        "missing_implementation": [],
        "stale_target": [],
        "out_of_spine_scope": [],
    }
    executable_surfaces: list[dict[str, Any]] = []
    covered_by_surfaces: list[dict[str, Any]] = []
    seen: set[str] = set()

    for gate_id in declared_core_gate_ids:
        if gate_id in seen:
            raise ValueError(f"duplicate declared core gate id: {gate_id}")
        seen.add(gate_id)

        if gate_id in OUT_OF_SPINE_SCOPE:
            buckets["out_of_spine_scope"].append(gate_id)
            continue

        coverage = CORE_ENGINE_COVERAGE.get(gate_id)
        if coverage:
            buckets["already_covered"].append(gate_id)
            covered_by_surfaces.append(
                {
                    "gate_id": gate_id,
                    "surface_id": coverage["surface_id"],
                    "path": coverage["path"],
                    "coverage": coverage["coverage"],
                    "proof": coverage["proof"],
                }
            )
            continue

        gate_row = gate_rows.get(gate_id)
        if gate_row is None:
            raise ValueError(f"declared core gate missing from registry: {gate_id}")

        script = gate_row.get("check_script")
        script_exists = _script_exists(root, script)
        retired = gate_row.get("status") in {"retired", "historical"} or gate_row.get("superseded_by")

        if script_exists:
            buckets["executable_now"].append(gate_id)
            executable_surfaces.append(
                {
                    "gate_id": gate_id,
                    "surface_id": f"gate:{gate_id}",
                    "path": script,
                    "check_script": script,
                    "category": gate_row.get("category"),
                    "description": gate_row.get("description"),
                    "mode": gate_row.get("mode", "enforce"),
                    "warn_only": bool(gate_row.get("warn_only", False)),
                }
            )
            continue

        if retired:
            buckets["stale_target"].append(gate_id)
            continue

        buckets["missing_implementation"].append(gate_id)

    classified = (
        buckets["executable_now"]
        + buckets["already_covered"]
        + buckets["missing_implementation"]
        + buckets["stale_target"]
        + buckets["out_of_spine_scope"]
    )

    if sorted(classified) != sorted(declared_core_gate_ids):
        missing = [gate_id for gate_id in declared_core_gate_ids if gate_id not in classified]
        extras = sorted(set(classified) - set(declared_core_gate_ids))
        raise ValueError(
            "classification incomplete: "
            + json.dumps({"missing": missing, "extras": extras}, sort_keys=True)
        )

    if len(classified) != len(set(classified)):
        raise ValueError("classification duplicated at least one declared core gate id")

    return {
        "declared_core_gate_ids": declared_core_gate_ids,
        "executable_now_gate_ids": buckets["executable_now"],
        "already_covered_gate_ids": buckets["already_covered"],
        "missing_implementation_gate_ids": buckets["missing_implementation"],
        "stale_target_gate_ids": buckets["stale_target"],
        "out_of_spine_scope_gate_ids": buckets["out_of_spine_scope"],
        "executable_surfaces": executable_surfaces,
        "covered_by_surfaces": covered_by_surfaces,
    }


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    json_mode = False

    if argv and argv[0] == "--":
        argv = argv[1:]

    if argv and argv[0] == "--json":
        json_mode = True
        argv = argv[1:]

    if argv and argv[0] in {"-h", "--help"}:
        print("Usage: spine_scope_gate_set.py [--json]", file=sys.stdout)
        return 0

    if argv:
        print(f"spine_scope_gate_set FAIL: unknown argument: {argv[0]}", file=sys.stderr)
        return 2

    try:
        payload = classify_core_gates()
    except Exception as exc:  # fail closed
        error_payload = {"ok": False, "error": str(exc)}
        print(json.dumps(error_payload, indent=2, sort_keys=True))
        return 1

    result = {"ok": True, **payload}
    if json_mode:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
