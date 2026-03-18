from __future__ import annotations

import copy
import subprocess
from pathlib import Path
from typing import Any

from artwork_preflight_common import packet_safe_artwork_preflight
from operator_mail_common import first_json_object


def normalize_space(value: Any) -> str:
    return " ".join(str(value or "").strip().split())


def compact_truth(value: Any) -> Any:
    if isinstance(value, dict):
        payload: dict[str, Any] = {}
        for key, item in value.items():
            compacted = compact_truth(item)
            if compacted not in (None, "", [], {}):
                payload[key] = compacted
        return payload
    if isinstance(value, list):
        payload = [compact_truth(item) for item in value]
        return [item for item in payload if item not in (None, "", [], {})]
    return value


def resolve_preflight_command_path(command_path: str) -> Path:
    candidate = Path(command_path).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()
    return (Path(__file__).resolve().parents[5] / candidate).resolve()


def run_preflight_command(command_path: str, args: list[str], *, cwd: Path) -> dict[str, Any]:
    command = [str(resolve_preflight_command_path(command_path)), *args]
    if "--json" not in args:
        command.append("--json")
    result = subprocess.run(
        command,
        cwd=cwd,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        combined = (result.stdout or "") + ("\n" + result.stderr if result.stderr else "")
        raise RuntimeError(normalize_space(combined) or f"{Path(command[0]).name} failed")
    return first_json_object(result.stdout or "")


def surface_artwork_preflight(payload: dict[str, Any]) -> dict[str, Any]:
    record = dict(payload.get("data") or {})
    analysis = packet_safe_artwork_preflight(dict(record.get("analysis") or {}))
    readiness_state = normalize_space(analysis.get("readiness_state") or "")
    state = "captured"
    if readiness_state == "analysis_failed":
        state = "analysis_failed"
    elif not analysis:
        state = "missing"
    summary = normalize_space(analysis.get("summary") or "") or None
    return compact_truth(
        {
            "owner": "Artie",
            "source": normalize_space(payload.get("capability") or record.get("capability") or "mint.artwork.preflight")
            or "mint.artwork.preflight",
            "state": state,
            "capture_state": normalize_space(payload.get("capture_state") or ""),
            "preflight_id": normalize_space(payload.get("preflight_id") or record.get("preflight_id") or ""),
            "record_file": normalize_space(payload.get("record_file") or ""),
            "summary": summary,
            "customer_summary": normalize_space(analysis.get("customer_summary") or summary or "") or None,
            "recommended_print_method": normalize_space(analysis.get("recommended_print_method") or "") or None,
            "recommendation_confidence": normalize_space(analysis.get("recommendation_confidence") or "") or None,
            "recommendation_basis": [normalize_space(item) for item in (analysis.get("recommendation_basis") or []) if normalize_space(item)],
            "review_required": analysis.get("review_required"),
            "readiness_state": readiness_state or None,
            "print_ready_candidate": analysis.get("print_ready_candidate"),
            "estimated_color_count": analysis.get("estimated_color_count"),
            "has_gradients": analysis.get("has_gradients"),
            "dimensions": copy.deepcopy(analysis.get("dimensions") or {}),
            "prepress_signals": copy.deepcopy(analysis.get("prepress_signals") or {}),
            "checks": copy.deepcopy(analysis.get("checks") or []),
            "source_ref": copy.deepcopy(record.get("source_ref") or {}),
            "file_identity": copy.deepcopy(record.get("file_identity") or {}),
        }
    )
