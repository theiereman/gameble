---
title: 'Each card of a trade shows its edition''s average price'
type: 'feature'
ticket: '12'
created: '2026-11-13'
status: 'built'
baseline_revision: '368858f7d5f39b076e0f593c17d8d0e5a61e4a5e'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/mockups/trade-average-price.html'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Two friends trading cannot tell what the cards they swap are worth, though the market now prices every edition. Epic requirements R21 and R5.

**Approach:** Once the market has first opened, every card of a trade shows, centred under it, its exact edition's average price as a bare PiCoin amount, or "Sans vente": on the read-only board in every state, on the cards being edited, and in each card picker cell. Prices come from `Game::Market::EditionPrices`, read once per request.

## Boundaries & Constraints

**Always:**
- One price per card: the edition's average as a plain amount (a few-sales edition shows its amount with no "peu de ventes"), or "Sans vente" for no sale. A stack shows one copy's price, unmarked; its ×n is unchanged.
- Every board state shows prices: received, sent, concluded, closed, at today's price.
- While editing, a card placed from the picker arrives with its price; the price sits under the stepper and never changes with the quantity.
- Picker cell: the price under the card, above the copies available; an unavailable cell greys it with the rest.
- The price ends the accessible name where the card has one: the board card's link (", prix moyen 46 200 PiCoins" / ", sans vente") and the picker toggle. A few-sales price is voiced like a priced one.
- Before the market's first opening nothing changes on the board or the picker. A suspended market keeps showing prices.
- Prices are read once per request on the reading role; the GET writes nothing.

**Never:** a total or difference per side, a "peu de ventes" mention on a trade, a price sort or filter in the picker, a second price component, any change to trades' rules (no PiCoins, no fee), any change to the faces endpoint, script-built markup.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Priced card | Edition with 5 sales, average 46 200 | "46 200" with the PiCoin mark under the card | No error expected |
| Few sales | Edition with 2 sales, average 9 400 | "9 400" alone, no "peu de ventes" | No error expected |
| No sale | No row or no sale used | "Sans vente" | No error expected |
| Stack of two | Line quantity 2, unit average 8 100 | "8 100", ×2 badge unchanged | No error expected |
| Card placed while editing | Pick added from the picker | Line shows the pick's price under the stepper | No error expected |
| Not yet opened | No settings, or never opened | No price element on board, lines or picker | No error expected |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/market/edition_prices.rb` -- `EditionPrices.call(card_season_ids)`: `{}` before the first opening, else a `Price` for every id. Reuse as is.
- `app/components/average_price_component.rb`, `.html.erb` -- draws one state; gains an option that drops the few-sales mention (default keeps today's behaviour for the card detail, collection and market).
- `app/helpers/average_price_helper.rb` -- `average_price_words(price)`; gains the same option.
- `app/helpers/card_details_helper.rb:64-73` -- `card_detail_open_label` / `link_to_card_detail(price:)` already append the words; thread the option through.
- `app/controllers/trades_controller.rb` -- `index`/`show`/`new`/`edit` load `@cards` (views by card-season id, every listed trade and suggestion) and, when editing, `@picks` (views of both holdings). Load `@prices` once from `@cards.keys | @picks.keys`. 218 lines; stay under 400.
- `app/helpers/trades_helper.rb` -- `BoardPick` (add `price`), `trade_board_locals` and `trade_draft_editor` / `trade_board_editor` / `trade_board_side` (take `prices:` and pass it to picks and to the board locals), `trade_pick_label` (append price words).
- `app/views/trades/show|index|edit|new.html.erb` -- pass `prices: @prices` to `trade_board_locals` / `trade_draft_editor`.
- `app/views/trades/_board.html.erb` -- passes `prices` to both `trades/side` renders.
- `app/views/trades/_side.html.erb` -- read-only cards: price after the face (outside the link), price into `link_to_card_detail`.
- `app/views/trades/_line.html.erb` -- edited card: a price slot after the stepper; filled server-side from `line.pick.price`, hidden and empty in the template (`line: nil`).
- `app/views/trades/_pick.html.erb` -- picker cell: price in `.trade-pick__foot` before the available count.
- `app/frontend/controllers/trade_board_side_controller.ts` -- `render(view, faceFor)` / `fill`: also fill an empty hidden price slot from a `priceFor(key)` callback.
- `app/frontend/controllers/trade_board_controller.ts` -- passes `faceFor` to sides (`renderSide`); add `priceFor` that clones the `.average-price` element of the pick with that key from `cardTargets`. 372 lines: keep the addition under 10 lines.
- `app/frontend/styles/trades-board.css`, `trades-picker.css`, `trades-responsive.css`, `average-price.css` -- `.trade-card--editing .stepper` is absolute at the card's foot (`bottom: -space-4`); on the phone it is `position: relative` in flow.
- Tests: `test/controllers/trades_controller_test.rb` (64K; add a separate `test/controllers/trade_prices_test.rb` instead), `test/components/average_price_component_test.rb`, `test/helpers/average_price_helper_test.rb`, `test/system/trade_board_test.rb` (picker and placed-line journey to extend). Seeds: `open_market!(first_opened_at: 1.day.ago)` from `test/support/market.rb`, `Game::Market::EditionPrice.create!(card_season_id:, average:, sales_used:)` as in `test/controllers/cards_average_price_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `app/components/average_price_component.*`, `app/helpers/average_price_helper.rb`, `app/helpers/card_details_helper.rb` -- an option to drop the few-sales mention, threaded to the link label -- one component for every price
- [x] `app/controllers/trades_controller.rb` -- `@prices` in index, show, new and edit, one read
- [x] `app/helpers/trades_helper.rb` + `show|index|edit|new.html.erb` + `_board.html.erb` -- prices into board locals, `BoardPick#price`, pick label words
- [x] `_side.html.erb`, `_line.html.erb`, `_pick.html.erb` + CSS -- the price under each card, centred; under the stepper while editing
- [x] `trade_board_controller.ts`, `trade_board_side_controller.ts` -- a placed card's line copies the pick's price
- [x] Tests: component and helper (option), `test/controllers/trade_prices_test.rb` (the matrix on show, edit, new, a concluded trade, labels, nothing before the first opening), system test extension (placed card shows its price)

**Acceptance Criteria:**
- Given the market has first opened and Lea proposes a priced card, a few-sales card and a no-sale card for Hugo's stack of two, when Hugo opens the trade, then each card shows its amount or "Sans vente" with no "peu de ventes" and no total, and the stack shows one copy's price.
- Given Hugo counters and places a priced card from the picker, when the picker shows its cells and the line appears, then the cell and the line both show that price, the line's under its stepper.
- Given the market has never opened, when Hugo opens any trade or the picker, then no price element is rendered.

## Implementation Notes

- The option is `flag_few_sales:` (default `true`) on `AveragePriceComponent`, `average_price_words`, `card_detail_open_label` and `link_to_card_detail`; `TradesHelper#trade_card_price` renders the component with it off, the one call every trade view uses.
- The editor carries `priced:` (prices non-empty) so the line template holds its hidden empty `.trade-card__price` slot only once the market has first opened.
- Read-only board prices and picker prices are `aria-hidden` (the link label or the toggle label voices them); the edited line's price is not, since the line has no accessible name of its own. The clone `priceFor` takes is the inner `.average-price`, outside the picker's `aria-hidden` wrapper.
- The desktop stepper is anchored from `--card-height` only when the line shows a price; on the phone that same line puts the stepper in flow (the existing `.stepper { position: relative }` lost to `.trade-card--editing .stepper` on specificity, so the stepper was in fact absolute there).
- `test/controllers/trades_controller_test.rb` now requires `support/game_sets`: it included `GameSets` without requiring it, so it failed to load when run alone.

## Plan Change Log

## Review Triage Log

- Pass 1 (quick lens): 1 finding — high 0, medium 0, low 1, false 0, maybe-false 0.
  - low, patch: `trades-board.css`, the edited price's top margin applied only to lines with a stepper, so a one-copy card's price sat about 20px above a neighbour's in the same row; confirmed in `_line.html.erb` (no stepper when `line.max <= 1`). Fixed by giving every edited line's price the same margin, desktop and phone; `lint:css`, `trade_prices_test.rb` and `trade_board_test.rb` green after the fix.

## Design Notes

The price is not part of the face templates: the picker's `.trade-pick__card` has a fixed card size, so a price inside the face would overflow it, and the faces JSON endpoint would need prices too. The pick cell renders its price server-side; a newly placed line clones that same server-rendered `.average-price` element, which keeps markup out of script.

Stepper then price while editing: on desktop the stepper is absolute below the card; when the line holds a visible price, anchor the stepper just under the card (from `--card-height`) and give the price room below it. On the phone the stepper is in flow, so DOM order (face, stepper, price) already gives card, stepper, price; reset any desktop offset there.

## Verification

**Environment:** work only in the worktree `/home/teyermann/projets/gameble/.claude/worktrees/build-41-12` (branch `build/41-12`); the main checkout holds another session's uncommitted work and must not be touched. Run tests there with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w4112 CHROME_BIN=/usr/bin/chromium`; that database is already prepared.

**Commands:**
- `bin/rails test test/controllers/trade_prices_test.rb test/controllers/trades_controller_test.rb test/components/average_price_component_test.rb test/helpers/average_price_helper_test.rb test/controllers/cards_average_price_test.rb test/controllers/library_prices_test.rb` -- expected: green
- `bin/rails test test/system/trade_board_test.rb test/system/trades_test.rb` -- expected: green
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bin/rubocop` on touched files -- expected: no finding
