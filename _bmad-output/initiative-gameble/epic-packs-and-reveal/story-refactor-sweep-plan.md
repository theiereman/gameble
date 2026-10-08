---
title: 'Refactor sweep'
type: 'refactor'
ticket: '10'
created: '2026-10-02'
status: done
baseline_revision: '32d3bebddcd7ea159fe0463ef076f624c36145ab'
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

**Problem:** Epic 3 left loose ends: `Game::FillEmptyBanksJob` now also tops up short banks but its name says otherwise; two controller tests carry the same Rails-internals workaround to count rate-limit hits; the benchmark's result-page figure predates the heavier reveal page; the epic's rejected and deferred review findings are recorded only in the plans; and some comments drifted.

**Approach:** A cleanup pass with no behaviour change: rename the job `Game::HealBanksJob` (comments, handler, task, tests); move the rate-limit counting workaround into one test helper used by both tests; re-run `game:benchmark_open_pack` and update the epic Notes; append the epic's rejected and deferred findings to `deferred-work.md`; correct drifted comments in `packs/game`, `app/views/pages/home.html.erb` and `app/views/packs`. The suite stays green and no test is weakened.

</frozen-after-approval>

## Implementation Notes

Oneshot: a rename, a test helper, a benchmark re-run, docs and comments.
- `FillEmptyBanksJob` renamed `Game::HealBanksJob` (file, handler, rake task, tests, comments); earlier plans keep the old name as historical records.
- `test/support/counting_rate_limit.rb` (`with_counting_rate_limit`) replaces the inline store patch in the packs and daily-bonus controller tests.
- Benchmark re-run: POST p95 8.8 ms, result page GET p95 7.5–8.1 ms (7 queries); epic Notes updated.
- Views checked (`pages/home`, `packs/show`): their comments match the code; no change needed.
- `deferred-work.md`: epic 3's rejected, deferred and false findings recorded; the benchmark entry resolved.

## Plan Change Log

## Review Triage Log

- low, patch: comments still described the old job or missed a caller (`FillBank` header, `HealBank` header, the job test header, the rake description) — corrected.
- low, patch: the benchmark entry in `deferred-work.md` was done but not marked resolved — `resolved:` added.
- low, patch: two false/rejected findings of 3.3 and 3.8 missing from `deferred-work.md` — added; the countdown entry's evidence pointer corrected.
- low, patch: redundant safe navigation in the rate-limit helper's `ensure` — simplified.
- low, noted: the views had no drifted comment — recorded in Implementation Notes.
- low, rejected: earlier plan files still name `FillEmptyBanksJob` — historical records, left as written.

## Verification

**Commands:**
- `bin/rails test && bin/rails test:system && npm run typecheck && npm run test:js` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
- `RAILS_ENV=test bin/rails game:benchmark_open_pack` -- expected: exit 0, figures recorded.
