---
title: 'Filters on a set album'
type: 'feature'
ticket: 23
created: '2026-10-25'
status: 'in-progress'
baseline_revision: '9ec8aeb2f7bf1a6c773285d98ede884bb63f0144'
route: 'oneshot'
route_source: 'pinned'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** A set album (`app/views/library/_album.html.erb`, rendered by `library#set` and `public_profiles#set`) shows every card of the set in set order, sixty to a page, and a large set loses the player. The author settled (2026-10-24) that the album gets filters: owned or missing and rarity, taken from the catalog's folded FILTRES zone (`app/views/library/_filters.html.erb`), plus a search by game name.

**Approach:** Render the catalog's `library/filters` partial under the album's header, generalised so the album passes its own choices: the state group offers only POSSÉDÉES / TOUT / MANQUANTES (judged by the album owner's holdings, on the player's own album and on a public profile's, signed out included), the rarity group as in the catalog, no set or genre group, and a search field named for a game's name (title only, in the page's locale). A new web-layer value `SetAlbumFilters` reads `state[]`, `rarity[]` and `q` from the request and answers the zone as a `Catalog::CollectionGrid` does (`chosen_rarities`, empty `chosen_sets` / `chosen_genres` / `genres`). `SetAlbumLoading#load_set_album` filters the set's members before paging: the state on the owner's editions already loaded, the rarity and the title on the shown face's `Catalog::CardView` (loaded for every member only when a rarity or a text is asked, so the query count stays the same), keeping set order. The grid, its result status line and its pages sit in the `collection-results` Turbo frame the form reloads (URL replaced, so the back button still returns where the album was opened and the heading's focus on open is unchanged); the header's tier bar and owned / total line stay computed on the whole set. A filter that leaves nothing shows the catalog's "Nothing matches these filters." line; TOUT EFFACER leads back to the album's path, in set order. EXPERIENCE.md's Set album and Filter zone rows, and DESIGN.md's Set album and Filter zone entries, say so.

</intent-contract>

## Implementation Notes

Oneshot: the album reuses the catalog's zone, form, Stimulus controller and frame pattern unchanged; the new code is one small value object, a filtered member list before the existing paging, and a partial generalised by its locals. About 150 lines with tests and docs.

- Files touched: `app/models/set_album_filters.rb` (new: reads `state[]`, `rarity[]`, `q`; answers the zone like a `Catalog::CollectionGrid`), `app/controllers/concerns/set_album_loading.rb` (members filtered before paging; card views read for every member only when a rarity or text is asked, else for the page as before, so the album keeps its 11 / 8 queries), `app/views/library/_filters.html.erb` (locals `filters:` instead of `grid:`, `state_choices:` instead of `ownership:` + `with_new:`, optional `set_filter:`, `search_label:`, `search_placeholder:`), `app/views/library/_collection.html.erb` (passes the catalog's state choices), `app/helpers/collection_helper.rb` (`collection_filter_count(filters:)`), `app/views/library/_album.html.erb` (the zone under the header; grid, status line and pages in the `collection-results` frame; the empty-filter line), both `set.html.erb` pages, `app/frontend/styles/collection.css` (`.set-album > turbo-frame { display: contents }` so the grid keeps the album's gaps), both locales (`library.album.search.label` / `placeholder`), `app/controllers/library_controller.rb` (comment), EXPERIENCE.md (Set album, Filter zone) and DESIGN.md (Set album, Filter zone).
- Decision: the rarity filter reads the face the album shows (the owner's best edition for a held game, the set's own card-season otherwise), so a filtered album never shows a card of another rarity than the chip; the search matches the title only, in the page's locale, accents and case ignored as the set search does (`SetSearch`), never the publisher, per "search by game name".
- Decision: the card detail opened from a filtered album still walks the whole set (its `set_kind` / `set_key` context is unchanged); the ticket asks nothing of the detail.
- Tests: `test/models/set_album_filters_test.rb` (new), five album filter tests and a filtered query count in `test/controllers/library_set_test.rb`, a visitor/viewer test in `test/controllers/public_profiles_controller_test.rb`, the helper test's keyword, and a system test in `test/system/collection_set_test.rb` (40-card set: MANQUANTES, then RARE, header unchanged, chip focus kept, TOUT EFFACER back to set order with the heading focused, the search keeping focus, then "◀ SETS" back to the collection entry).

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/controllers/library_set_test.rb test/controllers/public_profiles_controller_test.rb test/controllers/library_controller_test.rb test/helpers test/models` -- expected: pass
- `bin/rails test test/system/library_test.rb test/system/collection_set_test.rb test/system/public_profile_test.rb test/system/card_detail_test.rb` -- expected: pass
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `PARALLEL_WORKERS=2 bin/rails test` -- expected: pass

**Results (2026-10-25, Ruby 4.0.7, Postgres 16 on 5433, Chromium 141):**
- `test/controllers/library_set_test.rb`, `public_profiles_controller_test.rb`, `library_controller_test.rb`, `test/helpers`, `test/models/set_album_filters_test.rb`: pass (the album keeps 11 queries for a player and 8 for a visitor, filtered or not).
- System: `library_test.rb`, `collection_set_test.rb`, `public_profile_test.rb`, `card_detail_test.rb`, `shell_test.rb`: 48 runs, 0 failures.
- `npm run test:js` 561 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk validate` and `check`, `bin/rubocop`, `bundle exec i18n-tasks missing` and `unused`, `bin/brakeman`: clean.
- `PARALLEL_WORKERS=2 bin/rails test`: 3181 runs, 1 failure, `Game::PioneerOfTest#test_the_first_discoverer_and_the_date,_in_one_query` (fixture time `2.weeks.ago` drifted 110 s past its 60 s delta on a machine shared by nine builds; untouched by this change), which passes alone.
