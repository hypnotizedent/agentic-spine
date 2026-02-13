# fixtures/n8n/

Exported n8n workflow JSON files used as governance templates.

## Contents

- `Spine_-_Mailroom_Enqueue.json`: n8n workflow template for enqueuing
  fixture events into the mailroom inbox. Used by `spine.replay` to inject
  deterministic test payloads.

## Usage

These JSON files can be imported into n8n via `ops cap run n8n.workflows.import`.
They are reference copies -- the live n8n instance is the runtime authority.
