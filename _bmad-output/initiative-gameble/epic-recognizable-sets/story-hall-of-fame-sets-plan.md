---
title: 'Hall of fame sets'
type: 'feature'
ticket: '12'
created: '2026-10-12'
status: 'built'
baseline_revision: '1b5213d0d606cb291440982bf8b013bede252eef'
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

**Problem:** Publication builds theme, franchise, studio and UFO sets, but not the four hall of fame sets the spec names. Those sets reward the games players know from their reviews.

**Approach:** At publication, `SetBuilder` builds the four hall of fame sets from each card-season's frozen `rating` and `review_count`, using the thresholds the author agreed. Each set has a fixed key, its key in `params`, and bronze, silver, gold and complete tier rows like a theme. Names come from `en.yml` and `fr.yml`. The library, public profile, card detail, routes and back-office list and name the kind.

## Boundaries & Constraints

**Always:**
- The four sets, keys and rules (bounds inclusive unless "under"):

  | Key | Rule |
  |---|---|
  | `intouchables` | rating ≥ 97 and review count ≥ 20,000 |
  | `pepites` | rating ≥ 98 and review count under 1,000 |
  | `mal-aimes` | rating 40 to 69 and review count ≥ 20,000 |
  | `phenomenes` | review count ≥ 200,000 |

- A card-season without a review count is in none of them. A card can be in several.
- Names:

  | Key | fr | en |
  |---|---|---|
  | `intouchables` | Les Intouchables | The Untouchables |
  | `pepites` | Les Pépites | Hidden Gems |
  | `mal-aimes` | Les Mal-aimés | The Unloved |
  | `phenomenes` | Les Phénomènes | The Phenomena |

- Tiers: the same as a theme's (`Themes.tiers`: bronze 10 %, silver 25 %, gold 50 %, rounded up, plus `complete`). Members are in release order.
- A set that selects no card is not built.
- Kind order everywhere kinds are ordered: theme, franchise, studio, hall_of_fame, ufo, then the retired kinds. Within the kind, sets follow the table's order.
- Once published, sets never change. The schema does not change.

**Never:**
- No rebuild of a published season (entry 4).
- No player tiers, events or celebration (entries 5, 6).
- No change to theme, franchise, studio or UFO rules: a hall of fame card of no theme stays in the UFOs.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior |
|----------|--------------|---------------------------|
| Exactly at the thresholds | 97 % and 20,000 reviews; 98 % and 999; 69 % and 20,000; 40 % and 20,000; 200,000 reviews | in Intouchables, Pépites, Mal-aimés, Mal-aimés, Phénomènes respectively |
| Just outside | 96 % and 50,000; 98 % and 1,000; 70 % and 20,000; 39 % and 20,000; 199,999 | in none of the matching sets |
| Two sets | 98 % and 250,000 reviews | in Intouchables and Phénomènes |
| No review count | rating 99, `review_count` nil | in no hall of fame set |
| Empty selection | a draft with no game at 200,000 reviews | no `phenomenes` set; the other three are built |
| Tiers | a set of 30 cards | bronze 3, silver 8, gold 15, complete 30 |
| Names | the set `pepites` in fr and en | "Les Pépites" / "Hidden Gems" |

</frozen-after-approval>

## Code Map

- New `packs/catalog/app/models/catalog/hall_of_fame.rb` -- the four keys in order, each with its rule as a predicate on a `SeasonRows::Row` (`rating` is a percent BigDecimal, Steam's whole percent; `review_count` may be nil). Pure; it holds the thresholds.
- `packs/catalog/app/models/catalog/set_builder.rb` -- `hall_of_fame(rows)`: one set per key with members, `params: { "hall_of_fame" => key }`, `tiers: Themes.tiers(size)`. `call` becomes themes, franchises, studios, hall of fame, then the UFOs. Reuse `by_release`.
- `packs/catalog/app/models/catalog/set.rb:26` -- `BUILT_KINDS` adds `hall_of_fame` after `studio`; update the header comment, which says hall of fame sets have no builder yet.
- `packs/catalog/app/queries/catalog/draft_preview.rb:28-35` -- `set_counts` gains `"hall_of_fame"`.
- `app/components/set_label.rb` -- `when "hall_of_fame"` → `I18n.t(params["hall_of_fame"], scope: "catalog.hall_of_fame")`; raise ArgumentError when the param is blank, like a theme set.
- Kind lists:
  - `config/routes.rb:25,39`: the regex adds `hall_of_fame`;
  - `app/controllers/concerns/shelf_loading.rb:18` `KINDS`;
  - `packs/catalog/app/queries/catalog/season_shelf.rb` `EVERY_KIND_ORDER`, plus an `ORDER["hall_of_fame"]` that follows `HallOfFame`'s key order (a SQL `CASE` built from the keys) and is reused by `EVERY_KIND_ORDER`;
  - `packs/catalog/app/queries/catalog/card_detail.rb:34` `KIND_ORDER`.
- Locales, en + fr:
  - `catalog.hall_of_fame.<key>` (4 entries);
  - `hall_of_fame` in `library.show.tabs` ("Hall of fame" / « Panthéon »), `library.show.empty`, `public_profiles.show.empty` and `back_office.seasons.index.sets`.
  - `i18n-tasks` cannot see the dynamic `catalog.hall_of_fame.*` keys; add them to its ignore-unused list, as `catalog.themes.*` is in `config/i18n-tasks.yml`.
- Tests and seeds:
  - `test/support/catalog_seeds.rb`: `seed_card_seasons` already takes `ratings:` and `review_counts:`;
  - `db/seeds.rb`: give a few dev cards counts and ratings that fill each set;
  - adapt the tests that list kinds or set counts (back-office index and preview, `draft_preview_test`, `season_scores_test`, `set_label_test`).
- Don't touch: `Themes`, `SetNames`, the franchise and studio builders, `hub_sets.rb`, migrations.

## Tasks & Acceptance

**Execution:**
- [x] `hall_of_fame.rb`, `set_builder.rb` -- the rules and the builder, as above.
- [x] `set.rb`, `draft_preview.rb`, `set_label.rb`, `routes.rb`, `shelf_loading.rb`, `season_shelf.rb`, `card_detail.rb` -- list, order and name the kind.
- [x] `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml` -- the keys above; `i18n-tasks missing` and `unused` clean.
- [x] Tests:
  - `set_builder_test` covers every row of the matrix;
  - `publish_season_test`: a draft gets the hall of fame sets, their memberships and four tier rows each;
  - `set_label_test` in fr and en;
  - a library or profile controller test shows the hall of fame tab and names a set in fr and en;
  - adapt the existing tests.
- [x] `db/seeds.rb` -- data for the dev season.

**Acceptance Criteria:**
- Given a published draft with ratings and review counts, when its sets are counted by kind, then hall of fame sets exist with the cards their rules select, each with bronze, silver, gold and complete rows.
- Given that season, when the library, a set page, a card's detail and a public profile render in French and English, then the hall of fame tab and set names show.
- Given the change, then `bundle exec packwerk check`, `TZ=UTC bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bin/rubocop` and `bundle exec i18n-tasks missing`/`unused` pass.

## Implementation Notes

- `SeasonShelf::HALL_OF_FAME_ORDER` is a SQL `CASE` built from `HallOfFame.keys`, guarded on the kind; `ORDER["hall_of_fame"]` (then by key), `EVERY_KIND_ORDER` and `CardDetail` (after `KIND_ORDER`, before key) all use it, so hall of fame sets follow the table's order everywhere and a key outside `HallOfFame` falls back to key order.
- The test draft `seed_hall_of_fame_draft` (`test/support/catalog_seeds.rb`) has 24 cards: 8 cards cannot fill the five rarities and publication fails with `empty_tier`.
- The back-office seasons intro now names hall of fame sets among what publication builds (en and fr).
- Dev seeds: every fifteenth card is 98 % with 500 reviews, every twelfth has 250,000 reviews; the 60-card season builds Intouchables 3, Pépites 4, Mal-aimés 11, Phénomènes 4 (checked by running `SetBuilder` on the same rows, not by seeding the dev database).

## Plan Change Log

## Review Triage Log

| Lens | Finding | Verdict | Evidence | Route |
|---|---|---|---|---|
| quick | `set_label.rb`: a hall of fame key missing from the locales shows "Translation missing" (no `default:`) | low | Real only if a published key leaves `HallOfFame` someday; today's keys are fixed and a test pins the locales to `HallOfFame.keys`. The fix adds a parameter. | rejected (unlikely, not a direct correction) |
| quick | `season_shelf.rb`: `ORDER["hall_of_fame"]` has no key tiebreak, so keys outside `HallOfFame` (NULL rank) page in no defined order | low | Unreachable with today's keys, but the fix is a one-term tiebreak, as `EVERY_KIND_ORDER` and `CardDetail` already have. | patch (fixed: `, catalog_sets.key`) |
| quick | Implementation Notes say `CardDetail` orders within a kind by key, but the code uses `HALL_OF_FAME_ORDER` | low | True after the orchestrator's alignment of `card_detail.rb` with the table's order; the fix edits the plan. | rejected (plan edit); note updated as bookkeeping |

## Design Notes

- **Keys:** fixed, French and URL-safe (`mal-aimes`), since the sets are French-named in the spec. A screen never shows a key.
- **Shelf order:** the table's order (Intouchables, Pépites, Mal-aimés, Phénomènes), not alphabetical, so the four read as the spec lists them.
