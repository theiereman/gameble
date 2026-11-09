# Adversarial review: the market release (AD-40 to AD-49, amended AD-10, AD-13, AD-14)

Spine reviewed: `architecture-gameble.md` (draft, updated 2026-11-09), working-tree delta against HEAD. Rules read: `spec-gameble/market-economy.md` and CAP-29 to CAP-37 of `spec-gameble/spec-gameble.md`.

Code read in `app/domains/game/app`: `BankLock`, `TradeLocks`, `Operation`, `AcceptTrade`, `TradeSteps`, `OpenPack`, `ProposeTrade`, `CloseTrade`, `ExpireTrade`, `ExpireTradesJob`, `CancelOpenTrades`, `DropFriendsAndTrades`, `DropFriendsAndTradesJob`, `ReleasePlayer`, `ReceiveSeasonAllocation`, `AddToShowcase`, `ShowcaseEntry`, `SetTier`, handlers `PlayerDeleted` and `VisibilityChanged`, queries `FeedEntries`, `NewFeedEntries`, `VisibleFeedEntry`, `SeasonAllocationRecap`. Also `Accounts::DeletePlayer`, `Accounts::Player`, `PlayerStream`, and the `game_holdings`, `game_set_tiers` and `game_feed_entries` constraints in `db/schema.rb`.

Method: two units one level down that each obey every AD to the letter and still build incompatibly; then concrete interleavings of the money paths against AD-10's lock order. Nothing was run.

Severity: **critical** a literal build loses, freezes or duplicates PiCoins or a copy on the normal path; **high** a literal build breaks a money invariant on a reachable edge, or two units cannot coexist; **medium** a wrong result or a visible inconsistency with a bounded cost; **low** a wording gap two builders would probably settle alike.

**Verdict: the lock order and the auction formula hold, but the ledger has no contract for what each kind moves, so a literal build strands the winner's surplus, and `PlaceBid`'s three branches and the buy-now path are undefined at exactly the points where money moves. Two critical, four high, seven medium, four low.**

---

## What was attacked and holds

### Worked example against AD-44's formula

Every step of `market-economy.md` checks out, with `increment(x)` read as a ceiling to the hundred (5% of 30,000 is 1,500 and stays 1,500, so "rounded up to the next hundred" cannot mean "strictly above").

| Step | Computation | Result |
|---|---|---|
| Start 20,000, maximum 30,000 | one bidder: starting price | 20,000 |
| Maximum 25,000 (minimum bid 21,000) | `min(30,000, 25,000 + ceil100(1,250))` | 26,300 |
| Maximum 40,000 (minimum bid 26,300 + 1,400 = 27,700) | `min(40,000, 30,000 + 1,500)` | 31,500 |
| Close | surplus `40,000 - 31,500` | 8,500 |
| Seller | `31,500 x 0.90` | 28,350 |

The minimum-price table also matches the no-loss floor: 1,100 / 0.9 gives 1,300; 3,000 / 0.9 gives 3,400; 7,000 / 0.9 gives 7,800; 20,000 / 0.9 gives 22,300.

### Formula edges

- **The top two maximums are always `leader_maximum` and the new bid.** A new bid is at least `current_price + increment`, and every earlier beaten maximum is at or below `current_price`, so storing one maximum per listing loses nothing.
- **The price is monotonic.** New leader: `min(B, H + inc(H)) >= H >= P`. Beaten bid: `min(H, B + inc(B)) > P`, since `B > P`.
- **Equal maximums.** `min(H, H + inc(H)) = H`: the earlier bidder leads at that maximum, as the rule says.
- **First and second bid.** One bidder sits at the starting price; a second bidder at exactly the minimum bid lands on `start + inc(start)`, which is their own maximum, and they lead or are beaten consistently.
- **The buy-now invariant.** Every bid at or above buy-now settles, so no held maximum reaches it, and the settlement price never undercuts a held maximum.

### Lock order

- **Bank locks are a total order on every market path.** `PlaceBid` takes {bidder, seller}, `CloseAuction` {seller, leader}, `CancelListing` and `ListCard` {seller}, `EntrustCards` and `DropPresence` {player}, `AcceptTrade` {both}, all through `TradeLocks.players` (sorted, deduplicated). `ReceiveSeasonAllocation` re-acquires a lock its transaction already holds, which is reentrant.
- **No path holds a listing and then asks for a bank lock.** `DropPresence` for a leader needs only its own bank lock and the listing row; the row lock serialises it against `PlaceBid` and `CloseAuction`, and a `CloseAuction` that needs the removed player's bank lock blocks before it touches the listing.
- **The documented "holdings before player states" is not what the code does, and that is safe.** `AcceptTrade` locks holdings first, but `OpenPack` receives the allocation (locks `game_player_states`) and then upserts holdings. AD-45 lists the same order as `OpenPack`. Each holding lock read here runs under that player's bank lock, so the row order is not what prevents the deadlock. AD-10 should say so.
- **Wallets stay last.** Every debit of `available` runs under that player's bank lock (`hold`, `stamp`, `forfeit`), and the only change made without it is a credit (`release` of an outbid leader). So `PlaceBid` checking funds on an unlocked wallet read can only under-estimate, and the check constraint backs it.
- **`AcceptTrade`, `ProposeTrade` and `CloseTrade` touch no listing or wallet.** Their bank and holding locks are compatible with every market path.
- **`DeletePlayer` locks the player row `FOR NO KEY UPDATE`, then the bank.** A ledger insert's foreign-key check takes `FOR KEY SHARE`, which does not conflict.

### Invariants

- **Settlement twice.** Status is rechecked under the listing lock, and the partial unique index backs it. A relist is a new listing, so the index does not block it.
- **A bid during a close.** Serialised on the listing; a bid at or past `ends_at` is refused and the close's due check uses the same boundary.
- **An auction that never closes through a leader change.** Once due, no bid can change the leader, so `CloseAuction`'s "otherwise it does nothing" converges.
- **A copy sold and traded.** The listing carries `reserved + 1`; `ProposeTrade`, `AcceptTrade` and entrustment all read `quantity - reserved` under the holding lock; no code resets or recomputes `reserved`; `game_holdings_quantity_check` backs it. `TradeSteps#release` slices to existing rows.
- **The daily cap.** Read from `mint` entries under the bank lock, so concurrent batches cannot both pass it.

---

## Critical

### C1. A literal close strands the winner's surplus, and no AD says what each kind moves

- **ADs:** AD-41, AD-44, AD-45.
- **Units:** `CloseAuction` (AD-45) and `Ledger.post` entries (AD-41), against the nightly reconciliation (AD-41) and the snapshots (AD-48).
- **Obeying to the letter:** AD-45 ends with "then posts `purchase`, `sale` and `commission`". It never mentions a `release`, though `market-economy.md` says "the winner's surplus returns at close".
- **Interleaving, using the worked example:** the winner holds 40,000. Settlement posts `purchase` of 31,500 from `committed`. Nothing moves the remaining 8,500, which stays in `committed` for good: no later operation releases a maximum on a closed listing. The reconciliation passes, because wallet and entries agree.
- **Three builders, three ledgers, all "correct":**
  - `purchase` takes the full maximum from `committed` and credits the surplus to `available` in one entry;
  - `purchase` takes the price, and a separate `release` returns the surplus;
  - `sale` credits the net amount and `commission` subtracts again: `-31,500 + 28,350 - 3,150`, so 3,150 is destroyed twice.
- AD-41's invariant ("the sum of the deltas equals minted minus stamps, commissions and forfeits") cannot arbitrate, since each builder derives "commissions" from its own entries. In the third build a zero-delta `commission` passes it while the indicator reads zero destroyed.
- **Fix:** add to AD-41 one table fixing player, `available_delta` and `committed_delta` per kind:

| Kind | Player | `available_delta` | `committed_delta` |
|---|---|---:|---:|
| `mint` | entruster | +value | 0 |
| `stamp` | seller | -stamp | 0 |
| `hold` | bidder | -amount | +amount |
| `release` | maximum's owner | +amount | -amount |
| `purchase` | winner | 0 | -price |
| `sale` | seller | +price | 0 |
| `commission` | seller | -commission | 0 |
| `forfeit` | deleted player | -balance | 0 |

  Add to AD-45: "and `release` for the maximum minus the price, when positive". Add the check that `hold` and `release` net to zero in each entry, and that per sold listing `purchase + sale = 0`.

### C2. `PlaceBid` has one sentence for three different money moves

- **ADs:** AD-41, AD-44; CAP-31.
- **Units:** `PlaceBid`'s funds check and posting step, against `Ledger.post` and the wallet check constraints.
- **Obeying to the letter:** "It writes the listing and one `game_market_bids` row, then posts `hold` for the new maximum and `release` for the previous one."
- **Branch 1, beaten at once.** A leads with 30,000; B bids 25,000. "The previous one" is, literally, the held maximum on the listing: A's. Posting it frees 30,000 for A while A still leads and `leader_maximum` still says 30,000. A spends it, the close's `purchase` drives `committed` below zero, the check raises, and the auction fails on every run forever (and A has bid with money it no longer has backing). The opposite reading, hold and release B's own 25,000, is harmless but writes two ledger rows for nothing; a third builder posts nothing. The rule must pick.
- **Branch 2, a leader raising.** A has `available` 25,000 and `committed` 30,000 and raises to 50,000.
  - CAP-31 reads "a maximum above the available balance is refused": 50,000 > 25,000 refuses a raise A can afford (the delta is 20,000).
  - If the check is right, "`hold` then `release`" applied entry by entry takes `available` to -25,000 first. `CHECK` is immediate in Postgres, so the statement fails on a valid raise. Only aggregating per wallet, or releasing first, works; AD-41 says only "applies the deltas".
- **Branch 3, a new leader.** The only branch the sentence fits.
- **Fix:** state the branches in AD-44: new leader posts `hold` of the new maximum and `release` of the old leader's; beaten at once posts neither and still requires `maximum <= available`; a raise posts one `hold` of the difference and requires `difference <= available`. In AD-41: `Ledger.post` sums deltas per wallet into one update per wallet before inserting the entries. Add to the funds rule that a bidder's own held maximum counts toward a raise.

---

## High

### H1. Buy-now joins two AD paragraphs that each post and each publish

- **ADs:** AD-10, AD-41, AD-44, AD-45.
- **Units:** `PlaceBid`'s posting step (AD-44) and the settlement step shared with `CloseAuction` (AD-45).
- **Two `Ledger.post` calls.** AD-41 allows one per transaction. AD-44's step posts `hold` and `release`; AD-45's step posts `purchase`, `sale` and `commission`. Each unit obeys its own paragraph. Interleaving, with wallets locked call by call: T1 is a buy-now by player 8 displacing leader 7 on a listing of seller 3. Its first call locks wallets 7 and 8, its second then wants 3. T2 is a `CloseAuction` of another listing, seller 3, winner 7: its one call locks 3 and waits for 7. Deadlock, and the victim's player sees an error on a buy they paid attention to.
- **Wallets before holdings.** Literal AD-44 posts before the settlement moves the copy, inverting AD-10's "holdings, then wallets".
- **Two primary events.** AD-44 says it "publishes one `BidPlaced`, carrying the player outbid"; AD-45 says settlement "publishes one `AuctionSold`"; AD-10 says one primary event per operation. Publish only `AuctionSold` and the displaced leader is never told; publish only `BidPlaced` and the feed, the average price and the listing stream miss the sale.
- **`purchase` from what.** A buy-now buyer has no `hold`, so `purchase` from `committed` underflows unless a `hold` precedes it. C1's table needs this case.
- **Fix:** the settlement step returns entries and never posts; `PlaceBid` makes the single `Ledger.post` with all of them, after the holdings. A buy-now posts `hold` of the price (or the raise's difference) and `purchase` of the price, so `committed` never underflows. It publishes one `AuctionSold` carrying `outbid_player_id`, and the outbid handler subscribes to both events.

### H2. The commission has no rounding rule, and prices are not multiples of ten

- **ADs:** AD-41, AD-44, AD-45.
- **Units:** the `sale` amount and the `commission` amount, computed by whoever writes settlement. AD-44 makes `AuctionMath` "the only computation" but lists only `increment`, price and minimum bid.
- **Edge:** maximums are free integers. A maximum of 25,055 gives a price of 25,055 + 1,300 = 26,355. Ten percent is 2,635.5. `round(price * 0.9)` gives 23,720 and `round(price * 0.1)` gives 2,636, a total of 26,356: one PiCoin created. With `floor` on both, the total is 26,354 and one disappears. The worked example hides this: 31,500 divides by ten.
- **Same family:** a float percent breaks `increment` near exact hundreds. In floating point `0.07 * 100` is not exactly 7, so a ceiling can add a spurious 100. Percent settings in AD-42 have no stated type.
- **Fix:** add `AuctionMath.commission(price)` with integer arithmetic only, percent stored in basis points: `commission = (price * bp) / 10_000` (floor), and settlement's `sale` is the full price with `commission` subtracted per C1, so the two cannot disagree. Increment: `((x * bp + 999_999) / 1_000_000) * 100`.

### H3. A close can fail forever on a closed enumeration, and `CloseAuction` has no legal signature

- **ADs:** AD-10, AD-14, AD-45.
- **Units:** the settlement's tier pass and sale feed entry, against the constraints already in `db/schema.rb`; and `CloseAuction` against `Game::Operation`.
- **`reached_by`.** `game_set_tiers_reached_by_values_check` accepts `pack`, `trade`, `allocation`; `SetTier::REACHED_BY` matches. AD-45 says it "records set tiers", AD-10 still lists three origins.
  - Builder A writes `reached_by: "market"` and forgets the widening: a winner crossing a tier raises a check violation on every run. The job reports and moves on; the copy, the maximum and the seller's money are frozen, for that listing only and silently to players.
  - Builder B widens the check: `SeasonAllocationRecap` filters `reached_by: %w[pack trade]`, so tiers reached by a purchase vanish from the recap, and `FeedEntry`'s `reached_by` join needs review.
  - Builder C writes `"trade"`: it works, but the data export says "trade" for an auction.
- **Feed kind.** `game_feed_entries_kind_check` and `game_feed_entries_trade_check` refuse any new kind, and the second ties `trade` to a non-null `trade_id`. Same poison through a handler running inside the close.
- **`player:` is mandatory.** `Game::Operation.method_added` raises `ArgumentError` at class load unless `call` takes `player:`. AD-14 says "every `Game` operation acts for one player"; AD-45 calls `CloseAuction` "once per due listing". `Game::SystemOperation` (AD-14, AD-48) does not exist anywhere in `app`, `config`, `lib` or `test`, and may write only rows belonging to no player, so it cannot be the answer. A builder copying `require_player` would then refuse a banned seller before reaching AD-46's `withdrawn` branch, which is what `ExpireTrade`'s `require_account` override exists to avoid.
- **Fix:** AD-45: `CloseAuction.call(player: seller, listing_id:)` using `require_account`, as `ExpireTradesJob` passes the proposer; `DropPresence` likewise. AD-10: a tier reached by a purchase records `reached_by: "market"`, widened expand/contract before the first close, and `SeasonAllocationRecap` reads it as in-play. AD-45: name the feed kind and its check. Add that a close failure is counted and alerted per listing, since "reports and moves on" hides a stuck auction.

### H4. Account deletion has already removed the holding that AD-46 releases

- **ADs:** AD-14, AD-45, AD-46.
- **Units:** `Game::ReleasePlayer` (existing) and `DropPresence` or `CloseAuction`'s `withdrawn` branch.
- **Interleaving:** S has an open listing with A leading at 30,000. S deletes the account. `ReleasePlayer` runs in that transaction and executes `Holding.where(player_id:).delete_all`, removing the row that carries `reserved`. AD-46 then says "the reservation is released". Any step that does `holdings.fetch(card_season_id)`, as `shift_reserved` does, raises `KeyError`, and a settlement step modelled on `AcceptTrade#move` takes its `holding.nil?` branch and inserts `quantity: -1`, which the check refuses. Either way the job reports the error every minute, A's 30,000 stays held and the forfeit never comes, because it waits for "their listings and bids to be gone".
- **A stale read widens it.** `DeletePlayer` commits `deleted_at` after the handler, and every operation validates its `player` before taking the lock (`require_player` runs before the transaction). A `PlaceBid` or `CloseAuction` that waited on the deleting transaction's bank lock and then reads the seller it loaded earlier sees a live seller with no holding. AD-46's "`PlaceBid` refuses a removed seller" does not say the check happens after the lock. `lock_bank` re-reads `deleted_at` only and misses `banned_at`.
- **Fix:** AD-46: state that a deleted seller's holding is already gone and the release is a no-op on a missing row (reuse `TradeSteps#release`, which slices). AD-44 and AD-45: read seller and leader removal after the bank locks, from the primary, with one shared check covering both `banned_at` and `deleted_at`.

---

## Medium

### M1. The minimum bid can exceed the buy-now price

- **AD:** AD-44. Buy-now 35,000, current price 34,000. `increment(34,000)` is 1,700, so the minimum bid is 35,700. A bid of exactly 35,000 is refused as below minimum if the minimum check runs first, though the buy-now button offers exactly that amount; 35,700 is accepted and buys at 35,000.
- **Fix:** `AuctionMath.minimum_bid` returns `min(buy_now, current_price + increment)`, and the buy-now test runs before the minimum check. The funds check on a maximum above buy-now reads the buy-now price, since that is all that can be spent.

### M2. A removed leader still prices the auction until the job runs

- **AD:** AD-46. It covers `PlaceBid` for a removed seller only. Banned leader G holds 40,000, price 20,000. In the next minute B bids 50,000 and leads at 42,000 against a banned account; G is now outbid, so the job finds nothing to reset, and B overpays by 22,000. This is the shill case a ban exists for. If B bids 30,000 instead, B is told they were beaten and the auction then resets, erasing the bid with no notice.
- **Fix:** in `PlaceBid`, after the locks, a removed leader is treated as no leader: release their maximum in the same `Ledger.post` and compute from the starting price.

### M3. A settings change can silently undo another

- **AD:** AD-42. Each version holds every value. Two administrators change different values from version 5: version 6 has the new commission, version 7 has the new stamp and the old commission, and the Brotherhood has announced both. Two concurrent doublings also pass the "cannot more than double" bound. **Fix:** `ChangeSettings` takes a named advisory lock and validates against the version read under it.

### M4. `Ledger.post` upserts before it sorts

- **AD:** AD-41. "Upserts the missing wallets, locks them in ascending player id." A multi-row `INSERT ... ON CONFLICT` takes its index locks in `VALUES` order, so two first-time wallets in opposite orders deadlock before the sorted lock. **Fix:** sort the upsert too.

### M5. Other shapes the ADs leave to the builder

- **Who can cancel.** CAP-30 says "only before any bid"; AD-44 says "needs no current leader". After `DropPresence` clears a leader, a listing with bids and no leader can be cancelled. The same gap makes "the starting price with no bid" unclear: `leader_id IS NULL` or `NOT EXISTS bids`. Pick `leader_id IS NULL` and amend CAP-30, or forbid it.
- **Extensions in the history.** CAP-33 says "extensions add a line"; AD-44's public history selects only player, price, outcome and time, with one row per bid. Add `extended_until` to the bid row.
- **A raise in the history.** CAP-33's "one line per validated bid" makes a raise public, telling rivals the leader just raised. Exclude it, or accept it in the known limits.
- **Oversized entrustment.** "Up to the cap, whole cards only" does not say whether a card that does not fit stops the batch or is skipped so that a cheaper later one fits. CAP-29's "entrusts what fits" and "in selection order" suggest either.

### M6. The name-only surfaces do not fit the existing read paths

- **ADs:** AD-13, AD-44, AD-49.
- **Feed.** AD-49 names "a market sale's feed entry" as an exception, but `FeedEntries.visible`, `NewFeedEntries` and `VisibleFeedEntry` each drop an entry whose player fails `visible?`, and `ReleasePlayer` deletes feed entries of a deleted player, so "a deleted player prints the anonymous key" cannot occur there. Name the query that carries the exception.
- **Live history.** The component needs a viewer, but the listing's public stream renders once for everyone. Rendering with `viewer: nil` removes the friends-only link that the page render showed. State that the broadcast sends a signal to refetch, or that it renders with no viewer and that this is accepted.

### M7. Smaller concurrency gaps

- **`ActiveRecord::Deadlocked`.** `CancelOpenTrades` grows its lock set in a loop, so it can take a lower id after a higher one, and it rescues the deadlock only for itself. Postgres may instead pick the `PlaceBid` or `CloseAuction` on the other side as victim. A close retries; a bid returns a 500. Rescue it in the market operations as `Failure(:busy)`.
- **Stale edition price.** Two settlements of one card-season each compute the average before upserting. The second may miss the first's sale, and the nightly job only refreshes "rows whose window moved". Take the row lock, then read the sales.
- **Reconciliation false alarms.** Summing wallets and entries in two statements while settlements commit reports drift. Run it in one `REPEATABLE READ` read.

---

## Low

- **A capped price discloses the leader's maximum.** B bids 39,000 against a maximum of 40,000: `39,000 + 2,000` is capped to 40,000, so the public price is exactly the leader's maximum in one bid, without AD-44's queries being involved. `market-economy.md`'s known limits mention only probing in small steps. Add this one.
- **`hold` entries carry a maximum.** AD-44's restriction names only `leader_maximum` and `bids.maximum`. Extend it to `game_market_ledger_entries` of kind `hold` and `release`, and to `game_market_alt_signals`.
- **`now` for the end check.** AD-44 should say `now` is read after the listing lock, as `CloseTrade` does, so a bid that waited on the lock is judged on the time it was admitted.
- **AD-10's prose and `BankLock`'s comment** still describe an order that omits listings and wallets; the comment needs the same update as the spine.
