---
title: 'Filters on a set album'
type: 'feature'
ticket: 23
created: '2026-10-25'
status: 'built'
baseline_revision: '9ec8aeb2f7bf1a6c773285d98ede884bb63f0144'
route: 'oneshot'
route_source: 'pinned'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: true
context: ['{project-root}/AGENTS.md']
warnings: []
deferred:
  - summary: >-
      Back then Forward within milliseconds after TOUT EFFACER restored a stale cached album with the MANQUANTES chip still checked.
    evidence: |-
      Seen once in the system test when go_back and go_forward followed the clear immediately; with short pauses it passed. Unverified whether a person can hit it; settle by reproducing in a browser with fast Back/Forward after clearing.
    location: >-
      app/views/library/_album.html.erb, the filtered frame and Turbo's snapshot cache
    severity: medium (unverified)
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

### 2026-10-24 — Review pass
- verdicts: 8 findings — high 0, medium 2, low 6, false 0, maybe-false 0
- findings:
  - `[low]` `patch` Focus after TOUT EFFACER and the frame reloads was read with one-shot `document.activeElement` reads — retrying `:focus` matchers now.
  - `[medium]` `patch` TOUT EFFACER pushed a history entry, so Back after clearing landed on the filtered album instead of where the album was opened — the album's clear link replaces the entry (`clear_action: "replace"`, the catalog unchanged), and the system test goes back to the collection after clearing.
  - `[low]` `patch` The visitor's filtered album query count was claimed but unmeasured — `assert_request_queries(8)` with a rarity and a search on an owner's album.
  - `[low]` `patch` The rarity filter and the name search on an owner's public album were untested — a signed-out visitor's rare-only and "ELAN" cases, the header unchanged.
  - `[low]` `reject` New comments in `set_album_loading.rb` and `set_album_filters.rb` describe intent and `filtered_faces`' return shape — replacing the tuple with a named object is a refactor beyond this ticket's fix; the comments keep the shape readable meanwhile.
  - `[medium]` `patch` `SetAlbumFilters#folded` copied `SetSearch.normalize`, so the album search and the set search could drift, and refolded the query per card — `SetSearch.normalize` is public and used once for the query.
  - `[low]` `patch` A stray line break in `library_controller.rb`'s header comment — reflowed.
  - `[low]` `patch` EXPERIENCE.md's Filter zone row denied a visitor the state group while giving it to every album — it now says a visitor on a public profile's album gets it.

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

## Auto Run Result

Status: built

- Summary: a set album (the player's own and a public profile's, signed out included) offers the catalog's search field and folded FILTRES zone: state POSSÉDÉES / TOUT / MANQUANTES by the album owner's holdings, rarity of the face shown, and a search by game name ignoring case and accents; the grid keeps set order and pages only the matches, with an empty line and TOUT EFFACER when nothing matches; the header's count, bar and ticks keep measuring the whole set; filtering and clearing replace the history entry, so Back still returns where the album was opened.
- Files: `app/models/set_album_filters.rb` and its tests, `app/models/set_search.rb` (`normalize` public), `app/controllers/concerns/set_album_loading.rb`, `app/controllers/library_controller.rb` (comment), `app/helpers/collection_helper.rb`, `app/views/library/_filters.html.erb`, `_album.html.erb`, `_collection.html.erb`, `set.html.erb`, `app/views/public_profiles/set.html.erb`, `app/frontend/styles/collection.css`, both locales, the library set, public profile and helper tests, `test/system/collection_set_test.rb`, EXPERIENCE.md and DESIGN.md.
- Review: the Quick lens ran from the coordinating session after the unattended run halted on `no subagents`. 8 findings: 7 patched (2 medium, 5 low), 1 rejected (low); one unverified observation from the fixes deferred.
- Follow-up review recommended: true — two mediums were patched; the unverified risk is the stale cached album after a fast Back and Forward following TOUT EFFACER.
- Verification: after the patches, the set album filters, set search, library set, public profile and helper tests and the collection set and library system tests 103 runs, 0 failures; the new Back check fails without the replace and passed 5 runs in a row with it; rubocop clean; the unattended run's full suite (one load-bound `pioneer_of_test.rb` failure, green alone), vitest 561, typecheck, zeitwerk, packwerk, i18n-tasks, brakeman clean.
- Residual risks: a rarity or name filter loads every member's card view before paging (about 750 for the largest set); a card detail opened from a filtered album still steps through the whole set.
