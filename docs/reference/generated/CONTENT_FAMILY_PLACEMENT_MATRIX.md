---
status: generated
owner: "@operator"
scope: content-family-placement
---

# Content Family Placement Matrix

Generated from `ops/bindings/domains/media/content.family.placement.policy.yaml`.

| Family | Hot / Active | Stage | Hold | Archive | Rehydrate | Backup Primary | Backup Secondary | Blocking Dependencies |
|---|---|---|---|---|---|---|---|---|
| photos | `shop.photos.active` (canonical_active) | `shop.photos.active` (direct_import) | `photos.legacy.residue` (verify_then_tombstone) | `home.photos.archive` (keeper_archive) | `shop.photos.active` (in_place_active) | `shop.photos.backup.primary` (vm_primary) | undeclared | shop.photos.active, home.photos.archive, shop.photos.backup.primary, immich |
| media.movies | `home.media.movies.active` (canonical_active) | `home.media.stage` (bounded_stage) | `home.media.review` (operator_review) | `shop.media.movies.archive` (watched_aged_archive) | `home.media.movies.active` (return_to_hot_home) | `home.media.config_backup.primary` (service_config_primary) | `shop.media.config_backup.secondary` (service_config_secondary) | home.media.movies.active, home.media.stage, home.media.review, shop.media.movies.archive, home.media.config_backup.primary, shop.media.config_backup.secondary, media-home |
| media.tv | `home.media.tv.active` (canonical_active) | `home.media.stage` (bounded_stage) | `home.media.review` (operator_review) | `shop.media.tv.archive` (selective_pressure_archive) | `home.media.tv.active` (return_to_hot_home) | `home.media.config_backup.primary` (service_config_primary) | `shop.media.config_backup.secondary` (service_config_secondary) | home.media.tv.active, home.media.stage, home.media.review, home.media.config_backup.primary, shop.media.config_backup.secondary, media-home |
| media.music | `home.media.music.active` (canonical_active) | `home.media.stage` (bounded_stage) | `home.media.review` (operator_review) | `shop.media.music.archive` (selective_pressure_archive) | `home.media.music.active` (return_to_hot_home) | `home.media.config_backup.primary` (service_config_primary) | `shop.media.config_backup.secondary` (service_config_secondary) | home.media.music.active, home.media.stage, home.media.review, home.media.config_backup.primary, shop.media.config_backup.secondary, media-home |
| games | `shop.games.active` (planned_shop_primary) | `shop.games.stage` (planned_intake) | `shop.games.review` (planned_review) | `shop.games.archive` (planned_shop_archive) | `shop.games.active` (planned_return_to_shop_primary) | `shop.games.backup.primary` (planned_primary) | `shop.games.backup.secondary` (planned_secondary) | none |
