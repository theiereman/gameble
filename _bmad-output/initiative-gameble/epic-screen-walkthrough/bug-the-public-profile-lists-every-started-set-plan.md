---
title: 'The public profile lists every started set'
type: 'bugfix'
ticket: 18
created: '2026-10-24'
status: 'built'
baseline_revision: '8dcacbf74d26517c0b7a5f4eb95dbb3ea42e003f'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
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

### 2026-10-24 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `reject` No test sits at exactly 20 or 21 started sets, where an off-by-one would show — the cut is `first(MOST_COMPLETE_SETS_SHOWN)` on the sorted standings, read in the controller; a boundary test adds setup for a defect the one-call cut cannot make.
  - `[low]` `reject` Nothing checks that the standings are cut before `Catalog::SetsById` loads their sets — verified by reading `most_complete_set_rows`; a spy on the query adds machinery to guard a performance property, not a visible behavior.
  - `[low]` `reject` The set-id tie-break never decides who is cut in the 22-set test — it only orders equal shares, which a player cannot tell apart on the profile; a dedicated case is complexity for no visible defect.

## Verification

**Commands:**
- `bin/rails test test/controllers/public_profiles_controller_test.rb` -- expected: green, including a new test with 22 started sets showing 20 rows, the most complete first, the two least complete absent, and "22 sets started".
- `PARALLEL_WORKERS=2 bin/rails test` -- expected: green.
- `bin/rails test test/system/public_profile_test.rb -n /visitor/` -- expected: green.
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `npm run test:js`, `bin/rubocop` on changed files, `bundle exec i18n-tasks health` -- expected: clean.

## Auto Run Result

Status: built

- Summary: the public profile's SETS section shows the 20 most complete started sets (complete first, then by share owned, then set id) under a count naming every started set; the standings are cut to 20 before their sets load.
- Files: `app/controllers/public_profiles_controller.rb` (the count and the cut), `app/views/public_profiles/_sets.html.erb`, `_profile.html.erb`, `show.html.erb` (the count passed through), `test/controllers/public_profiles_controller_test.rb` (22 started sets: 20 rows under "22 sets started"), `ux-gameble/EXPERIENCE.md` (Public profile).
- Review: the Quick lens ran from the coordinating session after the unattended run halted on `no subagents`. 3 findings, all low test-coverage gaps, rejected with their reasons above; no patch, nothing deferred.
- Follow-up review recommended: false.
- Verification (unattended run, Postgres 16): `PARALLEL_WORKERS=2 bin/rails test` 3170 runs, 0 failures; `public_profile_test.rb`, `settings_test.rb`, `moderation_test.rb` system tests green on Chromium 141; packwerk, zeitwerk, vitest 561, typecheck, rubocop, brakeman, i18n-tasks clean; bundler-audit flags crass 1.0.7, pre-existing.
- Residual risks: none beyond the rejected coverage gaps.
