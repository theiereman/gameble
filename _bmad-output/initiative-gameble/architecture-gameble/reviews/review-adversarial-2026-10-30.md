# Adversarial review: the 2026-10-30 update (release 1.1.0)

Spine reviewed: `architecture-gameble.md` (updated 2026-10-30), the working-tree delta against the 2026-10-27 spine: new AD-35 (custom sets and active goals), AD-36 (Steam library sync), AD-37 (achievements as metrics), AD-38 (trade suggestions), AD-39 (share preview image); amendments to AD-4, AD-5 (rarity legend counts editions), AD-14, AD-15, AD-17, AD-21. Read with the 2026-10-30 spec (CAP-6, 9, 11, 17, 20, 27, 28; `achievements.md`) and the `.memlog.md` decisions of the same run.

Code read: `app/jobs/card_share_image_job.rb`, `app/models/card_share_image.rb` and `card_share_image/refresh.rb`, `app/controllers/share_images_controller.rb`, `Catalog::ShareImage`, `Catalog::StoreShareImage`, `Catalog::UpsertCardIdentity`, the share-image migration and routes (commit 46a61856, built a minute before the spine update); `Game::GrantAchievementsJob`, `BackfillAchievementsJob`, `GrantAchievement`, `AchievementProgress`, `Achievements`, `Handlers::Achievements`, `Handlers::PlayerActivity`, `Handlers::CardBacks`; `Game::Operation` (`lock_bank`, `require_player`), `Game::BankLock`, `Game::ReleasePlayer`, `Handlers::PlayerDeleted`; `Game::HeldGames`; `Catalog::SetBuilder.studios`, `Catalog::PublishedCardSeasonIds`; `TradesController#new`, `app/frontend/lib/trade_board_draft.ts`, `booster_reveal_all.ts`; `app/models/player_stream.rb`; `Accounts::ApplyRetentionJob`, `PlayerBySteamId`; `config/storage.yml`, `config/environments/production.rb`, `config/deploy.yml`, `config/recurring.yml`, `config/initializers/event_store.rb`; `db/schema.rb` (`game_packs`, `catalog_seasons`, `game_trades`); `pending-approvals.md`.

Method: for each new or amended AD, two units one level down (two 1.1.0 stories built by different sessions) that each obey every AD to the letter and still build incompatibly. Each finding names the pair, how both obey, the clash, the evidence, and the wording that closes it.

Severity: **high** means the two units ship data or behaviour that cannot coexist, or one breaks a privacy or erasure promise; **medium** means a visible inconsistency, a race with a wrong but recoverable result, or work the second unit has to undo; **low** means a wording gap two builders would probably, not certainly, resolve alike.

**Verdict: not yet a build contract for 1.1.0. Four high holes, six medium, seven low.** The domain cuts are right: custom sets and goals in `Game`, the library sync as a web-layer chain with no new arrow, achievements as metrics over state, suggestions computed on read. The holes are in what the new ADs leave unsaid where two stories meet: AD-39 contradicts the share-image story already built and cannot itself be built as written; AD-36 never says how the sync meets a deletion; AD-35 never says which games a custom set may list; AD-38 feeds friends' private custom-set goals into a friend-facing list. Each closes with a few sentences. None needs a new AD.

---

## H1 (high): AD-39 contradicts the share-image story already built, and two of its clauses cannot be built

**Pair.** The built story (commit 46a61856, plan status `in-review`) and the next unit to touch the image: the S3 switch AD-21 now orders, or AD-19's weekly cover refresh.

**What each obeys.** The built story follows its approved plan. A session that later reads AD-39 follows the spine.

**The clash, clause by clause.**

| AD-39 says | Built code does | Consequence |
| --- | --- | --- |
| `Catalog::RenderShareImageJob` renders | `CardShareImageJob` in `app/jobs`, composition in `app/models/card_share_image/*`; `Catalog::StoreShareImage` only stores | The render needs the card frame, the rarity colours and fonts, and locale words (`CardStrings`, `SetLabel`), all in the web layer. A `Catalog` job that renders would depend on the web layer, which AD-2 forbids. The spine's placement cannot be built. |
| Served "by a route under the card-season's slug, season and locale … with a long cache lifetime" | `GET /share-images/<token>.png`, a new token per render, `immutable`, one year | A stable URL with a year-long cache plus a re-render when the cover changes means Cloudflare and the crawlers keep the old image for a year. AD-39 contradicts itself; the code's token per render is what makes the re-render visible. |
| The row keeps "the cover URL and title it was rendered from" | It keeps a `fingerprint` (SHA-256 of the whole card view, the locale's words, `RENDER_VERSION`) | A refresh story written against the spine compares columns that do not exist, and misses the genre, the number and rarity-name changes the fingerprint already catches. |
| Stored in a private S3 bucket (AD-21, author's decision of 2026-10-30, rejecting "files on a volume") | `config.active_storage.service = :local` in production, on the `gameble_storage` volume; `pending-approvals.md` documents the volume | AD-21 says instances are stateless: a second web host cannot read the first host's volume. Nothing says how the images already stored on the volume reach the bucket. |
| "When an import or AD-19's refresh changes a card's cover or title, the rows … are re-rendered" | `CardShareImage::Refresh` follows `Catalog::CardIdentityUpserted` only | AD-19 says the weekly refresh goes "through a dedicated `Catalog` operation". If that operation publishes its own event, the subscriber misses it; only the page's fingerprint check catches it. |

Two smaller gaps sit in the built store path and would worsen under the spine's design:

- **Out-of-order renders.** Render A (old cover) and render B (new cover) run concurrently. If A commits after B, `StoreShareImage` replaces B with A, because it compares only against the stored fingerprint. The page's fingerprint check heals this at the next view; a stable URL would not.
- **Upload inside the transaction.** `ActiveStorage::Blob.create_and_upload!` runs inside the transaction that holds `FOR NO KEY UPDATE` on the card-season row. On S3 that puts a network upload under a row lock, and a rollback leaves an orphan object.

**Proposed AD-39 Rule (replaces the current bullets):**

> - `Catalog` owns `catalog_share_images`: one row per card-season and locale, with a public token, a fingerprint of what the image shows (the card view, the locale's words, a render version), and its PNG attached through Active Storage (AD-21). Nothing in it depends on a player. `Catalog::StoreShareImage` is its only writer.
> - The render belongs to the web layer, since it draws the card's frame, colours, fonts and copy: `CardShareImageJob` in `app/jobs` fetches the Steam cover, renders 1200 × 630 with ruby-vips (pixelated as on the card, 32 colours, no dithering), uploads the blob before any transaction, and calls `Catalog::StoreShareImage`. That operation stores the image only when its fingerprint still matches the card-season as it is now, under the card-season's row lock; otherwise it fails with `:stale_render`. A failure is reported to Sentry, leaves the previous row, and holds off further renders of that fingerprint for a day.
> - The card page's GET reads the row. It writes `og:image`, `twitter:image` and a large-image `twitter:card` only when the stored fingerprint matches the current one. Otherwise it enqueues the render (throttled through `Rails.cache`, which AD-11 allows) and the text-only preview stands.
> - The image is served at `/share-images/<token>.png`, outside the locale scope, signed out, `public, immutable`, for a year. A new render gets a new token, so a cached image is never served for a changed card. The route by slug and season is not used.
> - Every `Catalog` operation that changes a card's cover or texts, AD-19's refresh included, publishes `Catalog::CardIdentityUpserted`. `CardShareImage::Refresh` re-renders that card's existing rows from it.
> - Moving the store from the volume to the S3 bucket is configuration plus a bump of the render version, so each page renders its image again into the bucket; nothing copies blobs between services.

If the author keeps a `Catalog` owner for the job instead, AD-2 needs a new arrow; that is a decision for the author, not wording.

---

## H2 (high): the library sync against account deletion and set deletion: an erased library can come back

**Pair.** The library sync story (`SyncSteamLibraryJob` → `Steam::OwnedGames` → `Game::SyncLibrarySet`) and the account-deletion amendment (AD-14: `ReleasePlayer` drops custom sets, the library list and goals). Also the "delete my library set" action (spec: "deleting it stops the sync and erases the stored list").

**What each obeys.** The sync reads the Steam id, makes a Steam call that takes seconds, then calls one `Game` operation that "replaces the set's games in one transaction" (AD-36). Deletion runs `ReleasePlayer` in `Accounts`' deletion transaction, under AD-10's lock order.

**The clash.** AD-36 does not say what `SyncLibrarySet` takes (the player, or the set), whether it locks, or what it does when the set is gone. Three builds all obey the letter:

1. **Find or create.** The sync finds or creates "the player's library set" (the natural reading of "only AD-36's sync writes a library set's games"). It runs after the deletion commits and recreates the set with the library list for an anonymised player. That breaks AD-14's erasure and the spec's "deleting it … erases the stored list".
2. **No lock.** The sync reads the set, deletion removes it and commits, then the sync inserts games. With a foreign key this fails and the job retries forever. AD-35 names no foreign key; without one, the rows are orphaned.
3. **Row lock only.** The sync locks the set row, and its event reaches a handler that writes `game_player_states`. `ReleasePlayer` deletes `PlayerState` and would then delete the custom sets. Sync takes set row → player state; deletion takes player state → set row. That cycle can deadlock. AD-10's lock order has no place for custom set rows.

The same race hits a player who deletes the library set and creates a new one the same day: a stale job addressed by player writes the old library into the new set.

**Evidence.** `Game::Operation#lock_bank` already re-checks `deleted_at` under the advisory lock, and `GrantAchievement` uses it. `ReleasePlayer` takes `BankLock` and deletes `PlayerState` last. `GrantAchievementsJob` checks `deleted?` only at job start, so the operation's re-check is what protects it.

**Proposed wording.**

AD-36, replacing "Each reads … `Game::MarkLibraryUnavailable`":

> Each `SyncSteamLibraryJob` takes the player id and the set's token, never a Steam id or a games list. It reads the Steam id through `Accounts`, calls `Steam::OwnedGames`, then calls `Game::SyncLibrarySet` or `Game::MarkLibraryUnavailable` with the set's token. Both take the player's bank lock first (`lock_bank`, which refuses a deleted player), re-find the set by token under it, and succeed without writing when it is gone. Neither ever creates a set. `SyncLibrarySet` applies the difference (deletes the games that left, inserts those that came) rather than rewriting the list, so the bank lock is held briefly.

AD-10, lock order:

> … then the players' `game_player_states` rows, then the player's custom set rows and their games. A custom set's games reference the set with `ON DELETE CASCADE`, and a goal on a custom set references it the same way.

AD-35:

> Deleting a custom set, by the player or by `ReleasePlayer`, deletes its games and the goals on it in the same transaction, under the bank lock.

---

## H3 (high): "games of the catalog" is undefined, so the picker and the library sync list different games

**Pair.** The custom-set editor (its game picker) and the library sync (`Steam::OwnedGames` "returns the `catalog_cards` ids of the owned games present in the catalog"). Also the custom-set album and the goals highlight that read both.

**What each obeys.** AD-35 lists games as `catalog_cards` ids. Both builders read `catalog_cards`.

**The clash.** `catalog_cards` also holds draft-only games: imported for the next season, in `catalog_seasons` with status `draft` and card-seasons with null rarity (`StoreShareImage` and `PublishedCardSeasonIds` both filter `rarity IS NOT NULL` and `status = 'published'` for this reason). Two picker builds diverge:

- A picker that offers only published games, beside a sync that maps every owned app to any `catalog_cards` row. The library set then lists games no pack can give: they have no published card-season, no rarity, no face to draw in an album slot. They count toward a total that can never be met.
- A picker over `catalog_cards`. It lets a player search and list the next season's games before publication, which leaks the draft that AD-5 keeps behind promotion and publication.

Then the next publication drops a game that was in the last season. Game sets handle that ("a game that leaves a set stops counting for that set only"). For a custom set AD-35 is silent: the album, the hub progress and `GoalNeeds` can each decide alone whether the dropped game still counts.

**Proposed AD-35 bullet:**

> A custom or library set lists only games with a card-season in a published regular season, read through one `Catalog` query (`Catalog::PublishedCardIds`) that both the picker and `Steam::OwnedGames` filter by; draft-only and tribute cards are never listed. A listed game stays listed after a publication drops it: it counts toward the set's total and tiers, and shows as an empty slot named from the card's texts, since an earlier edition can still be held or traded. A set's total, held count and tiers are read by one query, `Game::CustomSetStandings`, which the album, the collection's sets list, the hub and `GoalNeeds` all use.

---

## H4 (high): trade suggestions read a friend's goals on private custom sets

**Pair.** The goals story (AD-35: a custom set, "its name and its goals are refused to anyone else"; the profile shows game-set goals only) and the suggestions story (AD-38: "from `Game::GoalNeeds` of the player and of each friend").

**What each obeys.** `GoalNeeds(friend)` returns every goal's missing games, as AD-35 defines it. AD-38 reads it for each friend open to friends.

**The clash.** A mutual suggestion tells the player "you spare a card your friend's goals miss". When that goal is on the friend's custom set, the suggestion reveals the set's contents to a friend, one missing game at a time. Watching suggestions across days reconstructs the set. AD-35 promises that nothing names a custom set on a friends' surface, and the suggestion is a friends' surface. One builder filters custom-set goals out of the friend's side; another follows CAP-11's "the friend's goals" literally. Both obey the letter.

**Proposed wording** (a default, for the author to confirm):

> AD-38: The player's own side reads all their goals. A friend's side reads only that friend's goals on game sets, the goals their profile may show (AD-35), through `Game::GoalNeeds(friend, game_sets_only: true)`. A suggestion names the friend and the cards, never a goal, set or tier.

If the author wants friends' custom-set goals to count, AD-35's "nothing names it on a public or friends' surface" must change to say a suggestion may reveal a wanted game but never its set.

---

## M1 (medium): the suggestion's prefill against the trade board's stored draft and the one-open-trade rule

**Pair.** The suggestion list (AD-38: "opens the trade board prefilled with its card-seasons (by slug and season)") and the trade board (AD-16: its browser-storage draft, `trade_board_draft.ts`, keyed per friend; `TradesController#new` redirects to the open trade when one exists).

**The clash.**

- **Draft against prefill.** The prefill can arrive as query parameters rendered into the initial markup, and the board's root then restores the friend's stored draft over it. Or the prefill is written into storage and merged with the old draft. Two builders pick differently, and the player sees either an unasked mix or a suggestion that silently drops.
- **One open trade.** When the player already has an open trade with that friend, `#new` redirects with the "one at a time" refusal. The suggestion list has no reason to know that, so its button leads to a refusal.
- **Quantity.** The quantity placed is unstated.

**Proposed AD-38 bullet:**

> A suggestion links to `trades/new?friend=<token>&give[]=<slug>:<season>&take[]=<slug>:<season>`, one copy each. A prefill replaces that friend's stored draft, and the board's initial state comes from the markup ahead of storage. A friend with whom the player has an open trade shows the suggestion with a link to that trade instead.

---

## M2 (medium): backfill against live grants: history announced as news, and the full progress query under the bank lock

**Pair.** `BackfillAchievementsJob` (run once after the deploy, `retroactive: true`) and `GrantAchievementsJob` (live, after every `PackOpened`, `TradeAccepted` …), running at the same time across the release.

**The clash.**

- **Ordering.** The backfill walks every player in batches. A player who opens a pack before the backfill reaches them gets every new achievement their history already meets granted live, non-retroactively. `PlayerStream` toasts each one, `Handlers::CardBacks` announces up to four backs, and the season recap lists them as earned in play. The flag AD-37 relies on depends on which job wins the race. Unique rows prevent doubles, not this.
- **Lock.** AD-37 says "the query computes only the metrics of achievements the player has not unlocked". But `GrantAchievement#reached` calls `AchievementProgress.call(player)` whole, inside `lock_bank`, once per met achievement. The 1.1.0 metrics scan every opened pack in order (streaks), every holding joined to its card (studio, release year) and every trade per partner. A veteran's backfill would run that scan about ten times under the bank lock, each run holding `POST /packs` past AD-7's 200 ms budget.

**Proposed AD-37 wording:**

> A release that adds achievements runs `BackfillAchievementsJob` before its code takes traffic: a data step of the deploy (a migration calling it `perform_now`), while the previous release, which knows no new key, still serves. No live grant of a new key therefore precedes the backfill.
>
> Under the bank lock, `GrantAchievement` re-reads only the metric of the achievement it grants (`AchievementProgress.call(player, metrics: [achievement.metric])`). The full read runs outside the lock, once per job.

---

## M3 (medium): the reveal-mode POST against the booster's opening and replay

**Pair.** The booster's reveal (AD-23's opening, `booster_reveal_all.ts`, where "Tout révéler" is available after some cards are already turned) and the achievements story reading `game_packs.reveal_mode`.

**The clash.**

- **Mixed reveals.** One card turned by hand, then "Tout révéler". AD-37 trusts the client, so the booster port decides what that is, and the achievements story assumes otherwise. Lazy Opener and Hardworking then disagree with their own conditions.
- **Repeats.** "Set once" does not say what a second POST does: an AD-23 replay re-reveals and POSTs again, as does a second tab or a network retry. A `Failure(:already_recorded)` would surface as an error toast on a successful reveal.
- **Old packs.** Nothing bounds which pack may be recorded. A player can POST `one_by_one` for every pack opened before the column, by token, and turn "packs opened before the column grant nothing" into a full streak.

**Proposed AD-37 bullet (replaces the reveal-mode bullet's middle):**

> The booster records `all` when "Tout révéler" turned any card of the pack, and `one_by_one` only when every card was turned by hand. `Game::RecordReveal` (`POST /:locale/packs/:token/reveal`) accepts only the player's own pack, opened within the last hour and after the column existed. A repeat returns success and writes nothing. It publishes `Game::PackRevealed` only when it writes.

---

## M4 (medium): the library sync's daily budget: where the count lives, who starves, and what the queue keeps

**Pair.** `SyncSteamLibrariesJob` (AD-36: "stops for the day at a configured number of calls") and the retention and moderation units: `Accounts::ApplyRetentionJob` deleting idle players, and bans.

**The clash.**

- **The count.** Where the count of calls is kept is unstated. One build keeps it in `Rails.cache`, another in a table. Both break AD-37's spirit of no stored counter, and neither says what resets it.
- **Starvation.** Enqueued "one per player with a library set" in id order, the same players fall past the cap every day once there are more sets than the budget.
- **Wasted calls.** The sync keeps calling Steam daily for banned and long-idle players until retention deletes them, spending the quota the import needs.
- **Queue arguments.** A builder who splits fetch and apply into two jobs passes the games list as a job argument. Solid Queue keeps the arguments of failed executions until someone clears them, so the library outlives AD-4's "the list lives only as that set's games".

**Proposed AD-36 wording:**

> `SyncSteamLibrariesJob` picks at most the configured number of library sets for the day, the least recently attempted first (never-synced first), skipping banned and deleted players and those not seen within the retention window. No call count is stored. `SyncLibrarySet` and `MarkLibraryUnavailable` both record the attempt time on the set.
>
> No job argument, log line or error context carries a Steam id or a games list.

---

## M5 (medium): Market Concentration's studio: a set member, or the card's first developer?

**Pair.** The achievements story (AD-37: "a studio is the card's first developer, as studio sets count it") and the studio sets (AD-5, `Catalog::SetBuilder.studios`).

**The clash.** `SetBuilder.studios` keys a studio by `SetNames.company(developers.first)`, keeps only studios with at least `MIN_GAMES` games and above `STUDIO_REVIEW_FLOOR`, and fixes membership per card-season at publication (AD-5: readers read the recorded membership, never the card's current data). "The card's first developer" reads `catalog_cards.developers`, which the import refreshes.

So one builder counts studio-set members of the published season and misses small studios. Another counts `developers.first` raw, without the company normalisation, and counts "Valve" and "Valve Corporation" apart. A third uses current developers, which drift from the set the player sees.

**Proposed AD-37 wording:**

> A studio is `SetNames.company` of the card's first developer as the card reads now, whether or not a studio set exists for it; the metric is read through one `Catalog` query that the studio sets' builder also uses for its key.

Or, if the author prefers set membership: "… is the key of a studio set of the published season the card-season belongs to". Either way, name one.

---

## M6 (medium): goals: duplicates, positions, and goals created on sets that cannot be aimed at

**Pair.** The "add a goal" action and the "reorder / remove" action, possibly two stories. Also the goal picker and a new season's publication.

**The clash.**

- **Duplicates.** Two goals on the same set pass every check, since uniqueness is only per player and position, and the hub then shows the set twice.
- **Positions.** An add that takes "count + 1" after a removal collides with the unique index. A swap needs the index deferrable or a two-step move, and AD-35 says neither.
- **Absent and tribute sets.** The picker can offer a set kind and key absent from the published season (reached from an earlier season's album) or the `tribute` set (AD-33, never the published season), and creates a goal that is born "ended".
- **Addressing.** How a goal is addressed in a URL is unstated: AD-15 forbids its id, positions shift, and the target is stable.

**Proposed AD-35 bullet:**

> Goals are unique per player and target (a partial unique index for each target kind). Adding takes the lowest free position under the bank lock, and a move rewrites the positions of that player in one statement, with the unique index `DEFERRABLE INITIALLY DEFERRED`. A goal is created only on a set of the published season (`tribute` excluded) or on the player's own `custom` set. A goal is addressed by its target: the set's kind and key, or the custom set's token.

---

## Low

- **L1. AD-5's rarity legend.** "The card-seasons of every regular season" should read "of every published regular season". Draft card-seasons are excluded today only because their rarity is null, an accident. Also, the legend's "totals across rarities" row (editions) sits directly under the top-bar counter (distinct games) and will show a larger number than the counter it opens from. Since the author chose editions, the row's label should say editions, or the screen will read as a bug report.
- **L2. AD-13's private stream list.** It names trades, invitations and card backs. The code also sends `Game::AchievementUnlocked` (`PlayerStream::EVENTS`), and AD-37's job-granted achievements can only be announced that way. Add "achievements unlocked" to the list.
- **L3. AD-24 presence.** `Handlers::PlayerActivity` is an allowlist in code, but the spine never says so. A builder who subscribes it to `PackRevealed`, `LibrarySetSynced` or a goal event shows a player "active" at the 3 a.m. sync. Add: "only the events of `PlayerActivity::EVENTS` are activity; a job's work never is."
- **L4. Reading the Steam id.** AD-36 says "reads the player's Steam id from `Accounts`". AD-34 keeps both `accounts_players.steam_id` and the `steam` identity row "for now". Name the identity row (`Accounts::SteamIdOf(player)` over `accounts_identities`) so the sync survives `steam_id`'s removal.
- **L5. Custom-set events.** AD-10's "events carry identifiers only" covers names. Say also that no event carries a custom or library set's games: events are never deleted, so a list in an event outlives the erasure AD-14 promises.
- **L6. Exotic share image.** The parked tribute season (AD-33) would hand `CardShareImageJob` a tier-6 card-season with no frame colours: a Sentry report per view. When AD-33 resumes, its Costs line should name the share image.
- **L7. Retroactive grants and the season recap.** CAP-23's recap lists "achievements unlocked during" the season. Backfilled grants carry the release time, so the next recap presents history as play. Either `game_achievement_unlocks` records `retroactive`, or the recap skips unlocks granted at a release.

---

## Summary

| # | Sev | Pair | Closes with |
| --- | --- | --- | --- |
| H1 | high | built share-image story vs S3 switch / weekly refresh | AD-39 rewritten to the built design (web-layer render, token-per-render route, fingerprint, stale-render refusal, one change event, S3 by config + render-version bump) |
| H2 | high | library sync vs account / set deletion | AD-36: job takes token, op takes `lock_bank`, re-finds by token, never creates, diff-applies; AD-10 lock order gains custom set rows; cascades |
| H3 | high | custom-set picker vs library sync (and album vs goals) | AD-35: only games with a published regular card-season, one `Catalog` query for both; dropped games stay and count; one standings query |
| H4 | high | goals privacy vs mutual suggestions | AD-38: friend's side reads game-set goals only; suggestion names no set (author confirms) |
| M1 | med | suggestion list vs trade board | AD-38: prefill URL contract, replaces stored draft, open trade linked instead |
| M2 | med | backfill vs live grant | AD-37: backfill before new code serves; per-metric re-check under lock |
| M3 | med | reveal POST vs booster replay | AD-37: mixed = `all`; idempotent; only recent, own, post-column packs |
| M4 | med | sync budget vs retention / bans | AD-36: oldest-attempt-first selection, no stored counter, skip banned/idle; no Steam data in job args |
| M5 | med | studio metric vs studio sets | AD-37: one named studio definition and query |
| M6 | med | goal add vs reorder / publication | AD-35: unique per target, lowest free position, deferrable index, published-season targets only, addressed by target |
| L1–L7 | low | see above | one sentence each |
