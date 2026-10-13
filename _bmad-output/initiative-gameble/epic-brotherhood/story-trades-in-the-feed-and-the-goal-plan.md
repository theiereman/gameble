---
title: 'Trades in the feed and the goal'
type: 'feature'
ticket: '9'
created: '2026-10-12'
status: done
baseline_revision: '224cc3934833c61bacd0d4b7a95d6a1a2d065e08'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A concluded trade (`Game::TradeAccepted`, published by `Game::AcceptTrade`) leaves no trace in the community: the feed's ÉCHANGES filter and the LIVE ticker never show a trade, and the weekly gauge counts only openings.

**Approach:** Handle `Game::TradeAccepted` in the trade's transaction: write one `trade` feed entry naming both players and the best card of each side (unique per trade), and count the trade 1 in the weekly goal, once for the two players, while making both players contributors of the week. The live stream broadcasts the new entry after commit to the feed, the ticker and the public strip; the feed, ticker and strip render it as "A et B ont échangé X contre Y" with the "⇄ Échange" tag.

## Boundaries & Constraints

**Always:** handlers run in the accepting transaction, publish nothing, write only the two traders' contribution rows and a new feed row; a duplicate event never fails the trade (unique trade id, ON CONFLICT DO NOTHING / upsert). The gauge total of a week = sum of openings + trades counted once (the job's one aggregate per week). A trade entry shows to a viewer only when `Game::Visibility.visible?` allows **both** players (nil viewer for live broadcasts); the Friends tab shows a trade when either player is in `players`. Deleting an account removes the trade entries naming it on either side. Schema changes are expand/contract (strong_migrations: check added `NOT VALID`, validated in its own migration; concurrent index in its own migration). Every string in `en.yml` and `fr.yml`; no ids in DOM, URLs or stream names; no `style` attribute; no planning ids or explanatory comments in code.

**Never:** a trade counting 2 in the gauge; a trade entry as a filler or with `notable: false`; a trade shown when either player is hidden, banned or deleted for that viewer; a broadcast inside the transaction; a change to how openings, discoveries or reposts are recorded or shown; a change to the Brotherhood line copy.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Trade concluded | Alice offers {A, B}, Bob gives {C}; both public | one `trade` entry: player Alice, partner Bob, card = best of offer, partner card = best of request, rarity = higher tier; next sum adds 1 to the week's total | — |
| Gauge once | Alice and Bob each open 2 packs and trade once | week total 5 (not 6); both have a contribution row | — |
| Trade-only player | Bob opened nothing this week, accepted a trade | Bob has a contribution row (rewarded if the goal is reached); not counted active for next week's target (openings = 0) | — |
| Event handled twice | same `TradeAccepted` handled again | still one entry, trade still counted once | never fails |
| Rolled back | acceptance fails / rolls back | no entry, no contribution, no broadcast | — |
| Visibility | Bob friends-only / private / banned | visitor: entry hidden (feed, ticker, strip, live broadcast); Bob's friend: shown only if Alice is visible too | — |
| Friends tab | viewer is friends with Bob only | the Alice–Bob trade shows under AMIS and AMIS · ÉCHANGES | — |
| Live | public trade committed | one job after commit; feed All view, ticker queue and public strip get it | — |
| Account deleted | Bob deletes his account | the trade entries naming Bob (either side) are gone | — |

</intent-contract>

## Code Map

- `packs/game/app/operations/game/accept_trade.rb` -- publishes `TradeAccepted {trade_id, proposer_id, recipient_id}` after `trade.update!(status: "accepted")`; unchanged. `TradeItem` rows (`side` offer/request, `card_season_id`, `quantity`) give the cards; offer = given by the proposer, request = given by the recipient.
- `config/initializers/event_store.rb` -- subscribe the new handler(s) to `Game::TradeAccepted` next to `PackOpened`/`PackOpenedFeed`; `LiveStream::EVENTS` gains `Game::TradeAccepted`.
- `packs/game/app/handlers/game/handlers/pack_opened.rb`, `pack_opened_feed.rb`, `card_reposted_feed.rb` -- patterns; add e.g. `trade_accepted.rb` (contribution) and `trade_accepted_feed.rb` (entry), or one handler for both.
- `packs/game/app/models/game/weekly_contribution.rb` -- add a `trades` column (default 0, check >= 0) and a `record_trade(proposer_id, recipient_id, now)`: one `upsert_all` of the two rows (ascending player id), crediting the trade to one of them (the recipient, who concluded it) and only ensuring the other's row, so `sum(openings + trades)` counts it once and both are contributors (`GrantGoalReward#contributed` and `GrantGoalRewardsJob` read row existence). `WeeklyGoal.target_for` keeps `openings: 1..` (active = opened a pack).
- `packs/game/app/jobs/game/sum_weekly_goal_job.rb` L30 -- sum `openings + trades`.
- `packs/game/app/models/game/feed_entry.rb` -- add `record_trade(trade_id:, proposer_id:, recipient_id:, offer:, request:, rarities:, at:)`; columns: `trade_id` (FK game_trades, unique where not null), `partner_id` (FK accounts_players, indexed), `partner_card_season_id` (FK catalog_card_seasons); a check that `kind = 'trade'` iff those three are present. Best card per side: highest rarity tier (`Catalog::Rarity::TIERS`), lowest card-season id on a tie; `rarity` = the higher of the two. Insert with `insert_all ... unique_by: :trade_id` (needs the unique index) or `ON CONFLICT DO NOTHING`.
- `packs/game/app/queries/game/feed_entries.rb` -- `Entry` gains `partner` (nil except trades); `visible` loads partners with the players and keeps a trade only if both are shown; `players:` matches `player_id` or `partner_id`.
- `packs/game/app/queries/game/new_feed_entries.rb` -- accept `trade_ids:` and apply the both-visible rule.
- `packs/game/app/operations/game/release_player.rb` -- also delete entries where `partner_id` is the player.
- `app/models/live_stream.rb` -- `notices` for `TradeAccepted` → `{ trade_id: }`; `app/jobs/live_feed_job.rb` passes `trade_ids`.
- `app/models/feed_items.rb` -- resolve the partner card too (one `Catalog::CardViews` call); items for a trade carry both card views (e.g. `[item, card, partner_card]`), skip a trade whose partner card is missing.
- `app/helpers/feed_helper.rb#feed_sentence` -- a `trade` sentence with both names and both titles.
- `app/views/feeds/_entry.html.erb` (two thumbnails framed in their rarity, tag "⇄ Échange"), `app/views/shell/_ticker_item.html.erb` (sentence + the trade tag in place of the rarity), `app/views/cards/_live_strip.html.erb` (sentence + trade tag), `app/views/live_streams/_feed.turbo_stream.erb`, `app/views/feeds/show.html.erb` -- pass the partner card; CSS in `app/frontend/styles/feed.css` / `shell.css` for the second thumbnail and the trade tag.
- `config/locales/{en,fr}.yml` -- `feeds.show.traded_html` ("%{name} et %{partner} ont échangé %{card} contre %{partner_card}" / "%{name} and %{partner} traded %{card} for %{partner_card}"), `feeds.show.trade_tag` ("⇄ Échange" / "⇄ Trade"); `pages.home.goal.progress` no longer says only boosters ("%{total} contributions sur %{target} cette semaine" / "%{total} contributions of %{target} this week").
- Tests to extend: `test/packs/game/feed_test.rb`, `test/packs/game/weekly_goal_test.rb`, `test/packs/game/goal_reward_test.rb`, `test/packs/game/trade_accept_counter_expire_test.rb` (helpers `befriend`, `hold`, `propose`, `accept`), `test/models/live_stream_test.rb`, `test/controllers/feeds_controller_test.rb`, `test/controllers/pages_controller_test.rb` (ticker), `test/packs/accounts/delete_player_test.rb`; query-count budgets may move.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*` -- add `trades` to `game_weekly_contributions` (+ check); add `trade_id`, `partner_id`, `partner_card_season_id` to `game_feed_entries` with FKs (`validate: false` then validated), the trade check (`NOT VALID` then validated), concurrent unique index on `trade_id` and index on `partner_id` in their own migrations; regenerate `db/schema.rb` with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_auto_6_9 RAILS_ENV=test bin/rails db:drop db:create db:migrate`.
- [x] `packs/game/app/models/game/{weekly_contribution,feed_entry}.rb`, handler(s), `config/initializers/event_store.rb`, `sum_weekly_goal_job.rb` -- record the trade in the feed and the goal.
- [x] `feed_entries.rb`, `new_feed_entries.rb`, `release_player.rb` -- both-visible rule, friends either side, deletion cleanup.
- [x] `live_stream.rb`, `live_feed_job.rb`, `feed_items.rb`, `feed_helper.rb`, views, CSS, locales -- the trade rendered in feed, ticker and strip, live.
- [x] Tests -- every matrix row: entry fields and best-card choice, idempotency, rollback, gauge once and trade-only contributor (sum job + reward), visibility (visitor, friend, banned), Friends tab either side, live broadcast after commit with the ticker item, deletion; controller tests for the ÉCHANGES filter and the ticker showing a trade.

**Acceptance Criteria:**
- Given two public friends conclude a trade, when a visitor opens the feed (All and ÉCHANGES) and the hub, then the trade shows once in the feed and once in the ticker with both names, both card titles and the "⇄ Échange" tag.
- Given a concluded trade and openings that week, when the sum job runs, then the week's total is the openings plus 1 for the trade, not 2.
- Given a reached goal and a player whose only contribution that week is a trade, when rewards are granted, then that player receives the reward booster.

## Implementation Notes

- One handler, `Game::Handlers::TradeAccepted`, writes both the feed entry and the contributions. The contributions are counted only when the feed insert actually adds the row (`insert_all ... unique_by: :trade_id` returning a row), so a duplicate event changes neither. A side with no rated card writes no entry and counts nothing; this cannot happen for held cards.
- The "⇄" glyph is drawn with the existing `swap` pixel icon next to the tag text, as DESIGN.md requires for glyphs the fonts lack. So `feeds.show.trade_tag` is "Échange" / "Trade", and the rendered tag still reads "⇄ Échange".
- `test/support/game_trades.rb` (`conclude_trade`) runs a real propose-and-accept. The new check makes hand-built `trade` rows without trade columns invalid, so the tests that wrote such rows now conclude a real trade. The teardowns of the non-transactional race tests delete trade entries (and contributions) before the trades.
- On a host in a DST zone, `trades_of_test` and `sessions_controller_test` fail until 2026-10-25 because the clock crosses the DST change. They pass with `TZ=UTC` and have nothing to do with this change.

## Plan Change Log

## Review Triage Log

### 2026-10-12 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` The diff adds prose to existing comment blocks (`feed_entry.rb`, `feed_entries.rb`, `weekly_contribution.rb`, `feeds/show.html.erb`, `cards/_public.html.erb`), and two of them were left badly wrapped. The blocks already existed, and the changes keep them true for the new trade kind; removing the trade sentences would leave them stale. The real defect was the broken wrapping in `feed_entries.rb` and `feeds/show.html.erb`. Fixed: both reflowed. This was a comment-only change, so the parent session made it directly rather than re-engaging the implementer. Feed, feeds controller and live stream tests are green, and rubocop is clean.

## Design Notes

The trade is credited to one row so the sum stays a plain `SUM(openings + trades)` over per-player rows (no shared row, no division); the other trader gets a row only to be a contributor. Showing the best card of each side matches the design's "one or two thumbnails" and the mock sentence "A et B ont échangé X contre Y"; the proposer is named first.

## Verification

All commands with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_auto_6_9` exported; never touch `gameble_test` or run `docker compose`.

**Commands:**
- `bin/rails test` -- expected: green
- `bin/rails test:system TEST="test/system/live_updates_test.rb test/system/feed_test.rb test/system/hub_test.rb"` -- expected: green
- `npm run test:js && npm run typecheck` -- expected: pass
- `bundle exec rubocop && bundle exec packwerk check && bin/rails zeitwerk:check && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

**Summary.** A concluded trade is now handled in the accepting transaction by `Game::Handlers::TradeAccepted`:
- It writes one `trade` feed entry, unique per trade. The entry names the proposer and, as partner, the recipient. It also holds the best card each one gave (highest tier, lowest id on a tie) and the higher rarity of the two.
- It counts the trade once in the weekly goal. The trade is credited to the recipient's `trades` column. The proposer gets a contribution row only, so both are contributors and the sum `openings + trades` counts the trade 1, not 2.
- The live stream broadcasts the entry after commit to the feed, the ticker and the public strip.
- The feed, the ticker and the strip render it as "A et B ont échangé X contre Y" with the swap icon and the "Échange" tag.
- A trade shows only when both players are visible to the viewer. The Friends tab matches either side. Deleting an account removes the trade entries that name the player on either side.

**Files.**
- `db/migrate/20261012110000`–`110005` and `db/schema.rb`: the `trades` contribution column; the `trade_id`, `partner_id` and `partner_card_season_id` feed-entry columns with FKs and a trade check (each added NOT VALID, then validated); concurrent indexes.
- `packs/game/app/handlers/game/handlers/trade_accepted.rb` and `config/initializers/event_store.rb`: the new handler and its subscription.
- `packs/game/app/models/game/feed_entry.rb` and `weekly_contribution.rb`: `record_trade` in each.
- `packs/game/app/jobs/game/sum_weekly_goal_job.rb`: the sum now adds openings and trades.
- `packs/game/app/queries/game/feed_entries.rb` and `new_feed_entries.rb`: the partner, the rule that both players must be visible, and Friends matching on either side.
- `packs/game/app/operations/game/release_player.rb`: cleanup of the partner side.
- `app/models/live_stream.rb`, `app/jobs/live_feed_job.rb`, `app/models/feed_items.rb` and `app/helpers/feed_helper.rb`: the trade notice, the partner card and the trade sentence.
- Views (feed entry, ticker item, live strip, turbo stream, feed page), `feed.css` and `shell.css`: the two thumbnails and the trade tag.
- `config/locales/{en,fr}.yml`: `traded_html`, `trade_tag`, and a goal progress line that no longer says only boosters.
- Tests:
  - new `test/support/game_trades.rb`;
  - new cases in feed, weekly goal, goal reward, trade acceptance, live stream, feeds and pages controllers, and player deletion;
  - teardowns of the race tests updated.

**Review.** One quick pass with 1 finding. One low was patched: comment blocks badly wrapped after the update. Nothing was deferred or rejected.

**Follow-up review recommended:** false. Only one low entry was patched.

**Verification.** All runs used `DATABASE_URL=…/gameble_test_auto_6_9`.

| Check | Result |
|---|---|
| `bin/rails test` | 2214 runs. The 2 failures are the DST-sensitive `sessions_controller_test.rb:316` and `trades_of_test.rb:62` under the host's CEST zone; both pass with `TZ=UTC`, and neither is related to this change. |
| System tests: live_updates, feed, hub | 34 runs, green |
| vitest | 217 tests, green |
| typecheck, rubocop, packwerk, zeitwerk, `i18n-tasks missing` / `unused` | clean |

**Residual risks.**
- The tag text is "Échange" / "Trade", drawn after the existing `swap` pixel icon instead of the literal "⇄" glyph, which the fonts lack.
- A trade is credited to its recipient's row. A per-player `trades` figure therefore reads "trades accepted", not "trades taken part in".
- The new FK from `partner_card_season_id` to `catalog_card_seasons` means a card-season named in a trade entry cannot be deleted without removing the entry first. Only draft seasons are pruned today.
- Two DST-sensitive tests fail on hosts in a DST zone until 2026-10-25. This predates the change.
