---
title: 'Mutual suggestions come first, at a cost that does not grow with friends'
type: 'feature'
ticket: '3'
created: '2026-11-02'
status: 'in-review'
baseline_revision: '6a713df243a1249cda9384b47c7d9ca76f5b7529'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Suggestions are one-sided: a friend who also needs a spare of the player is not put first, and the player's side stays empty.

**Approach:** `Game::TradeSuggestions` reads each friend's goals on game sets only (batched, `Game::GameSetGaps`), marks a friend mutual when the player spares a game those goals miss, ranks mutual first, places up to 4 of the player's spares on the give side, and fills suggestions in friend order without placing a game twice on either side.

## Boundaries & Constraints

**Always:** AD-38 order (mutual, spared games count, friendship age, token); the friend side reads game-set goals only; give lines never carry the friend's goals; query count independent of the number of friends; budget 200 ms of server time on 100 friends with 5 goals of 50-game sets.

**Never:** a cache, a stored suggestion or a schema change; touching the trade board views (`_side`, `_line`, `_faces`, `trade_card_faces`, `trade_pick_label`).

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/game_set_gaps.rb` -- batched missing games of friends' game-set goals
- [x] `app/domains/game/app/queries/game/trade_suggestions.rb` -- mutual ranking, give side, double-placement guard
- [x] `app/helpers/trade_suggestions_helper.rb`, locales -- mutual summary and opener name, current-row match on both sides
- [x] tests: query (mutual, custom-set goal, cap, dedupe, 1 vs 30 friends, 200 ms), controller (mutual row and send)

**Acceptance Criteria:**
- Given a mutual and a one-sided friend, then the mutual one is listed first; a friend's custom-set goal never makes it mutual; sending proposes both sides; the query count holds with 1 and 30 friends; the read stays under 200 ms on the seeded worst case.

## Implementation Notes

Route full by size. No migration and no cache: the budget test is written but was not run here (suites run later in the main tree); if it fails, AD-38's deferred cache needs bmad-architecture before shipping. The player's own spares are read once for all friends; open trades on the player's side are one batched read.

## Plan Change Log

## Review Triage Log
