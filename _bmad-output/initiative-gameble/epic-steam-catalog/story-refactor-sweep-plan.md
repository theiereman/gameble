---
title: 'Refactor sweep'
type: 'refactor'
ticket: '9'
created: '2026-10-02'
status: done
baseline_revision: '8d64754485ca09fa73edc8069f8ce67150b5ed3f'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 2's stories left duplication and loose ends: six Steam page operations repeat the same run guards, every development migration rewrites `db/queue_schema.rb`, French pages format numbers the English way (and differently in test and production), an old failed run can still be resumed after a newer run, and the epic's rejected review findings are recorded nowhere but the plans.

**Approach:** A cleanup pass over epic 2's code, scoped from its build records and review logs. Intended visible changes, and only these: French number formats; resuming refused (and its button hidden) on a failed run that is not the latest. Everything else keeps its behaviour, and the suite stays green.

## Boundaries & Constraints

**Always:**
- `Steam::PageSteps`, a mixin of private steps with no `call` (dry-operation only wraps a `call` defined on the class itself, so each operation keeps its own `call`): `find_run`, `lock_run`, `require_on_step` (uses `self.class::STEP`), `require_expected_cursor`, one under-lock check comparing the whole cursor (replacing `require_cursor_at` and `require_cursor`), `advance_page(run, last_appid:, add: { count => n })` using `run.count_of`, and `publish_page(event_class, run)` (payload `{ import_run_id:, last_appid: run.last_appid }`, unchanged for every step). Used by the six `Import*Page` operations; `ImportTagsPage` keeps its own count update; finishing a step stays a line in each `call`. `ImportAppListPage` keeps a method named `advance`, called right after `upsert_apps` inside the transaction (a job test patches it to simulate a killed worker). The per-class "another job meanwhile" comments move to the mixin; the six classes carry the same "`cursor`, when given…" paragraph.
- `db/queue_schema.rb` is committed as the development dump writes it (`db:migrate` dumps every configured database; the committed file was Solid Queue's installer template): same 13 tables, columns and indexes, `version: 1`. Not `schema_dump: false`, which would leave a fresh development queue database empty.
- `config/locales/fr.yml` defines every `number.*` subtree a view uses: `number.format` (separator `,`, delimiter U+00A0 — Jost has no U+202F glyph), `number.precision.format.delimiter: ""`, `number.percentage.format` (`delimiter: ""`, `format: "%n %"` with U+00A0), so test and production (where `fr` falls back to `en`) render the same. Tests assert exact characters (`"10 000"`), and the existing `seasons_controller_test.rb` assertion `/\A10.000\z/` is tightened to them.
- `Steam::ResumeImport` checks `require_failed` → `refuse_active_run` → `require_latest` in that order, failing with `not_latest` on a failed run that is not the latest; `ResumeImport.refusal(run)` (`not_resumable` or `not_latest`, without the active-run check) sets `@resumable` in the controller, which hides the Resume button on an older failed run. `errors.steam.not_latest` is reworded in `fr` and `en` to suit both resume and rescore. Its comment states the invariant: only the latest run can become active again, so `UnfinishedImportRun`'s gate covers every active run.
- The "every failure code has a message" test gains `ResumeImport`'s `not_latest`, `ImportCardsPage` and `RescoreCards`.
- `deferred-work.md` gains one entry per finding of epic 2 that was rejected or deferred and not fixed here (format of that file), at least: the import-check / publish-lock race (2.6), the rescore button only after a reload (2.8), a genre named `none` (2.8), the real import and calibration waiting in `pending-approvals.md` (2.3, 2.4, 2.5, 2.8).
- Comments in `packs/steam` and `packs/catalog` that no longer match the code are corrected (e.g. `import_tags_page.rb`'s "labels in other languages come later" if no story plans it).

**Never:** no new feature; no change to the import's steps, the prestige formula, the tier cut, the sets or any table; no test weakened or deleted (tests may be tightened and added); nothing pushed or deployed.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Suite | before and after the extraction | every existing test passes unchanged except the tightened assertion | — |
| Migrate | `bin/rails db:migrate` in development | `git status` clean | — |
| French numbers | 10000; 1234.5 with precision 3; 12.5 % in `fr` / `en` | `10 000` / `10,000`; `1234,500` / `1234.500`; `12,5 %` / `12.5%` (U+00A0) | — |
| Resume old failed | run A failed, run B later completed | refused; no Resume button on A | `Failure(:not_latest)` |
| Resume while active | A failed, B running | as before | `Failure(:run_in_progress)` |
| Resume latest failed | latest run failed | resumed as before; button shown | — |

</frozen-after-approval>

## Code Map

- `packs/steam/app/operations/steam/import_*_page.rb` -- the six operations; `find_run`, `lock_run`, `require_on_step`, `require_expected_cursor` are identical in all six.
- `test/jobs/steam_import_step_job_test.rb` (~177–188) -- patches `ImportAppListPage#advance` by name.
- `packs/steam/app/operations/steam/{resume_import,rescore_cards}.rb` -- `RescoreCards.refusal` is the pattern for `ResumeImport.refusal`.
- `test/packs/steam/import_operations_test.rb` (~299 run_in_progress order, ~308 failure-code table).
- `app/controllers/back_office/import_runs_controller.rb`, `app/views/back_office/import_runs/show.html.erb` (~56 Resume button).
- `db/queue_schema.rb`; `config/locales/fr.yml`; `app/views/back_office/seasons/_preview.html.erb` (`number_with_precision`, `number_to_percentage`); `test/controllers/back_office/seasons_controller_test.rb` (~118).
- `_bmad-output/initiative-gameble/deferred-work.md`; the Review Triage Logs of the epic's plans.

## Tasks & Acceptance

**Execution:**
- [x] `packs/steam/app/operations/steam/page_steps.rb` and the six operations.
- [x] `db/queue_schema.rb` regenerated.
- [x] `config/locales/fr.yml` numbers; tests.
- [x] `resume_import.rb`, controller, view, locales, tests.
- [x] failure-code table test; comment pass.
- [x] `deferred-work.md` entries.

**Acceptance Criteria:**
- Given the suite at the baseline, when it runs after the sweep, then every test passes, with no test weakened, and the matrix's new cases pass.
- Given a fresh `bin/rails db:migrate` in development, when it ends, then `git status` shows no change.
- Given `deferred-work.md`, when read, then every rejected or deferred finding of epic 2 not fixed here has an entry.
- Given `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `Steam::PageSteps`: the under-lock check is `require_cursor_unchanged(run, cursor)`, comparing the whole cursor read before the page (each `call` keeps it as `expected_cursor`). `ImportAppListPage#advance` now calls `advance_page` and returns `Success(run)`; `more_pages?` reads `run.last_appid` afterwards. `ImportCardsPage` appends its refusals before `advance_page`, whose `update!` saves them. The shared "`cursor`, when given…" paragraph ends "before the page is read" (the cards page calls no Steam).
- `db/queue_schema.rb`: the development dump differs from the installer template only in its header, `Schema[8.1]`, `enable_extension "pg_catalog.plpgsql"`, bracket spacing and table order (13 tables, same columns, indexes and foreign keys, checked by a sorted comparison). `bin/rubocop` already excludes `db/*schema.rb`.
- `number.*` is defined in `en.yml` too (Rails' own values, so English output is unchanged), keeping the "every key has its twin" rule; `config/i18n-tasks.yml` ignores `number.*` as unused (read by the helpers). New `test/helpers/number_formats_test.rb` covers the matrix; the seasons preview assertion is now exactly `"10,000"` (p50 = 10.0, precision 3, in `fr`).
- `ResumeImport.refusal(run)`: `:not_resumable` unless failed, then `:not_latest` unless `LatestImportRun`. Tests: operation (`not_latest`, older failed while latest running → `run_in_progress`, `refusal`), controller (no Resume button on an older failed run; `not_latest` alert).
- Comment pass: `import_tags_page.rb` (English names only; no story plans other languages), `prestige_score.rb` (calibration still pending, with the preview and the rescore), `unfinished_import_run.rb` and `fail_import.rb` (only the latest run can be resumed), `import_step_job.rb` and the import runs controller (reflowed long lines).
- Not committed: the sweep is left in the working tree for review.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 0, low 2, false 0, maybe-false 0, ignored 1

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | low | patch | `PageSteps`' header and `require_expected_cursor` still said "before calling Steam", and claimed every page advances and publishes | Confirmed (cards page reads no Steam; tags page and empty last pages differ). Comments corrected. |
| 2 | low | patch | `ImportStepJob`'s comment said any failed run can be resumed, with a broken reflow | Confirmed. Now "while it is the latest run"; reflowed. |
| 3 | — | ignored | The `pending-approvals.md` hunk in the review diff | Comes from the later epic 3 slicing commit, not this story. |


## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `bin/rails db:migrate && git status --short db/` -- expected: empty.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
