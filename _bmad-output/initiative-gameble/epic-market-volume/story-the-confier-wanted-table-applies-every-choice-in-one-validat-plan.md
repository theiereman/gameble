---
title: 'The Confier wanted table applies every choice in one validation'
type: 'feature'
ticket: '8'
created: '2026-11-20'
status: 'in-review'
baseline_revision: '91affd6fc8768c4ce6a5e48b59fed8f365baba81'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Confier wanted table (entry 14) needs one operation that sells copies to the orders it drew, opens auctions and entrusts the rest in a single validation, all or nothing, with one ledger post so the stamps net against the same validation's proceeds. Today `ListCard`, `EntrustCards` and `Mint.credit` each post their own entries and publish their own events, so they cannot be composed.

**Approach:** Extract `ListCard`'s listing step and `EntrustCards`' entrust step into modules that return ledger entries and publish nothing; `Mint.credit` returns its entry; split entry 7's `OrderServing` into a move part and a settle part; build `Game::Market::ApplyWantedChoices(player:, lines:, settings_token:)` composing them under AD-59's lock order with one `Ledger.post` and one `WantedChoicesApplied`.

## Boundaries & Constraints

**Always:** AD-59's order inside one transaction: drawn orders read unlocked by token → `TradeLocks.players(seller, *owners)` (ascending) → `lock_bank(player)` → market open and version current → holdings of every locked player for every line's card-season, ascending player id → `Order.lock.where(id: drawn).order(:id)` → order recheck → field checks → writes. Every step moves free copies and releases nothing. Edition price refreshes run after every move, sorted by card-season (stable in assignment order). One `Ledger.post`, last. One `WantedChoicesApplied` on the seller's stream with entry 1's keys. `ListCard`, `EntrustCards`, `SellToOrder`, `CloseAuction` behave and test exactly as before. No planning ids; files ≤400 lines; new `errors.game.*` codes by hand in both locales.

**Never:** `RefreshWanted` or any wanted-table code (entries 6, 22 in a worktree); event subscriptions (entries 6, 10, 12 wire `WantedChoicesApplied`); controllers, routes, views (entry 14); the order expiry job or MES ORDRES (entry 9); `CardListed`/`CardsEntrusted`/`OrderServed` from this operation; a rescue of the wallet check (the stamp check makes it unreachable); a line-count bound (left to the author).

## I/O & Edge-Case Matrix

`lines`: array of hashes `{ card_season_id:, copies:, choice: "order"|"auction"|"entrust", order_tokens: [..] (order), starting_price:, duration_hours: (auction) }`; a line is named by its 0-based index.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Flow 13 table | an order line (token = best), an auction line, an entrust line | orders `served` (average stored), one listing per auction copy (reserved +1, its stamp), entrusted copies deposited and minted; one post (purchase, sale at the order's version, commission and stamp and mint at the current one), all entries one `created_at`, `ReconcileWallets` balanced; one `WantedChoicesApplied`; `Success(Applied)` | none |
| Stamp from proceeds | seller available 0, a sale and an auction | applies; wallet ends at proceeds − stamp | none |
| Several copies, one order line | 3 copies, 2 tokens best first | both served best first, third copy entrusted | — |
| Order changed | drawn order served/withdrawn/expired, or a better one placed, or a token unknown or repeated | nothing moves | `Failure([:best_order_changed, [Changed(line:, order:)]])`, `order` the best order left now for that line's first changed copy, or nil |
| Invalid fields | copies summed per card-season > free; start not a price / under minimum; duration not offered; no rarity; stamps > available + sales net of commission + mint fitting the cap (walked in table order) | nothing moves | `Failure([:invalid_choices, [Refused(line:, code:)]])`, codes `not_enough_copies` (every line of that card-season), `invalid_price`, `start_below_minimum`, `invalid_duration`, `no_rarity`, `stamp_not_covered` (auction lines from the first whose cumulative stamps exceed the funds) |
| Malformed line | bad id, copies < 1, unknown choice, more tokens than copies | nothing | `Failure([:invalid_choices, [Refused(line:, code: :invalid_choice)]])` before the transaction |
| Over the cap | entrust copies past `CapLeft`, in table order, whole copies, a cheaper later one may pass | skipped, kept, named in `Applied#skipped`; the rest applies | — |
| Nothing applies | every entrust copy skipped and no sale or listing | nothing | `:nothing_fits` |
| Empty / closed / stale / busy / removed | `[]`; market closed; token ≠ current; deadlock; banned/deleted seller | nothing | `:empty_batch` / `:market_closed` / `:amounts_changed` / `:market_busy` / `:player_required` |

</intent-contract>

## Code Map

- `app/domains/game/app/operations/game/market/sell_to_order.rb` -- the shape to mirror: unlocked `BestEligibleOrder`, `TradeLocks.players`, `lock_bank`, `current_settings`, holdings, `Order.lock`, recheck, `Ledger.post(serve_order(...))`, `rescue ActiveRecord::Deadlocked`. Unchanged except through `OrderServing`.
- `.../order_serving.rb` -- split `serve_order` into `move_order_copy(order:, seller_id:, card_season_id:, holdings:, now:)` (`give_sold_copy` with `released: {}`, `receive_bought_copy`) and `settle_order(order:, seller_id:, card_season_id:, commission_settings:, now:)` (`refresh_edition_price(adding: order.price)`, `order.update!(served…)`, `sale_entries`); `serve_order` calls both. Settle the second of two orders on one edition after the first: its window then holds the first.
- `.../auction_settlement.rb` -- `give_sold_copy`, `receive_bought_copy` (allocation, tiers), `refresh_edition_price`, `sale_entries`; `AuctionMath.commission(price, bp)` is the commission formula, reuse it for the stamp check.
- `.../list_card.rb` -- extract `price_rule`, `duration_rule`, listing creation and `reserve` into a `ListingOpening` module whose step returns the listing and its stamp `Ledger::Entry`; `ListCard` posts it and still publishes `CardListed`. `whole_number` from `PriceAmount`.
- `.../entrust_cards.rb` -- extract `values_of`, the cap walk and `deposit` (move, `ShowcaseEntry.remove_unheld`, `ArchiveDeposit.add`) into an `Entrusting` module whose step returns the `mint` entry; the cap walk must serve an ordered list where one card-season may appear on several lines; `EntrustCards` posts once and still publishes `CardsEntrusted` and refuses `:nothing_fits`.
- `app/domains/game/app/models/game/market/mint.rb` -- `credit` returns the `Ledger::Entry`, posts nothing; update its comment ("only the entrust step calls it").
- `queries/game/market/{eligible_orders,cap_left}.rb`, `models/game/trade_locks.rb`, `operations/game/{operation,move_holdings}.rb` -- reuse as is; `EligibleOrders.call(cs, except:, now:).where.not(id: assigned).first` is the best left after earlier assignments.
- `events/game/market/wanted_choices_applied.rb` -- `.with(seller_id:, sales: [{order_id, buyer_id, card_season_id, price}], listing_ids:, entrusted: [{card_season_id, quantity}])`; entrusted summed per card-season.
- Locales `errors.game` (fr ~5079, en same block): add `invalid_choices` and `invalid_choice`; the line codes reuse existing keys.
- Tests: mirror `test/domains/game/market/sell_to_order_test.rb` (`nothing_moves`, `figures`, `events`, supports `market`, `market_auctions`, `market_orders`, `holdings`, `singleton_stub`); fixtures `catalog_card_seasons(:rare_card_one|:common_card_one|:uncommon_card_one)`; starting values: rare min 78, stamp 20, entrustment 50; daily cap 12 000.
- `Mint.credit` callers that relied on its post: `test/support/market_auctions.rb#fund!` and 16 test files (`grep -rln "Mint.credit" test`) -- wrap in `Game::Market::Ledger.post(...)`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/models/game/market/mint.rb` -- return the entry -- the caller's single post.
- [ ] `app/domains/game/app/operations/game/market/listing_opening.rb` (new) + `list_card.rb` -- listing step returning its stamp entry -- shared with the table.
- [ ] `app/domains/game/app/operations/game/market/entrusting.rb` (new) + `entrust_cards.rb` -- entrust step returning its mint entry, shared cap walk -- shared with the table.
- [ ] `app/domains/game/app/operations/game/market/order_serving.rb` -- move/settle split, `serve_order` unchanged in effect.
- [ ] `app/domains/game/app/operations/game/market/apply_wanted_choices.rb` (new; split the field checks into a sibling module if it nears 400 lines) -- the operation per the matrix; result `Applied = Data.define(:sold, :listed, :entrusted, :skipped)` with `Sold(line:, order:, received:)` (price less commission), `Listed(line:, listing:)`, `Entrusted(line:, copies:, minted:)`, `Skipped(line:, copies:)`; `Refused(line:, code:)`, `Changed(line:, order:)`.
- [ ] `config/locales/en.yml`, `fr.yml` -- `errors.game.invalid_choices` ("Certains choix sont à corriger. Rien n'a été vendu, mis en vente ni confié." / "Some choices need fixing. Nothing was sold, listed or entrusted."), `errors.game.invalid_choice` ("Ce choix n'existe pas." / "This choice does not exist.").
- [ ] Tests -- `test/domains/game/market/apply_wanted_choices_test.rb` (every matrix row; the ticket's Verify list; `reserved` of a listed-elsewhere copy on the same edition unchanged beyond the new auctions; `average_after_sale` of two orders served on one edition in order); `Mint.credit` callers wrapped; `list_card_test.rb`, `entrust_cards_test.rb`, `sell_to_order_test.rb`, `close_auction_test.rb` untouched and green.

**Acceptance Criteria:**
- Given Flow 13's seller holding a wanted Rare, an auction copy and an entrust copy, when `ApplyWantedChoices` runs with the drawn token, then the buyer holds the Rare, one listing is open, the entrust copy is in the Archives, and one ledger post reconciles with `ReconcileWallets.balanced?`.
- Given any refusal, when it returns, then holdings, reserved, ledger entries, orders, listings, deposits and the event store are unchanged.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

- Only drawn orders are rechecked: a copy the table drew no order for is entrusted even if an order arrived since (AD-59, "applied as entrusted").
- Refusal order: line shape (before locks), market and version, orders changed, then all field checks together; the field checks need the rechecked sales for the stamp funds.
- Rate limit: there is no operation-level limiter in the codebase (`throttle_player` is controller-side); entry 14's controller limits the action, its controller tests cover it.
- A changed line's `order` is the best order left for that line's first copy after the earlier lines' current assignments (greedy on the current state), what the table would draw now.

## Verification

**Commands:** (always with `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w46_8 PARALLEL_WORKERS=4`; create with `RAILS_ENV=test bin/rails db:create db:schema:load` if missing)
- `bin/rails test test/domains/game/market` -- green
- `bin/rails test` -- green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing` -- pass
- `npm run test:js`, `npm run format:check`, `npm run lint:css` -- pass (no frontend change expected)
- `bin/rails test test/system/market_entrust_test.rb test/system/market_listing_test.rb` -- green (their `Mint.credit` calls change; `ListCard` and `EntrustCards` are refactored under them)
- No migration. Do not stage or commit; leave `package-lock.json` alone.
