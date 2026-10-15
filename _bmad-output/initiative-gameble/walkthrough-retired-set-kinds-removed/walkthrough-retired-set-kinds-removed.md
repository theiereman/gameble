# Walkthrough: the retired set kinds removed

Target: commit `046fb0c` on `develop`. Plan: [story-the-published-season-gets-its-new-sets-once-plan.md](../epic-recognizable-sets/story-the-published-season-gets-its-new-sets-once-plan.md). Log: [walkthrough-retired-set-kinds-removed-log.md](walkthrough-retired-set-kinds-removed-log.md).

Current block: none — every block accepted.

## [x] 1. Intent (accepted)

Pasted verbatim from the plan's Intent section.

> **Problem:** Staging's season 1 still holds tomes, publisher sets and best-of-year sets, with their completions. Because of them, the set kind check keeps the three retired kinds, and their code lives on in the model, the labels, the routes, the shelf, the back-office and about 20 tests. Season 2 is themed and published, so those sets earn no tier and show only on season 1's own card pages.
>
> **Approach:** One migration deletes the retired sets in every season, together with their memberships, tiers and completion rows. A second migration narrows the kind check to the five kinds, unvalidated, and a third validates it. The retired-kind code, fixtures and tests go.
>
> **Decision (author, 2026-10-15):** no rebuild of season 1. Its card-seasons keep no set and no main theme. AD-5 and AD-10 are amended.

## [x] 2. Broad strokes (accepted)

Three migrations clear the data and tighten the database; the code then knows only five kinds. Open in this order:

1. [db/migrate/20261015130000_delete_retired_set_kinds.rb:4](../../../db/migrate/20261015130000_delete_retired_set_kinds.rb#L4) — the data delete, in foreign-key order.
2. [db/migrate/20261015130001_narrow_catalog_sets_kind_check.rb:2](../../../db/migrate/20261015130001_narrow_catalog_sets_kind_check.rb#L2) — the check narrowed to five kinds, then validated by the next migration.
3. [packs/catalog/app/models/catalog/set.rb:19](../../../packs/catalog/app/models/catalog/set.rb#L19) — the enum, now the single list of kinds.
4. [app/components/set_label.rb:14](../../../app/components/set_label.rb#L14) — set names without the tome, publisher and best-of-year branches.
5. [test/packs/catalog/delete_retired_set_kinds_migration_test.rb:70](../../../test/packs/catalog/delete_retired_set_kinds_migration_test.rb#L70) — the migrations run against a retired season and a themed one.

## [x] 3. The data delete (accepted)

One irreversible migration deletes, by subquery on the retired kinds, the completion rows, then memberships, tiers and sets. `game_set_completions` has no foreign key, so it goes first by set id; the other three follow the foreign keys, which have no `ON DELETE`. Nothing else references `catalog_sets`, so holdings, card-seasons, feed entries and unlocks stay.

- [db/migrate/20261015130000_delete_retired_set_kinds.rb:2](../../../db/migrate/20261015130000_delete_retired_set_kinds.rb#L2) — the subquery.
- [db/migrate/20261015130000_delete_retired_set_kinds.rb:13](../../../db/migrate/20261015130000_delete_retired_set_kinds.rb#L13) — `down` raises.

## [x] 4. The kind check narrowed (unvalidated, then validated) (accepted)

The check is replaced under the same name with the five kinds as equalities, unvalidated, so the swap does not scan the table; the next migration validates it. Because the delete runs first, the validation passes on staging in the same deploy.

- [db/migrate/20261015130001_narrow_catalog_sets_kind_check.rb:3](../../../db/migrate/20261015130001_narrow_catalog_sets_kind_check.rb#L3) — remove the eight-kind check, add the five-kind one.
- [db/migrate/20261015130002_validate_narrowed_catalog_sets_kind_check.rb:3](../../../db/migrate/20261015130002_validate_narrowed_catalog_sets_kind_check.rb#L3) — validation.
- [db/schema.rb:164](../../../db/schema.rb#L164) — the only schema change.

## [x] 5. The domain knows five kinds (accepted)

The enum loses the retired kinds and `BUILT_KINDS` goes: `Set.kinds.keys`, in tab order, is the one list the counts and the back-office read.

- [packs/catalog/app/models/catalog/set.rb:19](../../../packs/catalog/app/models/catalog/set.rb#L19) — enum.
- [packs/catalog/app/queries/catalog/season_summaries.rb:25](../../../packs/catalog/app/queries/catalog/season_summaries.rb#L25), [packs/catalog/app/queries/catalog/season_scores.rb:37](../../../packs/catalog/app/queries/catalog/season_scores.rb#L37), [app/views/back_office/seasons/index.html.erb:26](../../../app/views/back_office/seasons/index.html.erb#L26) — readers of the kinds.

## [x] 6. Screens, orders and routes (accepted)

Labels, tab lists, SQL orderings and route constraints drop the three retired kinds. `SetLabel.heading`, which only added a tome's year range, goes with its one caller switched to `SetLabel.for`. A season-1 card page now finds no set and shows neither sets nor genre; an old `/library/tome/...` URL no longer matches a route (404).

- [app/components/set_label.rb:14](../../../app/components/set_label.rb#L14) — names.
- [app/views/public_profiles/set.html.erb:24](../../../app/views/public_profiles/set.html.erb#L24) — the former `heading` caller.
- [app/controllers/concerns/shelf_loading.rb:17](../../../app/controllers/concerns/shelf_loading.rb#L17) — tab kinds.
- [config/routes.rb:26](../../../config/routes.rb#L26), [config/routes.rb:39](../../../config/routes.rb#L39) — route constraints.
- [packs/catalog/app/queries/catalog/season_shelf.rb:26](../../../packs/catalog/app/queries/catalog/season_shelf.rb#L26), [packs/catalog/app/queries/catalog/season_shelf.rb:31](../../../packs/catalog/app/queries/catalog/season_shelf.rb#L31) — shelf orders.
- [packs/catalog/app/queries/catalog/card_detail.rb:39](../../../packs/catalog/app/queries/catalog/card_detail.rb#L39) — card detail's kind order.

## [x] 7. Locales (accepted)

Both locale files lose the same keys: the tome, best-of-year and year-range names, the retired tabs and empty states, and the whole `catalog.genres` block the tomes named themselves with.

- [config/locales/en.yml](../../../config/locales/en.yml), [config/locales/fr.yml](../../../config/locales/fr.yml) — 72 lines removed each.

## [x] 8. Tests (accepted)

A new migration test widens the check, seeds a retired season 1 and a themed season 2 with completions, holdings, a feed entry and an unlock, runs the three migrations and checks that only the retired rows go; a second case runs them on a database with no retired set; a third checks the delete is irreversible. The rest are adapted: the fixture `valve_one` became a studio set keeping the label "Valve", so most tests changed only a kind or a URL; cases that tested a retired kind for its own sake were removed.

- [test/packs/catalog/delete_retired_set_kinds_migration_test.rb:70](../../../test/packs/catalog/delete_retired_set_kinds_migration_test.rb#L70) — worked example.
- [test/fixtures/catalog/sets.yml:4](../../../test/fixtures/catalog/sets.yml#L4) — `valve_one`.
- [test/packs/catalog/schema_test.rb:117](../../../test/packs/catalog/schema_test.rb#L117) — the database refuses the retired kinds.
- [test/controllers/library_set_test.rb:258](../../../test/controllers/library_set_test.rb#L258) — old URL, 404.
- [test/controllers/cards_controller_test.rb:389](../../../test/controllers/cards_controller_test.rb#L389) — season-1 card page with no set and no genre.
- Same treatment (kind or URL swapped, retired cases dropped): [set_label_test.rb](../../../test/components/set_label_test.rb), [seasons_controller_test.rb](../../../test/controllers/back_office/seasons_controller_test.rb), [card_preview_tags_test.rb](../../../test/controllers/card_preview_tags_test.rb), [library_controller_test.rb](../../../test/controllers/library_controller_test.rb), [pages_controller_test.rb](../../../test/controllers/pages_controller_test.rb), [public_profiles_controller_test.rb](../../../test/controllers/public_profiles_controller_test.rb), [player_export_test.rb](../../../test/models/player_export_test.rb), [card_detail_test.rb](../../../test/packs/catalog/card_detail_test.rb), [collection_grid_test.rb](../../../test/packs/catalog/collection_grid_test.rb), [draft_preview_test.rb](../../../test/packs/catalog/draft_preview_test.rb), [season_scores_test.rb](../../../test/packs/catalog/season_scores_test.rb), [season_shelf_test.rb](../../../test/packs/catalog/season_shelf_test.rb), [set_neighbours_test.rb](../../../test/packs/catalog/set_neighbours_test.rb), [set_slots_test.rb](../../../test/packs/catalog/set_slots_test.rb), [collection_summary_test.rb](../../../test/packs/game/collection_summary_test.rb), [export_of_test.rb](../../../test/packs/game/export_of_test.rb), system [card_detail_test.rb](../../../test/system/card_detail_test.rb), [collection_set_test.rb](../../../test/system/collection_set_test.rb) (renamed from `tome_test.rb`), [public_profile_test.rb](../../../test/system/public_profile_test.rb).

## [x] 9. Periphery (accepted)

- [packs/game/lib/open_pack_benchmark.rb:181](../../../packs/game/lib/open_pack_benchmark.rb#L181) — the benchmark seeds studio sets instead of publisher sets.
- [app/frontend/lib/history_trail.test.ts:17](../../../app/frontend/lib/history_trail.test.ts#L17) — a sample URL moved off `tome`.
- [config/i18n-tasks.yml:23](../../../config/i18n-tasks.yml#L23) — `catalog.genres.*` no longer ignored.
- [architecture-gameble.md](../architecture-gameble/architecture-gameble.md) — AD-5 and AD-10 amended.
- [epic-recognizable-sets.md](../epic-recognizable-sets/epic-recognizable-sets.md), [tickets.toml](../epic-recognizable-sets/tickets.toml) — R10, the decision note, entry 4 rewritten.
- [deferred-work.md](../deferred-work.md) — the pre-existing `rate_limit.*` unused keys.
