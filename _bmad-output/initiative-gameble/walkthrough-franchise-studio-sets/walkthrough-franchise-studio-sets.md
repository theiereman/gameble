# Walkthrough: franchise and studio sets

Target: commit 666f06b (`feat(catalog): publication builds franchise and studio sets, named on every screen that shows sets`). Plan: [story-franchise-and-studio-sets-plan.md](../epic-recognizable-sets/story-franchise-and-studio-sets-plan.md).

Current block: none — review done

## [x] 1. Intent — done

Source: the plan's frozen Intent section, verbatim.

**Problem:** Publication builds theme sets and the UFOs only. Players also recognize the games of a franchise and the games of a studio, and the import already keeps each card's developers and franchises.

**Approach:** At publication, `SetBuilder` also builds franchise and studio sets from the season's rows, with the filters the author agreed in the spike report. Each set gets a key, its display name in `params`, and one `complete` tier row. The library, public profile, card detail, routes and back-office list and name the two new kinds.

## [x] 2. Broad strokes — done

Publication now runs two more pure builders over the season's rows; naming rules live in one new module, and the screens learn two new kinds. Open in order:

1. [set_builder.rb:18](../../../packs/catalog/app/models/catalog/set_builder.rb#L18) — `SetBuilder.call`: themes, franchises, studios, then the UFOs.
2. [set_builder.rb:40](../../../packs/catalog/app/models/catalog/set_builder.rb#L40) — `franchises` and `studios`: grouping, filters, one `complete` tier.
3. [set_names.rb:41](../../../packs/catalog/app/models/catalog/set_names.rb#L41) — `SetNames`: display names, forms, keys, the title match.
4. [season_rows.rb:17](../../../packs/catalog/app/queries/catalog/season_rows.rb#L17) — `SeasonRows::Row` now carries title, developers, franchises, publisher, review count.
5. [set_label.rb:27](../../../app/components/set_label.rb#L27) — how a franchise or studio set is named on screen.

## [x] 3. Rows carry what the builders need — done

`SeasonRows` stays one query: a LEFT JOIN on the card's `en` text adds the English title, and the pluck adds the card's developers, franchises and publisher plus the card-season's review count. `PublishSeason` and `DraftPreview` both read these rows, so the back-office preview counts the same sets publication would build.

- [season_rows.rb:17](../../../packs/catalog/app/queries/catalog/season_rows.rb#L17) — the widened `Row`.
- [season_rows.rb:20](../../../packs/catalog/app/queries/catalog/season_rows.rb#L20) — the English text join.
- [season_rows.rb:30](../../../packs/catalog/app/queries/catalog/season_rows.rb#L30) — the pluck.

## [x] 4. Naming rules — done

`SetNames` holds pure functions. A franchise's display name drops ™ ® © and a trailing " Franchise", " Series" or " - Official"; a company's drops platform brackets (one or several platforms) and trailing legal suffixes. Two normal forms coexist: `form` (words joined by spaces, used for readable keys) and `merge_form` (words joined with no separator, used to group "Watch_Dogs" with "WatchDogs"). A key is the form parameterized, or `x-` and 12 hex digits of a SHA-256 when any character does not transliterate. A title matches a name through a shared significant word, or through a run of title words that, joined, equals the name joined.

- [set_names.rb:28](../../../packs/catalog/app/models/catalog/set_names.rb#L28) — the constants: marks, suffixes, platforms, legal suffixes, stopwords, exemptions.
- [set_names.rb:45](../../../packs/catalog/app/models/catalog/set_names.rb#L45) — `form` and `merge_form`.
- [set_names.rb:53](../../../packs/catalog/app/models/catalog/set_names.rb#L53) — `company` and `company_form`.
- [set_names.rb:61](../../../packs/catalog/app/models/catalog/set_names.rb#L61) — `key` and its digest fallback.
- [set_names.rb:72](../../../packs/catalog/app/models/catalog/set_names.rb#L72) — `title_matches?`, with `shares_word?` and `holds_run?` below.

## [x] 5. Franchise and studio builders — done

`named` groups the names a block gives each row by `merge_form`, keys each group from its most carried variant, then merges groups whose keys are equal. Franchises keep groups of at least 3 games whose name is no developer or publisher of the season (equal normalized name only) and whose English titles match the name for more than half of the games, Science Adventure and World of Darkness excepted. Studios count each game under its first developer and need 3 games and a most-reviewed game of 20,000 reviews. Every such set has members in release order and one `complete` tier.

- [set_builder.rb:40](../../../packs/catalog/app/models/catalog/set_builder.rb#L40) — `franchises`.
- [set_builder.rb:50](../../../packs/catalog/app/models/catalog/set_builder.rb#L50) — `studios`.
- [set_builder.rb:70](../../../packs/catalog/app/models/catalog/set_builder.rb#L70) — `named` and `most_carried`.
- [set_builder.rb:90](../../../packs/catalog/app/models/catalog/set_builder.rb#L90) — `named_in_titles?` and `complete_only`.

## [x] 6. Screens list and name the new kinds — done

A franchise or studio set is named from `params`, never from its key. The kinds take their place after themes and before the UFOs everywhere an order of kinds exists: tabs, the "Started" shelf, a card's sets. Routes accept the two kinds, and the back-office counts them.

- [set_label.rb:27](../../../app/components/set_label.rb#L27) — names from `params["franchise"]` and `params["studio"]`.
- [shelf_loading.rb:18](../../../app/controllers/concerns/shelf_loading.rb#L18) — tab order.
- [routes.rb:25](../../../config/routes.rb#L25) and [routes.rb:39](../../../config/routes.rb#L39) — kind constraints.
- [season_shelf.rb:31](../../../packs/catalog/app/queries/catalog/season_shelf.rb#L31) — order of kinds on the shelf of every kind.
- [card_detail.rb:34](../../../packs/catalog/app/queries/catalog/card_detail.rb#L34) — order of a card's sets.
- [set.rb:26](../../../packs/catalog/app/models/catalog/set.rb#L26) — `BUILT_KINDS`, the back-office columns.
- [draft_preview.rb:28](../../../packs/catalog/app/queries/catalog/draft_preview.rb#L28) — the preview's set counts.

## [x] 7. Tests — done

The naming rules and every row of the plan's matrix are unit-tested; publication, the library, a set page, a card's detail and a public profile are checked in French and English.

- [set_names_test.rb](../../../test/packs/catalog/set_names_test.rb) — naming rules.
- [set_builder_test.rb](../../../test/packs/catalog/set_builder_test.rb) — the matrix, merges, keys, the 15,000-row run.
- [publish_season_test.rb](../../../test/packs/catalog/publish_season_test.rb) — sets, memberships, one `complete` tier each.
- [library_controller_test.rb](../../../test/controllers/library_controller_test.rb), [library_set_test.rb](../../../test/controllers/library_set_test.rb), [public_profiles_controller_test.rb](../../../test/controllers/public_profiles_controller_test.rb), [cards_controller_test.rb](../../../test/controllers/cards_controller_test.rb) — screens in fr and en.

## [x] 8. Periphery — done

- [en.yml:412](../../../config/locales/en.yml#L412) and [fr.yml:417](../../../config/locales/fr.yml#L417) — back-office columns; tabs and empty states follow further down in both files.
- [catalog_seeds.rb](../../../test/support/catalog_seeds.rb) — test seeds take titles, developers, franchises and review counts.
- [seeds.rb:10](../../../db/seeds.rb#L10) — dev cards get franchises and studios.
- [draft_preview_test.rb](../../../test/packs/catalog/draft_preview_test.rb), [season_scores_test.rb](../../../test/packs/catalog/season_scores_test.rb), [seasons_controller_test.rb](../../../test/controllers/back_office/seasons_controller_test.rb), [set_label_test.rb](../../../test/components/set_label_test.rb) — follow the new kinds.
