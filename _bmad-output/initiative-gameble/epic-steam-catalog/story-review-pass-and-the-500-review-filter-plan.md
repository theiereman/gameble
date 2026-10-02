---
title: 'Review pass and the 500-review filter'
type: 'feature'
ticket: '3'
created: '2026-10-02'
status: 'built'
baseline_revision: '8828e609f57e0eeeda5fd759744d82e3e92f02aa'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md', '{project-root}/_bmad-output/initiative-gameble/epic-steam-catalog/story-import-run-tracer-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** An import run lists every Steam game (about 190,000) but knows nothing of their reviews, so it cannot keep only established games (epic 2, R3, R5).

**Approach:** After the app list, the run moves to a second step, `reviews`, that pages through the apps listed by this run, 100 at a time, asks `IStoreBrowseService/GetItems` for their review summaries, stores them on each app, and records a review verdict: kept, `too_few_reviews` (under 500) or `unavailable` (not on the store). It resumes from its cursor like the first step.

## Boundaries & Constraints

**Always:**
- Steps are ordered in `Steam::ImportRun::STEPS` (`app_list`, `reviews`). The cursor names its step: `{ "step" => "<step>", "last_appid" => N }`, from `StartImport` on, so a stale job of an earlier step fails the job's cursor guard. `Steam::FinishImportStep.new.call(import_run:)` takes the run already locked by the page operation (like `CompleteImport`), moves it to the next step with cursor `{ "step" => next, "last_appid" => 0 }` and publishes `ImportStepFinished` (`{ import_run_id:, step: }`, the step finished); on the last step it publishes that event and then calls `CompleteImport`. It returns the same run object, so the job enqueues the next step's first page at once.
- A `reviews` page first selects the next ≤ 100 appids with `import_run_id = run.id` and `appid > last_appid`, ordered by appid. None: the step finishes without calling Steam. Otherwise one `GetItems` call (Web API quota, about 1,900 calls a run, no store throttle) with `context: { language: "english", country_code: "US" }` (constants) and `data_request: { include_reviews: true }`, outside the transaction; then, in one transaction with the cursor guard, the page's rows are updated (never created; `import_run_id` and `name` untouched) and the cursor moves to the page's highest appid.
- Per app: `review_count` and `review_percent_positive` from `reviews.summary_filtered`, the raw `reviews` object (jsonb), `reviewed_run_id` (this run), and `review_exclusion`: NULL when kept, `too_few_reviews` when `review_count` < `Steam::ReviewPolicy::MIN_REVIEWS` (500), including an item with `success: 1` and no `reviews` (count 0), `unavailable` when the appid is absent from the answer (Steam answers an unknown appid as `id: 0, success: 15`, so answers are matched to the requested appids) or its `success` ≠ 1. The column belongs to this step alone; story 2.4 records its exclusions elsewhere.
- "Kept by a run" is `reviewed_run_id = run.id AND review_exclusion IS NULL`, a `Steam::App.kept_by(run)` scope that story 2.4 pages over. Apps not relisted by the current run are never reviewed by it, so never kept by it.
- `WebApi#get_items(appids:, context:, data_request:)` returns the raw store items keyed by appid, unnormalized, so story 2.4 reuses it with other `data_request` fields. It raises `Steam::WebApi::Error` (key redacted) when `response` is not a Hash, `store_items` is not an Array, or `store_items` is empty for a non-empty request.
- Counts gain `apps_reviewed`, `apps_kept`, `apps_excluded`. The run page shows them, with `data-import-run-*` attributes, once the run has reached `reviews`; the index page is unchanged except its intro copy, which no longer says the import only copies the list. Labels in `fr` and `en`.

**Never:** no store details, tags, images or texts (story 2.4); no prestige score (2.5); no `Catalog` write; no `appdetails` or `appreviews` call.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| App list done | last `app_list` page committed | run on `reviews`, cursor `{step: reviews, last_appid: 0}`, first reviews page enqueued by the same job | — |
| Page | 100 apps of this run after the cursor | summaries stored; ≥ 500 kept, < 500 `too_few_reviews`; cursor at the highest appid; counts moved | — |
| Exactly 500 | `review_count` 500 | kept | — |
| No summary | `success: 1`, no `reviews` | `too_few_reviews`, count 0 | — |
| Unavailable | appid absent from the answer, or `success` ≠ 1 | `unavailable` | — |
| Re-run | app excluded by an earlier run now has 600 reviews | kept by the new run | — |
| Not relisted | app row from an earlier run, absent from this run's list | not paged, not kept by this run | — |
| Last page | no app of this run after the cursor | step finishes without a Steam call; run completed | — |
| Stale job | an `app_list` job with cursor `{step: app_list, last_appid: 0}` once on `reviews` | does nothing | cursor guard |
| Steam error | 429/5xx, malformed or empty answer | retried, then run failed at its cursor | key redacted |

</frozen-after-approval>

## Code Map

- `packs/steam/app/models/steam/import_run.rb` -- `STEPS`, cursor and counts readers.
- `packs/steam/app/operations/steam/import_app_list_page.rb` -- golden example of a page; its last page now calls `FinishImportStep` instead of `CompleteImport`.
- `packs/steam/app/operations/steam/{start_import,resume_import,complete_import}.rb`, `app/jobs/steam/{import_step_job,recover_stalled_imports_job}.rb` -- cursor shape and `STEP_OPERATIONS`.
- `packs/steam/app/clients/steam/web_api.rb` -- `get_items` next to `get_app_list`, same retry, redaction and malformed-answer rules.
- `db/migrate/20261002154024*`, `*154025*` -- strong_migrations precedent: check constraint added with `validate: false`, validated in a second migration.
- `app/views/back_office/import_runs/{show,index}.html.erb`, `config/locales/{en,fr}.yml` -- `steps.app_list` exists; add `steps.reviews` and the count labels.
- `test/support/steam_api_stubs.rb` -- add one `GetItems` path stub whose block parses `env.params["input_json"]` and answers from a `{ appid => item }` hash (nil omits the appid), with helpers for counted, no-reviews and `success` ≠ 1 items.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*` -- add `review_count`, `review_percent_positive`, `reviews` jsonb, `reviewed_run_id` (FK to runs, no validation lock), `review_exclusion` with a check constraint added `validate: false` then validated in a second migration; a partial index on `(reviewed_run_id, appid) WHERE review_exclusion IS NULL`, added concurrently (`disable_ddl_transaction!`). Regenerate `db/schema.rb` on top of story 2.2's.
- [x] `packs/steam/app/clients/steam/web_api.rb` -- `get_items`.
- [x] `packs/steam/app/models/steam/{review_policy,app,import_run}.rb` -- `MIN_REVIEWS`, the verdict, `kept_by`, steps and counts.
- [x] `packs/steam/app/operations/steam/{finish_import_step,import_reviews_page}.rb`, `app/events/steam/{import_step_finished,reviews_page_imported}.rb` (`ReviewsPageImported` data `{ import_run_id:, last_appid: }`).
- [x] wire the cursor's step and `STEP_OPERATIONS["reviews"]` through `StartImport`, `ImportAppListPage`, `ImportStepJob`.
- [x] back-office views and locales.
- [x] `test/` -- rewrite the tests that expect the last app-list page to complete the run (`test/jobs/steam_import_step_job_test.rb`, `test/jobs/steam_recover_stalled_imports_job_test.rb`, `test/packs/steam/import_operations_test.rb`) so the app list hands over to `reviews`; add `FinishImportStep` to the failure-code table test; cover every matrix row, `get_items` (params incl. context, redaction, malformed and empty answers), a job test that the first reviews page is enqueued straight after the last app-list page, and a full stubbed run over both steps.

**Acceptance Criteria:**
- Given a stubbed app list of five games and their review summaries, when a run goes to the end, then it is completed, the games under 500 reviews are excluded, and the run page shows the reviewed, kept and excluded counts.
- Given `bin/rails test`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- Migrations `20261002220000` (columns, FK and check constraint with `validate: false`), `220001` (validates both), `220002` (partial index `index_steam_apps_kept_by_run`, concurrently). Rolled back and re-applied cleanly.
- `Steam::ReviewPolicy` is a module in `app/models` holding `MIN_REVIEWS`, the exclusion codes and `verdict(item)` (a `Verdict` data object). `ImportRun` gained `next_step`, `cursor_for`, `reached?` and the three count readers.
- `ImportReviewsPage` updates the page's rows one `update_all` each (100 small updates per page), scoped to `import_run_id = run.id`. A short page does not finish the step; the next job finds no app and finishes it without calling Steam, as the matrix says.
- `get_items` keys items by `appid` (falling back to `id`) and keeps only requested appids; probed once against the real API (620, 10, 999999999, 1): the two known apps came back with `summary_filtered`, the unknown ones were dropped.
- Manual check (full dev run) not done: it calls Steam about 1,900 times and runs for a long while; `Steam::App.kept_by(run).count` and the duration are still to record.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 0, low 3, false 0, maybe-false 0, deferred 1

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | low | patch | The "Steam error" row is untested for the `reviews` step at job level | Confirmed. Added a job test: a reviews page failing past its retries fails the run at `{step: reviews, last_appid: 0}`, and resuming completes it. |
| 2 | low | patch | `ImportRun#reached?` raises on an unknown step | Confirmed (`Integer >= nil`). Returns false now. |
| 3 | low | patch | `StartImport`'s comment still says "empty cursor" | Confirmed. Comment now names the step cursor and why. |
| 4 | — | defer | The full real run in development (kept count, duration) is not done | Not an acceptance criterion; it is run by the orchestrator after the commit, or at the latest by story 2.8's real import. |
| 5 | false | rejected | (implementer) no index on `(import_run_id, appid)` for paging | The page query walks the unique `appid` index from the cursor and filters on `import_run_id`, which nearly every row matches in a run; no scan of the whole table. |


## Verification

**Commands:**
- `bin/rails test` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.

**Manual checks (if no CLI):**
- With the import worker running, start a run in development, watch it move from `app_list` to `reviews` to completed, and record `Steam::App.kept_by(run).count` and the run's duration in Implementation Notes.
