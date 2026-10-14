# Review — reality check of the 2026-10-14 amendments (seasonal allocation, editions, pioneer)

Independent reviewer, 2026-10-14. Lens: is every committed decision checked against reality rather than asserted from memory? The update names no new technology, so it is checked against the code and schema already in the repo. Scope: AD-5, AD-9, AD-10, AD-14, AD-25, the data model note, the capability map (CAP-23) and Deferred (working-tree diff of `architecture-gameble.md`). The spine was not edited.

Read: `db/schema.rb` (`game_player_states`, `game_set_completions`, `game_first_discoveries`, `game_holdings`, `catalog_sets`, `catalog_set_memberships`, `catalog_set_tiers`, `catalog_card_seasons`), `Game::BankLock`, `Game::OpenPack`, `Game::ReleasePlayer`, `Game::SetCompletion`, `Game::FirstDiscovery`, `Game::CardBacks`, `Game::AchievementProgress`, `Game::Achievements`, `Accounts::DeletePlayer`, `config/initializers/event_store.rb`, the Game handlers, `spec-gameble/later-roadmap.md` and the spec's CAP-23.

**Verdict: pass with fixes.** The claims about what exists today are right: the lock order, the first-discovery retention, the one-row-per-card-season holdings, the ON CONFLICT pattern, and the editions keyed by `card_seasons`. No new technology is named. The risk is the opposite: the update layers a large amount of unbuilt design onto entities marked `[ADOPTED]` without saying it is new, and two rules do not fit the schema as it is.

---

## What holds against the code

- **Lock order.** `BankLock.acquire` is a transaction-scoped advisory lock (`pg_advisory_xact_lock`), and its header comment already states "bank locks by ascending player id, then holdings by player and card season, then `game_player_states` rows". The new "receive under the bank lock, check the received season there" fits, since the `game_player_states` row comes last.
- **First discoveries survive deletion.** `game_first_discoveries.player_id` is NOT NULL with an FK to `accounts_players`. `ReleasePlayer` only nulls `pack_id` and keeps the row. `Accounts::DeletePlayer` anonymises the player record and never deletes it, so the FK holds. The AD-14 sentence and the Pioneer "no migration" claim are true: the table has `player_id`, `card_season_id` (unique) and `discovered_at`.
- **Editions.** `game_holdings` is one row per (player, card_season), and `catalog_card_seasons` is unique on (card_id, season_id). "The minted season is the copy's edition" is exactly the current model.
- **`collection_seen_up_to`** (NOUVEAU watermark) exists on `game_player_states`, so "housekeeping writes publish nothing" is consistent.

---

## Findings

### F1 — Medium: set membership is per card-season, so "a card-season of that member's card in any season" is a different query from today's, and the update does not say so

`catalog_set_memberships` joins a set to a `card_season_id`, and `catalog_sets` is unique on (season_id, kind, key): a set exists once per season. `Game::SetCompletion::RECORD_SQL` matches `game_holdings.card_season_id = members.card_season_id`. AD-5 and AD-10 now require counting by *card* across seasons, with `COUNT(DISTINCT card_id)` and a join through `catalog_card_seasons`. This is a rewrite of the one SQL statement that decides `SetCompleted`, of the progress queries and of the album, not a tweak. `AchievementProgress::OBTAINED_SQL` also counts one per holding row, so a game held in two editions counts twice for `epics_obtained` and `legendaries_obtained`, against "every reader counts a game once across its editions".
**Fix:** add one sentence to AD-5 naming the join (holding's card-season to its `card_id`, then to the member's card in the set's season) and list the existing readers that change (`SetCompletion::RECORD_SQL`, `AchievementProgress`, album and counter queries), or state that the rarity achievements keep counting editions.

### F2 — Medium: `Game::ReceiveSeasonAllocation` is a second event-publishing operation nested in another operation's transaction, against AD-10's "one primary event"

AD-10 says an operation publishes one primary event. `OpenPack` already publishes `PackOpened` plus `CardDiscovered` and `SetCompleted` as secondary events. The new operation publishes `Game::SeasonAllocationReceived` from inside `OpenPack`, `AcceptTrade` (for both players) and the reward operations, and the update does not say whether it is a step of the caller or a nested operation, which transaction it joins, or in which order its event comes relative to the caller's. Two concrete gaps follow. (a) `OpenPack.call` locks the bank, then reads the next pack and credits holdings; the receive must sit between `lock_bank` and `credit` (and before `drawn_in_published_season`), otherwise "silent" tiers would be celebrated by the opening's own `publish_completions`. (b) "Checks the received season there" is ambiguous for a player with no earlier holdings: if nothing is written for them, every later operation re-runs the check, so the received marker should be set to the published season even when the allocation is empty.
**Fix:** state that it is a step called by the outer operation inside its transaction after the bank lock and before any credit, that its event is published before the caller's primary event and counts as secondary, and that the received season is recorded even when nothing is carried.

### F3 — Medium: the new vocabulary does not exist in the code and is marked `[ADOPTED]` without a "new" marker

Not in the repo today: `game_set_tiers` (the code has `game_set_completions`), `Game::SetTierReached`, `Game::ReceiveSeasonAllocation`, `Game::SeasonAllocationReceived`, `Catalog::SeasonSetsRebuilt`, `Catalog::RebuildSeasonSets`, the allocation screen, and the `game_player_states` columns for the received season, the seen season, the active title and the active menu theme. Also, `game_player_states` has no active-back column (`CardBacks.active_key` returns `standard` constant, its comment says epic 9 adds the column), although AD-25 states it as fact. Only `game_set_tiers` replacing `game_set_completions` and the rebuild predate this update; the allocation items are new in it. Existing precedent is the 2026-10-08 review, which flagged the same pattern. A reader of AD-10 cannot tell the existing `SetCompleted(player_id, set_id)` payload from the one to come.
**Fix:** add a short "To build" list in AD-10 and the data model note naming each new operation, event, table and column, and the two existing things that change (`SetCompletion`, `ReleasePlayer`, which today deletes `SetCompletion` rows and must delete tier rows). Give the new `game_player_states` column names so CAP-23's stories can reference them. The 2026-10-14 allocation items are the only ones in this review's lens; the rest is carried over.

### F4 — Low: the Pioneer note crosses a pack boundary it does not name

Deferred says the pioneer name is "read through `Accounts` at display". The card detail is a `Catalog` query (`packs/catalog/app/queries/catalog/card_detail.rb`, currently modified in the working tree), and Catalog cannot depend on Game or Accounts (Game → Catalog, Accounts). The name must be assembled in the web layer from a `Game` query on `game_first_discoveries` and `Accounts`'s visibility and ban state. The note also does not settle whether a signed-out visitor sees the name (the spec memlog leaves it open); the spine says the name reads « anonyme » for private, banned or deleted, which is fine, but "signed-out" is unspecified. The line uses the French word inside an English document; the rule that all repo text is English applies, so write it as `anonymous` with the locale key.
**Fix:** one line naming the web layer as the composer and the locale key; leave the signed-out question to the spec.

### F5 — Low: AD-5 repeats "Draws read only the published season"

The new bullet ends with the sentence already present two bullets above it in AD-5. Harmless; drop one.

---

## Not a finding

- `Game::BankLock` is keyed by player id only, so receiving an allocation under it also serialises the player's openings and trades, which is the intended behaviour.
- The rebuilt-sets handler still deletes completion rows in one statement, an exception AD-10 already records; the update does not widen it.
