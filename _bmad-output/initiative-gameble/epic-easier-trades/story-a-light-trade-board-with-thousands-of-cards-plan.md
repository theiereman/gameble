---
title: 'A light trade board with thousands of cards'
type: 'feature'
ticket: '4'
created: '2026-10-19'
status: 'built'
baseline_revision: '5bf2a4dd210bc08c216361b0a04656461ebe44ef'
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

**Problem:** The TradeBoard island's props carry a server-rendered `card-s` face for every card both players hold, and the picker renders every one of them at once. Measured on seeded players holding 3,000 distinct cards each (4,000-card season), the counter page weighs 21.0 MB of HTML (385 KB gzipped), takes 1.25 s on the server, and at 390 px with a 4× CPU slowdown the friend's picker takes 8.8 s to open and 1 to 9 s per filter change (issue 63, point 4; the deferred page weight item).

**Approach:** Props keep every card's data and the per-card counts but no face, except the faces of the cards already on the sides' lines. The picker renders matches a page at a time (more as the list nears its end, or as the keyboard moves past it) and fetches the faces of what it renders from a new GET endpoint returning `CardComponent` faces by card key; the board keeps every fetched face for its lifetime.

## Boundaries & Constraints

**Always:**
- Faces stay rendered only by `CardComponent` (`size: :s`) on the server; the island inserts the HTML as today.
- The new endpoint is a GET on `TradesController` (`faces`), authorized by `TradePolicy#faces?` (a signed-in player), writing nothing, answering JSON `{ "faces": { key => html } }` keyed by `trade_card_key` (`"<slug>--s<season number>"`), for published card-seasons only; unknown, malformed or draft keys are left out; at most `FACES_PER_REQUEST` keys are read per request, the rest ignored. No database id in the request or the answer.
- Props carry per side every held card's `key`, `title`, `rarity`, `owned`, `reserved`, `max`, `copies`, `otherCopies` (no `face`), plus one `faces` map for the cards on both sides' `lines`, the endpoint's URL and its per-request limit. Filters, match count, selection, limits, draft restore and sending work on the full card list as today.
- A card whose face has not arrived keeps its slot's size with an empty placeholder and stays pickable; a failed request leaves placeholders and is asked again the next time those cards are rendered; one key is never requested twice at once.
- The picker renders the first page of matches, then the next page when the end of the rendered list nears the visible area of the scrolling body, and enough pages to hold any index the keyboard moves to (End, arrows) before focusing it; a filter change starts again from the first page.
- Every pure step (paging arithmetic, which keys to fetch, batching, the request URL) is a function in `app/frontend/lib/` with vitest coverage.
- English, no planning ids or explanatory comments in code, no `style` attribute, no new `gameble:*` event, no browser storage.

**Never:** No client-side face rendering, no change to filters, chips, counts, operations or `Game::HeldCopies`, no new island, no endpoint returning holdings, no change to the read-only board HTML (`readHtml`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Page load | counter page, 3,000 + 3,000 held cards | props without per-card faces; faces only for the lines' cards | — |
| Open picker | 3,000 matches | first page rendered, its faces requested in batches ≤ limit; count reads 3,000 | — |
| Scroll to end | end of rendered list nears view | next page rendered and its missing faces requested | — |
| Keyboard End | focus in grid, End | pages added to reach the last match, which gets focus | — |
| Filter change | chip toggled | first page of the new matches rendered; known faces reused, missing ones requested | — |
| Reopen | picker closed and reopened | already fetched faces shown at once, no request for them | — |
| Draft restore | stored draft holds cards not on the lines | their faces requested on mount; placeholders until then | — |
| Fetch fails | network error or non-200 | placeholders stay, keys requested again next render | no error shown |
| Endpoint keys | known, unknown, malformed, draft-season keys; more than the limit | faces for the known published ones only, at most the limit | — |
| Signed out | GET faces | redirected like other trade actions | — |

</intent-contract>

## Code Map

- `app/helpers/trades_helper.rb` -- `trade_island_props` (:156-166) builds the props; `trade_island_side` (:174-195) puts `face: render(CardComponent.new(card: view, size: :s)).to_str` in every card hash: drop it, and add a `faces` map rendered for the keys of both sides' `lines` (`picks` already holds their views), `facesUrl: faces_trades_path`, `facesBatch: TradesController::FACES_PER_REQUEST` (or a constant beside `trade_card_key`). `trade_card_key(view)` (:112-114) is `"#{view.id}--s#{view.season_number}"` where `view.id` is the slug: add its inverse, parsing a key into `[slug, season_number]` or nil.
- `app/controllers/trades_controller.rb` -- add `faces`: `authorize :trade, :faces?`, read `params[:keys]` (array of strings, first `FACES_PER_REQUEST`, 60), resolve them to card-season ids through a Catalog query, `Catalog::CardViews.call(ids, locale: I18n.locale)`, render JSON `{ faces: { trade_card_key(view) => face html } }`. Not under `rate_limit` (writes only).
- `app/policies/trade_policy.rb` -- `def faces? = player?`.
- `config/routes.rb:96-105` -- `collection { get :faces }` in `resources :trades` (path `/:locale/trades/faces`, the token constraint keeps it off `show`).
- `packs/catalog/app/queries/catalog/` -- new query modeled on `published_card_season_id.rb` (one query for many `[slug, season_number]` pairs, published seasons, `rarity` not null), returning `{ [slug, number] => id }`; test beside the existing catalog query tests in `test/packs/catalog/`.
- `app/frontend/components/TradeBoard.tsx` -- `TradeCard` (:24-34) loses `face`; `TradeBoardProps` gains `faces: Record<string, string>`, `facesUrl: string`, `facesBatch: number`; holds the face cache for its lifetime (seeded from `props.faces`), a request function shared with the picker (in-flight keys tracked so none is asked twice), requests faces of restored draft lines missing from the cache on mount; line faces (:208) read from the cache, placeholder when absent.
- `app/frontend/components/TradePicker.tsx` -- `visible` (:71) stays the full match list for count and keyboard; render only the first `shown` matches (`useState`, reset to one page when `filter` changes); a sentinel after the rendered items observed with an `IntersectionObserver` rooted on `.trade-picker__body` with a generous root margin grows `shown`; `onGridKeyDown` (:92-102) grows `shown` before moving focus to an index beyond it (focus after render); request missing faces of the rendered cards; face at :235 from the cache, placeholder when absent.
- `app/frontend/lib/trade_faces.ts` (new) + `trade_faces.test.ts` -- page size constant, `shownFor(index)`/next page arithmetic, `missingFaces(keys, known, pending)`, `batches(keys, size)`, `facesUrl(base, keys)` (`keys[]=` params, encoded).
- `app/frontend/styles/trades.css:750-786` -- `.trade-pick__card` is fixed at `card-s`; add the placeholder look (sunken panel, control border) for an empty face in the picker and on a board line, and the sentinel (no height of its own beyond what observation needs).
- `test/controllers/trades_controller_test.rb:418-450` -- the counter props test reads `own.fetch("cards").last.fetch("face")`: assert instead that cards carry no `face`, that `faces` holds exactly the lines' keys with `card--s` HTML and no `style=`, and `facesUrl`/`facesBatch`; new tests for `GET faces` (known key → face, unknown/malformed/draft keys absent, over-limit keys cut, signed-out redirect, JSON has no `"id"` or `card_season_id`).
- `_bmad-output/initiative-gameble/deferred-work.md:89-91` -- add a `resolved:` line to the TradeBoard page weight item (before/after figures).

## Tasks & Acceptance

**Execution:**
- [x] `packs/catalog/app/queries/catalog/<new query>.rb` + test -- key pairs to published card-season ids in one query.
- [x] `app/helpers/trades_helper.rb`, `app/controllers/trades_controller.rb`, `app/policies/trade_policy.rb`, `config/routes.rb` -- props without per-card faces, line faces, endpoint.
- [x] `app/frontend/lib/trade_faces.ts` + `trade_faces.test.ts` -- paging, missing keys, batches, URL.
- [x] `app/frontend/components/TradeBoard.tsx`, `TradePicker.tsx`, `app/frontend/styles/trades.css` -- face cache, paged rendering, placeholders, keyboard growth.
- [x] `test/controllers/trades_controller_test.rb` -- props and endpoint tests as in the Code Map.
- [x] `_bmad-output/initiative-gameble/deferred-work.md` -- resolve the page weight item.

**Acceptance Criteria:**
- Given the seeded players (3,000 distinct cards each), when the four trade pages are measured, then each weighs under the threshold below and the figures before and after are recorded in Implementation Notes.
- Given Hugo at 390 px with a 4× CPU slowdown on the counter page, when he opens Lea's picker, scrolls to its end, toggles a chip, searches and clears, then each step stays within the threshold below and faces appear as cards come into view.
- Given a card picked whose face had not arrived, when Hugo places it, then the board shows it (face or placeholder, then face) and it is submitted.

## Implementation Notes

- Threshold (chosen from the measurement, seeded players with 3,000 distinct cards each on a 4,000-card season, development build, headless Chrome at 390×844, 4× CPU slowdown): each trade page under 2 MB of HTML and 100 KB gzipped, server time under 500 ms; the picker opens in under 500 ms, each search, chip or clear in under 300 ms, and no scroll frame over 100 ms.
- Before (baseline 5bf2a4d): `/trades` 21.0 MB (384.5 KB gzip, 1.30 s server), `/trades/:token` 21.0 MB (384.5 KB, 1.24 s), `/trades/new` 21.0 MB (382.3 KB, 1.31 s), counter 21.0 MB (384.7 KB, 1.25 s); on the counter page: DOMContentLoaded 2.28 s, open friend picker 8.8 s (3,000 cards in the DOM), search 1.0 s, clear 9.2 s, chip on 0.9 s / off 3.9 s, scroll worst frame 382 ms (mean 154 ms), close 1.0 s.
- After: `/trades` 1.48 MB (69.5 KB gzip, 127 ms server), `/trades/:token` 1.48 MB (69.5 KB, 112 ms), `/trades/new` 1.47 MB (65.9 KB, 110 ms), counter 1.49 MB (69.7 KB, 122 ms); on the counter page (medians of 3, two runs): DOMContentLoaded 0.33 s, open friend picker 47-51 ms (36 cards in the DOM), first 9 faces shown 180-220 ms after opening, search 43-48 ms, clear 87-89 ms, chip on 33-40 ms / off 41-43 ms, scroll worst frame 85-87 ms (mean 23-24 ms; single runs 79-107 ms), close 99 ms. Scrolling to the end grows the list a page at a time, End renders every match and focuses the last, a filter change starts again from the first page at the top, a reopened picker asks for no face it already has, and a card picked while its face request stalls is placed on the board with a placeholder and carried in the form.
- Re-measured by the orchestrating run on the same data (medians of 3): counter 1.49 MB / 69.7 KB gzip / 113 ms server; DOMContentLoaded 0.34 s, open 43 ms, first 9 faces 221 ms, search 43 ms, clear 83 ms, chip on 33 / off 44 ms, scroll worst frame 83 ms (mean 23 ms), close 94 ms. Every figure is within the threshold.
- Beyond the Code Map, both from the measurement: a filter change also scrolls the picker body back to the top (after End, a chip otherwise grew the list from 36 to 432 cards at once), and each picker card is a memoized `TradePick` (the worst scroll frame was 102 ms without it).
- Matrix audit: "Page load", "Endpoint keys" and "Signed out" are covered by `trades_controller_test.rb` and `published_card_season_ids_test.rb`; the paging arithmetic, the keys to fetch (known and in-flight skipped), batching and the URL by `trade_faces.test.ts`. The component wiring of "Open picker", "Scroll to end", "Keyboard End", "Filter change", "Reopen" and "Fetch fails" ran in headless Chrome at 390 px on the seeded database with throwaway scripts kept out of the repo (the repo has no React component tests; system tests are disabled). "Draft restore" was checked by reading only: the board requests the faces of every line missing from the cache whenever its lines change, mount included.

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 2 findings — high 0, medium 1, low 1, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` `TradePicker.tsx`: the active card (first placed line) is often beyond the first rendered page, so focus opened on card 0 while `activeKey` pointed elsewhere; once scrolling rendered that page the roving `tabindex` jumped there and arrow keys moved from it, hundreds of cards away — fixed: an effect re-anchors `activeKey` to the first rendered card whenever it is not among them (at opening and after a filter change), no extra page rendered; re-checked in Chrome at 390 px, focus and `tabindex=0` both on card 0 after opening.
  - `[low]` `[patch]` `trades_controller_test.rb`: `get … as: :json` with params is sent as a POST with a method override, so no test sent the client's real request, and the visitor test covered an HTML request while the client's JSON request gets a 401 `sign_in_required` — fixed: `faces_of` sends a plain GET with `keys%5B%5D=` query params and `Accept: application/json`; the visitor test asserts the JSON 401 `sign_in_required` and keeps the HTML redirect.

## Design Notes

Why fetch faces rather than page the card data: filters, the match count, the per-card counts and the stored draft's validation all need every held card's data, which costs about 1.4 MB raw and 61 KB gzipped for 6,000 cards without faces, against 21 MB with them; the faces are 93 % of the weight and nearly all of the render cost (3,000 `CardComponent` renders on the server, 3,000 face subtrees and `card-art` controllers in the browser). A virtualized grid was set aside: a paged list with a sentinel keeps the DOM small without fixed row heights, and the keyboard model only needs the list to grow.

```ts
export const PICKER_PAGE = 36
export const shownFor = (index: number) => Math.ceil((index + 1) / PICKER_PAGE) * PICKER_PAGE
export function missingFaces(keys: readonly string[], known: ReadonlyMap<string, string>, pending: ReadonlySet<string>): string[]
```

## Verification

**Commands:** (prefix every Rails command with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1803`; never run system tests)
- `npm run test:js` and `npm run typecheck` -- expected: all pass
- `bin/rails test test/controllers/trades_controller_test.rb test/packs/catalog` -- expected: pass
- `bin/ci`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` -- expected: green

**Manual checks:**
- The measurement scripts (scratch, outside the repo) re-run on the seeded scratch development database `gameble_dev_w1804`: page weights and picker timings against the threshold.

## Auto Run Result

- **Summary:** the TradeBoard island's props no longer carry a `CardComponent` face per held card, only the faces of the cards on the lines; the picker renders its matches 36 at a time (more as the list nears its end, or as the keyboard moves past it) and fetches the faces of what it renders from `GET /:locale/trades/faces?keys[]=…` (at most 60 keys, published cards only, JSON keyed by card key, no database id), keeping every fetched face for the board's lifetime; a card whose face has not arrived keeps its slot with a sunken placeholder.
- **Files:** `packs/catalog/app/queries/catalog/published_card_season_ids.rb` (+ test: key pairs to published card-season ids), `app/helpers/trades_helper.rb` (props without faces, line faces, key parsing, `FACES_PER_REQUEST`), `app/controllers/trades_controller.rb` (`faces`), `app/policies/trade_policy.rb` (`faces?`), `config/routes.rb` (`trades/faces`), `app/frontend/lib/trade_faces.ts` (+ test: paging, missing keys, batches, URL, answer parsing), `app/frontend/components/TradeBoard.tsx` (face cache and requests), `TradePicker.tsx` (paged rendering, memoized `TradePick`, keyboard growth, placeholders), `app/frontend/styles/trades.css` (placeholder, sentinel), `test/controllers/trades_controller_test.rb` (props and endpoint), `deferred-work.md` (page weight item resolved).
- **Measurement and threshold:** see Implementation Notes. Counter page 21.0 MB → 1.49 MB (384.7 → 69.7 KB gzipped), server 1.25 s → 0.11 s; at 390 px with a 4× CPU slowdown, picker open 8.8 s → 0.05 s, filters 0.9–9.2 s → 33–90 ms, worst scroll frame 382 → 88 ms. Threshold: < 2 MB and < 100 KB gzipped per page, < 500 ms server, open < 500 ms, each filter step < 300 ms, no scroll frame over 100 ms.
- **Review:** quick; 2 findings, 2 patched (1 medium, 1 low), none deferred or rejected. Follow-up review not recommended (no high patched, one medium).
- **Verification:** `bin/ci` green (2719 runs, 0 failures; one earlier run had 2 errors that did not recur in two later full runs and could not be captured); `npm run test:js` 450 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` clean; measurements re-run after the review fixes, all within the threshold.
- **For the author to check on staging:** open a picker on a real collection on a phone and watch faces fill in as you scroll (art drawn as before); the placeholder look while a face loads; a placed card's face on the board after PLACER; a draft restored after a reload shows its faces.
- **Residual risks:** the worst scroll frame (83–94 ms) is close to the 100 ms bound, its cost being 36 faces and their `card-art`/`tilt` controllers inserted at once; a face request that never settles keeps its keys marked in flight for the board's lifetime (no timeout); draft restore checked by reading only; timings come from a development build in headless Chrome with CPU throttling, not a real phone.

