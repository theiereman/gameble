# Rubric and reconcile review — spine update 2026-10-14 (seasons become reprints)

- **Spine:** `architecture-gameble/architecture-gameble.md` (uncommitted diff of 2026-10-14: AD-5, AD-9, AD-10, AD-14, AD-25, data model note, capability map CAP-23, Deferred)
- **Inputs reconciled:** `change-season-carryover/change-season-carryover.md` §4.5 (and §2–4.4 where load-bearing); `spec-gameble/spec-gameble.md` CAP-6, CAP-7, CAP-20, CAP-22, CAP-23, Constraints (Card copies, Launch scope); `spec-gameble/catalog-and-rarity.md` Seasons; `spec-gameble/later-roadmap.md` Pioneer; `epic-seasons-carry-over/` (md and tickets.toml); `epic-recognizable-sets/tickets.toml` entries 5, 7, 8, 15.
- **Codebase checked:** `packs/game` (`ReleasePlayer`, `SetCompletion`, `BankLock`, `TradeLocks`, `AcceptTrade`, `OpenPack`, `GrantGoalReward`, `HealBanksJob`, `HealBank`, `FirstDiscovery`, `CreatePlayerState`, `Handlers::SeasonPublished`, `Handlers::Achievements`, `SetProgress`, `TierCounts`, `CollectionSummary`); `ux-gameble/EXPERIENCE.md` (rarity counter, RAPPORT) for one cross-check.

## Verdict

**Conditional pass.** Section 4.5 landed in full and in the right places; the allocation rule is tighter than the proposal (BankLock, both trade players, the earlier-holding condition), and AD-14's first-discovery sentence ratifies `Game::ReleasePlayer`, which keeps the row and clears only `pack_id`. The update leaves five divergence points open. Three of them hit epic 13 now, before launch: the old-season packs still in banks, AD-5's counting rule being too broad, and the "one Game query" that no ticket builds first. Fix findings 1 to 5 before 13.5 starts; the low findings can be fixed in the same pass.

## Findings

### 1. HIGH — Banked packs keep delivering the earlier season after a publication

- **Where:** AD-5 ("Draws read only the published season"), AD-7, spec Constraints › Card copies ("Draws give only the published season's cards; earlier editions change hands only by trade"), CAP-23 ("before the hub and before any opening").
- **Problem:** Packs are drawn when banked (AD-7). At a publication, `Game::Handlers::SeasonPublished` → `HealBanksJob` only fills short banks, so up to ten pre-drawn regular packs per player (plus any unopened daily bonus or reward packs) still hold the previous season's card-seasons and are opened after the publication. This contradicts the new Card copies constraint. The booster plan's own deferred note already records it ("a pack drawn in an earlier season … real (packs are drawn when banked)"). It also undermines the allocation rule. A player who joined in season N−1 and opened nothing holds no earlier card, so the receipt run by their first opening gives them nothing. That opening then credits N−1 cards, so their next hub visit redirects them to the allocation screen after an opening. Units 13.5 and 13.15 (which count editions), 17.1 (receipt) and 17.2 (redirect) would each settle this their own way.
- **Fix (the author decides one):**
  - (a) **Redraw at publication:** add to AD-7: "When a season is published, every unopened pack is redrawn from it, keeping its kind, its count, its availability time and its odds (a reward pack keeps its Épique-or-better guarantee), one player per transaction, by the same job that heals banks." This keeps the spec as written.
  - (b) **Ratify the code:** amend the spec's Card copies to "…earlier editions are gained only by trade or from packs banked before the publication". Then state in AD-10 that a receipt with no earlier holding still records the season as received and seen, so a later opening of an old pack never triggers the screen.

### 2. MEDIUM-HIGH — AD-5's "every reader counts a game once … at the best minted rarity" contradicts the rarity counter and AD-23

- **Where:** AD-5, last holding bullet; AD-23 ("the per-tier counts before the opening"); `EXPERIENCE.md` Rarity counter ("Copies owned per rarity; a count updates as each card is revealed"); change proposal §4.6 RAPPORT ("Distinct games per best owned rarity, and copies across editions"); `Game::TierCounts` and `TierCounts.before_opening`.
- **Problem:** The rule binds every reader, but the rarity counter counts copies at their minted rarity and ticks up once per revealed card in the booster island. Under "a game once at its best rarity", a duplicate would add nothing and an upgrade would move a game from one tier to another. Neither the island's per-reveal increment nor `before_opening`'s subtraction would then match the server. RAPPORT also keeps a copies figure. Two units (13.15's collection reads and the booster's counter) would read AD-5 differently.
- **Fix:** Narrow the rule: "Every reader that counts games (the total counter, set progress, the album, the grid tile, the tier pass) counts a game once across its editions, at the best minted rarity held, through `<named query>`. The rarity counter and copy counts count copies at their minted rarity across every edition." Add to 13.15 that `TierCounts` (including `before_opening`) drops its published-season filter.

### 3. MEDIUM — "One `Game` query" is unnamed, and the ticket order builds edition counting three times before it exists

- **Where:** AD-5 ("through one `Game` query"); tickets 13.5 (tier pass across editions), 13.7 ("Set progress counts every edition", i.e. `Game::SetProgress`), and 13.8 ("it creates the best-edition read that entry 15 reuses").
- **Problem:** 13.5 and 13.7 are built before 13.8, so each writes its own card-level join. The tier insert (today `SetCompletion::RECORD_SQL`, joined by card-season) and `SetProgress` would carry two definitions of "holds a member", and 13.8 would add a third. Nothing in the rule says which query it is or that the set-based tier insert must share it. The rule cannot be enforced as written, and the ticket wording contradicts it.
- **Fix:** In AD-5, name the definition, for example "`Game::HeldGames`: per player and card, whether held, best minted rarity, copies and editions; the tier insert uses its SQL fragment". In the tickets, have 13.5 create it, have 13.7, 13.8 and 13.15 reuse it, and reword 13.8's "it creates the best-edition read" to "reuses 13.5's held-games read".

### 4. MEDIUM — Carried tier rows publish no event, so a tier first met at publication unlocks no back

- **Where:** AD-10 allocation bullet ("the carried rows publish no `Game::SetTierReached` or `Game::SetCompleted`"); AD-25 ("Unlocks are granted only by `Game` handlers on events"; "A set's back unlocks on gold on that set, once"); `Game::Handlers::Achievements` (listens to `SetCompleted`, `PackOpened`, `CardReposted`, `TradeAccepted`).
- **Problem:** `ReceiveSeasonAllocation` inserts every tier the player already meets, not only tiers earned before. A tier can be met for the first time at a publication: a new franchise or studio reaches 3 games, a theme joins the list, or a hall of fame set shrinks. A carried `gold` that is the first gold for its kind and key then fires no event, so no back is unlocked. The achievements "first complete set" and "three complete sets" wait for the next `PackOpened`. The card backs epic (Cosmetics) and 17.1 would each assume the other grants the back. The spec says only "tiers the player still meets", which hides the case.
- **Fix:** Add to AD-10: "`Game::SeasonAllocationReceived` carries the inserted tier rows; the card-back unlock and achievement handlers answer it as they answer `SetTierReached` and `SetCompleted`; the feed handler does not." Alternatively, rule that carried rows grant nothing new, and have the allocation screen show the tier as earned without its back. That rule needs the author.

### 5. MEDIUM — The Pioneer entry under Deferred sets a visibility rule that contradicts AD-13

- **Where:** Deferred › Pioneer ("reads « anonyme » when the player is private, banned or deleted"); `later-roadmap.md` Pioneer ("Signed-out visitors see the name too"); AD-13 ("Every surface that names a player beside their cards asks … `Game::Visibility.visible?(viewer, owner)`; public surfaces show an entry only if every player it names is public").
- **Problem:** The card detail is a public surface (CAP-18), and the pioneer is a player named beside a card. Under the Deferred text, a friends-only pioneer is named to everyone, signed-out visitors included. Under AD-13, they are hidden from non-friends. The feed's existing first-discovery entries follow AD-13. Pioneer and the feed would show the same discoverer two ways, and a Deferred entry must not open that divergence.
- **Fix:** "…its name shows when `Game::Visibility.visible?(viewer, pioneer)` holds and reads « anonyme » otherwise (private, friends-only to a non-friend, banned, deleted)". Mirror the wording in `later-roadmap.md`, or record an explicit AD-13 exception approved by the author.

### 6. LOW — Binds lists and the capability map disagree

- AD-9's rule now holds the allocation seasons, but its Binds lacks CAP-23.
- The map lists AD-11 for CAP-23, but AD-11's Binds lacks CAP-23.
- AD-25 binds CAP-23, but the map row for CAP-23 lacks AD-25. It also lacks AD-9 (state columns) and AD-18 (the Brotherhood line and the plural "n saisons").
- The CAP-7 row ("web layer, `Catalog`") lacks `Game`, which now supplies the editions owned on the card detail.
- **Fix:** Add CAP-23 to the Binds of AD-9 and AD-11. Change the map row to `CAP-23 | Game, web layer | AD-5, AD-9, AD-10, AD-11, AD-18, AD-25`, and add `Game` to the CAP-7 row.

### 7. LOW — "A reward" is not an operation that raises quantities

- **Where:** AD-10 allocation bullet ("an opening, an accepted trade for both players, a reward"); ticket 17.1 ("the two operations that raise quantities (the opening, and both players of an accepted trade)").
- **Problem:** `Game::GrantGoalReward` inserts a reward pack; quantities rise only in `OpenPack` and `AcceptTrade` (the only writers of `game_holdings.quantity`). The spine and the ticket disagree, and a builder may add a receipt to the reward job.
- **Fix:** Use "(today `Game::OpenPack` and `Game::AcceptTrade`, for both players)".

### 8. LOW — The receipt breaks AD-10's literal lock order

- **Problem:** The receipt runs "first", under the bank lock. It writes the player's tier rows and their `game_player_states` row before `AcceptTrade` and `OpenPack` lock holdings, but the stated order is bank locks, then holdings, then `game_player_states`. It is safe today, because every writer of those rows holds the bank lock, but the rule as written contradicts itself.
- **Fix:** "Lock order: bank locks in ascending player id, then each locked player's pending allocation, then holdings…, then `game_player_states` rows."

### 9. LOW — The starting values of the received and seen seasons are not fixed in the spine

- **Problem:** Ticket 17.1 starts existing and new accounts at the published season. The spine says nothing, and it does not say whether a receipt that "receives nothing" still records the season. `CreatePlayerState`, the backfill and the redirect of 17.2 depend on that value (see finding 1b).
- **Fix:** One sentence in AD-10: "A player state starts with both seasons at the published one (none when none is published); a receipt records the season as received even when it inserts nothing."

### 10. LOW — The active back's season mark is not stored on the pack

- **Where:** AD-23 ("The key and the active card back are stored on the opened pack"); AD-25 ("the active back records the season whose mark it wears"; it shows "as stored on the pack").
- **Problem:** Once the player changes the mark, a pack reopened as "mon dernier booster" or replayed by its key shows a different mark.
- **Fix:** In AD-23, use "…the active card back and its season mark are stored on the opened pack".

### 11. LOW — Marking the allocation seen is neither an event nor housekeeping

- **Problem:** AD-10 lists the housekeeping writes that publish nothing (last seen, the NOUVEAU watermark). The screen's POST marks the allocation seen, which is neither.
- **Fix:** Add "the allocation's seen season" to the housekeeping list, or name the operation and its event.

## Reconcile: input claims that did not land or that now disagree

| # | Input claim | State in the spine | Action |
| --- | --- | --- | --- |
| R1 | §4.5 AD-5, AD-9, AD-10 (tier rule, mark, allocation, received/seen), AD-25, achievements, data model note, map row, Deferred | All landed. The spine adds BankLock serialisation, "both players", the earlier-holding condition on the redirect, the best-rarity sentence and the title "latest season" | None; see findings 2 and 3 for the added sentence |
| R2 | Spec Card copies: "Draws give only the published season's cards; earlier editions change hands only by trade" | Contradicted by the code (banked packs keep their season) and not settled in the spine | Finding 1 |
| R3 | Spec CAP-23: "A player who joined in the current season sees no allocation" | The spine (and the epic's author decision, R5) use "a player with no holding from an earlier season", traded cards included | Amend the spec line to the author's rule; the spine is right |
| R4 | Spec CAP-23: carried tiers "never celebrated at an opening or announced in the feed" | Landed. The fate of the backs and achievements of carried rows is not stated | Finding 4 |
| R5 | Spec CAP-20: "the player picks which season's mark the active back wears" | AD-25 landed; the mark is missing from the pack (AD-23) | Finding 10 |
| R6 | Spec CAP-6 and catalog-and-rarity Seasons: one card per game at its best rarity; the counter never drops | Landed in AD-5, but stated too broadly | Finding 2 |
| R7 | later-roadmap Pioneer: "Signed-out visitors see the name too"; anonyme for private, banned or deleted | Deferred keeps the anonyme list, which conflicts with AD-13 for friends-only players | Finding 5 |
| R8 | Change §2 Risk: "set progress across editions must stay inside the 200 ms p95" | Covered by AD-7's budget and tickets 13.5 and 17.5 | None |
| R9 | Change log: "first discoveries stay per card and season, each edition with its own pioneer" | AD-9 (one row per card-season) and AD-14 ratify `ReleasePlayer`, which keeps the row | None |
| R10 | Ticket 17.1 `unknown`: "Whether a concurrent opening and trade can both receive the same allocation" | Settled by AD-10 (receipt under the BankLock, received season checked there) | Drop the unknown from 17.1 |
| R11 | Ticket 17.1: "the two operations that raise quantities" | The spine lists three, including "a reward" | Finding 7 |
| R12 | Ticket 17.1: "existing players and new accounts start with both seasons at the published one" | Not in the spine | Finding 9 |
| R13 | Ticket 13.8: "it creates the best-edition read that entry 15 reuses" | Disagrees with AD-5's one query, which 13.5 and 13.7 already need | Finding 3 |
| R14 | Epic 13 R5: "each tier or completion reached for the first time writes one row" | Under seasons, a tier is reached again on each season's set and gets a new row | Reword: "the first time on that set" |
| R15 | Tickets 13.5, 13.7 and 15 otherwise (any edition counts; tiers only on published-season sets; achievements by kind and key; best edition; total counter never drops) | Agree with AD-5, AD-10 and AD-25 | None |
| R16 | Epic 17 Requirements and References (AD-5, AD-10, AD-11, AD-25) | Agree, once the map row of finding 6 is fixed | None |

## Observations (no action required)

- AD-15 still addresses a set by season number, kind and key, while CAP-6 makes a set the same across seasons and reads progress against the published season. No rule says what an album URL for an earlier season shows (that season's members, or a redirect to the published one). Tickets 13.8 and 17.3 should agree on this. It is a candidate for one line in AD-15 if the author wants it fixed now.
- The recap's "earned during the season that ended" (backs, achievements, goal rewards) needs a time window between two publications. Only 17.2 reads it, so it is not a cross-unit divergence.
- The first opening after a publication runs the receipt over every published set for that player. This happens once per player and season, and the 17.5 rehearsal measures the p95.
