---
title: 'The all cards grid loads its next page on scroll'
type: 'feature'
ticket: 15
created: '2026-10-24'
status: 'blocked'
blocked_at: '2026-10-24'
blocked_reason: 'no subagents'
baseline_revision: '8dcacbf74d26517c0b7a5f4eb95dbb3ea42e003f'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The catalog (`/:locale/library/cards`, "Toutes les cartes") shows 60 cards a page and the reader must click the numbered page links to see more.

**Approach:** When the end of the grid nears the viewport, a reusable Stimulus controller fetches the page its `rel=next` link names as a Turbo Stream answer from `LibraryController#cards`, which appends the next page's server-rendered slots to the grid, replaces the page links with that page's and updates the grid's polite status line. The numbered links stay, and are the whole behaviour without JavaScript.

## Boundaries & Constraints

**Always:** the next page's URL is the `rel=next` link pagy already renders, so the search, filters and order carry over unchanged; markup arrives only by the Turbo Stream answer (no markup built in script); the status line is written by the server, its text different for every page so a screen reader announces each one; focus never moves: an answer that would replace the page links while the focus is inside them waits until the focus leaves them; an answer for a grid the filters have since reloaded is dropped, never appended; one request in flight at a time, aborted on disconnect; a failed or non-stream answer stops loading and leaves the links; Browser Back to the grid restores it from Turbo's cache with its appended cards at its scroll (no URL rewriting). Strings in `en.yml` and `fr.yml`, French plurals with `zero`. Static DOM ids only.

**Never:** no infinite scroll on the public profile's collection (`public_profiles/collection`) or a set's album, only the catalog: the controller is generic, but only `library/cards` opts in; no "load previous" upward; no change to Pagy's configuration, `GRID_SIZE`, the card detail's walk or `history_back_controller.ts`; no React; no `style` attribute; no new `gameble:*` event; no comments beyond a one-line external constraint.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Scroll to end | 150 cards, page 1 shown, reader scrolls near the page links | slots 61–120 appended, then 121–150; links show the current page; status "Cards 61 to 120 of 150 shown." | — |
| Last page | page links with no `rel=next` | nothing fetched | — |
| Filters active | `state[]`, `genre[]`, `q` in the URL | appended cards are the filtered page 2, same order | — |
| Filters reloaded mid-request | frame reloaded before the answer | answer dropped | abort or ignore |
| Focus in page links | answer arrives while a page link has focus | rendered once focus leaves the links | — |
| Failure | 429, network error, HTML answer | nothing appended, links stay | stop for that page |
| Stream past the end | stream request for a page past the last | nothing appended, links replaced | — |
| No JavaScript | plain GET with `page=2` | page 2 as HTML, links as today | — |

</intent-contract>

## Code Map

- `app/controllers/library_controller.rb` -- `#cards`: after `load_grid`, `respond_to` html (loads summary + set filter as today) and `turbo_stream` (skips them). Keep the `@season.nil?` early return.
- `app/controllers/concerns/collection_grid_loading.rb` -- `load_grid` sets `@grid_pagy`, `@slots`, `@grid_context`, `@seen_up_to`; read-only, do not change.
- `app/views/library/_collection.html.erb` -- shared with `public_profiles/collection.html.erb`; the `collection-results` turbo-frame holds the status `<p role=status>` (give it `id="collection-results-status"`), the grid and the `collection-seen` element. New local `scroll_pages` (default false) puts `data-controller="next-page"` and `data-action="focusout->next-page#focusLeft"` on that frame (it persists across filter reloads; its children are replaced).
- `app/views/library/_grid.html.erb` -- the `<ol>` gets `id="collection-slots"`; its `slots.each` body moves to a new `library/_slots.html.erb` (locals `slots, context, set_apart, new_badge`, keeps `CardStrings.new`).
- `app/views/library/_pages.html.erb` -- the `<nav>` gets `id="collection-pages"` and `data-next-page-target="pages"`.
- `app/views/library/cards.html.erb` -- passes `scroll_pages: true`.
- `app/frontend/lib/turbo.ts` -- `window.Turbo.renderStreamMessage` typing; reuse.
- `app/frontend/controllers/countdown_controller.ts`, `set_search_controller.ts` -- examples of thin controllers; `lib/in_view.ts` has no root margin, so do not reuse it.
- `app/frontend/controllers/history_back_controller.ts` -- already goes back through history to `/library/cards` whatever the query and focuses the card link on restore; must keep working with appended cards.
- `test/controllers/library_controller_test.rb` -- "no set or card-season id reaches the page" lists every `.collection [id]`: add the three new ids. "the grid's pages" shows the page tests' style.
- `test/system/library_test.rb`, `test/system/card_detail_test.rb` -- desktop window 1400×1400: the page links sit at ~2524 px on page 1, so a near-end margin of half the viewport (700 px) does not load on arrival; tests asserting 60 slots must stay green. The phone test "from a filtered, searched collection" scrolls to slot 60 and goes back: must stay green.

## Tasks & Acceptance

**Execution:**
- [ ] `app/frontend/lib/next_page.ts` -- pure module, no DOM: `TURBO_STREAM` media type, `NEAR_END_MARGIN = "0px 0px 50% 0px"`, `isTurboStream(contentType)`, and a per-links-element state class (waiting → loading → holding → spent) whose transitions say: fetch this URL now (once, only with a URL), render this answer now or hold it while focus is in the links, release the held answer when focus leaves, stop on failure.
- [ ] `app/frontend/lib/next_page.test.ts` -- vitest of every transition, including no URL, a second approach while loading, hold then release, failure, content types.
- [ ] `app/frontend/controllers/next_page_controller.ts` -- `pagesTargetConnected` creates the state for that element and observes it with its own `IntersectionObserver` (root margin from the module; created lazily since target callbacks run before `connect`); approaching fetches `a[rel=next]`'s href with `Accept: text/vnd.turbo-stream.html` and an `AbortController`; the answer is rendered with `window.Turbo.renderStreamMessage` only if the links element it came from is still connected; `pagesTargetDisconnected` of the current links aborts and drops; `focusLeft` checks after the focus has moved (`setTimeout` 0) whether `document.activeElement` left the links, then renders a held answer; `disconnect` aborts, clears timers and the observer.
- [ ] `app/views/library/_slots.html.erb`, `_grid.html.erb`, `_pages.html.erb`, `_collection.html.erb`, `cards.html.erb` -- as in the Code Map; extract the `collection-seen` element into `library/_seen.html.erb` (local `seen_up_to`) so the stream reuses it.
- [ ] `app/views/library/cards.turbo_stream.erb` -- with a season: append `library/slots` to `collection-slots` (when any), update `collection-results-status` with `library.grid.pages.shown` (count: slots, from, to, total: pagy count), append `library/seen` to `collection-results` when `@seen_up_to`, replace `collection-pages` with `library/pages`. Without a season: nothing.
- [ ] `app/controllers/library_controller.rb` -- the `respond_to` above.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `library.grid.pages.shown` (zero/one/other): en "Cards %{from} to %{to} of %{total} shown." / one "Card %{from} of %{total} shown."; fr "Cartes %{from} à %{to} sur %{total} affichées." / one "Carte %{from} sur %{total} affichée." / zero in both.
- [ ] `test/controllers/library_controller_test.rb` -- stream answer: page 2 as `turbo-stream` actions (append of the 60 page-2 slots in grid order, status text, links replaced with `rel=next` keeping `q`/filters), `Vary` includes `Accept`, filters respected, a visitor's stream, past the end appends nothing; HTML page 1 unchanged and carries `data-controller=next-page` on the frame; the ids test updated; the public profile's collection carries no `next-page`.
- [ ] `test/system/library_test.rb` -- with retrying matchers: on `/en/library/cards` with `state[]=missing&genre[]=roguelike&q=seed` (83 cards) scrolling the page links into view appends to 83 slots matching that grid's page 2, the status reads "Cards 61 to 83 of 83 shown.", no `rel=next` remains; on `/fr/library/cards` scrolling twice reaches 150 slots; opening an appended card and going back restores the grid with its appended cards at its scroll.

**Acceptance Criteria:**
- Given `/fr/library/cards` or `/en/library/cards` with 150 cards, when the reader scrolls to the end, then pages 2 and 3 append until 150 slots, and the page links end showing the last page.
- Given a search and filters, when the next page appends, then every appended card is one of that filtered grid's next page, in order.
- Given a card opened from an appended page, when the reader goes back (browser Back or ◀ Grille), then the grid shows its appended cards at the same scroll, focus on that card's link.
- Given JavaScript off, when the reader follows the page links, then each page shows as today.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

Why a Turbo Stream answer and not lazy frames: a frame per page would nest frames inside the `<ol>`; the architecture allows later markup by Turbo Stream, and a GET may answer one (it writes nothing). `respond_to` makes Rails add `Vary: Accept`, so the browser never serves one format for the other.

Why the status line's text names the range: a screen reader skips a live region rewritten with the same text, and "Cards 61 to 120" never repeats.

Known and out of scope (pre-existing with the numbered links too): under the `new` state filter with more than 60 new cards, page 1's watermark post makes page 2 judge new against the moved watermark.

## Verification

**Commands:**
- `npm run test:js` -- expected: all green, `next_page.test.ts` included
- `bin/rails test test/controllers/library_controller_test.rb test/controllers/public_profiles_controller_test.rb` -- expected: green
- `bin/rails test test/system/library_test.rb test/system/card_detail_test.rb` -- expected: green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/ci`, full `bin/rails test` -- expected: green

## Auto Run Result

Status: blocked
Blocking condition: no subagents. The plan is ready for development (full route, more than 100 lines across about fifteen files), but the session that ran it had no tool for launching a subagent, and step 3's full route requires an implementing subagent (as does step 4's review). No code was changed. To resume, run the build again from a session that can launch subagents, after setting `status` back to `ready-for-dev`; the plan above needs no change.
Environment notes for the next run, in a container without Docker: system tests need a chromedriver whose version matches the Chrome under `CHROME_BIN`, and a Chrome run as root needs `--no-sandbox`.
