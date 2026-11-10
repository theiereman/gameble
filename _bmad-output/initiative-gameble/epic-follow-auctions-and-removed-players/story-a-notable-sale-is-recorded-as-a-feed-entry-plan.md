---
title: 'A notable sale is recorded as a feed entry'
type: 'feature'
ticket: '40.6'
created: '2026-11-10'
status: 'built'
baseline_revision: 'ee385caffd1868936402b29b20042aabb8201400'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/epic-follow-auctions-and-removed-players.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A sale worth noticing leaves no trace in the activity feed, so players never see the market's big moments. Epic requirements R8 and R9 (the domain half).

**Approach:** The feed entries table learns a `sale` kind tied to a listing, `Game::FeedEntry.record_sale` is the one place that chooses which sales enter, a handler of `AuctionSold` calls it, and the feed's visibility rules let a sale entry through whatever the buyer's visibility.

## Boundaries & Constraints

**Always:**
- Expand migrations: `game_feed_entries` gains a nullable `listing_id`; the kind check is replaced by one including `sale` and a check requiring `listing_id` exactly for `sale`, both added not valid then validated in a second migration; the unique index on `listing_id` for kind `sale` is a concurrent index in its own migration.
- `record_sale` inserts with ON CONFLICT DO NOTHING one entry naming the buyer as `player_id`, with the card season and the rarity tier, for every Épique or Légendaire sale and any sale at the current settings version's feed threshold times its rarity's minimum price or more.
- `FeedEntries`, `NewFeedEntries` and `VisibleFeedEntry` show a sale entry whatever the buyer's visibility, unless the buyer is banned or deleted. Every other kind keeps its rule.
- The entry carries no amount; readers take the price from the listing's final price.

**Never:**
- No rendering, no live broadcast, no filter (the next story). No new operation: the handler runs in the sale's transaction and publishes nothing. No edit of `ReleasePlayer`, which already deletes every entry naming the player.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The threshold and the minimum price are read from the current settings version when the sale settles, not from the version the listing was made under, as the epic says ("current version").
- The notable-sale test lives on `Game::FeedEntry` beside the other `record_*` rules; the handler is `Game::Handlers::SaleFeed`, written like `CardRepostedFeed`.
- The entry's time is the event's timestamp, so it sorts with the other entries.
- A listing id column without a foreign key: listings are never deleted, and a constraint would couple the feed table to the market's.
- The price index on open listings that story 7 needs is that story's own migration, sorted after these.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Épique or Légendaire sale | Any price | One entry, buyer as player | No error expected |
| Common sale at 10 times the minimum | Threshold 10, minimum 1,300, price 13,000 | One entry | No error expected |
| Same sale just below | Price 12,999 | No entry | No error expected |
| Settled twice | The handler runs again for a listing | Still one entry | ON CONFLICT DO NOTHING |
| Private buyer | Buyer's visibility private | Entry listed to every viewer | No error expected |
| Banned or deleted buyer | Account removed | Entry hidden | No error expected |
| Unknown kind | A row of another kind | Refused by the check | Database error |

</frozen-after-approval>

## Code Map

- `db/migrate/20261110160000_*` to `20261110160002_*` -- column and checks, concurrent unique index, validation
- `app/domains/game/app/models/game/feed_entry.rb` -- `KINDS`, `record_sale`
- `app/domains/game/app/handlers/game/handlers/sale_feed.rb`, `config/initializers/event_store.rb` -- the handler and its subscription
- `app/domains/game/app/models/game/visibility.rb`, `queries/game/feed_entries.rb`, `new_feed_entries.rb`, `visible_feed_entry.rb` -- the sale exception

## Tasks & Acceptance

**Execution:**
- [ ] Migrations and the sale rule on `FeedEntry`
- [ ] Handler and subscription
- [ ] Visibility exception in the three feed readers
- [ ] Tests: model, handler, queries, migration check

**Acceptance Criteria:**
- Given a sale at the threshold settles, then the feed holds one sale entry naming the buyer, visible to every viewer unless the buyer is banned or deleted.

## Implementation Notes

Built as planned; nothing was run. The sale rule sits in `FeedEntry.record_sale`; `Visibility.sale_listed?` is the one test of a sale buyer's account, used by the three readers. Migrations `20261110160000` to `20261110160002`; `db/schema.rb` is left to be regenerated.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
