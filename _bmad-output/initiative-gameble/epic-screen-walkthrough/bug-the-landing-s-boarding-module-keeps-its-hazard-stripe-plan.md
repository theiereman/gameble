---
title: "The landing's boarding module keeps its hazard stripe"
type: 'bugfix' # feature | bugfix | refactor | chore
ticket: '12' # the entry id from the ticket tree, or the story file's stem when the entry has no id; empty outside it
created: '2026-10-25'
status: 'in-progress' # draft | ready-for-dev | in-progress | in-review | built | done | blocked
baseline_revision: '9ec8aeb2f7bf1a6c773285d98ede884bb63f0144' # the commit the work starts from, set before any code change
route: 'oneshot' # oneshot | full — set by step-02
route_source: 'pinned' # pinned | auto — set with route by step-02
review: '' # none | quick | thorough — set by step-04
review_source: '' # pinned | auto — set with review by step-04
lenses_ran: [] # ids of the lenses launched, set by step-04
review_loop_iteration: 0 # incremented by step-04 before each review loopback
followup_review_recommended: false # set by step-04 at Finalize — true if the LLM decided another review pass is worthwhile
context: [] # optional: `{project-root}/`-prefixed paths to project-wide standards/docs the implementation agent should load. Keep short — only what isn't already distilled into the plan body.
warnings: [] # optional: machine-readable warnings for orchestration, e.g. oversized, multiple-goals
deferred: [] # append-only machine-readable deferred review findings; each item carries summary/evidence and optional location/severity
---

<intent-contract>

## Intent

**Problem:** Module 09 of the landing (`app/views/landings/_boarding.html.erb`, « Embarquer sur le pont ») wears the hazard stripe through the `landing-hazard` class on its panel, as the support panel of module 08 does; the repetition, and the contrast with the plain modules 07 and 08, weaken the stripe (author, 2026-10-23, walkthrough finding 2).

**Approach:** Drop `landing-hazard` from the boarding panel only, so it takes the plain panel's padding and fill while keeping its corner brackets, its copy, its reserve pips and its sign-in actions; the support panel keeps its stripe. Pin it with a system test reading the panel's computed background on the desktop and the phone, and bring DESIGN.md's Landing section (final call) in step.

</intent-contract>

## Implementation Notes

Oneshot: a one-class removal in one partial, one system test and one line of DESIGN.md; no design choice is left open.

- `app/views/landings/_boarding.html.erb`: the panel loses `landing-hazard` and keeps `brackets: true`, `landing-boarding__panel`, its copy, its reserve pips, the Steam sign-in and the terms line. Without the class the panel takes the plain `.panel` padding (`--space-panel-padding`) instead of the stripe's extra top padding. `.landing-hazard` stays in `landing.css` for the support panel of module 08, now its only user.
- `test/system/landing_boarding_test.rb`: a new test reads the computed `backgroundImage` of the boarding panel (`none`) and of the support panel (a `repeating-linear-gradient`) at 1500 and 390px wide. It fails with the class put back (checked).
- Surprise: the boarding panel is not visible to Capybara on load, since the power-on hides a module until it scrolls into view, so the presence check uses `visible: :all`.
- `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md`, Landing, final call: the panel is described with no hazard stripe, dated to the author's 2026-10-23 call.
- The class is locale-independent, so the test runs in English only; French is the author's staging check.
- `package-lock.json` churns on `npm install` here (worktree name, npm 10.9 dropping `libc` fields); restored each time and left out of the commit.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/system/landing_boarding_test.rb` -- expected: pass, including a new test that the boarding panel has no background image at 1500px and 390px wide while the support panel still does.
- `bin/rails test test/controllers/landing_page_test.rb` -- expected: pass.
- `PARALLEL_WORKERS=2 bin/rails test` -- expected: pass.
- `bin/rubocop`, `bundle exec packwerk validate && bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `npm run test:js`, `bin/rails zeitwerk:check` -- expected: clean.

**Manual checks (if no CLI):**
- On staging, the author sees module 09 without a hazard stripe on the desktop and the phone, in French and in English.

**Results (2026-10-25, Postgres 16, Chromium 141):**
- `test/system/landing_boarding_test.rb`: 3 runs, 15 assertions, 0 failures; the new test fails with `landing-hazard` restored.
- Every landing system test (boarding, lamp, live feed, motion switch, moving cards, power-on, roadmap) with `test/controllers/landing_page_test.rb`: 61 runs, 488 assertions, 0 failures.
- `PARALLEL_WORKERS=2 bin/rails test`: 3171 runs, 33358 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop` no offenses; packwerk validate and check clean; `i18n-tasks missing` none; `npm run typecheck` clean; `npm run test:js` 53 files, 561 tests passed; `zeitwerk:check` all good.
- Not run: the staging check by the author, and `bin/ci`'s schema steps (no migration).
