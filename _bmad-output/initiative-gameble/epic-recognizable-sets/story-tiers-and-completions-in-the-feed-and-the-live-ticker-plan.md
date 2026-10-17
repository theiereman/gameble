---
title: 'Tiers and completions in the feed and the LIVE ticker'
type: 'feature'
ticket: '6'
created: '2026-10-17'
status: 'built'
baseline_revision: 'be756f9c1ef96ef4046a38c31fa9cd064188ae59'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** A set tier reached or a set completed publishes `Game::SetTierReached` / `Game::SetCompleted`, but nothing shows it in the activity feed or the LIVE ticker, so the community never sees a player's sets progress.

**Approach:** A new feed entry kind `set` (no card, no pack) holds, per player and operation, the highest result and the count of sets reached; one feed handler subscribed to the two tier events upserts it from the operation's `game_set_tiers` rows. The feed, the ticker, the live broadcast and the public card page's live strip render it under the existing visibility rules.

## Boundaries & Constraints

**Always:**
- One `set` entry per player and operation: the tier rows sharing the event's row `reached_by`, `reached_at` and `pack_id` (an opening's pack, or one trade's side). It stores `set_id` and `tier` of the highest result (complete > gold > silver > bronze, lowest set id on a tie), `set_count` = distinct sets among those rows, `occurred_at` = their `reached_at`, `notable` true, no `card_season_id`, `rarity`, `pack_id`, `trade_id`.
- Results are per set, as in the opening's celebration: bronze and silver on one set in one opening is one result (silver); gold and complete together is SET COMPLET.
- The handler runs in the operation's transaction, publishes nothing, writes one idempotent upsert per event (an event handled twice changes nothing), unique on `(player_id, occurred_at)` where `kind = 'set'`.
- Sentences (fr / en): one result → "Léa atteint le bronze du set Roguelike." / "l'argent du set" / "l'or du set", "Léa complète le set Dark Souls."; several → "Léa atteint 4 paliers · Metroidvania OR" (count plural with `zero`, `one`, `other`). The tag: the tier's name in its colour with 1–3 filled notches (bronze, silver, gold), or the small COMPLET frame beside the word "Complet" in lime; no thumbnail.
- Visibility: shown only where every surface already asks `Game::Visibility.visible?` (feed, friends tab, ticker, broadcast, strip).
- Schema changes expand/contract: nullable columns and new checks added unvalidated, validated in a second migration, the partial unique index concurrently in its own.

**Never:**
- No pack or card on a set entry, no "Sets" filter in the feed's type filters, no entry for the season allocation's carried tiers (no event), no change to the tier pass, the events' data, or the celebration.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Silver on a theme | public Léa's opening crosses Roguelike silver only | one `set` entry (silver, count 1); feed and ticker for a visitor: "Léa reaches silver in the Roguelike set." + SILVER tag | — |
| Four sets | one opening: 4 sets' tiers, highest Metroidvania gold | one entry, one ticker item: "Léa atteint 4 paliers · Metroidvania OR", OR tag | — |
| Two tiers one set | bronze + silver of Roguelike | one result: "… l'argent du set Roguelike." | — |
| Completion | last Dark Souls member | "Léa complète le set Dark Souls." + COMPLET mark | — |
| Trade | accepted trade crosses tiers for both players | one entry per player, each with that player's results | — |
| Private | private player's tier | entry stored, absent from feed, ticker, broadcast | — |
| Replayed event | handler called again | no new row, same values | upsert |
| Opening with no tier | — | no `set` entry | — |

</intent-contract>

## Code Map

- `db/migrate/` -- (1) `game_feed_entries`: add `set_id` bigint (no FK, as `game_set_tiers`), `tier` string, `set_count` integer; `change_column_null` `card_season_id` and `rarity` to true; replace `game_feed_entries_kind_check` (equality OR chain, add `set`) and add `game_feed_entries_set_check` (`(kind = 'set') = (set_id IS NOT NULL AND tier IS NOT NULL AND set_count IS NOT NULL AND card_season_id IS NULL AND rarity IS NULL)`) and a tier/count check, all `validate: false`; (2) validate them; (3) concurrent unique index `[player_id, occurred_at] WHERE kind = 'set'`. Patterns: `20261015130001_narrow_catalog_sets_kind_check.rb`, `…130002_validate…`, `20261008*_index_game_feed_entries_on_partner_id.rb`. Regenerate `db/schema.rb`.
- `packs/game/app/models/game/feed_entry.rb` -- `KINDS` + `set`; `record_sets(player_id:, set_id:, tier:, now:)`: one `INSERT … SELECT` from the event's row's siblings in `game_set_tiers`, `ON CONFLICT (player_id, occurred_at) WHERE kind = 'set' DO UPDATE`; rewrite the class comment.
- `packs/game/app/handlers/game/handlers/set_tier_feed.rb` -- new handler; `config/initializers/event_store.rb` subscribes it to both events.
- `app/models/live_stream.rb` -- EVENTS + the two events, notice `{ player_id:, set_id:, tier: }`; `TICKER_KINDS` + `set`.
- `packs/game/app/queries/game/new_feed_entries.rb` -- `sets:` notices → `set` entries whose `occurred_at` is the notified row's `reached_at` for that player. `app/jobs/live_feed_job.rb` passes them.
- `packs/catalog/app/queries/catalog/sets_by_id.rb` -- new: `{ id => Catalog::Set }` for ids.
- `app/models/feed_items.rb` -- yields `[item, card, partner_card, set]`; a `set` entry keeps a nil card and needs its set.
- `app/helpers/feed_helper.rb` -- `feed_sentence` `set` branch (`SetLabel.for`), a `feed_tier_tag` helper.
- Views destructuring items: `app/views/feeds/show.html.erb`, `feeds/_entry.html.erb`, `live_streams/_feed.turbo_stream.erb`, `shell/_ticker.html.erb`, `shell/_ticker_item.html.erb`, `cards/_live_strip.html.erb` -- pass `set`, render the set branch (no thumbnail, `feed__entry--set`).
- `app/frontend/styles/feed.css`, `shell.css` -- tier colours (`--color-tier-bronze`, `--color-tier-silver`, `--color-gold`, lime), notches 4 × 8 / 10 / 12 with 2px gaps, the 22 × 14 COMPLET frame (copy of `booster.css:1012-1041`), the set entry's tag in the last grid column.
- `packs/game/app/queries/game/export_of.rb`, `app/models/player_export.rb` -- a `set` feed entry exports its set (season, kind, key), tier and count instead of a card; `card_season_ids` drops nils.
- `config/locales/{fr,en}.yml` `feeds.show` -- sentences, tier names.
- Tests: `test/packs/game/feed_test.rb` (handler, grouping, trade, replay, private), `test/jobs/live_feed_job_test.rb`, `test/models/live_stream_test.rb`, `test/controllers/feeds_controller_test.rb` (signed-out feed shows it), export tests; adapt tests counting every feed row now that `portal_one` completes fixture `valve_one`, and `first_discovery_and_set_completion_test.rb`'s statement budget (one statement per tier event).

## Tasks & Acceptance

**Execution:**
- [x] Migrations, `db/schema.rb` -- the expanded table.
- [x] `feed_entry.rb`, `set_tier_feed.rb`, `event_store.rb` -- record.
- [x] `live_stream.rb`, `new_feed_entries.rb`, `live_feed_job.rb` -- broadcast and ticker.
- [x] `sets_by_id.rb`, `feed_items.rb`, `feed_helper.rb`, views, CSS, locales -- render.
- [x] `export_of.rb`, `player_export.rb` -- export.
- [x] Tests covering every matrix row, plus the adapted ones.

**Acceptance Criteria:**
- Given a public player whose opening reaches silver on a theme, when a signed-out visitor loads the feed and the hub ticker, and when the live job broadcasts, then each shows one set line naming the player, the set and silver, with no thumbnail.
- Given an opening reaching four sets' tiers, when it is broadcast, then the feed and the ticker each receive exactly one set item with the count and the highest.
- Given a private player's tier, when the feed, ticker and broadcast render, then it is absent.
- Given the change, when `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` run, then they pass.

## Implementation Notes

- The tier/count check is `game_feed_entries_tier_check`: a known tier and a positive count when present. The set check is the plan's equality; it does not force a card on the other kinds (their `card_season_id` and `rarity` are now nullable), which the handlers always write.
- The upsert's `DO UPDATE` runs only when the set, tier or count differ, so a replay leaves even `updated_at` unchanged.
- The tier mark carries no `aria-hidden` (the public card's strip asserts none); its spans are empty.
- `test/support/game_sets.rb` builds sets and tiers for the feed, job and controller tests; `trade_concurrency_test.rb`'s teardown now also deletes the set entries a committed trade leaves.
- Correction (after implementation): the set check was tightened before review: `(kind = 'set')` must equal each of "set, tier and count present", "no card" and "no rarity", so every other kind still needs its card and rarity, as the dropped NOT NULLs guaranteed. The note above about a card not being forced no longer holds. `db/schema.rb` was rebuilt from the migrations the CI way (`SCHEMA=tmp/migrated_schema.rb`): on an empty database `db:migrate` loads an existing `db/schema.rb` instead of running the migrations.

## Plan Change Log

## Review Triage Log

### 2026-10-17 — Review pass
- verdicts: 2 findings — high 0, medium 1, low 1, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` "each opening that reaches tiers is its own set entry" is flaky: under `travel_to(1.hour.ago)` the opening's top-up pack becomes available before the uncommon pack, and the second opening takes the random top-up pack — fixed: the first opening runs without time travel, so the top-up pack lies in the future; the full suite then passed.
  - `[low]` `[reject]` the Implementation Notes describe the set check as the plan's single equality while the migration enforces a card and rarity on every other kind — the fix is an edit of this build's plan; a correcting implementation note records the tightened check.

## Design Notes

- **Events, grouped by the row:** the architecture puts the feed choice in a handler that answers the tier events; an event carries only `player_id, set_id, tier`, so the handler finds its own row and groups the rows that operation wrote (same `reached_by`, `reached_at`, `pack_id`). Each event rewrites the whole group's summary, so the last one leaves it complete and a replay is harmless. A trade reaches tiers too; it gets the same entry, per player.
- **Highest by set id on a tie:** the entry is stored once for both locales, so the tie-break cannot be the localized name the celebration uses.
- **Deploy:** the old container's `FeedItems` skips an entry without a card, so new `set` rows stay invisible to it.

## Verification

**Commands:**
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` -- expected: `db/schema.rb` diff holds only the new columns, checks and index
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: green

## Auto Run Result

- **Summary:** a new feed entry kind `set` sums up, per player and operation (an opening, or one side of a trade), the set tiers and completions reached: the highest result (complete > gold > silver > bronze, lowest set id on a tie), the count of sets, no card and no pack. `Game::Handlers::SetTierFeed` upserts it on each `Game::SetTierReached` / `Game::SetCompleted`; `LiveStream` notices both events, the ticker counts `set` as a kind, and the feed, the ticker, the live broadcast and the public card page's strip render it with the tier's name and notches, or the COMPLET frame, behind `Game::Visibility`.
- **Files:**
  - `db/migrate/20261017090000…090002`, `db/schema.rb` — set columns, nullable card and rarity, kind/set/tier checks (validated apart), partial unique index per player and time.
  - `packs/game/app/models/game/feed_entry.rb`, `packs/game/app/handlers/game/handlers/set_tier_feed.rb`, `config/initializers/event_store.rb` — the grouped upsert and its handler.
  - `app/models/live_stream.rb`, `packs/game/app/queries/game/new_feed_entries.rb`, `app/jobs/live_feed_job.rb` — broadcast and ticker.
  - `packs/catalog/app/queries/catalog/sets_by_id.rb`, `app/models/feed_items.rb`, `app/helpers/feed_helper.rb`, six views, `feed.css`, `shell.css`, `config/locales/{en,fr}.yml` — rendering.
  - `packs/game/app/queries/game/export_of.rb`, `app/models/player_export.rb` — a set entry exports its set, tier and count.
  - Tests: `feed_test.rb`, `live_feed_job_test.rb`, `live_stream_test.rb`, `feeds_controller_test.rb`, `pages_controller_test.rb`, export tests, `test/support/game_sets.rb`; tests that counted feed rows adapted (opening `portal_one` completes fixture `valve_one`), the opening's statement budget is now three plus one per tier event, `trade_concurrency_test.rb`'s teardown deletes set entries.
- **Review:** 1 patch applied (medium, flaky test); 0 deferred; 1 rejected (low: a plan note, corrected by a new implementation note).
- **Follow-up review:** false — one medium patched, in a test.
- **Verification:** `TZ=UTC bin/rails test` 2658 runs, 0 failures; `npm run test:js` 339 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `i18n-tasks missing` green, `unused` only the pre-existing `rate_limit.*`; `bin/ci` green except "db/schema.rb round trip", which runs `git diff --exit-code` on the then-uncommitted schema — the same load-and-dump run by hand left `db/schema.rb` identical.
- **Residual risks:** the feed and ticker layout of a set entry was not viewed in a browser (system tests are disabled); the handler writes one statement per tier event, so an opening reaching many tiers costs that many upserts.
