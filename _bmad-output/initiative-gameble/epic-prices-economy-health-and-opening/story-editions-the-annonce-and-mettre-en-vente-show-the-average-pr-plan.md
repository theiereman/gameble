---
title: 'ÉDITIONS, the Annonce and Mettre en vente show the average price'
type: 'feature'
ticket: '41.3'
created: '2026-11-10'
status: 'draft'
baseline_revision: '3391a5dfad379884a7060791b614ced305b93eba'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-prices-economy-health-and-opening/epic-prices-economy-health-and-opening.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-prices-economy-health-and-opening/story-a-card-s-detail-shows-its-edition-s-average-price-kept-curre-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The card detail's ÉDITIONS, the Annonce and Mettre en vente give no hint of what an edition usually sells for, so a seller prices blind and a bidder cannot compare. Epic requirements R2, R3, R5.

**Approach:** Reuse story 1's `EditionPrices` and `AveragePriceComponent` unchanged: ÉDITIONS lists each owned edition with its price, the Annonce shows the listed edition's price with its sale count, and Mettre en vente shows each edition's price in its cell and the chosen edition's in the form, changing only when a cell is chosen.

## Boundaries & Constraints

**Always:**
- Nothing shows before the market's first opening: the queries answer nothing and the views draw no price, no slot and no template.
- ÉDITIONS draws one line per owned edition (rarity, season, price) once prices exist; before then it keeps its grouped rarity lines.
- The Annonce shows "Prix moyen" with the state and "Fondé sur <n> ventes" among the listing's facts, in every state of the listing, for visitors too.
- The form's price is server-rendered markup: one `<template>` per edition cell, cloned into a slot by the listing fields controller when the form state's chosen edition changes; the state module only reports which edition is chosen. The slot is also rendered server-side for an edition already chosen when the page loads.
- A cell's accessible name ends with its price words; the price never replaces the minimum shown in the cell.
- No database id in the page: the editions are keyed by the cell's token-like `ref` already used.
- Copy in `en.yml` and `fr.yml`.

**Never:** a change to `EditionPrices` or `AveragePriceComponent`, a price computed in the view or in script, markup built in script, the collection's sort or filter (story 4).

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The Annonce's price is read for the listing's edition at page load; the live refresh already morphs the page, so a sale elsewhere shows on the next refetch.
- `ListingByToken` gains the card-season id for the controller's lookup, which never reaches the HTML.
- A new `Catalog::EditionIds` query maps a card's editions to their card-season ids by season number, so the controller reads ids with one query rather than one per edition.
- The Mettre en vente sale page resolves the cells' ids through `EntrustableCopies.resolve`, which already maps a cell's `ref` to its card-season id in one query.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Two owned editions | Player holds S1 and S2 of a card, both sold | ÉDITIONS has one line each with its price | No error expected |
| Annonce, priced | Listed edition has 5 sales | "Prix moyen" with the amount and "Fondé sur 5 ventes" | No error expected |
| Annonce, no sale | No sale | "Sans vente", no count line | No error expected |
| Choose another edition | Player chooses the other cell in Mettre en vente | The form's price becomes that edition's | No error expected |
| Before first opening | Never opened | No price in ÉDITIONS, the Annonce, the cells or the form | No error expected |
| Refused post | Form re-rendered with a chosen cell | Slot holds the chosen edition's price | No error expected |

</frozen-after-approval>

## Code Map

- `app/controllers/cards_controller.rb`, `app/views/cards/_detail.html.erb`, `app/helpers/card_details_helper.rb` -- ÉDITIONS lines.
- `app/domains/catalog/app/queries/` -- the new editions-to-ids query.
- `app/controllers/market/listings_controller.rb`, `app/views/market/listings/show.html.erb`, `app/domains/game/app/queries/game/market/listing_by_token.rb` -- the Annonce's facts.
- `app/controllers/market/sales_controller.rb`, `app/views/market/sales/_cell.html.erb`, `_fields.html.erb`, `app/helpers/market_sales_helper.rb` -- cells and form.
- `app/frontend/controllers/listing_fields_controller.ts`, `app/frontend/lib/listing_form_view.ts` -- the chosen edition reaching the slot.
- `app/frontend/styles/market-sale.css`, `market-listing.css`, `card-detail.css`, locales -- style and copy.

## Tasks & Acceptance

**Execution:**
- [ ] Editions-to-ids query, ÉDITIONS lines with prices
- [ ] Annonce fact row
- [ ] Mettre en vente cells, templates, slot and the fields controller
- [ ] Copy in both locales
- [ ] Tests: component use, controllers, Vitest for the view, one system test

**Acceptance Criteria:**
- Given the first opening and a player with two editions of a card, when they open the card detail, the Annonce of a listing and Mettre en vente, then ÉDITIONS shows both prices, the Annonce shows the price with its sale count, and choosing the other edition changes the price in the form.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `npx prettier --check`, `npm run lint:css`, `npx tsc --noEmit`, YAML parse and en/fr parity, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
