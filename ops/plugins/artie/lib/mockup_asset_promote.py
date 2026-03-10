#!/usr/bin/env python3
"""Promote supplier product images into the mockup registry with full provenance."""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib import parse as urlparse
from urllib import request as urlrequest
from urllib import error as urlerror


def fail(message: str) -> None:
    """Exit with error message."""
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        prog="mockup-asset-promote",
        description="Promote supplier product image into mockup registry",
    )
    parser.add_argument("--supplier-code", required=True, help="Supplier code (sanmar, ssactive, as_colour)")
    parser.add_argument("--supplier-sku", required=True, help="Exact supplier SKU")
    parser.add_argument("--view", required=True, choices=["front", "back"], help="Mockup view")
    parser.add_argument("--approval-state", default="review", choices=["approved", "review"], help="Approval state")
    parser.add_argument("--force", action="store_true", help="Replace existing entry if duplicate exists")
    return parser.parse_args(argv)


def get_spine_root() -> Path:
    """Get spine root directory."""
    spine_root = os.environ.get("SPINE_ROOT")
    if spine_root:
        return Path(spine_root)

    # Try to find from script location
    script_dir = Path(__file__).resolve().parent
    # ops/plugins/artie/lib -> ops -> root
    candidate = script_dir.parent.parent.parent
    if (candidate / "ops").exists():
        return candidate

    fail("Cannot determine SPINE_ROOT. Set SPINE_ROOT environment variable.")


def load_yaml(file_path: Path) -> Any:
    """Load YAML file using yq."""
    import subprocess
    result = subprocess.run(
        ["yq", "eval", "-o=json", str(file_path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def save_yaml(file_path: Path, data: Any) -> None:
    """Save data as YAML using yq."""
    import subprocess
    json_data = json.dumps(data)
    subprocess.run(
        ["yq", "eval", "-P", "-"],
        input=json_data,
        check=True,
        capture_output=False,
        text=True,
        stdout=file_path.open("w"),
    )


def get_suppliers_base_url(spine_root: Path) -> str:
    """Get suppliers module base URL."""
    override = os.environ.get("SUPPLIERS_BASE_URL")
    if override:
        return override.rstrip("/")

    services_file = spine_root / "ops/bindings/services.health.yaml"
    if services_file.exists():
        services = load_yaml(services_file)
        for endpoint in services.get("endpoints", []):
            if endpoint.get("id") == "suppliers-v2":
                url = str(endpoint.get("url", "")).strip()
                if url:
                    parsed = urlparse.urlparse(url)
                    if parsed.scheme and parsed.netloc:
                        return f"{parsed.scheme}://{parsed.netloc}"

    return "http://192.168.1.213:3800"


def get_suppliers_api_key(spine_root: Path) -> str:
    """Get suppliers API key from environment or Infisical."""
    env_value = os.environ.get("SUPPLIERS_API_KEY", "").strip()
    if env_value:
        return env_value

    infisical_agent = spine_root / "ops/tools/infisical-agent.sh"
    if infisical_agent.exists():
        import subprocess
        result = subprocess.run(
            [str(infisical_agent), "get-cached", "infrastructure", "prod", "SUPPLIERS_API_KEY"],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()

    fail("SUPPLIERS_API_KEY not found. Set environment variable or ensure Infisical is configured.")


def fetch_supplier_product(base_url: str, api_key: str, supplier_code: str, supplier_sku: str) -> dict[str, Any]:
    """Fetch product details from suppliers module API."""
    encoded_code = urlparse.quote(supplier_code)
    encoded_sku = urlparse.quote(supplier_sku)
    url = f"{base_url}/api/v1/suppliers/{encoded_code}/products/{encoded_sku}"

    request = urlrequest.Request(
        url,
        headers={
            "Accept": "application/json",
            "X-API-Key": api_key,
        },
        method="GET",
    )

    try:
        with urlrequest.urlopen(request, timeout=30) as response:
            payload = response.read().decode("utf-8")
            return json.loads(payload or "{}")
    except urlerror.HTTPError as e:
        if e.code == 404:
            fail(f"Product not found: {supplier_code}/{supplier_sku}")
        elif e.code == 401 or e.code == 403:
            fail(f"Authentication failed. Check SUPPLIERS_API_KEY.")
        else:
            fail(f"HTTP {e.code} error fetching product: {e.reason}")
    except urlerror.URLError as e:
        fail(f"Network error: {e.reason}")
    except Exception as e:
        fail(f"Unexpected error fetching product: {e}")


def download_image(url: str, dest_path: Path) -> None:
    """Download image from URL to destination path."""
    try:
        request = urlrequest.Request(url, headers={"User-Agent": "artie-mockup-promotion/1.0"})
        with urlrequest.urlopen(request, timeout=60) as response:
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            with dest_path.open("wb") as f:
                f.write(response.read())
    except urlerror.HTTPError as e:
        fail(f"HTTP {e.code} error downloading image: {e.reason}")
    except urlerror.URLError as e:
        fail(f"Network error downloading image: {e.reason}")
    except Exception as e:
        fail(f"Unexpected error downloading image: {e}")


def normalize_color_name(color: str) -> str:
    """Normalize color name for file paths."""
    return color.lower().replace(" ", "-").replace("_", "-")


def generate_mockup_asset_id(supplier_code: str, style_code: str, color: str, view: str) -> str:
    """Generate mockup_asset_id."""
    color_normalized = normalize_color_name(color)
    # Use lowercase style for consistency
    style_lower = style_code.lower()
    return f"{supplier_code}-{style_lower}-{color_normalized}-{view}-v1"


def get_approved_by() -> str:
    """Get current user/session identifier for approved_by field."""
    # Try multiple sources
    if os.environ.get("SPINE_TERMINAL_NAME"):
        return os.environ["SPINE_TERMINAL_NAME"]
    if os.environ.get("USER"):
        return os.environ["USER"]
    return "operator"


def main(argv: list[str] | None = None) -> None:
    """Main entry point."""
    args = parse_args(argv or sys.argv[1:])

    spine_root = get_spine_root()
    registry_file = spine_root / "ops/bindings/artie.mockup.assets.yaml"

    if not registry_file.exists():
        fail(f"Registry file not found: {registry_file}")

    # Fetch product from suppliers API
    print(f"Fetching product {args.supplier_code}/{args.supplier_sku}...", file=sys.stderr)
    base_url = get_suppliers_base_url(spine_root)
    api_key = get_suppliers_api_key(spine_root)
    product = fetch_supplier_product(base_url, api_key, args.supplier_code, args.supplier_sku)

    # Extract required fields
    style_code = product.get("style_code")
    brand = product.get("brand")
    color_name = product.get("color_name")
    product_family = product.get("product_family")
    primary_image_url = product.get("primary_image_url")

    if not all([style_code, color_name, product_family, primary_image_url]):
        fail(f"Product missing required fields. Got: style_code={style_code}, color_name={color_name}, product_family={product_family}, primary_image_url={primary_image_url}")

    print(f"Product: {style_code} - {brand or 'N/A'} - {color_name} ({product_family})", file=sys.stderr)

    # Generate paths
    color_normalized = normalize_color_name(color_name)
    mockup_asset_id = generate_mockup_asset_id(args.supplier_code, style_code, color_name, args.view)

    # Asset storage path (relative to MinIO mount or workbench)
    asset_rel_path = f"artwork-registry/mockup-assets/{args.supplier_code}/{style_code}/{color_normalized}/{args.view}.png"

    # Actual filesystem path for download
    # Check if MINIO_ROOT or WORKBENCH_ROOT is set
    minio_root = os.environ.get("MINIO_ROOT")
    workbench_root = os.environ.get("WORKBENCH_ROOT")

    if minio_root:
        asset_abs_path = Path(minio_root) / asset_rel_path
    elif workbench_root:
        # Fallback: use runtime/domain-state in spine
        asset_abs_path = spine_root / "runtime/domain-state/artie/mockup-assets" / args.supplier_code / style_code / color_normalized / f"{args.view}.png"
    else:
        # Default: use runtime/domain-state
        asset_abs_path = spine_root / "runtime/domain-state/artie/mockup-assets" / args.supplier_code / style_code / color_normalized / f"{args.view}.png"

    # Load registry
    print(f"Loading registry: {registry_file}", file=sys.stderr)
    registry = load_yaml(registry_file)

    # Check for duplicates
    assets = registry.get("assets", [])
    existing = [a for a in assets if a.get("mockup_asset_id") == mockup_asset_id]
    if existing and not args.force:
        fail(f"Duplicate mockup_asset_id exists: {mockup_asset_id}. Use --force to replace.")

    # Download image
    print(f"Downloading image from {primary_image_url}...", file=sys.stderr)
    download_image(primary_image_url, asset_abs_path)
    print(f"Image saved to: {asset_abs_path}", file=sys.stderr)

    # Create registry entry
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    approved_by = get_approved_by() if args.approval_state == "approved" else None

    new_entry = {
        "mockup_asset_id": mockup_asset_id,
        "supplier": args.supplier_code,
        "style_code": style_code,
        "color_name": color_name,
        "product_family": product_family,
        "view": args.view,
        "asset_ref": asset_rel_path,
        "source_type": "supplier_approved",
        "quality_state": args.approval_state,
        "placement_profile_id": f"{style_code.lower()}.{args.view}.supplier-v1",
        "approved_at": now,
        # V2 provenance fields
        "promoted_from_supplier": True,
        "source_url": primary_image_url,
        "supplier_product_id": product.get("product_id"),
        "promoted_at": now,
    }

    if brand:
        new_entry["brand"] = brand

    if args.approval_state == "approved" and approved_by:
        new_entry["approved_by"] = approved_by

    # Update registry
    if existing and args.force:
        # Replace existing entry
        for i, a in enumerate(assets):
            if a.get("mockup_asset_id") == mockup_asset_id:
                assets[i] = new_entry
                print(f"Replaced existing entry: {mockup_asset_id}", file=sys.stderr)
                break
    else:
        # Append new entry
        assets.append(new_entry)
        print(f"Added new entry: {mockup_asset_id}", file=sys.stderr)

    registry["assets"] = assets

    # Update version if V2 schema
    if registry.get("version") < 2:
        registry["version"] = 2

    # Save registry
    print(f"Saving registry: {registry_file}", file=sys.stderr)
    save_yaml(registry_file, registry)

    # Output success
    print(json.dumps({
        "status": "success",
        "mockup_asset_id": mockup_asset_id,
        "asset_path": str(asset_abs_path),
        "registry_entry": new_entry,
    }, indent=2))


if __name__ == "__main__":
    main()
