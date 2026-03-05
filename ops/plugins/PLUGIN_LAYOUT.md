# Plugin Layout Standard

Every plugin should use this shape:

```
ops/plugins/<plugin>/
  bin/      # executable entrypoints only
  lib/      # shared helpers for the plugin
  tests/    # plugin tests
  README.md # plugin contract and recovery notes
```

Rules:

1. One script per concern; use subcommands/flags instead of cloning files.
2. All new shell entrypoints must source `ops/lib/spine-paths.sh`.
3. `.legacy` files are forbidden.
4. New scripts must ship with at least one test in `tests/`.

