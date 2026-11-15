---
title: "Every card's detail shows its duel profile, recomputed each Monday"
type: 'feature'
ticket: '1'
created: '2026-11-15'
status: 'built'
baseline_revision: 'a41c6f968404a070d7aa45ccbce57ce8be091f87'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/duel-rules.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Tribute card-seasons are not excluded from the duel stats because no tribute season kind exists yet.
    evidence: |-
      The exotic-cards epic is parked; Game::DuelMeasures filters only published seasons and rated card-seasons, so the tribute season must be excluded when it is built.
    location: >-
      app/domains/game/app/queries/game/duel_measures.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** Cards have no duel profile yet: the stats lane of the duels epic (decks, duels, Monday feed entry) needs one stored table of five percentile stats per card-season, recomputed on deploy, on season publication and every Monday, and players need to see it on the card detail.

**Approach:** One migration creates `game_duel_stats`; `Game::ComputeDuelStats` (an `ApplicationOperation`) replaces every row in one transaction from Catalog and Game data, publishes `Game::DuelStatsComputed`; a job, the season handler, a rake task in the deploy entrypoint, the seeds and `config/recurring.yml` trigger it; one query `Game::DuelProfiles` reads it; the card detail renders a DUEL block after ÉDITIONS.

## Boundaries & Constraints

**Always:**
- Rows: one per card-season with a non-null rarity of every published season (no tribute season kind exists yet; every published season is regular). Unrated (rarity NULL) and draft-season card-seasons get no row.
- Stats, in this fixed order (also the trump tie order): popularity, rating, release, discovery, circulation. Each has its exact value, its percentile (0–100, one decimal) toward its first direction (most popular, best rated, most recent, discovered first, most widespread), its distance from the median, and its last weekly percentile.
- Measures and ranking groups: popularity = `catalog_card_seasons.review_count`, ranked among the rated card-seasons of the same season; rating = `FLOOR(catalog_card_seasons.rating)` (the whole percent the card detail already shows), ranked in the same group by (whole percent, review_count) so an equal percent is broken by the review count; release = `catalog_cards.release_date`, same group, later is higher; discovery = `game_first_discoveries.discovered_at`, ranked among the season's card-seasons that have a first discovery, EARLIER is higher; circulation = count of distinct `game_holdings.player_id` with `quantity > 0`, ranked among the card-seasons of the same season and rarity held by at least one player (Archives deposits are not holdings and never count). A card-season with no discovery has no discovery value and percentile; one nobody holds has no circulation value and percentile; a NULL review_count gives no popularity value (and counts as 0 for the rating tie-break).
- Percentile (midrank) = 100 × (number of ranked values strictly below + 0.5 × number equal, the card itself included) ÷ number ranked, rounded half up to one decimal, computed exactly (Rational/BigDecimal or SQL numeric, never float).
- Median distance = |value − median of the group's values| (median = mean of the two middle values for an even count), stored as a float in the stat's natural unit: reviews, percent points, days, seconds, holders.
- Trump = the stat whose percentile is farthest from 50, among stats with a value; ties go to the earlier stat in the order above; direction `high` when the percentile is ≥ 50 (toward the first direction), else `low`.
- Last weekly percentiles: a `first` or `weekly` run sets them to the percentiles the card-season's previous row held, or to this run's own when it had no row; a `season` run keeps the previous row's last weekly percentiles, or this run's own for a card-season that had no row.
- The operation takes a transaction-level Postgres advisory lock (one fixed key) before reading, so two runs never overlap; it deletes and inserts every row in that one transaction with one `computed_at`, and publishes exactly one `Game::DuelStatsComputed` (data `{ reason: }`, reason one of `first`, `season`, `weekly`; any other reason is `Failure(:unknown_reason)`). No handler subscribes to it in this story.
- The card detail's DUEL block reads only `Game::DuelProfiles`; nothing else computes a percentile. Its bars are `<progress max="100">` hidden from assistive technology; no `style` attribute; labels are sentence case in the locales, capitals by CSS; every string in both `en.yml` and `fr.yml` (French plural keys with a `zero` form).

**Never:** no deck, editor, arrows, feed entry, feed handler subscription or Monday entry (later stories); no DUEL block on the public card page (`cards/_public`) or on the card face; no planning ids in code; no write from a controller, view or GET; no Solid Queue API in code; no new React or script-built markup.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Midrank ties | 4 card-seasons of a season, review counts 10, 20, 20, 40 | popularity percentiles 12.5, 50.0, 50.0, 87.5 | — |
| Rating tie broken | two cards at 91.4 % and 91.8 % (both 91), review counts 100 and 50 | different percentiles; the one with 100 reviews is higher; rating value 91 for both | — |
| Discovery | first discoveries at t1 < t2; a third card never pulled | t1 card higher than t2 card; unpulled card: discovery and circulation value and percentile NULL | — |
| Circulation per tier | two Commons held by 3 and 1 players, one Epic held by 1 player, an Archives deposit on a Common | Commons ranked only against each other (75.0 / 25.0); the Epic alone at 50.0; the deposit changes nothing; a holding with quantity 0 counts no holder | — |
| No row | an unrated card-season; a draft season's card-season | no row | — |
| Trump | percentiles 60, 95, 10, 30, 50 / 60, 70, 3, 30, 50 / 90, 10, 50, 50, nil | rating `high` / release `low` / popularity `high` (tie of 40 with rating goes to the earlier stat) | — |
| Median distance | review counts 10, 20, 40 | median 20; distances 10, 0, 20 | — |
| Rotation | row exists with popularity 40.0, weekly 30.0; new run computes 55.0 | `weekly` → weekly 40.0; `first` → weekly 40.0; `season` → weekly stays 30.0; a new card-season gets weekly = its own percentile | — |
| Event | any successful run | exactly one `Game::DuelStatsComputed` with the run's reason | `reason: "monthly"` → `Failure(:unknown_reason)`, rows unchanged, no event |
| Card detail | player or visitor opens the detail of a card-season with a row | DUEL block after the facts: 5 rows, ATOUT on the trump row, "Valeurs du <date>" | card-season without a row → no block; public card page → no block |

</intent-contract>

## Code Map

- `db/migrate/` -- new `<timestamp>_create_game_duel_stats.rb` (latest is `20261115090000`). Columns: `card_season_id` bigint not null, unique index, FK to `catalog_card_seasons`; `popularity_value` integer, `rating_value` smallint, `release_value` date, `discovery_value` datetime, `circulation_value` integer; per stat `<stat>_percentile` decimal(4,1), `<stat>_median_distance` float, `<stat>_weekly_percentile` decimal(4,1); `trump_stat` string not null, `trump_direction` string not null; `computed_at` datetime not null. Inline checks: percentiles between 0 and 100, trump values in the allowed sets, discovery value/percentile/distance null together, same for circulation (popularity too). A new table may carry its checks inline. Regenerate `db/schema.rb` exactly as AGENTS.md says.
- `app/domains/game/app/models/game/duel_stat.rb` -- new model, `STATS = %i[popularity rating release discovery circulation]`, `DIRECTIONS = %w[high low]`.
- `app/domains/game/app/models/game/duel_ranking.rb` (or similar pure object) -- midrank percentiles, median and distances for one group of `[id, comparable]` pairs; unit-testable without the database.
- `app/domains/game/app/operations/game/compute_duel_stats.rb` -- new operation, `call(reason:, now: Time.current)`. Read the measures with plucks/SQL joining `catalog_card_seasons` + `catalog_seasons` (`status = 'published'`, `rarity IS NOT NULL`) + `catalog_cards`, `game_first_discoveries`, `game_holdings`; build rows; `pg_advisory_xact_lock` inside `transaction`; `DELETE` + `insert_all` in batches; `step publish(DuelStatsComputed.new(data: { reason: }), stream_name: DuelStatsComputed::STREAM)`. Pattern: `app/domains/game/app/operations/game/market/sum_archive_stocks.rb`, `write_daily_snapshot.rb`; base `lib/application_operation.rb`. Keep each file under 400 lines (split measures into a query such as `app/domains/game/app/queries/game/duel_measures.rb` if needed).
- `app/domains/game/app/events/game/duel_stats_computed.rb` -- `RubyEventStore::Event`, `STREAM = "Game::DuelStats"`; pattern `events/game/market/daily_snapshot_written.rb`.
- `app/domains/game/app/jobs/game/compute_duel_stats_job.rb` -- `ActiveJob::Base`, `queue_as :default`, `perform(reason = "weekly")` → `ComputeDuelStats.new.call(reason:).value!`. Pattern `jobs/game/archive_stocks_job.rb`. One at a time is the operation's advisory lock.
- `app/domains/game/app/handlers/game/handlers/season_published.rb` -- add `ComputeDuelStatsJob.perform_later("season")` (jobs enqueue after commit: `config/initializers/active_job.rb`). Already subscribed in `config/initializers/event_store.rb`.
- `app/domains/game/app/queries/game/duel_profiles.rb` -- `Game::DuelProfiles.call(card_season_ids)` → hash card_season_id → `Profile` (Data: `stats` in STATS order, each `Stat` with name, value, percentile, median_distance, weekly_percentile; `trump_stat`, `trump_direction`, `computed_at`). The one reader for the detail, and later the editor, the duel snapshot and automatic moves.
- `app/domains/game/lib/tasks/game.rake` -- new `game:compute_first_duel_stats`: when `Game::DuelStat.none?` run `Game::ComputeDuelStatsJob.perform_now("first")`, print a line either way; idempotent.
- `bin/docker-entrypoint` -- `./bin/rails db:prepare game:backfill_achievements game:compute_first_duel_stats game:create_first_market_settings` (update its comment); `test/config/docker_entrypoint_test.rb` follows.
- `db/seeds.rb` -- after the fake players' openings block (line ~89): `if Rails.env.development? && Catalog::PublishedSeason.call && Game::DuelStat.none?` → `Game::ComputeDuelStatsJob.perform_now("first")` with a `puts`.
- `config/recurring.yml` -- `compute_duel_stats` anchor: class `Game::ComputeDuelStatsJob`, queue `default`, `args: [ "weekly" ]`, schedule every Monday at 00:00 UTC (check the string parses with `Fugit` to cron `0 0 * * 1` in UTC); add to both `development` and `production`. Test pattern `test/config/recurring_archive_stocks_test.rb`.
- `app/controllers/cards_controller.rb` (248 lines) -- `@duel_profile = Game::DuelProfiles.call([ @detail.card_season_id ])[@detail.card_season_id] unless @public`; `app/views/cards/show.html.erb` passes `duel_profile: @duel_profile` to `cards/detail`. The detail's card-season is the edition its "Prix moyen" reads.
- `app/views/cards/_detail.html.erb` -- after `</dl>` of `.card-detail__facts` (after ÉDITIONS and Steam reviews, before `cards/edition_sales`) render a new partial `app/views/cards/_duel_profile.html.erb` when `duel_profile` is present. Do not touch `cards/_public.html.erb`.
- `app/helpers/` -- a new `duel_profile_helper.rb` for the words (stronger side, rounded whole percent), raw values (number_with_delimiter, `l(date, format: :long_day…)` as `card_detail_pioneer_date` in `app/helpers/card_details_helper.rb` does) and the date line.
- `app/frontend/styles/tokens.css` -- add `--color-capsule-duel: #9ec3e6;` beside `--color-capsule-goal` (line ~41). New `app/frontend/styles/duel-profile.css` imported in `app/frontend/entrypoints/application.css` after `card-detail-public.css` (`card-detail.css` is at 423 of 500 lines); progress styling pattern `.set-row__bar` in `app/frontend/styles/hub-daily-sets.css:126`.
- `config/locales/en.yml`, `config/locales/fr.yml` -- a `duel_stats:` block (see Design Notes).
- Tests: `test/domains/game/` (operation, ranking, query, job, handler), `test/config/recurring_compute_duel_stats_test.rb`, `test/config/docker_entrypoint_test.rb`, a new `test/system/card_duel_profile_test.rb`, a request or view test if useful. Helpers: `test/support/catalog_seeds.rb` (`seed_card_seasons(..., review_counts:, ratings:, release_dates:)`), `test/support/game_packs.rb`, fixtures `test/fixtures/catalog/card_seasons.yml` (`portal_one`, epic, season `one`, no review_count), `test/system/card_average_price_test.rb` (visitor visiting `card_path`), `test/system/card_detail_test.rb` (player sign-in, set browse path), `test/domains/game/heal_banks_job_test.rb` (handler enqueue after commit). Never name a model in a test class body.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/<ts>_create_game_duel_stats.rb`, `db/schema.rb` -- create the table; regenerate schema from migrations -- storage
- [x] `app/domains/game/app/models/game/duel_stat.rb`, `duel_ranking.rb` -- model and pure ranking -- exact midrank, median, distances
- [x] `app/domains/game/app/operations/game/compute_duel_stats.rb` (+ measures query if split) -- compute and replace rows, rotation, trump, lock, event -- the one computation
- [x] `app/domains/game/app/events/game/duel_stats_computed.rb`, `jobs/game/compute_duel_stats_job.rb`, `handlers/game/handlers/season_published.rb` -- triggers
- [x] `app/domains/game/lib/tasks/game.rake`, `bin/docker-entrypoint`, `db/seeds.rb`, `config/recurring.yml` -- first run on deploy and in development, Mondays 00:00 UTC
- [x] `app/domains/game/app/queries/game/duel_profiles.rb` -- the one reader
- [x] `app/controllers/cards_controller.rb`, `app/views/cards/show.html.erb`, `_detail.html.erb`, new `_duel_profile.html.erb`, `app/helpers/duel_profile_helper.rb` -- DUEL block
- [x] `app/frontend/styles/tokens.css`, new `duel-profile.css`, `entrypoints/application.css` -- token and block styles per DESIGN
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- copy
- [x] tests listed in Code Map -- cover every matrix row, the job's lock, the handler enqueue after commit (and nothing on a failed publication), recurring in both blocks, entrypoint order, the rake task's idempotence, the system test

**Acceptance Criteria:**
- Given a run on fixture seasons, when a visitor (through a non-public detail path, e.g. a set or brother browse) and a signed-in player open a card's detail, then each reads the DUEL block with five stats in words, the ATOUT row and "Valeurs du <date>", and `visit card_path(slug:)` as a visitor (the public card page) shows no DUEL block.
- Given an empty `game_duel_stats`, when the web container boots, then `game:compute_first_duel_stats` runs after `game:backfill_achievements` and fills the table once; a second boot changes nothing.
- Given a season is published, when the publication commits, then `Game::ComputeDuelStatsJob` is enqueued with `"season"`.
- Given two runs started together, when both execute, then the second waits for the first's transaction (advisory lock held for the transaction).

## Implementation Notes

- The computation is split three ways: `Game::DuelMeasures` (one SQL read of every rated card-season of a published season), `Game::DuelStatRows` (pure: groups, rankings, trump, weekly carry-over) and `Game::DuelRanking` (pure midrank and median distance of one group); `Game::ComputeDuelStats` only locks, replaces and publishes.
- Exactness: keys and measures are Integers, Dates as Julian days and discovery times as `Time#to_r`; the percentile is a Rational rounded half up to tenths, stored as BigDecimal.
- The weekly carry-over is per row: a `first`/`weekly` run copies the previous row's percentiles as they were, nil included (a stat that had no value last week has no weekly percentile).
- Copy: raw counts interpolate `%{number}` (delimited) beside `count` for the plural, as `card_details.steam_reviews` does; the plan's `%{count}` would print undelimited figures. `errors.game.unknown_reason` added in both locales for the failure code.
- The DUEL heading is an `h2`; a stat without a value shows its name and "No value", no bar and no words.
- The development database still needs `bin/rails db:migrate` (only the test database was rebuilt to regenerate the schema).

## Plan Change Log

## Review Triage Log

### 2026-11-15 — Review pass
- verification (before review): `bin/ci`'s schema round trip showed the `IN (...)` trump checks dump differently after a schema load (`ANY (ARRAY[...]::text[])` vs `ARRAY[...::text]`); the migration now writes them as OR comparisons and the regenerated `db/schema.rb` round-trips unchanged.
- verdicts: 39 findings — high 0, medium 5, low 18, false 16, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) The concurrency test cannot tell whether the waiting run read the first run's committed rows; its probe counts any advisory lock of the cluster — test now overwrites a percentile in the first run before release and asserts the waiting weekly run carried it; probe restricted to this lock key and database.
  - `[low]` `[patch]` (verification-gap, other) `package-lock.json` churn (dev flags dropped) from a local `npm install` — reverted, not part of the commit.
  - `[low]` `[reject]` (edge-case) A stat with no previous percentile carries a nil weekly percentile — the plan's carry-over says the previous row's percentiles; nil honestly means no comparison; pinned by a new test (see blind-hunter nil carry-over row).
  - `[medium]` `[patch]` (edge-case) A top or bottom card of a group of 100+ (percentile >= 99.5 or <= 0.5) reads "More popular than 100% of cards" — whole percent capped at 99 in `duel_stat_words`, helper test added.
  - `[false]` `[reject]` (edge-case) Implicit else in `duel_stat_value` renders blank — the stat names are the fixed `DuelStat::STATS`; no other name reaches the helper.
  - `[low]` `[reject]` (edge-case) With no published season the boot task reruns a zero-row "first" run each boot — production and staging have published seasons; no subscriber hears the event yet.
  - `[low]` `[reject]` (edge-case) Two web containers booting together on an empty table both run "first" — the advisory lock serialises them, the second recomputes the same values; one web container boots per deploy.
  - `[medium]` `[patch]` (edge-case) Concurrency probe not tied to this lock — same root cause as the verification-gap row; same fix.
  - `[low]` `[patch]` (blind-hunter) `package-lock.json` churn — same root cause as the verification-gap row; reverted.
  - `[low]` `[reject]` (blind-hunter) Circulation counts banned players' holdings — the story's measure is "distinct holders with a positive quantity"; deleted players' holdings are already deleted by `ReleasePlayer`; banned holders are rare and the fix adds a join and a rule the intent does not state.
  - `[false]` `[reject]` (blind-hunter) The words overclaim because the midrank counts the card itself half — the midrank with equal values counting half is the rule of `duel-rules.md` and the story; the words carry that percentile.
  - `[false]` `[reject]` (blind-hunter) "of cards" while ranked within one season — the Copy deck's words ("des cartes") and the rule's per-season catalog; not a code defect.
  - `[low]` `[reject]` (blind-hunter) The boot task can block the server boot — the story places the first run in the entrypoint beside the achievements backfill, which already runs synchronously the same way.
  - `[medium]` `[patch]` (blind-hunter) Concurrency probe — same root cause as the verification-gap row; same fix.
  - `[low]` `[reject]` (blind-hunter) After a mid-week season run, the next Monday's last weekly percentiles are the season run's, not last Monday's — the row holds one set of previous percentiles; keeping last Monday's across a season run needs a second set of columns; seasons are published a few times a year. Residual risk noted in the result.
  - `[low]` `[patch]` (blind-hunter) The nil carry-over has no test — test added: a weekly run after a row with no discovery percentile stores a nil discovery weekly percentile.
  - `[false]` `[reject]` (blind-hunter) The schedule's time zone differs from the verdict job's — `config.time_zone` is unset (UTC), so both run in UTC; the new one says so explicitly.
  - `[low]` `[patch]` (blind-hunter) The stream name "Game::DuelStats" breaks the `Pack::Name$part` pattern — renamed "Game::DuelStats$computed".
  - `[low]` `[reject]` (blind-hunter) Progress-bar CSS copied a fourth time — extracting a shared bar class touches three unrelated screens; no user harm.
  - `[false]` `[reject]` (blind-hunter) "Plus introuvable que" is awkward — the Copy deck's direction is "LA PLUS INTROUVABLE" and board 9 writes "Plus introuvable que".
  - `[false]` `[reject]` (blind-hunter) "%{percent} positives" lacks a noun — board 9 writes "91 % positives".
  - `[low]` `[reject]` (blind-hunter) English `duel_stats.rarities` duplicates `catalog.rarity` — French needs its own plural adjectives; one key family for both locales keeps the template single.
  - `[low]` `[reject]` (blind-hunter) The view compares `trump_stat` itself instead of `Profile#trump`; the controller repeats the id — cosmetic.
  - `[false]` `[reject]` (blind-hunter) Delete and re-insert every row — the story says the run replaces every row in one transaction; no reader references row ids.
  - `[false]` `[reject]` (intent) One at a time in the operation, not the job — the job only calls the operation, so two jobs serialise on its lock; the concurrency test shows the wait.
  - `[low]` `[reject]` (intent) After commit comes from the app-wide `enqueue_after_transaction_commit` — the same setting and test pattern as `HealBanksJob`; a failed publication enqueues nothing (tested).
  - `[low]` `[reject]` (intent) Weekly rotation reading B3 vs B2 — same root cause as the blind-hunter mid-week season row.
  - `[false]` `[reject]` (intent) Percentile reading A1 vs A2 — duel-rules: equal values counting half (midrank), the card's own value among the ranked ones.
  - `[low]` `[defer]` (intent) No tribute exclusion — no season kind or tribute season exists yet (exotic cards parked); deferred to whoever adds the tribute season.
  - `[false]` `[reject]` (intent) The Archives exclusion is only structural — entrusted copies leave `game_holdings`; the test shows a deposit counts nothing.
  - `[medium]` `[patch]` (intent) The system test reads words for three stats, not five — portal_one given a review count and a discovery; all five rows' words and values asserted for the player and the visitor.
  - `[false]` `[reject]` (intent) Release raw value as a full date vs the Copy deck's year — board 9, named by the story, draws "22 juin 1996"; the exact value is a date.
  - `[false]` `[reject]` (intent) Strings beyond the Copy deck — the words for every direction follow its single example; "No value" covers the plan's no-value state; the failure key is required by AGENTS.md.
  - `[low]` `[reject]` (intent) Block after the facts list (after Steam reviews) rather than directly after ÉDITIONS — DESIGN places it as one more group of fact rows after ÉDITIONS; splitting the list for one row is not worth it.
  - `[false]` `[reject]` (intent) A pulled edition nobody holds now has no circulation value — duel-rules ranks circulation among editions at least one player holds.
  - `[false]` `[reject]` (intent) Measures read from Catalog tables with Game SQL — Game → Catalog is an allowed dependency and other Game queries read Catalog tables the same way.
  - `[false]` `[reject]` (intent) The draft and unrated exclusions — matches the intent; tested.
  - `[false]` `[reject]` (intent) Copy deck direction labels unused — they belong to the deck editor and duel stories.
  - `[low]` `[patch]` (intent) Package-lock outside intent — same root cause as the verification-gap row; reverted.

## Design Notes

DUEL block (DESIGN.md Duels › Duel profile; mock board 9): a `<section class="duel-profile" aria-labelledby=…>` after the facts, background `--color-panel-sunken` like the fact rows; heading "Duel" in the fact label style (muted, uppercase via CSS). Five rows in STATS order, each: line 1 the stat name (muted) and, for the trump, a tag "Atout" (uppercase by CSS, 1px `--color-capsule-duel` outline, `--color-capsule-duel` text) — left; the raw value — right, in `--color-text`. Line 2: `<progress class="duel-profile__bar" max="100" value="<percentile>" aria-hidden="true">`, 8px, track `--color-panel-raised` with 1px `--color-line-deep` edge, fill `--color-accent`, the trump's fill `--color-text-max`. Line 3: the words in `--color-text` (trump row `--color-text-max`). Last line "Valeurs du <date>" muted, date of `computed_at` in words as the pioneer date (`card_details.pioneer.dated` pattern, `:long_day` / `:long_day_first`). A stat with no value: name, no bar, "Aucune valeur" / "No value" in place of words and raw value (assumption: no copy exists for it).

Words name the stronger side: percentile p ≥ 50 → first direction with `p.round`; else second direction with `(100 − p).round` (mock: bar 12 → "Plus confidentielle que 88 % des cartes").

Copy (`duel_stats:` in both locales; French typography: narrow no-break space before `%` as the repo's french_typography test demands — check `test/config/french_typography_test.rb`):
- heading "Duel"/"Duel"; trump "Atout"/"Trump"; dated "Valeurs du %{date}"/"Values of %{date}"; no_value "Aucune valeur"/"No value".
- names: Popularité/Popularity, Note/Rating, Sortie/Release, Découverte/Discovery, Circulation/Circulation.
- words high/low: popularity "Plus populaire que %{percent} des cartes"/"More popular than %{percent} of cards", "Plus confidentielle que …"/"More obscure than …"; rating "Mieux notée que …"/"Better rated than …", "Moins bien notée que …"/"Worse rated than …"; release "Plus récente que …"/"Newer than …", "Plus ancienne que …"/"Older than …"; discovery "Découverte avant %{percent} des cartes"/"Discovered before %{percent} of cards", "Découverte après …"/"Discovered after …"; circulation "Plus répandue que %{percent} des cartes %{rarity}"/"More widespread than %{percent} of %{rarity} cards", "Plus introuvable que …"/"Harder to find than …", with rarity adjectives (fr plural lowercase: communes, peu communes, rares, épiques, légendaires; en: Common, Uncommon, Rare, Epic, Legendary).
- raw values: popularity "%{count} avis"/"%{count} reviews" (plural keys, fr with zero); rating "%{percent} positives"/"%{percent} positive"; release and discovery dates in words; circulation "%{count} joueurs"/"%{count} players" (plural, zero).

Rotation reading: "last weekly percentiles" are what the arrows and the Monday entry compare with; a season run between two Mondays leaves them alone, so the next Monday compares with the values the row held before it.

## Verification

**Commands:**
- `docker compose up -d` then `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb` -- schema regenerated; `git diff db/schema.rb` shows only the new table
- `bin/rails test test/domains/game test/config test/controllers test/requests` (the dirs that exist) -- expected: green
- `bin/rails test test/system/card_duel_profile_test.rb` and `bin/rails test test/system/card_detail_test.rb test/system/card_average_price_test.rb` -- expected: green
- `bin/ci` -- expected: all steps green
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes` -- expected: green

## Auto Run Result

**Summary:** every rated card-season of a published season now has a stored duel profile in `game_duel_stats`. Each of the five stats has its value, a midrank percentile, its distance from the median and its last weekly percentile, plus a trump. `Game::ComputeDuelStats` computes them under an advisory lock and replaces the whole table in one transaction. It publishes `Game::DuelStatsComputed` and is run by `Game::ComputeDuelStatsJob`. Four things trigger it: the deploy entrypoint when the table is empty, the development seeds, a season publication, and every Monday at 00:00 UTC. `Game::DuelProfiles` is the one reader. The card detail shows a DUEL block after the facts to players and to visitors coming through a browse path; the public card page shows none.

**Files changed**
- `db/migrate/20261115100000_create_game_duel_stats.rb`, `db/schema.rb`: the table and its checks; the schema is regenerated from the migrations and round-trips.
- `app/domains/game/app/models/game/duel_stat.rb`, `duel_ranking.rb`, `duel_stat_rows.rb`: the model, the pure midrank and median ranking, and the rows with their trump and weekly carry-over.
- `app/domains/game/app/queries/game/duel_measures.rb`, `duel_profiles.rb`: what the stats rank, and the one reader.
- `app/domains/game/app/operations/game/compute_duel_stats.rb`, `events/game/duel_stats_computed.rb`, `jobs/game/compute_duel_stats_job.rb`, `handlers/game/handlers/season_published.rb`: the computation, its event, its job and the season trigger.
- `app/domains/game/lib/tasks/game.rake`, `bin/docker-entrypoint`, `db/seeds.rb`, `config/recurring.yml`: the first run on deploy and in development, and the Monday run.
- `app/controllers/cards_controller.rb`, `app/views/cards/show.html.erb`, `_detail.html.erb`, `_duel_profile.html.erb`, `app/helpers/duel_profile_helper.rb`: the DUEL block.
- `app/frontend/styles/tokens.css`, `duel-profile.css`, `entrypoints/application.css`: the `--color-capsule-duel` token and the block's styles.
- `config/locales/en.yml`, `fr.yml`: the duel stats copy and `errors.game.unknown_reason`.
- Tests: the operation, ranking, query, job/handler/rake, concurrency, helper, recurring, entrypoint and cards controller budgets, and the system test `test/system/card_duel_profile_test.rb`.

**Review:** 39 findings: 5 medium, 18 low, 16 false. The fixes cover 3 distinct medium problems and 4 distinct low ones:
- Medium:
  - The concurrency test now shows that the waiting run reads the first run's committed rows, and its probe is tied to this lock.
  - The words are capped at 99 %, so a card is never "more … than 100 % of cards".
  - The system test asserts all five stats in words.
- Low:
  - The nil weekly carry-over now has a test.
  - The stream is renamed `Game::DuelStats$computed`.
  - The `package-lock.json` churn is reverted.
  - The schema round trip is fixed (found by `bin/ci` before review).
- Deferred: the tribute-season exclusion, plus a pre-existing failing library test logged in `deferred-work.md`.
- Rejected: the rest, each with its reason in the triage log.

**Follow-up review recommended:** true. This first pass fixed 3 distinct medium problems; the triage log counts 5 medium rows because the probe problem was reported by three lenses. The risk nobody has checked is the first deploy's computation over the production catalogue (about 12k card-seasons per season, all in memory, in one transaction, inside the boot entrypoint): it has not been timed against production-sized data.

**Verification:**
- `bin/ci` passed these steps: rubocop, packwerk, `i18n-tasks missing`, typecheck, markup, format, CSS lint, planning refs, file sizes, bundler-audit, brakeman, schema built from the migrations, and seeds.
- `bin/ci` failed three steps:
  - Setup, because the local development database refuses an earlier migration (`20261114170001`) over its existing rows. This is local data and has nothing to do with this change.
  - The schema round trip, before the fix. After the fix I ran it by hand and the schema came back unchanged.
  - The Rails suite: 5568 runs, 1 failure. It is the pre-existing `library_controller_test.rb:119` from `f22bf3b7`, and it is deferred.
- `npm run test:js`: 1388 passed.
- `bin/rails zeitwerk:check`: all good.
- System tests `card_duel_profile`, `card_detail` and `card_average_price`: 9 runs, 0 failures.

**Residual risks:**
- After a season publication between two Mondays, the next Monday's last weekly percentiles are the season run's values, not the previous Monday's, because a row holds only one previous set. Seasons are published a few times a year.
- On the card detail, a stat with no value reads "No value" / "Aucune valeur". This copy is an assumption, not in the Copy deck.
- Banned players' holdings count toward circulation.
- The local development database needs `bin/rails db:migrate`, and its earlier migration error must be fixed first.
