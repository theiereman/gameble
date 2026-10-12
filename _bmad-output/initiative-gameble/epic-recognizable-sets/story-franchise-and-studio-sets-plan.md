---
title: 'Franchise and studio sets'
type: 'feature'
ticket: '11'
created: '2026-10-12'
status: 'built'
baseline_revision: 'ae4ec1481d866d0b4c28b001955c3891f398b5e4'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Publication builds theme sets and the UFOs only. Players also recognize the games of a franchise and the games of a studio, and the import already keeps each card's developers and franchises.

**Approach:** At publication, `SetBuilder` also builds franchise and studio sets from the season's rows, with the filters the author agreed in the spike report. Each set gets a key, its display name in `params`, and one `complete` tier row. The library, public profile, card detail, routes and back-office list and name the two new kinds.

## Boundaries & Constraints

**Always:**
- Franchise sets:
  - the display name drops ™ ® © and a trailing " Franchise", " Series" or " - Official", case-insensitively;
  - names that differ only by case, punctuation or those suffixes make one set;
  - a set needs at least 3 games;
  - it is dropped when its display name, normalized like a studio name, equals the normalized name of any developer or publisher of the season's cards;
  - it is also dropped unless more than half of its games' English titles match its name. "Science Adventure" and "World of Darkness" are exempt from the title rule.
- Studio sets:
  - a game counts only under its first developer;
  - names are normalized: ™ ® ©, a platform in brackets ("(Mac)", "(Linux)"), trailing legal suffixes (Co., Ltd., Inc., LLC, GmbH, S.A., S.R.L., K.K., Corp., Corporation, Limited) and case are ignored;
  - a set needs at least 3 games, and its most-reviewed game needs at least 20,000 reviews (the card-season's `review_count`; nil counts as 0).
- A title matches a franchise name when:
  - they share a whole word that is not a stopword (the, of, and, a, an, in, on, game, games, simulator) and is at least 3 letters long, or is the name's only word; or
  - the name's words joined without separators equal a run of consecutive title words joined the same way ("Watch_Dogs", "Yu-Gi-Oh!").
- Words are lowercase letters and digits; apostrophes are removed first.
- Franchise and studio sets have one `complete` tier row (their size). Members are in release order, like the other kinds.
- A set's name comes from `params` ("franchise" or "studio"), never from its key. Tab and column names are in both `en.yml` and `fr.yml`.
- Once published, sets never change. The schema does not change.

**Never:**
- No hall of fame sets (entry 12).
- No rebuild of a published season.
- No change to the theme or UFO rules: a card in a franchise or studio set but in no theme set stays in the UFOs.
- No new screen design, no player tiers, no events.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior |
|----------|--------------|---------------------------|
| Franchise kept | 3 games of "Tom Clancy Franchise" titled "Tom Clancy's …" | set named "Tom Clancy", tier `complete` = 3 |
| Variants merged | "FINAL FANTASY" × 2, "Final Fantasy Series" × 1 | one set of 3; display name taken from the most frequent variant |
| Too small | franchise with 2 games | no set |
| Named like a company | franchise "Team17" over games developed by "Team17", or franchise "Team17 Digital" over games published by "Team17 Digital Ltd" (decision, author 2026-10-12: an equal normalized name only, no prefix match) | no set |
| Cross-promotion | "Estate Agent Simulator" over unrelated titles | no set ("simulator" is a stopword) |
| One short word | "Ys" over "Ys VIII", "Ys IX", "Ys Origin" | set "Ys" |
| Separator-free | "WatchDogs Franchise" over "Watch_Dogs", "Watch_Dogs 2", "Watch Dogs: Legion" | set "WatchDogs" |
| Exempt | "Science Adventure Series" over "Steins;Gate", "Chaos;Head", "Robotics;Notes" | set "Science Adventure" |
| Studio normalized | "CAPCOM Co., Ltd." × 2, "Capcom" × 1, one with 25,000 reviews | one studio set of 3 |
| Second developer | a game whose developers are ["Valve", "Feral Interactive (Mac)"] | counts for Valve only |
| Under the floor | studio of 5 games, its most-reviewed with 19,999 reviews | no set |
| Name without a URL-safe form | a franchise whose name has no Latin letter or digit | the set still gets a valid, unique key |

</frozen-after-approval>

## Code Map

- `packs/catalog/app/queries/catalog/season_rows.rb` -- `Row` gains `title` (the card's English title from `catalog_card_texts`, nil when there is none), `developers`, `franchises`, `publisher` and `review_count`. It stays one query: a LEFT JOIN on the `en` text. `PublishSeason` and `DraftPreview` both read it.
- `packs/catalog/app/models/catalog/set_builder.rb` -- add `franchises(rows)` and `studios(rows)`. `call` returns themes, franchises, studios, then the UFOs. Reuse `by_release`, and use `Themes::COMPLETE` for the tier.
- New `packs/catalog/app/models/catalog/set_names.rb` (or private helpers if they stay small) -- the franchise display name, company normalization, title words and the title match. Pure functions.
- `packs/catalog/app/models/catalog/set.rb` -- `BUILT_KINDS` adds `franchise studio` after `theme`. Update the header comment: franchise and studio sets are built now.
- `packs/catalog/app/operations/catalog/publish_season.rb` -- no logic change (`build_sets` is generic). Update the header comment only if it lists kinds.
- `packs/catalog/app/queries/catalog/draft_preview.rb:27-35` -- `set_counts` gains `"franchise"` and `"studio"` counts. `_preview.html.erb:141` already loops over the counts.
- `app/components/set_label.rb` -- `when "franchise"` → `params["franchise"]`, `when "studio"` → `params["studio"]`. Update the header comment.
- `config/routes.rb:25,39` -- the kind regex adds `franchise|studio`.
- `app/controllers/concerns/shelf_loading.rb:18` -- `KINDS = %w[theme franchise studio ufo tome publisher best_of_year]`.
- `packs/catalog/app/queries/catalog/season_shelf.rb:29` `EVERY_KIND_ORDER` and `card_detail.rb:34` `KIND_ORDER` -- the same order: theme, franchise, studio, ufo, then the retired kinds. Franchises and studios are ordered by key (the `BY_KEY` default).
- Locales, en + fr, each with `franchise` and `studio` entries:
  - `library.show.tabs`;
  - `library.show.empty`;
  - `public_profiles.show.empty`;
  - `back_office.seasons.index.sets` (en.yml ~410, 548, 554, 578).
- Tests and seeds:
  - `test/support/catalog_seeds.rb#seed_card_seasons` takes `developers:`, `franchises:`, `titles:` and `review_counts:`;
  - `db/seeds.rb` gives the dev cards a few franchises and developers, so both kinds show;
  - existing tests that list kinds, set counts or tabs follow the change (back-office index and preview, shelf, `set_label_test`, `season_scores`/`season_summaries`).
- Don't touch: `Game::SetCompletion`, `hub_sets.rb` (themes first, then by id, is fine), the theme list, migrations.

## Tasks & Acceptance

**Execution:**
- [ ] `season_rows.rb` -- widen `Row` and the pluck -- the builder needs titles, companies and review counts.
- [ ] `set_builder.rb` (+ `set_names.rb`) -- franchise and studio builders as in Boundaries. The key is the name's normalized form `parameterize`d; a name whose form is blank takes `"x-" + the first 12 hex digits of its SHA-256`. Sets with the same key merge. -- one rule for keys and merging.
- [ ] `set.rb`, `draft_preview.rb`, `set_label.rb`, `routes.rb`, `shelf_loading.rb`, `season_shelf.rb`, `card_detail.rb` -- list, order and name the new kinds.
- [ ] `config/locales/{en,fr}.yml` -- the keys above (fr: "Franchises", "Studios", and empty states in the back-office's register). `i18n-tasks` must be clean.
- [ ] Tests:
  - `set_builder_test` covers every row of the matrix;
  - `publish_season_test`: a draft with franchises and studios gets their sets, memberships and one `complete` tier row each;
  - `set_label_test`;
  - a library or profile controller test shows the Franchises and Studios tabs and names a set, in fr and en;
  - adapt the existing tests.
- [ ] `test/support/catalog_seeds.rb`, `db/seeds.rb` -- data for the above.

**Acceptance Criteria:**
- Given a published draft with franchise and studio data, when its sets are counted by kind, then franchise and studio sets exist, each with exactly one tier row `complete` = its member count.
- Given that season, when the library, a set page, a card's detail and a public profile render in French and in English, then the franchise and studio tabs and set names show.
- Given the change, then `bundle exec packwerk check`, `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bin/rubocop` and `bundle exec i18n-tasks missing`/`unused` pass.

## Implementation Notes

- `Catalog::SetNames` holds the pure naming rules: display names, the spaced `form` (keys) and the separator-free `merge_form` (grouping), company names, keys and the title match. Platform brackets accept a list ("(Mac/Linux)").
- `SetBuilder.named` groups by `merge_form`, keys each group from its most carried variant, then merges groups of equal key ("Pokémon" / "Pokemon"). A key falls back to `x-` + 12 hex digits of SHA-256 whenever a character does not transliterate.
- The company check of a franchise compares `company_form` of its display name against every developer and publisher of the season's rows (equality only, author's decision).
- `db/seeds.rb` gives the dev cards developers, review counts and two franchises (2 franchise sets, 4 studio sets); `db:seed` was not run, the rows were checked through the builder in a runner.
- Verification: `TZ=UTC bin/rails test` 2315 runs, 0 failures; `npm run test:js` 224 passed; packwerk, zeitwerk, rubocop (690 files), `i18n-tasks missing`/`unused` clean. In Europe/Paris two date tests fail across the 25 October DST change, independently of this change.

## Plan Change Log

## Review Triage Log

### 2026-10-12 — Review pass (quick)
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` Names differing only by punctuation inside a word ("Watch_Dogs" / "WatchDogs", "S.T.A.L.K.E.R." / "STALKER") get different keys and do not merge, against the Boundaries; reproduced in a runner. Grouping moves to the words joined without separators, the key comes from the chosen variant.
  - `[low]` `[patch]` A partly transliterable name keeps only its Latin or digit fragment ("ファイナルファンタジー 7" and "ドラゴンクエスト 7" both key `7`), so two unrelated sets merge, against the matrix's unique key. The digest now applies whenever a character does not transliterate.
  - `[low]` `[patch]` `PLATFORM` strips only one platform per bracket, so "Aspyr (Mac/Linux)" stays apart from "Aspyr". The regex now accepts a list of platforms.
- Matrix audit (before review): the "Named like a company" row was ambiguous against the equality rule; the author chose equality only (2026-10-12) and the row was reworded.

## Design Notes

- **Display name of a merged set:** the most frequent cleaned variant; on a tie, the alphabetically first. So "FINAL FANTASY" × 29 beats "Final Fantasy" × 2, and a studio shows "CAPCOM" (its legal suffix removed) or "Capcom", whichever more games carry.
- **Company check:** the cleaned franchise name goes through the same normalization as studio names. It is compared against every developer (not only the first) and every publisher of the season's rows, as the spike did.
- **Legal suffixes:** only trailing ones are removed, repeatedly ("Foo Co., Ltd." → "Foo"). Removing them anywhere, as the probe did, would eat words such as "Co" in "Co-op Studio".
- **Titles:** the English title is the one the spike matched (`name_en`). A card without an English text never matches.
