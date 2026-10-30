# Rubric review: spine update 2026-10-30 (release 1.1.0)

- **Spine:** `architecture-gameble/architecture-gameble.md`, uncommitted delta of 2026-10-30. New: AD-35 to AD-39. Amended: AD-4, AD-5, AD-14, AD-15, AD-17, AD-21, the layer table, the Stack, the seed diagrams, the capability map and Deferred.
- **Context:** `.memlog.md` entries 172 to 182 (the update run's decisions).
- **Spec checked:** `spec-gameble.md` CAP-6, CAP-9, CAP-11, CAP-17, CAP-20, CAP-27, CAP-28 and the 1.1.0 constraints; `achievements.md`; the story `backlog/story-a-shared-card-link-previews-with-a-generated-image.md`; the three 1.1.0 epics (`epic-aim-at-the-cards-you-want`, `epic-more-achievements-and-easy-card-backs`, `epic-trade-suggestions`).
- **Code checked:** commit `46a61856` (the share image, built the same morning; its plan is `in-review`): `app/jobs/card_share_image_job.rb`, `app/models/card_share_image*.rb`, `app/controllers/share_images_controller.rb`, `Catalog::ShareImage`, `Catalog::StoreShareImage`, the `Catalog::ShareImage*` queries, `config/routes.rb`, `config/application.rb`, `config/storage.yml`, `config/environments/production.rb`, `config/deploy.yml`, `pending-approvals.md`. For achievements: `Game::Achievements`, `Game::AchievementProgress`, `Game::GrantAchievementsJob`, `Game::BackfillAchievementsJob`, `Game::Handlers::Achievements`, `Game::GrantAchievement`, `Game::CardBacks`, `Game::GrantCardBacksJob`, `PlayerStream`, `game.rake`. Also `Game::HeldGames`, `Game::CollectionSummary`, `Game::ProposeTrade`, `Game::Draw`, `Catalog::SetBuilder`, `Catalog::TierTable`, `Catalog::UpsertCardIdentity`, `config/recurring.yml`, `config/queue.yml`, and in `db/schema.rb` the tables `game_packs`, `game_daily_bonus_claims`, `game_first_discoveries`, `game_feed_entries`, `game_trades`, `catalog_seasons` and `accounts_identities`.

## Verdict

**Conditional pass.** AD-35 to AD-38 are well aimed. They keep custom sets out of `catalog_sets` and out of rewards, keep goals out of the draw, give the missing cards a single query (`GoalNeeds`), use only the existing dependency arrows for the library sync, and keep achievements on one metric query shared by the live grant and the backfill. Their claims about the achievement code hold.

The share image section (AD-39, with AD-15 and AD-21) does not hold. It describes a design that differs from what commit `46a61856` built the same morning, in the job's name and domain, the route, the staleness model and the storage. Its slug route with a long cache lifetime would also bring back the stale-image problem that its own Prevents line names.

Beyond that, five divergence points stay open, and independently built stories would hit them on day one:
- which catalog games a custom set or a library set may hold;
- the reveal POST, which contradicts AD-7 and has no exchange in AD-23;
- the library sync confusing a Steam error with a private profile;
- the queues the new jobs run on;
- the daily call budget's mechanism.

Fix the critical finding and H1 to H5 before slicing the 1.1.0 stories. Fix the medium findings in the same pass, and the low ones when convenient.

## Checklist

| Check | Result |
| --- | --- |
| Fixes the real divergence points of 1.1.0 | Mostly. Open: the catalog scope of custom sets (H2), the reveal exchange and its mixed mode (H3), transient vs private library failures (H4), the queues (H1), the budget mechanism (H5), the metric details (M1), the legend's season scope and counter (M2). |
| Every Rule is enforceable and prevents its divergence | Most are, through database constraints (positions 1 to 5, partial unique library index, uniqueness per set and game) or a single named query. AD-39's route rule defeats its own Prevents (C1). "Packs opened before the column grant nothing" cannot be enforced as written (H3). "Stops for the day at a configured number of calls" has no place for its count (H5). |
| Nothing Deferred lets two units diverge | Holds for the new entries: the suggestion cache and the budget value are values or optimisations, and their mechanisms are fixed elsewhere (except H5). The existing "Production backup schedule and restore drill: set before launch" is stale since the 2026-10-29 launch and says nothing about the bucket (M3). |
| Ratifies rather than contradicts existing code | Achievements, HeldGames, ProposeTrade, the card backs, the event names and the `game_packs` columns are ratified (see below). The share image is contradicted (C1). |
| Covers every 1.1.0 spec point | Yes, every listed point has a home. The spec's CAP-6 "distinct cards" against the spine's "editions" needs a sentence (M2). |
| Operational envelope | The bucket per destination, the secrets, the recurring sync, the Steam key and its quota are decided. Missing: the queues and job priority (H1), S3-compatible client settings (M4), the backup stance and lost-file behaviour of the bucket (M3), the move off the built local volume (C1), and the scope of who gets synced (H5). |

### Claims about existing code, checked

| Claim | Found |
| --- | --- |
| `Game::Achievements` is a constant of key, metric, threshold | Yes: `Achievement = Data.define(:key, :metric, :threshold)`, `CATALOGUE` of ten. |
| `Game::AchievementProgress` is the one metric query for the live grant and the backfill | Yes: one SQL, read by `GrantAchievementsJob.grant`, by `GrantAchievement#reached` and, through `grant`, by `BackfillAchievementsJob`. It computes every metric today; "only the metrics not unlocked" is a new rule, not a ratification (fine, but say so in the story). |
| `GrantAchievementsJob` follows the events of AD-10 | Yes: `Game::Handlers::Achievements` enqueues it on `PackOpened`, `SetCompleted`, `SeasonAllocationReceived`, `CardReposted`, `TradeAccepted`. |
| Retroactive grants raise no toast | Yes: `PlayerStream` drops `retroactive` achievement and back unlocks. The backfill is the `game:backfill_achievements` rake task. |
| `DailyBonusCollected`, `CardDiscovered` exist | Yes. `CardDiscovered` is a second event published by `OpenPack` (pre-existing; fine). `PackRevealed` and `RecordReveal` are new. |
| `game_packs` has `kind` (`regular`, `bonus`, `reward`), `card_season_ids`, `opened_at` | Yes; `reveal_mode` is new. `Game::Draw.pack` allows a game twice in a pack, so "Packaging Irregularity" is reachable. |
| Achievement backs are entries of AD-25's constant | Yes, `Game::CardBacks::ACHIEVEMENT_BACKS`, which already maps three of the ten old achievements (see M1d). |
| `Game::HeldGames`, `Game::ProposeTrade`, `Catalog::TierTable`, studio = first developer | Yes (`SetBuilder.studios`: `developers.first(1)` through `SetNames.company`). |
| Share image: `Catalog::RenderShareImageJob`, a slug/season/locale route, a row with cover URL and title, S3 | No (C1). |

## Findings

### Critical

**C1. AD-39, AD-15, AD-21: the share image section contradicts the code built for it, and its route defeats its own Prevents.**

Commit `46a61856` (plan `in-review`) built:
- `CardShareImageJob` in `app/jobs`, with the composition in `app/models/card_share_image/*` in the web layer, since it uses `CardStrings`, `SetLabel` and the locale's words;
- `Catalog::StoreShareImage`, an operation that publishes `Catalog::ShareImageStored`;
- a `fingerprint` column (a SHA-256 of the card view, the locale's words and `RENDER_VERSION`) compared at page read;
- `CardShareImage::Refresh` on `Catalog::CardIdentityUpserted`;
- a route `/share-images/<token>.png` outside the locale scope, whose token is regenerated for every new fingerprint and served `public, immutable` for a year, with Active Storage's own routes turned off;
- storage on the `local` service, in the `gameble_storage` volume.

AD-39 instead names `Catalog::RenderShareImageJob` in `Catalog`, a row "with the cover URL and title it was rendered from", re-rendering only on import or refresh, and "a route under the card-season's slug, season and locale … with a long cache lifetime". AD-21 names S3.

A stable slug URL with a long cache lifetime is exactly how "a stale image after a cover change" happens: Cloudflare, Discord and X keep the old bytes under the same URL. The built token rotation is what prevents it. A builder who follows the spine rewrites working code into a worse design. A builder who follows the code leaves the spine wrong.

**Fix:**
- Rewrite AD-39's Rule to ratify the built shape:
  - `Catalog` owns `catalog_share_images` (card-season, locale, public token, fingerprint) and `Catalog::StoreShareImage`.
  - The render is a web-layer job (`CardShareImageJob`) because it draws the card's copy.
  - The fingerprint covers what the image shows plus a render version. The page shows the image only when the fingerprint matches, and otherwise enqueues the render, throttled through `Rails.cache`. This is a cache write, not a primary write (say so under AD-11).
  - A new fingerprint gets a new token, so an image URL is immutable.
  - Re-rendering also follows `Catalog::CardIdentityUpserted`.
- AD-15: add "share images by a token rotated with their content".
- Keep the S3 decision (memlog 176) as the one deliberate change, with a "built code brought into line" bullet:
  - production switches `active_storage.service` to the S3 service before the share image ships to production;
  - existing local blobs are not migrated: clear `catalog_share_images` or bump `RENDER_VERSION`, since the images are derived;
  - the `gameble_storage` volume and the `local` service in production go once nothing reads them.
- The stack's `ruby-vips` row is already a dependency; only `aws-sdk-s3` is new.

### High

**H1. AD-21, AD-36, AD-39: the new jobs have no named queue, and renders already run on `default`.**

`CardShareImageJob` is `queue_as :default`. `config/queue.yml` runs `default` with 3 threads inside Puma (`SOLID_QUEUE_IN_PUMA`), next to `SumWeeklyGoalJob` and `LiveGoalJob` every 10 seconds, `ExpireTradesJob` every minute and `GrantAchievementsJob` after every opening. Two things can flood that queue:
- a crawl of the sitemap's card pages in two locales (once `SEARCH_INDEXING` is on);
- an import: `UpsertCardIdentity` publishes on every upsert, changed or not, and `Refresh` enqueues one job per stored image of that card.

Each of those jobs fetches the Steam CDN and runs libvips in the web process. AD-36's "its own throttled queue" names nothing, and `queue.yml` says a new queue must be listed by hand.

**Fix:**
- Add to AD-21: "Each background workload with external calls has its own queue, listed in `config/queue.yml` with one thread: `import` (AD-19), `share_images` (AD-39), `steam_library` (AD-36). Nothing slow runs on `default`."
- In AD-39, put `CardShareImageJob` on `share_images`.

**H2. AD-35, AD-36: "a game of the catalog" is undefined.**

`catalog_cards` holds draft-only cards (imported, never published) and cards absent from the published season. `Steam::OwnedGames` returns "the `catalog_cards` ids of the owned games present in the catalog", and CAP-27 lets a player pick "games of the catalog". The custom-set editor's search, the library sync, the album's empty slots (a face needs a card-season) and the tier count from "its current game count" can each pick a different scope. A library set could then show games no player can ever pull.

**Fix:** AD-35 should say: "A custom set lists cards that have a card-season in a published season. The editor offers only those and the library sync keeps only those. A listed game keeps counting (any edition) after a later season drops it, and its empty slot shows its latest published card-season. Tiers are computed from the number of listed games." (Or pick the stricter "published season only" scope; either way, say it once.)

**H3. AD-37 against AD-7 and AD-23: the reveal POST contradicts "the server keeps no flip state", has no exchange, and its history rule cannot be enforced.**

There are three problems:
1. AD-7 still says "The reveal is a browser animation. The server keeps no flip state."
2. AD-23 exists so that no session invents its own opening request, yet the reveal POST has no route, payload, error codes or idempotency.
3. "Packs opened before the column grant nothing" cannot be enforced: a client can POST a mode for any old pack it owns and seed a streak backwards. The mode is also undefined when a player flips two cards and then presses "Tout révéler". The booster's module and the achievement metric will each choose their own reading.

**Fix:**
- Amend AD-7: "except the reveal mode recorded once after the reveal (AD-37)".
- Add to AD-23:
  - The exchange is `POST /:locale/packs/:token/reveal`, JSON `{ mode }`.
  - It is accepted only for the player's own opened pack, while `reveal_mode` is null, and only for the player's most recently opened pack (or within a few minutes of `opened_at`). A repeat is a no-op success.
  - Codes: `not_found`, `already_recorded`, `too_late`.
- State the meaning in AD-37: `all` when "Tout révéler" was used for any card, `one_by_one` only when every card was flipped by itself. The value is computed in `app/frontend/lib/booster.ts`.

**H4. AD-36: a Steam error is read as "Steam does not share the library".**

`Steam::OwnedGames` returns `Failure(:library_unavailable)` "when the answer holds no games list or fails", and the job then calls `MarkLibraryUnavailable`. After a 5xx, a 429 or a timeout, the screen would tell the player that their game details are private (CAP-27). The bulk sync would mark many players at once during a Steam outage.

**Fix:**
- `Steam::OwnedGames` returns `Failure(:library_private)` only when Steam answers 200 without `games`.
- Transport errors, 5xx and 429 raise, and the job retries with backoff without touching the set. After the last retry it reports to Sentry and leaves the set as it was.
- Only `:library_private` calls `MarkLibraryUnavailable`, which records "unavailable since" and publishes `Game::LibrarySetUnavailable` (or is declared a housekeeping write; AD-10 requires one or the other).

**H5. AD-36: the daily budget has no mechanism, and the scope of who is synced is open.**

"The sync stops for the day at a configured number of calls" leaves open where the count lives (a `Rails.cache` counter, a table, Solid Queue limits) and whether first syncs on create count against it. A player can also delete and recreate their library set to force calls. Banned, deleted and long-absent players would be synced daily forever.

**Fix:**
- `SyncSteamLibrariesJob` enqueues at most `STEAM_LIBRARY_DAILY_SYNCS` (an environment value, the Deferred entry) library sets per day, least recently synced first, so there is no counter.
- It skips banned and deleted players and players not seen for 30 days (their set syncs at the next daily run after they return).
- Creating a library set is rate-limited to once per player per day, and its first sync is one of the day's.

### Medium

**M1. AD-37: four metric details that two builders would read differently.**
- (a) "Holding metrics are the current maximum over `game_holdings`." Rows are per card-season, but "Diversified Portfolio" counts copies of a game. Say "`SUM(quantity)` per card across its card-seasons, the maximum over cards".
- (b) "A studio is the card's first developer, as studio sets count it." `SetBuilder.studios` normalises with `Catalog::SetNames.company`. Say that `Game` reads the studio key through a `Catalog` query and never recomputes it.
- (c) "Streak metrics are the longest run over opened `regular` packs". That fits "Luck Is a Marketing Concept" (standard capsules), but `achievements.md` says the two reveal streaks run over "capsules". Decide whether bonus and reward packs count in, are skipped, or break a reveal streak, and write it down.
- (d) `ACHIEVEMENT_BACKS` already maps `boosters_100 → centurion`, `first_legendary → etoile-dor` and `three_complete_sets → aurore`, while `achievements.md` names four new back achievements and says nothing of these three. Say that the three stay (players hold the unlock rows) and that the constant gains four.

**M2. AD-5's rarity legend: the season scope, the counter, and the filter.**
- "Every regular season": `catalog_seasons` has no kind, only `draft` and `published` (AD-33 is parked). Read literally, the draft season's card-seasons would inflate the overall totals. Say "every published season".
- The top-bar counter reads `HeldGames.count` (games), and the legend that opens right under it counts editions. Its overall owned total will exceed the counter. CAP-6 also says "distinct cards", and the spine elsewhere says "a game is a card". Say once that the legend counts editions by the author's choice and differs from the counter, so that nobody "fixes" one into the other, and ask the spec to say "editions".
- "Choosing a rarity filters the card grid on it": state whether the grid matches on the shown (best minted) rarity, which will not equal the legend's edition count.

**M3. AD-21, AD-39, Deferred: the bucket's backup stance and lost-file behaviour.**

Nothing says whether the bucket is backed up. If a blob goes missing, the built `ShareImageByToken` returns nil and the controller answers 404, while the card page keeps writing `og:image` because the row's fingerprint matches (pending-approvals says as much). The Deferred "backup schedule … set before launch" is stale since the 2026-10-29 launch.

**Fix:**
- AD-39: "the bucket is a derived cache: it is not backed up, and a row whose blob is missing counts as missing (no tags, the render is enqueued)".
- Rewrite the Deferred entry as the production database backup and restore drill, with the bucket excluded.

**M4. AD-21: the S3-compatible client settings.**

From 1.178 on, `aws-sdk-s3` sends CRC checksums by default, and several S3-compatible stores reject them. Most self-hosted stores also need path-style addressing. Two sessions configuring staging and production will find this separately.

**Fix:** AD-21 should say:
- the `s3` service in `config/storage.yml` reads endpoint, region, bucket and keys from `ENV` (AD-21's environment-only rule, not `credentials` as the template comment suggests), with `force_path_style: true`, `request_checksum_calculation: "when_required"` and `response_checksum_validation: "when_required"`;
- the first staging deploy checks one upload and one download.

**M5. AD-38: friends' custom-set goals, and AD-8's four-card cap.**

CAP-27 makes a custom set and its name visible to its author only. AD-38 reads "`GoalNeeds` of … each friend", which includes goals on custom sets. Two builders will differ on whether a friend's private set feeds mutual suggestions. A suggestion can also hold more than four cards per side, while AD-8 caps a proposal at four.

**Fix:**
- State that a friend's custom-set goals feed suggestions only as bare missing games, never naming or hinting at the set (or exclude them).
- State that a prefilled proposal places at most four card-seasons per side, mutual cards first, then by goal position.

### Low

- **L1. Status markers.** AD-35 to AD-39 carry no `[ADOPTED]` or "approved by the author" marker, unlike AD-1 to AD-34. AD-35 is a "fast path" per the memlog. Mark each one's status so builders know whether it binds.
- **L2. Capability map.** The rows lag the Binds. CAP-8 lacks AD-35 (goals on the profile) and AD-38. CAP-11 lacks AD-35. CAP-14 lacks AD-36. CAP-20 lacks AD-37.
- **L3. AD-36 and the Steam id.** "Reads the player's Steam id from `Accounts`" should go through the Steam identity (`accounts_identities`, provider `steam`, AD-34), not `steam_id`, which AD-34 plans to retire.
- **L4. AD-36 and the legal pages.** As AD-34 does for Clerk, name the privacy notice, the retention page and the legal page's stored-data line as carrying the library list and the daily Steam call (the epic lists this as a follow-up). Say whether `Accounts::ApplyRetentionJob` touches it.
- **L5. AD-35 and goals.**
  - Deleting a custom set deletes its goals in the same operation.
  - Reordering goals under a unique `(player, position)` needs a deferrable constraint or a two-step swap. Pick one.
  - "A library set is never a goal" is checked by the operation, since a check constraint cannot see the target's kind.
  - `SyncLibrarySet` fails with `:no_library_set` if the set was deleted while the job ran.
- **L6. Stack.** `aws-sdk-s3` is not in `Gemfile.lock` yet. `ruby-vips` was already a dependency (the Gemfile comment cites the card filter), so its reason column should not read as new.
- **L7. AD-37 and the backfill.** Name the trigger: "the author runs `bin/rails game:backfill_achievements` after the deploy (idempotent)". It is a sensitive operation for `pending-approvals.md` when the author is away.
- **L8. AD-39 and import fan-out.** `UpsertCardIdentity` publishes even when nothing changed, against AD-10's "an operation that changes nothing publishes nothing". With `Refresh`, an import enqueues one no-op render per stored image. Either accept it (the job skips on the fingerprint, on its own queue after H1) or have `Refresh` compare the fingerprint before enqueuing.
