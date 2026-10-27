---
title: 'The steam domain reads without comments'
type: 'refactor'
ticket: 7
created: '2026-10-27'
status: 'built'
baseline_revision: '0db736cef2e6faec03eafd03c30d9acdce90fff1'
route: 'oneshot'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      test/domains/steam still carries planning ids (cards_test, genres_step_migration_test, import_operations_test, raw_value_test, review_pass_test, store_details_test) and comments.
    evidence: |-
      script/check_planning_references test/domains/steam reports them; this ticket's scope and the brief limit the change to app/domains/steam.
    location: >-
      test/domains/steam
    severity: medium
  - summary: >-
      RescoreCards.refusal no longer says it leaves out the active-run check made under the lock.
    evidence: |-
      Callers are in the web layer (back_office/import_runs_controller.rb), outside this scope, so a rename would touch it.
    location: >-
      app/domains/steam/app/operations/steam/rescore_cards.rb:20
    severity: low
---

<intent-contract>

## Intent

**Problem:** `app/domains/steam` (49 files) carries 641 comment lines and 44 planning-id lines that narrate the code or cite documents a reader does not have.

**Approach:** Delete the narrating comments; keep a one-line comment only where it states a Steam API limit or another external constraint; where a deleted comment held intent, let a name hold it. No behaviour change.

## Boundaries & Constraints

**Always:** `script/check_planning_references app/domains/steam` clean; steam tests, rubocop and packwerk green.

**Never:** touch anything outside `app/domains/steam` (and this plan); add planning ids; write multi-line comments.

</intent-contract>

## Code Map

- `app/domains/steam/app/{clients,events,jobs,models,operations,queries}`, `lib/tasks/steam.rake`, `package.yml` -- comment lines to delete.

## Tasks & Acceptance

**Execution:**
- [x] every full-line comment in the domain deleted by script; no trailing comments existed
- [x] one-line external-constraint comments restored: GetItems 100-appid cap, unknown-appid answer, empty last page, Net::HTTP deadline, retry order, asset URL format, OpenID association, claimed id only, jsonb NUL bytes, genres event kept for old runs
- [x] `DetailsPolicy.release_on`/`tag_ids` private helpers renamed `earliest_release_on`/`tag_ids_by_weight` to carry what their comments said

**Acceptance Criteria:**
- Given the domain, when `script/check_planning_references app/domains/steam` runs, then it reports nothing.
- Given the suites, when they run, then they pass.

## Implementation Notes

Oneshot: a mechanical deletion (about 650 lines) done by script, then a short reviewed list of kept comments.

## Plan Change Log

## Review Triage Log

### 2026-10-27 - Review pass
- verdicts: 24 findings - high 0, medium 4, low 5, false 0, maybe-false 0, reject 15 (merged into groups below)
- findings:
  - `[medium]` `[patch]` cursor helpers `require_expected_cursor`/`require_cursor_unchanged` indistinguishable once their comments went - renamed `require_job_cursor_current` / `require_cursor_unchanged_under_lock`
  - `[medium]` `[patch]` `get_player_summary` no-retry contract lost - `summary_connection` renamed `connection_without_retry`
  - `[medium]` `[patch]` Postgres unique-index reason for the `reopen` rescue lost - one-line comment restored
  - `[low]` `[patch]` Cdn comment sat above FILENAME and dropped the hashed file-name form - moved onto `asset_url` and completed
  - `[low]` `[defer]` RescoreCards.refusal caveat - callers outside scope
  - `[medium]` `[defer]` tests of the domain keep planning ids (intent-alignment reading B) - outside the ticket's scope
  - `[low]` `[reject]` ImportStepJob retry/stall invariant undocumented, add a test (edge-case-hunter, blind-hunter) - a new test is beyond a cleanup, no demonstrated harm
  - `[low]` `[reject]` Failure-code catalogue comments gone - codes are in the locale files and asserted by tests
  - `[low]` `[reject]` ImportRun lifecycle map, STEPS history, rename rules for tag_ids_by_weight/earliest_release_on/season_number - behaviour kept, rules readable in short methods; the epic's rule is to drop narration
  - `[low]` `[reject]` no cop prevents comments returning; verification asserted not shown; scripted deletion unchecked (package.yml header, rake desc, directives) - tests, rubocop, packwerk, zeitwerk and the diff read all pass; only package.yml's header was non-Ruby and it was deliberate
  - `[low]` `[reject]` verification-gap lens: no gaps

## Auto Run Result

- Summary: every comment of the steam domain removed except one-line external constraints; two private helpers and two internal names renamed.
- Files changed: 49 domain files plus package.yml (header dropped) and this plan.
- Review: 4 lenses; 4 patches applied, 2 deferred, rest rejected as above.
- Follow-up review recommended: false.
- Verification: check_planning_references app/domains/steam exit 0; rubocop app/domains/steam clean; steam tests 255 runs 0 failures; full `bin/rails test` 3220 runs 0 failures (before patches); after patches steam + controllers 1246 runs 0 failures; packwerk and zeitwerk clean.
- Residual risk: system tests not run (no markup or behaviour touched).

## Verification

**Commands:**
- `script/check_planning_references app/domains/steam` -- exit 0
- `bin/rubocop app/domains/steam` -- no offenses
- `bin/rails test test/domains/steam` -- 255 runs, 0 failures; full `bin/rails test` 3220 runs, 0 failures
- `bundle exec packwerk check`, `bin/rails zeitwerk:check` -- clean
