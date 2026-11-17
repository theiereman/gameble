---
title: 'Refactor sweep'
type: 'refactor'
ticket: '10'
created: '2026-11-17'
status: 'built'
baseline_revision: '5f7eca4580f96c82d65a812f2887051e70a14a88'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The nine builds of the live friend duels epic left the same expressions written several times in the duel operations, the deadline code, the Duels controller and the Duels views, and one explanatory comment AGENTS.md forbids. No file of the epic is over its size limit and nothing in it is dead.

**Approach:** Make only the cleanups below, each behaviour-neutral, inside the epic's existing files; record every other finding as deferred with its reason. No migration, no change to a rendered page, a JSON answer, a lock order or a stream, and nothing of the achievements and capsule code or the Duels screen's record section.

Cleanups:
1. `Game::Duel#rules` and `Game::Duel#clock` replace `DuelRules.new(duel, duel.rounds.to_a)` (seven places) and `DuelClock.new(duel, duel.seats, rules)` (two).
2. `DuelSteps#close_seats` is the shared ending of `end_challenge` and `AnswerRound#finish`: leave the seats, publish the event, release the deleted players' seats.
3. `DuelMovesController#settled` is the shared redirect of `challenge`, `accept`, `cancel` and `moved`.
4. `duels/_waiting_line` is the waiting sentence and clock `_lobby` and `_sheet_waiting` both rendered.
5. `PlayerStream` loses the comment the method name already states.

</intent-contract>

## Implementation Notes

Oneshot: about forty mechanical lines over twelve files, each change local and behaviour-neutral.

Checked and found clean: no file of the epic over its limit (the largest, `friends.css`, is 455 of 500); no unused method in the duel Ruby files and no unused export in the duel state modules; the remaining comments are browser or Turbo constraints (`bell_controller.ts`, `duel_controller.ts`, `duel_received_controller.ts`, `duel_sheet_controller.ts`) and one SQL technique (`achievement_progress.rb`, epic 44).

Weighed and left, with the reason in `deferred-work.md`: the shared opening of `CallRound` and `AnswerRound`; `guard`, `keepOpen` and `TICK_MS` repeated between two Stimulus controllers. The deferred items listed in the epic's plans (native apps, challenge-sheet follow-ups, the clock's lease, tab order on desktop) are behaviour or hitl work, not refactors, and stay as recorded.

Not touched: migrations, `Game::DuelCapsule`, the achievements, the Duels screen's record and last duels section.

## Verification

**Commands:**
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `i18n-tasks missing` -- expected: clean
- System tests of the duel files, one at a time -- expected: green

## Auto Run Result

**Summary:** cleanup only across the live friend duels epic, with no change to behaviour, markup, JSON or lock order.

**Files changed**
- `app/domains/game/app/models/game/duel.rb`: `rules` and `clock`; `duel_deadlines.rb`, `duels_due.rb`, `duel_view.rb`, `answer_round.rb`, `call_round.rb`, `play_automatic_move.rb` read them.
- `app/domains/game/app/operations/game/duel_steps.rb`: `close_seats`; `answer_round.rb` reads it.
- `app/controllers/duel_moves_controller.rb`: `settled`.
- `app/views/duels/_waiting_line.html.erb` (new), `_lobby.html.erb`, `_sheet_waiting.html.erb`.
- `app/models/player_stream.rb`: one comment dropped.
- `_bmad-output/initiative-gameble/deferred-work.md`: two entries.

**Review (none, pinned):** the author reviews the whole duel diff.

**Follow-up review recommended:** false.
