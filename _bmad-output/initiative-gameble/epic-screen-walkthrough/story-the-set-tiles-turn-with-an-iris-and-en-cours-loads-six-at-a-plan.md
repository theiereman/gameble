---
title: 'The set tiles turn with an iris and EN COURS loads six at a time'
type: 'feature'
ticket: '36'
created: '2026-10-27'
status: 'built'
baseline_revision: 'ee4c06208fee7593fe1c3811016a1229ed954699'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/mockups/key-set-tile-motion-and-path.html'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The author's staging review (2026-10-27) found the set tile's turn too fast and ugly with a transparent gap halfway, the tier counts overflowing their squares, and the full EN COURS list heavy; the entry's search still showed the old result rows.

**Approach:** An iris with a luminous ring replaces the 3D turn (mockup A12 + A14), the verso's path becomes circles with a lit line and the required counts (B2), EN COURS and COMPLETED show six tiles and a Load more button, and the entry's search shows its results, for every set of the season, as the same tiles in place of the lists.

## Boundaries & Constraints

**Always:** Both faces server-rendered at one fixed size, the whole tile one link, the faces' visual parts `aria-hidden`, `aria-current` on the last-opened album, no `style` attribute in server HTML, GETs never write, a Pundit policy on every action, no database id in a URL, the same query count whatever the number of sets, strings in en.yml and fr.yml. The iris opens from the pointer's entry (centre on keyboard focus), fades under reduced motion, never turns on touch, and never leaves the tile empty. The gold frame sits on the one set of the whole EN COURS list closest to its next tier, on whichever page it is.

**Never:** Touch the hub's rows (`library/_set_progress_row`), add React, build markup in script, edit a frozen block or `pending-approvals.md`, edit `key-collection-in-progress.html`.

</intent-contract>

## Code Map

- `app/controllers/concerns/set_board_loading.rb` -- `load_set_tiles` pages a section six at a time (`TilePage`), `load_set_search` pages the results; `set_tiles` still serves the public profile.
- `app/controllers/library_controller.rb`, `app/views/library/{_set_tile_page,_set_tile_section,_set_results,more_tiles,more_results,in_progress}.html.erb` -- the pages, each next page a nested Turbo Frame holding the Load more link.
- `app/helpers/set_rows_helper.rb` -- `set_tier_path` with the lit share of each stretch.
- `app/views/library/_set_progress_tile.html.erb`, `app/frontend/styles/collection.css` -- iris, ring, B2 path.
- `app/frontend/controllers/set_tile_controller.ts`, `app/frontend/lib/set_tile_iris.ts` -- the iris origin.

## Tasks & Acceptance

**Execution:**
- [x] Iris and ring in CSS (`@property --iris-r/--iris-k`, mask on the verso, ring pseudo-element, brightness on the recto), reduced-motion fade, no `visibility`.
- [x] `set-tile` controller with a tested DOM-free lib: origin from the pointer, centre on focus-visible.
- [x] B2 path: circles, a `<progress>` per stretch lit piecewise (no style attribute, no JS), name and required count under each circle.
- [x] Six at a time: EN COURS and COMPLETED through `GET library/in-progress?section=&offset=`, the results through `GET library?q=&offset=`, each a frame request answering the next six and the next button; the first tile of a later page is autofocused.
- [x] Search: the old rows replaced by tiles (an unstarted set a tile with silhouettes, "No tier", a lit-nothing path, "Nothing collected yet" for a large one); the results hide the lists with `:has`.
- [x] Locale keys, DESIGN.md and EXPERIENCE.md, tests (request, helper, vitest, system).

**Acceptance Criteria:**
- Given a player with 12 sets in progress, when the entry loads, then six tiles show and Load more adds six, until none is left.
- Given the closest set is the 14th, when the second page loads, then it carries the gold frame and the first page has none.
- Given a query, then every matching set of the season, started or not, shows as a tile, six at a time.
- Given the iris is sampled each frame from start to end, then both faces are visible and opaque.

## Implementation Notes

- Author's decisions of 2026-10-27, as sent to the build: iris and ring from the cursor (A12 + A14); B2 with required counts only; six at a time with Load more.
- Decision recorded: COMPLETED is capped at six with the same button (a complete set's tile weighs as much as an in-progress one's).
- Decision recorded: the results keep `SetSearch` (cap 50 matches, then refine); Load more pages inside that cap.
- `script/check_markup_apis` does not exist in this tree; it could not be run.
- Query budgets: the frame costs 7 queries whatever the number of sets (also for a later page); the entry with a search 11, a later page of results 7, without a search 5.
- The lit line is one `<progress>` per node leading to the previous one, so the server alone computes it (`set_tier_path`'s `lit`) and no `style` attribute is needed.
- Dead after the change and removed: `.set-entry__list` CSS and the entry-row test helpers; the hub's row view, `last-album`'s `a.set-row` and the row CSS stay for the hub.

## Plan Change Log

### 2026-10-27 — The author's correction on the search (before the build was finished)
- Trigger: the coordinator relayed the author's correction: all sets must stay findable, including those not started and those of the catalogue.
- Amended: the first reading (the search filters the tiles of the page client-side, EN COURS loading every remaining set first, no catalogue search) is dropped. The server-side search over the whole published season stays, its results become tiles in place of EN COURS and COMPLETED, paged six at a time by the same Load more button.
- Known-bad state avoided: a set unfindable from the entry; loading every set of EN COURS when a query is typed (the weight problem the ticket removes).
- KEEP: the Turbo Frame paging, the query-count assertions, the tile as one link.
- The ticket's "Assumed by the agent" note (Load more adds six per click; typing loads every remaining set first; unstarted sets no longer found) is superseded: only the first assumption holds. `tickets.toml` is not edited; the author is told in the report.

## Review Triage Log

### 2026-10-27 — Review pass (thorough)
- verdicts: 30 findings — high 0, medium 3, low 12, false 0, maybe-false 0, rejected-as-negligible or out of scope 15 (counted with low)
- findings:
  - `[medium]` `patch` Iris frame test sampled visibility/opacity only, which the mask never changes — it now also asserts the mask gradient midway.
  - `[medium]` `patch` The out-of-range offset test had no set in progress, so it proved nothing — eight sets, `abc`, `-6` and `99999` now assert the first page, the first page and nothing.
  - `[medium]` `patch` `path_lit`'s equal-threshold branch unpinned — helper test added (tier asking as many cards as the previous one).
  - `[low]` `patch` A full-page GET with `offset` started mid-list (edge hunter) — the offset is read only on a frame request, test added.
  - `[low]` `patch` Redundant `MAX_OFFSET` clamp, filler `sets.size` assertion, multi-line comments and a badly re-wrapped header comment — removed or shortened.
  - `[low]` `defer` Offset paging can repeat or skip a set when standings change between clicks (blind and edge hunters) — a cursor on a stable token would need a new public key; the spec asks for an offset; tolerance recorded here.
  - `[low]` `defer` Loaded pages are lost on back navigation, no error state on the button — the entry is rebuilt on return; a follow-up if the author minds.
  - `[low]` `reject` Two buttons share the label "Load more" — each sits under its own heading, the same as the other lists.
  - `[low]` `reject` Autofocus on the first new tile also fires the focus iris, and for a pointer user scrolls to it — it moves focus off the vanished button, wanted.
  - `[low]` `reject` Hybrid touch devices match :hover, hover origin after a layout shift, `pointerleave` origin reset — negligible, the iris still opens, only from the centre.
  - `[low]` `reject` A set window dropped by `search_rows` (no standing, no figures), `offset` without `section`, a `set-more-` frame with a bad section answering the first load — not reachable from the page's own links; harmless.
  - `[low]` `reject` `tiles.shift` coupling, `path_lit` index arithmetic, unused `closest` nil for results, no test of the controller (DOM), colour-only path state (faces are `aria-hidden`, the sentence carries the state), CSS support of `@property`/`:has` (the repo targets current browsers), the seam between pages — style or hypothetical, the screenshots show a regular gap.
  - `[low]` `reject` Dead code claim (rows view, `.set-row__*`): the hub still uses them; `i18n-tasks unused` is clean.
  - Intent alignment: the profile takes the tile's iris and path through the shared partial and is covered by its unchanged system and request tests; no divergence worth a change.

## Auto Run Result

- Implemented: the iris and ring, the B2 path, six-at-a-time loading for EN COURS, COMPLETED and the search results, and the search showing every set of the season as tiles in place of the lists.
- Review: patches 5 (3 medium), deferred 2, rejected the rest, reasons above.
- Follow-up review recommended: false.
- Verification: `bin/rails test` 3213 runs green, `npm run test:js` 585, typecheck, zeitwerk, packwerk, rubocop, i18n-tasks missing and unused clean; system files library (15), collection_set (3), public_profile (3), shell (23) each run alone, green. Screenshots at 1400, 900, 760 and 390 px in en and fr, at rest, fully open and mid-iris, read.
- Residual risks: the iris's real hover path cannot run in headless Chrome (reports `hover: none`); only the pointer-origin and focus paths are exercised, plus a forced mid-transition frame test.

## Verification

**Commands:**
- `bin/rails test` (full, non-system), `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec rubocop`, `bundle exec i18n-tasks missing` and `unused` -- green
- `bin/rails test test/system/library_test.rb`, then `collection_set_test.rb`, `public_profile_test.rb`, `shell_test.rb`, one file at a time -- green
