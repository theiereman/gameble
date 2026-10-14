# Adversarial review: the 2026-10-14 update (seasons are reprints)

Spine reviewed: `architecture-gameble.md` (updated 2026-10-14). The changes are AD-5 (holding a member across editions, one `Game` query per reader), AD-9 (received and seen seasons on `game_player_states`), AD-10 (tier rule on published-season sets, `Game::ReceiveSeasonAllocation`, the allocation redirect), AD-14 (first discoveries kept), AD-25 (backs and titles across seasons), the capability map (CAP-23) and Deferred (pioneer).

Source of intent: `change-season-carryover/change-season-carryover.md` section 4.5, and spec CAP-6, CAP-20, CAP-22, CAP-23.

Units one level down: `epic-seasons-carry-over/tickets.toml` (entries 1 to 3), `epic-recognizable-sets/tickets.toml` (entries 5, 6, 8, 15), Cosmetics (epic 9, Done when 2, 3, 5). I checked them against the code they build on: `Game::OpenPack`, `Game::AcceptTrade`, `Game::TradeLocks`, `Game::BankLock`, `Game::SetCompletion::RECORD_SQL`, `Game::DrawPool`, `Game::TierCounts`, `Game::GrantGoalReward`, `Game::CollectDailyBonus`, `Game::HealBanksJob`, `Game::CreatePlayerState`, `Game::MarkCollectionSeen`, `Game::Handlers::PlayerActivity`, `Game::Handlers::Achievements`, `Game::AchievementProgress`, `Catalog::PublishedSeason`, `Catalog::PublishSeason`, `app/frontend/components/Booster.tsx`, and the schema.

Method: for each change, I built two units that each follow every AD word for word and still don't fit together. Each finding names the clash and gives rule text that closes it.

**Verdict: the direction is sound but the update is not ready to build as written.** Holdings stay one row per edition, sets match across seasons by kind and key, and the allocation is received apart from being seen. All of that is coherent and fits the code. But the update adds a second way to write tier rows (the receipt) next to the first (the tier pass), and it doesn't fix four things:

- the season both ways read;
- what each tier row records about where it came from;
- which handlers answer the receipt;
- which measure "every reader" means.

That leaves three ways to celebrate a tier twice or lose one, and one clash with code that is already built (the top-bar counter). I found 11 holes: 3 high, 5 medium, 3 low. Each closes by adding a sentence to an existing AD. None needs a new AD. F4 and F5 hit epic 13 (before launch), so fix them before 13.5 and 13.15. The rest must land before epic 17 entry 1.

Severity: **high** means a carried tier is celebrated, a reward is lost, or two units ship incompatible data that a later story has to unpick. **Medium** means a visible inconsistency or a latent clash that a predictable change (a replica, a new way to gain cards) turns into a bug. **Low** means a wording gap a builder would probably resolve the same way, but might not.

---

## High

### F1. Within one operation, the published season is read several times, and a publication can land between the reads (AD-5, AD-7, AD-10)

- **Unit A, epic 17 entry 1 (the receipt):** follows AD-10 to the letter. Under the player's bank lock, `ReceiveSeasonAllocation` reads the published season through `Catalog::PublishedSeason` and finds it equal to the received season (N), so nothing is pending.
- **Unit B, epic 13 entry 5 (the tier pass):** also follows AD-10 ("each tier of a published-season set"). It writes its insert the way `Game::TierCounts` already does, with a `PUBLISHED_SEASON` subquery ("highest-numbered published") embedded in the SQL. `Game::DrawPool.current` re-reads `Catalog::PublishedSeason` on every call as well, and `OpenPack` uses it to redraw a pack from an older season.
- **Clash:** `Catalog::PublishSeason` takes no bank lock, and Postgres runs at READ COMMITTED, so each statement sees the latest commit. Suppose season N+1 commits between the receipt and the tier pass of one opening. The receipt sees N (nothing pending). The redraw and the tier pass see N+1. Every tier the player already meets in N+1's sets is then inserted by the tier pass, each with its own `SetTierReached` or `SetCompleted` event: celebrated in the opening's response, posted to the feed and the LIVE ticker. That is exactly the carried celebration CAP-23 forbids. On the next operation, the receipt finds N+1 pending and inserts nothing (the rows already exist), and the allocation screen then lists as "received" tiers the feed has already announced. The window is one opening wide, and it opens on the very first openings after every publication, the busiest moment there is.
- **Rule fix (AD-10, after the receipt sentence):** "An operation that raises quantities reads the published season once, right after taking the bank locks, and passes that season to the allocation receipt, the draw, the tier pass and its response. No statement inside it reads 'the latest published season' again, and `Game::DrawPool` is fetched for that season (if the pool has moved on, the operation fails and is retried)." Alternative, if the shorter guarantee is preferred: "`Catalog::PublishSeason` switches the published season under an exclusive season lock, and every quantity-raising operation holds the shared one", taken before the bank locks in the lock order. This costs openings a stall as long as the flip. It works only if the flip is a short transaction separate from the bulk writes.

### F2. Carried rows publish no tier event, but backs and achievements are granted only from tier events (AD-10, AD-25)

- **Unit A, Cosmetics (epic 9, Done when 2):** follows AD-25 ("unlocks are granted only by `Game` handlers on events"). A handler answers `SetTierReached` with gold and inserts the set's back unlock, `ON CONFLICT DO NOTHING`. The picker lists the seasons a back was earned in from the player's gold rows, as AD-25 says.
- **Unit B, epic 17 entry 1:** follows AD-10. The receipt inserts "the tier rows the player already meets in the published season's sets" and publishes only `SeasonAllocationReceived`, with no tier event.
- **Clash:** "already meets" is not the same as "had before". A gold first met at the receipt is carried silently. That happens with a theme or hall of fame set new in the season, a set that shrank so its threshold fell, or a game moved into a theme. No handler unlocks its back, so the player has a gold row and no back. The picker reads gold rows and lists season marks for a back the player can't select: two sources of truth for one unlock. `Game::Handlers::Achievements` listens to `SetCompleted` and not to the receipt, so "first complete set" is also granted late, at the next unrelated opening (whose `PackOpened` reruns `GrantAchievementsJob`), with its toast attached to a pack that has nothing to do with it. If a third unit makes the back handler answer `SeasonAllocationReceived` and the receipt runs inside `OpenPack`, AD-23's "any card back unlocked by it" puts the carried back in the opening's response, which is a carried celebration again.
- **Rule fix (AD-25, first bullet):** "A set's back is unlocked while the player has a `gold` row on a set of that kind and key, in any season; set backs have no unlock row, and the opening's response announces one only when the opening inserted the first such row." This makes it derived, as titles and menu themes already are. **Or, keeping unlock rows (AD-10):** "The card-back and achievement handlers answer `Game::SeasonAllocationReceived` over the rows the receipt inserted; the feed handler does not. An unlock it causes is announced on the allocation screen only, never by an opening's response or the private stream." AD-25's announcement list then gains the allocation screen.

### F3. Tier rows don't record how they were reached, so three readers each guess (AD-10, AD-23, CAP-23)

- **Unit A, epic 17 entry 2 (the screen):** follows AD-10. The GET lists "the sets that follow you" as the player's tier rows on published-season sets. This is the only honest read, because rows have no other attribute.
- **Unit B, epic 13 entry 5 (opening response and replay):** follows AD-23 ("a repeated key returns that pack as it was opened"). Tier rows don't store the pack, so the replay rebuilds "tiers reached by this opening" from the rows whose `reached_at` equals `pack.opened_at`. That is the natural key, since `OpenPack` takes `now` once and passes it to every insert.
- **Clashes:**
  1. A returning player opens a pack from a tab loaded before the publication, which AD-10 allows. The opening crosses silver on Roguelike and celebrates it. Later the hub redirects to the screen, which lists Roguelike silver under "vos sets vous suivent". The same tier is celebrated once and presented again as received.
  2. The receipt runs inside that same opening with the same `now`, so its carried rows share `reached_at` with the crossed ones. The replay of a lost response then celebrates every carried tier that the first answer left out.
  3. The recap of season N+1 ("tiers reached in the season that ended", CAP-23) reads N+1 rows, which include the rows carried into N+1. Those were already shown at the previous allocation and are presented again as earned by play.
- **Rule fix (AD-10, tier rule):** "Each tier row records how it was reached, written once by the operation that inserts it: the pack, the trade, or the allocation. The opening's response and its replay read the rows of that pack; the allocation screen lists the allocation rows of the published season; a season's recap lists that season's rows reached by play." With F2's derived backs, this also gives "the opening inserted the first gold row" a precise meaning.

---

## Medium

### F4. "Every reader counts a game once, at its best rarity" contradicts the top-bar counter and AD-23's per-tier counts, both already built (AD-5, AD-23)

- **Unit A, epic 13 entry 15 (every edition counts):** follows AD-5 ("every reader counts a game once across its editions, at the best minted rarity held, through one `Game` query"). It rewrites `Game::TierCounts` to count distinct games at their best rarity and points every reader at it, including `before_opening`.
- **Unit B, the booster island (built):** follows AD-23 and EXPERIENCE's rarity counter ("copies owned per rarity; a count updates as each card is revealed"). `Booster.tsx` sets `counts = tierCountsBefore` and adds one per revealed card (`countsAfterReveal(before, card.tier)`).
- **Clash:** a player holding Hades in Épique pulls a Rare Hades. The island ticks Rare up by one, but the server count (best rarity) doesn't move. The next page load drops the counter the island just raised, and every duplicate pull makes it drift further. Leaving Unit A out isn't an option either: today `TierCounts` filters on the published season, so the top-bar counter falls to zero at every publication. That is the symptom this change set out to remove (change proposal, section 1).
- **Rule fix (AD-5, holding bullet):** "Collections have two measures, each one `Game` query that reads every edition and never filters by season. *Games*: distinct cards, each at its best minted rarity (the grid tile, the total counter, set progress, RAPPORT's games). *Copies*: quantities per minted rarity (the top-bar rarity counter, AD-23's counts before an opening, RAPPORT's copies)." Replace "every reader counts a game once" with a pointer to these two measures.

### F5. The tier pass finds its candidate sets by credited card-season, so a traded earlier edition reaches no set (AD-10)

- **Unit A, epic 13 entry 5:** extends `Game::SetCompletion::RECORD_SQL`, which narrows the candidate sets to `catalog_set_memberships WHERE card_season_id IN (:credited)`. It adds AD-10's "published-season set" filter and makes the member join edition-aware, as the rule asks.
- **Unit B, a trade (built, `AcceptTrade#completions`):** passes the credited card-season ids, which for an S1 Hades are S1's.
- **Clash:** the S1 card-season's memberships are S1 sets, and those "earn no new tier". So a tier the trade truly crosses on the published season is never recorded by the trade. It surfaces later, either at an unrelated opening that happens to touch a member of the set (celebrated at the wrong moment, credited to the wrong pack) or silently at the next season's allocation. The spec's "an opening or a trade celebrates only the tiers it crosses itself" fails for exactly the case CAP-23 adds: earlier editions change hands only by trade.
- **Rule fix (AD-10, tier rule):** "The tier pass reaches the published season's sets through the credited cards (card → its card-season in the published season → that card-season's memberships); a credited card absent from the published season reaches no set."

### F6. The received and seen columns have no initial value, and nothing says whether "receives nothing" advances them (AD-9, AD-10)

- **Unit A, epic 17 entry 1:** follows AD-10 ("a player with no holding from an earlier season receives nothing"). When there is nothing to receive, it returns early without writing, so `received` stays put. The ticket's own note "existing players and new accounts start with both seasons at the published one" becomes a backfill plus a line in `CreatePlayerState`.
- **Unit B, epic 17 entry 2 (the redirect):** follows AD-10 ("while the last seen season is below the published one and they hold a card-season of an earlier season"). It reads a missing or null `seen` as 0 and "hold" as "a holding row exists".
- **Clashes:**
  1. `game_player_states` rows are also created lazily by upserts in `Game::Handlers::PlayerActivity` and `Game::MarkCollectionSeen` (`||--o|` in the model). Those upserts leave the new columns null, so a row created that way reads as "never seen".
  2. A player who joined in season N+1 trades for an S1 card mid-season. They now "hold a card-season of an earlier season", and with null or stale `seen` the hub redirects them to an allocation recapping a season they never played. The spec says "a player who joined in the current season sees no allocation". The epic note says "traded ones included". The spine decides neither.
  3. Holding rows whose quantity is zero stay in the table, so "hold" by row existence and "hold" by `quantity > 0` give different players a screen.
  4. "Season" can mean `catalog_seasons.id` or `number`. One unit stores the id and the other compares it with numbers.
- **Rule fix (AD-9):** "The received and seen seasons are season numbers, never null: any write that creates the `game_player_states` row sets both to the published season's number (0 when none is). The receipt always advances `received` to the published season, inserting rows or not." **And in AD-10:** "The redirect holds while `seen` is below the published season and the player holds, with quantity above zero, a card-season of a season below the published one; both the receipt and the redirect use this one `Game` query."

### F7. The redirect decision runs on the read path, which AD-11 allows to lag (AD-10, AD-11)

- **Unit A, epic 17 entry 2:** puts the redirect in the hub and booster GETs, which by AD-11 run on the `reading` role.
- **Unit B, the read replica (Deferred):** added "as a configuration change", as AD-11 promises.
- **Clash:** the screen's POST marks the season seen and redirects to the hub. The hub's GET reads a replica a second behind, sees `seen` still below the published season, and redirects back to the allocation screen. The screen is shown twice or loops, and a second POST is harmless only by luck. The same lag can skip the redirect right after a publication (the replica still shows N while openings on the primary already run in N+1). This is latent today because `reading` points to the primary, but nothing in the spine stops a replica from triggering it.
- **Rule fix (AD-11):** "Requests whose decision must reflect the player's own last write (the allocation redirect) read the primary; adding a replica keeps them there."

### F8. Which operations trigger the receipt is a list, and where the receipt falls in the lock order isn't stated (AD-10)

- **Unit A, epic 17 entry 1:** wires the receipt into the two quantity-raising code paths the ticket names: `OpenPack#credit` and `AcceptTrade#move`. "A reward" in AD-10 matches nothing, because `GrantGoalReward` inserts a pack and raises no quantity.
- **Unit B, any later raiser:** a V2 market purchase, an event or season card grant, or a handler that hands out cards as an achievement reward. Each follows AD-3 and AD-10 as written and doesn't find itself in the list. Once the raise happens inside a handler, the receipt it should call publishes an event, which AD-10 forbids handlers to do.
- **Second clash:** "first receives" places the receipt's write to `game_player_states` (the `received` column) before `AcceptTrade` locks holdings. AD-10's lock order puts state rows after holdings. The bank locks make a deadlock unlikely today, but the rule as written contradicts itself.
- **Rule fix (AD-10):** "Quantities rise through one `Game` step that first receives the player's pending allocation, for each player it credits, before writing any holding; no other code raises a quantity, and no handler does. The receipt reads `received` under the bank lock without locking the state row, counts holdings as they stand before the credit, and writes the state row in its place in the lock order."

---

## Low

### F9. Menu themes count "distinct sets", while titles and achievements count distinct kind and key (AD-25)

AD-25 says a menu theme comes "when the player's distinct sets with a `gold` row reach its count". A set is a per-season row (AD-5). One cosmetics unit counts distinct `set_id`: gold on Roguelike in S1 and in S2 counts twice, and the 3-, 10- and 25-gold themes come early. Another counts kind and key, as the achievement rule does. **Fix:** "a menu theme when the distinct set kinds and keys with a `gold` row reach its count." Also say which tier counts as complete for the set achievements, because AD-5 says `gold` and `complete` both complete a set while `Achievements` listens only to `SetCompleted`. Write: "a set counts as complete with a `gold` or `complete` row."

### F10. The pioneer's name rule bypasses AD-13 (Deferred, AD-13, AD-14)

The Deferred entry says the pioneer's name is "read through `Accounts` at display", showing "anonyme" when the player is private, banned or deleted. AD-13 says every surface naming a player asks `Game::Visibility.visible?(viewer, owner)`. A unit built from the Deferred entry shows a friends-only player's name to strangers on a public card page. **Fix:** "its name shows when `Game::Visibility.visible?(viewer, discoverer)` holds, and reads « anonyme » otherwise."

### F11. Smaller wording gaps

- **The pack's back mark (AD-23, AD-25).** "The active back records the season whose mark it wears", but AD-23 stores only the back key on the opened pack. A replay of a lost response, or "mon dernier booster", then reads the mark live and shows a mark changed since the opening. Fix: "the opened pack stores the active back's key and season mark."
- **Seasons skipped while away (AD-10, CAP-23).** A player away through N+1 and N+2 gets one receipt (N+2), which is correct since N+1's sets earn nothing more, and one screen. "Recaps the season that ended" doesn't say which seasons it covers. Fix: "the screen recaps every season after the last one seen; tiers are received for the published season only."
- **Openings are never refused (AD-23).** CAP-23 says the screen comes "before any opening". The spine resolves this by silent receipt, so a booster tab loaded before the publication still opens. A builder reading the spec may add an `allocation_unseen` code that the island doesn't handle. Fix (AD-23, Failure): "the list of codes is closed; an unseen allocation never refuses an opening."
- **Cost of the receipt (AD-7).** The first opening of every returning player after a publication pays for the receipt across all of the season's sets, joined by card, inside the 200 ms p95. Say "the receipt is one `INSERT … SELECT` over the published season's tier rows". Note that a job serving players ahead of time is legal (AD-14: one player per transaction, under the bank lock), so the rehearsal (epic 17 entry 5) can fall back on it.

---

## What holds

- **One row per edition (AD-6) with a member held "by card" (AD-5)** needs no schema change. Holdings already store the card-season, and `catalog_card_seasons.card_id` makes the join.
- **The bank lock as the receipt's serialiser** is real. `Game::BankLock` is a transaction-scoped advisory lock, `OpenPack`, `GrantGoalReward`, `CollectDailyBonus`, `MarkCollectionSeen` and `HealBank` take it through `lock_bank`, and `AcceptTrade` takes both players' locks in ascending id (`TradeLocks.players`). Concurrent operations of one player can therefore receive only once, provided F1 fixes the season they receive.
- **Operations that don't raise quantities** (`GrantGoalReward`, `CollectDailyBonus`, `HealBank`) only insert packs, which are redrawn into the published season when opened (`OpenPack#drawn_in_published_season`). They need no receipt.
- **First discoveries per card-season (AD-14)** match `Game::FirstDiscovery` and `ReleasePlayer`, which keeps the row and clears only its pack. Only openings write them, and openings draw only the published season, so earlier editions' pioneers are frozen as intended.
- **Several events from one operation** already exist (`PackOpened`, then `CardDiscovered` and `SetCompleted`). The receipt's event adds one more inside the opening's transaction without breaking "one primary event", as long as F2 decides which handlers answer it.
