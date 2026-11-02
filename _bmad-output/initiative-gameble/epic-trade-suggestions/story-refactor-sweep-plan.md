---
title: 'Refactor sweep'
type: 'refactor'
ticket: 6
created: '2026-11-02'
status: 'built'
baseline_revision: 'ddcb5b303cc01fe02644e757004b66f294af6398'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Cleanup only, scoped when it starts from the epic's build records and the review findings deferred during it.

**Approach:** Split the 235-line `Game::TradeSuggestions` query into small named objects, compute the declined pairs once per call, and give batched held-games reads one home.

</intent-contract>

## Implementation Notes

Oneshot: a mechanical move of existing code with no new behavior. The epic's plans carry no deferred findings, so the sweep followed the known candidates.

- `Game::TradeSuggestions` keeps `call`, `still_spared`, `Result`, `Suggestion`, `Line`; SQL and spare building moved to `TradeSuggestions::FreeEditions`, `OpenTrades`, `DeclinedByFriend`, `Spares`.
- The two open-trade SQL strings that differed only by side became one parameterised string; `on_holder_side` reuses it.
- `declined_by_friend` ran twice per call; it now runs once and is passed down.
- `GameSetGaps` no longer owns a held-games SQL; `HeldGames.among_players` holds the batched read beside the single-player one.
- Left alone: `trades_helper`, `trade_suggestions_helper`, the trade views and the Stimulus controller (every helper is used, no duplication found); `GameSetGaps` gap logic stays batched, since `GoalNeeds` is per player and would multiply queries.

## Verification

- rubocop, `script/check_file_sizes`, `script/check_planning_references`, `bundle exec packwerk check`, `bin/rails zeitwerk:check` -- clean. Suites run later in the main tree.

## Review Triage Log

### 2026-11-02 - Review pass
- verdicts: 0 findings - high 0, medium 0, low 0, false 0, maybe-false 0

## Auto Run Result

- Summary: trade suggestions split into FreeEditions, OpenTrades, DeclinedByFriend and Spares; declined pairs read once; batched held-games read moved to `HeldGames.among_players`.
- Review: 0 findings. Follow-up review recommended: false.
- Verification: static checks only (rubocop, size, planning-reference, packwerk, zeitwerk); suites not run by author's instruction.
- Residual risk: the budget and flat-query tests have not run on this change.
