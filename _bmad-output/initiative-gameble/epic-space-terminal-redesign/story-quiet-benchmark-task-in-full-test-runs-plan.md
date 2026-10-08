---
title: 'Quiet benchmark task in full test runs'
type: 'chore'
ticket: '17'
created: '2026-10-08'
status: 'built'
baseline_revision: '7382c7668715311b5aae961bdc48d02cbf6dac44'
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

**Problem:** A full or directory run of `bin/rails test` prints `already initialized constant OpenPackBenchmark::…` warnings once per worker: `test:prepare` loads the .rake files in its own Rake application before the workers fork, so each worker's first `load_tasks` (through `test/support/rake_tasks.rb`) evaluates `packs/game/lib/tasks/game_benchmark.rake` again and redefines the class body's constants.

**Approach:** Move the `OpenPackBenchmark` class verbatim into `packs/game/lib/open_pack_benchmark.rb`, outside `lib/tasks` (so `load_tasks` never loads it) and outside any autoload path, and have the rake file `require_relative "../open_pack_benchmark"` inside the task body, so it is required once per process and only when the task runs. The task's name, description and behaviour stay the same. The moved header comment loses its planning ids (AGENTS.md policy: no epic n, R-n, AD-n, story n.n in code); the rule it states stays.

</frozen-after-approval>

## Implementation Notes

Oneshot: a move of one class into its own file plus a one-line require; no logic changes.

- `packs/game/lib/open_pack_benchmark.rb`: the class as it was, its header reworded for its new place ("It builds…", "Run by its task, which requires this file") and stripped of its planning ids (epic 3, R4, Done when 6, AD-23, AD-11, story 6.7). `packs/game/lib` is on the load path (packs-rails) but on no autoload path, and `load_tasks` reads only `lib/tasks/*.rake`, so the file loads only through the task's `require_relative`.
- `packs/game/lib/tasks/game_benchmark.rake`: the namespace and task as they were, with `require_relative "../open_pack_benchmark"` in the task body and a header naming why the class lives outside `lib/tasks`.
- `test/support/rake_tasks.rb`: its comment named `game_benchmark.rake`'s constants as the cause of the warnings; it now states the rule that prevents them (a .rake file defines no constant). No other .rake file defines one.
- Surprise: a directory run (`bin/rails test test/packs/game`) printed no warning even at the baseline; only a full `bin/rails test` reproduces them. The Verification line was corrected to the full run.
- Verification, in a throwaway worktree on Ruby 3.3 with the app's `it` block parameters rewritten to `_1` there only, Postgres 16 on 5432: full `bin/rails test` at the baseline 1696 runs, 0 failures, 22 `already initialized constant` lines; with the change 1696 runs, 0 failures, 0 warning lines. `RAILS_ENV=test bin/rails game:benchmark_open_pack` ran in 7 min 22 s and exited 0 (worst POST p95 79.4 ms). `bin/rubocop` on the touched files: no offenses.

## Verification

**Commands:**
- `bin/rubocop packs/game/lib` -- expected: no offenses
- `bin/rails test test/packs/game/top_up_bank_test.rb test/packs/game/player_state_test.rb test/packs/game/drop_friends_and_trades_test.rb` -- expected: pass
- `bin/rails test 2>&1 | grep -c "already initialized constant"` -- expected: 0 (a full run goes through test:prepare and forks workers)
- `RAILS_ENV=test bin/rails game:benchmark_open_pack` -- expected: runs, reports its p95, exits 0 under the limit

## Review Triage Log

- Pass 1 (quick): no unmet criterion, broken rule or bug. The reviewer checked the class moved verbatim but for its planning ids, `zeitwerk:check`, the file absent after `load_tasks`, the task's name and description, the require path in development, and rubocop.
  - rejected (would be low) -- the full-run "0 warnings" was measured on Ruby 3.3 with `it` rewritten, not on Ruby 4.0.7: a .rake file re-evaluated by `load` redefines its constants on any Ruby, and the file no longer defines any, so the outcome does not depend on the version; at worst warnings would remain.
