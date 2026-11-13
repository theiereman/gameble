---
title: 'Entrust and sale grids page from the server, with filters and infinite scroll'
type: 'feature'
ticket: ''
created: '2026-11-13'
status: 'done'
baseline_revision: '13f81b2371d2a27fcc61f00a6569748bd83a9e71'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** "Confier" and "Mettre en vente" render every free edition a player holds. Production's largest collection has 5,667, which means about 2 s of server render, about 30 MB of HTML and over 11,000 Stimulus controllers. Ticking a card takes about 0.5 s in Firefox. On "Confier", the quantity steppers also draw over the bottom recap bar.

**Approach:** Both grids show one server page of cards, sorted as today and filtered by the server (search, rarity, doubles), and load further pages by infinite scroll through the existing `next-page` controller. "Confier" keeps its selection across pages and filter changes, and gets a "select all" action. The cards in these two grids lose their tilt.

## Boundaries & Constraints

**Always:**
- Same order as today: value descending, then season, title, ref.
- What the entrust operation receives and refuses is unchanged.
- The preview keeps applying the operation's rule, counting copies in list order.
- Filters live in the URL query, and the back button restores them.
- Keyboard navigation and the screen-reader statuses keep working on the loaded cells.
- Includes the uncommitted Stimulus outlet patch and the change-only DOM writes already in the tree.

**Decisions (author, 2026-11-13):**
- "Select all" on "Confier" ticks every edition matching the current filters, loaded or not, at one copy each. The doubles filter already narrows it to editions held twice or more.
- The grid scrolls infinitely, with no page links shown.

**Never:**
- No React.
- No markup built in script; new cells come from the server, through turbo streams.
- No change to `EntrustCards`, `ListCard`, auction or cap rules.
- No database migration unless an index is proven missing.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Large collection | 5,000+ free editions | First page renders the first 60 cards; scrolling near the end appends the next 60 | Failed fetch leaves the next link for a retry (existing `NextPage`) |
| Filter change | Rarity "common" ticked | Grid is replaced by page 1 of commons; the count of matches is shown | Empty result shows the existing "no match" notice with clear-filters |
| Selection survives | 3 cards ticked, then filter changed so they are not loaded | Recap still lists the 3 and the form still posts them | — |
| Select all | Filter "common", 1,800 matches, 60 loaded; click "select all (1,800)" | All 1,800 ticked at one copy each (ticks already set keep their count); recap shows the first lines plus "and N more"; gauge and total update once | Editions with 0 free are skipped; a failed fetch leaves the ticks unchanged and says so |
| Sale choice survives | Card chosen, then filter hides it | Fields and summary keep the chosen card | — |
| Card-only entry | `/market/entrust/cards/:slug` or `/market/sell/cards/:slug` | Unchanged: only that card, no paging | — |
| Refused post | Entrust refused | The page re-renders page 1 with the posted filter and the ticks kept | — |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/market/entrustable_copies.rb` and `sellable_copies.rb` -- they load every row, then `CardViews` for all of them, and sort in Ruby. Move filtering (query on the localised or fallback title, rarities, `quantity >= 2` for doubles), ordering and `LIMIT`/`OFFSET` into SQL. The value order is `CASE rarity` built from `settings.entrustment(rarity)`; the sale side orders by rarity tier. Return the total count, and call `CardViews` only for the page's ids. `resolve` stays as it is.
- `app/controllers/market/entrustments_controller.rb` --
  - `load_page` gets paging through `pagy(:offset)` (the `CollectionGridLoading::GRID_SIZE` pattern, 60) and a `format.turbo_stream` answer for further pages and filter reloads.
  - `posted_filter` also reads the GET params.
  - `most_valuable_first` currently loads every copy: sort the posted lines by settings value, season, title and ref instead.
  - `ticked_on` has to keep posted ticks that are not on the page, so the recap still renders them.
- `app/controllers/market/sales_controller.rb` -- same paging and filters. `sale_prices` only for the page's refs. The chosen ref is kept even when it is off the page.
- `app/views/market/entrustments/_grid.html.erb`, `_cell.html.erb`, `_filters.html.erb`, `new.html.erb`, `create.turbo_stream.erb`; `app/views/market/sales/_grid.html.erb`, `_cell.html.erb`, `new.html.erb` -- the grids gain the `next-page` controller and a pages nav, reusing `library/_pages` or a copy of it with the market ids. The filters become a GET form targeting the grid.
  - The posted `copies[ref]` inputs move out of the cells into one form container, cloned from a server `<template>`, so that off-page ticks are posted.
  - The recap renders at most about 30 lines, plus an "and N more" line.
  - The cell keeps `data-*` for its copy.
- `app/components/card_component.rb` and `.html.erb` -- add a `tilt: true` keyword; these two grids pass `tilt: false`. Without tilt there is no `tilt` controller and no glitter target.
- `app/frontend/lib/entrust.ts` --
  - `copies` becomes the known copies, by ref, merged as cells connect (`cellTargetConnected` in `entrust_controller.ts`). Visibility comes from the server, so `visible` and `matches` go.
  - `preview` sorts the ticked copies by value, season, title and ref, not by DOM order.
  - Add `selectAll(state, copies)`: one copy each, existing counts kept.
- Select all -- a GET `market/entrust/matching`, with the same filter params and a Pundit check like `new?`. It answers JSON rows `{ref, title, rarity, season, free, owned, value}` for every match. The button shows the match count rendered with the page.
- `app/frontend/controllers/entrust_controller.ts`, `entrust_grid_controller.ts`, `entrust_filters_controller.ts` -- filters submit the GET form, debounced for search, instead of filtering in the client. The grid renders only the cells that connected or changed. Add the select-all action and button.
- `app/frontend/controllers/listing_form_controller.ts`, `listing_grid_controller.ts`, `app/frontend/lib/listing_form.ts` -- editions are merged as cells connect, and the chosen edition is kept when its cell leaves. The sale filters reuse the entrust filters partial, generalised.
- `app/frontend/controllers/next_page_controller.ts`, `app/frontend/lib/next_page.ts` -- reuse them as they are.
- `app/frontend/styles/market-entrust.css` -- `.entrust-cell { isolation: isolate; }` so the stepper (`z-index: 5`) no longer draws over the dock. Add `content-visibility: auto` with an intrinsic size on the cells of both grids.
- Tests: `test/controllers/market/entrustments_controller_test.rb`, `sales_controller_test.rb`, `test/domains/game/market/*copies*_test.rb`, `app/frontend/lib/entrust.test.ts`, `listing_form.test.ts`, the controller tests, and `test/system/market_entrust_test.rb` and `market_listing_test.rb`, which use the client filters and must follow the server filters.

## Tasks & Acceptance

**Execution:**
- [ ] The two copies queries -- SQL filter, order, limit and offset, count; card views for the page only -- the main server cost.
- [ ] `card_component` -- a `tilt:` option, defaulting to true.
- [ ] The two controllers and their views -- paging, a turbo-stream page answer, GET filters, ticks kept off the page, cheap `most_valuable_first`.
- [ ] Entrust frontend -- known copies merged on connect, preview in value order, the inputs container, a capped recap, select all, server filters.
- [ ] Sale frontend -- editions merged on connect, the chosen edition kept, the filters partial.
- [ ] CSS -- isolation on cells, `content-visibility`.
- [ ] Tests -- query paging and filters, controller paging and turbo stream, ticks kept off the page, the matching endpoint, the JS state (merge, order, select all), and the two system files.

**Acceptance Criteria:**
- Given a player with 5,000 free editions, when they open "Confier" or "Mettre en vente", then the response holds at most 60 cards and the server renders it in well under 300 ms locally.
- Given the stepper of a ticked card scrolled under the recap bar, when the bar is shown, then the bar draws over the stepper.

## Implementation Notes

- `content-visibility` sits on the card art, not the cell: on the cell it clipped the tick badge and ring.
- Filter reloads use a turbo frame with a full HTML response, as the library does. Infinite-scroll pages use turbo streams.
- The selection is posted as one `selection` field (`ref=copies` pairs), because Rack refuses more than 4,096 fields. The entrust result panel is capped at 30 stayed lines.
- Search folds accents in SQL (`normalize(…, NFD)` plus stripping the combining marks), with no migration.
- The frame no longer uses `data-turbo-action="replace"`. That promoted each filter reload to a Turbo visit, whose view transition (`<meta name="view-transition">`) swallowed a click made right after the reload, which was the flaky entrust system test. `copy_filters_controller#reloaded` now updates the URL with `history.replaceState`.

## Verification

**Commands:**
- `bin/rails test test/controllers/market test/domains/game/market` -- expected: green.
- `npm run test:js`, `npm run format:check`, `npm run lint:css` -- expected: green.
- `bin/rails test test/system/market_entrust_test.rb test/system/market_listing_test.rb` -- expected: green.
- `bin/ci` -- expected: green.
- `bin/rails zeitwerk:check` -- expected: green.

**Manual checks:**
- Headless Chrome on the 408-card dev player, with the profiling scripts in the scratchpad: the click cost and the visit cost go down.
