---
title: 'The collection sorts and filters by average price'
type: 'feature'
ticket: '41.4'
created: '2026-11-10'
status: 'in-review'
baseline_revision: '89b6413ac8057b366ce0ff9ca6ad83e3e30db687'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-prices-economy-health-and-opening/epic-prices-economy-health-and-opening.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-prices-economy-health-and-opening/story-a-card-s-detail-shows-its-edition-s-average-price-kept-curre-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/story-players-search-and-filter-the-market-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Toutes les cartes and a player's collection cannot be ordered or narrowed by what a card is worth, so spotting the dear or the cheap cards means opening each one. Epic requirements R4, R5.

**Approach:** A `Game::Market` query joins the edition price table onto the collection's cards on the reading role and applies the price sort and range; `Catalog::CollectionGrid` is not touched. The PRIX group of the filter zone (the market's `filters/_price` partial, unchanged) gains a price-order choice beside the two fields; while sorted or filtered by price each card shows its price with story 1's `AveragePriceComponent`, ending its accessible name.

## Boundaries & Constraints

**Always:**
- Parameters `sort` (`price_asc`, `price_desc`), `min_price`, `max_price` (whole PiCoins); anything else is ignored, never an error. Before the market's first opening the sort, the group and the prices are absent and the parameters are ignored.
- The price compared per card: for a player's own or another player's collection, the highest average among the editions of the card that player holds, else the average of the card's tile edition (the published season's, or the held one); cards with no sale come last in both directions and never match a range.
- The price shows under a card, compact, only while the grid is sorted or filtered by price, and ends the card's accessible name with the state's words; a filter alone keeps the grid's usual order.
- `Catalog::CollectionGrid` stays free of `Game`; the price query takes the grid's relation and returns it joined, filtered and ordered. Reading role only; a GET writes nothing.
- The filter state goes through `collection_filters.ts` like the other groups: the PRIX group counts its non-empty fields and a chosen order in the active count and its pastille; a field or order change reloads the grid.
- The price parameters ride in the grid's context so paging, a card's back link and its ◀ ▶ keep them.
- Copy in `en.yml` and `fr.yml`.

**Never:** a change to the PRIX partial's markup or to the market filters, a price on the card face, a new migration, a database id in a URL or the page, a sort or filter on a set album or a trade picker.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The sort is two radio choices beside a default ("Récentes" is not named: the choice is "Prix moyen croissant" / "décroissant", none chosen keeps the order) inside the PRIX group's wrapper, not a new control.
- A range with a minimum above the maximum matches nothing, as the market's does; a card with no sale never matches any bound.
- A field submits on change (the grid reloads in its frame, so focus stays); a chosen order submits at once like a chip.
- The few-sales state is priced for ordering and filtering: it has an average.
- The displayed price comes from a second small query for the page's cards, sharing the join with the sort, so the page never recomputes a price in the view.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Sort descending | `sort=price_desc` | Dearest first, no-sale cards last | No error expected |
| Sort ascending | `sort=price_asc` | Cheapest first, no-sale cards still last | No error expected |
| Range | `min_price=5000&max_price=20000` | Only cards inside, ends included, each with its price | No error expected |
| Own collection | Player holds two editions of a card | The higher average is compared and shown | No error expected |
| Not owned | Card the viewer does not hold | The published season's edition average | No error expected |
| No filter | Neither sort nor range | No price under any card | No error expected |
| Before first opening | Never opened | No group, no pastille, parameters ignored | Ignored |
| Invalid | `sort=up`, `min_price=abc` | Ignored | Ignored |

</frozen-after-approval>

## Code Map

- `app/controllers/concerns/collection_grid_loading.rb` -- grid parameters, context, paging; gains the price choice.
- `app/controllers/cards_controller.rb` -- the card's ◀ ▶ over the grid reads the same choice.
- `app/domains/game/app/queries/game/market/` -- the new collection price query.
- `app/views/library/_collection.html.erb`, `_filters.html.erb`, `_filter_row.html.erb`, `_slots.html.erb`, `app/helpers/collection_helper.rb`, `app/helpers/card_details_helper.rb` -- the PRIX group, counts, pastille and the price under a card.
- `app/views/filters/_price.html.erb` -- reused unchanged.
- `app/frontend/lib/collection_filters.ts`, `app/frontend/controllers/collection_filters_controller.ts` -- the group's state and reload.
- `config/locales/en.yml`, `fr.yml`, `app/frontend/styles/collection-grid.css` -- copy and style.

## Tasks & Acceptance

**Execution:**
- [ ] `Game::Market::CollectionPrices` -- parse, apply to a relation, price the page's cards
- [ ] Grid loading, card ◀ ▶ and context carry the choice
- [ ] PRIX group in both filter layouts, counts, pastille, order radios
- [ ] Price under a card and in its accessible name
- [ ] `collection_filters.ts` and its controller, Vitest
- [ ] Copy in both locales
- [ ] Tests: query, controller, helper, Vitest, one system test

**Acceptance Criteria:**
- Given the first opening, when a player sorts Toutes les cartes by price descending and then keeps a price range, then the dearest edition comes first with no-sale cards last, the range keeps only the cards inside with their prices under them, and no price shows without the sort or filter.

## Implementation Notes

Built as planned; nothing was run. `Game::Market::CollectionPrices` holds the lateral join that picks, per card, the owner's most valuable held edition (else the grid's edition), applies the range and the order (no-sale last in both directions) and prices the page's cards. `CollectionGridLoading` reads the choice once per request (`market_state` is memoized and shared with the card detail) and puts it in the grid context so paging and the card's neighbours keep it. The PRIX group is `library/_price_filter` (order radios plus the market's `filters/_price` partial, untouched) wrapped in a `data-group=price` target; `collection_filters.ts` counts a chosen order and each filled bound and reloads the grid on an order or number change. Visitors' collection requests cost one more query (the market state); a signed-in player's cost none, the shell already reads it. Not covered by a test: another player's collection with the same sort (the code path is the same `load_grid`).

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `npx prettier --check`, `npm run lint:css`, `npx tsc --noEmit`, YAML parse and en/fr parity, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
