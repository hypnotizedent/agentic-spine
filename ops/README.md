# ops CLI

Install the governance helper into your PATH so each terminal session pulls the same checks.

```bash
ln -s "$HOME/code/agentic-spine/bin/ops" "$HOME/.local/bin/ops"
```

Once installed, run `ops preflight` to confirm governance hashes load, `ops start 540` to create a worktree, and `ops lane <builder|runner|clerk>` to see the lane headers.
