---
title: 'Refactor sweep'
type: 'refactor'
ticket: '4'
created: '2026-10-28'
status: done
baseline_revision: 'fb55cb8e93c8c94bf5de25f7c088e614d211c046'
route: 'oneshot'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** A player state row created by an upsert in `Game::RecordPlayerActivity` or `Game::MarkCollectionSeen` before `Game::CreatePlayerState` keeps null allocation markers, so the first opening would publish one extra `Game::SeasonAllocationReceived`. The deferred note also says `Game::OpenPack` locks the state row out of the order bank, holdings, state rows.

**Approach:** Every path that creates a state row writes the received and seen season markers at the published season, through one shared definition. The lock order is checked against the code and recorded, not changed, when the receipt must read holdings before the pack credits them.

</intent-contract>

## Implementation Notes

Oneshot: three small edits in one pack and one test file each. `Game::ReceiveSeasonAllocation` reads the holdings to compute carried tiers, so in `Game::OpenPack` it has to run before `credit`; the state row is therefore locked before the holdings upsert, which no other operation inverts while the player's bank lock serialises both.

## Verification

**Commands:**
- `bin/rails test test/domains/game` -- expected: 0 failures
- `bundle exec packwerk check` and `bin/rails zeitwerk:check` -- expected: no offense
