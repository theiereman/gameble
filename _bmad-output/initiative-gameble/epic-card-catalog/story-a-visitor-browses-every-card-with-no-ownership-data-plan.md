---
title: 'A visitor browses every card with no ownership data'
type: 'feature'
ticket: 4
created: '2026-10-20'
status: 'built'
baseline_revision: '76ba9e33bbf475e3311a28c4344fa02606fac5bc'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
commit: 'bf5e277ac33e7350ab4d2fd77ddc5607b7f74fd9'
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** A signed-out visitor opening "Toutes les cartes" sees the ownership parts emptied rather than absent: the state filter group (POSSÉDÉES, TOUT, MANQUANTES, NOUVELLES, DOUBLONS), the RAPPORT panel and its phone fold reading zeros, and the top bar's "Cartes uniques : 0 / 150" on every collection page (the entry, Toutes les cartes, a set's album). The author decided on 2026-10-20 that a visitor sees none of it.

**Approach:** For a visitor (`current_player` nil, a banned player included): no state filter group, and any `state[]` the query carries is ignored (the grid shows every card, and the links it carries name no state); no RAPPORT aside, the grid taking the full width at every breakpoint; no `top_bar_status` on `library#show`, `library#cards` and `library#set`, so the top bar shows the Steam sign-in as on other pages. The search and the rarity, set and genre filters keep working. A player's view is unchanged. The card detail's rows (ticket 3), the copy badge, edition count and NOUVEAU (none for a visitor already) stay as they are. Throttling and `Cache-Control: private` are as today, now covered for `/library/cards`.

## Boundaries & Constraints

**Always:** a player's grid, filters, RAPPORT and status unchanged; the visitor's grid runs no `game_holdings` / `game_player_states` query; no database id; no `style` attribute; strings in both locales; no planning ids in code or tests.

**Never:** change set albums' header counts and progress bars or the set search rows (their visitor form is not part of this ticket), the public card page, the public profile, the policies (PagePolicy already lets a visitor read), or `PublicReadThrottle`'s pages.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Visitor, Toutes les cartes | signed out, `/en/library/cards` | no `[data-group=state]`, no `.report`, no `.collection__aside`, no `.collection-status`; search, rarity, set and genre groups present; every face plain | none |
| Visitor asks a state | `state[]=owned` | the grid shows every card (state ignored), the FILTRES count 0, card links carry no `state` | none |
| Visitor filters | `q=` a title, `rarity[]=rare`, a set | grid narrowed as for a player; an empty result shows the empty-filter line | none |
| Visitor, entry and album | `/en/library`, `/en/library/theme/roguelike` | no `.collection-status` in the top bar; the Steam sign-in present | none |
| Banned player | session of a player banned since | same as visitor | none |
| Player | signed in | unchanged: state group, RAPPORT, status | none |
| Throttle and cache | 121 reads of `/fr/library/cards` from one address | the 121st is 429; a read carries `Cache-Control: private` | none |

</intent-contract>

## Code Map

- `app/controllers/concerns/collection_grid_loading.rb` -- `grid_states_asked(source)` returns `[]` when `current_player` is nil; `grid_context` drops `:state` for a visitor (so the detail's ◀ ▶, which reads the same concern in `CardsController#grid_browse`, walks the same grid).
- `app/views/library/_filters.html.erb` -- render the state `fieldset` only for a signed-in player (a local, e.g. `ownership:`, passed from `_collection`); update the header comment.
- `app/views/library/_collection.html.erb` -- render the `aside` (RAPPORT) only for a signed-in player; add a modifier class to `.collection` for a visitor (no aside) and pass the local to `library/filters`; update the comment.
- `app/frontend/styles/collection.css` -- the visitor modifier: one column, `grid-template-areas: "main"`, at every width (the default rule is `220px minmax(0, 1fr)` / `"aside main"`); remove the `.collection-status--visitor` rule in the phone media query (no longer rendered) and its comment.
- `app/views/library/_status.html.erb` -- drop the `collection-status--visitor` class and the visitor sentence of its comment.
- `app/views/library/show.html.erb`, `cards.html.erb`, `set.html.erb` -- `content_for :top_bar_status` only when `current_player`.
- `app/controllers/library_controller.rb` -- class comment: a visitor sees no ownership data. Loading the summary for a visitor may be skipped only if query counts stay asserted.
- `test/controllers/library_controller_test.rb` -- the visitor cases ("a visitor sees every slot…", "a visitor, and a player owning nothing, open on every slot", "a visitor sees the published season's tiles", the entry case "…so does a visitor") now assert the absence of the state group, RAPPORT and status, the Steam sign-in in the top bar, a state asked ignored, the search and rarity and set filters narrowing; keep the "no holdings query" assertions and update the visitor's query count only for queries removed, saying why. Add a set album visitor case asserting no `.collection-status` (in `test/controllers/library_set_test.rb`). Player cases unchanged.
- `test/controllers/cards_controller_test.rb` -- a visitor browsing a grid with `state[]` in its `grid` context walks every card.
- `test/integration/rate_limit_test.rb` -- a new case: `/fr/library/cards` throttled at the 121st read (429) and `Cache-Control: private` on a read.

## Tasks & Acceptance

**Execution:**
- [x] `app/controllers/concerns/collection_grid_loading.rb` -- states ignored for a visitor.
- [x] `app/views/library/_filters.html.erb`, `_collection.html.erb`, `_status.html.erb`, `show.html.erb`, `cards.html.erb`, `set.html.erb`, `app/frontend/styles/collection.css`, `app/controllers/library_controller.rb` -- no ownership parts for a visitor.
- [x] `test/controllers/library_controller_test.rb`, `test/controllers/library_set_test.rb`, `test/controllers/cards_controller_test.rb`, `test/integration/rate_limit_test.rb` -- the matrix rows.

**Acceptance Criteria:**
- Given a visitor on Toutes les cartes, when the page renders, then no state filter, RAPPORT or owned count appears and the grid fills the width; search and the other filters work.
- Given a visitor on any collection page, when it renders, then the top bar shows no owned / total count.
- Given a player, when they open any collection page, then it is unchanged.

## Implementation Notes

- A visitor's `state[]` is ignored in `CollectionGridLoading` (`grid_states_asked`, `grid_context`), so the grid, its card links and the detail's ◀ ▶ agree; `LibraryController#pages_query` (pagy `querify:`) also drops `state` from a visitor's page links, which the plan's map did not name but its matrix row needs.
- The RAPPORT aside and the state group render only for a signed-in player; `.collection--visitor` lays the grid alone at every width; `top_bar_status` is given only for a player on the entry, Toutes les cartes and an album.
- The summary loads are kept for a visitor, so the query counts hold (a visitor's seven).

## Plan Change Log

## Review Triage Log

### 2026-10-20 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` A visitor still runs the summary loads (`Catalog::CardCount` among them) on the three pages though nothing shows them — the plan keeps them to hold the asserted query counts; the cost is one or two cheap queries, and removing them means reworking the counts for no user-visible change.

## Verification

**Commands:** (prefix every Rails command with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w14 CHROME_BIN=/usr/bin/chromium`, this worktree's own test database; never run system tests; call git as `/usr/bin/git`; do not commit)
- `bin/rails test test/controllers test/integration` -- pass
- `npm run test:js` -- pass (collection-grid.test.ts reads collection.css)
- `bin/rubocop` and `bundle exec i18n-tasks missing` -- clean

## Auto Run Result

- Summary: a signed-out visitor (or a banned player) sees no ownership data on the collection pages: no state filter group (a `state[]` in the query is ignored, and no link names one), no RAPPORT (the grid alone at every width), no owned / total count in the top bar of the entry, Toutes les cartes or an album (the Steam sign-in instead); search, rarity, set and genre filters keep working. A player's view is unchanged. `/fr/library/cards` is shown throttled at the 121st read and `Cache-Control: private`.
- Files: `app/controllers/concerns/collection_grid_loading.rb`, `app/controllers/library_controller.rb`, `app/views/library/_collection.html.erb`, `_filters.html.erb`, `_status.html.erb`, `show.html.erb`, `cards.html.erb`, `set.html.erb`, `app/frontend/styles/collection.css`; tests in `test/controllers/library_controller_test.rb`, `library_set_test.rb`, `cards_controller_test.rb`, `test/integration/rate_limit_test.rb`.
- Review (quick): 1 low finding, rejected (unused summary loads kept for the query counts). No patch, no deferral.
- Follow-up review recommended: false.
- Verification: `bin/rails test` 2881 runs, 0 failures (one run showed 1 error not reproduced in three later full runs, likely a concurrent use of the test database); `npm run test:js` 486 passed; typecheck, zeitwerk, packwerk, rubocop (846 files), i18n-tasks missing and brakeman clean.
- Residual risk: the visitor's full-width layout is checked from the CSS only, not in a browser.
- Open question for the author (not built): EXPERIENCE.md, Navigation, says a visitor's "collection's sets show no progress"; a set album's header ("0/62", progress bar, tier ticks) and the entry's set search rows still show a visitor's zero progress. This ticket's description does not list them and the epic leaves set albums out of scope; whether they should hide for a visitor is the author's call.
