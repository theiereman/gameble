---
title: 'Trade core: propose, cancel, decline and reserve'
type: 'feature'
ticket: '4'
created: '2026-10-07'
status: done
baseline_revision: '47cea18b653361d83cd2a5ab133491a1eade4cca'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Friends cannot trade: Game has friendships (5.1) but no trade data and no operation that reserves an offer (R2, R3, R4).

**Approach:** In `Game`, add `game_trades` and `game_trade_items` and three operations, `ProposeTrade`, `CancelTrade`, `DeclineTrade`, each one transaction with one identifier-only event, locking in the order of AD-10 (both bank locks ascending, then the proposer's holdings ascending card-season). No screen, no controller.

**Decisions (autonomous run, author away):** items are passed as `{ card_season_id => quantity }` hashes (`offer:`, `request:`); "reserved up to the copies owned minus those reserved elsewhere" means the offer is refused (`:insufficient_copies`) when a line exceeds `quantity - reserved`, never silently trimmed; a trade stores its pair (`low_player_id`, `high_player_id`) and `proposer_id`; status is `open | cancelled | declined | accepted | expired` (the last two are written by later tickets); `expires_at` is stored (sent + 7 days) but an open trade past its expiry still counts as open until the expiry job (later ticket) closes it; the event is published on the proposer's stream (`Game::TradeProposed` / `TradeCancelled` / `TradeDeclined`, data `{ trade_id:, proposer_id:, recipient_id: }`); only the proposer cancels, only the recipient declines; requested cards must exist in Catalog but are not reserved nor checked owned; banned or unknown recipient counts as not a friend; coding is done directly in this session.

## Boundaries & Constraints

**Always:** writes only through Game operations (AD-3); `quantity >= reserved >= 0` stays true; at most 4 distinct card-seasons per side, at least one, each quantity a positive integer; one open trade per pair also enforced by a partial unique index; locks taken in a fixed order (AD-10).

**Never:** accept, counter, expiry job, screens, controllers, presence, live trades; changing `Holding` quantity.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Propose | friends, free copies | open trade, offer reserved, `TradeProposed` | n/a |
| Not friends / self / banned | any | refused | `:not_friends` |
| Second trade for the pair (either direction) | open trade exists | refused | `:trade_already_open` |
| Bad sides | empty, >4 cards, quantity <= 0, unknown card | refused | `:invalid_offer` / `:invalid_request` |
| Card fully reserved or not owned | line > quantity - reserved | refused, nothing reserved | `:insufficient_copies` |
| Cancel / decline | open trade, right party | closed, offer released, one event | `:trade_not_found`, `:not_allowed`, `:trade_not_open` |

</frozen-after-approval>

## Code Map

- `db/migrate/…_create_game_trades.rb`, `db/schema.rb` -- tables, partial unique index on open pairs, checks.
- `packs/game/app/models/game/trade.rb`, `trade_item.rb` -- models.
- `packs/game/app/operations/game/{propose,cancel,decline}_trade.rb`, `models/game/trade_locks.rb` (lock order helper) -- operations.
- `packs/game/app/events/game/trade_{proposed,cancelled,declined}.rb` -- events.
- `config/locales/{en,fr}.yml` -- errors.game codes.
- Reuse: `Game::BankLock`, `Game::Friendship`, `Game::Holding`, `Game::OpenPack` concurrency test pattern.

## Tasks & Acceptance

**Execution:**
- [ ] migration, schema, models, events, operations, locales
- [ ] tests: operations, database constraints, concurrency (same card twice, opposite proposals, lock order)

**Acceptance Criteria:**
- Given two friends, when one proposes, then exactly the offered copies are reserved and a second trade for the pair is refused.
- Given two simultaneous proposals of the same last copy, then one succeeds and `reserved <= quantity`.
- Given two friends proposing to each other at once, then one succeeds and none deadlocks.

## Implementation Notes

Implemented directly in the main session. Quantity per line capped at 999 (`TradeItem::MAX_QUANTITY`). Same card on both sides is allowed. Known gap: `require_player` refuses a banned player, so a banned proposer cannot cancel and a banned recipient cannot decline; releasing offers at ban time belongs with the account-deletion/ban ticket (R6) and the expiry job.

## Plan Change Log

## Review Triage Log

Quick review (subagent), 0 high, 2 medium, 6 low. Patched: unbounded request quantity (cap 999), lenient Integer parsing (base 10 strings only), RecordNotUnique rescued only for the open-pair index, plan file name. Kept: banned party cannot close (deferred to R6/expiry), A-for-A trade allowed, :not_allowed before :trade_not_open.

## Verification

**Commands:**
- `bin/rails test` (minus card_face_visual_test), `bin/rubocop`, `bin/packwerk check`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `npm run test:js` -- all green
