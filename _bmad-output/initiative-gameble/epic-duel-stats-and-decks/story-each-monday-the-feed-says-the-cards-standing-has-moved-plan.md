---
title: "Each Monday the feed says the cards' standing has moved"
type: 'feature'
ticket: '6'
created: '2026-11-15'
status: 'built'
baseline_revision: 'ad7a35b8a96e5df49b121f8cebc741ef6f17828b'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred:
  - summary: >-
      After a season publication between two Mondays, the Monday post compares with the season run's percentiles, not the previous Monday's.
    evidence: |-
      Game::DuelStatRows rotates the last weekly percentiles on every non-season run from the previous row's percentiles, which a mid-week season run has replaced; the post reads the stored weekly percentiles (Game::DuelProfiles.weekly_changes). A second set of columns in game_duel_stats would keep last Monday's values; seasons are published a few times a year. Pre-existing in the rotation, already a residual risk of the duel profile story.
    location: >-
      app/domains/game/app/models/game/duel_stat_rows.rb
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The weekly duel stats run (`Game::ComputeDuelStats`, reason `weekly`) changes every card's percentiles, but nobody hears of it: the Brotherhood feed should say each Monday which cards moved most.

**Approach:** Four expand/contract migrations let `game_feed_entries` hold a `duel_stats` entry with no player and its moved cards (jsonb); a feed handler on a weekly `Game::DuelStatsComputed` picks, per card, its largest single-stat change against the last weekly percentiles and inserts one entry per week (ON CONFLICT DO NOTHING) with the three largest rises and three largest falls; the feed queries and views handle an entry with no player and draw it as the Chattomètre's weekly entry is, with up to six rows.

## Boundaries & Constraints

**Always:**
- Migrations (strong_migrations, one concern each, OR comparisons in checks, never `IN (...)`, so `db/schema.rb` round-trips): (1) add `moves` jsonb, nullable; (2) `change_column_null :player_id, true`; replace `game_feed_entries_kind_check` with `duel_stats` added, and `game_feed_entries_set_check` with `kind = 'duel_stats'` beside `set` and `verdict` in its card_season_id/rarity clauses, both `validate: false`; add `game_feed_entries_duel_stats_check` `"(kind = 'duel_stats') = (player_id IS NULL) AND (kind = 'duel_stats') = (moves IS NOT NULL)"`, `validate: false`; (3) validate the three checks; (4) `disable_ddl_transaction!`, `add_index :game_feed_entries, :occurred_at, unique: true, where: "kind = 'duel_stats'", name: "index_game_feed_entries_one_duel_stats_per_week", algorithm: :concurrently`. Timestamps `20261115160000`–`20261115160003`.
- A week's entry has `occurred_at` = Monday 00:00 UTC of the week of the event's time (`event.metadata[:timestamp] || Time.current`), as the verdict's week start does.
- A card's move: over all its card-seasons (rows of `game_duel_stats` sharing `catalog_card_seasons.card_id`) and the five stats, the change `percentile − weekly_percentile` of largest magnitude, stats where either side is NULL skipped, a zero change is no move. Ties: earlier stat in `Game::DuelStat::STATS` order, then lower card_season_id. Rises: positive moves, largest first, three at most; falls: negative moves, largest magnitude first, three at most; equal moves ordered by card_season_id. A card is a rise or a fall, never both.
- The comparison reads the stored `<stat>_weekly_percentile` after the weekly run's rotation (so the first Monday compares with the deploy's `first` run, and the editor's later arrows compare with the same week); the stats are read only through `Game::DuelProfiles` (add a method there); nothing computes a percentile.
- `moves` holds, rises then falls, `{ "card_season_id", "stat", "from", "to" }` with from/to as one-decimal Floats. No row → no entry that week (an empty "has moved" would be false).
- Feed: shows under TOUS + TOUT (no filter), never under AMIS (no player, so `where(player_id: friends)` already leaves it out) or a kind filter, never in the ticker (`LiveStream::TICKER_KINDS` unchanged). Like the verdict, the hub feed block, the public card page's LIVE strip and the landing's LIVE module show its line alone (`links: false` sentence or non-post sentence, no rows, no tag).
- Drawing in the feed (post mode): no byline, no thumbnail, no tag, no reaction bar; headline kicker "Duel" and title "Le cours des cartes a bougé." / "The cards' standing has moved."; then a list of up to six rows "Quake, popularité en hausse, de 55 à 62" / "Quake, popularity up, from 55 to 62", the card's name a `feed__game` link to `card_season_path(slug:, number:)` of the moved edition, percentiles rounded to whole numbers; no arrow, no colour for rise/fall. No `style` attribute, every string in both locales.
- An entry with no player passes the feed's visibility (`Game::FeedEntries` `visible` and `titled`, `Game::VisibleFeedEntry`) and is never shown for a nil player of any other kind.

**Never:** no change to `Game::Visibility.visible?` (a nil owner stays hidden); no live broadcast of the entry (it appears on the next feed render); no entry from a `first` or `season` run; no new pixel art or decor; no planning ids; no write outside the handler; no change to `Game::ComputeDuelStats`'s rotation.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Weekly run | rows whose percentiles differ from their weekly ones | one `duel_stats` entry, player NULL, `occurred_at` the week's Monday 00:00 UTC, moves = 3 rises then 3 falls | — |
| Second weekly run same week | entry exists | still one entry, unchanged | ON CONFLICT DO NOTHING |
| First / season run | any | no entry | — |
| Largest single stat | card A: popularity +3, rating −8 | A is a fall, rating, its from/to | — |
| Two editions of one card | edition 1 popularity +5, edition 2 circulation +12 | one move for the card: edition 2, circulation | — |
| First Monday | `first` run, catalog changes, `weekly` run | moves compare with the `first` run's percentiles | — |
| NULL side | discovery weekly NULL, percentile 40 | discovery not considered | — |
| Nothing moved | all changes zero | no entry | — |
| Fewer than six | two rises, no fall | entry with two rows | — |
| Check | insert a `pull` (or any non-duel_stats) with NULL player, or a duel_stats with a player or without moves | refused by the database | `ActiveRecord::StatementInvalid` |
| Feed with no-player entry | TOUS, TOUT, page and newer pages, jump target by token | entry listed; AMIS and kind filters never list it; ticker never | — |

</intent-contract>

## Code Map

- `db/migrate/20261110160000_add_sale_to_game_feed_entries.rb`, `…160001…`, `…160002…`, `20261109100002_add_one_verdict_per_week_index_to_game_feed_entries.rb` -- patterns to copy (check replacement with old expression, validate, concurrent partial unique index). Current checks: `db/schema.rb` `create_table "game_feed_entries"`.
- `app/domains/game/app/models/game/feed_entry.rb` -- `KINDS` gains `duel_stats`; add `record_duel_stats(moves:, week_start:, now:)` beside `record_verdict` (`insert_all([row], unique_by: :index_game_feed_entries_one_duel_stats_per_week, record_timestamps: false)`, `notable: true`).
- `app/domains/game/app/queries/game/duel_profiles.rb` -- the one reader of `game_duel_stats`; add e.g. `weekly_changes`: one pluck joining `catalog_card_seasons` for `card_id`, returning per row and stat a Data (card_season_id, card_id, stat, from, to) for stats with both sides present.
- new `app/domains/game/app/models/game/duel_stat_moves.rb` -- pure: changes → rises and falls per the rules (unit-test without DB where possible).
- new `app/domains/game/app/handlers/game/handlers/duel_stats_feed.rb` -- pattern `weekly_verdict_feed.rb`; returns early unless `event.data.fetch(:reason) == "weekly"` (data keys are symbols; reason a String).
- `config/initializers/event_store.rb` -- `event_store.subscribe(Game::Handlers::DuelStatsFeed, to: [ Game::DuelStatsComputed ])` beside `WeeklyVerdictFeed`, with a one-line comment as its neighbours.
- `app/domains/game/app/queries/game/feed_entries.rb` -- `visible`: an entry with `player_id.nil?` needs no player check (the DB check guarantees only duel_stats); `titled`: `titles[it.player.id]` only when `it.player`. `notable`/`listed` need nothing (`where(player_id: players)` excludes NULL). `new_feed_entries.rb` selects by pack, trade, repost, set or listing only, so it never meets a duel_stats entry: leave it.
- `app/domains/game/app/queries/game/visible_feed_entry.rb` -- already lists an entry with no owners (`[].all?`); cover it by a test, change nothing unless the test fails.
- `app/models/feed_items.rb` -- for `duel_stats`: resolve the moves' card_season_ids with the same `Catalog::CardViews` lookup (add them to the ids collected), yield `[ item, nil, nil, nil, moves ]` where moves is a list of Data (card view, stat, from, to, rose?) with unresolved cards dropped; skip the entry when none resolves. Other kinds keep their 4-tuples (block destructuring ignores the 5th).
- `app/helpers/feed_helper.rb` -- `feed_sentence` and `feed_headline_parts` branches for `duel_stats`; a helper rendering the moves list (`tag.ul class: "feed__moves"`, rows `feed__move`), card link `card_season_path(slug: card.id, number: card.season_number)` with `class: "feed__game", data: { turbo_prefetch: false }`.
- `app/views/feeds/_entry.html.erb` -- `duel = item.entry.kind == "duel_stats"`: class `feed__entry--duel-stats` (plus `feed__entry--set` for the no-thumb grid), byline only `if post && item.player`, no thumbnail, moves list after `.feed__head` when `post` and `local_assigns[:moves]`, no tag (empty `.feed__tags` hides itself), no reactions.
- `app/views/feeds/show.html.erb`, `show.turbo_stream.erb` (two loops) -- destructure `|item, card, partner_card, set, moves|` and pass `moves:`. `app/views/shell/_live_strip_body.html.erb` -- a `duel_stats` branch with no tag before the `else` (which reads `card.rarity`). Landing (`landings/_live.html.erb`) renders non-post: sentence only, nothing to change beyond the partial.
- `app/frontend/styles/feed-post.css` (296 lines) -- `.feed__entry--duel-stats` grid areas: headline + time, then a `moves` area (all three container widths); `.feed__moves` / `.feed__move` in `{typography.body}` `--color-text`, link as `.feed__game`. Outside the feed container `.feed__moves` stays hidden like the byline/headline.
- `config/locales/en.yml`, `fr.yml` -- under `feeds.show`: `headline.duel_stats` ("Duel"), `duel_stats` ("Le cours des cartes a bougé." / "The cards' standing has moved."), `duel_stats_rose_html` / `duel_stats_fell_html` ("%{card}, %{stat} en hausse, de %{from} à %{to}" / "%{card}, %{stat} up, from %{from} to %{to}"; "en baisse" / "down"), `duel_stats_stats.<stat>` lowercase names (popularité, note, sortie, découverte, circulation / popularity, rating, release, discovery, circulation). Check `test/config/french_typography_test.rb`.
- Tests: `test/domains/game/feed_test.rb` (patterns for entries, visibility, pages), `test/domains/game/compute_duel_stats_test.rb` (`published_card_seasons`, `compute`), `test/domains/game/publish_weekly_verdict_job_test.rb` (handler in transaction), `test/controllers/feeds_controller_test.rb`, `test/system/market_feed_test.rb` (feed + ticker assertions), `test/support/catalog_seeds.rb`. Never name a model in a test class body.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261115160000…160003_*.rb`, `db/schema.rb` -- the four migrations; regenerate the schema from migrations on the worktree's test DB; diff shows only these changes
- [x] `feed_entry.rb`, `duel_profiles.rb`, new `duel_stat_moves.rb`, new `handlers/duel_stats_feed.rb`, `config/initializers/event_store.rb` -- moves and the weekly entry
- [x] `feed_entries.rb` -- no-player entries visible and titled
- [x] `feed_items.rb`, `feed_helper.rb`, `feeds/_entry.html.erb`, `feeds/show.html.erb`, `feeds/show.turbo_stream.erb`, `shell/_live_strip_body.html.erb`, `feed-post.css` -- drawing
- [x] `config/locales/en.yml`, `fr.yml` -- copy
- [x] tests -- migration/check tests (each refused insert in the matrix), handler tests (every matrix row: one per week whatever the runs, none from first/season, largest single stat, two editions, first Monday vs deploy run, NULL side, nothing moved), query tests (`FeedEntries.page`/`newer` and `call` with a no-player entry for a visitor and a player, AMIS and a kind filter excluding it, `VisibleFeedEntry` by its token), a helper or controller test of the rows' words and links in both locales, and the system test `test/system/duel_stats_feed_test.rb`

**Acceptance Criteria:**
- Given a published season whose cards' ranks change between a `first` and a `weekly` run, when a visitor opens the feed in French, then TOUS shows "Le cours des cartes a bougé." with three rises and three falls, each the card's name linked to its edition's page with the stat and both percentiles in words, while AMIS (signed-in player) and the hub ticker never show it.
- Given the migrations on a database holding feed entries of every kind, when they run, then every check validates and `db/schema.rb` regenerated from the migrations round-trips unchanged.

## Implementation Notes

- The handler dates the post with `Game::WeeklyGoal.week_start` (Monday 00:00 UTC), the verdict's week.
- `Game::FeedEntries` lets an entry with no player through only when its kind is `duel_stats` (`owner_shown?`); `VisibleFeedEntry` and `NewFeedEntries` are unchanged (the first already lists an entry with no owners, the second never selects one).
- `compute_duel_stats_concurrency_test.rb` commits a real weekly run, so its teardown now deletes the `duel_stats` posts it leaves behind.
- After review, a change whose percentiles round to the same whole number is no move (so a row never reads "de 50 à 50"), and on the phone each moved card's row is 44px tall so its link's tap zone stays its own.

## Plan Change Log

## Review Triage Log

### 2026-11-15 — Review pass
- verdicts: 33 findings — high 0, medium 4, low 21, false 8, maybe-false 0
- findings:
  - `[medium]` `[patch]` (blind-hunter) On the phone each `.feed__game`'s 44px tap zone overlaps the next row's link (rows 25px apart) — `@media (max-width: 719px)` gives `.feed__move` a 44px pitch with no gap.
  - `[low]` `[patch]` (blind-hunter) A sub-point change reads "de 50 à 50" — a change whose percentiles round to the same whole number is no move in `DuelStatMoves`; tested.
  - `[medium]` `[defer]` (blind-hunter) A mid-week season run moves the baseline of the next Monday's post — pre-existing in the duel profile story's rotation; deferred (frontmatter and `deferred-work.md`).
  - `[low]` `[reject]` (blind-hunter) Post backdated to Monday 00:00 is buried if the run is late — the run is scheduled at Monday 00:00 UTC, as the verdict's own backdated entry; changing the key needs another column.
  - `[low]` `[reject]` (blind-hunter) Feed stat names copy `duel_stats.names` — the sentence needs lowercase mid-sentence forms; separate keys keep each locale's grammar.
  - `[false]` `[reject]` (blind-hunter) "Up/down" means nothing for some stats — the intent prescribes the wording ("popularité en hausse, de 55 à 62"), and a percentile is always toward the stat's first direction.
  - `[low]` `[reject]` (blind-hunter) A crafted POST can react to the post — the verdict behaves the same; `ReactionNotices` sends nothing for an entry with no owner; a guard adds a branch for a request no screen sends.
  - `[low]` `[reject]` (blind-hunter) The post borrows `feed__entry--set` then overrides it — cosmetic; `--duel-stats` sets every grid template it needs.
  - `[low]` `[reject]` (blind-hunter) Empty `elsif` branches — they keep the tag-less kind out of the `card.rarity` branch, as the plan says; cosmetic.
  - `[low]` `[reject]` (blind-hunter) The `moves` hash format lives in two layers — one writer, one reader; a shared reader adds surface for no named failure.
  - `[low]` `[reject]` (blind-hunter) The preview line links nowhere — the plan draws the previews' line alone; the strip has no links by design.
  - `[low]` `[reject]` (blind-hunter) The database accepts `moves = '[]'` — the handler is the only writer and never writes an empty list; tested.
  - `[low]` `[reject]` (blind-hunter) `weekly_changes` works in Ruby inside the lock — a weekly job; the timing over production data is the duel profile story's open follow-up risk.
  - `[false]` `[reject]` (blind-hunter) Small circulation groups crowd the post — the stat's percentile per tier is the duel rules' definition and the intent ranks raw percentile changes.
  - `[low]` `[patch]` (blind-hunter) No turbo-stream page renders a duel post — same root cause as the verification-gap turbo-stream row; test added.
  - `[low]` `[patch]` (blind-hunter) The ticker assertion passes on an empty ticker — same root cause as the verification-gap/intent ticker row; a friend's pull now shows in the ticker first.
  - `[low]` `[patch]` (edge-case) "from 55 to 55" — same root cause as the blind-hunter rounding row; patched there.
  - `[low]` `[reject]` (edge-case) Reactions by token on the post — same as the blind-hunter reactions row.
  - `[false]` `[reject]` (edge-case) A stored stat that leaves `STATS` breaks old posts — no stat is renamed; the five stats are fixed by the duel rules.
  - `[medium]` `[defer]` (edge-case) Season run between Mondays shifts the baseline — same root cause as the blind-hunter season row; deferred.
  - `[low]` `[patch]` (verification-gap) `show.turbo_stream.erb`'s `moves:` untested — controller test on the appended older page and the prepended newer page.
  - `[low]` `[patch]` (verification-gap) No test for a post whose cards all fail to resolve — controller test added: no post drawn.
  - `[low]` `[patch]` (verification-gap) The edition tie-break by card-season id is untested — unit test with one card, two editions, equal opposite changes.
  - `[low]` `[reject]` (verification-gap, other) Reactions accepted by token — same as the blind-hunter reactions row.
  - `[medium]` `[defer]` (intent) Baseline is the stored column, not the previous weekly run — same root cause as the blind-hunter season row; deferred.
  - `[false]` `[reject]` (intent) Card names link to `card_season_path` not `card_path` — "its page": the moved edition's page is the card's page showing the DUEL block that moved (plan decision).
  - `[low]` `[reject]` (intent) The previews (strip, landing) show the line — the intent excludes AMIS, other filters and the ticker by name; the verdict, also kept from the ticker, shows in the previews (plan decision, reported to the author).
  - `[low]` `[patch]` (intent) The ticker test may pass trivially — same root cause as the blind-hunter ticker row; patched.
  - `[false]` `[reject]` (intent) `NewFeedEntries` untouched — it selects by pack, trade, repost, set or listing only and never meets a `duel_stats` entry.
  - `[low]` `[reject]` (intent) Reaction and jump-target paths untested at page level — `VisibleFeedEntry` is tested by token for a visitor and a player; the jump only positions the page.
  - `[false]` `[reject]` (intent) "Duel" kicker, no tag, no arrow — the intent's "any arrow as text" allows none; the kicker is the plan's recorded assumption.
  - `[false]` `[reject]` (intent) Migrations never run over existing rows — every existing row has a player, no moves and another kind, so each widened or new check holds by construction; the schema built from the migrations matches.
  - `[false]` `[reject]` (intent) Links checked for two of six rows — every row is built by the same helper; the controller test checks both directions' links.

## Design Notes

Decisions the intent left open, taken here: a "card" is the game, so one row per card and the largest change across its editions, linked to the moved edition's page (`card_season_path`), which shows the DUEL block of that edition. The previews (hub feed block, LIVE strip, landing) show the line alone as they show the verdict: the ticket names only the ticker as excluded. No entry when nothing moved. The headline kicker "Duel" is new copy (assumption, reuses the DUEL block's word).

Row rendering example (fr): `<li class="feed__move"><a class="feed__game" href="/fr/cards/quake/seasons/1">Quake</a>, popularité en hausse, de 55 à 62</li>`.

## Verification

**Commands:** (with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w42_6`, `CHROME_BIN=/usr/bin/chromium`)
- Environment: work only in the git worktree `/home/teyermann/projets/gameble/.claude/worktrees/agent-a1b1a017a4646694b` (absolute paths; never the main checkout `/home/teyermann/projets/gameble`), export both variables above for every Rails command, never touch the development database, never run the whole system suite (it crashes the machine), do not commit. `test/controllers/library_controller_test.rb:119` already fails on the baseline.
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate db:schema:dump && cp tmp/migrated_schema.rb db/schema.rb`, then `git diff feature/duels -- db/schema.rb` -- only this story's changes
- `bin/rails test test/domains/game test/controllers test/helpers test/jobs test/models test/config` -- green except the known `library_controller_test.rb:119`
- `bin/rails test test/system/duel_stats_feed_test.rb test/system/market_feed_test.rb test/system/feed_reactions_test.rb test/system/landing_live_feed_test.rb` -- green
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes` -- green

## Auto Run Result

**Summary:** each weekly duel stats run now posts one feed entry of kind `duel_stats`, with no player, dated the week's Monday 00:00 UTC (one per week by a unique index, `ON CONFLICT DO NOTHING`). Per card (game), its move is its largest single-stat change across its editions against the stored last weekly percentiles; the post keeps the three largest rises then the three largest falls. A first or season run posts nothing, and neither does a week where nothing moved by a whole point. The feed draws it under TOUS + TOUT with the "Duel" kicker, "Le cours des cartes a bougé." and up to six rows ("Quake, popularité en hausse, de 55 à 62"), each card linked to its moved edition's page; AMIS, the kind filters and the ticker never show it; the hub feed block, the LIVE strip and the landing show its line alone, as they show the verdict.

**Files changed**
- `db/migrate/20261115160000`–`160003`, `db/schema.rb`: `moves` jsonb; nullable `player_id` with the kind, set and new duel_stats checks (not valid, then validated); the concurrent one-per-week index.
- `app/domains/game/app/models/game/feed_entry.rb`, `duel_stat_moves.rb`, `queries/game/duel_profiles.rb`, `handlers/game/handlers/duel_stats_feed.rb`, `config/initializers/event_store.rb`: the moves and the weekly post.
- `app/domains/game/app/queries/game/feed_entries.rb`: an entry with no player is listed (duel_stats only) and titled.
- `app/models/feed_items.rb`, `app/helpers/feed_helper.rb`, `app/views/feeds/_entry.html.erb`, `show.html.erb`, `show.turbo_stream.erb`, `app/views/shell/_live_strip_body.html.erb`, `app/frontend/styles/feed-post.css`: the drawing.
- `config/locales/en.yml`, `fr.yml`: the copy.
- Tests: `test/domains/game/duel_stats_feed_test.rb`, `duel_stat_moves_test.rb`, `test/system/duel_stats_feed_test.rb`, additions to `feeds_controller_test.rb`, `landing_page_test.rb`, `card_preview_tags_test.rb`, a teardown line in `compute_duel_stats_concurrency_test.rb`.

**Review:** 33 findings — 4 medium, 21 low, 8 false. Patched: 1 medium (phone tap zones of the moved cards' links) and 5 low (rows rounding to "de 50 à 50", and tests for the turbo-stream pages, a post whose cards are all gone, the edition tie-break and a non-empty ticker). Deferred: the mid-week season run shifting the next Monday's baseline (one root cause, reported by three lenses), pre-existing in the duel profile rotation. Rejected: the rest, each with its reason in the triage log.

**Follow-up review recommended:** false. One medium entry was patched on this first pass.

**Verification** (on `gameble_test_w42_6`):
- `bin/rails test test/domains/game test/controllers test/helpers test/jobs test/models test/config`: 3942 runs, 1 failure, the known `library_controller_test.rb:119`; the other directories (`bin channels components initializers integration lib mailers policies script`): 525 runs, 0 failures. A single whole-suite `bin/rails test` run hit "too many clients" on the Postgres shared with the parallel builds, so it was run in these two parts.
- System tests `duel_stats_feed`, `market_feed`, `feed_reactions`, `landing_live_feed`: 6 runs, 0 failures.
- `bin/ci` steps run one by one (its `bin/setup` step touches the development database, so it was skipped): rubocop, packwerk validate and check, `i18n-tasks missing`, typecheck, markup, format, CSS lint, planning refs, file sizes, bundler-audit, brakeman, the schema built from the migrations (identical) and its round trip (identical), seeds replant — all green. `npm run test:js` and `bin/rails zeitwerk:check` green.

**Residual risks:**
- A season run between two Mondays makes the next post compare with that run (deferred).
- The previews (hub feed block, LIVE strip, landing) show the post's line; a strict reading of "TOUS and TOUT only" would leave it out there.
- The "Duel" headline kicker is new copy, an assumption.
- A late weekly run (retried days later) posts under the week's Monday, so the post sits below newer entries.
