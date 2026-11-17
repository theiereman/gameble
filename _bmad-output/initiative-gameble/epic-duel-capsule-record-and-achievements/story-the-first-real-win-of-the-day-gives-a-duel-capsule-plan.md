---
title: 'The first real win of the day gives a duel capsule'
type: 'feature'
ticket: '1'
created: '2026-11-17'
status: 'built'
baseline_revision: '852d5a6f006c857f9f9fe2acbe331c4e1b8a4e4d'
route: 'full'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: The winner's top-bar capsule chips do not update on the duel's closing push; they read the new capsule on the next page load.
    evidence: `PlayerStream` turns `Game::DuelFinished` into a duels notice only, and the event carries no capsule case.
  - summary: A published season with an empty tier makes `Game::DrawPool.current` raise inside the finishing move, as it already does in opening a capsule; the duel then cannot finish until the season is repaired.
    evidence: `Game::DuelCapsule.award` calls `Game::DrawPool.current` only for a granted win; a season cannot be published with an empty tier.
---

<intent-contract>

## Intent

**Problem:** A duel win gives nothing back, so there is no reason to duel again the same day or to play it honestly.

**Approach:** The finishing move draws one 3-card duel capsule for a winner none of whose moves were automatic and who has none for the UTC day the duel ends, records which of three cases applied on the duel, and the result screen, the special reserve, the canister and the Flukeometer read it.

## Boundaries & Constraints

**Always:** Expand/contract migrations (checks added not valid then validated, a concurrent index in its own migration); the grant runs in the finishing move's transaction under the winner's bank lock with the unique index as final guard; one event per operation.

**Never:** A capsule for a loss, a draw, an automatic move of the winner, a removed winner or a second win the same UTC day; PiCoins or cards moving between players.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First win of the day | winner, no automatic move, no duel capsule for the end day | one duel pack, `capsule: granted` | none |
| Second win the same UTC day | duel capsule exists for the end day | none, `capsule: already_won_today` | unique index refuses a racing insert |
| Automatic move of the winner | one of the winner's moves automatic | none, `capsule: automatic_move` | none |
| Loss, draw, removed winner | | none, no case recorded | none |

</intent-contract>

## Tasks & Acceptance

See the ticket entry; every task landed.

## Implementation Notes

- Migrations `20261117100000` (columns and the four swapped checks added not valid), `20261117100001` (validation), `20261117100002` (concurrent partial unique index on player and `duel_day`); `db/schema.rb` regenerated from them on Postgres 18.
- `Game::DuelCapsule.award` runs from `Game::AnswerRound#finish`, so a finishing `PlayAutomaticMove` goes through it too; the winner's moves are read from the rounds' automatic flags.
- The result records the case in `game_duels.capsule`, which already existed; the screen shows it to the winner only.
- `Game::Fortune::PACK_COLUMNS` now drives the board's capsule sum and the backfill's tally check, so a future kind cannot drift from them.
- The duel emblem is DESIGN.md's blades grid in `origin_canisters.mjs`; the duel capsule's small canister is a new icon in `export.mjs`. The Duelliste back keeps its own blades over two cards, which the design asks for, so the earlier deferred line is settled.
- The test decks' season held only Commune cards, so a capsule could not be drawn from it: `LiveDuels#complete_deck` adds a card of each other tier.

## Auto Run Result

- Summary: the first real win of a UTC day gives a duel capsule; see the notes above.
- Review: none, no lenses launched.
- Verification: `bin/rails test` (5989 runs, one known unrelated failure in the error pages build script), the system tests of the duel screens and of the capsule screen one file at a time, `npm run test:js`, `npx tsc --noEmit`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing`, `node script/pixel_art/export.mjs --check`, rubocop.
- Residual risks: the migrations run on production data only at deploy; the once-a-day grant is for the author to exercise on staging.
