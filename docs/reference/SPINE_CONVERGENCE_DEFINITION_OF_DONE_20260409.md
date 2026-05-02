---
status: authoritative
owner: "@ronny"
last_verified: 2026-04-09
scope: spine-convergence-definition-of-done
---

# Spine Convergence Definition of Done

This document is the finish line for the extraction/convergence program that began on 2026-03-25.

Its job is simple:

- define what counts as **done**
- define what residue in spine is **acceptable by design**
- define what work is **not part of this program**
- stop future terminals from inventing new finish lines

This is a **spine** definition of done, not a universal workspace simplification doctrine.

## Core Rule

The spine is done when it is no longer the place where normal domain work has to happen.

That means:

- product and domain authority lives **outside** spine
- spine keeps only:
  - L1 engine surfaces
  - L2 shared rails/adapters
  - governed cross-domain capabilities
  - thin compatibility shims/seams
  - explicit host/runtime/platform residue that is intentionally shared

The exact off-spine home does **not** have to be the same for every domain.

For this program, a domain counts as extracted if its canonical authority lives in a truthful external home such as:

- `/Users/ronnyworks/code/mint-modules`
- `/Users/ronnyworks/code/communications-domain`
- `/Users/ronnyworks/code/media-domain`
- `/Users/ronnyworks/code/projects/home/agents/<domain>`
- another explicitly chosen external repo or workbench target

This prevents the finish line from moving every time repo topology is debated.

## Repo Roles

The intended steady-state roles are:

- `/Users/ronnyworks/code/agentic-spine`
  - kernel
  - governance
  - shared rails
  - verify/gates
  - compatibility shims/seams
- `/Users/ronnyworks/code/projects/home`
  - operator/domain operational truth
  - agent tooling
  - domain-local bindings/contracts
  - day-to-day domain surfaces
- `/Users/ronnyworks/code/mint-modules`
  - Mint product truth
- `/Users/ronnyworks/code/ronny-products`
  - incubator / parked / experimental products

Whether `/Users/ronnyworks/code/communications-domain`, `/Users/ronnyworks/code/media-domain`, or `/Users/ronnyworks/code/agentic-foundation` are later merged, archived, or narrowed is a **separate** architecture question. It is not required to call the spine program done.

## Done Means

The convergence program is complete only when all of the following are true.

### 1. Major extracted domains are no longer authoritative in spine

These domains already count as extracted if their off-spine homes remain canonical and spine only carries shims/seams/shared rails:

- Mint
- communications
- media

### 2. Remaining small domains leave spine or are explicitly classified as shared-platform residue

The remaining small domains are:

- calendar
- home
- immich
- finance
- n8n

For each one, exactly one of these must be true:

- it is extracted to a truthful off-spine home
- it is explicitly classified as intentional shared/platform residue with a written reason

Silently leaving full domain implementations in spine does **not** count as done.

### 3. Normal domain work no longer requires spine edits

If a future terminal doing ordinary domain work on Mint, communications, media, finance, immich, n8n, calendar, or home still has to edit spine domain code as the normal path, the program is not done.

Allowed exception:

- intentional shared rails and platform-owned capabilities

### 4. Spine residue is explicit, not accidental

A file may remain in spine only if it is one of:

- L1 engine
- L2 shared adapter
- governed cross-domain capability
- host/runtime rail
- verify rail
- compatibility shim
- compatibility seam

Every remaining domain-looking surface in spine must have an explicit reason it still exists.

### 5. Shared rails are treated as finished residue, not extraction debt

The following kinds of surfaces are acceptable to remain in spine once classified:

- media shared rails
  - `d257`
  - `d420`
  - `g4`
  - `media-nfs-verify`
  - content-family helpers
  - capacity snapshot/reconcile chain
- communications shared/runtime rails
  - `g11`
  - `d222`
  - `d233`
  - alerts dispatcher worker
  - alerts runtime status
  - send preview
  - send execute
  - mail-archiver import monitor
- operator-storage shared rails
- provider rails
- host launchd rails

Once a surface has been classified into this bucket, it is no longer extraction backlog.

### 6. Spine remains operationally clean

At finish:

- `ops verify --engine-smoke` passes
- runtime is `0` active / `0` orphaned waves
- the extracted domains continue to resolve through truthful shims/seams

### 7. Future work changes category

When this program is done, any remaining work touching spine must be framed as one of:

- platform rail redesign
- shared capability redesign
- governance cleanup
- host/runtime/launchd cleanup
- repo-topology simplification outside the spine program

It is no longer valid to frame that work as “keep extracting domains from spine.”

## Explicit Non-Goals

The following are **not** required to call this program done:

- deleting every stale or ugly projection file
- removing every product-looking reference from `routing.dispatch.yaml`
- removing every product-looking entry from `capability_map.yaml`
- eliminating every deprecated shim
- merging `communications-domain` into workbench
- merging `media-domain` into workbench
- merging or deleting `agentic-foundation`
- redesigning all gates to be perfectly domain-agnostic
- making the repo tree aesthetically minimal

Those may be worthwhile later. They are not the finish line for this program.

## Accepted Residue Rule

A terminal may leave a surface in spine if and only if it can say, plainly:

- who still calls it
- why that caller is platform/shared rather than domain-local
- why leaving it in spine is intentional

If it cannot answer those three questions, the surface is still backlog.

## Stop Rule

Stop opening new extraction waves once all of the following are true:

- Mint, communications, and media are canonical outside spine
- finance, n8n, and immich are extracted or explicitly classified
- calendar has an explicit landing-zone decision
- home is either extracted or explicitly retained because of calendar/platform coupling
- no new domain work requires ordinary edits inside spine

At that point, the spine program is over.

Do not keep polishing.
Do not keep re-auditing for aesthetic purity.
Do not reopen extraction because a projection is ugly.

## Current Status Against This Definition

As of 2026-04-09 (updated end-of-day):

- all criteria satisfied:
  - Mint extracted
  - communications extracted
  - media extracted
  - finance extracted to `projects/finance` (supersedes prior workbench staging)
  - n8n extracted to `projects/n8n` (spine `704a7745`)
  - immich extracted to `projects/immich` (spine `704a7745`)
  - calendar landing zone decided (standalone domain) and extracted to `workbench/agents/calendar` (spine `7699a338`)
  - home extracted to `projects/home/tools/spine-plugin-home` (spine `d5d1fa22`)
  - shared communications/media/operator-storage rails classified
  - spine operational health clean (engine smoke 5/5, waves 0/0)

The convergence program is **done**. The stop rule is satisfied.

## Remaining Required Work

None. All extraction criteria are met. Future spine work is platform/governance/shared-rail work, not extraction.

## Terminal Rule

Any terminal touching spine after this document exists must be held to this:

- if the work moves the spine toward the criteria above, it belongs to the convergence program
- if it does not, it must be justified as platform/shared-rail/governance work
- if it is merely cleanup without changing the done criteria, defer it

This document is the cap.
