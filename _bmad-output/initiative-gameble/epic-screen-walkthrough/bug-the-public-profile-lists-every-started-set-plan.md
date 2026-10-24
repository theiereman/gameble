---
title: 'The public profile lists every started set'
type: 'bugfix'
ticket: 18
created: '2026-10-24'
status: 'blocked'
blocked_at: '2026-10-24'
blocked_reason: 'no subagents'
baseline_revision: '8dcacbf74d26517c0b7a5f4eb95dbb3ea42e003f'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The public profile's SETS section (`app/views/public_profiles/_sets.html.erb`, rows from `started_set_rows` in `app/controllers/public_profiles_controller.rb`) lists every set the player has started, which makes the profile too long (author, 2026-10-23, on staging, walkthrough finding 8).

**Approach:** Show only the 20 most complete started sets, in the existing order (complete first, then by share owned, then set id), and keep the section's count ("n sets entamés" / "n sets started") at the true total of started sets; the "VOIR LA COLLECTION COMPLÈTE" button already links to the full list. A profile with 20 sets or fewer shows them all, unchanged. Limit the standings before loading their sets, so no more sets are read than shown. EXPERIENCE.md's Public profile line says SETS lists the twenty most complete started sets, with the count naming them all.

</intent-contract>

## Implementation Notes

Oneshot: about 40 lines across the controller, the sets partial and its two callers' locals, one request test and one line of EXPERIENCE.md. The started set ids come from catalog set memberships of the published season, so every standing has its set and the standings' size is the true count.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/controllers/public_profiles_controller_test.rb` -- expected: green, including a new test with 22 started sets showing 20 rows, the most complete first, the two least complete absent, and "22 sets started".
- `PARALLEL_WORKERS=2 bin/rails test` -- expected: green.
- `bin/rails test test/system/public_profile_test.rb -n /visitor/` -- expected: green.
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `npm run test:js`, `bin/rubocop` on changed files, `bundle exec i18n-tasks health` -- expected: clean.

## Auto Run Result

Status: blocked
Blocking condition: no subagents. The review step needs a context-free reviewer subagent, and this unattended session had no tool to launch one, so no review lens ran and the Review Triage Log is empty. The implementation is complete and verified; it needs a review pass (set `status` to `in-review` and re-dispatch: that routes straight to the review step) before it can be `built`.

**Change:** the public profile's SETS section shows the 20 most complete started sets (complete first, then by share owned, then set id) and its count names every started set; the standings are cut to 20 before their sets are loaded. A profile with 20 sets or fewer is unchanged.

**Files changed:**
- `app/controllers/public_profiles_controller.rb` -- `MOST_COMPLETE_SETS_SHOWN = 20`; `@started_set_count` from all standings, `@started_sets` from the first 20 (`started_standings`, `most_complete_set_rows`).
- `app/views/public_profiles/_sets.html.erb` -- the count reads the new `started_set_count:` local.
- `app/views/public_profiles/_profile.html.erb`, `app/views/public_profiles/show.html.erb` -- pass `started_set_count` through.
- `test/controllers/public_profiles_controller_test.rb` -- a profile with 22 started sets shows 20 rows, the two least complete left out, under "22 sets started".
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- the Public profile line says SETS lists the twenty most complete started sets under a count of them all.

**Verification (Postgres 16, own database `gameble_test_w1318`):**
- `bin/rails test test/controllers/public_profiles_controller_test.rb` -- 53 runs, 0 failures.
- `PARALLEL_WORKERS=2 bin/rails test` -- 3170 runs, 0 failures, 0 errors.
- `bin/rails test test/system/public_profile_test.rb` (3 runs), `test/system/settings_test.rb` and `test/system/moderation_test.rb` (15 runs) -- 0 failures, on the local Chromium 141 with chromedriver 141.
- `bundle exec packwerk validate` and `check`, `bin/rails zeitwerk:check`, `npm run test:js` (561 tests), `npm run typecheck`, `bin/rubocop` (943 files), `bin/brakeman`, `bundle exec i18n-tasks missing`, `db:seed:replant` -- clean.
- `bin/bundler-audit` reports crass 1.0.7 (CSS sanitizer bypass, fix >= 1.0.8): pre-existing, Gemfile.lock untouched. `i18n-tasks health` flags an existing fr interpolation mismatch on `back_office.seasons.index.confirm.one` and normalization: pre-existing, no locale touched.
- `bin/ci` as a whole was not run: its migration steps drop and rebuild the schema and expect Postgres 18; this change has no migration.

**Residual risks:** no independent review ran. The count assumes every started standing has its set, which holds since `Game::SetsInProgress` reads set ids from the season's set memberships.
