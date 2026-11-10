---
title: 'Bids follow the auction rules'
type: 'feature'
ticket: '39.4'
created: '2026-11-10'
status: 'draft'
baseline_revision: '579532637b130be63c1c49b044afb9ff5190069e'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/epic-an-auction-runs-and-settles.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-due-auction-closes-and-settles-exactly-once-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-sale-refreshes-its-edition-s-average-price-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A listing can be shown, closed and settled, but nobody can bid on it: the leader only exists in test arrangement, no price follows the second-highest maximum, no escrow is held by a real bid, no late bid extends the auction and nothing buys at once. Epic requirements R4 (the bidding half of `AuctionMath`), R5, R6, R7 and R9 (a bid landing at the close).

**Approach:** `game_market_bids` keeps one row per validated bid; `AuctionMath` gains the increment, the displayed price and the minimum bid (pure, no loop); `Game::Market::PlaceBid` takes the bank locks, locks the listing and applies one of four branches (buy-now, new leader, beaten at once, leader's raise), reusing the settlement step of the close for the buy-now branch. It publishes one `BidPlaced`, or `AuctionSold` on buy-now, and answers the branch and the amounts the bid form will name.

## Boundaries & Constraints

**Always:**
- `AuctionMath` is the only computation and has no loop; it reads the listing's own settings version (`increment_basis_points`, `soft_close_seconds` through `Settings.find(listing.settings_id)`), never the current one. `increment(amount, basis_points)` is `(amount * basis_points).ceildiv(10_000).ceildiv(100) * 100`. `displayed_price(highest:, second:, starting_price:, basis_points:)` is the starting price when `second` is nil, else `min(highest, second + increment(second))`. `minimum_bid(price:, starting_price:, buy_now_price:, basis_points:)` is the starting price when `price` is nil (no leader), else `min(buy_now_price, price + increment(price))` with a missing buy-now ignored. `raise_minimum(maximum)` is `maximum + 1`: the leader's raise only has to be above their own maximum.
- `PlaceBid#call(player:, listing_id:, maximum:)` refuses a banned or deleted bidder (`require_player`), reads the listing unlocked (`Failure(:listing_not_found)`), takes the bank locks in ascending player id (the bidder's, plus the seller's when the maximum reaches the immutable buy-now price), re-checks the bidder is not removed, locks the listing, reads `now`, then refuses in this order: a closed current version (`market_closed`), a listing that is not open or whose `ends_at` is at or before `now` (`auction_ended`), a removed seller (`listing_withdrawn`), the seller's own listing (`own_listing`), a maximum under the minimum (`below_minimum`), a commitment above what the bidder's `available` covers (`more_than_available`). A deadlock answers `Failure(:market_busy)`. Every refusal changes and publishes nothing.
- A removed leader (`banned_at` or `deleted_at`, read after the bank locks) counts as no leader: the bid is judged against the starting price and the leader's whole maximum is released in the same single `Ledger.post`. This story does not void that leader's bid rows (the removed-player epic does).
- The four branches, with `X` the typed maximum, `M` the leader's maximum, `P` the current price, `L` the leader. Commitment needed from `available`: buy-now `buy_now - (M if the bidder is L)`, otherwise `X - (M if the bidder is L)`.
  - Buy-now (`buy_now_price` set and `X >= buy_now_price`): `hold` of the commitment when positive, the listing takes the bidder as leader at `buy_now_price` (maximum and price), `settle_sale(held: buy_now_price, final_price: buy_now_price)` then `release` of any other leader's whole maximum; one `Ledger.post`; publishes `AuctionSold` with that other leader as `outbid_player_id` and their amount as `outbid_released`.
  - New leader (no leader, or `X > M` and the bidder is not L): `hold` of `X`, `release` of `M` to the previous leader, listing leader, maximum and `current_price = displayed_price(highest: X, second: M or nil)`.
  - Beaten at once (the bidder is not L and `X <= M`): no entry, the price becomes `displayed_price(highest: M, second: X)`; equal maximums keep L and the price becomes `M`.
  - Leader's raise (the bidder is L and `X > M`): `hold` of `X - M`, the maximum only; the price and `ends_at` do not move.
- Soft close: a bid that changes the price or the leader (new leader, beaten at once; never a raise, never a buy-now) with `ends_at - now < soft_close_seconds` sets `ends_at = now + soft_close_seconds` and stores it as the row's `extended_until`; otherwise `extended_until` stays null.
- One `game_market_bids` row per validated bid (never for a refusal): listing, player, `maximum` (the held maximum, the buy-now price on the buy-now branch), `price_after` (the listing's price once the bid applied), `outcome` and `extended_until`. Outcome at insert: `leading` (new leader and buy-now), `beaten` (beaten at once, equal maximum included), `raise`. In the same transaction a new leader or a buy-now turns the displaced leader's `leading` rows into `outbid`; the settlement step turns the winner's `leading` rows into `won` and every other player's `leading`, `outbid` and `beaten` rows of that listing into `lost`, so the close and the buy-now both leave a finished listing with no `leading` row. `voided` is allowed by the check and written by no code in this story.
- Lock order follows AD-10: bank locks ascending, listing, then (buy-now only) holdings, player states, the edition price row, and `Ledger.post` once, last. The listing lock is what orders a bid against `CloseAuction`, which locks bank, listing in the same order; a bid at or past `ends_at` is refused, and a close of a listing a bid just extended answers `listing_not_closable`.
- `PlaceBid` publishes exactly one event besides the tier events the settlement already publishes: `BidPlaced` (listing, bidder, branch as a string, `outbid_player_id`, `outbid_released`; the outbid fields only on the new-leader branch, nil and 0 otherwise) on the bidder's stream, or `AuctionSold` on the seller's stream. Events carry identifiers and amounts only. `BidPlaced` joins the balance notice of `PlayerStream` for the bidder and the outbid player.
- Schema changes are expand only and in separate migrations: the table, then each concurrent index on its own. Only `PlaceBid` and the settlement step write bids; only `Ledger.post` writes wallets and entries. No planning id in code or tests, English outside `fr.yml`, no database id leaves the server.

**Never:**
- No bid form, controller, route, policy, rate limit, template, screen text or JavaScript (the bidding screen story), no unusual-maximum or buy-now confirmation (the dialogs story), no history, offer count or outcome text (the history story), no notice row or bell line, no live refresh, no feed entry, no voided row, no forfeit (the removed-players and notices epic), no cancel or relist.
- No second formula for the increment, the displayed price or the minimum anywhere (not in SQL, a view or a handler); no loop to find the price; no `Wallet` or `LedgerEntry` write outside `Ledger`; no leader maximum on any public read.
- No edit to `db/schema.rb` by hand; no change to the close's branches or to its single post and event.

**Decisions (settled by Claude, no checkpoint in this run; the author may revisit):**
- Failures stay bare codes. The two refusals that name an amount (`below_minimum`, `more_than_available`) carry none: the bidding screen reads the fresh minimum through `AuctionMath` and the fresh ceiling from `Balance` in the same redraw, as the listing form reads its shortfall, and tells "price moved" from "at least" by comparing the minimum its form drew with the fresh one.
- The leader raising to a value at or under their own maximum answers `below_minimum`; the minimum the screen shows them is `AuctionMath.raise_minimum`. No increment applies to a raise (AD says only "above their own maximum").
- The answer is the `Game::Market::BidAnswer` data object: `branch` (`:buy_now`, `:new_leader`, `:beaten`, `:raise`), `equal_maximum` (true only for the equal-maximum beaten case), `price` (the listing's price after the bid), `maximum` (the bidder's held maximum, nil when beaten), `minimum` (the next minimum bid, nil once sold) and `listing` (the reloaded record). It lets the bidding screen name the panel and its amounts without reading the listing again.
- `maximum:` accepts an Integer or the text of a whole number and refuses anything else, zero and amounts above the bigint range with `Failure(:invalid_price)` (the existing key). The four-line parse repeats `ListCard`'s rule rather than touching that file, which the listing story edits in parallel; the refactor sweep can merge both.
- The commitment check applies to every branch, beaten at once included, as the architecture table states: a player cannot bid above what they could hold.
- The settlement step gains one line, `Bid.close_out(listing_id:, winner_id:)`, so both settlements finish the rows; the non-sold ends of the close leave the rows as they are (the removed-players epic voids them).
- `publish_to_seller` moves from `CloseAuction` to `AuctionSettlement`, which `PlaceBid` also includes, so the buy-now publishes `AuctionSold` the way the close does.
- Index choices: `(listing_id, id)` serves the history and the offer count; `(player_id, listing_id)` serves the bidder's list of auctions. Neither is partial.
- The concurrency proof is a real two-connection race (`LockRaces`) of `PlaceBid` and `CloseAuction` on one due listing, not a mock: whichever order wins, one settlement or one refusal, and the ledger reconciles.
- The five new `errors.game` keys use the Copy deck's words in both languages, with `%{amount}` where the deck names one.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First bid | Start 20,000, no leader, maximum 30,000, 500 bp | `new_leader`; leader, maximum 30,000, price 20,000; `hold` 30,000; row `leading`, price after 20,000 | No error expected |
| Beaten at once | Leader holds 30,000 at 20,000; bid 25,000 | `beaten`; price 26,300 (25,000 + 1,300); no ledger entry; leader unchanged; row `beaten`, price after 26,300 | No error expected |
| New leader | Leader 30,000 at 26,300; bid 40,000 | `new_leader`; price 31,500 (30,000 + 1,500); `hold` 40,000, `release` 30,000 to the first leader; first leader's row `outbid`; `BidPlaced` names them and 30,000 | No error expected |
| Equal maximums | Leader 30,000; another bids 30,000 | `beaten` with `equal_maximum`; price 30,000; leader unchanged | No error expected |
| Leader's raise | Leader 30,000 at 20,000 raises to 35,000 | `raise`; `hold` 5,000; price and `ends_at` unchanged; no `extended_until` | No error expected |
| Raise not above | Leader bids 30,000 again, or 29,000 | Nothing changes | `Failure(:below_minimum)` |
| Soft close | Bid with 2 minutes left, window 180 s, new leader or beaten at once | `ends_at = now + 180 s`, `extended_until` equal to it | No error expected |
| Outside the window | Bid with 10 minutes left; or exactly 180 s left | `ends_at` unchanged, `extended_until` null | No error expected |
| Raise in the window | Leader raises with 1 minute left | `ends_at` unchanged | No error expected |
| Buy-now, no leader | Buy-now 50,000, maximum 80,000, available 60,000 | `buy_now`; holds 50,000, settles at 50,000, surplus 0; `AuctionSold`; row `won`; `average_after_sale` stored | No error expected |
| Buy-now, leader raising into it | Leader holds 30,000, bids 60,000 | Holds 20,000 more (50,000 less 30,000); settles at 50,000; leader columns say the bidder at 50,000 | No error expected |
| Buy-now over another leader | Leader B holds 30,000; bidder reaches 50,000 | Bidder holds 50,000, B's 30,000 released in the same post; `AuctionSold` carries B and 30,000; B's rows `lost` | No error expected |
| Below the minimum | Leader at 20,000, bid 20,999 (minimum 21,000); or first bid 19,999 | Nothing changes | `Failure(:below_minimum)` |
| More than available | Available 25,000, bid 30,000; or leader's raise needing more than available | Nothing changes | `Failure(:more_than_available)` |
| Own listing | The seller bids | Nothing changes | `Failure(:own_listing)` |
| Ended | Status not open, or `ends_at <= now` | Nothing changes | `Failure(:auction_ended)` |
| Removed seller | Seller banned or deleted | Nothing changes | `Failure(:listing_withdrawn)` |
| Removed leader | Leader banned or deleted, bid of 25,000 | Bidder leads at the starting price, the removed leader's maximum released in the same post | No error expected |
| Market closed | Current version closed | Nothing changes | `Failure(:market_closed)` |
| Bad amount | `"abc"`, 0, negative, beyond bigint | Nothing changes | `Failure(:invalid_price)` |
| Unknown listing | No such id | Nothing changes | `Failure(:listing_not_found)` |
| Bid against the close | `PlaceBid` and `CloseAuction` on one due listing at once | One settlement, or the bid refused as ended; no copy or PiCoin moves twice; ledger reconciles | `Failure(:auction_ended)` or `Failure(:listing_not_closable)` |
| Deadlock | `ActiveRecord::Deadlocked` | Rolled back, nothing stored | `Failure(:market_busy)` |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/market/auction_math.rb` -- holds `commission` and `BASIS_POINTS`; gains `increment`, `displayed_price`, `minimum_bid`, `raise_minimum`.
- `app/domains/game/app/operations/game/market/auction_settlement.rb` -- `settle_sale(listing:, winner_id:, held:, final_price:, now:)` and `sold_event`, already shaped for the buy-now (`held: buy_now_price`); gains `Bid.close_out` and the moved `publish_to_seller`. The edition price step of the previous story sits in the same method.
- `app/domains/game/app/operations/game/market/close_auction.rb` -- sibling operation to mirror (unlocked read, `TradeLocks.players`, `Listing.lock.find`, removed players read after the locks, `rescue Deadlocked`); loses `publish_to_seller`.
- `app/domains/game/app/operations/game/market/list_card.rb` -- shape of `current_settings`, `amount` parsing, `Balance.call(player).available`, entries with `Ledger::Entry`.
- `app/domains/game/app/models/game/market/listing.rb`, `settings.rb`, `ledger.rb`, `balance.rb` (queries) -- the listing's columns (`current_price`, `leader_id`, `leader_maximum`, `ends_at`, `buy_now_price`, `settings_id`), `increment_basis_points` and `soft_close_seconds` on the version, `Ledger::Entry` kinds `hold` and `release`, the available figure.
- `app/domains/game/app/models/game/trade_locks.rb`, `bank_lock.rb` -- `TradeLocks.players` for the ascending bank locks.
- `app/models/player_stream.rb` -- `BALANCE_EVENTS`, `notices`; gains `BidPlaced`.
- `app/domains/game/app/handlers/game/handlers/goals_reached.rb`, `achievements.rb` -- already hear `AuctionSold` for the winner, so a buy-now needs no change.
- `app/domains/game/app/events/game/market/auction_sold.rb` -- the event pattern for the new `BidPlaced`.
- `db/migrate/20261110120000_create_game_market_listings.rb`, `20261110120001_add_open_ends_at_index_to_game_market_listings.rb` -- shape of a table with checks and of a concurrent index migration; the newest migration on the branch is `20261110120005`, the edition price story takes `20261110130000` to `20261110130002`, this story follows with `20261110140000` to `20261110140002`.
- `app/domains/game/app/queries/game/market/offer_counts.rb` -- a zero stub the history story replaces; untouched here.
- `test/support/market.rb`, `market_listings.rb`, `market_auctions.rb`, `holdings.rb`, `lock_races.rb`, `test/domains/game/market/close_auction_test.rb`, `auction_math_test.rb` -- arrangement to reuse (`open_market!`, `listing!`, `fund!`, `lead!`, `hold`, `first_holding_the_lock`, `together`) and tests to extend.
- `config/locales/en.yml`, `fr.yml` -- `errors.game` already holds `market_busy`, `market_closed`, `invalid_price`, `listing_not_found`, `listing_not_closable`, `player_required`.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/20261110140000_create_game_market_bids.rb` -- create `game_market_bids`: `listing` and `player` references (not null, `index: false`, foreign keys to `game_market_listings` and `accounts_players`), `maximum` bigint not null, `price_after` bigint not null, `outcome` string not null, `extended_until` datetime, `created_at` datetime not null; checks `outcome IN ('leading','outbid','beaten','raise','won','lost','voided')`, `maximum > 0`, `price_after > 0` -- the history of validated bids
- [ ] `db/migrate/20261110140001_add_listing_index_to_game_market_bids.rb` -- `disable_ddl_transaction!`, concurrent index on `(listing_id, id)` -- the history and offer count reads
- [ ] `db/migrate/20261110140002_add_player_index_to_game_market_bids.rb` -- `disable_ddl_transaction!`, concurrent index on `(player_id, listing_id)` -- a bidder's auctions
- [ ] `app/domains/game/app/models/game/market/bid.rb` -- model on the table: `OUTCOMES`, `belongs_to :listing`, `belongs_to :player`, `displace(listing_id:, player_id:)` (leading to outbid for that player), `close_out(listing_id:, winner_id:)` (winner's leading to won, other players' leading, outbid and beaten to lost) as `update_all` scopes -- the one place the outcome changes
- [ ] `app/domains/game/app/models/game/market/auction_math.rb` -- add `increment`, `displayed_price`, `minimum_bid`, `raise_minimum` as pure module functions (no loop, integer math only) -- R4's bidding half
- [ ] `app/domains/game/app/models/game/market/bid_answer.rb` -- `Data.define(:branch, :equal_maximum, :price, :maximum, :minimum, :listing)` -- what the bidding screen reads
- [ ] `app/domains/game/app/events/game/market/bid_placed.rb` -- new event class, data `listing_id`, `bidder_id`, `branch`, `outbid_player_id`, `outbid_released` -- the epic's notices read it later
- [ ] `app/domains/game/app/operations/game/market/auction_settlement.rb` -- call `Bid.close_out` in `settle_sale` next to the listing's `sold` update; add the moved private `publish_to_seller(listing, event)` -- both settlements finish the bid rows; the buy-now publishes like the close
- [ ] `app/domains/game/app/operations/game/market/close_auction.rb` -- delete its `publish_to_seller` (now inherited from the mixin) -- no behaviour change
- [ ] `app/domains/game/app/operations/game/market/place_bid.rb` -- new operation `PlaceBid#call(player:, listing_id:, maximum:)` including `AuctionSettlement`: parse, unlocked read, `lock_banks`, `Listing.lock.find`, `biddable` refusals in the stated order, `lead_of` (nil for a removed leader), `commitment_covered`, then one of `buy_now`, `new_leader`, `beaten_at_once`, `raise_maximum` building entries, listing changes and the row, `soft_close` for the two price-moving branches, a single `Ledger.post`, one event, `BidAnswer`; `rescue Deadlocked` to `:market_busy`. Keep each branch method short and the file under 400 lines, moving the branches into a mixin `app/domains/game/app/operations/game/market/bid_branches.rb` if it grows past it -- R5, R6, R7
- [ ] `app/models/player_stream.rb` -- add `Game::Market::BidPlaced` to `BALANCE_EVENTS` and a `notices` branch giving a balance notice to the bidder and the outbid player (`balance_notices(data.values_at(:bidder_id, :outbid_player_id))`) -- the Balance chip follows an escrow
- [ ] `config/locales/en.yml` and `config/locales/fr.yml` -- by hand beside `market_busy`, under `errors.game`: `auction_ended` ("This auction has ended." / "Cette enchère est terminée."), `below_minimum` ("At least %{amount} is needed." / "Il faut au moins %{amount}."), `listing_withdrawn` ("This listing was withdrawn." / "Cette annonce a été retirée."), `more_than_available` ("You can commit at most %{amount}." / "Vous pouvez engager au plus %{amount}."), `own_listing` ("You cannot bid on your own listing." / "Vous ne pouvez pas enchérir sur votre propre annonce.") -- every new Failure code in both languages
- [ ] `test/domains/game/market/auction_math_test.rb` -- extend: `increment` at 20,000 (1,000), 25,000 (1,300), 26,300 (1,400), 30,000 (1,500) and 1 (100); `displayed_price` with one bidder, two, equal maximums and the cap at the highest; `minimum_bid` with no leader, a leader, a buy-now below the next step; `raise_minimum`; the worked example's three prices
- [ ] `test/domains/game/market/place_bid_test.rb` -- operation tests of the matrix: the worked example bid by bid (20,000, then 26,300 with no ledger entry for the beaten maximum, then 31,500 with the first leader released), equal maximums, a raise holding only the difference without moving price or end, the soft-close extension and its absence for a raise, outside the window and at exactly the window, the bid rows (outcome, price after, `extended_until`, `outbid` flip), the event data and the balance notices after commit, every refusal changing no row, no entry and no event, a removed leader released in the same post and bid rows untouched, a double-spend by two bids of one player not exceeding `available` (the check constraint never fires)
- [ ] `test/domains/game/market/place_bid_buy_now_test.rb` -- buy-now from no leader, from a leader raising into it (holds the difference), over another leader (released in the same post, `AuctionSold` names them), `average_after_sale` and the edition row written, the winner's allocation and tiers as a close does, rows `won` and `lost`, the ledger reconciling through `ReconcileWallets`, a buy-now refused for the seller and for a short balance
- [ ] `test/domains/game/market/place_bid_race_test.rb` -- non-transactional test with `LockRaces`: `PlaceBid` and `CloseAuction` on one due listing at once and in the held-lock order; one settlement or one refusal, one copy moved, `ReconcileWallets` balanced
- [ ] `test/domains/game/market/close_auction_test.rb` -- keep green; one assertion that a settled listing has no `leading` bid row after a close with bids placed through `PlaceBid` -- the settlement finishes the rows
- [ ] `test/models/player_stream_test.rb` -- notices for `BidPlaced`: bidder and outbid player, the bidder alone when nobody is outbid, no duplicate

**Acceptance Criteria:**
- Given a listing from 20,000 at 5%, when three players bid 30,000, 25,000 and 40,000, then the prices read 20,000, 26,300 and 31,500, the second bid writes no ledger entry, the first leader's 30,000 is released with the third bid, and after the close the winner pays 31,500 and recovers 8,500.
- Given a bid in the last 3 minutes that changes the price or the leader, when it commits, then the end moves to 3 minutes after it and the row holds that time; given a leader's raise, then neither the price nor the end moves.
- Given a maximum reaching the buy-now price, when it commits, then the listing is sold at that price in the same transaction, the bidder's own held maximum counted in what they hold, any other leader released in the same post, and one `AuctionSold` is published.
- Given any refusal, when it happens, then no listing, bid, wallet or ledger row changes and no event is published.
- Given `PlaceBid` and `CloseAuction` on one due listing at once, when both run, then the copy and the PiCoins move once and the wallets reconcile with the ledger.
- Given a settled listing, when its bids are read, then none is `leading`: the winner's is `won`, the others' `lost`.
- Given the migrations, when the schema is regenerated from them on Postgres 18, then it carries the table and its two indexes, with no hand edit.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

- A removed leader never needs a bank lock in a bid: their release only raises their wallet, and `Ledger.post` locks wallets in ascending id last, so no cycle with the close (bank locks, listing, holdings, wallets).
- The price is derived once per validated bid from two maximums and never recomputed in a loop; the listing keeps only the leader's maximum, so the beaten bidder's maximum survives only in the bid row (private to its owner).

```ruby
def increment(amount, basis_points) = (amount * basis_points).ceildiv(BASIS_POINTS).ceildiv(100) * 100

def displayed_price(highest:, second:, starting_price:, basis_points:)
  second ? [ highest, second + increment(second, basis_points) ].min : starting_price
end
```

## Verification

**Commands:**
- `ruby -c` and `bundle exec rubocop` on each touched Ruby file -- expected: no offence
- `bundle exec packwerk check` -- expected: no violation
- `script/check_planning_references` and `script/check_file_sizes` -- expected: pass
- `bin/rails test test/domains/game/market/auction_math_test.rb test/domains/game/market/place_bid_test.rb test/domains/game/market/place_bid_buy_now_test.rb test/domains/game/market/place_bid_race_test.rb test/domains/game/market/close_auction_test.rb test/domains/game/market/ledger_write_guard_test.rb test/models/player_stream_test.rb` -- expected: green (run once at the end of the market build, not by the build agent)
- `bin/rails zeitwerk:check` and `bundle exec i18n-tasks missing` -- expected: pass
- After the migrations: regenerate `db/schema.rb` as CI does -- expected: no drift (done at the end of the market build)
