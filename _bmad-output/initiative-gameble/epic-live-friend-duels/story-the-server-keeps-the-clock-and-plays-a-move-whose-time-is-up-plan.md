---
title: 'The server keeps the clock and plays a move whose time is up'
type: 'feature'
ticket: '6'
created: '2026-11-16'
status: 'built'
baseline_revision: 'c7988f21'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      Nothing writes the seat's present_until yet, so the reconnection deadline is only exercised by tests.
    evidence: |-
      grep finds present_until only in schema, DuelClock and DuelsDue; a later ticket must write the lease.
    severity: medium
  - summary: >-
      A friend can still accept a challenge during the 2 s to 12 s between its 60 s and the job or sweep.
    evidence: |-
      AcceptChallenge#invited does not check the clock; the ticket does not ask for it.
    severity: low
  - summary: >-
      The shown countdown uses move_deadline_at, not the shortened lease deadline, and server_time is stamped at render time.
    evidence: |-
      DuelView.deadline and DuelStreamJob delay; the clock can read a few seconds long.
    severity: low
---

<intent-contract>

## Intent

**Problem:** A duel waits forever on a player who left: nothing bounds a move, a challenge nobody answers stays open, and the friend's board gives no sign of time.

**Approach:** Every hand-over sets a deadline and enqueues a job for it; the job and a 10 s sweep make the server lapse a stale challenge or play the move DuelRules would, under the duel lock, and the screens show a client-driven countdown from a deadline the view carries.

## Boundaries & Constraints

**Always:** An operation acts only when, under the lock, the move number still matches and the effective deadline (the earlier of `move_deadline_at` and the mover's `present_until` plus 60 s, no lease counting as present) has passed. Jobs enqueue after commit; no new Solid Queue process (the `duels` queue is served by the default worker).

**Never:** No `style` attribute in server HTML, no ticket ids in code, no writes outside operations.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Call times out | active duel, caller's 60 s up, job or sweep runs | DuelRules' automatic call locked, round marked caller_automatic, 45 s to answer | none |
| Answer times out | locked call, 45 s up | automatic answer, round marked answer_automatic, next call gets 60 s; round 10 finishes the duel | none |
| Challenge not accepted | challenged, 60 s up | duel lapsed, both seats left, event written once | none |
| Old job | move_number moved on | nothing written | Failure(:not_due) ignored |
| Real move just before | move played at deadline - 1 s | move wins, job does nothing | none |
| Lost job | no job, deadline passed | the sweep plays it | none |
| Lease ran out | mover's present_until + 60 s passed before the deadline | played early | none |

</intent-contract>

## Code Map

- `app/domains/game/app/models/game/duel_clock.rb` -- durations, mover, effective deadline, due?
- `app/domains/game/app/operations/game/duel_steps.rb` -- schedule (deadline + job), due check, lapse shared by AcceptChallenge and LapseChallenge
- `app/domains/game/app/operations/game/{challenge_friend,accept_challenge,call_round,answer_round}.rb` -- set the deadline and job at each hand-over; call/answer take `automatic:`
- `app/domains/game/app/operations/game/{lapse_challenge,play_automatic_move}.rb` -- the server's operations; the move is delegated through `step` to CallRound/AnswerRound
- `app/domains/game/app/jobs/game/{duel_deadlines,duel_deadline_job,sweep_duel_deadlines_job}.rb`, `queries/game/duels_due.rb` -- the two jobs and the sweep's candidates
- `app/domains/game/app/models/game/duel_view.rb`, `app/models/{duel_screen,duel_lobby,duel_stream}.rb`, `app/views/duels/{_clock,_board,_lobby}.html.erb`, `app/helpers/duels_helper.rb` -- the deadline and server time on the screens
- `app/frontend/{lib/duel_clock.ts,controllers/duel_clock_controller.ts,styles/duel.css}` -- the client-driven countdown
- `config/recurring.yml`, `config/locales/{en,fr}.yml` -- sweep every 10 s; clock strings and `errors.game.not_due`

## Tasks & Acceptance

**Execution:**
- [x] Clock, operations, jobs, query, recurring entry
- [x] View, screen, lobby, countdown controller, locales
- [x] Tests: `test/domains/game/duel_deadlines_test.rb`, `test/config/recurring_sweep_duel_deadlines_test.rb`, `test/system/duel_deadline_test.rb`, additions in `test/jobs/duel_stream_job_test.rb` and `test/domains/game/duel_view_test.rb`, `app/frontend/lib/duel_clock.test.ts`

**Acceptance Criteria:**
- Given a call left 60 s, when the time is up, then both boards show the round played with the automatic mark.
- Given a challenge left 60 s, when the time is up, then it lapses for both.
- Given an old move number, a real move before the deadline, a lost job, a shortened reconnection deadline and round 10, then each behaves as the matrix says.

## Implementation Notes

Built without running any suite: the coordinator runs them after integration. The sweep's SQL only preselects; `DuelClock` decides. The mover's name on the clock is "You" (Vous) on the mover's own board, the opponent's name otherwise.

## Plan Change Log

## Review Triage Log

### 2026-11-16 - Review pass
- verdicts: 7 findings - high 0, medium 2, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` comments against the policy - removed from the new code and tests
  - `[medium]` `[patch]` a banned or deleted mover blocks the duel forever - CallRound and AnswerRound skip require_player when automatic
  - `[medium]` `[defer]` present_until never written - deferred above
  - `[low]` `[reject]` weak race test - the old-number and before-deadline cases are tested; the lock check is shared by every case
  - `[low]` `[defer]` late accept of a challenge - deferred above
  - `[low]` `[defer]` displayed deadline vs lease - deferred above
  - `[low]` `[defer]` stale server time on a delayed push - deferred above

## Auto Run Result

Built the server clock: deadlines and jobs at each hand-over, LapseChallenge, PlayAutomaticMove, the sweep, the countdown. Suites run by the coordinator. No follow-up review recommended.

## Verification

Suites run by the coordinator. Static checks run here: `npm run format:check`, `npm run lint:css`, `npx tsc --noEmit`, `script/check_file_sizes`, `script/check_planning_references`: all clean.
