# Rubric review: spine update 2026-11-09 (market release)

- **Spine:** `architecture-gameble/architecture-gameble.md`, AD-40 to AD-49, the amended lines of AD-10 (lock order, quantity-raising operations), AD-13 and AD-14, the map rows CAP-29 to CAP-37, and Deferred.
- **Spec checked:** `spec-gameble.md` CAP-29 to CAP-37, Constraints, Assumptions; `market-economy.md`.
- **Code checked:** `Game::Operation`, `Game::BankLock`, `Game::AcceptTrade`, `Game::TradeSteps`, `Game::ReleasePlayer`, `Game::DropFriendsAndTrades`, `Game::DropFriendsAndTradesJob`, `Game::Handlers::{PlayerDeleted, PlayerBanned, TradeAccepted, GoalsReached, Achievements}`, `Game::Visibility`, `Game::FeedEntries`, `Game::ShowcaseEntry`, `Game::SeasonAllocationRecap`, `Game::SumWeeklyGoal`, `Accounts::CreateAnnouncement`, `Accounts::ShowAnnouncement`, `Accounts::ApplyRetentionJob`, `Accounts::Player.idle`, `MarketsController`, `MarketPolicy`, `ApplicationCable::Connection`, `LiveFeedJob`, `LiveStream`, `config/initializers/event_store.rb`, `config/recurring.yml`, `config/queue.yml`, and in `db/schema.rb` the tables `game_holdings`, `game_feed_entries`, `game_set_tiers`, `game_showcase_entries`, `game_player_states`, `catalog_card_seasons`, `accounts_announcements`.

## Verdict

**Conditional pass.** The money core is sound: one ledger writer, one lock order, a single auction computation, a settlement guarded twice (recheck under lock, partial unique index). The auction arithmetic reproduces the worked example of `market-economy.md`. The update does not yet say how the market opens or how it is run, it contradicts the deletion code it builds on, and it leaves a settlement's downstream effects and the bid postings to each builder.

Fix C1 and H1 to H5 before slicing the market stories. Fix the medium findings in the same pass, and the low ones when convenient.

## Checklist

| Check | Result |
| --- | --- |
| Fixes the real divergence points, misses none | Mostly. Open: opening the market (C1), the handlers of a settlement (H2), the postings of each bid case (H3), the sale feed entry (H5), the actor of system operations (M1), the sale time and formula edges of the average (M5), metric definitions (M6). |
| Every Rule is enforceable and prevents its divergence | Most are, through check constraints, the partial unique index, one named computation or a recheck under lock. Weak: the insert-only ledger against `update_all` and `delete_all` (M2); AD-46's job against rows the deletion has already removed (H1). |
| Nothing Deferred lets two units diverge | Three entries can (M8): feed thresholds, notices beyond the outbid one, and the optional typical price, which has no entry at all. |
| Ratifies rather than contradicts the code | Most claims hold (table below). Contradicted: AD-46's precedent and its deletion assumption (H1), `Game::SystemOperation` (M1), AD-10's list of `reached_by` values (H2), AD-49 against `ReleasePlayer` (H5). |
| Covers every load-bearing requirement | Not landed: the legal precondition (C1), the weekly-goal exclusion (H2), the compact amount format and the fee justification (M3), the extension line in the bid history (M4). See the coverage table. |
| Every dimension decided, deferred or open | Not met for operations. Opening, stopping, recurring entries, job order, close-lag monitoring and the migrations of existing check constraints are absent from the rules, from Deferred and from the open questions (C1, H4). |

## Claims about existing code, checked

| Claim | Found |
| --- | --- |
| Bank lock first, then rows, is the existing order (AD-10) | Yes. `BankLock` uses `pg_advisory_xact_lock`; its comment needs the new links. |
| `quantity - reserved` is the free count, and trades respect it (AD-44) | Yes. `TradeSteps#enough_copies` and the check `quantity >= reserved AND reserved >= 0`. `requestable` reads `quantity` only, but acceptance rechecks. |
| Settlement can follow `AcceptTrade` (AD-45) | Yes for the sequence: lock, published season, allocations, move, `ShowcaseEntry.remove_unheld`, tiers. `move` is private to `AcceptTrade`, so AD-43's "same step" means extracting it. |
| A listed only copy stays in the showcase | Yes. `remove_unheld` tests `quantity > 0`. |
| Rarity minted on the copy is available | Yes, `catalog_card_seasons.rarity`. It is nullable, so an unnumbered card-season needs a refusal. |
| `Game::Visibility.visible?` answers AD-49's question | Yes, and `visible?(nil, owner)` is true only for a public owner. |
| A visitor can read the market and subscribe | Yes. `MarketPolicy#show?` is `true`, the controller includes `PublicRead`, and the cable accepts a nil player. |
| Player rows are anonymised, first discoveries keep their player (AD-14, AD-41) | Yes. `ReleasePlayer` keeps `FirstDiscovery` and clears only its `pack_id`. |
| An announcement can be written through `Accounts` (AD-42) | Yes, `CreateAnnouncement`, with limits that AD-42 ignores (M3). |
| `DropPresenceJob` "runs every minute, like `DropFriendsAndTradesJob`" (AD-46) | **No.** `DropFriendsAndTradesJob` is not in `config/recurring.yml`. It runs by rake only. Ban and deletion act through synchronous handlers. |
| `Game::SystemOperation` (AD-14, AD-48) | **No such class.** `SumWeeklyGoal` inherits `ApplicationOperation` directly. |
| `reached_by` is a pack, a trade or the allocation (AD-10) | True today, and it is the problem: a check constraint and `SeasonAllocationRecap` fix that list (H2). |

## Critical

### C1. The market cannot open as written, and cannot be stopped (AD-40, AD-42)

**Failure.** Every market operation refuses while no settings version is open, and `ChangeSettings` validates a value "measured against the current version". The first row therefore has no base to be measured against, and no rule says who inserts it. One builder seeds it in a migration, another in a rake task, a third adds a first-run form. The same gap applies to the flag: nothing says which action sets it, whether opening is itself an announced change, or what a later `ChangeSettings` copies into it.

The spec's legal condition, "before the market opens: the terms of use forbid real-money trading of cards and PiCoins, and the draw odds are published", appears nowhere in the spine, so the market can open in breach of it.

"The market stays open once opened" also removes the only brake. If the nightly reconciliation finds a difference, or entrustment mints wrongly, the sole way to stop minting is a deploy.

**Fix.** Add to AD-42:
- A `Game::Market::OpenMarket` operation, administrator only, inserts or copies a version with `open = true` and announces the opening. Starting values come from one constant mirroring `market-economy.md`, seeded by an idempotent task as a closed version.
- The back-office refuses opening until the author ticks that the terms and the odds page are live, recording who ticked.
- Either add a `paused` value that stops entrusting, listing and bidding while `CloseAuction` keeps running, or write down explicitly that a pause is a deploy and accept it in Deferred.
- State that `open` is copied forward and that `ChangeSettings` cannot change it.

## High

### H1. AD-46 contradicts the deletion it runs after (AD-46, AD-14)

**Failure.** `Game::Handlers::PlayerDeleted` runs `ReleasePlayer` synchronously in the deletion's transaction, and that does `Holding.where(player_id:).delete_all`. When the job reaches a deleted seller, "the reservation is released" has no row to act on. A builder reusing the shared lowering step or `lock.find` raises. Since the job reports and moves on, the same error recurs every minute, the leader's maximum is never released and the `forfeit` never posts, because it waits for "their listings and bids are gone". That is the stuck maximum AD-46 names under Prevents. `CloseAuction`'s `withdrawn` path has the same hole.

The named precedent misleads too: `DropFriendsAndTradesJob` has no entry in `config/recurring.yml`, so "like" tells the builder nothing about scheduling. It is a rake-run repair, and the live path is the handlers.

**Fix.** State that for a deleted seller the holding may be gone and the reservation release is skipped, and order the steps so the leader's release comes first and is independent. Keep the job (it respects "a handler never writes another player's wallet"), remove the comparison, and name the entry to add to `recurring.yml`.

### H2. "Settles like an accepted trade" leaves every consumer undecided (AD-45, AD-10)

**Failure.** AD-45 publishes `AuctionSold` and says no more about who listens. Subscriptions are per event in `config/initializers/event_store.rb`:
- `Handlers::TradeAccepted` writes a `WeeklyContribution`. A builder copying it breaks the spec assumption "a market sale does not count for the weekly goal", which landed nowhere in the spine.
- `GoalsReached::EVENTS` and `Achievements::EVENTS` list `TradeAccepted`. Without `AuctionSold` a goal on a card just bought stays open and card-count achievements wait for the next opening.
- `PlayerActivity`, `LiveStream`, `PlayerStream` and `PushNotices` each need a yes or no.

The tier pass has its own trap. `game_set_tiers_reached_by_values_check` allows only `pack`, `trade` and `allocation`, and `SeasonAllocationRecap` reads `%w[pack trade]`. Passing `market` fails the constraint, and once migrated the tier silently vanishes from the recap. AD-10's list was not amended.

Buy-now is also unresolved. AD-44 has `PlaceBid` publish `BidPlaced`, and AD-45 runs the settlement inside it, which publishes `AuctionSold`: two primary events against AD-10's one, and it decides whether the previous leader gets an outbid notice.

**Fix.** Add to AD-45 a table of consumers of `AuctionSold`: goals yes, achievements yes, activity yes or no, weekly contribution **no**, feed through H5. State that `reached_by` is `"trade"`, or add `market` and amend the recap. State that a buy-now publishes `AuctionSold` only, carrying the outbid player, or that both events are allowed as a named exception to AD-10.

### H3. The postings of a bid are defined for one case out of four (AD-44, AD-41)

**Failure.** AD-44 says `PlaceBid` posts "`hold` for the new maximum and `release` for the previous one". That describes a new leader only.
- **A leader's raise.** A leader with 30,000 held and 15,000 available raises to 40,000. CAP-31 read literally ("a maximum above the available balance is refused") refuses it, and `market-economy.md` ("holds more PiCoins") accepts it. If `Ledger.post` applies entries one by one, `hold` first violates `available >= 0` even when the funds suffice.
- **A bid beaten at once.** `market-economy.md` says the maximum is "released at once". One builder posts `hold` and `release`, another posts nothing. The funds check and the permanent record differ.
- **Buy-now.** Is the hold the stated maximum or the buy-now price, and is the funds check against which? It also needs the previous leader's release.

**Fix.** Add a table of case, funds check and entries to AD-44. Recommended: a raise checks `new - old <= available` and posts the difference as one `hold`; a beaten bid checks the funds and posts nothing; buy-now checks and charges the buy-now price, with no intermediate hold. State that `Ledger.post` nets deltas per wallet before writing.

### H4. Operations are mostly undecided (AD-41, AD-45, AD-46, AD-48)

**Failure.** Seven schedules are implied and none is named as a `recurring.yml` entry with its queue: close (10 s), removed players (1 min), archive stock sum, reconciliation, average refresh, snapshot, alt signals.
- `config/queue.yml` runs three threads on `default` by default, shared with the live feed jobs. The 2026-10-30 review raised the same gap.
- The snapshot contains the reconciliation result, so the two nightly jobs have an order that nothing states.
- `AD-45` reports exceptions only. If `CloseDueAuctionsJob` stops, nothing is raised, listings stay open past their end and maximums stay held, which CAP-32's "ends by itself" forbids. Reconciliation still balances, so it sees nothing.
- The rollout is silent. Migrations must extend the feed kind check (and `reached_by`, per H2), and nothing states that the code ships dark before opening, or what the first days watch.

**Fix.** Add one operations line per job (entry, queue, schedule), and run reconciliation inside or before the snapshot. Add a monitor: age of the oldest due open listing, alerting past a few minutes, shown in the back-office. Add a short rollout rule: expand migrations, deploy closed, smoke on staging, open with C1's operation. Or list each of these under Deferred with a trigger.

### H5. The sale feed entry has no shape, and AD-49 contradicts the deletion (AD-13, AD-49, AD-45)

**Failure.** AD-49 lists "a market sale's feed entry" but no rule says who is named (seller, buyer, both), what kind it is or how it is unique.
- `game_feed_entries_kind_check` must be extended, and the row has no listing column. `trade_id` is the only per-transaction unique key.
- `Game::FeedEntries.visible` drops any entry whose `player_id` or `partner_id` fails `visible?`, and `NewFeedEntries` needs a sale path. AD-49's exception therefore means changing a query, which is unstated, and the sale kind must bypass the filter while the other kinds keep it.
- `ReleasePlayer` deletes every `FeedEntry` of a deleted player, as `player_id` or `partner_id`. AD-49's "a deleted player prints the anonymous key" never happens on the feed, and a deleted seller erases the buyer's sale from history.
- AD-49's component is "given the player and the viewer", but `LiveFeedJob` and the listing's public stream render once per locale with no viewer. Nothing says to pass `nil`, so a builder may broadcast a link meant for one viewer.

**Fix.** In AD-45 or AD-13, define the entry: `kind: "sale"`, `listing_id` unique, the buyer as `player_id` and the seller as `partner_id` (or one name only). State the visibility bypass for that kind, and whether `ReleasePlayer` anonymises or deletes those rows. In AD-49, state that a broadcast renders with `viewer = nil`, so a name carries a link only for a public player until the page reloads.

## Medium

### M1. System operations have no actor (AD-14, AD-45, AD-48)

`Game::Operation.method_added` raises unless `call` takes a required `player:`. `CloseAuction` and `ChangeSettings` have no obvious player, and AD-48 names a `Game::SystemOperation` that does not exist. `CloseAuction` may pass the seller using `require_account` as `ExpireTrade` does, or inherit `ApplicationOperation` as `SumWeeklyGoal` does. **Fix:** name the base class per operation; create `Game::SystemOperation` or replace the term in AD-14 and AD-48.

### M2. Insert-only is enforced only at the model (AD-41)

"The model raises on update and destroy" does not stop `update_all`, `delete_all` or `insert_all`, the styles this domain uses (`AcceptTrade#move`, `ReleasePlayer`). A deletion step written the usual way would erase the permanent record. **Fix:** a database trigger refusing UPDATE and DELETE on `game_market_ledger_entries`, plus a test that only `Ledger` references the wallet and entry models.

### M3. Tone, format and legal copy did not land (AD-18, AD-42)

- "Shown compact (1.2M), never with a euro sign": no helper is named in AD-41 or the Conventions, so each screen will format its own.
- "The Brotherhood announces and justifies each fee": AD-42 covers settings changes only, and does not say whether staff type the text or a locale key fills it. `accounts_announcements` caps each message at 280 characters, and `CreateAnnouncement(shown: true)` hides whatever is currently shown, so a settings change silently removes a staff announcement.
- The word rule ("Mon maximum", never "automatic") has no home in AD-18 or the Conventions.
- The privacy and retention pages must name the wallet, ledger and bids, as AD-36 did for the library list. The 3-year idle deletion also forfeits the balance, and nothing says so.

**Fix:** one amount helper in the Conventions, one sentence on the announcement's source and on `shown`, and a privacy line in AD-46.

### M4. Bid history lacks the extension line and the voided bid (AD-44, AD-46)

CAP-33 requires that "extensions add a line". AD-44's public history (player, price after, outcome, time) has no such row or column. After a leader is voided, the history shows prices above the restarted current price with no rule. `CancelListing` "needs no current leader" permits a cancel after a voided bid, while CAP-30 says "only before any bid". **Fix:** an `extended` outcome or an `extended_to` column; an outcome `voided`; state whether cancel tests for leader or for any bid row.

### M5. The average price lacks its inputs (AD-47, AD-42)

No sale time is named on a listing, and `ends_at` is wrong for a buy-now, so the 90-day window has no column. "Drop highest and lowest" is undefined for one or two sales, and integer rounding is unstated. AD-42's list of what reads current values omits the average window and count, and the stamp and minimum at listing. **Fix:** a `sold_at` and `final_price` column; no drop under 3 sales; a floor or round rule; complete the list.

### M6. Metrics and signals are not defined enough to compute once (AD-48)

"Active over 90 days" and "active that day" have no source: `last_seen_at` holds only the latest visit, so a nightly job cannot rebuild a past day. "Earnings" is not defined (mint only, mint plus sales, net of stamps). The five alt signals have no thresholds and no home for them, whether constants or settings. "A daily job replaces" `game_market_alt_signals` with no operation, against the write rule. **Fix:** define the sources, one definition of earnings, name a constant list, and name the operation.

### M7. Bounds are checked one value at a time (AD-42)

The no-loss floor depends on entrustment, stamp and commission, so a commission or stamp change can move the floor above an unchanged minimum. "Double or halve" cannot apply to a commission of 0 or to the list of durations. **Fix:** validate the whole candidate row, floor included; say which fields the ratio rule covers.

### M8. Deferred entries that can diverge

- "Feed selection thresholds: tuned with real activity" overlaps the sale threshold, which AD-42 makes a setting. Carve it out.
- "Notices beyond the outbid one: set by the UX". A seller's or winner's notice has a place to go only by contradicting AD-13's "only what calls for an answer", or by using the bell. Decide the channel now, even if the list is deferred.
- The typical price per rarity is optional in `market-economy.md` and has no entry. Say built, deferred or dropped.

### M9. The map and the Binds lines disagree

Map rows cite ADs whose Binds omit the capability: AD-6 (CAP-30), AD-10 (CAP-31, CAP-32), AD-11 (CAP-33, CAP-34), AD-13 (CAP-31), AD-15 (CAP-33), AD-18 (CAP-36). AD-42 binds only CAP-30 and CAP-35, though entrustment, increment, soft close, commission and the average read it. The CAP-13 row lacks AD-49 and AD-42, CAP-33 lacks AD-13 and AD-46, and CAP-34 lacks AD-45. AD-40 binds all nine, yet only CAP-29 and CAP-30 cite it.

## Low

- AD-43: when a card does not fit under the cap, does the batch stop or continue with cheaper cards? One `mint` entry per batch also records no cards, so the event must carry them.
- AD-44: the tie rule (the earlier maximum keeps the lead) is not restated beside `AuctionMath`.
- AD-40: rate limits have no values and need `by:` the player; the repo's existing calls set explicit numbers.
- AD-44: `PlaceBid` takes the seller's bank lock on every bid, only needed for buy-now. A seller with many live auctions queues their own pack openings against the 200 ms p95. Accept it or take the lock only on buy-now.
- AD-40 to AD-49 have no **Costs** line, unlike AD-8, AD-33 and AD-34; the extraction of `move`, the check-constraint migrations and the `FeedEntries` change belong there.
- Spec: CAP-18's "a visitor reaches only…" list does not include the market, while CAP-33 opens it. The code follows CAP-33.
- `catalog_card_seasons.rarity` is nullable; say that an unrated card-season can be neither entrusted nor listed.

## Coverage

| Requirement | Status |
| --- | --- |
| Only entrustment mints; stamp, commission, forfeit destroy | Landed (AD-41) |
| Permanent record that balances rebuild from | Landed, weakly enforced (M2) |
| Integer amounts | Landed (AD-41) |
| Mint in code, bank means the capsule reserve | Landed (AD-40) |
| Friend trades stay free | Holds: nothing in AD-40 to AD-49 touches them |
| Legal condition before opening | **Not landed** (C1) |
| No real money | Holds by absence; no rule needed |
| Export of history, listings, bids | Landed (AD-46) |
| Deletion erases the name, destroys the balance, keeps the record | Landed (AD-41, AD-46, AD-49) |
| Private player uses the market, name with no link | Landed (AD-44, AD-49) |
| Listing holds one copy | Landed (AD-44) |
| Oversized batch in selection order | Landed; skip-or-stop open (Low) |
| New listings only for a setting change | Landed (AD-42) |
| Starting value and bounds of settings | Partly (C1, M7) |
| Auction arithmetic and worked example | Landed; verified by hand: 26,300, then 31,500, seller 28,350 |
| Soft close, cap, whole cards, reservation | Landed |
| Market sale excluded from the weekly goal | **Not landed** (H2) |
| Sales in the feed | Partly: threshold read (AD-42), entry undefined (H5) |
| Average price per edition, few or no sales | Partly (M5) |
| Compact amounts, no euro sign | **Not landed** (M3) |
| Brotherhood justifies each fee | Partly: announcement only (M3) |
| Extensions in the bid history | **Not landed** (M4) |
| Four indicators, plain language, no auto regulation | Landed; definitions open (M6) |
| Five alt signals, no limit on trades | Landed; thresholds open (M6) |
| No seniority gate, no welcome bonus | Holds |
| Typical price per rarity (optional) | Not decided (M8) |
