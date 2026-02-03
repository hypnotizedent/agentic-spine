
## Explicitly Excluded (Config)

The following config surfaces are **out of scope** for /Code admission:

- mint-os/**  (application-level configs, dependency artifacts)
- node_modules/**
- vendor/**
- dist/**

Rationale:
These represent app internals, not operator or system truth.
