---
title: 'A copy for sale or in a trade stays owned but stops counting as a duplicate'
type: 'feature'
ticket: ''
created: '2026-11-14'
status: 'built'
baseline_revision: 'bb7197a96ecdbf386c690ae6b223f201070868c9'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A copy put up for sale (or offered in a pending trade) is reserved (`game_holdings.reserved`), but the collection ignores it: the tile still reads "x2", the DOUBLONS filter and the report's duplicate count still treat it as a spare, and the card detail says "2 exemplaires". A player can take their last free copy for a duplicate and sell it by mistake.

**Approach:** The reserved copy stays owned (set completion, unique counts and "Cartes totales" unchanged) but is counted apart. Duplicates count only free copies (`quantity - reserved`), and the owner sees why a copy is set aside: "1 en vente" or "1 en échange".

Decisions (author, 2026-11-14): option "Compté à part"; trade reservations follow the same rule with a distinct label.

## Boundaries & Constraints

**Always:** A copy's reason is derived, not stored: copies on sale = the player's open listings (`Game::Market::Listing.open_now`) of that edition; copies in a trade = reserved minus on sale, never below 0. The reason tags show only to the collection's owner (a trade reservation is private). Every string in `en.yml` and `fr.yml`, French plurals with `zero`.

**Never:** No schema change, no change to how operations reserve or release copies, no change to the market's sale/entrust grids or the trade picker (they already count free copies). No database id in markup.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Spare on sale | 2 copies, 1 listed | Tile "x2" + "1 en vente"; not under DOUBLONS; report duplicates −1; detail "2 exemplaires, dont 1 en vente" | — |
| Only copy on sale | 1 copy, listed | Tile shows no badge, but "1 en vente"; card still owned, sets still complete | — |
| Sale and trade | 3 copies, 1 listed, 1 in a trade | "1 en vente" and "1 en échange"; detail "3 exemplaires, dont 1 en vente et 1 en échange"; not a duplicate | — |
| Spread over editions | S1 ×2 (1 listed) + S2 ×1 | 2 free copies → still under DOUBLONS, report counts 1 duplicate | — |
| Friend's / public grid | Friend has 2 copies, 1 listed | No reason tag; DOUBLONS filter counts free copies | — |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/collection_states.rb` -- `HELD_GAMES` subquery sums `quantity` per game; `"duplicates" => "held_games.copies >= 2"`. Add a free-copies sum and test it instead.
- `app/domains/game/app/queries/game/held_games.rb` -- `EDITIONS`/`Edition` feed the grid tiles; `copies` stays the full count (badge "x2" unchanged).
- `app/domains/game/app/queries/game/tier_counts.rb` -- copies per rarity for the report's "Cartes totales"; leave as is.
- `app/views/library/_report.html.erb` -- computes `duplicates = copies - unique`; switch to a passed-in free-based count. Rendered from `app/views/library/_collection.html.erb:7` with locals from `CollectionGridLoading#load_summary` (`app/controllers/concerns/collection_grid_loading.rb:127`).
- `app/views/library/_slots.html.erb` -- collection grid tile (`collection-slot__counts`, then `collection-slot__price` under the card). Note: its local `set_apart` already means "owned face toggle"; do not reuse that name. Also appended by `app/views/library/cards.turbo_stream.erb`.
- `app/controllers/concerns/collection_grid_loading.rb#load_grid` -- builds `@slots` as `[view, held, price]`; `grid_owner`/`grid_another?` (overridden in `public_profiles_controller.rb`, `cards_controller.rb`).
- `app/views/library/_album.html.erb` + `app/controllers/concerns/set_album_loading.rb` (`Slot` Data, `album_slots`) -- set album tiles; callers `library_controller.rb:66` (own), `custom_sets_controller.rb:23` (own), `public_profiles_controller.rb:29` (other).
- `app/controllers/cards_controller.rb#show` + `app/views/cards/_detail.html.erb:134-138` -- `@copies` and the "Exemplaires" fact (`card_details.copies`).
- `app/domains/game/app/queries/game/market/card_entrustment.rb` -- pattern for a per-card SUM over holdings joined to `catalog_card_seasons`.
- `app/frontend/styles/collection-grid.css` (486 lines, limit 500) and `app/frontend/styles/trades-board.css:244` (`.trade-card__reserved`, the sunken reserved-tag look to echo).
- Tests: `test/domains/game/collection_states_test.rb`, `held_games_test.rb`, `tier_counts_test.rb`, controller/view tests of library and cards.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/reserved_copies.rb` -- new `Game::ReservedCopies.call(player, card_ids:)` → `{ card_id => Reserved(on_sale:, in_trade:) }` for cards with reserved copies; plus `.duplicates(player)` = Σ over held games of max(free − 1, 0) -- one place owns the reason split and the free-based duplicate count.
- [x] `app/domains/game/app/queries/game/collection_states.rb` -- DOUBLONS keeps games with ≥ 2 free copies.
- [x] `app/controllers/concerns/collection_grid_loading.rb`, `set_album_loading.rb`, `library_controller.rb`/`custom_sets_controller.rb` as needed -- load reservations for the page's cards only when the viewer owns the grid; pass the free-based duplicate count to the report.
- [x] `app/views/library/_slots.html.erb`, `_album.html.erb`, `cards.turbo_stream.erb`, `_report.html.erb`, `_collection.html.erb` -- render the reason tags under the card (readable by screen readers) and the new duplicate count.
- [x] `app/controllers/cards_controller.rb`, `app/views/cards/_detail.html.erb` -- "N exemplaires, dont 1 en vente et 1 en échange" (parts joined with `to_sentence`).
- [x] `app/frontend/styles/collection-grid.css` -- tag style under the card, centred, small label, sunken box like the trade reserved tag.
- [x] `config/locales/en.yml`, `fr.yml` -- `library.grid.reserved.on_sale|in_trade` (pluralised, fr `zero`), `card_details.copies_reserved` wrapper and its parts.
- [x] Tests -- query tests for every matrix row; DOUBLONS state test; controller/view tests that the owner sees the tags and a public profile does not; card detail sentence.

**Acceptance Criteria:**
- Given a listing is cancelled, withdrawn or sold, when the collection reloads, then its tag disappears and the counts follow the remaining copies.
- Given no copy is reserved, when any collection screen renders, then the markup is unchanged from today.

## Design Notes

Reason split, per edition then summed per game:
```sql
SELECT cs.card_id, SUM(h.reserved), COALESCE(SUM(listed.n), 0)
  FROM game_holdings h JOIN catalog_card_seasons cs ON cs.id = h.card_season_id
  LEFT JOIN (SELECT card_season_id, COUNT(*) n FROM game_market_listings
              WHERE seller_id = :player_id AND status = 'open' GROUP BY card_season_id) listed
         ON listed.card_season_id = h.card_season_id
 WHERE h.player_id = :player_id AND h.reserved > 0 AND cs.card_id IN (:card_ids)
 GROUP BY cs.card_id
```
in_trade = reserved − on_sale (clamped at 0).

## Verification

**Commands:**
- `bin/rails test test/domains/game test/controllers` -- expected: green
- `bundle exec packwerk check && bin/rails zeitwerk:check && npm run lint:css && npm run format:check && script/check_file_sizes && script/check_planning_references` -- expected: clean
- `bin/rails test test/system/<collection/card detail files touched> -n /<name>/` -- expected: green

**Manual checks:**
- In dev, list the second copy of a card: tile "x2" + "1 EN VENTE", absent from DOUBLONS, detail sentence, report duplicates down by one.

## Implementation Notes

- Tag styles live in `app/frontend/styles/collection-slot-reasons.css` (`collection-grid.css` was at 486/500 lines).
- `to_sentence` gets its connector from `card_details.reserved.and`: the app has no `fr.support.array` keys.
- The main grid keeps its existing "x1" badge for a single copy (pre-existing; only the album hides it below 2).
- Review: reason tags moved over the card's bottom edge so every slot keeps its 2:3 box.

## Review Triage Log

Pass 1 (quick): high 0 · medium 1 · low 2 · false 0 · maybe-false 0 · rejected 1.

| Finding | Verdict | Route | Evidence / action |
|---|---|---|---|
| Reserved slot drops `aspect-ratio`, so a skipped slot (content-visibility, Turbo restore, appended page) changes height when it renders | medium | patch | `collection-grid.css:163-188` sizes slots by 2:3 and `contain-intrinsic-size`; tags now overlay the card's bottom edge, override removed |
| Only copy on sale shows "x1" on the grid, matrix says "no badge" | low | reject | Pre-existing: `_slots.html.erb` always printed "x1" and `library_controller_test.rb:139` expects it; the change adds the tag, which is the row's point; covering test added |
| English "%{count} in trades" wrong for several copies in one trade | low | patch | `trade_steps.rb:96-98` reserves `quantity` copies per offer; `other` now "%{count} in trade" |
| No test for custom-set album, turbo-stream page, only copy on sale | low | patch | Tests added in `collection_reserved_copies_test.rb` |
