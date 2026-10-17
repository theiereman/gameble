---
title: 'Trade picker filters'
type: 'feature'
ticket: 'story-trade-picker-filters'
created: '2026-10-07'
status: 'done'
baseline_revision: '0bb5424eb49e66823bb71cf8a03b3c3a0ba9d4cf'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The trade board's card picker lists every card a side can place in one grid, with no way to narrow it. A large collection forces scrolling and keyboard-walking through the whole grid to find a card.

**Approach:** Add a title search and rarity chips at the top of the picker, filtering the grid client-side with the same wording and look as the collection filters. Rarity reaches the island through the card props.

## Boundaries & Constraints

**Always:** Filter state is local to the picker and never touches the selection: a placed card stays placed while filtered out. Cards are identified by `key`, never by index, so roving focus and toggling keep working on the filtered list. OR within rarities, AND with the search. Strings in both `en.yml` and `fr.yml` under `trades.island.strings`, with a matching `TradeBoardStrings` field. No `style` attribute in server HTML, no planning ids in code.

**Never:** No new `gameble:*` event, no server round trip, no sorting UI, no genre/season/availability filter. Do not change the board's counter form, the selection limit or the quantity stepper.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Search | Typing part of a title, any case or accent | Grid shows matching cards only, in server order | No error expected |
| Rarity | One or more chips on | Grid shows cards of those rarities | No error expected |
| No match | Filters exclude every card | Grid replaced by a no-match message and a clear action | Selection and PLACER unaffected |
| Selected card hidden | A placed card is filtered out | It stays in the selection and the count | No error expected |
| Clear | Clear action | Search and chips reset, focus lands on the search field | No error expected |

</frozen-after-approval>

## Code Map

- `app/helpers/trades_helper.rb` -- `trade_island_side` (l.127-145) builds each card hash; add `rarity` from `Catalog::CardView#rarity`.
- `app/frontend/components/TradeBoard.tsx` -- `TradeCard` and `TradeBoardStrings` types (l.9-59): add `rarity` and the filter strings.
- `app/frontend/components/TradePicker.tsx` -- grid, `active` index, `pick(index)`, `onGridKeyDown` all index into `side.cards`; rework to index into the visible list and map back to `card.key`. Empty state at l.69-98 gets a third, no-match case.
- `app/frontend/lib/trade_board.ts` (+ `.test.ts`) -- pure logic home; add a card filter function here.
- `app/frontend/lib/card_types.ts` -- `RARITIES` list and type, for the chip order.
- `app/views/library/_filters.html.erb`, `app/frontend/controllers/collection_filters_controller.ts` -- markup and behaviour to mirror (chips, 250 ms typing pause, IME composition guard). Not reusable directly.
- `app/frontend/styles/collection.css` (`.filter-chip*`, `.filters*`) and `trades.css` -- reuse chip classes, add only the picker layout.
- `config/locales/en.yml`, `fr.yml` -- `trades.island.strings.*`; rarity labels from `catalog.rarity.*`, wording from `library.filters.*`. French plural keys need a `zero` form.
- `test/system/trades_test.rb` -- `pick_toggle` helper l.113, picker tests l.115, l.176, l.220.

## Tasks & Acceptance

**Execution:**
- [ ] `app/helpers/trades_helper.rb` -- add `rarity` to each card hash -- the island needs it to filter
- [ ] `app/frontend/lib/trade_board.ts` + `trade_board.test.ts` -- pure `filterCards(cards, query, rarities)`: accent- and case-insensitive title match, OR over rarities -- unit-test every matrix row
- [ ] `app/frontend/components/TradeBoard.tsx` -- extend types with `rarity` and strings
- [ ] `app/frontend/components/TradePicker.tsx` -- search field, rarity chips, clear action, no-match state, key-based focus and toggle over the visible cards -- keep one tab stop and arrow-key navigation
- [ ] `app/frontend/styles/trades.css` -- filter bar layout inside the picker, phone sheet included -- reuse `.filter-chip*`
- [ ] `config/locales/en.yml`, `fr.yml` -- search label and placeholder, rarity group legend, clear, no-match copy, result count with `zero`
- [ ] `test/system/trades_test.rb` -- filter by title and by rarity, hidden card stays placed, no-match and clear -- retrying matchers only

**Acceptance Criteria:**
- Given the picker open on a mixed collection, when I type part of a title, then only matching cards remain and arrow keys walk the remaining cards.
- Given a placed card, when a filter hides it, then PLACER still submits it and the count still includes it.
- Given filters matching nothing, when I clear them, then the full grid returns and the search field has focus.

## Implementation Notes

## Plan Change Log

## Review Triage Log

Pass 1 (quick): 0 high, 1 medium, 1 low, 4 false/maybe-false.

- medium, patch: all-reserved message and no-match message rendered together. Real in TradePicker.tsx; the no-match case now yields to the all-reserved state.
- low, patch: one-shot reads of focus in the new system test. Replaced with retrying `:focus` matchers.
- low, rejected: no debounce or IME guard. Filtering is local and cheap, and the fix adds state and timers.
- false: arrows after a title search have no path from the search field. Tab reaches the grid's single tab stop, then arrows walk the visible cards, which is the specified behaviour.
- false: the clear action is outside the no-match paragraph. It shows whenever a filter is active, so it is present in that state.
- maybe-false: phone sheet height with the filter bar. Needs a manual check at phone width; not settled by the diff.

## Design Notes

Filters are deliberately limited to title and rarity: they are the two attributes a player recognises a card by, and rarity already has labels and chip styling. Availability and genre can follow if wanted.

## Verification

**Commands:**
- `npm run test:js` -- expected: all pass
- `bin/rails test && bin/rails test:system TEST=test/system/trades_test.rb` -- expected: all pass
- `bin/rails zeitwerk:check && bundle exec packwerk check && bundle exec i18n-tasks health` -- expected: no offences

**Manual checks (if no CLI):**
- On a phone-width viewport the filter bar fits the sheet without horizontal scroll and the grid keeps scrolling.
