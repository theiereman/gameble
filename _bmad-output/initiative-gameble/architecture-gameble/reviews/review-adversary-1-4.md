# Adversarial review: release 1.4 additions to the spine

Date: 2026-11-14. Scope: AD-52 to AD-57, the 1.4 amendments to the Design Paradigm `Game` row, AD-7, AD-13, AD-14, AD-24, the Capability map rows CAP-39 to CAP-42 and the two new Deferred bullets. Rules read: `spec-gameble/duel-rules.md`, `spec-gameble.md` CAP-39 to CAP-43. Code read: `app/domains/game` (reservations, trade release, market release, `ReleasePlayer`, the ban, deletion and visibility handlers, the activity handler, `BankLock`, `TradeLocks`), `app/channels`, `app/models/player_stream.rb`, `db/schema.rb`, `app/domains/steam` (review data).

Method: for each hole, two stories built by different people, each obeying every AD to the letter, that still build incompatibly or break a rule of `duel-rules.md`. Each hole ends with the smallest AD change that closes it. The spine was not edited.

## Verdict on the question asked about deck blocks

No existing release path sets `reserved` to 0 or recomputes it from trades or listings. Every release subtracts what it reserved:

- trades: `TradeSteps#release` (`reserved - quantity` of the offer) for decline, cancel, expiry, counter and `CancelOpenTrades` (going private, ban, deletion); `MoveHoldings#move` on acceptance subtracts `released: offer` only;
- market: `ListingReservation#release_reservation` (`reserved - 1`) for unsold, withdrawn and cancelled listings; settlement moves one copy with `released: { card => 1 }`;
- entrusting and the recipient side of a trade lower `quantity` only after checking `quantity - reserved`;
- `ReleasePlayer` deletes the holdings rows outright, which is correct for a deleted player.

AD-52's claim holds against today's code. Its remaining risks are new code (H-14) and the split in `Game::ReservedCopies` (today `in_trade = reserved - on_sale`, which would count a deck block as "in trade" until AD-52's split lands; AD-52 already owns that).

## Holes

### H-1 [critical] A deletion mid-duel strands the opponent and keeps the deleted player's id

- **Story A (deletion, AD-14):** extends `Game::ReleasePlayer` to drop decks, as AD-14 lists. `ReleasePlayer` already deletes the player's `game_player_states` row (`PlayerState.where(player_id:).delete_all`), and that row holds `duel_id` (AD-54).
- **Story B (moves, AD-54 and AD-56):** `PlayAutomaticMove` and `FinishDuel` follow the house pattern of acting for a player: `require_player`, which refuses a removed player, as the trade operations do. `FinishDuel` locks both players' `game_player_states` rows and clears `duel_id`.
- **Clash:** after deletion, the automatic move for the deleted seat fails on `require_player`, or `FinishDuel` fails to find and lock the missing row. The duel never finishes, the opponent's `duel_id` is never cleared, and the opponent can never challenge or accept again. Separately, AD-14 says the deleted player's id "is nulled on their duels once finished", but `ReleasePlayer` runs while the duel is still active, so nothing nulls it later. The id of a deleted player stays on a personal-data row for good.
- **Also:** `game_player_states` is optional per player (the ER diagram has `||--o|`), so "lock both players' rows" can find no row for an old account even without a deletion.
- **Smallest AD change (AD-54 and AD-14):** "Duel operations act for the duel and use `require_account`. A missing `game_player_states` row counts as `duel_id` null and is upserted when it is set. `ReleasePlayer` nulls the player's id on their finished duels, and `FinishDuel` nulls the id of any seat whose player is deleted." Better: drop the `duel_id` pointer and enforce one open duel per player by a partial unique index on a `game_duel_seats` table (player, open), which deletion cannot orphan.

### H-2 [high] Duel operations take row locks without the bank locks, which deadlocks with openings and leaves decks unlocked at acceptance

- **Story A (`FinishDuel`, AD-54 and AD-57):** locks the duel row, then both `game_player_states` rows in ascending id (AD-54 says exactly this), then draws the duel capsule in the same transaction. The capsule is a pack grant, which AD-7 serialises under the winner's bank lock ("the bank lock still serialises claims and openings"). So the order is duel row, then `player_states`, then bank lock.
- **Story B (existing `OpenPack`, `CollectDailyBonus`, `AcceptTrade`):** takes the bank lock first, then writes `game_player_states` (`ReceiveSeasonAllocation`, and the `PlayerActivity` handler's upsert).
- **Clash:** `FinishDuel` holds the winner's `player_states` row and waits for their bank lock, while the winner's `OpenPack` holds the bank lock and waits for the same row. Postgres aborts one of them. AD-10 already says "holdings and player states are both taken under the bank lock", and AD-54 breaks that.
- **Second clash, in the same hole:** `AcceptChallenge` (AD-54) takes no bank lock, while deck edits run under the player's bank lock (AD-52). A challenger who edits the deck during the 60 seconds of the challenge, or deletes it, races the snapshot. The acceptance can copy 11 cards, two decks from different moments, or a deck that no longer exists.
- **Smallest AD change (AD-10's lock order and AD-54):** "Every duel operation takes both seats' bank locks in ascending player id first (a deleted seat's too), then the duel row, then the deck rows, then holdings, then `game_player_states`." Add "duel rows, then deck rows" to AD-10's list between trade rows and market listings.

### H-3 [high] "Calls left" leaks the hidden call

- **Story A (`CallRound`, AD-54):** stores the locked stat and direction on the duel row or the round row when the caller locks, since the call must survive a reload.
- **Story B (`DuelView`, AD-54):** shows "calls left" for both players, as `duel-rules.md` requires ("both players see which stats each has left"), and derives it from every call stored.
- **Clash:** between the lock and the reveal, the answerer's view drops the stat the caller just called. Each stat is called once per player, so the answerer learns the exact stat and has only the direction left to guess. The rule that the call stays hidden until the reveal is broken by a view that obeys AD-54 to the letter, since AD-54 forbids only "an unrevealed call", not facts derived from it. The server-side automatic answer must also not use it: `duel-rules.md` defines it on "the caller's stats left".
- **Smallest AD change (AD-54, on `DuelView`):** "Calls left, scores, margins and the round history count only revealed rounds; nothing derived from an unrevealed call reaches the other seat."

### H-4 [high] The opponent's deck, rendered in the order it was stored, gives away the draw order

- **Story A (`AcceptChallenge`):** "shuffles both decks" (AD-54) and stores each deck's snapshot as the shuffled array, which is the draw order, so the deck and its order are one column.
- **Story B (duel screen):** renders "both 12-card decks for the whole duel" by iterating the snapshot, with the DOM order, a position attribute or a `<template>` per card.
- **Clash:** the opponent's deck list in snapshot order is the opponent's draw order. With the struck-out cards, it gives the opponent's exact hand, which the simulation values at about 80 % of wins. AD-54 forbids "a draw order" in the view but not a list ordered by one.
- **Smallest AD change (AD-54):** "A deck's snapshot is stored in a canonical order (season, then card number); the draw order is a separate permutation that only `Game::DuelRules` reads. `DuelView` lists decks in canonical order."

### H-5 [high] Cards first pulled after the last computation, and a whole new season, have no discovery or circulation value but can enter a deck

- **Story A (`ComputeDuelStats`, AD-53):** runs on `SeasonPublished`, when nobody holds or has discovered any card of the new season, then weekly. An edition with no holder or no first discovery gets nulls, as `duel-rules.md` says.
- **Story B (deck operations, AD-52):** check only a free copy. `duel-rules.md` says an unpulled edition "cannot be in a deck anyway", but an edition first pulled on Tuesday is held at once and keeps null discovery and circulation until Monday. After a season publication, every new-season card is in that state for up to a week.
- **Clash:** a deck holds cards with null stats. `DuelRules` has no outcome for "most widespread" against a null, and the automatic move has no "most extreme" for them. Two implementers will pick null as 0, null as 50, or a crash.
- **Smallest AD change (AD-52 and AD-53):** either "a deck refuses an edition whose `game_duel_stats` row lacks a value (`Failure(:not_yet_ranked)`), and the editor shows it as ranked from the next Monday", or "a null discovery or circulation is stored as the bottom percentile of its ranked set until the next computation". The author picks one.

### H-6 [high] The "unrounded" rating does not exist in the data

- **Story A (`ComputeDuelStats`, AD-53):** reads rating from `Catalog`, as AD-4 requires ("`Game` never references a Steam-specific field"). `catalog_card_seasons.rating` is `decimal(5,2)`, but its value comes from `Steam::ReviewPolicy`, which reads `summary_filtered.percent_positive`, an integer from 0 to 100. No table stores positive and total reviews.
- **Story B (`DuelRules` tests, from `duel-rules.md`):** expect rating ranked "on the unrounded share" so that exact ties stay rare, which was the simulation's fix for the 6.7 % void rate on "worst rated".
- **Clash:** the AD cannot be built as written. A builder either reads Steam's raw JSON from `Game`, which breaks AD-4 and AD-2, or ships whole-number ratings, about 80 distinct values, so the voids the simulation removed come back.
- **Smallest AD change (AD-53, and an author decision):** "Rating's exact value is `Catalog`'s whole percent; equal ratings compare review count next." Otherwise, AD-4 has `Steam` hand `Catalog` the positive count from the next import, and seasons imported before it keep the whole percent. Also say what popularity reads for a card-season whose `review_count` is null (allowed by the check constraint for rows from before 2026-10-12).

### H-7 [high] Presence by subscribe and unsubscribe marks a present player absent, so the game plays their duel

- **Story A (seat channel, AD-55):** runs `MarkDuelAbsent` on unsubscribe and `MarkDuelPresent` on subscribe, as written.
- **Story B (duel screen):** uses Turbo Drive. A reload or a Turbo visit sends unsubscribe and subscribe for the same stream, and a player may open the duel in two tabs.
- **Clash:** Action Cable runs a connection's commands on its worker pool, so the order is not guaranteed. Closing the second tab marks a player absent while the first tab stays open. A subscribe handled before the unsubscribe leaves the player absent while they watch the screen. Nothing marks them present again, so after 60 seconds each of their moves is played automatically, and they lose the capsule ("the game played none of the winner's moves"). The same race clears `reachable_until` (AD-55) while the player is on a page, though it heals at the next 30-second tick.
- **Smallest AD change (AD-55):** "Seat presence and reachability are heartbeats: the channel sets `seat_seen_until` and `reachable_until` ahead on subscribe and every 15 to 30 seconds; unsubscribe clears nothing; absence is the heartbeat's expiry, read by the deadline job." `MarkDuelPresent` and `MarkDuelAbsent` then become reads, not operations.

### H-8 [high] "The move's number" is undefined, so a late deadline job plays the wrong move

- **Story A (`DuelDeadlineJob`, AD-56):** enqueued "with the duel token and the move's number". The builder uses the round number and checks "was round n played" against `game_duel_rounds`, which AD-54 fills "one row per played round", that is, at the answer.
- **Story B (`CallRound`):** keeps the locked call on the duel row until the answer.
- **Clash:** the call deadline job for round n runs late (a queue backlog, or the minute sweep), after the real call but before the answer. Round n has no row yet, so the job plays the awaited move, which is now the answer, well before its 45 seconds. The same happens with the reconnection deadline: AD-56 stores "the deadline of the move awaited … and an absent player's reconnection deadline" as if there were one deadline, but both seats can be absent at once, and the move's deadline can expire before the reconnection deadline.
- **Smallest AD change (AD-56):** "The duel row holds `move_number`, raised by every move (accept, each call, each answer), and `move_deadline_at`; each seat has its own `absent_until`. A deadline job acts only when the row's `move_number` and deadline equal those it was enqueued with. A move's deadline is not paused by absence; reconnection only decides whether later moves wait for their deadline."

### H-9 [high] The one-duel rule against incoming challenges has two readings

- **Story A (`ChallengeFriend`):** sets `duel_id` on both players at the challenge, since AD-54 says "at most one open challenge or duel".
- **Story B (`AcceptChallenge`):** sets the acceptor's `duel_id` at acceptance, reading "one open challenge" as the challenger's own.
- **Clash:** with A, a friend can keep a player permanently busy by challenging them again every 60 seconds, and two friends cannot both challenge a third. With B, several challenges can wait on one player. Accepting one leaves the others to fail at acceptance with a confusing error, and their challengers stay blocked until the lapse. AD-14's private path lapses "their open challenge", singular, which fits A only.
- **Smallest AD change (AD-54):** "`duel_id` is set on the challenger at the challenge and on the opponent at acceptance. A player has at most one incoming challenge (a partial unique index on opponent where the state is `challenged`). `ChallengeFriend` refuses a friend with a `duel_id` or an incoming challenge (`Failure(:friend_busy)`)."

### H-10 [medium] The challenge refers to no deck, and nobody checks that both decks are complete

- **Story A (`ChallengeFriend`):** stores the challenger's deck as a foreign key, which the column list of AD-54 lacks.
- **Story B (`DeleteDeck`, AD-52):** deletes the deck and its cards. It knows nothing of challenges, so it uses a cascade or meets a restricting foreign key.
- **Clash:** deleting a deck under a pending challenge either fails with a foreign-key error or cascades the challenge away, and nothing lapses it or tells the friend. `duel-rules.md` says "A deck with fewer than 12 cards is a draft and cannot duel", but neither `ChallengeFriend` nor `AcceptChallenge` is named to check it. This is a rule with no owner.
- **Smallest AD change (AD-54):** "`game_duels` stores each seat's deck token; `AcceptChallenge`, under the locks of H-2, refuses (`Failure(:deck_not_ready)`) a deck that is missing or not 12 cards and lapses the challenge; `ChallengeFriend` refuses a draft deck."

### H-11 [medium] The challenged player sees the challenger's deck before choosing theirs

- **Story A (challenge notice, AD-55 and AD-13):** renders the challenge on the friend's private stream with the challenger's deck, since the deck "is revealed" and the notice wants to look rich.
- **Story B (accept screen):** lets the friend pick a deck after seeing it.
- **Clash:** the acceptor picks a counter-deck with knowledge the challenger never gets. `duel-rules.md` reveals both decks at the start, together. AD-54's `DuelView` covers the duel but not the `challenged` state or the notice.
- **Smallest AD change (AD-54):** "In state `challenged`, `DuelView` and the challenge notice show the challenger's name and nothing of their deck."

### H-12 [medium] The automatic move's tie-break needs medians the snapshot does not hold

- **Story A (`AcceptChallenge`):** copies "every value and percentile of AD-53" into the duel. After that, "a duel reads nothing from … `game_duel_stats`".
- **Story B (`DuelRules`):** implements "the larger distance of the exact value from the median" for automatic moves between equal choices.
- **Clash:** the median of each stat (per season, and per tier and season for circulation) is in neither the snapshot nor the stats table. Story B either reads `game_duel_stats` live, which breaks the freeze, or computes the median over the 24 snapshot cards, which gives a different result.
- **Smallest AD change (AD-53):** "`game_duel_stats` stores, per stat, the distance of the exact value from its ranked set's median, and the snapshot copies it."

### H-13 [medium] How and when the stats are computed is underspecified

- **Event path:** "runs … on `Catalog::SeasonPublished`". A `Game` handler runs inside `PublishSeason`'s transaction and may not publish (AD-10), but `ComputeDuelStats` publishes `DuelStatsComputed`. One builder calls it from the handler, which nests publication and fattens the publish transaction. Another enqueues a job.
- **Concurrent runs:** the deploy step, a season publication and Monday 00:00 can overlap. Two transactions that "replace every row" collide on the unique card-season index.
- **What "previous" means:** "the previous computation's percentiles" (AD-53) against "change since the previous week" (CAP-40). A Thursday season publication makes the following Monday's arrows and the "moved most" feed entry compare with Thursday, not with last week.
- **Smallest AD change (AD-53):** "A `SeasonPublished` handler enqueues `ComputeDuelStatsJob` after commit; runs are serialised (one at a time, by an advisory lock); the previous percentiles are those of the last weekly run, which non-weekly runs carry over unchanged."

### H-14 [medium] Which seasons have stats

- **Story A (`ComputeDuelStats`):** reads "a published season" as `Catalog::PublishedSeason.call`, the current one, which is how the rest of the code uses the phrase (AD-5, AD-10).
- **Story B (deck editor):** lists earlier editions with "its season shown beside its trump" (`duel-rules.md`).
- **Clash:** from the next season on, earlier editions have no row, so decks full of them cannot duel. The tribute season (AD-33, parked) and card-seasons with a null rarity (circulation is ranked "within its tier") have no defined treatment either.
- **Smallest AD change (AD-53):** "one row per card-season of every published regular season; a card-season with no rarity or of a tribute season has no row and cannot enter a deck."

### H-15 [medium] The Monday feed entry has no shape

- **Story A (feed handler, AD-53 and AD-13):** inserts a `game_feed_entries` row for the weekly `DuelStatsComputed`. But `player_id` is `NOT NULL`, the kind check lists seven kinds, `game_feed_entries_set_check` ties a null `card_season_id` to `set` and `verdict` only, and AD-13's public filter shows an entry "only if every player it names is public".
- **Story B (feed rendering, `ReleasePlayer`):** keys on `player_id` (`ReleasePlayer` deletes entries by `player_id`).
- **Clash:** one builder borrows an arbitrary player id, as the `verdict` precedent does with the weekly winner, so the entry vanishes when that player goes private or is deleted. Another makes `player_id` nullable without expand/contract. "Which cards moved most", how many and by what measure belong to the same unowned shape.
- **Smallest AD change (AD-53):** "kind `duel_stats`, one per ISO week (a partial unique index on `occurred_at`, as `verdict`), naming no player (`player_id` made nullable for this kind, expand then validate), its cards in a column of card-season ids ranked by the largest absolute percentile change, at most N."

### H-16 [medium] "Absent for good" and "as soon as it falls to them" have no mechanism that obeys AD-10

- **Story A (`CallRound` or `AnswerRound`):** when the move passes to an absent seat past its reconnection deadline, calls `PlayAutomaticMove` inline, as AD-3 allows ("an operation may call another operation of its own pack"). That publishes two events in one transaction, against AD-10's "one primary event".
- **Story B (ban, deletion and privacy handlers, AD-14):** must "lapse their open challenge" and make the seat "absent for good". Handlers may not publish (AD-10), but lapsing is a duel operation that publishes. The handler also writes the friend's `duel_id`, another player's row.
- **Clash:** each builder breaks AD-10 one way or the other, or the ban and deletion simply do nothing to the duel. Then the banned player's live cable subscription keeps their seat present (the connection refuses a banned player only at connect), and each of their moves waits for its full 45 or 60 seconds.
- **Smallest AD change (AD-56 and AD-14):** "Automatic moves and lapses are played only by `DuelDeadlineJob`. An operation that hands the move to an absent, banned or deleted seat sets its deadline to now. Ban, deletion and going private write no duel row: the job and `AcceptChallenge` read removal and `open_to_friends?` and lapse or auto-play."

### H-17 [medium] In-duel operations may re-check friendship

- **Story A (moves):** reuse `TradeSteps#friends`, the existing check, on every move, since trades check friendship at every step.
- **Story B (remove friend, ban, going private):** drops the friendship or closes the profile mid-duel.
- **Clash:** the duel can no longer be moved and never finishes. `duel-rules.md` says "No duel is won by forfeit". Removing a friend mid-duel is specified nowhere.
- **Smallest AD change (AD-54):** "Only `ChallengeFriend` and `AcceptChallenge` check friendship and visibility. Moves and `FinishDuel` never do. Removing a friend, going private or a ban leaves a started duel to finish."

### H-18 [medium] A card already in one deck cannot be added to a second deck

- **Story A (deck operation, AD-52):** "refuse an edition with no free copy", applied to every add.
- **Story B (editor, `duel-rules.md`):** shows a card whose copies are all reserved with the Reserved tag, and counts its own deck block as reserved.
- **Clash:** a player with one copy in deck 1 cannot put it in deck 2, though AD-52's "exactly 1 … whatever the number of decks" is meant to allow it.
- **Smallest AD change (AD-52):** "An edition already in another of the player's decks needs no free copy; the editor's Reserved tag ignores the player's own deck block."

### H-19 [medium] What ends the duel after round 10

- **Story A:** `AnswerRound` for round 10 runs `FinishDuel` as a step, which publishes two events in one transaction (AD-10).
- **Story B:** `FinishDuel` runs from a job enqueued after the last answer, so for a moment the duel is `active` with ten rounds played, and `duel_id` stays set.
- **Smallest AD change (AD-54):** "The last answer, real or automatic, finishes the duel in its own transaction and publishes `DuelFinished` in place of its round event."

### H-20 [low] Seat broadcasts can arrive out of order

Two moves in quick succession enqueue two render jobs. Running on two job threads, the older render can be sent after the newer one, so a seat shows a stale state until the next move. **AD-55:** "A seat's view carries `move_number`, and the screen ignores an older one; or the render job is limited to one at a time per duel."

### H-21 [low] The duel page may read a stale copy

AD-11 puts GETs on the reading role, "tolerating a second of delay". When a replica is added, the duel page can render the state from before the player's own move. **AD-54:** "duel pages read the primary", as AD-10 already does for the allocation check.

### H-22 [low] `NoteReachable` may publish an event every 30 seconds per connected player

AD-10 exempts only the named housekeeping writes. **AD-55:** "`NoteReachable` is housekeeping and publishes nothing."

### H-23 [low] A deck-blocked copy can be requested in a trade

`ProposeTrade#requestable` checks `quantity`, not free copies, so a friend can request a deck-blocked copy. The trade fails at acceptance with `requested_cards_unavailable`, and since deck names are private the requester never learns why. **AD-52:** "the friend's trade board offers only free copies; a deck block reads as reserved, unnamed."

### H-24 [low] Smaller unowned details

- `GrantAchievementsJob` follows a fixed list of events (AD-37), and AD-57 does not add `DuelFinished`.
- `DuelView.for(duel, viewer)` is undefined for a viewer who holds no seat; say the policy refuses them.
- Discovery's exact value is "to the second" in `duel-rules.md`, but `discovered_at` is stored to the microsecond. Say which one `DuelRules` compares.
- The Capability map omits AD-10 (lock order) and AD-15 (deck and duel tokens) for CAP-40 to CAP-42, and AD-5 for CAP-39.
- Neither deferred bullet covers a challenge to a friend who is reachable but away. That is accepted by design, so nothing to add.

## Owner check: rules of `duel-rules.md` an implementer could get wrong

| Rule | Owner in the spine | Status |
| --- | --- | --- |
| Five stats, percentile by midrank to one decimal, trump | AD-53, one query | Owned. Rating is not buildable as written (H-6); a null popularity is undefined (H-6) |
| Discovery and circulation null for an unpulled edition | AD-53 | Owned, but it breaks for newly pulled editions and new seasons (H-5) |
| Computed at deploy, at season publication, weekly | AD-53 | Owned; mechanism and serialisation missing (H-13) |
| Which seasons are ranked | none | **Unowned** (H-14) |
| 12 cards, a game once per deck, 5 decks, named | AD-52 | Owned |
| A draft cannot duel | none | **Unowned** (H-10) |
| A deck block is one copy across decks | AD-52 | Owned; the second deck is refused (H-18) |
| A deck block counts as reserved everywhere; going private keeps it | AD-52 and the existing code | Owned and verified |
| Deck names shown only to the owner | AD-52 (screens name the decks) | Owned for the owner; for others implied (H-23) |
| Card detail shows the profile of the "Prix moyen" edition | none named | Unowned (low; one sentence in AD-53) |
| Challenge only a reachable friend, 60 s to accept | AD-55, AD-56 | Owned; presence race (H-7) |
| One duel at a time | AD-54 `duel_id` | Owned, two readings (H-9); deletion strands it (H-1) |
| A private player cannot duel | AD-13, AD-14, AD-54 | Owned; the handler mechanism breaks AD-10 (H-16) |
| Decks locked, shuffled, revealed; hands hidden | AD-54 | Owned; draw order leaks by rendering order (H-4); challenge-time leak (H-11) |
| Call order A B A B A B A B B A, each stat once, hand of 3 | AD-54 `DuelRules` | Owned |
| Round steps; the call hidden until the reveal | AD-54 `DuelView` | Owned; "calls left" leaks (H-3) |
| Outcome, exact-value tie, void round, margin tie-break, margin shown | `DuelRules`, `DuelView` | Owned |
| Frozen at the start | AD-54 | Owned; the median for the tie-break is missing (H-12) |
| 60 / 45 / 60 s, automatic move rules | AD-56, `DuelRules` | Owned; move identity and double deadline (H-8) |
| Automatic tie-break by distance from the median | `DuelRules` | Data missing (H-12) |
| A banned or deleted player is played automatically | AD-14, AD-56 | Owned in words; no mechanism obeys AD-10 (H-16); deletion breaks it (H-1) |
| No forfeit | AD-56 | Owned; friendship re-checks can block it (H-17) |
| First daily win gives a capsule, none if any of the winner's moves was automatic | AD-57 | Owned; lock order (H-2) |
| Wins, losses, draws on the profile; achievements | AD-57 | Owned; the achievement trigger is missing (H-24) |
| Export, deletion, "anonyme" | AD-14 | Owned; nobody nulls the id after the finish (H-1) |
| The Monday feed entry | AD-53 | Owned in words; the row shape is impossible today (H-15) |
