---
status: generated
owner: "@ronny"
scope: content-family-decommission-readiness
---

# Content Family Decommission Readiness

Generated from `/Users/ronnyworks/code/projects/media/bindings/content.family.placement.policy.yaml` and the linked lifecycle/closure surfaces.

| Plane | Type | Required By | Optional Only | Planned Only | Residual Only | Safe Now? | Blocking Dependencies | Required Preconditions |
|---|---|---|---|---|---|---|---|---|
| download-stack | service_plane | none | media.movies, media.music, media.tv | none | yes | no | service.data.lifecycle.registry still references plane: media:allowed_secondary_roots:download-stack:/mnt/media<br>services.health still enables probes on plane: download-node-exporter<br>media.services still marks plane active for: watchtower-download, download-node-exporter<br>service.closure.contract still lists plane as residual source: media-home-public-closure:residual_source_policy.residual_hosts | none |
| streaming-stack | service_plane | none | media.movies, media.music, media.tv | none | yes | yes | none | none |
