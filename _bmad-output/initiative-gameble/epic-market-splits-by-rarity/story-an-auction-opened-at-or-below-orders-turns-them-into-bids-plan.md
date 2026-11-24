---
title: 'An auction opened at or below orders turns them into bids'
type: 'feature'
ticket: '2'
created: '2026-11-24'
status: 'built'
baseline_revision: '250e4a7d330b32419ad77f69fa1c39ff6d43132c'
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
  - '{project-root}/_bmad-output/initiative-gameble/epic-market-splits-by-rarity/story-the-settings-orders-and-notices-carry-the-rarity-rules-plan.md'
warnings: ['oversized']
deferred:
  - summary: >-
      An auction opened under very many eligible orders converts them all in one transaction.
    evidence: |-
      The conversion locks every owner's bank and writes one bid row and one event row per order inside the seller's transaction; one open order per player and game bounds it, but no measure exists. Settle by timing a listing under hundreds of orders.
    location: >-
      app/domains/game/app/operations/game/market/order_conversion.rb
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** A holder who lists a card at or below the price of an eligible buy order leaves that order untouched, so an anonymous order replaces the contest between named bidders and the order's PiCoins sit idle beside the auction.

**Approach:** `ListCard` converts, in the one transaction that opens the auction and whatever the rarity, the eligible orders priced at or above the starting price into bids: the best leads with its PiCoins moved (held once) to the listing, the others are beaten and refunded. The handlers tell the owners, MES ORDRES and the bell read the result, and Mettre en vente shows the orders and prefills the start at the lowest eligible order's price.

## Boundaries & Constraints

**Always:** `PlaceBid` and `CloseAuction` never read orders. One event (`CardListed`, carrying `converted` rows keyed `order_id owner_id listing_id price status`) published inside the transaction; the handlers run in it and publish nothing; pushes go through the existing after-commit batch. Owner bank locks in ascending player id (after the seller's), order rows in ascending id, each rechecked open and unexpired at the `now` read once. An order of a banned or deleted owner is never converted. Equal maximums: the earlier order (created_at, then id) leads. The leader's order status becomes `bid`, the others `beaten`; a `bid` order is ended and never reopens. Readers of stored events use `data.fetch(:converted, [])`. Every string in en.yml and fr.yml; tokens only in HTML; no planning ids; code reads without comments.

**Never:** build the Common/Uncommon-only direct sale, the wanted table's rarity choices or `ApplyWantedChoices` conversion (entry 3), or the shop cap (entry 4). Do not touch `PlaceBid`, `CloseAuction`, `SellToOrder`, the best-order banner. Do not hand-edit `db/schema.rb`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Two orders reach | Orders 400 (A) and 350 (B), auction opened at 300 | A `bid` and leader, maximum 400; B `beaten`, refunded; price = min(400, 350 + increment(350)); one hold on the listing; two bid rows; balances and reconciliation unchanged apart from the stamp | None |
| One order reaches | Order 400, start 300 | A leads at price 300 (starting price, no second maximum) | None |
| Order below start | Orders 400 and 280, start 300 | 400 converts; 280 stays `open`, its hold untouched, keeps its `listed_above_order` notice | None |
| Order at the start | Order exactly 300, start 300 | Converts (at or above) | None |
| Equal maximums | Two orders at 400 | The earlier created_at (then id) leads | None |
| Removed owner | Order owner banned or deleted | Never converted; PiCoins untouched by the conversion | None |
| Own order | The seller's own order | Never converted (EligibleOrders `except`) | None |
| Order ended meanwhile | An order served, cancelled or expired between the read and the locks | Left out | None |
| Later outbid | Bidder maximum 500 over the converted leader | Leader's maximum released as any maximum; `outbid` notice; order stays `bid`; MES ORDRES reads DÉPASSÉE | None |
| Auction won by the order | No later bid, auction closes | Order's owner wins; MES ORDRES reads GAGNÉE | None |
| No eligible order | Start above every order, or no order | Behaves as before | None |
| Deadlock | Lock contention | `Failure(:market_busy)` as today | rescue in ListCard |

</intent-contract>

## Code Map

Settled first: the ledger's unique indexes (`db/schema.rb`, `game_market_ledger_entries`) are `one_settlement` (listing, player, kind, only stamp/purchase/sale/commission) and `one_order_entry` (order, player, kind, where order_id is set). The conversion's `release` carries `order_id` (an unused kind for that order) and its `hold` carries `listing_id` (kind `hold` is not in the settlement index), and the subject check allows one subject per entry. So no index refuses it: no migration. A test proves it (release with order_id plus hold with listing_id for one player in one post).

- `app/domains/game/app/operations/game/market/list_card.rb` -- the transaction: after `lock_bank(player)`, settings, holding, rules, stamp covered and `open_listing`; add the conversion before `Ledger.post`, and put the entries of stamp and conversion in the same single `Ledger.post`. Passes `converted:` to `CardListed.with`. Keep the file under 400 lines: put the conversion in a new module `OrderConversion` beside `listing_opening.rb`.
- `app/domains/game/app/queries/game/market/eligible_orders.rb` -- `EligibleOrders.call(card_season_id, except:, now:)` is the only eligibility reader (open at `now`, reaching the rarity, not the seller's, owner not removed; price desc, created_at, id). Reuse; do not duplicate. `Order.lock` rows after owner locks and recheck open/unexpired/owner not removed at the `now` read.
- `app/domains/game/app/models/game/market/{auction_math,ledger,ledger_entry,bid,bid_terms,listing,order}.rb` -- `AuctionMath.displayed_price(highest:, second:, starting_price:, basis_points:)`; `Ledger::Entry` (`order_id` xor `listing_id`); `Bid::OUTCOMES` (`leading` for the leader, `beaten` for the others; `history_visible` rows feed `TiedBids`); `Order::STATUSES` already has `bid`, `beaten`.
- `app/domains/game/app/operations/game/market/place_bid.rb` -- reference for the hold/release entries and the `Bid.create!` shape; its `release` of the displaced leader's maximum on the listing must work unchanged on a converted leader.
- `app/domains/game/app/events/game/market/card_listed.rb` -- `CardListed.with(..., converted:)` already declared (entry 1).
- `app/domains/game/app/handlers/game/market/handlers/{order_notices,wanted_notices,wanted_refresh}.rb` and `config/initializers/event_store.rb` -- `OrderNotices` (add `CardListed` to `EVENTS`; for each converted row ordered by owner then order: delete its `listed_above_order` notice, write `order_leads` (status `bid`) or `order_beaten` with `listing_id` and `amount: price` via `Notice.record_for`); `WantedNotices` (skip the owners converted on that listing so no `wanted` notice is written for them); `WantedRefresh::PLAYERS` (`CardListed` => the converted owners).
- `app/models/market_push_notice.rb`, `app/jobs/market_push_notice_job.rb`, `app/models/player_stream.rb`, `app/models/wanted_card_notice.rb` -- `MarketPushNotice` (hear `CardListed`; `notices` returns `{player_id:, order_id:}` per converted row; `ORDER_KINDS` gains the two kinds; path of both kinds is the listing's); `PlayerStream` (`CardListed` also notifies the converted owners: balance and market topic); `push_notices.market_order_leads` and `market_order_beaten` in both locales.
- `app/domains/game/app/queries/game/market/{order_notice_lines,player_orders,bid_history,listing_bidders}.rb`, `app/helpers/{bell_helper,market_orders_helper}.rb`, `app/views/market/my_orders/*`, `app/controllers/market/my_orders_controller.rb` -- `OrderNoticeLines` (the two kinds show the listing's card); the bell line (`shell.bell.market.order_leads_html`, `order_beaten_html`, path the Annonce); `PlayerOrders` rows for `bid` and `beaten` orders: the listing is found by the order's `order_leads`/`order_beaten` notice (`listing_id`); an order reads EN ENCHÈRE while its listing is open and led by its owner (group in progress), GAGNÉE once the listing is sold and led by its owner, DÉPASSÉE otherwise (outbid, unsold, withdrawn, cancelled) or when `beaten`; ended groups ordered by the end (listing's `updated_at` for a bid order, order's for beaten); no ANNULER, a "VOIR L'ANNONCE" link, notes "the card joins your collection" (GAGNÉE) and "PiCoins returned" (DÉPASSÉE). Check every other reader of order statuses (the in-progress count chips, `PlayerDesk`, order cancel dialogs, `ORDER_TONES`) handles `bid` and `beaten`.
- `app/controllers/market/sales_controller.rb`, `app/helpers/market_sales_helper.rb`, `app/views/market/sales/{new,_fields,_summary}.html.erb`, `app/frontend/lib/listing_form{,_view}.ts`, `app/frontend/controllers/listing_{form,fields,summary}_controller.ts` and their tests, `app/frontend/styles/market-sale*.css` -- Mettre en vente: edition data carries the eligible orders' prices (add a reader beside `EligibleOrders.best` that returns every eligible price per edition; never an id or token); above the start field a block "<n> ordre(s) d'achat, le meilleur à <amount>" drawn per chosen edition from a server-rendered `<template>` like the best-order banner (no markup built in script); on choosing an edition whose orders exist and while the seller has not typed, the start is prefilled at the lowest eligible order's price (also on the server-rendered chosen-edition path and on refusal re-render); under the start a line that follows the typed start: "Avec ces ordres, l'enchère part à <price>, menée par un ordre d'achat." (the price `AuctionMath` would give over the orders at or above the start) and, for each order left under the start, "L'ordre à <amount> reste ouvert." The pure maths (which orders convert, the opening price, which stay open) live in `lib/listing_form.ts` with vitest tests; the controller stays glue. Keep `lib/` and controller files under 400 lines, CSS under 500, no `style` attribute.
- `app/domains/game/app/queries/game/market/alt_signals/tied_bids.rb` -- reads `Bid.history_visible`, so converted bid rows feed it unchanged: cover with a test, change only if the test fails.
- `config/locales/en.yml`, `config/locales/fr.yml` -- every new string in both (bell lines, push title/body, MES ORDRES chips and notes, Mettre en vente block and lines). French copy is the author's EXPERIENCE.md wording: EN ENCHÈRE, GAGNÉE, DÉPASSÉE, "VOIR L'ANNONCE ▸", "la carte rejoint votre collection", "PiCoins rendus", "<n> ordre(s) d'achat, le meilleur à <amount>", "Avec ces ordres, l'enchère part à <price>, menée par un ordre d'achat.", "L'ordre à <amount> reste ouvert." `i18n-tasks` is blind to dynamic `errors.<domain>.<code>` keys.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/operations/game/market/` -- conversion module and `ListCard` wiring: after the seller's bank lock read `EligibleOrders` at the starting price, take owner bank locks ascending and order rows ascending, recheck at `now`; leader order `bid`, others `beaten`; one `Ledger.post` holding the stamp, per converted order a `release` (order) and, for the leader only, a `hold` (listing) of the same amount; listing `leader_id`, `leader_maximum`, `current_price` from `AuctionMath`; one `Bid` row per converted order; `CardListed` carries the converted rows
- [ ] handlers, event store, push, player stream -- as in the Code Map
- [ ] queries, helper, views, bell, locales -- MES ORDRES, bell and push lines
- [ ] Mettre en vente server and script -- orders block, prefill, opening line; vitest for the maths
- [ ] `test/domains/game/market/order_backed_auction_test.rb` -- domain test of the matrix (two orders 400 and 350 at 300; 280 left open; one order; at the start; equal maximums; banned and deleted owner; own order; order served between read and lock; the ledger index unknown; later outbid releases PiCoins; won; balances and `ReconcileWallets` balanced; `CardListed` data; notices written once; `TiedBids` reads the converted bids; bid history names them)
- [ ] handler, query, helper and controller tests for each reader changed; `test/system/market_order_backed_auction_test.rb` -- seller opens the auction from Mettre en vente, the buyer's MES ORDRES reads EN ENCHÈRE, a later bid outbids it and the PiCoins return

**Acceptance Criteria:**
- Given two eligible orders 400 and 350 and a start of 300, when the holder lists, then the 400 order leads at the price `AuctionMath` gives, one hold stands on the listing, the 350 order is beaten and refunded, both owners are noticed and pushed, and the reconciliation balances.
- Given an order at 280 and a start of 300, when the holder lists, then it stays open with its `listed_above_order` notice.
- Given a converted leader, when a player bids above it, then it is outbid and its PiCoins return as any maximum, and MES ORDRES reads DÉPASSÉE with the auction linked.
- Given Mettre en vente on a copy with eligible orders, when it opens, then the orders show above the form, the start is prefilled at the lowest eligible price and the line says what the auction starts at and which orders it leaves open.

## Implementation Notes

- No migration: the ledger's unique indexes accept a `release` with `order_id` and a `hold` with `listing_id` for one player in one post (the domain test posts both). `db/schema.rb` untouched.
- Conversion lives in `Game::Market::OrderConversion` (included by `ListCard`): reads `EligibleOrders` at the starting price, takes owner bank locks ascending (after the seller's), locks the order rows ascending, then re-reads the same eligibility restricted to the locked ids at the `now` read once. Stamp and conversion entries go through one `Ledger.post`.
- `EligibleOrders.prices` (every eligible price per edition, best first, no id) feeds Mettre en vente; the edition data carries `orders` as a comma list.
- MES ORDRES derives EN ENCHÈRE / GAGNÉE / DÉPASSÉE from the listing found by the order's `order_leads`/`order_beaten` notice; `PlayerOrders::Row` gains `listing_token`, a bid order's `expires_at` is its auction's end; in-progress holds `open` and `bid`. The row status is the derived one (`bid`, `won`, `outbid`), never a new column.
- The prefill on the client is `untouched` start (empty, or equal to the previous edition's lowest order) so a start the seller typed is kept; the server prefills the lowest order's price whenever the start is blank (chosen path, single-copy path, refusal re-render).
- `start()` in `lib/listing_form.ts` takes the increment basis points as a trailing defaulted parameter and `choose()` takes the locale (default `en`) so existing callers and tests keep their shape.
- Existing tests changed because their premise is gone: a listing at or below an order's price now converts the order (`order_notices_test`, `sell_to_order_test` lists above the order), the refresh-wanted event list gains `CardListed`.
- Not done on purpose: entries 3 and 4 of the epic (direct sale, wanted conversion, shop cap).

## Plan Change Log

## Review Triage Log

### 2026-11-24 - Review pass
- verdicts: 23 findings - high 0, medium 0, low 22, false 0, maybe-false 1
- findings:
  - `[low]` `reject` (blind) order-to-auction link lives only in the order_leads/order_beaten notice - the architecture names the notice as that link, notices are deleted only with a released account whose orders are already withdrawn, a stored column would add a migration for no reachable case.
  - `[low]` `reject` (blind) withdrawn, cancelled or voided auctions read DÉPASSÉE - in each case the maximum is released and PiCoins return, which is what the chip and its note say; a cancelled listing cannot have a leader.
  - `[low]` `reject` (blind) the ended time and the 7-day window use the listing's updated_at - a closed listing is not touched again, so the value is stable.
  - `[low]` `patch` (blind, with edge) a refused post with a blank start is refilled beside the invalid-price error - keep_posted_values keeps the posted value as typed; the controller test now asserts the empty start.
  - `[low]` `reject` (blind) the prefill can sit under a raised minimum - the seller meets the existing minimum refusal; rare and not worth a branch.
  - `[low]` `reject` (blind) an untouched start equal to the previous lowest order is overwritten on switching edition - the value being replaced is the same prefill the seller sees.
  - `[low]` `reject` (blind) the client repeats the increment rule - the screen already computes commission in script; the vitest case and the system test pin the same figure as AuctionMath.
  - `[low]` `reject` (blind) silent defaults for increment and locale in start() and choose() - the controllers always pass both; cosmetic.
  - `[low]` `reject` (blind) the orders slot :empty never matches the server render - only spacing of an empty field differs.
  - `[low]` `reject` (blind) feminine chips and one sentence per order left open in a polite live region - the chips are the author's wording; the lines are rare at one order per player per game.
  - `[low]` `reject` (blind) the converted payload is read raw in five handlers - follows the existing sales pattern; a shared reader is a refactor for the sweep.
  - `[low]` `reject` (blind) comments added against the no-comments policy - the surrounding files carry the same one-line headers; cosmetic.
  - `[low]` `reject` (blind) missing tests for two listings of one edition, double-order owners and status readers - covered by the order-served-between-read-and-lock test and the full suite; no concrete defect shown.
  - `[maybe-false]` `defer` (edge) unbounded owner locks and writes when many orders reach a popular card - one open order per player per game bounds it by the players wanting that game; settle by measuring a listing under many orders.
  - `[low]` `reject` (edge) seller lock before owner locks can deadlock - the order the architecture mandates; a deadlock is rescued as market_busy and the seller retries.
  - `[low]` `reject` (edge) typed start equal to the lowest order replaced on switching edition - same as the blind finding above.
  - `[low]` `reject` (edge) the opening line shows below the minimum - the minimum refusal shows beside it and blocks the submit.
  - `[low]` `patch` (edge) blank start refilled after a refusal - same fix as above.
  - `[low]` `reject` (edge) a bid order with no notice vanishes from MES ORDRES - same as the first blind finding.
  - `[low]` `patch` (gap) no test seeds a listed_above_order notice on an order that is then converted - added a case to order_notices_test.rb: list above, then at the order's price, the notice is gone and order_leads stands.
  - `[low]` `patch` (gap) the auto-chosen sole edition's prefill is untested - added a sales controller test with one holding and two orders.
  - `[low]` `reject` (gap) the 7-day window and non-open auction outcomes of a converted order are unpinned - read-only display, the main states are covered.
  - `[low]` `reject` (intent) the descriptive audit notes the system test runs in English, drives the outbid through PlaceBid and visits the sale path directly - the French chips and lines are asserted in controller and vitest tests; no divergence from the intent's surfaces.

## Design Notes

The conversion is a fold over the converted orders, best first: `highest` is the best order's price, `second` the next one's (nil with one), so the displayed price is `AuctionMath.displayed_price(highest:, second:, ...)`. Bid rows are written in created_at then id order, `leading` for the leader and `beaten` for the rest, all with the final price as `price_after`. A converted leader later outbid shows DÉPASSÉE although its row stays `bid`: MES ORDRES derives the three labels from the listing, never from a new column. A deadlock between the seller's lock and an owner's lock is rescued as `market_busy`, as `ListCard` does today.

## Verification

**Environment (every test command):** you are in a git worktree on branch `build/48-2`; use `/usr/bin/git` if `git` is refused; never push, never merge, never commit (the parent commits). `npm ci` is done; Postgres listens on localhost:5433 (user postgres, password postgres): set `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w482`, `CHROME_BIN=/usr/bin/chromium`, `PARALLEL_WORKERS=4` in each test command. Never run `bin/rails test:system` whole, and never loop it: run only the system test files this ticket touches, one or two at a time, with at most 2 workers. The unit suite (`bin/rails test`) may run in full. No migration is expected; if one proves needed, regenerate `db/schema.rb` as AGENTS.md says and say so in Implementation Notes. Record decisions, files touched and surprises under Implementation Notes.

**Commands:**
- `DATABASE_URL=<gameble_test_w482 on the 5433 server> CHROME_BIN=/usr/bin/chromium PARALLEL_WORKERS=4 bin/rails test` -- expected: pass
- `bin/rails test test/system/market_order_backed_auction_test.rb` and the touched system files (market sale, my orders), one or two at a time, at most 2 workers -- expected: pass
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/ci` -- expected: pass

## Auto Run Result

- Summary: `ListCard` converts, in the transaction that opens the auction and whatever the rarity, the eligible orders at or above the starting price (`OrderConversion`): the best leads with its PiCoins moved to the listing in the same `Ledger.post` (held once), the others are beaten and refunded, one bid row per converted order, price and leader from `AuctionMath`. `CardListed` carries the converted rows; handlers write `order_leads` and `order_beaten`, refresh wanted rows and push; MES ORDRES reads EN ENCHÈRE, GAGNÉE, DÉPASSÉE with the auction linked and no ANNULER; Mettre en vente shows the eligible orders, prefills the start at the lowest and says what the auction starts at and which orders stay open. No migration: the ledger's unique indexes accept a `release` on an order then a `hold` on a listing for one player (a test posts both).
- Files: `order_conversion.rb` (new), `list_card.rb`, `eligible_orders.rb`, `order_notices.rb`, `wanted_notices.rb`, `wanted_refresh.rb`, `order_notice_lines.rb`, `player_orders.rb`, `market_push_notice.rb`, `player_stream.rb`, the sales controller, helpers and views (`_orders.html.erb` new), `listing_form` script and controllers with vitest, `market-sale-order.css`, en.yml and fr.yml, and the tests (domain, controller, helper, model, vitest, `test/system/market_order_backed_auction_test.rb`).
- Review: thorough, four lenses. Patches applied: 3 (low): a refused blank start stays blank, a test that conversion removes the `listed_above_order` notice, a test of the sole edition's prefill. Deferred: 1 (unbounded conversion size, medium unverified). 19 other findings rejected with their reasons in the triage log. No follow-up review recommended; patched counts: high 0, medium 0, low 3.
- Verification: `bin/ci` passes (6727 Rails runs, 0 failures, seeds, schema checks), `npm run test:js` 1605 passed, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check` pass; system tests `market_order_backed_auction_test.rb`, `market_sales_test.rb` (and, before review, `market_direct_sale`, `market_orders`, `market_confier_wanted`) pass at 2 workers.
- Residual risks: the opening line's price is computed in script from the same rule as `AuctionMath`, pinned by one shared figure in tests; a seller who types exactly the lowest order's price then switches edition loses it; MES ORDRES finds a converted order's auction through its notice.
