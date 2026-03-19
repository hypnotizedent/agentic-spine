#!/usr/bin/env python3
"""Read-only inspection of governed Mint production packages."""

from __future__ import annotations

import argparse
import copy
import json
import os
from pathlib import Path
from typing import Any

import yaml

from quote_packet_normalize import fail, load_structured_file


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="production-package-show",
        description="Inspect a staged Mint production package (read-only).",
    )
    parser.add_argument("production_package_id", help="Production package ID to inspect")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of YAML")
    parser.add_argument("--exports", action="store_true", help="Include export history if available")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    script_dir = Path(__file__).resolve().parent
    spine_root = Path(os.environ.get("SPINE_ROOT") or script_dir.parent.parent.parent.parent)
    mint_root = Path(
        os.environ.get("MINT_DATA_ROOT")
        or os.environ.get("SPINE_DATA_ROOT")
        or os.environ.get("SPINE_DOMAIN_STATE")
        or (spine_root.parent / ".data")
    ) / "mint"

    packages_dir = Path(os.environ.get("MINT_PRODUCTION_PACKAGES_DIR") or (mint_root / "production-packages"))
    exports_dir = Path(os.environ.get("MINT_PRODUCTION_EXPORTS_DIR") or (mint_root / "production-package-exports"))

    package_id = args.production_package_id
    package_file = packages_dir / f"production_package_{package_id}.yaml"
    if not package_file.exists():
        fail(f"staged package not found: {package_id}")

    package = load_structured_file(package_file) or {}
    if not isinstance(package, dict):
        fail(f"package is not a valid object: {package_id}")

    # Build summary
    summary: dict[str, Any] = {
        "production_package_id": package.get("production_package_id"),
        "production_handoff_id": package.get("production_handoff_id"),
        "order_id": package.get("order_id"),
        "order_revision_id": package.get("order_revision_id"),
        "package_state": package.get("package_state"),
        "target_class": package.get("target_class"),
        "machine_target": package.get("machine_target"),
        "source_asset_refs": copy.deepcopy(package.get("source_asset_refs") or []),
        "staged_bundle_path": package.get("staged_bundle_path"),
        "manifest_path": package.get("manifest_path"),
        "created_at": package.get("created_at"),
        "created_by": package.get("created_by"),
        "receipt_notes": package.get("receipt_notes"),
        "blocking_reasons": copy.deepcopy(package.get("blocking_reasons") or []),
    }

    # Optionally include export history
    if args.exports:
        export_records: list[dict[str, Any]] = []
        if exports_dir.exists():
            for export_file in exports_dir.glob(f"production_export_{package_id}--*.yaml"):
                export_data = load_structured_file(export_file)
                if isinstance(export_data, dict):
                    export_records.append({
                        "production_export_id": export_data.get("production_export_id"),
                        "export_state": export_data.get("export_state"),
                        "export_mode": export_data.get("export_mode"),
                        "export_bundle_path": export_data.get("export_bundle_path"),
                        "created_at": export_data.get("created_at"),
                    })
        summary["export_history"] = export_records

    print(yaml.dump(summary, default_flow_style=False, allow_unicode=True, sort_keys=False) if not args.json else json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main(sys.argv[1:]))
