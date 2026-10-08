---
title: 'Refactor sweep'
type: 'refactor'
ticket: '13'
created: '2026-10-07'
status: done
baseline_revision: '03a1649c139d3c67794f76e26ce00f2987968f34'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred:
  - summary: >-
      A full or directory run of `bin/rails test` still prints game_benchmark.rake's constant-redefinition warnings once per worker (20 lines), so the plan's "stderr without already initialized constant" check is not met.
    evidence: |-
      Pre-existing, not caused by the shared loader: Rails' test command runs test:prepare through Rails::Command::RakeCommand in a Rake application of its own before forking, so the .rake files' constants exist in each worker but no task does, and the worker's first load_tasks redefines OpenPackBenchmark's constants. A run of named files skips test:prepare and prints none. Fix: move OpenPackBenchmark out of the .rake file into a file the task requires once (game pack, outside this sweep). Recorded on the deferred-work.md entry.
    location: >-
      packs/game/lib/tasks/game_benchmark.rake:19
    severity: low
---

<intent-contract>

## Intent

**Problem:** Epic 8 left findings behind in its plans and in `deferred-work.md`: the top bar reads the whole `Game::BankSummary` (daily claim, published season) on every signed-in page though its chips use the reserve only, and the pack page reads it twice; fonts could be inlined as `data:` URIs that `font-src 'self'` refuses; three rake-task tests repeat their own task loader; dead leftovers remain (`.menu-item__form`, the `packages/pixel-art-filter/dist` ignore line, two unused card-art test helpers); the hub showcase's line still lacks the genre and number its transitional entry waited on (8.3, 8.6, both built). Many entries were settled by later stories (10.3, 10.4, 5.1, 6.1, 6.3, 8.4) but are not marked.

**Approach:** A bounded cleanup inside epic 8's code (shell, hub, booster and pack pages, the card-art tests, the Vite config). Intended visible change, and only this: the showcase line reads "rarity · genre · number". Everything else keeps its behaviour and markup; signed-in pages run fewer queries. Every epic-8 entry of `deferred-work.md` is marked resolved (with where), updated, or left recorded with its reason.

## Boundaries & Constraints

**Always:**
- `Game::BankSummary.reserve(player, now:)` → `{ available:, reserve_full:, next_available_at: }` (Reserve count, BankSchedule: two queries); `Game::BankSummary.call` returns `reserve(...)` merged with the bonus part, same keys and values as today.
- `ShellHelper#shell_bank`: the page's `@bank` when set, else `Game::BankSummary.reserve(current_player)`; the packs chip's full state reads `bank[:reserve_full]` (`shell_reserve_full?` removed; `Reserve::FULL` and `Pack::BANK_SIZE` are both 10, so nothing visible changes).
- `BoostersController#show` and `PacksController#show` read `BankSummary.reserve` into `@bank` (the shell reuses it); `@next_pack` comes from it. The hub and the daily claim keep the full summary.
- Query-count tests that include the top bar are lowered by exactly what the narrower read saves, their comments and names following.
- `vite.config.ts`: `build.assetsInlineLimit` never inlines a `.woff` or `.woff2` file; other assets keep Vite's default.
- `test/support/rake_tasks.rb` (`RakeTasks#rake_task(name)`): loads the application's tasks once per process (guard on `Rake::Task.task_defined?`) and returns the task; the three rake-task tests use it.
- Showcase line: rarity icon, then `[rarity name, genre label (SetLabel.genre), number_label].compact.join(" · ")` in one span, in the rarity colour.
- `deferred-work.md`: `resolved:` lines added or extended in place on epic-8 entries; no entry deleted; other epics' entries untouched.

**Never:** no new feature beyond the showcase line; no change to the card face (CardComponent, card.css) or its baselines; no edit to locales, routes, `db/schema.rb`, the hub menu (`pages/_menu*`), the tab bar, or another story's plan; no test weakened or deleted (tightened, moved or added only); no Booster.tsx restructuring.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Reserve read | player with 3 available, one scheduled | `reserve` = `{ available: 3, reserve_full: false, next_available_at: t }` in 2 queries; `call` the same plus the bonus keys | — |
| Full reserve chip | 10 available packs, any page | "Réserve pleine", no countdown | — |
| Signed-in library / set / card / profile | as in today's count tests | one or two queries fewer than today, all from the top bar | — |
| Pack page | opened pack, reserve 0 or 1+ | no "Ouvrir un booster" at 0, shown at 1+; the bank read once | — |
| Showcase | notable Épique pull with genre and number | line "Épique · Action · S1 · #n" | genre or number nil: left out, no stray separator |
| Fonts in a build | woff2 under 4 KB (hypothetical) | emitted as a file, never `data:` | — |

</intent-contract>

## Code Map

- `packs/game/app/queries/game/bank_summary.rb` -- `call` (Reserve.count, DailyBonusClaim.exists?, BankSchedule, PublishedSeason); add `reserve`.
- `app/helpers/shell_helper.rb` -- `shell_bank` (line 49), `shell_next_pack_in`, `shell_reserve_full?` (line 93); `app/views/shell/_packs_chip.html.erb` (line 14, header comment names BANK_SIZE).
- `app/controllers/boosters_controller.rb` (`@bank`), `app/controllers/packs_controller.rb` `show` (`@next_pack`, line 52).
- Count tests: `test/controllers/library_controller_test.rb:430-441`, `library_set_test.rb:232-249`, `public_profiles_controller_test.rb:440-472`, `cards_controller_test.rb:439-451`; `test/helpers/shell_helper_test.rb` (shell_bank, shell_reserve_full?); `test/packs/game/queries_test.rb:23` (summary), `test/packs/game/top_up_bank_test.rb:21` (`summary` strips bonus keys → `reserve`).
- `vite.config.ts` -- RubyPlugin + react, `worker.format`; Vite 8 `assetsInlineLimit` accepts `(filePath, content) => boolean | undefined`.
- `test/lib/catalog_number_seasons_task_test.rb:13`, `test/packs/game/player_state_test.rb:105`, `test/packs/game/top_up_bank_test.rb:169` -- per-file loaders.
- `app/frontend/styles/hub.css:59` `.menu-item__form` (dead since menu 01 became a link, 8.11); `.gitignore:49`; `app/frontend/lib/card_art/test_helpers.ts` `toPixels`, `distinctColors` (no caller since the pixelcrush move).
- `app/views/pages/_showcase.html.erb:16-19`, `test/controllers/pages_controller_test.rb:100-104`; reference line builder in `app/views/cards/_public.html.erb:17`.
- `_bmad-output/initiative-gameble/deferred-work.md:158-293` -- epic-8 entries.

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/queries/game/bank_summary.rb`, `test/packs/game/queries_test.rb` -- `reserve`; test its keys and its two queries.
- [x] `app/helpers/shell_helper.rb`, `app/views/shell/_packs_chip.html.erb`, `test/helpers/shell_helper_test.rb` -- reserve read, `reserve_full` key; tests follow.
- [x] `app/controllers/boosters_controller.rb`, `app/controllers/packs_controller.rb`, `test/packs/game/top_up_bank_test.rb` -- reserve reads.
- [x] the four count tests -- new counts, comments, names.
- [x] `vite.config.ts` -- font exclusion.
- [x] `test/support/rake_tasks.rb` and the three rake tests -- shared loader.
- [x] `app/frontend/styles/hub.css`, `.gitignore`, `app/frontend/lib/card_art/test_helpers.ts` -- dead code.
- [x] `app/views/pages/_showcase.html.erb`, `test/controllers/pages_controller_test.rb` -- showcase line; a test for a card without genre or number.
- [x] `_bmad-output/initiative-gameble/deferred-work.md` -- resolved/updated lines.

**Acceptance Criteria:**
- Given the suite before and after, when run, then every existing assertion still holds apart from the lowered counts and the showcase line, and the new tests pass.
- Given `bin/rubocop`, `bundle exec packwerk validate`/`check`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `npx vitest run`, `bin/rails test`, and the system tests of the hub, shell, booster, countdown and daily bonus screens, when run, then all pass.

## Implementation Notes

- Subagents unavailable, done in-session (implementation and the quick review lens).
- `Game::BankSummary.reserve` returns the first three keys in two queries; `call` merges the bonus part onto it (same keys, same values). The shell, the booster screen and the pack page read `reserve`; the pack page also stopped reading the summary twice (its `@bank` is the shell's). Counts: a signed-in card page 10 → 8 (published season and daily claim), a signed-in profile 12 → 11 and its tome 14 → 13 (the published season was already in the query cache). Library pages are unchanged: their `top_bar_status` replaces the chips. The hub and the daily claim keep `call`.
- `shell_reserve_full?` removed: the chips read the summary's `reserve_full` (`Reserve::FULL`, 10, as `Pack::BANK_SIZE` was).
- `vite.config.ts`: checked with a temporary 1 KB `tiny-probe.woff2` in fonts.css, emitted as `assets/tiny-probe-*.woff2` and referenced by URL in the CSS; the probe was removed afterwards.
- Rake loader: a first version loaded the tasks lazily inside `run_task`, so inside `capture_io`, and failed in the full suite only (`catalog_number_seasons_task_test` "any other failure" captured the benchmark's warnings). Cause found: `bin/rails test` without exact file arguments runs `test:prepare` through `Rails::Command::RakeCommand` in its own Rake application before forking, so the workers hold the .rake files' constants but no task. The loader is now called in `setup`, outside `capture_io`, as the old per-file guards were; the warnings themselves are pre-existing (deferred).
- Dead code removed: `.menu-item__form` and `.hub-showcase .button-form` (menu 01 and the showcase button are links since 8.11), the `packages/pixel-art-filter/dist` ignore line (the package left in 6c6ee61), `toPixels` and `distinctColors` in `card_art/test_helpers.ts` (no caller). `hub.css`'s header comment now places the community goal panel.
- Showcase line: `[rarity name, SetLabel.genre, number_label].compact.join(" · ")`; `number_label` carries the season ("S1 · #4"), as the public card page's line does.
- Left recorded in deferred-work.md with their reasons (not cleanup, or need a device, production data or another epic): CSP enforcement and its report-uri check, the reading pool, Solid Queue enqueue from a GET, the card-number contract, `dust_tier`'s `ignored_columns`, the chip countdown at zero off the hub, long press and non-passive touchmove on cards, phone gestures, tray thumbnails, phone headroom, stale bank and earlier-season overcount, card backs, the real-phone measurement.
- Files with shared surfaces: none of db/schema.rb, routes, locales, the hub menu or the tab bar; the query-count tests of cards and public profiles changed (a lane adding a top-bar query will meet them).

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[defer]` The Verification line "stderr without already initialized constant" is not met: a full run prints game_benchmark.rake's warnings once per worker — pre-existing (Rails' test:prepare loads the .rake files in its own Rake application before forking); recorded in `deferred` and on the deferred-work.md entry with the fix.

## Design Notes

Deferred-work dispositions (epic 8): resolved by this story — top bar bank read, font inlining, rake loaders; resolved earlier, marked now — view-transition meta (10.4), public card chrome and its sign-in button (10.3), daily panel after collection (10.4), pixel filter CSP (8.4), card baselines on CI (CI system-test green with them); in part — player chip (settings entry, 10.4), tabs (PLUS, 10.4), menu 03–06 (04 by 5.1, 05 by 6.1), showcase (xl face, line), phone hub (goal panel, 6.3); still recorded with their reason — CSP enforcement and its checks, reading pool, Solid Queue GET enqueue, card-number contract, `ignored_columns`, chip countdown, long press, touchmove, phone gestures, tray thumbnails, headroom, stale bank, overcount, card backs, real-phone measurement.

## Verification

**Commands:**
- `bin/rubocop` on changed Ruby files -- no offenses
- `bundle exec packwerk validate && bundle exec packwerk check` -- clean
- `bundle exec i18n-tasks missing` and `unused` -- none
- `npm run typecheck && npx vitest run` -- pass
- `bin/rails test` (PARALLEL_WORKERS=2) -- 0 failures, stderr without "already initialized constant"
- `bin/rails test test/system/{hub,shell,booster,countdown,daily_bonus}_test.rb` (PARALLEL_WORKERS=1) -- pass
- `bin/vite build` (test mode) -- fonts emitted as files

## Auto Run Result

**Summary.** Epic 8's sweep: the top bar, the booster screen and the pack page read only the reserve (`Game::BankSummary.reserve`), the pack page once; the chips read the summary's `reserve_full`; fonts are never inlined by Vite; the three rake-task tests share one loader; dead CSS, a stale ignore line and two unused test helpers removed; the hub showcase's line gives rarity, genre and number; every epic-8 entry of deferred-work.md resolved, resolved in part or left recorded with its reason.

**Files.**
- `packs/game/app/queries/game/bank_summary.rb` -- `reserve`, `call` built on it.
- `app/helpers/shell_helper.rb`, `app/views/shell/_packs_chip.html.erb` -- reserve read, `reserve_full`, `shell_reserve_full?` gone.
- `app/controllers/boosters_controller.rb`, `app/controllers/packs_controller.rb` -- reserve reads, the pack page's reused by the shell.
- `app/views/pages/_showcase.html.erb` -- the line with genre and number.
- `app/frontend/styles/hub.css` -- dead rules, header comment.
- `app/frontend/lib/card_art/test_helpers.ts`, `.gitignore`, `vite.config.ts` -- dead helpers, stale ignore, font exclusion.
- `test/support/rake_tasks.rb` (new), `test/lib/catalog_number_seasons_task_test.rb`, `test/packs/game/{player_state,top_up_bank}_test.rb` -- shared loader.
- `test/packs/game/queries_test.rb`, `test/helpers/shell_helper_test.rb`, `test/controllers/{packs,pages,cards,public_profiles}_controller_test.rb` -- new tests, counts lowered.
- `_bmad-output/initiative-gameble/deferred-work.md` -- resolved lines.

**Review.** Quick lens (in-session), 1 finding: deferred (low, pre-existing warnings from Rails' test:prepare). No patch, no rejection.

**Follow-up review recommended:** false (no patched entry).

**Verification.** `bin/rubocop` on the changed Ruby files: no offenses. `packwerk validate` and `check`: clean. `i18n-tasks missing` and `unused`: none. `npm run typecheck`: ok. `npx vitest run`: 14 files, 135 tests passed. `bin/rails test` (PARALLEL_WORKERS=2): 1489 runs, 0 failures, 0 errors (stderr: the pre-existing 20 benchmark warning lines). System tests hub, shell, booster, countdown, daily_bonus (PARALLEL_WORKERS=1): 72 runs, 0 failures. `bin/vite build --force` (test): ok, fonts emitted as files. Card face baselines untouched.

**Residual risks.** Query-count tests of the card page and the profile will conflict with a lane that adds a top-bar query (e.g. a trades badge): the merged count is that lane's minus this one's saving. The benchmark warnings in full runs remain (deferred).
