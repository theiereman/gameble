---
title: 'A foreign key violation on holdings fails the full suite at random'
type: 'bugfix'
ticket: 'bug-a-foreign-key-violation-on-holdings-fails-the-full-suite-at-random'
created: '2026-10-30'
status: 'built'
baseline_revision: '0a00ddafa1f61c609855cfc57c276e75b64c3758'
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

**Problem:** On 2026-10-19 the full parallel `bin/rails test` failed once in three builds with `PG::ForeignKeyViolation` on `game_holdings.card_season_id` (`Game::WeeklyGoalTest`, `Game::OpenPackTest`). Each file passed alone, and the suite passed on a rerun.

**Approach:** Name the shared state, fix it at the cause, and show 10 full parallel runs in a row with no foreign key violation, without skipping or retrying any test.

</intent-contract>

## Implementation Notes

Oneshot: the investigation found the cause already fixed on develop, so no code changes. What remains is to confirm the cause, run the 10 full-suite runs and record them.

**Cause.** `Game::DrawPool` holds one snapshot per process: the published season's card-season ids by tier, keyed on `[season.id, season.published_at]`. Some tests add card-seasons to the fixture season and then draw, which caches a snapshot holding the new ids under the fixture season's unchanged key. Their transaction rolls back the rows but not the process-level snapshot. A later test in the same worker that did not reset the pool got the stale snapshot from `Game::DrawPool.current`, drew a rolled-back id, and `Game::OpenPack#credit` failed on the holdings foreign key. Whether this happened depended on which tests the parallel queue put in the same worker and in what order, which is why each file passed alone and why rerunning with the same seed did not reproduce it reliably. Before the fix, only some files reset the pool in their own `setup`.

**Fix (already on develop).** Commit `3d03a25100c5ea12fc9890ecb6eeecf111969683` (2026-10-20, `fix(test): every test starts without a draw pool, ...`) added `setup { Game::DrawPool.reset! }` to `ActiveSupport::TestCase` in `test/test_helper.rb` and removed the per-file resets. `Game::DrawPoolTest` ("every test builds its own pool, so a card an earlier test added to the published season and rolled back is never drawn") guards it. That commit never closed this ticket.

**Cause confirmed.** With the reset commented out in `test/test_helper.rb` (temporarily, then restored, not committed), three full parallel runs failed: seed 59697 (`DrawPoolTest` failure only), seed 25964 (`DrawPoolTest` failure plus 4 `PG::ForeignKeyViolation` errors on `game_holdings.card_season_id` from `Game::OpenPack#credit`, in `GoalRewardsControllerTest`, `DailyBonusesControllerTest` x2 and `Game::CollectDailyBonusTest`) and seed 14600 (`DrawPoolTest` failure only). This is the same error as the ticket, in other files that open packs. Removing the shared reset leaves no reset anywhere, which is stricter than on 2026-10-19: those four files still reset the pool themselves then. The ticket's two files did not (`git grep DrawPool 3d03a251^ -- test` finds neither), so the next check targets them. In one worker (`PARALLEL_WORKERS=1`), with the shared reset removed, `DrawPoolTest`'s rolled-back-card test was run alongside `WeeklyGoalTest` "openings count on the opener's own row" and "a replayed opening counts nothing", and `OpenPackTest` "opening takes the oldest available pack" and "a card twice in a pack". Of seeds 1 to 16, five failed when the rolled-back test ran before the openings: seed 3 (OpenPackTest), and seeds 7, 13, 15 and 16 (one OpenPackTest and one WeeklyGoalTest error each). Each error was `PG::ForeignKeyViolation` on `game_holdings` for card-season 694339566, which the earlier test added and rolled back. With the reset restored, seeds 7, 13, 15 and 16 pass.

**Other causes ruled out.** `Rails.cache` is `:null_store` in test, so it cannot hold a stale id. No other domain module keeps process-level state about card-seasons; `Accounts::ClerkClient` caches only JWKS. The non-transactional concurrency tests reset the Rails fixture caches in `teardown_fixtures`, so the next transactional test reloads the fixtures, and the pool reset at the next `setup` drops any snapshot their threads built. The 2026-10-19 runs also used the shared default `gameble_test` database while other sessions ran, but the reproduction above runs on a private database (`gameble_test_wfk`), so the shared database is not needed to explain the error.

## Verification

All commands use `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_wfk` and `CHROME_BIN=/usr/bin/chromium`, on the default parallel workers (12 processors).

**Commands:**
- `bin/rails test`, 10 runs in a row on baseline `0a00ddaf`. Expected: 0 failures, 0 errors, no `ForeignKeyViolation` in any run.
- The same command with the reset temporarily removed. Expected: the foreign key violation comes back, which shows it is the cause.

**Results.** 10 full parallel runs in a row of `bin/rails test` on baseline `0a00ddaf` (no code change), 3620 runs each:

| Run | Seed | Result | `ForeignKeyViolation` |
|-----|------|--------|-----------------------|
| 1 | 42537 | 0 failures, 0 errors, 0 skips | 0 |
| 2 | 994 | 0 failures, 0 errors, 0 skips | 0 |
| 3 | 7509 | 0 failures, 0 errors, 0 skips | 0 |
| 4 | 43356 | 0 failures, 0 errors, 0 skips | 0 |
| 5 | 46521 | 0 failures, 0 errors, 0 skips | 0 |
| 6 | 25463 | 0 failures, 0 errors, 0 skips | 0 |
| 7 | 44836 | 0 failures, 0 errors, 0 skips | 0 |
| 8 | 25691 | 0 failures, 0 errors, 0 skips | 0 |
| 9 | 1993 | 0 failures, 0 errors, 0 skips | 0 |
| 10 | 22874 | 0 failures, 0 errors, 0 skips | 0 |

No test is skipped or retried: no test file and no test configuration changed. Before these runs, one more green run (seed 56894) timed the suite at 57 s.

With the reset temporarily removed (see Implementation Notes): seed 59697, 1 failure; seed 25964, 1 failure and 4 `ForeignKeyViolation` errors; seed 14600, 1 failure.

## Review Triage Log

### 2026-10-30 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` The reproduction removed every reset, which is stricter than 2026-10-19, and its four errors were in files that reset the pool themselves that day, not in `WeeklyGoalTest` or `OpenPackTest`. — True: the cause was named, but the evidence did not show those two files failing. The fix edits this build's plan, so the finding is rejected under triage rules. The gap was still closed: the one-worker reproduction now in Implementation Notes shows both of the ticket's files failing with the ticket's error.

## Auto Run Result

- **Summary:** no code change. The cause is the process-level `Game::DrawPool` snapshot. It survived the rollback of card-seasons that an earlier test added to the fixture season, and was fixed on 2026-10-20 by `3d03a25100c5ea12fc9890ecb6eeecf111969683`, which resets the pool before every test in `test/test_helper.rb` and is guarded by `Game::DrawPoolTest`. This build named the cause and reproduced it, in the ticket's own files among others, by removing that reset. It also ran the full parallel suite 10 times in a row: all 10 passed, with no foreign key violation.
- **Files changed:** `_bmad-output/backlog/bug-a-foreign-key-violation-on-holdings-fails-the-full-suite-at-random-plan.md`, this plan: the cause, how it was reproduced, and the 10 runs.
- **Review:** quick lens, 1 finding: 0 patched, 0 deferred, 1 rejected (low, its fix edits the plan; the evidence it asked for was still added).
- **Follow-up review recommended:** false (patched: high 0, medium 0, low 0).
- **Verification:** 10 full parallel runs of `bin/rails test`, all green, with no `ForeignKeyViolation` (table above). Without the reset: 3 full runs each fail `DrawPoolTest`, one also shows 4 holdings foreign key errors; the one-worker runs fail in `WeeklyGoalTest` and `OpenPackTest`. All on `gameble_test_wfk`.
- **Residual risks:** the shared default `gameble_test` database can still let two sessions running the suite at once disturb each other. That is a separate hazard, already avoided by giving each lane its own `DATABASE_URL`, and it was not needed to explain this error. In production the draw pool key assumes a published season's card-seasons never change without `published_at` changing.
