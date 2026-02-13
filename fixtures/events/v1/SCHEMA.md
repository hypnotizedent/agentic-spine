# Fixture Event Schema (v1)

Defines valid header values for v1 fixture event files.

## Header Fields

Every fixture event file begins with a header block (no YAML front matter --
plain `KEY: VALUE` lines) followed by a markdown body.

| Field           | Required | Valid Values |
|-----------------|----------|-------------|
| AUDIENCE        | yes      | `SUPERVISOR` |
| MODE            | yes      | `ROUTE`, `EXECUTE`, `TRIAGE` |
| SESSION TYPE    | yes      | `SPINE` |
| PIPELINE STAGE  | yes      | `INTAKE`, `VERIFY`, `EXECUTE`, `CLOSEOUT` |
| HORIZON         | yes      | `NOW`, `NEXT`, `LATER` |
| OUTCOME         | yes      | Free-text string (quoted) describing expected result |

## Filename Convention

```
S<YYYYMMDD>-<HHMMSS>__<event_type>__R<seq>.md
```

- `S` prefix: fixture timestamp anchor
- `<event_type>`: snake_case event name (e.g., `email_received`, `spine_verify`)
- `R<seq>`: zero-padded 4-digit replay sequence number (e.g., `R0001`)

## Body Structure

After the header, each fixture has:

1. `## Event: <event_type>` heading
2. Metadata key-value pairs (bold key, value)
3. Context or payload block
4. `---` separator
5. Processing instructions (numbered list)

## Baseline Pairing

Each fixture event in `events/v1/` should have a corresponding baseline hash
in `fixtures/baseline/` with the same stem and a `.hash` extension.
