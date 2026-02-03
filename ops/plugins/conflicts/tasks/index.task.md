# TASK: Conflicts Index v0
MODE: SPINE
STAGE: RUN
OUTCOME: "Create a normalized conflicts dictionary and write it to plugins/conflicts/out/conflicts.json"

## REQUEST
You are building a conflicts lookup table for an agentic system.

Goal:
- Normalize the many words Ronny uses for the same thing (issue, mistake, incident, bug, drift, loop, etc.)
- Output MUST be valid JSON (no markdown, no commentary).

Schema:
{
  "version": "v0",
  "updated_utc": "<UTC ISO8601>",
  "groups": [
    {
      "group": "<short canonical name>",
      "meaning": "<one sentence meaning>",
      "signals": ["<strings>"],
      "aliases": ["<strings>"],
      "anti_aliases": ["<strings>"],
      "default_header": {
        "SESSION_TYPE": "SPINE",
        "MODE": "TALK",
        "PIPELINE_STAGE": "VERIFY",
        "DR": "<one-line DR that matches this group>"
      }
    }
  ]
}

Rules:
- 6 to 10 groups max.
- Include at least these canonical groups: AUTHORITY_CONFLICT, TOOLING_DRIFT, LOOPING, SECRETS_BREAK, PATH_CONFUSION, RECEIPT_MISSING.
- DR must be one line and actionable (e.g., "Stop. Run smoke. Identify single authority. Proceed.").
