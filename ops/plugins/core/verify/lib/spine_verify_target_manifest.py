#!/usr/bin/env python3
"""Spine-only verify target manifest.

Produces the authoritative mapping from canonical verify targets to gates
and capabilities.  Exactly 4 targets: engine_smoke, engine_honesty, spine,
binding_coherence.

Imports classification data from sibling Packet 2/3 helpers and validates
coverage rules before emitting the manifest.

Exit 0 if all hard coverage rules pass, exit 1 otherwise.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Sibling imports — add parent dir so spine_scope_gate_set / capability_gate_parity
# are importable when run standalone.
# ---------------------------------------------------------------------------
_LIB_DIR = str(Path(__file__).resolve().parent)
if _LIB_DIR not in sys.path:
    sys.path.insert(0, _LIB_DIR)

from spine_scope_gate_set import classify_core_gates  # noqa: E402
from capability_gate_parity import run_parity_check, load_yaml, GATE_REGISTRY_PATH  # noqa: E402

import yaml as _yaml  # noqa: E402

ROOT = Path(__file__).resolve().parents[5]
CAPABILITIES_PATH = ROOT / "ops/capabilities.yaml"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _load_capabilities_set() -> set[str]:
    """Return set of all capability ids from capabilities.yaml."""
    data = load_yaml(CAPABILITIES_PATH)
    caps = data.get("capabilities")
    if isinstance(caps, dict):
        return set(str(k) for k in caps)
    return set()


def _load_active_gate_ids() -> set[str]:
    """Return set of active (non-retired) gate ids from gate.registry.yaml."""
    data = load_yaml(GATE_REGISTRY_PATH)
    ids: set[str] = set()
    for gate in (data.get("gates") or []):
        if not isinstance(gate, dict):
            continue
        if gate.get("retired", False):
            continue
        gid = gate.get("id")
        if isinstance(gid, str):
            ids.add(gid)
    return ids


def _capability_refs_for_gates(
    gate_ids: list[str],
    parity_rows: list[dict[str, Any]],
) -> list[str]:
    """Return deduplicated capability_ids referenced by the given gate_ids via parity rows."""
    gate_set = set(gate_ids)
    seen: set[str] = set()
    out: list[str] = []
    for row in parity_rows:
        gid = row.get("gate_id", "")
        cid = row.get("capability_id", "")
        if gid in gate_set and cid and cid not in seen:
            seen.add(cid)
            out.append(cid)
    return out


# ---------------------------------------------------------------------------
# Manifest builder
# ---------------------------------------------------------------------------

def build_manifest() -> dict[str, Any]:
    """Build the full target manifest with coverage validation."""

    # --- Packet 2: gate classification ---
    classification = classify_core_gates(ROOT)
    executable_now = classification["executable_now_gate_ids"]
    already_covered = classification["already_covered_gate_ids"]
    missing_impl = classification["missing_implementation_gate_ids"]
    stale_target = classification["stale_target_gate_ids"]
    out_of_scope = classification["out_of_spine_scope_gate_ids"]
    declared_core = classification["declared_core_gate_ids"]

    # --- Packet 3: parity ---
    parity = run_parity_check()
    parity_rows = parity.get("gate_capability_rows", [])

    # --- Reference sets ---
    active_gate_ids = _load_active_gate_ids()
    capabilities_set = _load_capabilities_set()

    # All spine gate ids that appear in the spine target
    spine_gate_ids = sorted(set(executable_now) | set(already_covered))

    # Capability refs for spine gates (from parity rows)
    spine_capability_ids = _capability_refs_for_gates(spine_gate_ids, parity_rows)

    # All capability_refs from parity rows for gates in any target
    all_target_gate_ids: set[str] = set()

    # --- Build target rows ---
    targets: list[dict[str, Any]] = []

    # 1. engine_smoke
    engine_smoke = {
        "target_id": "engine_smoke",
        "front_door_command": "./bin/ops verify --engine-smoke",
        "backbone_command": "./bin/ops cap run verify.run -- engine",
        "target_class": "supportive_spine_scope",
        "gate_ids": list(already_covered),  # D3
        "capability_ids": ["verify.engine.run"],
        "non_gate_surface_refs": [
            "ops/plugins/core/verify/bin/verify-engine",
        ],
        "coverage_status": "non_gate_only",
        "coverage_notes": (
            "D3 entrypoint smoke is covered by verify-engine E1 check. "
            "Remaining checks are non-gate engine plumbing."
        ),
    }
    targets.append(engine_smoke)
    all_target_gate_ids.update(engine_smoke["gate_ids"])

    # 2. engine_honesty
    engine_honesty = {
        "target_id": "engine_honesty",
        "front_door_command": "./bin/ops verify --engine-honesty",
        "backbone_command": "./bin/ops cap run verify.run -- honesty",
        "target_class": "supportive_spine_scope",
        "gate_ids": [],
        "capability_ids": ["verify.engine.honesty"],
        "non_gate_surface_refs": [
            "ops/plugins/core/verify/bin/verify-engine-honesty",
        ],
        "coverage_status": "non_gate_only",
        "coverage_notes": (
            "Validates dispatch, wave lifecycle, telemetry, and close semantics. "
            "Not tied to individual drift gates."
        ),
    }
    targets.append(engine_honesty)

    # 3. spine
    spine_target = {
        "target_id": "spine",
        "front_door_command": "./bin/ops verify --spine",
        "backbone_command": "./bin/ops cap run verify.run -- spine",
        "target_class": "canonical_spine_scope",
        "gate_ids": spine_gate_ids,
        "capability_ids": spine_capability_ids,
        "non_gate_surface_refs": [
            "ops/plugins/core/verify/bin/verify-engine",
            "ops/plugins/core/verify/bin/verify-engine-honesty",
        ],
        "coverage_status": "partial",
        "coverage_notes": (
            f"{len(executable_now)} gates executable, "
            f"{len(already_covered)} already covered by engine, "
            f"{len(missing_impl)} missing implementation, "
            f"{len(out_of_scope)} out of spine scope, "
            f"{len(stale_target)} stale targets."
        ),
        "source_refs": [
            "ops/plugins/core/verify/lib/spine_scope_gate_set.py",
            "ops/plugins/core/verify/lib/capability_gate_parity.py",
        ],
    }
    targets.append(spine_target)
    all_target_gate_ids.update(spine_target["gate_ids"])

    # 4. binding_coherence
    binding_coherence = {
        "target_id": "binding_coherence",
        "front_door_command": "./bin/ops verify --binding-coherence",
        "backbone_command": "direct exec of ops/plugins/core/verify/bin/verify-binding-coherence",
        "target_class": "supportive_spine_scope",
        "gate_ids": [],
        "capability_ids": [],
        "non_gate_surface_refs": [
            "ops/plugins/core/verify/bin/verify-binding-coherence",
        ],
        "coverage_status": "non_gate_only",
        "coverage_notes": (
            "Validates binding contract capability refs and gate capability_refs "
            "domain alignment. Not gate-scoped."
        ),
    }
    targets.append(binding_coherence)

    # --- Unmapped gates (honest gaps) ---
    unmapped_gate_ids = sorted(set(missing_impl) | set(out_of_scope))

    # --- Unmapped capability refs ---
    # All capability_refs from parity rows for gates that appear in ANY target
    all_target_cap_ids: set[str] = set()
    for t in targets:
        all_target_cap_ids.update(t["capability_ids"])

    parity_cap_refs_for_target_gates = _capability_refs_for_gates(
        list(all_target_gate_ids), parity_rows
    )
    unmapped_capability_refs = [
        c for c in parity_cap_refs_for_target_gates if c not in all_target_cap_ids
    ]

    # --- Coverage summary ---
    coverage_summary = {
        "total_declared_core_gates": len(declared_core),
        "executable_now": len(executable_now),
        "already_covered": len(already_covered),
        "missing_implementation": len(missing_impl),
        "out_of_spine_scope": len(out_of_scope),
        "stale_target": len(stale_target),
        "mapped_to_targets": len(all_target_gate_ids),
        "unmapped_honest_gaps": len(unmapped_gate_ids),
    }

    # --- Coverage validation ---
    issues: list[str] = []
    hard_fail = False

    # Rule 1: every executable_now gate in at least one target's gate_ids
    for gid in executable_now:
        if gid not in all_target_gate_ids:
            issues.append(f"HARD: executable_now gate {gid} not mapped to any target")
            hard_fail = True

    # Rule 2: every already_covered gate in at least one target's gate_ids
    for gid in already_covered:
        if gid not in all_target_gate_ids:
            issues.append(f"HARD: already_covered gate {gid} not mapped to any target")
            hard_fail = True

    # Rule 3: every gate in a target row exists in gate.registry.yaml (active)
    for t in targets:
        for gid in t["gate_ids"]:
            if gid not in active_gate_ids:
                issues.append(
                    f"HARD: gate {gid} in target {t['target_id']} not active in gate.registry.yaml"
                )
                hard_fail = True

    # Rule 4: every capability in a target row exists in capabilities.yaml
    for t in targets:
        for cid in t["capability_ids"]:
            if cid not in capabilities_set:
                issues.append(
                    f"HARD: capability {cid} in target {t['target_id']} not in capabilities.yaml"
                )
                hard_fail = True

    # Rule 5: every Packet 3 capability_ref from gates in targets is reflected
    for cref in unmapped_capability_refs:
        issues.append(
            f"HARD: capability_ref {cref} from gate parity not in any target's capability_ids"
        )
        hard_fail = True

    # Rule 6: no G1-G17 or estate/domain verify targets
    for t in targets:
        tid = t["target_id"]
        if tid.startswith("G") and tid[1:].isdigit():
            issues.append(f"HARD: forbidden G-series target: {tid}")
            hard_fail = True
        for prefix in ("estate_", "domain_"):
            if tid.startswith(prefix):
                issues.append(f"HARD: forbidden estate/domain target: {tid}")
                hard_fail = True

    # Rule 7: honest reporting of unmapped gates (observations, not errors)
    for gid in missing_impl:
        issues.append(f"INFO: gate {gid} missing implementation (honest gap)")
    for gid in out_of_scope:
        issues.append(f"INFO: gate {gid} out of spine scope (honest gap)")

    return {
        "targets": targets,
        "executable_spine_gate_ids": sorted(executable_now),
        "already_covered_gate_ids": sorted(already_covered),
        "unmapped_gate_ids": unmapped_gate_ids,
        "unmapped_capability_refs": unmapped_capability_refs,
        "coverage_summary": coverage_summary,
        "issues": issues,
        "_hard_fail": hard_fail,
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def print_text_summary(manifest: dict[str, Any]) -> None:
    """Print human-readable summary."""
    cs = manifest["coverage_summary"]
    print("=== SPINE VERIFY TARGET MANIFEST ===")
    print()
    print(f"Targets: {len(manifest['targets'])}")
    for t in manifest["targets"]:
        print(f"  {t['target_id']}: {t['coverage_status']} "
              f"(gates={len(t['gate_ids'])}, caps={len(t['capability_ids'])})")
    print()
    print("Coverage summary:")
    for key, val in cs.items():
        print(f"  {key}: {val}")
    print()
    print(f"Executable spine gates: {manifest['executable_spine_gate_ids']}")
    print(f"Already covered gates: {manifest['already_covered_gate_ids']}")
    print(f"Unmapped gates (honest gaps): {manifest['unmapped_gate_ids']}")
    print(f"Unmapped capability refs: {manifest['unmapped_capability_refs']}")

    if manifest["issues"]:
        print()
        print("Issues:")
        for issue in manifest["issues"]:
            print(f"  - {issue}")

    print()
    if manifest["_hard_fail"]:
        print("TARGET MANIFEST: FAIL (hard coverage rule violated)")
    else:
        print("TARGET MANIFEST: PASS")


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    json_mode = False

    if argv and argv[0] == "--":
        argv = argv[1:]

    if argv and argv[0] == "--json":
        json_mode = True
        argv = argv[1:]

    if argv and argv[0] in {"-h", "--help"}:
        print("Usage: spine_verify_target_manifest.py [--json]")
        return 0

    if argv:
        print(f"spine_verify_target_manifest FAIL: unknown argument: {argv[0]}",
              file=sys.stderr)
        return 2

    try:
        manifest = build_manifest()
    except Exception as exc:
        error_payload = {"ok": False, "error": str(exc)}
        print(json.dumps(error_payload, indent=2, sort_keys=True))
        return 1

    hard_fail = manifest.pop("_hard_fail", False)

    if json_mode:
        print(json.dumps(manifest, indent=2, sort_keys=True))
    else:
        manifest_with_flag = {**manifest, "_hard_fail": hard_fail}
        print_text_summary(manifest_with_flag)

    return 1 if hard_fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
