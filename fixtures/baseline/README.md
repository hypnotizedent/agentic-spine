# fixtures/baseline/

Stored baseline output hashes for deterministic replay verification.

## Structure

Each baseline file corresponds to a fixture event in `fixtures/events/v1/`:

```
S<timestamp>__<event_type>__R<seq>.hash
```

The `.hash` file contains the SHA256 of the normalized expected output for
that fixture event. The replay test (`surfaces/verify/replay-test.sh`)
re-runs each fixture and compares the live output hash against the stored
baseline hash.

## Adding Output Payloads

When diagnosing replay failures, store the full output payload alongside
the hash file for replay diagnosis:

```
S<timestamp>__<event_type>__R<seq>.hash      # SHA256 hash (always present)
S<timestamp>__<event_type>__R<seq>.output     # Full output payload (optional, for diagnosis)
```

Output payloads enable diff-based diagnosis when a replay hash diverges
from baseline, without re-running the fixture to reproduce the failure.
