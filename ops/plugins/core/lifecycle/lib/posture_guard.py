"""Execution posture enforcement for authority bridges.

Checks SPINE_EXECUTION_POSTURE env var and blocks registry-growth mutations
(upsert of new gaps/loops) when posture is 'converge', unless an explicit
override reason is provided via SPINE_POSTURE_OVERRIDE_REASON.

Shrink-direction mutations (close, reparent, continuity) are always allowed
regardless of posture.
"""

from __future__ import annotations

import os
import sys

# Commands that grow the registry (new gap/loop creation).
GROWTH_COMMANDS = frozenset({"upsert"})

# Commands that shrink or clarify the registry (always allowed).
SHRINK_COMMANDS = frozenset({"close", "reparent", "continuity", "sync"})


def check_posture_guard(command: str, *, bridge_name: str = "authority-bridge") -> None:
    """Check execution posture before allowing a mutation.

    Call this at the top of growth-direction command handlers (upsert).
    Does nothing for shrink-direction commands or non-converge postures.

    Exits with code 1 and structured error if posture is converge and
    no override reason is provided.
    """
    if command not in GROWTH_COMMANDS:
        return

    posture = os.environ.get("SPINE_EXECUTION_POSTURE", "discover").strip().lower()

    if posture in ("discover", "degraded", ""):
        return

    if posture != "converge":
        print(
            f"posture-guard: unrecognized posture '{posture}', treating as discover",
            file=sys.stderr,
        )
        return

    override_reason = os.environ.get("SPINE_POSTURE_OVERRIDE_REASON", "").strip()
    if override_reason:
        print(
            f"posture-guard: converge override for {bridge_name} {command}",
            file=sys.stderr,
        )
        print(f"  reason: {override_reason}", file=sys.stderr)
        return

    print(
        f"POSTURE BLOCKED: Active execution posture is 'converge'.",
        file=sys.stderr,
    )
    print(f"  Bridge: {bridge_name}", file=sys.stderr)
    print(f"  Command: {command}", file=sys.stderr)
    print(
        "  Registry growth (new gaps/loops) is denied during converge posture.",
        file=sys.stderr,
    )
    print("  Remediation:", file=sys.stderr)
    print(
        "    - Record observations in the session receipt instead",
        file=sys.stderr,
    )
    print(
        "    - Or rerun with SPINE_EXECUTION_POSTURE=discover",
        file=sys.stderr,
    )
    print(
        '    - Or set SPINE_POSTURE_OVERRIDE_REASON="<reason>" for break-glass',
        file=sys.stderr,
    )
    sys.exit(1)
