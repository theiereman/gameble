---
title: 'A wave of achievements read from data the game already keeps'
type: 'feature'
ticket: ''
created: '2026-11-16'
status: 'built'
baseline_revision: 'e86edd9bfe178b920986050a6e1c16cb087a471d'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 1
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The author wants many more achievements: higher tiers of the capsule, repost and trade ones, and new ones for PiCoins, friends, reactions, the showcase, the Archives, the Chattomètre and custom sets. All of them can be read from tables the game already writes.

**Approach:** Add 32 catalogue entries. Each entry is an existing metric with a new threshold, or a new metric that reads existing tables. Re-check them on the events that move those numbers, plus a weekly fan-out after the Monday verdict. Every entry gets en/fr strings in the catalogue's corporate deadpan and a 7×7 glyph.

## Boundaries & Constraints

**Always:** A metric is one SQL subquery in `AchievementProgress::METRIC_SQL`, except where a rule already lives in Ruby (the ranking's `Fortune.listed`). Only completed Chattomètre weeks count (`week_start < WeeklyGoal.week_start(now)`), so a week still in play never grants. Strings go in both locales; pixel files come from `node script/pixel_art/export.mjs`. The deploy entrypoint's `game:backfill_achievements` grants what history already meets, without a toast.

**Decisions (author, 2026-11-16):** PiCoins held = wallet `available + committed`. Reactions given = a player's current reactions; one per post, so this is the total of posts reacted to. "Showcase cleared" = an empty showcase while the "showcase full" achievement is already earned. Chattomètre streaks are consecutive calendar weeks; a week without capsules breaks them. `delivered_on_schedule` stays even though it is farmable: "a custom set earns nothing" now covers tiers, feed and backs, and `custom_set_earns_nothing_test.rb` is narrowed to match. The plan stays whole at about 2700 tokens.

**Never:** No migration, no new table, no new event type. No card back or avatar reward. Nothing from the deferred lots (goals, avatar changes, link clicks, profile visits, Discord, code contribution).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected |
|----------|--------------|----------|
| Bids count as held | 40k available + 10k committed | `picoins_held` = 50 000 |
| Own-post reaction | Player reacts to their own pull | self-reaction met; the reactor is re-checked once (deduped with the author) |
| Author of a reacted entry | 10th reaction lands on a player's entry | the author is re-checked; an entry without a player (`duel_stats`) re-checks no one |
| Cleared before filling | Empty showcase, never full | `showcase_cleared_after_full` = 0 |
| Alone in the week | Only one ranked player last week | not counted as last |
| Last-place tie | Two lowest at the same `z_score` | last = the one `ranked` puts last (`player_id` desc) |
| Gap in streak | +, +, no capsules, + | longest lucky streak = 2 |
| Week in play | 2 completed + weeks and the current one + | 2 |
| Library set | Steam-library set of 40 games | not a custom set; ignored |
| Fan-out | Monday verdict job, with or without a public winner | one grant job per player with a fortune row last week |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/achievements.rb` -- `CATALOGUE` (append; the tests pin the first 30 in order).
- `app/domains/game/app/queries/game/achievement_progress.rb` (228 lines, limit 400) -- `METRIC_SQL`, `longest_run_sql` (reuse for the streaks), and `STUDIO_METRIC` as the pattern for a Ruby-side metric.
- `app/domains/game/app/handlers/game/handlers/achievements.rb` -- the `EVENTS` map from event to player keys.
- `app/domains/game/app/operations/game/react_to_feed_entry.rb` -- the event lacks the entry's owners. An entry has up to two owners, `player_id` and `partner_id` (a trade names the recipient as partner): see `VisibleFeedEntry` and `Handlers::ReactionNotices`, which never counts an owner's own reaction.
- `app/domains/game/app/jobs/game/publish_weekly_verdict_job.rb` -- returns early when there is no winner.
- `app/domains/game/app/models/game/fortune.rb` -- `listed` and `ranked` (`z_score desc, player_id asc`), `week_start` per Monday UTC; `game_fortunes.week_start IS NULL` is the all-time row.
- Data: `game_market_wallets`, `game_friendships` (low/high), `game_feed_reactions`, `game_feed_entries` (`kind = 'verdict'` carries the winner), `game_showcase_entries` (`ShowcaseEntry::SIZE` = 5), `game_market_archive_deposits` (quantity only grows), `game_custom_sets` (`kind = 'custom'`) + `game_custom_set_games` + held games as in `HeldGames`.
- `app/helpers/achievements_helper.rb` `GLYPHS`; `script/pixel_art/export.mjs` `ACHIEVEMENT_GLYPHS` (7×7 `#` grids).
- `config/locales/{en,fr}.yml` `achievements.names.*` / `achievements.conditions.*`.
- Tests: `test/domains/game/achievements_test.rb` (846 lines, metric zeros, both locales), `achievement_board_test.rb`, `opening_pace_achievements_test.rb` (shape to copy), `market/market_achievements_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `achievements.rb` -- append the 32 entries of the table below.
- [x] `achievement_progress.rb` -- add the metrics: `picoins_held`, `friends`, `reactions_given`, `reactions_to_own_posts`, `most_reactions_on_a_post`, `showcase_cards`, `showcase_cleared_after_full`, `cards_entrusted`, `verdicts_won`, `lucky_week_streak`, `unlucky_week_streak`, `largest_custom_set`, `largest_completed_custom_set`; `last_places` in Ruby from `Fortune.listed`. Pass the current week start as a bind next to `:player_id`. The reaction metrics and `last_places` follow the Design Notes.
- [x] `react_to_feed_entry.rb` -- add `author_id: entry.player_id, partner_id: entry.partner_id` to the event data.
- [x] `handlers/achievements.rb` -- add `Market::CardsEntrusted`, `FeedEntryReacted` (player, author and partner), `InvitationAccepted` (sender and recipient), `ShowcaseCardAdded`, `ShowcaseCardRemoved`, `CustomSetCreated`, `CustomSetEdited`; skip nil ids and dedupe.
- [x] `publish_weekly_verdict_job.rb` -- after the verdict, with or without one, enqueue `GrantAchievementsJob` for every player with a fortune row last week.
- [x] `export.mjs` + `achievements_helper.rb` -- the new glyphs, then run the exporter.
- [x] `en.yml`, `fr.yml` -- names and conditions for the 32 keys.
- [x] `test/domains/game/custom_set_earns_nothing_test.rb` -- keep the custom set it completes under 10 games, or leave `AchievementUnlock` out of the compared rewards, and say so in its comment.
- [x] Tests -- a new `test/domains/game/more_achievements_test.rb` for each metric and every matrix row; extend the zero-progress expectations; add a handler test for the new triggers and the fan-out.

| Key | Metric | ≥ | Glyph | fr | en |
|---|---|---|---|---|---|
| boosters_1000 / 5000 / 10000 | packs_opened | 1000/5000/10000 | pack | Client stratégique · Actionnaire de référence · Fait partie des meubles | Key Account · Major Shareholder · Part of the Furniture |
| reposts_10 / 50 / 200 | reposts | 10/50/200 | card | Ambassadeur de marque · Service communication · Directeur de la communication | Brand Ambassador · Communications Department · Chief Communications Officer |
| trades_10 / 50 / 100 | trades_accepted | 10/50/100 | trade | Partenariat durable · Chambre de commerce · Accord de libre-échange | Lasting Partnership · Chamber of Commerce · Free Trade Agreement |
| picoins_50k / 500k / 1m | picoins_held | 50k/500k/1M | coin | Épargne de précaution · Patrimoine imposable · Premier million | Rainy-Day Fund · Taxable Estate · First Million |
| friends_10 / 25 / 50 | friends | 10/25/50 | friends | Réseau professionnel · Team building · Séminaire annuel | Professional Network · Team Building · Annual Company Retreat |
| reactions_50 / 200 / 500 | reactions_given | 50/200/500 | thumb | Retour constructif · Enquête de satisfaction · Responsable de l'engagement | Constructive Feedback · Satisfaction Survey · Head of Engagement |
| self_assessment | reactions_to_own_posts | 1 | mirror | Auto-évaluation | Self-Assessment |
| viral_memo | most_reactions_on_a_post | 10 | megaphone | Note de service virale | Viral Memo |
| showcase_full | showcase_cards | 5 | showcase | Agencement du point de vente | Point-of-Sale Layout |
| everything_must_go | showcase_cleared_after_full | 1 | broom | Tout doit disparaître | Everything Must Go |
| entrusted_100 / 1000 / 5000 / 10000 | cards_entrusted | 100/1000/5000/10000 | archive | Dépôt légal · Fonds d'archives · Mécénat d'entreprise · Legs au patrimoine | Legal Deposit · Archive Collection · Corporate Patronage · Heritage Bequest |
| employee_of_the_week | verdicts_won | 1 | crown | Employé de la semaine | Employee of the Week |
| room_for_improvement | last_places | 1 | anchor | Marge de progression | Room for Improvement |
| sustained_growth | lucky_week_streak | 3 | sun | Croissance soutenue | Sustained Growth |
| turnaround_plan | unlucky_week_streak | 3 | rain | Plan de redressement | Turnaround Plan |
| statement_of_requirements | largest_custom_set | 10 | quill | Cahier des charges | Statement of Requirements |
| delivered_on_schedule | largest_completed_custom_set | 10 | binder | Livré dans les délais | Delivered on Schedule |

**Acceptance Criteria:**
- Given a player whose history already meets an entry, when the deploy backfill runs, then it is granted without a toast.
- Given the achievements screen, when it renders, then each of the 62 tiles shows its glyph, name, condition and, for thresholds above 1, its progress.

## Design Notes

Streaks reuse `longest_run_sql` with weeks as the ordering: `week_start - 7 * ROW_NUMBER() OVER (ORDER BY week_start)` over the player's rows where `z_score > 0` (or `< 0`) and `week_start < :current_week`. Last place must not scan whole weeks: the metric runs on every grant job and once per player at each deploy's backfill. Count the player's own listed rows for completed weeks such that no listed row of the same week ranks behind them (`z_score < theirs`, or the same `z_score` with a higher `player_id`, the mirror of `Fortune.ahead_of`), and another listed row of that week exists. Write both as correlated `EXISTS` probes; the `(week_start, z_score, player_id)` index answers them.

Reactions belong to an entry's owners, `player_id` and `partner_id`. Self-assessment = the player reacted to an entry they own. Received reactions on an entry = reactions by anyone who is not one of its owners, as `ReactionNotices` counts them; compare with `IS DISTINCT FROM` for the partner, since `NOT IN` against a null `partner_id` drops every row. Name the shared SQL fragment after what it holds (reactions on the player's entries), not after the self-assessment metric.

## Verification

**Commands:**
- `bin/rails test test/domains/game/ test/helpers test/controllers/achievements_controller_test.rb` -- green
- `node script/pixel_art/export.mjs --check`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references`, `bundle exec i18n-tasks missing` -- clean

## Implementation Notes

- Ruby-side metrics are now `RUBY_METRICS` (`most_games_of_a_studio`, `last_places`), replacing the single `STUDIO_METRIC`; `last_places` also keeps to completed weeks, like the streaks.
- `showcase_full` takes its threshold from `ShowcaseEntry::SIZE`; `showcase_cleared_after_full` reads the `showcase_full` unlock row.
- The fan-out uses `ActiveJob.perform_all_later` over `Fortune.of_period(:last_week, now)`.
- `custom_set_earns_nothing_test.rb` keeps its three-game set; only its comment changed. The existing trigger count in `achievements_test.rb` (11 -> 20), the countable list in `achievement_board_test.rb` and the event data in `react_to_feed_entry_test.rb` follow the change.
- 14 new glyphs: coin, friends, thumb, mirror, megaphone, showcase, broom, archive, crown, anchor, sun, rain, quill, binder.
- Loop 1: `last_places` counts the player's listed completed-week rows (aliased `mine`) with a `NOT EXISTS` probe for a listed row ranked behind and an `EXISTS` probe for another listed row, both through `Fortune.listed` (`listed_that_week`). The reaction metrics read `REACTIONS_ON_PLAYER_ENTRIES` (entries the player owns as `player_id` or `partner_id`); Viral Memo leaves out both owners' reactions. The event's data is built in `ReactToFeedEntry#reacted`.

## Plan Change Log

- **Loop 1 (2026-11-16), quick review.** Triggers: `last_places` windows over every listed row of each week the player played, on the hot grant path and the deploy backfill; trade entries name the recipient as `partner_id`, but the reaction metrics and the event read only `player_id`. Amended: Code Map (entry owners), the `achievement_progress.rb`, `react_to_feed_entry.rb` and handler tasks, and the Design Notes (last place by `EXISTS` probes; reactions by owners, with an owner's own reaction never counted as received; the fragment name). Avoids: a backfill whose cost grows with players × weeks for every player, and a trade recipient whose reactions never count. KEEP: everything else of the first attempt, saved as `/tmp/claude-1000/-home-teyermann-projets-gameble/4ec48c2a-6864-4058-8667-ac1688f03cd6/scratchpad/achievements-attempt-1.patch` (git diff from the baseline, new files included). Apply it with `git apply`, then change only what these amendments name. That patch also carries the coordinator's test fixes: catalogue totals and countable bars derived from `CATALOGUE` in the achievements, public profile and pages controller tests, and the market tiles found by `index(:hostile_takeover)`. Its names, conditions, glyphs and the other tests passed the full suite and stay as they are. Also cover in tests: a trade recipient's self-assessment and received reactions, and an owner's own reaction not counting toward Viral Memo.

## Review Triage Log

- Loop 1 (quick): 2 medium, 2 low, 1 false, 2 rejected low.
  - medium · bad_plan -- `achievement_progress.rb` `last_places`: the window reads every listed row of each played week, so its cost grows with players × weeks; it runs on every grant job and once per player at deploy (`bin/docker-entrypoint` backfill). The Design Notes prescribed it.
  - medium · bad_plan -- `react_to_feed_entry.rb` / reaction metrics: a trade entry's `partner_id` is an owner (`VisibleFeedEntry`, `ReactionNotices`), yet only `player_id` counted. The task prescribed `author_id: entry.player_id`.
  - low · patch (folded into the loop 1 amendment) -- `MOST_REACTIONS_ON_A_POST_SQL` counts the owner's own reaction as received; `ReactionNotices` excludes it.
  - low · patch (folded) -- the fragment `REACTIONS_TO_OWN_POSTS` holds everyone's reactions on the player's entries, while the metric `reactions_to_own_posts` means the player's own; the name misleads.
  - low · rejected -- `z_score > 0` against the displayed index rounding to 0 for z in (0, ~0.002): too rare, and the fix needs an arbitrary threshold.
  - low · rejected -- the `duel_stats` matrix row is tested through a hand-built event: the handler's nil skip is verified, and `entry.player_id` is nil for those entries by construction.
  - false -- "62 tiles only checked indirectly": the controller test renders every tile; a missing glyph raises in `GLYPHS.fetch` and a missing string under `raise_on_missing_translations`.
- Pass 2 (quick, after loop 1): 2 low, both patched. Loop 1's findings are gone: `last_places` uses `EXISTS` probes, the reaction metrics count both owners, and an owner's own reaction no longer counts as received.
  - low · patch -- `handlers/achievements.rb`: `values_at(...).compact` treats a missing key like a nil id, so a mistyped `EVENTS` key or an event published without its key grants nobody silently, where `fetch` raised inside the publishing transaction. Back to `fetch`, skipping only nil ids.
  - low · patch -- `handlers/achievements.rb`: a removed reaction (`kind: nil`) enqueued up to three grant jobs although a removal only lowers counts (`ReactionNotices` already returns early); players do this every day, so the handler now skips it.
