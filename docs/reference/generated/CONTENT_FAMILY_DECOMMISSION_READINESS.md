---
status: generated
owner: "@ronny"
scope: content-family-decommission-readiness
---

# Content Family Decommission Readiness

Generated from `ops/bindings/content.family.placement.policy.yaml` and the linked lifecycle/closure surfaces.

| Plane | Type | Required By | Optional Only | Planned Only | Residual Only | Safe Now? | Blocking Dependencies | Required Preconditions |
|---|---|---|---|---|---|---|---|---|
| download-stack | service_plane | none | media.movies, media.music, media.tv | none | yes | no | service.data.lifecycle.registry still references plane: media:allowed_secondary_roots:download-stack:/mnt/media<br>services.health still enables probes on plane: download-node-exporter<br>media.services still marks plane active for: watchtower-download, download-node-exporter<br>service.closure.contract still lists plane as residual source: media-home-public-closure:residual_source_policy.residual_hosts | media-home 14-day stability window (target: 2026-04-02)<br>shop archive drain not yet approved |
| streaming-stack | service_plane | none | media.movies, media.music, media.tv | none | yes | no | none | media-home 14-day stability window (target: 2026-04-02)<br>shop archive drain not yet approved |
