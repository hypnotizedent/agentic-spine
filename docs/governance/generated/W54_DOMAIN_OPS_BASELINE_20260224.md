# W54 Domain Ops Baseline (2026-02-24)

Task: `SPINE_BUILD_W54_DOMAIN_OPS_FACTORY`
Scope: normalization + governance + planning artifacts only (no live DNS/mail/registrar mutations).

## Baseline Commands and Results

| Command | Run Key | Status | Summary |
|---|---|---|---|
| `./bin/ops cap run session.start` | `CAP-20260224-124209__session.start__Rhxet51379` | done | fast startup complete; recommended domains: `core,hygiene-weekly` |
| `./bin/ops cap run domains.namecheap.status` | `CAP-20260224-124209__domains.namecheap.status__Rnpzx51378` | done | canonical domains inventoried (3 checked, 0 transferred) |
| `./bin/ops cap run cloudflare.status` | `CAP-20260224-124209__cloudflare.status__R7nny51380` | done | zones=3 (`mintprints.co=27`, `mintprints.com=23`, `ronny.works=44` records) |
| `./bin/ops cap run cloudflare.dns.status` | `CAP-20260224-124226__cloudflare.dns.status__R7nrc57081` | done | DNS counts match Cloudflare zone inventory |
| `./bin/ops cap run verify.core.run` | `CAP-20260224-124226__verify.core.run__Ro08x57082` | done | pass=15 fail=0 |
| `./bin/ops cap run verify.pack.run hygiene-weekly` | `CAP-20260224-124233__verify.pack.run__Rl8g562236` | failed | pass=59 fail=2 (`D162`, `D201`) |
| `./bin/ops cap run proposals.status` | `CAP-20260224-124226__proposals.status__R984r57083` | done | pending=0, SLA breaches=0 |

## Registrar Snapshot Highlights

- `mintprints.com`
  - nameservers: `nile.ns.cloudflare.com`, `rosemary.ns.cloudflare.com`
  - registrar_lock: `false`
  - expiry: `10/30/2026`
- `mintprints.co`
  - nameservers: `nile.ns.cloudflare.com`, `rosemary.ns.cloudflare.com`
  - registrar_lock: `false`
  - expiry: `04/26/2026`
- `ronny.works`
  - snapshot missing lock/nameserver/expiry fields (drives `D201` fail)

## Known Pre-Existing Baseline Failures

- `D162 operator-smoothness-lock`
  - stale calendar operator artifacts beyond freshness window.
- `D201 domain-registrar-parity-lock`
  - `ronny.works` missing `registrar_lock`, `nameservers`, `expiry_date` in Namecheap snapshot.

## W54 Planning Assumption State

Treat transfer state as `pending transfer initiated` for:
- `mintprints.com`
- `mintprints.co`
- `ronny.works`
