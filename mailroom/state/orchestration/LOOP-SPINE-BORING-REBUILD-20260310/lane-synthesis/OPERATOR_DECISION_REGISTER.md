# Operator Decision Register

| Surface | Current classification | Why unresolved | Conservative default |
|---|---|---|---|
| `.environment.yaml` / `.identity.yaml` | `needs-operator-decision` | Generated tenant/host state is checked into root, but the starter/foundation model wants templated bootstrap inputs instead. | Stop tracking host-specific values in spine. |
| `.mcp.json` | `needs-operator-decision` | Hardcoded private local runtimes and cross-repo paths make it unsuitable as-is for either boring spine or public starter. | Keep private and template later. |
| `.claude/settings.json` | `needs-operator-decision` | Local IDE hook with absolute repo path. | Keep private/local only. |
| `docs/CANONICAL/**` | `needs-operator-decision` | Files are authoritative by content but violate the declared canonical doc roots. | Do not promote further content there. |
| `docs/core/SPINE.md` | `needs-operator-decision` | Competes with `docs/governance/SPINE.md` for top-level authority. | Treat `docs/governance/SPINE.md` as canonical. |
| `ops/staged/**` | `needs-operator-decision` | Mixes authoritative language, reusable service source, and staging debt in one root. | Freeze new additions and extract service source to foundation. |
| `ops/gates/**` and `gates/**` | `needs-operator-decision` | Gate execution is split across multiple roots, undermining one obvious verify surface. | Keep `surfaces/verify/**` canonical. |
| `ops/agents/*.contract.md` | `foundation-source` leaning | Registry is the real machine-readable truth; prose contracts still contain active operator/domain material. | Move prose contracts out of spine core. |
| Root `STUB-*` files | `needs-operator-decision` | They represent real unresolved operator work, but top-level stubs are not a boring steady-state pattern. | Move into a governed decisions/closeout lane or clear them. |
| `docs/governance/domains/**` domain-heavy files | `foundation-source` leaning | Some are true control-plane docs, others are domain/operator authority better owned outside boring spine. | Keep only control-plane domains in spine. |

