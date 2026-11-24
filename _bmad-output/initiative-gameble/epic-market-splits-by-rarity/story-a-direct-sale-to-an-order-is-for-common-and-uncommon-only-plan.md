---
title: 'A direct sale to an order is for Common and Uncommon only'
type: 'feature'
ticket: '3'
created: '2026-11-24'
status: 'built'
baseline_revision: '69c8facca0a457bbdf9b62786e2acb335aaf63d1'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/docs/design-system.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-market-splits-by-rarity/story-an-auction-opened-at-or-below-orders-turns-them-into-bids-plan.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Two editions of one card with different rarities share its orders: a Rare line's prefilled start and best-order figure may count an order a same-card Common or Uncommon line of the table serves first.
    evidence: |-
      The Rare line reads EligibleOrders.prices before the table's order draw; the operation never converts a served order, so the auction only opens with fewer converted orders. Needs two editions of one card at different rarities, which no fixture has.
    location: >-
      app/domains/game/app/queries/game/market/wanted_table.rb
    severity: low
  - summary: >-
      The Vos cartes voulues panel and the card detail still show the best order of a Rare and above copy, and its tile leads to a Mettre en vente with no banner.
    evidence: |-
      WantedCopies and the card detail read EligibleOrders.best for every rarity; the ticket names only Mettre en vente and the Confier wanted table.
    location: >-
      app/domains/game/app/queries/game/market/wanted_copies.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** A Rare, an Epic or a Légendaire can still be sold to a buy order in one press, from Mettre en vente's banner and from the Confier wanted table, so money and one press fill gaps that should be contested by named bidders.

**Approach:** `SellToOrder` and the table's `order` choice serve a Common or Uncommon only. The banner and VENDRE MAINTENANT show for those rarities only. The wanted table draws three choices for a Common or Uncommon line and two (ENCHÈRES, CONFIER) for a Rare and above, whose ENCHÈRES opens through `ListCard`'s conversion of orders, inside the table's one transaction.

## Boundaries & Constraints

**Always:** `SellToOrder` checks the market and the settings version first, then the rarity (`Failure(:direct_sale_not_for_rarity)`), and nothing moves on refusal. `ApplyWantedChoices` refuses an `order` line above Uncommon with `Failure([:invalid_choices, ...])` naming the line and the code, before it reads any drawn order. The table's auction step is `ListCard`'s (`OrderConversion`) inside the one transaction, entries in the one `Ledger.post`; one `WantedChoicesApplied` carries the converted rows under `converted`; its handlers treat them as `CardListed`'s do. Orders already served by the same validation are never converted. The order drawing (best first, each assigned once, one copy each) serves Common and Uncommon lines only. Every string in en.yml and fr.yml; tokens only; no planning ids; code reads without comments.

**Never:** build the shop cap. Touch `PlaceBid`, `CloseAuction` or `ListCard`'s conversion itself. Draw a hidden order token for a Rare and above line.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Direct sale of a Rare | Valid order token, open market, current version | Refused, nothing moves | `Failure(:direct_sale_not_for_rarity)` |
| Direct sale, stale version, Rare | Stale settings token | The version failure wins | `Failure(:amounts_changed)` |
| Order line on an Epic | `choice: order` with tokens | Whole table refused, nothing moves | `Failure([:invalid_choices, [Refused(line, :direct_sale_not_for_rarity)]])` |
| Auction line at or below an order | Rare, one order 900, start 800 | Listing led by the order at 800, order `bid`, PiCoins held once on the listing, one event with `converted` | None |
| Auction above every order | Rare, order 900, start 950 | Order stays open, no leader | None |
| Order served and auction in one table | Uncommon order line, Rare auction line | Served order is not converted | None |
| Rare line prefill | Orders 400 and 350 | ENCHÈRES at 350; no orders: average, else minimum; CONFIER only when the stamps cannot be paid and the copies fit under the cap | None |
| Common or Uncommon line | Any | Three choices, existing Prefill rule | None |

</intent-contract>

## Code Map

- `app/domains/game/app/models/game/market/direct_sale.rb` (new) -- `RARITIES`, `rarity?`, `edition?`: the one definition of what can be sold to an order in one press.
- `app/domains/game/app/operations/game/market/sell_to_order.rb` -- rarity step after `current_settings`.
- `app/domains/game/app/operations/game/market/apply_wanted_choices.rb` -- `direct_sale_only` before the drawn orders are checked; includes `OrderConversion`; `open_auctions` (listing, stamp, conversion per copy); orders settled before auctions open so a served order is never converted; `Applied` carries `converted`; the event carries it.
- `app/domains/game/app/operations/game/market/order_conversion.rb` -- reused unchanged (entry 2).
- `app/domains/game/app/queries/game/market/wanted_table.rb` -- `Line` gains `backing` (the eligible prices of a Rare and above line) and `direct?`, `best_price`; the order draw asks zero copies for a Rare and above line.
- `app/domains/game/app/events/game/market/wanted_choices_applied.rb`, handlers `order_notices.rb`, `wanted_refresh.rb`, `app/models/market_push_notice.rb`, `app/models/player_stream.rb` -- converted owners are noticed, refreshed and pushed for the table's event as for `CardListed`; `wanted_notices.rb` already skips converted owners.
- `app/controllers/market/sales_controller.rb`, `app/helpers/market_sales_helper.rb`, `app/views/market/sales/{_cell,_fields}.html.erb` -- the banner and its template only for a direct-sale edition; the orders line stays for every rarity.
- `app/controllers/market/wanted_choices_controller.rb`, `app/helpers/market_wanted_choices_helper.rb`, `app/views/market/wanted_choices/{_line,_result_row}.html.erb` -- two options for a Rare and above line, its group described by the backed note, the best order column from `best_price`, the result's "(led by a buy order at ...)"; `available` handed to the script.
- `app/frontend/lib/wanted_table.ts`, `app/frontend/controllers/wanted_table_controller.ts` -- `direct` on a line, `available` on the state, the Rare and above prefill, `choose` refuses `order` there.
- `config/locales/{en,fr}.yml` -- `errors.market.direct_sale_not_for_rarity`, `market.wanted_choices.new.backed_note`, `market.wanted_choices.result.led_by_order_html`.

## Tasks & Acceptance

**Execution:**
- [x] `direct_sale.rb`, `sell_to_order.rb`, `apply_wanted_choices.rb` -- rarity rules and the auction step with conversion
- [x] handlers, push, stream, event -- converted owners of the table's event
- [x] wanted table query, controller, helper, views, script, locales -- two choices above Uncommon, prefill, result line
- [x] sales controller, helper, views -- banner for Common and Uncommon only
- [x] tests: `sell_to_order_test`, `apply_wanted_choices_test`, `wanted_table_test`, `order_backed_auction_test`, handler, model and controller tests, vitest, `test/system/market_wanted_table_rarity_test.rb`; existing Rare direct-sale tests moved to an Uncommon

**Acceptance Criteria:**
- Given a Rare copy and an open order on it, when the holder presses VENDRE MAINTENANT's POST or `SellToOrder`, then it is refused with `:direct_sale_not_for_rarity` and nothing moves.
- Given a Rare line in the Confier wanted table with an order, when the table opens, then it has two choices, no À L'ORDRE radio, ENCHÈRES prefilled at the lowest order's price, and validating opens the auction with the order leading and the result line saying so.
- Given an Uncommon line with an order, when the table opens, then it keeps its three choices and one press sells to the order.

## Implementation Notes

- Reading of "CONFIER when the stamp cannot be paid or the cap rule applies" for a Rare and above line: the script walks the table in order with the funds (`available`) plus the proceeds of the lines before it; ENCHÈRES is prefilled unless the line's stamps exceed those funds and its copies fit under the cap left, in which case CONFIER. A line that does not fit under the cap stays ENCHÈRES (a copy over the cap would be skipped).
- A Rare and above line carries the prices of the eligible orders in `data-orders` with `data-direct="false"`; no order token is drawn or posted for it.
- Mettre en vente: `best_orders` only reads the direct-sale editions, so the banner slot, its template and VENDRE MAINTENANT never exist for a Rare and above; the `Aucun ordre d'achat` line is not drawn for them either.
- `SellToOrder` and the table refuse by `DirectSale.rarity?`; settled orders are written before the auctions open so `EligibleOrders` no longer lists them.
- Existing tests moved to an Uncommon because their premise (a Rare sold to an order) is gone: sell to order, apply wanted choices, wanted table, order notices, wanted refresh, order sale feed (an Epic can no longer be sold to an order, so the entries use an Uncommon above the threshold), sales and wanted choices controller tests, the direct sale, wanted copies and Confier wanted system tests.

## Plan Change Log

## Review Triage Log

### 2026-11-24 - Review pass
- verdicts: 32 findings - high 0, medium 0, low 29, false 3, maybe-false 0
- findings:
  - `[low]` `patch` (blind) the sales controller reads Catalog::CardSeason directly - moved into `DirectSale.edition_ids`.
  - `[false]` `reject` (blind) converted owners are not locked - `OrderConversion` takes `TradeLocks.players` itself after the seller's lock, as `ListCard` does.
  - `[false]` `reject` (blind) duplicate notices when a player is both buyer and converted owner - `NamedPlayers.of` feeds a `where(id:)` and `PlayerStream` notices go through `uniq`.
  - `[low]` `patch` (blind) `direct` parsed as `!== "false"` fails open - now `=== "true"`, the controller test markup carries it.
  - `[low]` `reject` (blind) `orders` means drawn or backing prices by `direct` - one script type, commented, a second field would duplicate the lists.
  - `[low]` `reject` (blind) the backed note is visually hidden - the intent says the group is described by it; the sighted reader reads the two radios.
  - `[low]` `reject` (blind) result line may misstate proceeds and reports one led listing for several copies - the first listing converts every reaching order, later copies convert none; the sentence is the author's wording.
  - `[low]` `patch` (blind) multi-line comments - the two script comments are now one line each.
  - `[low]` `reject` (blind) `DirectSale` is thin and queries once - one query per sale, no hot path.
  - `[low]` `reject` (blind) `direct_sale_only` masks other field errors - the whole table is refused either way; fixing the rarity lines first is the player's path.
  - `[low]` `reject` (blind) backing computed for every edition and not deduplicated by card - see the deferred same-card item; the cost is one query.
  - `[false]` `reject` (blind) switching from a banner edition to a Rare leaves a stale banner - `showIn` replaces the slot with nothing when no template exists for the ref.
  - `[low]` `reject` (blind) frontend test gaps - the new vitest cases and the confier system test cover the walk and the attributes; remaining cases are repeats.
  - `[low]` `reject` (blind) nested conditionals in `wanted_group_description` - three terms, covered by controller tests.
  - `[low]` `reject` (blind) file size - `script/check_file_sizes` passes.
  - `[low]` `reject` (edge) a Rare line's backing counts orders a same-card line serves first - deferred above, needs two rarities on one card.
  - `[low]` `reject` (edge) a lowest order under the current minimum is clamped so it stays open - same as Mettre en vente's prefill, which the entry-2 triage rejected.
  - `[low]` `reject` (edge) `proceeds` and `entrustedCopies` meet an `order` choice on a non-direct line - unreachable: such a line has no order radio and `choose` refuses it.
  - `[low]` `patch` (edge) a forged direct-sale POST on a Rare drew its refusal in the banner slot that does not exist - the slot falls back to the form when the edition is not direct.
  - `[low]` `reject` (edge) `seen_order` runs before the settings and rarity checks - a valid token passes it; a forged token on a Rare is refused as changed, which refuses all the same and moves nothing.
  - `[low]` `patch` (gap) no test serves an order and auctions another edition of its card in one table - added to `apply_wanted_choices_test.rb`.
  - `[low]` `patch` (gap) the prefill walk's auction-stamp and entrusted-proceeds terms are unpinned - two vitest cases added.
  - `[low]` `reject` (intent) CONFIER prefill reads "stamp unpayable or cap rule" as unpayable and fitting the cap - recorded in Implementation Notes; a copy over the cap would be skipped, so prefilling it would be wrong.
  - `[low]` `reject` (intent) lowest of all eligible orders rather than of the drawn ones - a Rare line draws none, and every order must convert.
  - `[low]` `reject` (intent) the system test validates the prefill instead of clicking ENCHÈRES, in English only - the radio is the prefilled choice; French strings are asserted in the controller test.
  - `[low]` `reject` (intent) the Rare line's best-order column shows the best backing price - the intent keeps the best order visible on the line.
  - `[low]` `reject` (intent) `@available` is added for the unpayable-stamp rule - needed to compute it in script.
  - `[low]` `reject` (intent) the table sorts by best order across rarities - the sort rule is unchanged by the ticket.
  - `[low]` `reject` (intent) result line reports the first led listing only - see above.
  - `[low]` `reject` (intent) Flow 13 is satisfied by the Confier system test re-pointed to an Uncommon - the docs were amended before this entry.
  - `[low]` `reject` (intent) error key and hidden note carry slightly different English wording - same French sentence; the key is a refusal, the note a description.
  - `[low]` `reject` (intent) the banner gating is tested at the controller and the direct sale system test, not the named system test - the entry names the table for its system test.

## Verification

**Environment:** Postgres on localhost:5433, `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w483`, `CHROME_BIN=/usr/bin/chromium`, `PARALLEL_WORKERS=4`; system tests one or two files at a time at most 2 workers.

**Commands:**
- `bin/rails test` -- expected: pass
- `bin/rails test test/system/market_wanted_table_rarity_test.rb test/system/market_confier_wanted_test.rb test/system/market_direct_sale_test.rb test/system/market_wanted_copies_test.rb test/system/market_order_backed_auction_test.rb` -- expected: pass
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/ci` -- expected: pass

## Auto Run Result

- Summary: `SellToOrder` and the table's `order` choice serve a Common or Uncommon only (`DirectSale`). The banner, its template and VENDRE MAINTENANT exist only for those editions. The Confier wanted table draws two choices for a Rare and above line, described by the backed note, prefilled ENCHÈRES at the lowest eligible order's price (else the average, else the minimum; CONFIER when the stamps cannot be paid and the copies fit the cap). Its auction step is `ListCard`'s conversion inside the one transaction, with one `WantedChoicesApplied` carrying `converted`, handled like `CardListed` for notices, refresh, push and stream; the result line says "(led by a buy order at ...)".
- Files: `direct_sale.rb` (new), `sell_to_order.rb`, `apply_wanted_choices.rb`, `wanted_table.rb`, `wanted_choices_applied.rb`, the order notices and wanted refresh handlers, `market_push_notice.rb`, `player_stream.rb`, the sales and wanted choices controllers, helpers and views, `wanted_table.ts` and its controller, en.yml and fr.yml, and tests (domain, model, controller, vitest, `test/system/market_wanted_table_rarity_test.rb` new).
- Review: thorough, four lenses. Patches applied: 6 (low). Deferred: 2 (low). The other findings are rejected with their reasons in the triage log. No follow-up review recommended; patched counts: high 0, medium 0, low 6.
- Verification: `bin/ci` passes (6742 Rails runs, 0 failures, seeds), `npm run test:js` 1611 passed, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check` pass. System tests `market_wanted_table_rarity`, `market_confier_wanted`, `market_direct_sale`, `market_wanted_copies`, `market_order_backed_auction` pass at 2 workers (the last once failed at its second sign-in in one combined run and passed three reruns alone).
- Residual risks: the CONFIER prefill is a reading of "stamp unpayable or the cap rule applies"; the result line names only the first led listing of a multi-copy auction line.
