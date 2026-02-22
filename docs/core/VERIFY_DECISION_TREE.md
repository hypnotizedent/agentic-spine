# Verify Lane Decision Tree

## Which verify command do I run?

1. **Quick preflight (daily):** `./bin/ops cap run verify.core.run`
2. **After domain work:** `./bin/ops cap run verify.route.recommend` and run the suggested `verify.pack.run` target
3. **Release/nightly:** `./bin/ops cap run verify.release.run`

`verify.domain.run` is integration/debug only.
`verify.pack.run` is normally selected by `verify.route.recommend`.
