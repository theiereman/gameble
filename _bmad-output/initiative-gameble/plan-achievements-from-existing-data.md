---
title: 'A wave of achievements read from data the game already keeps'
type: 'feature'
ticket: ''
created: '2026-11-16'
status: 'ready-for-dev'
baseline_revision: ''
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
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
- `app/domains/game/app/operations/game/react_to_feed_entry.rb` -- the event lacks the entry's author.
- `app/domains/game/app/jobs/game/publish_weekly_verdict_job.rb` -- returns early when there is no winner.
- `app/domains/game/app/models/game/fortune.rb` -- `listed` and `ranked` (`z_score desc, player_id asc`), `week_start` per Monday UTC; `game_fortunes.week_start IS NULL` is the all-time row.
- Data: `game_market_wallets`, `game_friendships` (low/high), `game_feed_reactions`, `game_feed_entries` (`kind = 'verdict'` carries the winner), `game_showcase_entries` (`ShowcaseEntry::SIZE` = 5), `game_market_archive_deposits` (quantity only grows), `game_custom_sets` (`kind = 'custom'`) + `game_custom_set_games` + held games as in `HeldGames`.
- `app/helpers/achievements_helper.rb` `GLYPHS`; `script/pixel_art/export.mjs` `ACHIEVEMENT_GLYPHS` (7×7 `#` grids).
- `config/locales/{en,fr}.yml` `achievements.names.*` / `achievements.conditions.*`.
- Tests: `test/domains/game/achievements_test.rb` (846 lines, metric zeros, both locales), `achievement_board_test.rb`, `opening_pace_achievements_test.rb` (shape to copy), `market/market_achievements_test.rb`.

## Tasks & Acceptance

**Execution:**
- [ ] `achievements.rb` -- append the 32 entries of the table below.
- [ ] `achievement_progress.rb` -- add the metrics: `picoins_held`, `friends`, `reactions_given`, `reactions_to_own_posts`, `most_reactions_on_a_post`, `showcase_cards`, `showcase_cleared_after_full`, `cards_entrusted`, `verdicts_won`, `lucky_week_streak`, `unlucky_week_streak`, `largest_custom_set`, `largest_completed_custom_set`; `last_places` in Ruby from `Fortune.listed`. Pass the current week start as a bind next to `:player_id`.
- [ ] `react_to_feed_entry.rb` -- add `author_id: entry.player_id` to the event data.
- [ ] `handlers/achievements.rb` -- add `Market::CardsEntrusted`, `FeedEntryReacted` (player and author), `InvitationAccepted` (sender and recipient), `ShowcaseCardAdded`, `ShowcaseCardRemoved`, `CustomSetCreated`, `CustomSetEdited`; skip nil ids and dedupe.
- [ ] `publish_weekly_verdict_job.rb` -- after the verdict, with or without one, enqueue `GrantAchievementsJob` for every player with a fortune row last week.
- [ ] `export.mjs` + `achievements_helper.rb` -- the new glyphs, then run the exporter.
- [ ] `en.yml`, `fr.yml` -- names and conditions for the 32 keys.
- [ ] `test/domains/game/custom_set_earns_nothing_test.rb` -- keep the custom set it completes under 10 games, or leave `AchievementUnlock` out of the compared rewards, and say so in its comment.
- [ ] Tests -- a new `test/domains/game/more_achievements_test.rb` for each metric and every matrix row; extend the zero-progress expectations; add a handler test for the new triggers and the fan-out.

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

Streaks reuse `longest_run_sql` with weeks as the ordering: `week_start - 7 * ROW_NUMBER() OVER (ORDER BY week_start)` over the player's rows where `z_score > 0` (or `< 0`) and `week_start < :current_week`. To find last place, window over `Fortune.listed` restricted to the weeks where the player has a row, which keeps the scan small: `ROW_NUMBER() OVER (PARTITION BY week_start ORDER BY z_score, player_id DESC) = 1` and `COUNT(*) OVER (PARTITION BY week_start) > 1`.

## Verification

**Commands:**
- `bin/rails test test/domains/game/ test/helpers test/controllers/achievements_controller_test.rb` -- green
- `node script/pixel_art/export.mjs --check`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references`, `bundle exec i18n-tasks missing` -- clean

## Implementation Notes

## Plan Change Log

## Review Triage Log
