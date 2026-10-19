---
title: 'Roadmap milestones created from the initiative and curated in the back-office'
type: 'feature'
ticket: '19'
created: '2026-10-19'
status: 'built'
baseline_revision: 'ddda3c11bc8a4e0b721ded8da6013315b9c484f5'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The landing's roadmap (CAP-25) has no data. The author dropped the generated-in-repo roadmap (20.10): the roadmap lives in the database, its milestones created automatically from the initiative's epics, everything else curated by staff, with no drift check and nothing to keep in step by hand.

**Approach:** `Catalog` owns two tables, roadmap milestones and the stories under each (architecture AD-29). An idempotent operation, run by a rake task from `bin/docker-entrypoint` on every web container boot, creates one hidden "to come" milestone per epic of `_bmad-output/initiative-gameble/tickets.toml` that has none, keyed by the epic's slug; that one file is let into the Docker image. Administrator back-office pages reword, show or hide, set the status of and reorder milestones, and add, edit, reorder and delete their stories.

## Boundaries & Constraints

**Always:** AGENTS.md rules: writes only through `Catalog::` operations returning `Success`/`Failure(:code)` and publishing one event in their transaction; reads through `Catalog` queries; GET never writes; tokens (24-char `has_secure_token`) in URLs and DOM, never ids; a Pundit policy per action (administrators only); every string in `en.yml` and `fr.yml`, including `errors.catalog.<code>` added by hand; no `style` attribute; no planning ids in code; new tables in one `create_table` migration each (new tables need no expand/contract); regenerate `db/schema.rb` as AGENTS.md says. Automatic creation never edits or deletes an existing milestone; new milestones get positions after the last one, in file order, wording fr and en = the epic's title, status to come, hidden.

**Never:** No public display (stories 20.11 and 20.12). No milestone created or deleted by staff (only the automatic pass creates them; a stale one is hidden). No CI check comparing the roadmap with the initiative. No hand-written TOML parser. No change to the Kamal hooks.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First run | empty tables, file with N epics | N milestones, positions 1..N in file order, title in both wordings, to_come, hidden; one event | — |
| Rerun / renamed epic | all slugs present, a title changed, staff edits | nothing created, no event, rows untouched | Success([]) |
| New epic appended | one unknown slug | one milestone after the current last position | — |
| File missing or unreadable TOML | boot in an image without it | task prints a warning, creates nothing, exits 0 | boot is never failed by the roadmap |
| Concurrent boots | two containers run the task | no duplicate (unique slug, table lock or ON CONFLICT) | — |
| Staff edit invalid | blank wording, wording over the length limit, unknown status | form re-rendered 422 with the error message | `Failure(:invalid_wording | :invalid_status)` |
| Move at an edge | first moved up / last moved down | no change, alert | `Failure(:at_edge)`; buttons not shown at edges |
| Moderator / player / visitor | any roadmap address | moderator 403, others 404 (existing back-office hiding) | — |

</intent-contract>

## Code Map

- `packs/catalog/app/{models,operations,queries,events}/catalog/` -- new code goes here; follow `publish_season.rb` (operation style, `failure_message`), `season_summaries.rb` (query returning `Data`), `season_published.rb` (event, ids only), `Season.stream_name`.
- `lib/application_operation.rb` -- base class: `transaction`, `step`, `publish(event, stream_name:)`, `failure_message`.
- `packs/catalog/lib/tasks/catalog.rake` -- add `catalog:create_roadmap_milestones` beside `number_seasons`; tested like `test/lib/catalog_number_seasons_task_test.rb` with `test/support/rake_tasks.rb`.
- `bin/docker-entrypoint` -- runs `./bin/rails db:prepare` before the server; make it `./bin/rails db:prepare catalog:create_roadmap_milestones` (one boot).
- `.dockerignore` -- ignores `/_bmad-output/`; add `!/_bmad-output/initiative-gameble/tickets.toml` right after it (checked: Docker copies only that file).
- `Gemfile` -- no TOML gem; add `gem "tomlrb", "~> 2.0.5"` (pinned like the others, with a one-line comment as its neighbours have); verified it parses the initiative file (`Tomlrb.load_file(path)["epic"]` → hashes with `slug`, `title`).
- `app/controllers/back_office/seasons_controller.rb`, `bans_controller.rb` -- controller pattern (`authorize [ :back_office, :x ], :action?`, redirect with notice/alert, `status: :see_other`, `rate_limit`).
- `app/policies/back_office/seasons_policy.rb` + `test/policies/back_office/seasons_policy_test.rb` -- headless administrator policy and its test shape.
- `app/views/back_office/seasons/index.html.erb`, `bans/_ban_action.html.erb`, `dashboard/show.html.erb` -- layout (`content_for :back_button`, `.stack`, `h1`, `PanelComponent`, `table.ledger`, `ButtonComponent` with `href:`/`method: :post`/`confirm:`, `.ban-form__field` input style); dashboard links each page behind its policy.
- `app/frontend/entrypoints/application.css` -- back-office styles (`.ledger*`, `.ban-form*`); add a small `.roadmap-form` block only if the existing classes cannot lay out a labelled form.
- `config/routes.rb` -- `scope "back-office", module: :back_office` block; token constraint `/[1-9A-HJ-NP-Za-km-z]{24}/`.
- `test/controllers/back_office/hidden_test.rb` -- enumerates every back-office route with a 24-"A" token; new routes must keep it green (non-staff 404 on every verb).
- `test/controllers/back_office/seasons_controller_test.rb` -- integration test shape (`HiddenBackOffice`, `SteamSignIn`, `sign_in(accounts_players(:administrator))`, `assert_unknown_address`).
- `config/locales/en.yml` / `fr.yml` -- `back_office:` (line ~328) and `errors: catalog:` (line ~1485).

## Tasks & Acceptance

**Execution:**
- [ ] `Gemfile`, `Gemfile.lock` -- add tomlrb -- read the initiative file.
- [ ] `db/migrate/*_create_catalog_roadmap_milestones.rb`, `*_create_catalog_roadmap_stories.rb`, `db/schema.rb` -- milestones: token (unique), epic_slug (unique, not null), wording_fr, wording_en, status (check done/in_progress/to_come, default to_come), shown (bool, default false), position (int), timestamps; stories: token (unique), milestone_id (FK, indexed), the same wording/status/shown (default true)/position columns -- the data.
- [ ] `packs/catalog/app/models/catalog/roadmap_milestone.rb`, `roadmap_story.rb`, `initiative_epics.rb` -- models (`has_secure_token :token, length: 24`, `STATUSES`, ordered scope by position then id) and the reader returning `[Epic(slug:, title:)]` from a path, or nil with a reason when missing/unparseable.
- [ ] `packs/catalog/app/operations/catalog/` -- `CreateRoadmapMilestones(epics:)`, `UpdateRoadmapMilestone(milestone:, wording_fr:, wording_en:, status:, shown:)`, `MoveRoadmapMilestone(milestone:, direction:)`, `CreateRoadmapStory(milestone:, ...)`, `UpdateRoadmapStory(story:, ...)`, `MoveRoadmapStory(story:, direction:)`, `DeleteRoadmapStory(story:)`; moves swap positions with the neighbour in order -- writes.
- [ ] `packs/catalog/app/events/catalog/` -- `RoadmapMilestonesCreated` (milestone_ids) and `RoadmapChanged` (milestone_id, story_id, change), on stream `"Catalog::Roadmap"` -- one event per write.
- [ ] `packs/catalog/app/queries/catalog/` -- `RoadmapMilestones` (all, ordered, with story counts), `RoadmapMilestoneByToken`, `RoadmapStoryByToken`, `RoadmapStories(milestone)` -- reads for the back-office.
- [ ] `packs/catalog/lib/tasks/catalog.rake`, `bin/docker-entrypoint`, `.dockerignore` -- the automatic creation on every boot.
- [ ] `config/routes.rb`, `app/controllers/back_office/roadmap_milestones_controller.rb`, `roadmap_stories_controller.rb`, `app/policies/back_office/roadmap_policy.rb`, `app/views/back_office/roadmap_milestones/{index,edit}.html.erb`, `roadmap_stories/{new,edit,_form}.html.erb`, `dashboard/show.html.erb`, locales -- milestones table (position, both wordings, slug, status, shown, up/down, edit); a milestone's edit page holds its form and its stories table (up/down, edit, delete with confirm) and the add-story link; forms re-render 422 with the failure message.
- [ ] `test/packs/catalog/*roadmap*_test.rb`, `test/lib/catalog_create_roadmap_milestones_task_test.rb`, `test/policies/back_office/roadmap_policy_test.rb`, `test/controllers/back_office/roadmap_*_controller_test.rb` -- each operation's success and every failure, the matrix rows, the real initiative file parsing to a non-empty epic list, the policy per role, the pages for administrator/moderator/player.

**Acceptance Criteria:**
- Given an empty roadmap, when `bin/rails catalog:create_roadmap_milestones` runs twice, then the back-office roadmap page lists one hidden "to come" milestone per initiative epic, in the file's order, and the second run prints that nothing was created.
- Given an administrator on the roadmap page, when they reword a milestone in both languages, mark it shown and in progress, move it up, add two stories, reorder and delete one, then the page reflects each change after its redirect, and rerunning the task leaves them as they were.
- Given a moderator, when they open a roadmap page, then they get 403; a player or visitor gets the 404 page.

## Implementation Notes

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 2 findings — high 0, medium 1, low 1, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` UpdateRoadmapMilestone takes only a row lock then needs ROW EXCLUSIVE while MoveRoadmapMilestone holds SHARE ROW EXCLUSIVE and waits on the same row: a save during a move of that milestone or its neighbour deadlocks — fixed: UpdateRoadmapMilestone takes `lock_milestones` first in its transaction.
  - `[low]` `[reject]` A story deleted between its lookup and a move is refused with `at_edge` instead of `story_not_found` — needs two administrators racing on one story and only changes the flash wording; the fix adds a branch.

## Design Notes

Milestones are never created or deleted by staff: deleting one would only see it recreated at the next deploy, so a stale epic is hidden instead. New milestones are hidden so an English epic title never reaches French players before staff word it. The rake task resolves the path `Rails.root.join("_bmad-output/initiative-gameble/tickets.toml")` and never raises on a missing or broken file (a stale roadmap is accepted); the test that parses the real file catches a broken file in CI instead. Lock the milestones table (`LOCK TABLE ... IN SHARE ROW EXCLUSIVE MODE`) inside the creation transaction so concurrent boots neither duplicate nor collide on positions.

## Verification

**Commands:** (with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w2019`)
- `bin/rails test` -- expected: 0 failures, 0 errors
- `bin/rails zeitwerk:check` and `bundle exec packwerk check` -- expected: clean
- `npm run test:js` and `bin/ci` -- expected: pass
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb DATABASE_URL=.../gameble_schema_w2019 bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb` -- expected: schema diff only adds the two tables

## Auto Run Result

- **Summary:** the roadmap lives in `Catalog`: milestones (one per initiative epic, keyed by slug, created hidden and to come, never edited or deleted by the automatic pass) and stories under each, curated by administrators in the back-office. `bin/docker-entrypoint` runs `db:prepare catalog:create_roadmap_milestones` on every web container boot; `.dockerignore` lets `_bmad-output/initiative-gameble/tickets.toml` into the image (checked with a throwaway build); `tomlrb ~> 2.0.5` reads it.
- **Files:** two migrations and `db/schema.rb`; models `RoadmapMilestone`, `RoadmapStory`, `InitiativeEpics`, `RoadmapWording`, `RoadmapOrder`; seven operations plus `RoadmapEditing`; events `RoadmapMilestonesCreated`, `RoadmapChanged`; four queries; `catalog.rake` task; `bin/docker-entrypoint`, `.dockerignore`, `Gemfile(.lock)`; routes, `RoadmapMilestonesController`, `RoadmapStoriesController`, `RoadmapEntries`, `RoadmapPolicy`, views, dashboard link, en/fr locales; operation, task, policy and controller tests.
- **Review:** 1 patch applied (medium, deadlock between milestone save and move); 0 deferred; 1 rejected (low, wrong flash wording on a race).
- **Follow-up review recommended:** false (one medium patched, no high).
- **Verification:** `bin/rails test` 2782 runs, 0 failures; zeitwerk and packwerk clean; `npm run test:js` 430 passed; the task run twice on a scratch database created 20 milestones then nothing.
- **Residual risks:** the task swallows every error so a roadmap problem never fails a boot, which could hide a database or code error in the logs; milestones are created hidden, a default the author did not state.

