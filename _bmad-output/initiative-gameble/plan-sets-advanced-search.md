---
title: 'Every set behind one advanced search screen, no more "Load more"'
type: 'feature'
ticket: ''
created: '2026-11-09'
status: 'built'
baseline_revision: 'aa4e3e263df49d96e85847c3c4f98fbe1ef26f91'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The collection's set lists grow six tiles at a time per kind through "Load more", which makes no sense for browsing: a player cannot see or filter the whole set catalogue, and search results are silently capped at 50.

**Approach:** Add a "All sets" screen with search and filters laid out like "All cards" (filter row, bottom sheets, numbered pages with scroll loading), and reduce the collection to a preview that leads to it.

**Decisions (author):**
- Collection order: goals, "All my cards" tile, new "All sets" tile, EN COURS, MES SETS, Steam library.
- EN COURS becomes one list across kinds: the six sets closest to their next tier, then a "See all" link to the new screen filtered on in progress.
- COMPLÉTÉS leaves the collection and becomes a filter.
- The search field leaves the collection and lives only on the new screen.
- Filters: kind, state (not started, in progress, complete), tier reached (novice to master), goals.
- Custom sets and the Steam library set appear on the new screen under a "My sets" kind, and keep their dedicated sections on the collection.

## Boundaries & Constraints

**Always:** server-rendered HTML with one root Stimulus controller; strings in both `en.yml` and `fr.yml` (French plurals with `zero`); a Pundit policy on the action; the GET writes nothing; tokens, never database ids, in URLs and DOM; filters in the URL so Back returns to the same results; OR within a filter group, AND across groups; "See all" is a `ButtonComponent` with `variant: :link`.

**Never:** change the custom set editor's own "Load more" (a game picker); change the `public_profiles` collection or the album; add a migration; inherit `SetSearch::LIMIT`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Default list | no params | every set; in progress closest first, then not started by name, then complete | No error expected |
| Search | `q` | matches name or kind, name-prefix first, combined with filters | Over-long `q` is truncated |
| Unknown filter value | `state=foo` | value ignored | Never a 500 |
| Tier chosen | custom set, no tiers | custom set excluded | No error expected |
| Nothing matches | any | empty line and "Clear all" | No error expected |
| No published season | any | the no-season panel | No error expected |
| Visitor | signed out | same redirect as the collection | `:play?` policy |

</frozen-after-approval>

## Code Map

- `config/routes.rb:56-57` -- add `library/sets` beside `library/cards`.
- `app/controllers/library_controller.rb` -- `show`, `in_progress`, `cards` (model for the new action, html + turbo_stream).
- `app/controllers/concerns/set_board_loading.rb` -- reuse `search_rows`, `set_tiles`, `own_set_tiles`, `aimed_at?`, `completion_order`, `closest_to_next_tier`; remove offset paging.
- `app/models/set_search.rb` -- in-memory matching; `normalize`, `ranked` to reuse.
- `app/domains/game/app/queries/game/sets_in_progress.rb`, `app/domains/catalog/app/queries/catalog/set_figures.rb` -- standings for started and unstarted sets.
- `app/views/library/_all_cards_tile.html.erb` -- the tile to mirror.
- `app/views/library/_filters`, `_filter_row`, `_pages`, `cards.turbo_stream.erb` -- layout and paging to follow; bound to `Catalog::CollectionGrid`, so reuse classes and `BottomSheetComponent`.
- `app/frontend/controllers/next_page_controller.ts`, `collection_filters_controller.ts`, `lib/collection_filters.ts` -- reuse; `lib/set_search.ts` stays (`Debounce` has other users).
- `app/helpers/shell_helper.rb`, `mobile/` path configuration -- grep for `library_cards`/`library/cards`; give the new screen the same treatment.

## Tasks & Acceptance

**Execution:**
- [x] `app/models/set_browser.rb` -- new object: filters, standings and order over game and own sets, no cap -- one place for the rules of the matrix.
- [x] `test/models/set_browser_test.rb` -- cover every matrix row and each filter.
- [x] `config/routes.rb`, `app/controllers/library_controller.rb` -- `sets` action (`authorize :page, :play?`), html and turbo_stream; `show` no longer searches or pages; `in_progress` loads the six closest and whether more exist.
- [x] `app/controllers/concerns/set_board_loading.rb` -- preview across kinds, delete `load_set_search`, `tile_offset`, `next_offset`, `TilePage` if unused.
- [x] `app/views/library/sets.html.erb`, `sets.turbo_stream.erb`, `_set_filters.html.erb`, `_all_sets_tile.html.erb` -- the screen and its tile.
- [x] `app/views/library/_entry.html.erb`, `in_progress.html.erb` -- the decided order and preview.
- [x] `app/views/library/_set_search`, `_set_results`, `_set_tile_section`, `_set_tile_page`, `more_tiles`, `more_results`, `app/frontend/controllers/set_search_controller.ts` -- delete what is left unused.
- [x] `config/locales/en.yml`, `fr.yml` -- new copy; `no_progress` no longer says "above"; remove `library.entry.load_more`, `search`, `results`, `found`, `none`, `completed` if unused.
- [x] `test/controllers/library_controller_test.rb`, `library_goal_suggestions_test.rb`, `test/system/library_test.rb` -- replace the "Load more" tests with the preview and the screen.
- [x] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- update the Collection opening, Set search and copy rows, dated by the author.

**Acceptance Criteria:**
- Given more than six sets in progress, when the collection loads, then six tiles show and "See all" opens the screen filtered on in progress.
- Given six or fewer, when the collection loads, then no "See all" shows.
- Given the screen, when a filter chip or the search changes, then results update in place, the URL holds the filters, and Back restores them.
- Given more than one page, when scrolling to the end, then the next page appends; without JavaScript, the numbered links work.
- Given the phone width, when opening a filter, then a bottom sheet opens as on "All cards".

## Implementation Notes

Work only in the worktree `/home/teyermann/projets/gameble/.claude/worktrees/sets-advanced-search` (branch `feat/sets-advanced-search`), using absolute paths; never edit source in `/home/teyermann/projets/gameble`, whose checkout another session is using. This plan file stays at its current path and is the one exception. Call git as `/usr/bin/git`, and do not commit. Write the code and its tests but do not run the test suites: they are run once afterwards.

## Plan Change Log

## Review Triage Log

Pass 1 (quick lens): 0 high, 1 medium, 4 low patched, 1 low rejected, 1 false.

| Finding | Verdict | Route | Evidence |
|---------|---------|-------|----------|
| `package-lock.json` changed by `npm install` | low | patch | Name and `dev` flags differed from baseline; restored before the commit. |
| `sets.html.erb` lacks `last-album` | medium | patch | `aria-current` on the last album's tile was lost from the search it replaced; controller added and tested. |
| `EXPERIENCE.md` says 300ms | low | patch | The reused controller waits 250ms; corrected. |
| `EXPERIENCE.md` stale rows | low | patch | Phrases still named the removed search and COMPLÉTÉS; corrected. |
| One-shot read at `test/system/library_test.rb:84` | low | patch | Replaced by the retrying `assert_field`. |
| "See all" threshold differs from the screen's in progress | low | rejected | Real, but no set becomes unreachable: uncounted sets are goals shown above or reachable from the "All sets" tile just above; a fix would add a field to `Game::SetBoard`. |
| Complete sets match no tier chip | false | rejected | A complete set's tile shows "Complete", not a rank, and the State filter selects it; the intent limits tier chips to novice through master. |

## Design Notes

"My sets" is one more value of the kind filter, so the chip row stays uniform. The filter form reuses the `collection-filters` controller when its frame names can stay `collection-results`; otherwise pass them as Stimulus values rather than copying the controller.

## Verification

**Commands:**
- `bin/ci` -- expected: passes
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: pass
- `bin/rails test test/system/library_test.rb` -- expected: passes
