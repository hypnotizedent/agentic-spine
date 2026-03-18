from __future__ import annotations

import re
from typing import Tuple


MARKETING_HINTS = (
    "unsubscribe",
    "manage preferences",
    "view in browser",
    "promo",
    "promotion",
    "discount",
    "sale",
    "newsletter",
    "special offer",
    "limited time",
    "free trial",
    "free digitizing",
    "vectorizing",
    "digitizing price",
    "patches at your door",
    "custom patches",
    "keychains",
    "web design",
    "pop-up",
    "opt-in audit",
)
OUTREACH_HINTS = (
    "advisors needed",
    "advisory opportunities",
    "board opportunity",
    "board opportunities",
    "board and advisory",
    "board seat",
    "your profile is a good fit",
    "open board",
    "open advisory",
    "quick conversation to learn more",
    "free for a quick conversation",
    "open approval",
    "unsecured",
    "funding's unsecured",
)
OUTREACH_LINK_HINTS = (
    "calendly.com",
    "calendar below",
    "schedule a call",
    "book time",
)
RISKY_HINTS = (
    "click here",
    "claim",
    "urgent",
    "verify account",
    "confirm account",
    "winner",
    "gift",
    "reward",
)


def clean(text: str) -> str:
    return re.sub(r"\s+", " ", text or "").strip()


def classify_message(sender: str, subject: str, preview: str) -> Tuple[str, str, str]:
    sender = clean(sender).lower()
    subject = clean(subject).lower()
    preview = clean(preview).lower()
    text = " ".join(part for part in (sender, subject, preview) if part)
    internal_sender = sender.endswith("@mintprints.com")
    forwarded = subject.startswith("fw:") or subject.startswith("fwd:")
    marketing_hits = [hint for hint in MARKETING_HINTS if hint in text]
    outreach_hits = [hint for hint in OUTREACH_HINTS if hint in text]
    outreach_link_hits = [hint for hint in OUTREACH_LINK_HINTS if hint in text]
    risky_hits = [hint for hint in RISKY_HINTS if hint in text]
    outreach_sender = sender.endswith("@boardsi.com")

    if internal_sender and forwarded:
        return (
            "internal_forwarded",
            "review_in_customer_lane",
            "forwarded internal customer/vendor thread",
        )
    if risky_hits:
        return (
            "risky_promotional",
            "quarantine_candidate_keep_recoverable",
            ", ".join(risky_hits[:2]),
        )

    outreach_score = len(outreach_hits) * 2 + len(outreach_link_hits) * 2 + (2 if outreach_sender else 0)
    if outreach_score >= 4:
        basis_parts = []
        if outreach_sender:
            basis_parts.append("known_outreach_sender")
        basis_parts.extend(outreach_hits[:2])
        basis_parts.extend(outreach_link_hits[:2])
        return (
            "promotional",
            "hide_from_primary_lane_keep_recoverable",
            ", ".join(basis_parts[:3]),
        )

    if marketing_hits or sender.startswith("noreply@") or sender.startswith("no-reply@"):
        return (
            "promotional",
            "hide_from_primary_lane_keep_recoverable",
            ", ".join(marketing_hits[:2]) if marketing_hits else "noreply_sender",
        )

    return (
        "customer_or_operator",
        "review_in_customer_lane",
        "no_promotional_or_risky_markers",
    )
