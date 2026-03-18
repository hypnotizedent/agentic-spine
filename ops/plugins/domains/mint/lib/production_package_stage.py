#!/usr/bin/env python3
"""Stage governed Mint production packages from immutable production handoff records."""

from __future__ import annotations

import argparse
import copy
import json
import os
from pathlib import Path
from typing import Any

import yaml

from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root
from quote_packet_normalize import dump_yaml, fail, load_structured_file, now_utc, stop


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="production-package-stage",
        description="Stage a governed Mint production package from an immutable production handoff.",
    )
    parser.add_argument("production_handoff_id", help="Production handoff ID to stage from")
    parser.add_argument(
        "--target",
        help="Optional target machine override (barudan|screenpro)",
        default=None,
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of YAML")
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_PRODUCTION_PACKAGE_CAPABILITY_NAME") or "mint.production.package.stage"


def update_entity_index(index_file: Path, list_key: str, entity_key: str, entry: dict[str, Any]) -> None:
    index_data = load_structured_file(index_file) if index_file.exists() else {list_key: []}
    if not isinstance(index_data, dict):
        index_data = {list_key: []}
    entries = index_data.setdefault(list_key, [])
    existing = next((item for item in entries if isinstance(item, dict) and item.get(entity_key) == entry.get(entity_key)), None)
    if existing:
        existing.update(copy.deepcopy(entry))
    else:
        entries.append(copy.deepcopy(entry))
    dump_yaml(index_file, index_data)


def dedupe_strings(values: list[str]) -> list[str]:
    seen = set()
    output: list[str] = []
    for value in values:
        if not value or value in seen:
            continue
        seen.add(value)
        output.append(value)
    return output


def package_id_for(handoff_id: str, target: str) -> str:
    return f"{handoff_id}--{target}"


def package_file_for(packages_dir: Path, production_package_id: str) -> Path:
    return packages_dir / f"production_package_{production_package_id}.yaml"


def manifest_file_for(staging_root: Path, production_package_id: str) -> Path:
    bundle_dir = staging_root / production_package_id
    return bundle_dir / "manifest.yaml"


# Target-specific configuration matching mint.production.package.authority.yaml
TARGET_CONFIG = {
    "barudan": {
        "target_class": "embroidery",
        "machine_target": "barudan",
        "accepted_extensions": ["dst", "u00"],
        "near_ready_extensions": ["emb", "pxf", "edr"],
        "required_methods": ["embroidery"],
    },
    "screenpro": {
        "target_class": "screen_print",
        "machine_target": "screenpro",
        "accepted_extensions": ["eps", "pdf", "ai", "svg"],
        "required_methods": ["screen_print", "transfers"],
    },
}


def infer_target_from_handoff(handoff: dict[str, Any]) -> str | None:
    """Infer machine target from handoff target_classes or line methods."""
    target_classes = handoff.get("target_classes") or []
    if "barudan" in target_classes:
        return "barudan"
    if "screen_print_press" in target_classes or "screenpro" in target_classes:
        return "screenpro"

    # Fallback: infer from line item methods
    lines = handoff.get("line_items") or []
    has_embroidery = any(
        str((line or {}).get("decoration_method") or "").strip() == "embroidery"
        for line in lines
        if isinstance(line, dict)
    )
    has_screen_print = any(
        str((line or {}).get("decoration_method") or "").strip() in {"screen_print", "transfers"}
        for line in lines
        if isinstance(line, dict)
    )

    if has_embroidery:
        return "barudan"
    if has_screen_print:
        return "screenpro"

    return None


def validate_target(target: str) -> None:
    """Validate that target is supported."""
    if target not in TARGET_CONFIG:
        valid_targets = ", ".join(TARGET_CONFIG.keys())
        fail(f"unsupported target '{target}'; valid targets: {valid_targets}")
    if target == "gtx":
        fail("GTX package staging is explicitly deferred in v1 (no proven boring export pattern yet)")


def get_asset_extension(asset_ref: str) -> str:
    """Extract file extension from asset ref (lowercase)."""
    return Path(asset_ref).suffix.lstrip(".").lower()


def filter_compatible_assets(
    lines: list[dict[str, Any]],
    target_config: dict[str, Any],
) -> tuple[list[str], list[dict[str, Any]], list[str]]:
    """
    Filter handoff lines to find method-compatible production assets.

    Returns:
        - list of compatible production_asset_refs
        - list of line summaries with compatible assets
        - list of blocking reasons if any required lines have no compatible assets
    """
    accepted_extensions = set(target_config["accepted_extensions"])
    required_methods = set(target_config["required_methods"])

    compatible_assets: list[str] = []
    compatible_lines: list[dict[str, Any]] = []
    blocking_reasons: list[str] = []

    for line in lines:
        if not isinstance(line, dict):
            continue

        method = str(line.get("decoration_method") or "").strip()
        if method not in required_methods:
            continue  # Skip lines not relevant to this target

        line_assets = [str(ref) for ref in (line.get("production_asset_refs") or []) if str(ref or "").strip()]
        line_compatible = [
            asset for asset in line_assets
            if get_asset_extension(asset) in accepted_extensions
        ]

        if not line_compatible:
            order_line_id = line.get("order_line_id") or "unknown"
            asset_list = ", ".join([get_asset_extension(a) for a in line_assets]) if line_assets else "none"
            blocking_reasons.append(
                f"line {order_line_id} (method={method}) has no compatible assets "
                f"(found: {asset_list}; required: {', '.join(accepted_extensions)})"
            )
        else:
            compatible_assets.extend(line_compatible)
            compatible_lines.append({
                "order_line_id": line.get("order_line_id"),
                "decoration_method": method,
                "production_asset_refs": line_compatible,
                "quantity": line.get("quantity"),
            })

    return (dedupe_strings(compatible_assets), compatible_lines, blocking_reasons)


def build_package_manifest(
    production_package_id: str,
    handoff: dict[str, Any],
    target_config: dict[str, Any],
    compatible_assets: list[str],
    compatible_lines: list[dict[str, Any]],
    timestamp: str,
) -> dict[str, Any]:
    """Build the minimal package manifest for the staged bundle."""
    return {
        "production_package_id": production_package_id,
        "production_handoff_id": handoff.get("production_handoff_id"),
        "order_id": handoff.get("order_id"),
        "order_revision_id": handoff.get("order_revision_id"),
        "target_class": target_config["target_class"],
        "machine_target": target_config["machine_target"],
        "staged_at": timestamp,
        "staged_by": current_capability_name(),
        "source_asset_refs": compatible_assets,
        "staged_files": compatible_assets,  # V1 references-only: no copy, just refs
        "staging_notes": f"V1 references-only staging for {target_config['machine_target']} (no file copy)",
        "line_items": compatible_lines,
    }


def build_package_record(
    production_package_id: str,
    handoff: dict[str, Any],
    target: str,
    target_config: dict[str, Any],
    compatible_assets: list[str],
    compatible_lines: list[dict[str, Any]],
    manifest_path: Path,
    staging_root: Path,
    timestamp: str,
    blocking_reasons: list[str] | None = None,
) -> dict[str, Any]:
    """Build the immutable package record."""
    package_state = "blocked" if blocking_reasons else "staged"
    staged_bundle_path = str(staging_root / production_package_id) if not blocking_reasons else None

    return {
        "production_package_id": production_package_id,
        "production_handoff_id": handoff.get("production_handoff_id"),
        "order_id": handoff.get("order_id"),
        "order_revision_id": handoff.get("order_revision_id"),
        "target_class": target_config["target_class"],
        "machine_target": target,
        "package_state": package_state,
        "source_asset_refs": compatible_assets if not blocking_reasons else [],
        "staged_bundle_path": staged_bundle_path,
        "manifest_path": str(manifest_path) if not blocking_reasons else None,
        "created_at": timestamp,
        "created_by": current_capability_name(),
        "receipt_notes": "; ".join(blocking_reasons) if blocking_reasons else f"staged {len(compatible_assets)} assets for {len(compatible_lines)} line(s)",
        "line_items": compatible_lines if not blocking_reasons else [],
        "blocking_reasons": blocking_reasons or [],
    }


def build_summary(record: dict[str, Any], package_file: Path) -> dict[str, Any]:
    return {
        "production_package_id": record.get("production_package_id"),
        "package_state": record.get("package_state"),
        "target_class": record.get("target_class"),
        "machine_target": record.get("machine_target"),
        "order_id": record.get("order_id"),
        "order_revision_id": record.get("order_revision_id"),
        "staged_bundle_path": record.get("staged_bundle_path"),
        "manifest_path": record.get("manifest_path"),
        "source_asset_count": len(record.get("source_asset_refs") or []),
        "package_file": str(package_file),
        "receipt_notes": record.get("receipt_notes"),
        "blocking_reasons": copy.deepcopy(record.get("blocking_reasons") or []),
    }


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    spine_root = resolve_spine_root(__file__)
    mint_root = resolve_mint_data_root(spine_root=spine_root, current_file=__file__)

    handoffs_dir = Path(os.environ.get("MINT_PRODUCTION_HANDOFFS_DIR") or (mint_root / "production-handoffs"))
    packages_dir = Path(os.environ.get("MINT_PRODUCTION_PACKAGES_DIR") or (mint_root / "production-packages"))
    packages_index_file = Path(
        os.environ.get("MINT_PRODUCTION_PACKAGES_INDEX_FILE") or (mint_root / "production-packages-index.yaml")
    )
    staging_root = Path(
        os.environ.get("MINT_PRODUCTION_PACKAGES_STAGING_ROOT") or (mint_root / "production-packages/staged-bundles")
    )

    handoff_id = args.production_handoff_id
    handoff_file = handoffs_dir / f"production_handoff_{handoff_id}.yaml"
    if not handoff_file.exists():
        fail(f"production handoff not found: {handoff_id}")

    handoff = load_structured_file(handoff_file) or {}
    if not isinstance(handoff, dict):
        fail(f"handoff is not a valid object: {handoff_id}")

    # Determine target
    target = args.target or infer_target_from_handoff(handoff)
    if not target:
        stop("cannot infer target from handoff; provide --target explicitly")

    validate_target(target)
    target_config = TARGET_CONFIG[target]

    production_package_id = package_id_for(handoff_id, target)
    package_file = package_file_for(packages_dir, production_package_id)

    # Check idempotency: reuse existing package if already staged
    if package_file.exists():
        existing = load_structured_file(package_file) or {}
        if isinstance(existing, dict) and existing.get("production_package_id") == production_package_id:
            summary = build_summary(existing, package_file)
            print(yaml.dump(summary, default_flow_style=False, allow_unicode=True, sort_keys=False) if not args.json else json.dumps(summary, indent=2))
            print(f"\npackage_state: existing_{existing.get('package_state')}", file=os.sys.stderr)
            return 0

    # Filter handoff lines for method-compatible production assets
    lines = handoff.get("line_items") or []
    compatible_assets, compatible_lines, blocking_reasons = filter_compatible_assets(lines, target_config)

    timestamp = now_utc()

    if blocking_reasons:
        # Build blocked package record
        manifest_path = Path("/dev/null")  # No manifest for blocked packages
        record = build_package_record(
            production_package_id, handoff, target, target_config,
            compatible_assets, compatible_lines, manifest_path, staging_root,
            timestamp, blocking_reasons
        )
        packages_dir.mkdir(parents=True, exist_ok=True)
        dump_yaml(package_file, record)
        update_entity_index(packages_index_file, "packages", "production_package_id", {
            "production_package_id": production_package_id,
            "package_state": "blocked",
            "target_class": target_config["target_class"],
            "machine_target": target,
            "order_id": handoff.get("order_id"),
            "created_at": timestamp,
        })
        summary = build_summary(record, package_file)
        print(yaml.dump(summary, default_flow_style=False, allow_unicode=True, sort_keys=False) if not args.json else json.dumps(summary, indent=2))
        print(f"\npackage_state: blocked", file=os.sys.stderr)
        print(f"blocking_reasons: {'; '.join(blocking_reasons)}", file=os.sys.stderr)
        return 1

    # Build staged package
    bundle_dir = staging_root / production_package_id
    bundle_dir.mkdir(parents=True, exist_ok=True)

    manifest_path = manifest_file_for(staging_root, production_package_id)
    manifest = build_package_manifest(
        production_package_id, handoff, target_config,
        compatible_assets, compatible_lines, timestamp
    )
    dump_yaml(manifest_path, manifest)

    record = build_package_record(
        production_package_id, handoff, target, target_config,
        compatible_assets, compatible_lines, manifest_path, staging_root, timestamp
    )

    packages_dir.mkdir(parents=True, exist_ok=True)
    dump_yaml(package_file, record)
    update_entity_index(packages_index_file, "packages", "production_package_id", {
        "production_package_id": production_package_id,
        "package_state": "staged",
        "target_class": target_config["target_class"],
        "machine_target": target,
        "order_id": handoff.get("order_id"),
        "source_asset_count": len(compatible_assets),
        "created_at": timestamp,
    })

    summary = build_summary(record, package_file)
    print(yaml.dump(summary, default_flow_style=False, allow_unicode=True, sort_keys=False) if not args.json else json.dumps(summary, indent=2))
    print(f"\npackage_state: staged", file=os.sys.stderr)
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main(sys.argv[1:]))
