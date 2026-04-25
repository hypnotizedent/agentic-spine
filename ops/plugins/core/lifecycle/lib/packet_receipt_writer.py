"""Inaugural canonical hidden packet receipt writer seam.

This module is the first-class library write surface for hidden packet-level
YAML receipts (EXEC_RECEIPT-*.yaml under $SPINE_STATE/domain-state/) introduced
by LOOP-SPINE-AGENT-WORKFLOW-UNIFICATION-20260410 Packet 1. No prior writer
exists; wave close is the intended caller.
"""

import hashlib
import os
import subprocess
from typing import Any, Dict

import yaml


class PacketReceiptError(Exception):
    """Raised for any validation, git-truth, or write failure."""


_REQUIRED_CORE_FIELDS = (
    "starting_head",
    "ending_head",
    "wave_id",
    "lanes",
    "final_verify",
    "blockers",
)


def _git(spine_repo: str, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", spine_repo, *args],
        check=False,
        capture_output=True,
        text=True,
    )


def _verify_commit(spine_repo: str, sha: str, label: str) -> None:
    if not isinstance(sha, str) or not sha.strip():
        raise PacketReceiptError(f"{label} must be a non-empty string")
    result = _git(spine_repo, "rev-parse", "--verify", f"{sha}^{{commit}}")
    if result.returncode != 0:
        raise PacketReceiptError(
            f"{label} ({sha!r}) is not a valid git commit in {spine_repo}: "
            f"{result.stderr.strip()}"
        )


def validate_head_truth(starting_head: str, ending_head: str, spine_repo: str) -> None:
    """Fail closed unless both SHAs resolve and starting is an ancestor of ending."""
    _verify_commit(spine_repo, starting_head, "starting_head")
    _verify_commit(spine_repo, ending_head, "ending_head")
    if starting_head == ending_head:
        return
    result = _git(
        spine_repo,
        "merge-base",
        "--is-ancestor",
        starting_head,
        ending_head,
    )
    if result.returncode != 0:
        raise PacketReceiptError(
            f"starting_head ({starting_head}) is not an ancestor of "
            f"ending_head ({ending_head}) in {spine_repo}"
        )


def _validate_required_fields(fields: Dict[str, Any]) -> None:
    if not isinstance(fields, dict):
        raise PacketReceiptError("fields must be a dict")
    for key in _REQUIRED_CORE_FIELDS:
        if key not in fields:
            raise PacketReceiptError(f"missing required core field: {key}")
        value = fields[key]
        if key in ("lanes", "blockers"):
            if not isinstance(value, list):
                raise PacketReceiptError(f"{key} must be a list")
        elif key == "final_verify":
            if not isinstance(value, (dict, list)):
                raise PacketReceiptError("final_verify must be a dict or list")
        else:
            if not isinstance(value, str) or not value.strip():
                raise PacketReceiptError(f"{key} must be a non-empty string")


def _canonical_dump(payload: Dict[str, Any]) -> str:
    return yaml.safe_dump(
        payload,
        sort_keys=True,
        default_flow_style=False,
        allow_unicode=True,
    )


def write_packet_receipt(
    destination_path: str, fields: Dict[str, Any], spine_repo: str
) -> Dict[str, Any]:
    """Validate, fingerprint, and atomically write a canonical packet receipt."""
    if not isinstance(destination_path, str) or not destination_path.strip():
        raise PacketReceiptError("destination_path must be a non-empty string")
    if not isinstance(spine_repo, str) or not spine_repo.strip():
        raise PacketReceiptError("spine_repo must be a non-empty string")

    _validate_required_fields(fields)
    validate_head_truth(fields["starting_head"], fields["ending_head"], spine_repo)

    if "fingerprint_sha256" in fields:
        raise PacketReceiptError(
            "fingerprint_sha256 must not be supplied by caller; it is computed"
        )

    payload: Dict[str, Any] = dict(fields)

    # fingerprint_sha256 is the sha256 of the canonical YAML serialization of
    # the payload BEFORE the fingerprint itself is injected.
    pre_fingerprint_bytes = _canonical_dump(payload).encode("utf-8")
    fingerprint = hashlib.sha256(pre_fingerprint_bytes).hexdigest()
    payload["fingerprint_sha256"] = fingerprint

    final_serialization = "---\n" + _canonical_dump(payload)

    parent_dir = os.path.dirname(destination_path)
    if parent_dir:
        os.makedirs(parent_dir, exist_ok=True)

    tmp_path = f"{destination_path}.tmp"
    try:
        with open(tmp_path, "w", encoding="utf-8") as handle:
            handle.write(final_serialization)
        os.replace(tmp_path, destination_path)
    except OSError as exc:
        try:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
        except OSError:
            pass
        raise PacketReceiptError(f"failed to write receipt: {exc}") from exc

    return payload
