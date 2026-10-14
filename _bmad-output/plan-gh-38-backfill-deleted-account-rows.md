---
title: 'Prevent backfills from recreating rows for deleted accounts'
type: 'bugfix'
ticket: ''
created: '2026-10-14'
status: 'built'
baseline_revision: '703461af681624b8a41f7749eb33c15dd5b74417'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The player-state and friend-code backfills read accounts in batches, then can recreate rows if an account is deleted before its operation runs.

**Approach:** Make both creation operations acquire the player's bank lock inside their transaction before checking or writing. Preserve banned-account behavior and the friend-code collision retry savepoints.

</frozen-after-approval>

## Implementation Notes

Oneshot is appropriate because the fix is limited to two operations and focused regression coverage. Both operations now acquire `lock_bank` in their transaction; friend-code collision attempts remain savepoint-scoped. DeepSeek agents added stale-account regression tests and lock-race coverage for both operations.

## Review Triage Log

- false — `Gemfile.lock` contains unrelated macOS ARM platform entries; they are excluded from the issue #38 commit and PR, so no application change is needed.

## Verification

**Commands:**
- `bin/rails test test/packs/game/delete_player_concurrency_test.rb` -- both deletion races return `Failure(:player_required)` and leave no player-state or friend-code row.
- `bin/rails test` -- expected: all Rails tests pass in CI.
- `bundle exec packwerk check` -- expected: no dependency violations.
