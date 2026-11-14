# Rubric and reality review: spine update 2026-11-14 (release 1.4, decks and live duels)

- **Spine:** `architecture-gameble/architecture-gameble.md`, AD-52 to AD-57, and the 1.4 amendments: Design Paradigm `Game` row, AD-7, AD-13, AD-14, AD-24, the map rows CAP-39 to CAP-42, and Deferred (ranked and deferred duels, live duel load).
- **Spec and UX checked:** `spec-gameble.md` CAP-39 to CAP-43, Constraints, Success signal; `duel-rules.md`; `achievements.md` (duel achievements); `EXPERIENCE.md` › Duels, Échanges › Reserved tag, Amis › Friend row, Fil d'activité › achievement table 24–33, Flow 11; `forge-decks-and-matches/simulation-2026-11-14.md` (findings 4 and 5).
- **Code checked** (working tree on `develop` at 83992213; `origin/develop` is 3 commits ahead in locales, the event-store initializer and `schema.rb`, none of them in the areas below): `PlayerStreamChannel`, `ApplicationCable::Connection`, `PlayerStream`, `ShellHelper#player_stream_tag`, `layouts/application.html.erb`, `config/queue.yml`, `config/recurring.yml`, `config/cable.yml`, `config/initializers/active_job.rb`, `config/initializers/event_store.rb`, `bin/docker-entrypoint`, `Game::Pack`, `Game::Reserve`, `Game::Fortune`, `Game::LuckOdds`, `Game::DrawOdds`, `Game::PackRedraw`, `Game::ReservedCopies`, `Game::TradeSteps`, `Game::MoveHoldings`, `Game::Market::ListingReservation`, `Game::Market::PlayerDesk`, `Game::ReleasePlayer`, `Game::Handlers::{SeasonPublished, Achievements, PackOpened, VisibilityChanged, WeeklyVerdictFeed}`, `Game::GrantAchievementsJob`, `Game::Achievements`, `Game::ClaimAchievement`, `Game::FriendsPresence`, `Game::ExportOf`, `Catalog::SeasonPublished`, `Steam::CardMapping`, `Steam::ReviewPolicy`, `Steam::PrestigeScore`; in `db/schema.rb` the tables `game_packs`, `game_player_states`, `accounts_players`, `game_holdings`, `game_first_discoveries`, `game_feed_entries`, `game_fortunes`, `catalog_card_seasons`, `steam_apps`.
- **Gems read in the bundle:** actioncable 8.1.4.1 (`Channel::PeriodicTimers`, `Channel::Base`, `Connection::Base`, `Connection::Subscriptions`, `Server::Worker`), turbo-rails (`Turbo::StreamsChannel`, `cable_stream_source_element.js`), solid_queue 1.7.0 (`RecurringTask`, `SolidQueue.time_zone`, engine initializer), fugit 1.14.0 (parsed live).

## Verdict

**Conditional pass.** The shape is right: decks reuse `reserved` so every existing free-copy reader follows without change, duels are frozen snapshots behind one view object and one rules object, and the clock is the server's. Three things do not hold against reality: seat presence toggled by subscribe and unsubscribe is unordered in Action Cable and can mark a connected player absent; the new pack kind `duel` makes every duel capsule fail to open through the Flukeometer's kind table; and the "unrounded rating" the stats rely on is not data gameble holds or may fetch.

Fix H1 to H3 before slicing the duel stories, the medium findings in the same pass, the low ones when convenient.

## Reality checks

| Mechanism the ADs assume | Finding |
| --- | --- |
| `periodically` in a `Turbo::StreamsChannel` subclass | Holds. `Turbo::StreamsChannel < ActionCable::Channel::Base`, which includes `PeriodicTimers`: timers start `after_subscribe` and stop `after_unsubscribe`; each tick runs through `worker_pool.async_exec`, wrapped in Active Record connection management. `PlayerStreamChannel` overrides only `subscribed`. |
| `unsubscribed` callback | Holds for a clean close and for an explicit unsubscribe (`Subscriptions#remove_subscription` → `unsubscribe_from_channel`; `handle_close` → `unsubscribe_from_all`). It does not run when the process dies, so the 45 s lease is the right backstop. **But** every command and every close is posted to one shared thread pool (`worker_pool_size` 4) with no per-connection ordering, and a subscribe for an identifier already subscribed is silently ignored (`return if subscriptions.key?(id_key)`). Subscribe and unsubscribe effects can land in either order (H1, L1). |
| Player stream on every page | Mostly. `player_stream_tag` is rendered by the layout for any signed-in non-back-office page, and is not `data-turbo-permanent`: every Turbo visit unsubscribes and resubscribes. Staff on back-office pages are never reachable. |
| Opaque stream name, checked per player | Holds. `PlayerStream.streamables` = `[stream_key, locale]`; the channel checks the verified name is one of `PlayerStream.names(current_player)`. A seat channel can follow the same pattern; note the locale segment (L10). |
| `set(wait_until:)` and the dispatcher | Holds. Scheduled jobs wait in `solid_queue_scheduled_executions`; the dispatcher (`polling_interval: 1`, `batch_size: 500`) moves due ones to ready, a worker polls every second: about 1–2 s late, inside AD-56's 2 s margin when the queue is idle (M6). |
| `enqueue_after_transaction_commit` | Holds, set on `ActiveJob::Base` by `config/initializers/active_job.rb`, so jobs enqueued from an operation run in a channel callback also wait for commit. |
| "every Monday 00:00 UTC" | Holds. Fugit parses `every monday at 12am` (and `at midnight`) to `0 0 * * 1`; Solid Queue appends `SolidQueue.time_zone`, which defaults to `config.time_zone`, unset, hence `UTC`. The existing `publish_weekly_verdict` runs at 00:05 the same morning. |
| Solid Cable latency | `polling_interval: 0.1.seconds` in production: fine for live rounds. |
| `accounts_players.last_seen_at` | Exists. No `reachable_until` yet. |
| `game_player_states` | Exists, one row per player; no `duel_id` yet. `Game::ReleasePlayer` deletes it on account deletion (L12). |
| `Game::ReservedCopies` | Exists, splits `reserved` per game into `on_sale` and `in_trade` (the rest); adding `in_deck` is a local change. Every release is relative (`reserved = reserved ± n` in `TradeSteps`, `ListingReservation`, `MoveHoldings`), and nothing resets `reserved`, so AD-52's "releases never free a deck block" holds in code. |
| `Catalog::SeasonPublished` | Exists; `Game::Handlers::SeasonPublished` drops goals and enqueues `HealBanksJob`. `ComputeDuelStats` publishes an event, so it cannot run inside that handler (AD-10); it must be a job the handler enqueues (L17). |
| `GrantAchievementsJob` | Exists, enqueued by `Game::Handlers::Achievements` from a fixed event table; no duel event yet (L8). |
| Pack kinds | `enum :kind, { regular, bonus, reward }`; `game_packs_kind_check` lists the three; `game_packs_card_season_ids_check` fixes 3 cards for `bonus` only. `Game::Reserve::KINDS["special"] = %w[bonus reward]`. `Game::Fortune::PACK_COLUMNS` and `Game::LuckOdds::EXPECTATIONS` both `fetch` by kind (H2). |
| Rating "positive over total, unrounded" | Does not exist. `IStoreBrowseService/GetItems` returns `reviews.summary_filtered` with an integer `percent_positive` and `review_count`; `Steam::PrestigeScore` raises on a non-integer percent; `catalog_card_seasons.rating` is `decimal(5,2)` filled from that integer; no positive count is stored anywhere. The keyless `appreviews` endpoint that has `total_positive` is barred by AD-19 (H3). |
| Discovery, circulation | `game_first_discoveries.discovered_at` is a timestamp, one row per card-season (unique); holdings and Archives deposits are separate tables, so counting `game_holdings.quantity > 0` already excludes the Archives. |
| Data export | Assembled by `PlayerExport` (web layer) from `Game::ExportOf` and `Accounts` queries, as AD-14 says. |
| Feed entry with no player | Not possible today: `game_feed_entries.player_id` is `NOT NULL`, the kind check lists seven kinds, and no column can hold six card moves (M5). |
| Deploy data steps | `bin/docker-entrypoint` runs `db:prepare game:backfill_achievements …` on **every** server boot, not once per release (M2). |

## Rubric

| Check | Result |
| --- | --- |
| Each new AD's rule is enforceable | AD-52, AD-53, AD-57: yes, with the gaps M1, M2, H3. AD-54: yes, but the operation list and states miss the challenger's cancel (M7) and the lock order is not placed (M4). AD-55: the reachability lease is enforceable; seat presence is not, as written (H1). AD-56: the job guard is too weak (M3). |
| Each rule prevents its stated divergence | AD-52 "a second formula for free copies": partly (L6). AD-54 "rules computed in two places": partly, the automatic move needs data the snapshot lacks (L2). AD-55 "reachability stuck after a crash": yes. AD-57 "a capsule paid for an automatic move": yes, given H1 is fixed; otherwise a connected player can lose it. |
| Deferred cannot let two units diverge | Holds. Ranked and deferred duels and the live-load backend are cleanly outside 1.4. The one open product question 1.4 creates, whether duel capsules count in the Flukeometer, is neither decided nor deferred (H2). |
| Stories can be built independently | Not yet for: the duel capsule (H2), the Monday entry (M5), the challenge sheet versus the received dialog (M7), the duels screen versus the friend row's DÉFIER (M9), the deck editor's arrows versus the feed (M2). |
| UX and rules needing a structural decision | Covered: card detail duel profile (AD-53 query), Reserved tag split (AD-52), export (AD-14), routes by token (`game_decks.token`, `game_duels.token`), i18n (AD-18). Missing: Monday entry storage (M5), deck names owner-only and "RETIRER DES DECKS" (L3, L4), "Compléter les manques" rule home (L5), duel and result policies (L4), opponent naming (L9), last used deck (L14). |

## Findings

### H1 — Seat presence toggled by subscribe and unsubscribe can mark a connected player absent (AD-55, AD-56)

AD-55 runs `Game::MarkDuelAbsent` on the seat channel's unsubscribe and `Game::MarkDuelPresent` on subscribe. Action Cable posts each connection's commands and its close to one shared thread pool with no ordering, and a reload or a phone switching networks opens the new socket before the server sees the old one close. The old connection's late `unsubscribed` then marks absent a player who is on the duel screen; nothing re-asserts presence, so 60 s later AD-56 plays their moves and AD-57 withholds their capsule. A second tab on the duel screen does the same when it closes.

**Fix:** make seat presence a lease, as reachability is: a per-seat `present_until`, set on subscribe and refreshed by `periodically` on the seat channel (for example every 10 s, 25 s ahead); a seat is absent when its lease has lapsed, and its reconnection deadline is the lease's end plus 60 s; unsubscribe does not mark absence (or only ends the lease when it was set by that subscription); a move by the seat renews it.

### H2 — Pack kind `duel` makes the capsule unopenable and leaves the Flukeometer undecided (AD-7, AD-57)

`Game::Handlers::PackOpened` calls `Fortune.record_opening`, which does `PACK_COLUMNS.fetch(pack.kind)` and `LuckOdds.of(pack.kind)` (`EXPECTATIONS.fetch`): for `duel` both raise inside the opening's transaction, so `Game::OpenPack` rolls back. `Game::Reserve::KINDS` puts only `bonus` and `reward` in the special reserve, so a duel pack would not even be counted or opened from it. `game_packs_kind_check` and the size check also need widening. The Flukeometer (`game_fortunes`) is not in the spine, and whether a duel capsule counts in a player's luck is a product decision nobody has taken.

**Fix:** a Costs line under AD-57: widen `game_packs_kind_check` and the size check (3 cards for `duel`) expand/contract; add `duel` to `Reserve::KINDS["special"]`, to `LuckOdds` (bonus odds × 3) and to `Fortune::PACK_COLUMNS` with a `duel_packs` column, unless the author excludes duel capsules from the Flukeometer, in which case `record_opening` skips the kind; add the partial unique index on `(player_id, duel_day)` concurrently in its own migration; the origin's locale key and colour token.

### H3 — The "unrounded rating" does not exist (AD-53, `duel-rules.md`)

AD-53 reads rating from `Catalog` as "positive over total reviews, unrounded". `Catalog` holds only Steam's whole-number percent (`GetItems` gives no positive count, `PrestigeScore` enforces an integer, `steam_apps` stores the integer), and the endpoint that gives `total_positive` is the keyless store API AD-19 forbids. The simulation's fix for void rounds (finding 4) assumed data gameble cannot get; about 80 distinct ratings remain.

**Fix:** the author chooses, and the spine states it: either rating's exact value is the whole-number `rating` and the void rate on "worst rated" is accepted (strike "unrounded" from `duel-rules.md` and AD-53), or its exact value is the pair (whole percent, review count), compared in that order, which is data `Catalog` already has.

### M1 — Editions discovered since the last computation have no discovery or circulation value (AD-53)

Stats are computed at the deploy, at a publication and on Mondays. An edition first pulled after the last computation (every edition of a new season, for up to a week after its publication) has no row value for discovery or circulation, yet it is held and can enter a deck. `duel-rules.md` says such an edition "cannot be in a deck anyway", which is true only at the instant of computation. The editor, the card detail, the snapshot, `DuelRules` and the automatic move would each meet a null.

**Fix:** AD-53 defines the stand-in once, in its one query: until the next computation, such an edition takes the lowest percentile on discovery (discovered last) and on circulation (one holder), and its exact values are its live `discovered_at` and 1; or `ComputeDuelStats` also runs daily. The snapshot copies whatever the query returns.

### M2 — The previous percentiles are overwritten by every run, and every boot is a "deploy" run (AD-53)

`game_duel_stats` keeps "the previous computation's percentiles", and every run (deploy, publication, weekly) replaces the rows. `bin/docker-entrypoint` runs the data steps on every server boot, so each deploy or restart would recompute and move the comparison basis. The deck editor shows moves "since the previous Monday" and the Monday entry compares "since the previous computation": after a mid-week deploy or publication the two disagree, and the Monday entry reports only the days since that deploy. "Valeurs du <date>" also needs a stored date.

**Fix:** only the weekly run (and the first run, when the table is empty) rotates `previous`; the deploy step runs only when the table is empty; a publication run recomputes current values and keeps `previous`; the rows (or one header row) store `computed_at`.

### M3 — The deadline job's guard is "move not played", which is not enough (AD-56)

`DuelDeadlineJob` carries the token and the move's number and does nothing "when that move was played". A reconnection-deadline job would still play move N after the player came back, and a player already past their reconnection deadline who receives the turn needs a move played at once, which no enqueue covers. Both players can be absent at once, so one reconnection deadline on the row is not enough.

**Fix:** `PlayAutomaticMove` acts only when, under the duel lock, the move is still awaited and its stored deadline (the move's, or the seat's reconnection deadline) is at or before `now`; reconnection deadlines are per seat; an operation that hands the turn to a seat past its reconnection deadline sets that move's deadline to `now` and enqueues the job.

### M4 — The duel row is not placed in AD-10's lock order (AD-54, AD-57)

AD-54 locks the duel row, then both players' `game_player_states`. `FinishDuel` also draws a capsule, which takes the winner's bank lock (AD-7). The `PlayerDeleted` and `VisibilityChanged` handlers already hold bank locks when they lapse a challenge or hand a duel to automatic play. Duel row then bank lock in one path, bank lock then duel row in another, is a deadlock cycle.

**Fix:** AD-54 adds to AD-10's order: both seats' bank locks in ascending player id, then the duel row, then the player states; every duel operation that can finish, grant or lapse takes the bank locks first (or every duel operation does, which is simplest).

### M5 — The Monday stats entry has nowhere to live (AD-53, AD-13)

`game_feed_entries.player_id` is `NOT NULL`, its kind check lists seven kinds, and no column holds the six moves (card-season, stat, direction, both percentiles). They cannot be read back from `game_duel_stats` at render, since the next run replaces it. `FeedEntries.visible`, `NewFeedEntries` and `VisibleFeedEntry` assume a player.

**Fix:** a Costs line under AD-53: a feed kind (`duel_stats`) added expand/contract; `player_id` nullable for that kind only (check); the moves stored with the entry (a child table, or a `jsonb` of ids, stat keys and percentiles; ids only, as AD-10 asks of events); unique per ISO week; the feed queries let it through on TOUS and TOUT only, never AMIS or the ticker.

### M6 — Timed duel jobs share the `default` queue (AD-56, AD-55)

`DuelDeadlineJob`, the seat broadcast job and the sweep have no queue named, so they land on `default`: 3 threads in one process, shared with `ComputeDuelStats`, `HealBanksJob`'s per-player work, achievement grants, two 10-second recurring jobs and the per-minute ones. A burst there delays a move or a seat's view while the server clock keeps running, and the player times out on a screen that has not updated.

**Fix:** AD-56 names a `duels` queue served by its own worker entry in `config/queue.yml` (which lists queues explicitly) for the deadline job and the seat broadcasts; it names the sweep job and puts it in both blocks of `config/recurring.yml`, as AD-50 does.

### M7 — The challenger's side of a challenge has no operation, state or stream (AD-54, AD-55, AD-13)

AD-55 sends a challenge and its lapse to the friend. The challenger's sheet must learn of acceptance, refusal or lapse; its "ANNULER" needs an operation and a state the friend's dialog hears. AD-54's states (`challenged`, `refused`, `lapsed`, `active`, `finished`) and operations have no cancel.

**Fix:** add `CancelChallenge` and the state `cancelled`; every challenge outcome (accepted, refused, lapsed, cancelled) is sent to both players' private streams, listed in AD-13.

### M8 — Two different "online" questions for one DÉFIER (AD-24, AD-55)

AD-55 makes DÉFIER and `ChallengeFriend` require reachability, while "online" elsewhere reads `last_seen_at` (`FriendsPresence::ONLINE_WINDOW` is 5 minutes). The duels screen's "EN LIGNE · n" says "as Presence says", the challenge sheet lists "online friends only", and the friend row shows "DÉFIER EN DUEL" "for an online friend". Built as written, they list friends whose challenge the operation refuses.

**Fix:** one query (for example `Game::ReachableFriends`: friends with `reachable_until` ahead, `open_to_friends?`, not in a duel) feeds the duels screen's EN LIGNE group, the sheet's friend list and every DÉFIER button; the presence line text stays AD-24's.

### L1 — Clearing `reachable_until` on unsubscribe flickers (AD-55)

The player stream is not `data-turbo-permanent`, so each Turbo visit unsubscribes then resubscribes, unordered (see reality checks); a second tab closing, or an old socket closing late, clears a lease a live subscription holds. The next tick restores it within 30 s. **Fix:** unsubscribe does not clear the lease (it lapses within 45 s), or accept the flicker in one line.

### L2 — The automatic move's tie-break needs data the snapshot lacks (AD-54)

"The larger distance of the exact value from the median" needs each stat's median in the edition's season, but after the start a duel reads nothing from `game_duel_stats`. **Fix:** AD-53's row stores each stat's distance from its median (or the snapshot copies the medians), and AD-54 lists it among the copied values with the card number.

### L3 — Deck names and "RETIRER DES DECKS" have no named home (AD-52)

The trade, sale and entrust screens name the decks holding a card and offer to take it out of all of them. **Fix:** one query (`Game::DecksHolding(player, card_ids)`) beside `ReservedCopies`, and one operation (`Game::RemoveFromDecks`) under the bank lock, lowering `reserved` once.

### L4 — Decks and duels have no stated visibility (AD-52, AD-54)

Nothing says decks and their names show to their owner only, that a duel shows the opponent's cards but never their deck's name, or that a duel and its result are refused to anyone but its two seats. **Fix:** one bullet each, as AD-35 does for custom sets.

### L5 — "Compléter les manques" and the coverage strip need one rule (AD-52)

The gap threshold (90), "best free card for each gap in turn, then the best remaining trumps" and the coverage figures would otherwise be computed by the editor view and by the fill operation separately. **Fix:** one `Game::DeckCoverage` object read by the editor and by the fill operation.

### L6 — Spare counts diverge once decks block a kept copy (AD-52, AD-38)

`Market::PlayerDesk.spare_copies` counts `quantity - GREATEST(reserved, 1)` per edition (a reserved copy doubles as the kept one), while `ReservedCopies.duplicates` and AD-38 count `free - 1` per game. Decks make `reserved ≥ 1` common on kept cards, so a deck card held twice shows one spare on the market desk and none in suggestions. **Fix:** AD-52 says whether a deck-blocked copy is the kept copy, and one function computes spares.

### L7 — The friend side of the trade picker must now subtract deck blocks only

The friend side's maximum is "what they own"; the UX now asks that a friend's deck-blocked copy count as unavailable, without revealing their trade reservations. **Fix:** one line in AD-52: the friend side subtracts `ReservedCopies`' in-deck count only.

### L8 — AD-37's event list is not extended

**Fix:** `GrantAchievementsJob` also follows the duel's finishing event, for both seats; the Duelliste back is an entry of AD-25's constant.

### L9 — Opponent names on duel results and history

Under AD-13, `visible?` would hide an opponent who later goes private from the other player's history. **Fix:** the duel result and history render the opponent through AD-49's component, as name-only surfaces.

### L10 — The seat stream needs the locale

`PlayerStream` names carry the locale and the job renders per locale. **Fix:** the seat stream is named by the seat key and the locale, as `PlayerStream` is.

### L11 — What the export holds about the opponent

**Fix:** a duel history row in the export carries the player's own cards, result and times, and no opponent identity, as `ExportOf::TradeRow` carries no partner.

### L12 — Who nulls the deleted seat

`ReleasePlayer` deletes the player state row and the duel then finishes by automatic play. **Fix:** `FinishDuel` nulls a deleted seat's player id; the `PlayerDeleted` handler nulls it on duels already finished; duel operations tolerate a missing player state row.

### L13 — Map and paradigm rows

**Fix:** the `Accounts` row adds reachability; CAP-21 adds AD-55; CAP-41 adds AD-10, AD-12, AD-15, AD-49; CAP-42 adds AD-25; CAP-40 adds AD-8, AD-38, AD-43, AD-44; the ERD gains decks, deck cards, duels, duel rounds and duel stats.

### L14 — "Last used deck"

The sheet and the received dialog preselect the last used deck. **Fix:** the snapshot records the source deck's token per seat and the last used deck is read from the player's latest duel, or a column on `game_player_states`; the spine says which.

### L15 — `NoteReachable` is housekeeping

**Fix:** AD-10's housekeeping list adds the reachability lease (and the seat lease of H1): no event.

### L16 — Deck rows lack database checks

**Fix:** `game_deck_cards.slot` checked between 1 and 12 and unique per deck; the deck name checked 1 to 24 characters.

### L17 — `ComputeDuelStats` cannot run in the publication handler

It publishes `Game::DuelStatsComputed`, and handlers never publish (AD-10). **Fix:** "the `SeasonPublished` handler enqueues `ComputeDuelStatsJob`", as it does `HealBanksJob`.
