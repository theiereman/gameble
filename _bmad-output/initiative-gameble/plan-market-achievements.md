---
title: 'Market achievements, the hardest unlocking a suited avatar'
type: 'feature'
ticket: ''
created: '2026-11-13'
status: 'built'
baseline_revision: '555207ecfc5b167822845cb4256cd3f980f4c8bb'
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

**Problem:** The market (auctions in PiCoins) has no achievement of its own; only a purchase re-checks the existing ones. The author wants market achievements that take skill or persistence, and the hardest one unlocks a new avatar wearing a suit.

**Approach:** Add five catalogue entries read from the market tables already on the branch (listings and bids), re-check them for both the seller and the winner of every sale, and add one achievement-unlocked avatar drawn by the pixel-art exporter.

## Boundaries & Constraints

**Always:** Every metric is one SQL subquery in `AchievementProgress::METRIC_SQL`, reading only sold listings and their bids; voided and `raise` bids never count. New strings in both `en.yml` and `fr.yml`, in the catalogue's corporate deadpan. Pixel files come from `node script/pixel_art/export.mjs`.

**Decisions (author, 2026-11-13):** a resale counts at 2× the purchase price or more; Hostile Takeover means losing the lead (`outbid` rows, not `beaten`) at least twice on a listing you then win; Competitive Tender needs 3 distinct bidders; the five tiles show even while the market is closed. Insider Trading counts five *different editions* resold at 2×, so one cheap purchase cannot justify several resales.

**Never:** No migration, no new event, no change to how auctions settle. No retroactive backfill run (the market is not open in production). No card back for these achievements.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Comeback win | Player has 2 `outbid` bids on a listing they won | `comeback_wins` = 1, Hostile Takeover granted | — |
| Comeback too easy | 1 `outbid` + several `beaten` bids on a listing they won; or 2 `outbid` but another player won | 0 | `:not_reached` |
| Bidding war | Player's sold listing drew bids from 3 distinct players | `most_bidders_on_a_sale` = 3 | — |
| Voided bidder | 3rd bidder's lead was voided through `VoidLead` (their rows become `outbid`→`lost` plus one `voided`) | that player not counted: 2 | — |
| Doubled resale | Bought edition at 5,000, later listed and sold it at 10,000 | `doubled_resales` = 1 | — |
| Resale under double, or sold before the purchase | 9,999 after 5,000; or the sale listing created before the purchase settled | 0 | — |
| Other player's purchase | Seller never won that edition | 0 | — |
| One purchase, many resales | Won one copy at 5,000, sold three copies of that edition at 10,000+ | `doubled_resales` = 1 | — |
| Seller and winner checked | A sale settles | grant job enqueued for `seller_id` and `winner_id` | — |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/achievements.rb` -- `CATALOGUE` of `Achievement(key, metric, threshold)`; append the five entries at the end.
- `app/domains/game/app/queries/game/achievement_progress.rb` -- add four SQL constants and their `METRIC_SQL` keys; file is ~200 lines, under the 400 limit.
- `app/domains/game/app/handlers/game/handlers/achievements.rb` -- `Game::Market::AuctionSold => [ :winner_id ]`; add `:seller_id` (event data has it, `auction_settlement.rb:33`).
- `app/domains/game/app/models/game/avatars.rb` -- `UNLOCKING_ACHIEVEMENTS`; add `"executive" => "insider_trading"`. Unlocked avatars need no claim (`GrantAchievement#nothing_to_claim?` only checks card backs).
- `app/helpers/achievements_helper.rb` -- `GLYPHS` maps every key to a glyph; `fetch` raises on a missing one.
- `script/pixel_art/export.mjs` -- `ACHIEVEMENT_GLYPHS` (7×7 `#`/`.` grids, line ~293), avatars as 16×16 grids with a legend (e.g. `avatar-guardian`, line ~658), file descriptions (line ~1727).
- `config/locales/{en,fr}.yml` -- `avatars.names`, `achievements.conditions`, `achievements.names`.
- Schema facts: `game_market_listings` (`seller_id`, `leader_id` = winner once `status = 'sold'`, `card_season_id`, `final_price`, `sold_at`, `created_at`); `game_market_bids` (`listing_id`, `player_id`, `outcome` in leading/outbid/beaten/raise/won/lost/voided). Usable indexes: listings `(seller_id, status)`, `(card_season_id, sold_at) WHERE sold`; bids `(player_id, listing_id)`, `(listing_id, id)`.
- Bid rows: `VoidLead#void` (`market/void_lead.rb:35`) turns the removed leader's `leading` into `outbid`, then adds a `voided` row; `Bid.close_out` later turns other players' `outbid` into `lost` but leaves the winner's rows. Exclude a bidder by `NOT EXISTS` a `voided` row of theirs on the listing; never count `raise`.
- Tests to update: `test/domains/game/opening_pace_achievements_test.rb:28` (catalogue ends with the opening pace pair, size 25); `test/controllers/profile_avatars_controller_test.rb:28,33` (19 avatars, 3 locked); `test/domains/game/market/close_auction_events_test.rb:33-44` (grant "for the winner only"); `test/domains/game/achievements_test.rb:755-760` (event data lacks `seller_id`, expects 10 jobs → 11); `test/domains/game/choose_avatar_test.rb:71-72` (every avatar key); `test/domains/game/achievement_board_test.rb:70-74` (countable keys: add `competitive_tender`, `quarterly_targets_met`, `insider_trading`). Fixtures for sales: `test/support/market_sales.rb` (`sold!`), `market_listings.rb`, `market_settings.rb` (`open_market!`).

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/achievement_progress.rb` -- add `cards_sold`, `most_bidders_on_a_sale`, `comeback_wins`, `doubled_resales` SQL -- one subquery each, starting from the indexed side (seller's sold listings; player's bids).
- [x] `app/domains/game/app/models/game/achievements.rb` -- append `hostile_takeover` (comeback_wins, 1), `competitive_tender` (most_bidders_on_a_sale, 3), `capital_gain` (doubled_resales, 1), `quarterly_targets_met` (cards_sold, 25), `insider_trading` (doubled_resales, 5).
- [x] `app/domains/game/app/handlers/game/handlers/achievements.rb` -- re-check the seller too.
- [x] `app/domains/game/app/models/game/avatars.rb` -- `executive` unlocked by `insider_trading`.
- [x] `script/pixel_art/export.mjs` -- glyphs `takeover`, `gavel`, `growth`, `ledger`, `briefcase`; `avatar-executive` (slicked dark hair, navy suit, white shirt, red tie) with its description; run the exporter.
- [x] `app/helpers/achievements_helper.rb` -- map the five keys to their glyphs.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- names and conditions for the five, avatar name.
- [x] `test/domains/game/market/market_achievements_test.rb` -- one test per matrix row, plus the handler enqueueing both players.
- [x] Update the six tests named in the Code Map.

**Acceptance Criteria:**
- Given a player who meets Insider Trading, when the sale settles, then the achievement is granted and the Executive avatar becomes selectable on the Me page.
- Given the achievements page, when a player has made 3 of 5 doubled resales, then the Insider Trading tile shows `3 / 5`.

## Design Notes

Doubled resale, counted once per edition:

```sql
SELECT COUNT(DISTINCT sale.card_season_id) FROM game_market_listings AS sale
 WHERE sale.seller_id = :player_id AND sale.status = 'sold'
   AND EXISTS (SELECT 1 FROM game_market_listings AS bought
                WHERE bought.card_season_id = sale.card_season_id AND bought.status = 'sold'
                  AND bought.leader_id = :player_id AND bought.sold_at <= sale.created_at
                  AND bought.final_price * 2 <= sale.final_price)
```

Alt accounts can fake resales; the existing alt-signal detector already flags one-sided price patterns, so no extra guard here.

## Verification

**Commands:**
- `bin/rails test test/domains/game/market/market_achievements_test.rb test/domains/game/market/close_auction_events_test.rb test/domains/game/choose_avatar_test.rb test/domains/game/achievements_test.rb test/domains/game/opening_pace_achievements_test.rb test/domains/game/achievement_board_test.rb test/controllers/achievements_controller_test.rb test/controllers/profile_avatars_controller_test.rb` -- expected: green
- `node script/pixel_art/export.mjs --check`, `bundle exec packwerk check`, `bundle exec i18n-tasks health`, `bundle exec rubocop` on touched files, `script/check_planning_references`, `script/check_file_sizes` -- expected: clean

## Implementation Notes

- Metrics run through the real auction path where the matrix names one (comebacks, bidders, voided lead via `PlaceBid`, `VoidLead`, `CloseAuction`); resales use `sold!` rows.
- Beyond the six tests named in the Code Map, four more hard-coded the catalogue: `achievements_controller_test.rb` (to-earn names, countable bars), `pages_controller_test.rb` and `public_profiles_controller_test.rb` (25 → 30). Added an achievements-page test for the `3 / 5` Insider Trading tile.
- `i18n-tasks health` already fails on `develop`'s unused keys and normalization; no new key is missing or unused.

## Plan Change Log

## Review Triage Log

| Finding | Verdict | Route | Evidence |
|---|---|---|---|
| fr `capital_gain` / `insider_trading` conditions read as "resell twice" | low | patch | "au moins deux fois le prix" without a preposition first parses as two resales; now "pour au moins le double du prix payé". |
| `COMEBACK_WINS_SQL` counts the `outbid` row a lead void leaves | low | patch | `VoidLead#void` displaces the leader to `outbid`; nothing stops an unbanned player rebidding, so one real loss plus the void grants Hostile Takeover. Added the same `NOT EXISTS voided` guard as the bidder count, with a test. |
| `pages_controller_test.rb:979` hunk belongs to the traded-volume change | false | reject | True of the working tree, not a defect: the hunk is committed with the traded-volume change, not with this one. |
