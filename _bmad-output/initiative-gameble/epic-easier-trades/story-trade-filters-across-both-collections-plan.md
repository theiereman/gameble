---
title: 'Trade filters across both collections'
type: 'feature'
ticket: '2'
created: '2026-10-19'
status: 'built'
baseline_revision: '3eded637bd86575368f9addf3e2a00fb3d06d35e'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The trade picker narrows a side only by title and rarity, so finding a worthwhile trade with a friend who has a large collection means browsing every card (issue 63, point 2).

**Approach:** Each picker card carries, besides its edition's copies, the owner's and the other player's copies of the same game across editions (the unit the collection shows since 13.15), computed in the helper from the holdings already loaded. The picker gains a group of three chips per side, friend: their duplicates, missing from mine, both own; own: my duplicates, missing from theirs, available. Chips AND together, AND with the rarity chips (still OR among themselves) and with the title search, through one per-side filter state that entry 3 will lift to the board.

## Boundaries & Constraints

**Always:**
- Game unit for every chip comparison: a card's game is its `CardView#id` (the slug); copies are summed over every edition the player holds with `quantity > 0`. Duplicates = owner's game copies ≥ 2; missing = other player's game copies = 0; both own = other player's game copies ≥ 1 (the owner holds it by construction); available = the card's `max` ≥ 1 (unreserved copies of that edition, own side only).
- Filters only hide cards: a placed card filtered out stays in the selection, the count and the submitted form; `max`, the selection limit, the stepper and what may be traded are unchanged (a single copy can still be offered).
- The counts are keyed by the card's `key` (`trade_card_key`) inside each card hash; never a database id in props.
- One filter state type per side (`query`, `rarities`, `chips`) with an empty default, exported from `app/frontend/lib/trade_board.ts`; the picker holds it locally for now.
- Clear resets search, rarities and chips; the match count and no-match state count every filter.
- The empty own side and its help line (entry 6) keep working; sending stays gated by the friend's side only.
- Every string in `en.yml` and `fr.yml` under `trades.island.strings`, with matching `TradeBoardStrings` fields. No new query (holdings and card views are already loaded), no `style` attribute, no new `gameble:*` event, no planning ids or explanatory comments in code.

**Never:** No filter state on the board or kept across reopenings (entry 3), no phone folding (entry 3), no change to face rendering or paging (entry 4), no season/set/genre filter or sorting, no server round trip, no change to the operations or to `Game::HeldCopies`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Their duplicates | friend side; cards with friend game copies 1, 2, 3 | cards with 2 and 3 shown | — |
| Duplicates across editions | friend holds S1 Rare ×1 and S2 Epic ×1 of Hades | both Hades cards carry copies 2, so both match their duplicates | — |
| Missing from mine | friend side; I hold Hades only in S1 | the friend's S2 Hades card is not missing; a game I hold in no edition is | — |
| Both own | friend side | cards whose game I hold in any edition | — |
| My duplicates / missing from theirs | own side | game copies ≥ 2 / friend holds no edition of the game | — |
| Available | own side; a card with every copy reserved | hidden by "available"; cards with `max` ≥ 1 shown | — |
| Combination | Rare + Epic, their duplicates, missing from mine | exactly the Rare or Epic cards that match both chips | — |
| Contradiction | missing from mine + both own | no card, the no-match message and clear action | — |
| Placed card hidden | a placed card filtered out, then PLACER | stays placed, counted and submitted | — |
| Clear | clear action with chips on | every card back, chips unchecked, focus on search | — |

</intent-contract>

## Code Map

- `app/helpers/trades_helper.rb` -- `trade_island_side` (:162-180) builds each card hash `{ key, title, rarity, owned, reserved, max, face }` from `held` (`Game::HeldCopies` rows keyed by card_season_id) and `picks` (`Catalog::CardViews` of both players' held card-seasons). Add `copies` (owner's game copies) and `otherCopies` (other player's game copies), from a private helper grouping a `held` hash by `picks[id].id` and summing `quantity`. Pass the other side's held hash from `trade_board_props` (:126-139) and `trade_draft_props` (:141-151): friend side gets `own_held` as other, own side gets `friend_held`. `trade_island_strings` (:189-197) camelizes `trades.island.strings` deeply.
- `app/frontend/components/TradeBoard.tsx:11-19, 35-69` -- `TradeCard` gains `copies`, `otherCopies`; `TradeBoardStrings` gains the chip legend and labels.
- `app/frontend/lib/trade_board.ts:117-128` -- `filterCards(cards, query, rarities)`: change it to take the per-side filter state; add the chip type, the chip list per side and their predicates as data, an empty filter state and a "filtering" predicate. `fold` stays.
- `app/frontend/lib/trade_board.test.ts:124-155` -- existing `filterCards` tests to adapt; add the chip rows.
- `app/frontend/components/TradePicker.tsx` -- `query`/`rarities` state (:24-26), `visible` (:50), `filtering` (:51), `clearFilters` (:57-61), the rarity fieldset (:122-135) to mirror for the chip group, labels from strings keyed by side and chip.
- `app/frontend/styles/trades.css:663-676` -- picker filter layout; reuse `.filters__group`, `.filters__legend`, `.filter-chip*`; add only what the second group needs.
- `config/locales/en.yml:~1209-1225`, `fr.yml:~1255-1272` -- `trades.island.strings`; add `compare_legend` and `chips.{friend,own}.*`.
- `test/controllers/trades_controller_test.rb:418-464` -- the counter island props test asserts card hashes with `values_at("key", "owned", "reserved", "max")`; extend or add a test for `copies`/`otherCopies`, including a second edition (pattern: `test/packs/game/held_games_test.rb:6-13`, a published season 2 and `insert_all!` of a card-season of the same card), and the draft board (`new_trade_path(friend:)`).
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md:109` -- Copy deck, Card picker row: add the chip labels.
- Do not touch `test/system/trades_test.rb` beyond selector fixes (system tests are disabled, not run).

## Tasks & Acceptance

**Execution:**
- [x] `app/helpers/trades_helper.rb` -- `copies` and `otherCopies` per card, in the game unit, from the loaded holdings -- the island compares the two collections.
- [x] `app/frontend/lib/trade_board.ts` + `trade_board.test.ts` -- the per-side filter state, chips per side, `filterCards` over it; vitest every matrix row and combinations of chips, rarities and search -- the pure filter.
- [x] `app/frontend/components/TradeBoard.tsx`, `TradePicker.tsx`, `app/frontend/styles/trades.css` -- types, the chip group under the rarities, clear and count including chips -- the picker UI.
- [x] `config/locales/en.yml`, `fr.yml` -- legend fr "Collections" / en "Collections"; friend fr "Ses doublons", "Absentes de ma collection", "En commun" / en "Their duplicates", "Missing from mine", "We both own"; own fr "Mes doublons", "Absentes de sa collection", "Disponibles" / en "My duplicates", "Missing from theirs", "Available" -- both locales.
- [x] `test/controllers/trades_controller_test.rb` -- counts on the counter and draft boards, a second edition counted in the game, no id in props -- the server side of the verify line.
- [x] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- chip labels in the Copy deck.

**Acceptance Criteria:**
- Given Hugo drafting with Lea, when he opens Lea's picker and checks Rare, Epic, their duplicates and missing from mine, then only Lea's Rare or Epic cards she holds twice or more (any editions) and whose game Hugo holds in no edition remain.
- Given Hugo holds Hades in S1 only and Lea holds it in S2, then Lea's S2 Hades card carries `otherCopies` ≥ 1 and is not shown under missing from mine.
- Given a placed card hidden by a chip, when Hugo places and sends, then it is submitted; a card with one copy stays placeable with every chip off.

## Implementation Notes

- No CSS change: the chip group reuses `.filters__group`, `.filters__legend` and `.filter-chip*` and stacks in `.trade-picker__filters` like the rarity group, which has no rule of its own either.
- `filterCards` takes the per-side `SideFilter` (`query`, `rarities`, `chips`); `EMPTY_FILTER`, `filtering` and `toggled` live beside it in `trade_board.ts`, ready for entry 3 to lift the state to the board.
- Game copies come from a private `trade_game_copies(held, picks)` grouping the loaded holdings by `CardView#id`; no query added.
- Matrix audit: every filter row is covered by vitest (`trade_board.test.ts`) and the game-unit counts across editions by `trades_controller_test.rb`. "Placed card hidden" and "Clear" are picker interactions with no running test: the repo has no React component tests and system tests are disabled. By reading, `onPlace(selection)` and `sideCount(selection)` never pass through the filtered list, and clear sets `EMPTY_FILTER` and focuses the search; the disabled system test "the picker filters…" already exercises both for search and rarity.

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 1, maybe-false 0
- findings:
  - `[false]` `[reject]` the plan's UI task names `trades.css` but the diff leaves it unchanged — no bad outcome: the new fieldset is styled by `.filters__group`/`.filters__legend` (`collection.css`) and stacks in the flex column like the rarity group; recorded in Implementation Notes, and the only fix would edit the plan.
  - `[low]` `[reject]` the third acceptance criterion and the "Placed card hidden" and "Clear" rows have no automated test — behavior verified by reading (selection never filtered, clear resets `EMPTY_FILTER`); a test needs component-test infrastructure the repo lacks, and system tests are disabled by policy.
  - `[low]` `[reject]` `TradePicker.tsx:63` widens the side's chip labels to `Partial<Record<Chip, string>>`, losing the per-side type link — a missing label would only render an empty chip; the controller test asserts all six labels, and keeping the link needs a typed per-side accessor, more than a direct correction.

## Design Notes

The ticket compares "in the unit the collection shows", which 13.15 made one card per game across editions, while the picker still lists editions (13.15 kept trades per edition). So every chip compares games: a friend's S1 Rare ×1 and S2 Epic ×1 of Hades both match "their duplicates", since giving either still leaves the game in their collection, as the collection's DOUBLONS state counts it. The edition's own `owned` badge is unchanged. "Missing" and "both own" read the same `otherCopies` on either side, so one predicate serves each.

```ts
type Chip = "duplicates" | "missing" | "shared" | "available"
const CHIPS = { friend: ["duplicates", "missing", "shared"], own: ["duplicates", "missing", "available"] }
// duplicates: copies >= 2 · missing: otherCopies === 0 · shared: otherCopies > 0 · available: max >= 1
```

## Verification

**Commands:**
- `npm run test:js` and `npm run typecheck` -- expected: all pass
- `bin/rails test test/controllers/trades_controller_test.rb test/helpers` -- expected: all pass
- `bin/rails test`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bin/rubocop` -- expected: green (prefix every Rails command with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1802`; the database is already created and loaded; never run system tests)

## Auto Run Result

- **Summary:** each picker card carries `copies` (its holder's copies of the game over every edition) and `otherCopies` (the other player's), computed from the holdings already loaded; the picker gains a "Collections" chip group per side — friend: their duplicates, missing from mine, both own; own: my duplicates, missing from theirs, available — that AND together and with the rarity chips and search through one per-side `SideFilter`. Selection, limits and sending are unchanged.
- **Files:** `app/helpers/trades_helper.rb` (game copies per card), `app/frontend/lib/trade_board.ts` (+ test: chips, `SideFilter`, `filterCards`), `app/frontend/components/TradeBoard.tsx` (types), `TradePicker.tsx` (chip group, clear, count), `config/locales/{en,fr}.yml` (legend and chip labels), `test/controllers/trades_controller_test.rb` (counts on counter and draft boards, second edition), `ux-gameble/EXPERIENCE.md` (Copy deck, chip labels).
- **Review:** quick; 3 findings: 0 patched, 0 deferred, 3 rejected (1 false, 2 low) with reasons in the triage log. Follow-up review not recommended (nothing patched).
- **For the author to approve:** the game unit for "duplicates" too (a friend's S1 ×1 and S2 ×1 of a game both show under their duplicates while each card reads ×1); the chip labels fr "Ses doublons", "Absentes de ma collection", "En commun", "Mes doublons", "Absentes de sa collection", "Disponibles", legend "Collections".
- **Verification:** `bin/ci` green (2709 runs, 0 failures); `npm run test:js` 416 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` clean.
- **Residual risks:** not seen in a browser; the second chip row shortens the grid on a phone until entry 3 folds the filters.
