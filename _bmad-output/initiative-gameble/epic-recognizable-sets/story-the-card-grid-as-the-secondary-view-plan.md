---
title: 'The card grid as the secondary view'
type: 'feature'
ticket: '9'
created: '2026-10-17'
status: 'built'
baseline_revision: 'e4847af41d8814f0b1bcc22d7dd520ca825fcb6c'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The grid of every card (`/library/cards`, reached by "TOUTES LES CARTES" on the collection entry) still carries the old collection screen: a column of sets with kind tabs and a paged shelf, a set filter that lists the shelf page's sets as chips, and a set-scoped grid that no longer has a page since sets open as albums.

**Approach:** The grid page becomes "Toutes les cartes": the grid with its search and FILTRES zone and the RAPPORT, no shelf of sets. The filter zone's set group picks a kind, then finds a set by typing its name (EXPERIENCE.md, Filter zone: "set (a kind, then a set found by typing its name)"). The set-scoped grid support the album left behind is removed.

## Boundaries & Constraints

**Always:**
- Page: h1 "Toutes les cartes"/"All cards" (visually hidden, as the entry's "Collection" h1), page title "Toutes les cartes · Collection · gameble" (follow how the album builds its title), top-bar screen title "Collection" and the unique-cards status as today, back button as today (the trail names "◀ Sets" from the entry).
- No set column: drop the aside's kind tabs, set rows, "Toute la saison" row and shelf paging. The RAPPORT stays where it shows today (panel in the left column from 1180px, fold on the phone, hidden between); the left column is not rendered empty between 720 and 1180px.
- Set group (only when the season holds sets), inside the existing FILTRES form:
  - kind radios `set_kind` over the kinds the season holds, in order theme, franchise, studio, hall_of_fame, ufo, labelled with `library.set_kinds.*`; an unknown or absent value selects the first kind held;
  - a text field `set_q` labelled "Chercher un set"/"Find a set" (a `<label>`, never a placeholder), at most `SetSearch::MAX_QUERY`;
  - set chips (checkboxes `sets[]` = "kind:key", the chip style of the other groups): first every chosen set (checked, whatever the kind and text), then up to 12 unchosen sets of the chosen kind whose name contains the text, accent- and case-insensitive (SetSearch's normalisation; names starting with it first, then by name); blank text lists the kind's first 12 sets by name; a polite status line gives the count found (`library.entry.found`), and text with no match shows `library.entry.none`.
  - With JavaScript: changing the kind or typing in `set_q` (after the same pause as the search, IME composition respected) reloads only the chips and status, in a turbo frame inside the set group, and never reloads the grid (kind and set text filter no card); focus stays where it was. Checking a set chip filters the grid at once, like any chip. Without JavaScript the "apply" button submits everything and the page renders the same set group.
  - `set_kind` and `set_q` are not filters: not in the active-filter count, not in a card's grid context, not kept by "Tout effacer" (it leads to bare `/library/cards`).
- Filters combine as today: OR within a group, AND across groups (state, rarity, sets, genre) and with the text search.
- Removed with the set-scoped grid: `Catalog::CollectionGrid`'s `kind:`/`key:` and `set` (always the whole season, newest gained first); `grid_context`'s kind/key; `CardsController#named_grid` (a detail link whose `grid` names a kind and key walks the whole season's grid with its filters); `grid_page_path` always to `library_cards_path`; the `kind`/`shelf` parameters of `/library/cards`.
- Fixed query count whatever the number of sets; every GET writes nothing; no database id in HTML or URLs; every string in `en.yml` and `fr.yml` (French plurals with `zero`); no `style` attribute; no planning ids; no new explanatory comments (rewrite existing header comments that describe removed behaviour).

**Never:**
- No one-card-per-game grid, no edition count (entry 15); no change to the album, the entry, the hub or the card detail beyond the grid-context removal.
- No other player's full collection (a later ticket).
- No new route other than what the filter needs (prefer none: the set chips load from `/library/cards` itself), no migration.
- No arrow keys or roving tabindex on this grid.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| From the entry | `/en/library` | "All cards" link to `/en/library/cards`; that page has the h1 "All cards", the search, FILTRES and the grid, no set rows or kind tabs | — |
| Theme and rarity | `/en/library/cards?genre[]=rpg&rarity[]=rare` | only the rare RPG cards; the count announces them | — |
| Set and rarity | `?sets[]=theme:roguelike&rarity[]=epic` | only the epic cards of the Roguelike set; its chip checked | — |
| Find a franchise | `?set_kind=franchise&set_q=dark` | a chip "Dark Souls" (`sets[]` = `franchise:<its key>`), unchecked; no other franchise not containing "dark"; grid unfiltered | — |
| Accents and case | `set_kind=theme&set_q=ROGUE` (fr) | the Roguelike chip | — |
| No match | `set_kind=studio&set_q=zzz` | "No set found for “zzz”." in the set group; grid unchanged | — |
| Chosen elsewhere | `sets[]=theme:roguelike&set_kind=franchise&set_q=dark` | Roguelike chip checked first, then Dark Souls; filter count 1 | — |
| Unknown kind | `set_kind=nope` or a kind the season lacks | the first kind held is selected | — |
| Many sets | 200 studios, blank text | 12 studio chips; same query count as with 3 studios | — |
| No sets | season without sets | no set group | — |
| Old detail link | card detail `?grid[kind]=theme&grid[key]=roguelike&grid[q]=` | walks the whole season's grid; back to `/library/cards` (its page) | — |

</intent-contract>

## Code Map

- `app/controllers/library_controller.rb` -- `cards`: drop `ShelfLoading`, `@kinds`/`@kind`, `SHELF_KEY`, `load_shelf`; load the set group (`@set_kinds`, chosen kind, `@set_query`, found sets and count). `load_summary`/`load_unique_cards` stay. Rewrite the class header comment (it narrates the shelf).
- `app/controllers/concerns/shelf_loading.rb` -- delete. Move what survives: `KINDS` → `CollectionGridLoading::SET_KINDS`, `page_param` + `MAX_PAGE` → `CollectionGridLoading`; `SetAlbumLoading` (`ShelfLoading::MAX_PAGE`) and `CardsController` (`ShelfLoading::KINDS` at lines ~123, ~140) follow.
- `app/controllers/concerns/collection_grid_loading.rb` -- `collection_grid(season, source)` only; `grid_cards` always `newest_first: true`; `grid_context(source, seen:)` without set; header comment updated.
- `packs/catalog/app/queries/catalog/collection_grid.rb` -- drop `kind:`/`key:`, the set join and order, `Grid#set`; `chosen_sets` always read. Test `test/packs/catalog/collection_grid_test.rb` follows (drop set-scope tests).
- `app/models/set_search.rb` -- add a kind-scoped finder for the filter (e.g. `SetSearch.in_kind(season:, kind:, query:, locale:, limit: 12)` → `Result(sets, count)`), reusing `normalize`/ordering; blank query = the kind's sets by name. Test in `test/models/set_search_test.rb` (exists? else create).
- `app/controllers/cards_controller.rb` -- remove `named_grid`; `grid_browse` uses `collection_grid(season, source)`; `grid_page_path` → `library_cards_path`; header comment's `grid` line drops "and set".
- `app/helpers/collection_helper.rb` -- delete `collection_season_path`, `collection_set_path`, `set_chip_label`, `collection_list_params`; `collection_clear_path` takes no argument (or inline `library_cards_path`). `test/helpers/collection_helper_test.rb` follows.
- Views: `app/views/library/cards.html.erb` (h1/title, locals), `_collection.html.erb` (no set list; aside = RAPPORT; drop kind/kinds/set/spines/shelf locals), `_filters.html.erb` (no `kind`/`shelf` hidden fields; new set group as a partial, e.g. `library/_set_filter.html.erb`, with the turbo frame `collection-set-options` holding chips + status). Delete `_set_list.html.erb` and `_set_row.html.erb` (check `set_row` partial has no other caller; `set_progress_row` is a different partial and stays).
- `app/frontend/controllers/collection_filters_controller.ts` -- targets for the set kind/set text; on their change/typing submit the form with a submitter whose `data-turbo-frame` is `collection-set-options` (`form.requestSubmit(submitter)`; a hidden button inside the form), never the grid frame; `changed` ignores radios for grid submission; the count counts only checkboxes (as today). Pure logic worth a vitest goes to `app/frontend/lib/` with a `.test.ts`, following `auto_submit.ts`.
- CSS `app/frontend/styles/collection.css` -- delete `.collection-sets*`, `.collection-kind*`, `.collection-sets .series-nav*` and their media-query rules (~178-280, ~412-450, ~891-930); the aside between 720 and 1180px no longer shows; style the set group (kind radios as chips, the set text field like `.filters__search-field`, status muted).
- Locales `config/locales/{en,fr}.yml`: `library.cards.title` ("Toutes les cartes · Collection · gameble"/"All cards · Collection · gameble"), `library.cards.heading` ("Toutes les cartes"/"All cards") or reuse `library.entry.all_cards`; `library.filters.set_search.label` ("Chercher un set"/"Find a set"); `library.filters.set_kind` legend if needed ("Sorte"/"Kind"). Remove keys left unused (`library.show.tabs.*`, `library.show.empty.*`, `library.show.past_the_end`, `library.sets.*`, `library.set_row.*` if unused): `bundle exec i18n-tasks unused` must list only the pre-existing `rate_limit.*`.
- Dead after the shelf: `Catalog::SetTotals`, `Game::SetProgress`, `Catalog::SeasonShelf.relation` and `ORDER`/`BY_KEY` if nothing else calls them (grep, incl. packs' public API files and tests) -- delete with their tests; `SeasonShelf.every_kind`/`kinds`/`HALL_OF_FAME_ORDER` stay (SetSearch, CardDetail).
- Tests: `test/controllers/library_controller_test.rb` -- replace the shelf/kind-tab tests (~312-425: "a kind of … lists the themes", UFOs, franchises/studios tabs, hall of fame tab, season without themes, "120 studios … shelf") with set-group tests (matrix rows); update the query-count test (~517, "sixteen … nine") to the new exact counts and add one with 200 studios vs 3; keep the read-only, ids and French tests passing. `test/controllers/library_set_test.rb:314`, `test/controllers/cards_controller_test.rb` (~600-720, grid browse and `grid[kind]` cases), `test/integration/*` touching `/library/cards`. Support: `test/support/game_sets.rb` (`insert_set`, `insert_theme`), `test/support/library_requests.rb` (`assert_request_queries`). System tests: obvious selector updates only, never run.

## Tasks & Acceptance

**Execution:**
- [ ] `collection_grid.rb`, `collection_grid_loading.rb`, `cards_controller.rb`, `shelf_loading.rb` (delete) -- remove the set-scoped grid and the shelf, move the surviving constants -- the album replaced the set grid.
- [ ] `set_search.rb` (+ test) -- the kind-scoped set finder.
- [ ] `library_controller.rb`, `cards.html.erb`, `_collection.html.erb`, `_filters.html.erb`, `_set_filter.html.erb` (new), delete `_set_list`/`_set_row`, `collection_helper.rb` -- "Toutes les cartes" without the set column, with the kind-then-search set group.
- [ ] `collection_filters_controller.ts` (+ lib and vitest if logic is extracted) -- the set chips reload in their frame without reloading the grid.
- [ ] `collection.css`, locales -- remove dead styles and keys, add the set group's look and strings.
- [ ] Delete what the shelf leaves dead (`SetTotals`, `SetProgress`, `SeasonShelf.relation`) with their tests, after grepping.
- [ ] Request and unit tests for every matrix row, both locales, no `[style]`, no ids, GET writes nothing, exact query counts.

**Acceptance Criteria:**
- Given the collection entry, when the player follows "Toutes les cartes", then the grid shows with its search and FILTRES zone and no list of sets beside it.
- Given the grid, when the player chooses the genre RPG and the rarity Rare, then only rare RPG cards show, as before.
- Given the set group, when the player picks "Franchise" and types "dark", then a "Dark Souls" chip appears without the grid reloading, and checking it shows only Dark Souls cards.
- Given the change, when `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused` run, then they pass (unused: only the pre-existing `rate_limit.*`).

## Implementation Notes

- **Set chips' submitter:** the set kind and text submit through a `<button data-turbo-frame="collection-set-options">` that the controller appends, uses with `form.requestSubmit(submitter)` and removes in the same call (`app/frontend/lib/collection_filters.ts#submitToFrame`). A permanent hidden button would have become the form's default button, so Enter in the card search would have reloaded the set chips instead of the grid. Enter in `set_q` is caught (`setKeydown`) and reloads the chips, not the grid.
- **Status line:** the polite `role=status` line sits outside the frame and is updated on `turbo:frame-load` from a hidden `[data-set-filter-summary]` inside the frame, following the entry's set search. A live region swapped in with the frame's new content is not reliably announced. Without JavaScript the server renders the same line.
- **Status text:** `library.entry.none` when text is typed and matches nothing, otherwise `library.entry.found` with the count of the kind's sets the text finds (chosen sets of that kind included). Blank text lists the kind's first 12 by name and counts them all.
- **URL:** the form keeps `data-turbo-action="replace"`, so reloading the set chips also replaces the URL with the current `set_kind`/`set_q`. A reload then renders the same set group. Page links keep those two parameters; the grid context and "Tout effacer" do not.
- **`SetSearch.in_kind`** reads `Catalog::SeasonShelf.every_kind(season:).where(kind:)`: one query, filtered and ranked in Ruby with the same normalisation and ranking as `SetSearch.call` (extracted into `ranked`). `except:` drops the chosen sets from the 12 without reducing the count.
- **Also dead and deleted:** `Game::HeldCards`, which only `Game::SetProgress` used.
- **Query counts:** a player's grid now costs 13 queries (16 before) and a visitor's 7 (9 before). The set group adds two queries (kinds held, the kind's sets) whatever the number of sets; the shelf's four are gone.
- **System tests:** only `collection_set_test.rb` "between 720 and 1179px" was rewritten (grid alone, no aside). `library_test.rb` still asserts `.collection-sets` rows on `library_path` and set pages, which the entry and album tickets had already invalidated. Left as is, not run.

- **URL, after review:** `data-turbo-action="replace"` moved from the form to the grid's frame (`collection-results`), so only a grid reload replaces the URL; reloading the set chips leaves the URL, and the grid page it names, alone. Grid page links carry the `set_kind`/`set_q` of the request that last rendered the grid.
- **Verdict on `Game::HeldCards`:** no reference left in `app`, `packs`, `test`, `config` or `lib` once `Game::SetProgress` went; deletion kept.

## Plan Change Log

## Review Triage Log

### 2026-10-17 — Review pass
- verdicts: 6 findings — high 0, medium 0, low 6, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` Reloading the set chips replaced the URL with the form's fields and no `page`, while the grid frame still showed page N — `data-turbo-action="replace"` moved from the form to the `collection-results` frame (Turbo reads it from submitter, form, then target frame), so a set-chip reload no longer touches the URL.
  - `[low]` `[reject]` Grid page links keep the `set_kind`/`set_q` of the request that last rendered the grid, so a page click after changing the kind restores the earlier kind and text — only the transient search state snaps back; the chosen sets and every filter are kept, and any grid reload refreshes the links; a fix needs the page links rebuilt client-side.
  - `[low]` `[patch]` A set-chip reload landing after a chip was checked shows that chip unchecked — `changed` now cancels the pending set-text debounce when a grid reload starts, which closes the likelier window (the 250ms pause); a request already in flight can still land late, which needs a check within the request time and corrects itself on the next grid reload.
  - `[low]` `[reject]` With two search fields and no submit button in the DOM, Enter in the card search no longer submits implicitly — the card search already reloads the grid 250ms after typing, so Enter adds nothing a player waits for; a fix adds a key handler.
  - `[low]` `[patch]` New explanatory comments against AGENTS.md (`load_set_filter`, `_set_filter` header, `SET_KINDS`, the set group's CSS comment, the TS Enter comment) — removed; rewritten pre-existing comments kept.
  - `[low]` `[patch]` On the phone `.filters__group`'s touch gap overrode `.set-filter`'s `--space-3` — the phone rule now reads `.filters__group:not(.set-filter)`.

## Design Notes

- **Set group shape:** the design names the order (a kind, then a set found by typing) but draws no screen. Kind radios narrow the text search, which keeps a single short list (12) whatever the kind's size (themes ~42, franchises ~188, studios ~254); blank text still lists something so the four hall of fame sets and the one UFO set need no typing. Chosen sets stay listed first so a filter on is always visible and can be switched off.
- **Frame, not route:** the set chips reload from `/library/cards` itself through a submitter targeting their own frame, so the grid, the search field and the kind radios stay in place and no new endpoint or policy is needed.
- **Old detail links:** a `grid` context naming a set now walks the whole season's grid; links built by the old set grid are rare and still land on a working grid.

## Verification

**Commands:**
- `bin/ci` -- expected: green (revert any stray `package-lock.json` "license" line it writes)
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: green (unused: pre-existing `rate_limit.*` only)

**Manual checks (if no CLI):**
- If a headless browser is available, view `/en/library/cards` at 1280px and 390px on a scratch database (set group, RAPPORT placement); system tests stay disabled.

## Auto Run Result

- **Summary:** `/library/cards` becomes "Toutes les cartes" ("All cards"): the grid with its search, FILTRES zone and RAPPORT, without the column of sets (kind tabs, set rows, "Toute la saison" row, shelf paging). Visually hidden h1 "All cards", title "All cards · Collection · gameble", top bar unchanged. The FILTRES set group picks a kind among those the season holds, then finds a set by typing its name: up to 12 chips, the chosen sets first and checked, then the kind's matches (accent- and case-insensitive, names starting with the text first); blank text lists the kind's first 12 by name; a polite status line counts the matches or says none. With JavaScript the kind and the text reload only the chips, in their own frame, never the grid and never the URL; without it the apply button submits everything. The set-scoped grid the album left behind is gone: `Catalog::CollectionGrid` covers the whole season only, and an old card-detail link naming a set in its grid walks the whole season's grid.
- **Files:**
  - `packs/catalog/app/queries/catalog/collection_grid.rb`, `season_shelf.rb` — whole-season grid only; `SeasonShelf.relation` removed.
  - `app/models/set_search.rb` — `SetSearch.in_kind`, the kind-scoped finder (one query).
  - `app/controllers/library_controller.rb`, `concerns/collection_grid_loading.rb` (`SET_KINDS`, `MAX_PAGE`, `page_param`), `concerns/set_album_loading.rb`, `cards_controller.rb` — the set group's loading; set grid and `named_grid` removed.
  - `app/views/library/{cards,_collection,_filters,_grid,_set_filter}` — the page, the RAPPORT-only column, the set group; `app/helpers/collection_helper.rb` trimmed.
  - `app/frontend/controllers/collection_filters_controller.ts`, `app/frontend/lib/collection_filters.ts` (+ test) — set chips reloaded in their frame.
  - `app/frontend/styles/collection.css`, `config/locales/{en,fr}.yml` — set group styles and strings; dead styles and keys removed.
  - Deleted: `concerns/shelf_loading.rb`, `library/_set_list`, `library/_set_row`, `Catalog::SetTotals`, `Game::SetProgress` (+ test), `Game::HeldCards`.
  - Tests: `library_controller_test.rb` (set group, every matrix row, query counts 13 / 7, 200 sets cost the same as 3), `cards_controller_test.rb`, `set_search_test.rb`, `collection_grid_test.rb`, `season_shelf_test.rb`, `collection_helper_test.rb`; `test/system/collection_set_test.rb` selectors only (not run).
- **Review:** quick lens; 4 patches applied (all low), 0 deferred, 2 rejected (low: stale `set_kind`/`set_q` on grid page links after a kind change, which only resets the transient search state; Enter in the card search no longer submits implicitly, which the 250ms auto-submit already covers).
- **Follow-up review:** false — no high and no medium patched (patched: 4 low).
- **Verification:** after the patches `bin/ci` green (2663 runs, 0 failures; rubocop, packwerk, brakeman, audits, i18n missing, typecheck, schema round trip, seeds); `npm run test:js` 359 passed; `npm run typecheck`, `bin/rails zeitwerk:check` green; `i18n-tasks unused` only the pre-existing `rate_limit.*`. `bin/ci`'s stray `package-lock.json` "license" line reverted.
- **Residual risks:** the frame-targeted set reload was never run in a browser (it relies on Turbo reading a removed submitter's `data-turbo-frame` and on `data-turbo-action` living on the grid frame); a set-chip response already in flight when a chip is checked can still land with that chip unchecked; `test/system/library_test.rb` still expects `.collection-sets` rows (stale since the entry ticket, not run).
