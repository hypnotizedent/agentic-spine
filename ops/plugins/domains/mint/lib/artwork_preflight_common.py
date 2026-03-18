from __future__ import annotations

import copy
import mimetypes
import os
import re
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

from PIL import Image

from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root as governed_resolve_spine_root
from operator_mail_common import file_sha256
from quote_packet_normalize import dump_yaml, load_structured_file, now_utc


ARTWORK_PREFLIGHT_NAMESPACE = uuid.uuid5(
    uuid.NAMESPACE_URL,
    "https://spine.ronny.works/mint/artwork-preflight",
)
RASTER_EXTENSIONS = {"png", "jpg", "jpeg", "webp", "tif", "tiff"}
VECTOR_EXTENSIONS = {"ai", "eps", "svg"}
PDF_EXTENSIONS = {"pdf"}
SPOT_COLOR_RE = re.compile(r"(?i)\b(?:pantone|pms)\s*[a-z0-9 -]{1,24}")
HEX_COLOR_RE = re.compile(r"#[0-9a-fA-F]{3,8}\b")
RGB_COLOR_RE = re.compile(r"rgba?\([^)]+\)")
SVG_VECTOR_TAGS = ("path", "rect", "circle", "ellipse", "polygon", "polyline", "line")


def resolve_spine_root() -> Path:
    return governed_resolve_spine_root(__file__)


def resolve_mint_root(spine_root: Path | None = None) -> Path:
    return resolve_mint_data_root(spine_root=spine_root, current_file=__file__)


def runtime_paths(spine_root: Path | None = None) -> dict[str, Path]:
    mint_root = resolve_mint_root(spine_root)
    return {
        "mint_root": mint_root,
        "records_root": Path(os.environ.get("MINT_ARTWORK_PREFLIGHT_DIR") or (mint_root / "artwork-preflights")),
        "index_file": Path(
            os.environ.get("MINT_ARTWORK_PREFLIGHT_INDEX_FILE") or (mint_root / "artwork-preflights-index.yaml")
        ),
    }


def entity_file(entity_dir: Path, prefix: str, entity_id: str) -> Path:
    return entity_dir / f"{prefix}_{entity_id}.yaml"


def load_index(index_file: Path, list_key: str) -> list[dict[str, Any]]:
    payload = load_structured_file(index_file) if index_file.exists() else {}
    if not isinstance(payload, dict):
        return []
    return [copy.deepcopy(item) for item in (payload.get(list_key) or []) if isinstance(item, dict)]


def update_entity_index(index_file: Path, list_key: str, entity_key: str, entry: dict[str, Any]) -> None:
    payload = load_structured_file(index_file) if index_file.exists() else {list_key: []}
    if not isinstance(payload, dict):
        payload = {list_key: []}
    rows = payload.setdefault(list_key, [])
    existing = next(
        (
            item
            for item in rows
            if isinstance(item, dict) and normalize_space(item.get(entity_key) or "") == normalize_space(entry.get(entity_key) or "")
        ),
        None,
    )
    if existing is not None:
        existing.update(copy.deepcopy(entry))
    else:
        rows.append(copy.deepcopy(entry))
    dump_yaml(index_file, payload)


def normalize_space(value: Any) -> str:
    return " ".join(str(value or "").strip().split())


def normalize_lower(value: Any) -> str:
    return normalize_space(value).lower()


def maybe_int(value: Any) -> int | None:
    try:
        if value in (None, ""):
            return None
        return int(value)
    except (TypeError, ValueError):
        return None


def maybe_float(value: Any) -> float | None:
    try:
        if value in (None, ""):
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def compact_truth(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: compact_truth(item) for key, item in value.items() if compact_truth(item) not in (None, "", [], {})}
    if isinstance(value, list):
        out = [compact_truth(item) for item in value]
        return [item for item in out if item not in (None, "", [], {})]
    return value


def preflight_id_for(
    *,
    sha256: str,
    piece_quantity: int | None,
    requested_width_in: float | None,
    requested_height_in: float | None,
    artifact_id: str,
    attachment_name: str,
) -> str:
    basis = "|".join(
        [
            normalize_space(sha256),
            str(piece_quantity or ""),
            str(requested_width_in or ""),
            str(requested_height_in or ""),
            normalize_space(artifact_id),
            normalize_space(attachment_name),
        ]
    )
    return str(uuid.uuid5(ARTWORK_PREFLIGHT_NAMESPACE, basis))


def guess_content_type(file_path: Path, explicit: str = "") -> str:
    if normalize_space(explicit):
        return normalize_space(explicit).lower()
    guessed, _ = mimetypes.guess_type(str(file_path))
    return normalize_space(guessed or "").lower()


def file_extension(file_path: Path) -> str:
    return file_path.suffix.lower().lstrip(".")


def file_kind(file_path: Path, content_type: str = "") -> str:
    extension = file_extension(file_path)
    normalized_content_type = normalize_space(content_type).lower()
    if extension in RASTER_EXTENSIONS or normalized_content_type.startswith("image/"):
        if extension != "svg":
            return "raster"
    if extension in VECTOR_EXTENSIONS or normalized_content_type in {"application/postscript", "application/illustrator", "image/svg+xml"}:
        return "vector"
    if extension in PDF_EXTENSIONS or normalized_content_type == "application/pdf":
        return "pdf"
    return "unsupported"


def check_entry(check_id: str, state: str, summary: str, *, severity: str = "info", details: dict[str, Any] | None = None) -> dict[str, Any]:
    payload = {
        "check_id": check_id,
        "state": normalize_space(state) or "unknown",
        "severity": normalize_space(severity) or "info",
        "summary": normalize_space(summary) or None,
        "details": compact_truth(details or {}) or None,
    }
    return compact_truth(payload)


def quality_state(checks: list[dict[str, Any]]) -> str:
    if any(str(item.get("state") or "") == "fail" for item in checks):
        return "review_required"
    if any(str(item.get("state") or "") == "warn" for item in checks):
        return "review_required"
    return "pass"


def extract_spot_color_refs(text: str) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for match in SPOT_COLOR_RE.findall(text or ""):
        label = normalize_space(match)
        if not label:
            continue
        key = label.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(label)
    return out


def color_token_count(text: str) -> int:
    tokens = {item.lower() for item in HEX_COLOR_RE.findall(text or "")}
    tokens.update(item.lower() for item in RGB_COLOR_RE.findall(text or ""))
    return len(tokens)


def readable_text_fallback(path: Path) -> str:
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    if "\x00" in raw:
        return ""
    return raw


def parse_svg_size_to_inches(value: str) -> float | None:
    raw = normalize_space(value)
    if not raw:
        return None
    match = re.match(r"^([0-9.]+)\s*(px|in|mm|cm|pt)?$", raw, flags=re.IGNORECASE)
    if not match:
        return None
    amount = maybe_float(match.group(1))
    unit = normalize_lower(match.group(2) or "px")
    if amount is None:
        return None
    if unit == "in":
        return amount
    if unit == "mm":
        return round(amount / 25.4, 3)
    if unit == "cm":
        return round(amount / 2.54, 3)
    if unit == "pt":
        return round(amount / 72.0, 3)
    return round(amount / 96.0, 3)


def parse_svg_dimensions(root: ET.Element) -> dict[str, Any]:
    width_in = parse_svg_size_to_inches(root.attrib.get("width", ""))
    height_in = parse_svg_size_to_inches(root.attrib.get("height", ""))
    view_box = normalize_space(root.attrib.get("viewBox") or "")
    if view_box and (width_in is None or height_in is None):
        parts = [maybe_float(item) for item in view_box.split()]
        if len(parts) == 4 and parts[2] is not None and parts[3] is not None:
            width_in = width_in if width_in is not None else round(parts[2] / 96.0, 3)
            height_in = height_in if height_in is not None else round(parts[3] / 96.0, 3)
    return compact_truth(
        {
            "width_in": width_in,
            "height_in": height_in,
            "view_box": view_box or None,
        }
    )


def parse_bounding_box_to_inches(text: str) -> dict[str, Any]:
    match = re.search(r"%%BoundingBox:\s*([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)", text or "")
    if not match:
        return {}
    x0 = maybe_float(match.group(1))
    y0 = maybe_float(match.group(2))
    x1 = maybe_float(match.group(3))
    y1 = maybe_float(match.group(4))
    if None in {x0, y0, x1, y1}:
        return {}
    return {
        "width_in": round(abs(float(x1) - float(x0)) / 72.0, 3),
        "height_in": round(abs(float(y1) - float(y0)) / 72.0, 3),
    }


def raster_effective_dpi(
    *,
    width_px: int,
    height_px: int,
    metadata_dpi: dict[str, float] | None,
    requested_size: dict[str, Any],
) -> dict[str, Any]:
    req_width = maybe_float(requested_size.get("width_in"))
    req_height = maybe_float(requested_size.get("height_in"))
    if req_width and req_height:
        return {
            "x": round(width_px / req_width, 1),
            "y": round(height_px / req_height, 1),
            "source": "requested_size",
        }
    if metadata_dpi and metadata_dpi.get("x") and metadata_dpi.get("y"):
        return {
            "x": round(float(metadata_dpi["x"]), 1),
            "y": round(float(metadata_dpi["y"]), 1),
            "source": "embedded_metadata",
        }
    return {}


def recommend_print_method(
    *,
    file_kind_value: str,
    estimated_color_count: int | None,
    has_gradients: bool,
    piece_quantity: int | None,
    vector_signal: bool,
    embedded_raster_present: bool,
    spot_color_count: int,
    model_config: dict[str, Any],
) -> tuple[str | None, str, list[str]]:
    rules = dict((model_config.get("print_method_recommendation") or {}))
    if not bool(rules.get("enabled", True)):
        return None, "low", []

    dtg_threshold = dict(rules.get("dtg_threshold") or {})
    screen_threshold = dict(rules.get("screen_print_threshold") or {})
    vector_bias = dict(rules.get("vector_screen_print_bias") or {})

    dtg_min_colors = int(dtg_threshold.get("min_colors") or 5)
    dtg_piece_range = list(dtg_threshold.get("piece_range") or [50, 1000])
    dtg_min_pieces = int(dtg_piece_range[0]) if len(dtg_piece_range) > 0 else 50
    dtg_max_pieces = int(dtg_piece_range[1]) if len(dtg_piece_range) > 1 else 1000
    dtg_requires_gradient = bool(dtg_threshold.get("or_has_gradients", True))

    screen_max_colors = int(screen_threshold.get("max_colors") or 4)
    screen_min_pieces = int(screen_threshold.get("min_pieces") or 24)
    vector_max_spot_colors = int(vector_bias.get("max_spot_colors") or 6)

    qty_in_dtg_range = piece_quantity is not None and dtg_min_pieces <= piece_quantity <= dtg_max_pieces
    qty_screen_ready = piece_quantity is not None and piece_quantity >= screen_min_pieces
    color_count = int(estimated_color_count or 0)

    if vector_signal and file_kind_value in {"vector", "pdf"} and qty_screen_ready and not has_gradients and not embedded_raster_present:
        reasons = ["vector_signal", f"piece_quantity>={screen_min_pieces}"]
        if spot_color_count:
            reasons.append(f"spot_color_count={spot_color_count}")
        if spot_color_count and spot_color_count <= vector_max_spot_colors:
            return "screen_print", "high", reasons
        if color_count and color_count <= max(screen_max_colors, vector_max_spot_colors):
            reasons.append(f"estimated_color_count<={max(screen_max_colors, vector_max_spot_colors)}")
            return "screen_print", "high", reasons
        return "screen_print", "medium", reasons

    dtg_reasons: list[str] = []
    if color_count >= dtg_min_colors:
        dtg_reasons.append(f"estimated_color_count>={dtg_min_colors}")
    if dtg_requires_gradient and has_gradients:
        dtg_reasons.append("gradient_signal")
    if embedded_raster_present:
        dtg_reasons.append("embedded_raster_signal")
    if qty_in_dtg_range:
        dtg_reasons.append(f"piece_quantity_in_range:{piece_quantity}")
    if dtg_reasons and qty_in_dtg_range:
        return "dtg", "high", dtg_reasons
    if qty_screen_ready and color_count and color_count <= screen_max_colors and not has_gradients:
        return "screen_print", "high", [f"estimated_color_count<={screen_max_colors}", f"piece_quantity>={screen_min_pieces}"]
    if dtg_reasons:
        return "dtg", "medium", dtg_reasons
    if vector_signal:
        return "screen_print", "medium", ["vector_signal"]
    return None, "low", []


def analyze_raster(
    file_path: Path,
    *,
    piece_quantity: int | None,
    requested_size: dict[str, Any],
    model_config: dict[str, Any],
) -> dict[str, Any]:
    max_sample_side = max(int(((model_config.get("raster_analysis") or {}).get("max_sample_side") or 0)), 0) or 160
    gradient_model = dict(((model_config.get("raster_analysis") or {}).get("gradient_detection")) or {})
    min_dpi = int((((model_config.get("raster_analysis") or {}).get("dpi")) or {}).get("minimum_print_dpi") or 300)

    with Image.open(file_path) as image:
        image.load()
        rgba = image.convert("RGBA")
        metadata = dict(image.info or {})
    width_px, height_px = rgba.size
    sampled = rgba.copy()
    sampled.thumbnail((max_sample_side, max_sample_side))
    pixels = list(sampled.getdata())
    opaque_pixels = [tuple(pixel[:3]) for pixel in pixels if len(pixel) == 4 and pixel[3] > 16]
    if not opaque_pixels:
        opaque_pixels = [tuple(pixel[:3]) for pixel in pixels]

    exact_unique = len(set(opaque_pixels))
    quantized = sampled.convert("RGB").quantize(colors=min(32, max(8, exact_unique or 1)))
    quantized_counts = quantized.getcolors(maxcolors=256) or []
    estimated_color_count = max(len(quantized_counts), 1)
    continuous_tone_ratio = float(exact_unique) / float(max(estimated_color_count, 1))
    gradient_floor = int(gradient_model.get("min_exact_unique_colors") or 96)
    gradient_ratio = float(gradient_model.get("continuous_tone_ratio") or 4.0)
    has_gradients = exact_unique >= gradient_floor or continuous_tone_ratio >= gradient_ratio
    complexity_score = round(
        min(
            1.0,
            (min(estimated_color_count / 12.0, 1.0) * 0.45)
            + (min(exact_unique / 128.0, 1.0) * 0.35)
            + (0.20 if has_gradients else 0.0),
        ),
        2,
    )
    metadata_dpi = {}
    if isinstance(metadata.get("dpi"), tuple) and len(metadata["dpi"]) == 2:
        metadata_dpi = {"x": float(metadata["dpi"][0]), "y": float(metadata["dpi"][1])}
    effective_dpi = raster_effective_dpi(
        width_px=width_px,
        height_px=height_px,
        metadata_dpi=metadata_dpi,
        requested_size=requested_size,
    )
    transparency_present = any(len(pixel) == 4 and pixel[3] < 250 for pixel in pixels)

    recommended_method, recommendation_confidence, recommendation_basis = recommend_print_method(
        file_kind_value="raster",
        estimated_color_count=estimated_color_count,
        has_gradients=has_gradients,
        piece_quantity=piece_quantity,
        vector_signal=False,
        embedded_raster_present=True,
        spot_color_count=0,
        model_config=model_config,
    )

    dpi_x = maybe_float(effective_dpi.get("x"))
    dpi_y = maybe_float(effective_dpi.get("y"))
    low_dpi = dpi_x is not None and dpi_y is not None and min(dpi_x, dpi_y) < min_dpi
    print_ready_candidate = dpi_x is not None and dpi_y is not None and not low_dpi

    checks = [
        check_entry("supported_format", "pass", "Supported raster artwork file.", details={"file_kind": "raster"}),
        check_entry(
            "print_dpi",
            "fail" if low_dpi else ("pass" if print_ready_candidate else "unknown"),
            (
                f"Effective print dpi is {min(dpi_x, dpi_y):.1f}, below the {min_dpi} dpi threshold."
                if low_dpi
                else (
                    f"Effective print dpi is {min(dpi_x, dpi_y):.1f}."
                    if print_ready_candidate
                    else "No requested print size or embedded dpi metadata was available."
                )
            ),
            severity="warn" if low_dpi else "info",
            details=effective_dpi,
        ),
        check_entry(
            "gradient_signal",
            "warn" if has_gradients else "pass",
            "Gradient or continuous-tone signal detected." if has_gradients else "No strong gradient signal detected.",
            severity="warn" if has_gradients else "info",
            details={"estimated_color_count": estimated_color_count, "exact_unique_sample_colors": exact_unique},
        ),
        check_entry(
            "transparency",
            "warn" if transparency_present else "pass",
            "Transparency or alpha was detected in the raster artwork." if transparency_present else "No alpha transparency detected.",
            severity="warn" if transparency_present else "info",
        ),
    ]

    art_label = "full-color artwork with gradient transitions" if has_gradients else ("multi-color artwork" if estimated_color_count >= 5 else "lower-color artwork")
    detail_parts = [f"about {estimated_color_count} colors", f"{width_px}x{height_px}px"]
    if print_ready_candidate:
        detail_parts.append(f"about {min(dpi_x, dpi_y):.0f} dpi at requested size")
    summary = f"Attached art reads as {art_label} ({', '.join(detail_parts)})."
    if recommended_method and piece_quantity:
        summary = f"{summary[:-1]} At {piece_quantity} pieces, {recommended_method.replace('_', ' ')} looks like the cleaner recommendation."
    customer_summary = summary

    return compact_truth(
        {
            "state": "captured",
            "summary": summary,
            "customer_summary": customer_summary,
            "recommended_print_method": recommended_method,
            "recommendation_confidence": recommendation_confidence,
            "recommendation_basis": recommendation_basis,
            "review_required": quality_state(checks) != "pass",
            "readiness_state": "raster_print_ready_candidate" if print_ready_candidate and quality_state(checks) == "pass" else "raster_review_required",
            "print_ready_candidate": print_ready_candidate,
            "estimated_color_count": int(estimated_color_count),
            "has_gradients": bool(has_gradients),
            "complexity_score": complexity_score,
            "dimensions": {"width_px": width_px, "height_px": height_px},
            "metadata_dpi": metadata_dpi or None,
            "effective_dpi": effective_dpi or None,
            "prepress_signals": {
                "vector_signal": False,
                "embedded_raster_present": True,
                "transparency_present": transparency_present,
                "gradient_present": has_gradients,
                "spot_color_refs": [],
                "separation_signal": False,
                "live_text_present": False,
            },
            "checks": checks,
        }
    )


def analyze_svg(
    file_path: Path,
    *,
    piece_quantity: int | None,
    model_config: dict[str, Any],
) -> dict[str, Any]:
    text = readable_text_fallback(file_path)
    root = ET.fromstring(text)
    dims = parse_svg_dimensions(root)
    path_count = sum(1 for tag in SVG_VECTOR_TAGS for _ in root.findall(f".//{{*}}{tag}"))
    text_count = sum(1 for _ in root.findall(".//{*}text"))
    image_count = sum(1 for _ in root.findall(".//{*}image"))
    gradient_count = sum(1 for _ in root.findall(".//{*}linearGradient")) + sum(1 for _ in root.findall(".//{*}radialGradient"))
    transparency_present = bool(re.search(r'(?i)(?:opacity|fill-opacity|stroke-opacity)\s*=\s*"?(?!1(?:\.0+)?\b)[0-9.]+', text))
    spot_refs = extract_spot_color_refs(text)
    estimated_color_count = max(color_token_count(text), len(spot_refs) or 0) or None
    has_gradients = gradient_count > 0
    embedded_raster_present = image_count > 0
    live_text_present = text_count > 0
    vector_signal = path_count > 0

    recommended_method, recommendation_confidence, recommendation_basis = recommend_print_method(
        file_kind_value="vector",
        estimated_color_count=estimated_color_count,
        has_gradients=has_gradients,
        piece_quantity=piece_quantity,
        vector_signal=vector_signal,
        embedded_raster_present=embedded_raster_present,
        spot_color_count=len(spot_refs),
        model_config=model_config,
    )

    checks = [
        check_entry("supported_format", "pass", "Supported SVG vector artwork file.", details={"file_kind": "vector"}),
        check_entry(
            "vector_paths",
            "pass" if vector_signal else "fail",
            "Vector drawing paths are present." if vector_signal else "No vector drawing paths were detected.",
            severity="warn" if not vector_signal else "info",
            details={"path_count": path_count},
        ),
        check_entry(
            "live_text",
            "warn" if live_text_present else "pass",
            "Live text is still present in the file." if live_text_present else "No live text elements were detected.",
            severity="warn" if live_text_present else "info",
            details={"text_element_count": text_count},
        ),
        check_entry(
            "embedded_raster",
            "warn" if embedded_raster_present else "pass",
            "Embedded raster imagery is present in the SVG." if embedded_raster_present else "No embedded raster imagery was detected.",
            severity="warn" if embedded_raster_present else "info",
            details={"image_element_count": image_count},
        ),
        check_entry(
            "spot_colors",
            "pass" if spot_refs else "unknown",
            f"Spot-color refs detected: {', '.join(spot_refs[:3])}." if spot_refs else "No explicit PMS/spot-color refs detected in the SVG source.",
            details={"spot_color_refs": spot_refs},
        ),
    ]

    detail_parts: list[str] = []
    if dims.get("width_in") and dims.get("height_in"):
        detail_parts.append(f"about {float(dims['width_in']):g}x{float(dims['height_in']):g}in")
    if spot_refs:
        detail_parts.append(f"{len(spot_refs)} spot-color ref{'s' if len(spot_refs) != 1 else ''}")
    elif estimated_color_count:
        detail_parts.append(f"about {estimated_color_count} solid colors")
    if has_gradients:
        detail_parts.append("gradient cues")
    summary = "Attached art reads as vector artwork"
    if detail_parts:
        summary += f" ({', '.join(detail_parts)})"
    summary += "."
    if live_text_present:
        summary += " Live text is still present, so Artie should clean that before calling it production-safe."
    if embedded_raster_present:
        summary += " Embedded raster content is present, so Artie should verify the placed image quality."
    if recommended_method and piece_quantity:
        summary += f" At {piece_quantity} pieces, {recommended_method.replace('_', ' ')} looks like the cleaner recommendation."
    customer_summary = "The attached file looks like vector artwork."
    if recommended_method and piece_quantity:
        customer_summary += f" At {piece_quantity} pieces, {recommended_method.replace('_', ' ')} looks like the cleaner lane."

    return compact_truth(
        {
            "state": "captured",
            "summary": summary,
            "customer_summary": customer_summary,
            "recommended_print_method": recommended_method,
            "recommendation_confidence": recommendation_confidence,
            "recommendation_basis": recommendation_basis,
            "review_required": quality_state(checks) != "pass",
            "readiness_state": "vector_print_ready_candidate" if quality_state(checks) == "pass" else "vector_review_required",
            "print_ready_candidate": quality_state(checks) == "pass",
            "estimated_color_count": estimated_color_count,
            "has_gradients": has_gradients,
            "dimensions": dims,
            "prepress_signals": {
                "vector_signal": vector_signal,
                "embedded_raster_present": embedded_raster_present,
                "transparency_present": transparency_present,
                "gradient_present": has_gradients,
                "spot_color_refs": spot_refs,
                "separation_signal": bool(spot_refs),
                "live_text_present": live_text_present,
            },
            "checks": checks,
        }
    )


def analyze_postscript_vector(
    file_path: Path,
    *,
    piece_quantity: int | None,
    model_config: dict[str, Any],
) -> dict[str, Any]:
    text = readable_text_fallback(file_path)
    dims = parse_bounding_box_to_inches(text)
    path_ops = len(re.findall(r"\b(?:moveto|lineto|curveto|closepath)\b", text, flags=re.IGNORECASE))
    live_text_present = bool(re.search(r"\bshow\b", text, flags=re.IGNORECASE) or "/Font" in text)
    embedded_raster_present = bool(re.search(r"\b(?:image|colorimage)\b", text, flags=re.IGNORECASE))
    has_gradients = bool(re.search(r"\b(?:gradient|shading)\b", text, flags=re.IGNORECASE))
    separation_signal = bool(re.search(r"(?i)(?:/Separation|%%DocumentCustomColors|%%CMYKCustomColor|%%PlateColor)", text))
    spot_refs = extract_spot_color_refs(text)
    estimated_color_count = max(color_token_count(text), len(spot_refs) or 0) or None

    recommended_method, recommendation_confidence, recommendation_basis = recommend_print_method(
        file_kind_value="vector",
        estimated_color_count=estimated_color_count,
        has_gradients=has_gradients,
        piece_quantity=piece_quantity,
        vector_signal=path_ops > 0 or separation_signal,
        embedded_raster_present=embedded_raster_present,
        spot_color_count=len(spot_refs),
        model_config=model_config,
    )

    checks = [
        check_entry("supported_format", "pass", "Supported AI/EPS vector artwork file.", details={"file_kind": "vector"}),
        check_entry(
            "vector_paths",
            "pass" if path_ops > 0 else "unknown",
            "Vector path operators were detected." if path_ops > 0 else "No explicit vector path operators were detected in the readable source.",
            details={"path_operator_count": path_ops},
        ),
        check_entry(
            "live_text",
            "warn" if live_text_present else "pass",
            "Live text or font references are still present." if live_text_present else "No live text or font references were detected.",
            severity="warn" if live_text_present else "info",
        ),
        check_entry(
            "embedded_raster",
            "warn" if embedded_raster_present else "pass",
            "Embedded raster image operators were detected." if embedded_raster_present else "No embedded raster image operators were detected.",
            severity="warn" if embedded_raster_present else "info",
        ),
        check_entry(
            "separations",
            "pass" if separation_signal else "unknown",
            "Separation or custom-color markers were detected." if separation_signal else "No explicit separation/custom-color markers were detected.",
            details={"spot_color_refs": spot_refs},
        ),
    ]

    detail_parts: list[str] = []
    if dims.get("width_in") and dims.get("height_in"):
        detail_parts.append(f"about {float(dims['width_in']):g}x{float(dims['height_in']):g}in")
    if spot_refs:
        detail_parts.append(f"{len(spot_refs)} spot-color ref{'s' if len(spot_refs) != 1 else ''}")
    elif estimated_color_count:
        detail_parts.append(f"about {estimated_color_count} solid colors")
    summary = "Attached art reads as vector artwork"
    if detail_parts:
        summary += f" ({', '.join(detail_parts)})"
    summary += "."
    if live_text_present:
        summary += " Live text is still present, so Artie should review outline/font safety."
    if embedded_raster_present:
        summary += " Embedded raster content is present, so Artie should verify the placed image quality."
    if recommended_method and piece_quantity:
        summary += f" At {piece_quantity} pieces, {recommended_method.replace('_', ' ')} looks like the cleaner recommendation."
    customer_summary = "The attached file looks like vector artwork."
    if recommended_method and piece_quantity:
        customer_summary += f" At {piece_quantity} pieces, {recommended_method.replace('_', ' ')} looks like the cleaner lane."

    return compact_truth(
        {
            "state": "captured",
            "summary": summary,
            "customer_summary": customer_summary,
            "recommended_print_method": recommended_method,
            "recommendation_confidence": recommendation_confidence,
            "recommendation_basis": recommendation_basis,
            "review_required": quality_state(checks) != "pass",
            "readiness_state": "vector_print_ready_candidate" if quality_state(checks) == "pass" else "vector_review_required",
            "print_ready_candidate": quality_state(checks) == "pass",
            "estimated_color_count": estimated_color_count,
            "has_gradients": has_gradients,
            "dimensions": dims,
            "prepress_signals": {
                "vector_signal": path_ops > 0 or separation_signal,
                "embedded_raster_present": embedded_raster_present,
                "transparency_present": False,
                "gradient_present": has_gradients,
                "spot_color_refs": spot_refs,
                "separation_signal": separation_signal,
                "live_text_present": live_text_present,
            },
            "checks": checks,
        }
    )


def analyze_pdf(
    file_path: Path,
    *,
    piece_quantity: int | None,
    model_config: dict[str, Any],
) -> dict[str, Any]:
    raw = file_path.read_bytes()
    text = raw.decode("latin-1", errors="ignore")
    extracted_text = ""
    page_count = 0
    width_in = None
    height_in = None
    try:
        from pypdf import PdfReader  # noqa: PLC0415

        reader = PdfReader(str(file_path))
        page_count = len(reader.pages)
        if reader.pages:
            first_page = reader.pages[0]
            media_box = first_page.mediabox
            width_in = round(float(media_box.width) / 72.0, 3)
            height_in = round(float(media_box.height) / 72.0, 3)
            extracted_text = "\n".join(normalize_space(page.extract_text() or "") for page in reader.pages).strip()
    except Exception:
        extracted_text = ""

    embedded_raster_present = b"/Subtype /Image" in raw or "/Image" in text
    separation_signal = "/Separation" in text or "/DeviceN" in text
    has_gradients = "/Shading" in text or "Gradient" in text
    transparency_present = "/SMask" in text or "/Transparency" in text
    live_text_present = bool(normalize_space(extracted_text)) or "/Font" in text
    spot_refs = extract_spot_color_refs(text + "\n" + extracted_text)
    estimated_color_count = len(spot_refs) or None
    vector_signal = separation_signal or not embedded_raster_present or bool(normalize_space(extracted_text))

    recommended_method, recommendation_confidence, recommendation_basis = recommend_print_method(
        file_kind_value="pdf",
        estimated_color_count=estimated_color_count,
        has_gradients=has_gradients,
        piece_quantity=piece_quantity,
        vector_signal=vector_signal,
        embedded_raster_present=embedded_raster_present,
        spot_color_count=len(spot_refs),
        model_config=model_config,
    )

    checks = [
        check_entry("supported_format", "pass", "Supported PDF artwork file.", details={"file_kind": "pdf", "page_count": page_count}),
        check_entry(
            "vector_signal",
            "pass" if vector_signal else "warn",
            "Vector-friendly PDF signals were detected." if vector_signal else "This PDF reads more like an image container than a clean vector export.",
            severity="warn" if not vector_signal else "info",
        ),
        check_entry(
            "live_text",
            "warn" if live_text_present else "pass",
            "Live text or font references were detected in the PDF." if live_text_present else "No live text or font references were detected.",
            severity="warn" if live_text_present else "info",
        ),
        check_entry(
            "embedded_raster",
            "warn" if embedded_raster_present else "pass",
            "Embedded raster imagery was detected in the PDF." if embedded_raster_present else "No embedded raster imagery was detected.",
            severity="warn" if embedded_raster_present else "info",
        ),
        check_entry(
            "separations",
            "pass" if separation_signal or spot_refs else "unknown",
            "Spot/separation markers were detected in the PDF." if separation_signal or spot_refs else "No explicit separation/spot markers were detected in the PDF.",
            details={"spot_color_refs": spot_refs},
        ),
    ]

    detail_parts = []
    if width_in and height_in:
        detail_parts.append(f"about {width_in:g}x{height_in:g}in")
    if page_count:
        detail_parts.append(f"{page_count} page{'s' if page_count != 1 else ''}")
    if spot_refs:
        detail_parts.append(f"{len(spot_refs)} spot-color ref{'s' if len(spot_refs) != 1 else ''}")
    summary = "Attached art reads as a PDF artwork export"
    if detail_parts:
        summary += f" ({', '.join(detail_parts)})"
    summary += "."
    if live_text_present:
        summary += " Live text or font references are still present, so Artie should review font safety."
    if embedded_raster_present:
        summary += " Embedded raster content is present, so Artie should verify image quality before production."
    if recommended_method and piece_quantity:
        summary += f" At {piece_quantity} pieces, {recommended_method.replace('_', ' ')} looks like the cleaner recommendation."
    customer_summary = "The attached file looks like a production PDF export."
    if recommended_method and piece_quantity:
        customer_summary += f" At {piece_quantity} pieces, {recommended_method.replace('_', ' ')} looks like the cleaner lane."

    return compact_truth(
        {
            "state": "captured",
            "summary": summary,
            "customer_summary": customer_summary,
            "recommended_print_method": recommended_method,
            "recommendation_confidence": recommendation_confidence,
            "recommendation_basis": recommendation_basis,
            "review_required": quality_state(checks) != "pass",
            "readiness_state": "pdf_print_ready_candidate" if quality_state(checks) == "pass" else "pdf_review_required",
            "print_ready_candidate": quality_state(checks) == "pass",
            "estimated_color_count": estimated_color_count,
            "has_gradients": bool(has_gradients),
            "dimensions": compact_truth({"width_in": width_in, "height_in": height_in, "page_count": page_count}),
            "prepress_signals": {
                "vector_signal": vector_signal,
                "embedded_raster_present": embedded_raster_present,
                "transparency_present": bool(transparency_present),
                "gradient_present": bool(has_gradients),
                "spot_color_refs": spot_refs,
                "separation_signal": bool(separation_signal or spot_refs),
                "live_text_present": live_text_present,
            },
            "checks": checks,
        }
    )


def unsupported_result(file_path: Path, *, content_type: str) -> dict[str, Any]:
    return {
        "state": "unsupported",
        "summary": None,
        "customer_summary": None,
        "recommended_print_method": None,
        "recommendation_confidence": "low",
        "recommendation_basis": [],
        "review_required": True,
        "readiness_state": "unsupported",
        "print_ready_candidate": False,
        "estimated_color_count": None,
        "has_gradients": None,
        "dimensions": {},
        "prepress_signals": {
            "vector_signal": False,
            "embedded_raster_present": None,
            "transparency_present": None,
            "gradient_present": None,
            "spot_color_refs": [],
            "separation_signal": False,
            "live_text_present": None,
        },
        "checks": [
            check_entry(
                "supported_format",
                "fail",
                f"Unsupported artwork file type for preflight: {file_extension(file_path) or content_type or 'unknown'}.",
                severity="warn",
            )
        ],
    }


def analyze_artwork_file(
    file_path: Path,
    *,
    piece_quantity: int | None,
    requested_size: dict[str, Any],
    attachment_name: str = "",
    content_type: str = "",
    model_config: dict[str, Any] | None = None,
) -> dict[str, Any]:
    config = dict(model_config or {})
    normalized_content_type = guess_content_type(file_path, content_type)
    kind = file_kind(file_path, normalized_content_type)
    if kind == "raster":
        analysis = analyze_raster(file_path, piece_quantity=piece_quantity, requested_size=requested_size, model_config=config)
    elif kind == "vector":
        if file_extension(file_path) == "svg" or normalized_content_type == "image/svg+xml":
            analysis = analyze_svg(file_path, piece_quantity=piece_quantity, model_config=config)
        else:
            analysis = analyze_postscript_vector(file_path, piece_quantity=piece_quantity, model_config=config)
    elif kind == "pdf":
        analysis = analyze_pdf(file_path, piece_quantity=piece_quantity, model_config=config)
    else:
        analysis = unsupported_result(file_path, content_type=normalized_content_type)

    return compact_truth(
        {
            "owner": "Artie",
            "name": normalize_space(attachment_name or file_path.name) or file_path.name,
            "content_type": normalized_content_type or None,
            "file_kind": kind,
            "file_path": str(file_path),
            "sha256": file_sha256(file_path),
            "file_size_bytes": file_path.stat().st_size,
            "piece_quantity": piece_quantity,
            "requested_size": compact_truth(requested_size),
            **analysis,
        }
    )


def preflight_index_entry(record: dict[str, Any]) -> dict[str, Any]:
    source_ref = dict(record.get("source_ref") or {})
    customer_binding = dict(record.get("customer_binding") or {})
    job_binding = dict(record.get("job_binding") or {})
    analysis = dict(record.get("analysis") or {})
    return compact_truth(
        {
            "preflight_id": record.get("preflight_id"),
            "artifact_id": source_ref.get("artifact_id"),
            "seed_id": source_ref.get("seed_id"),
            "source_message_id": source_ref.get("source_message_id"),
            "source_conversation_id": source_ref.get("source_conversation_id"),
            "customer_id": customer_binding.get("customer_id"),
            "customer_email": customer_binding.get("customer_email"),
            "customer_name": customer_binding.get("customer_name"),
            "job_ref": job_binding.get("job_ref"),
            "order_id": job_binding.get("order_id"),
            "filename": record.get("file_identity", {}).get("original_filename"),
            "sha256": record.get("file_identity", {}).get("sha256"),
            "file_kind": analysis.get("file_kind"),
            "readiness_state": analysis.get("readiness_state"),
            "recommended_print_method": analysis.get("recommended_print_method"),
            "review_required": analysis.get("review_required"),
            "created_at": record.get("created_at"),
            "updated_at": record.get("updated_at"),
        }
    )


def packet_safe_artwork_preflight(payload: dict[str, Any]) -> dict[str, Any]:
    safe = copy.deepcopy(payload)
    safe.pop("file_path", None)
    return compact_truth(safe)
