# CLI (Subordinate / Non-Authoritative)

Canonical entrypoint is `bin/ops`.

This CLI (`bin/cli/bin/spine`) is an internal agent runtime interface.
It must not become a second system or be treated as authoritative.

## Usage

For human operators: use `bin/ops` commands.
For agent runtime: `bin/cli/bin/spine` may be used internally.
