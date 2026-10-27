# Inception proposal: epic 12, "Readable by humans: the codebase before the public release"

Status: draft for the author to approve or correct. Nothing in `tickets.toml`, the board or the epic file has been changed; this file is the only write.

## 0. What was measured, and on what

`develop` (e3889842) does not yet hold epic 21: `package.json` there still lists `react`, `react-dom`, `turbo-mount`. Epic 21 is done on the branch `epic/port-off-react` (head 4d331726, worktree `.claude/worktrees/epic-port-off-react`, 27 commits ahead of origin). Every number below is measured on that head, since epic 12 starts after epic 21 is merged. Counts come from `git grep`, `wc -l` and the two commands below, all read-only:

- `bundle exec packwerk check`: "No offenses detected", "No stale violations detected".
- `bundle exec rubocop`: 952 files inspected, no offenses.

Planning-id pattern used (the Done when 2 list): `\b(AD|CAP|R)-[0-9]+`, `[Ss]tory n.n`, `[Ee]pic n`, `DESIGN.md`, `EXPERIENCE.md`. A "comment line" is a line whose first non-blank character is `#` (Ruby), `//`, `/*` or `*` (TypeScript), counted in non-test files.

## 1. The epic as it stands

Done when (epic file, restated):

1. The backend's domain code lives under `app/domains/`, packwerk's check passes in CI, the full suite is green.
2. A CI step finds no planning reference in `app`, `config`, `db`, `lib`, `script` or `test`.
3. No production Ruby or TypeScript file exceeds 400 lines, no CSS file 500.
4. ESLint, Prettier and Stylelint run in CI and pass.
5. A developer following only the README on a fresh machine runs the app and the tests; the repository holds the architecture overview, the glossary, CONTRIBUTING, `.env.example` and an AGPL-3.0 LICENSE.
6. No LAN address, personal path or private host is hard-coded in tracked configuration.

Requirements: R1 domains under `app/domains/<name>/` (packwerk kept, Ruby namespaces unchanged); R2 no planning ids, comments only for external constraints; R3 size limits (400 Ruby/TS, 500 CSS; tests exempt per the epic's Assumption); R4 consistency pass; R5 ESLint, Prettier, Stylelint in CI; R6 newcomer documentation; R7 AGPL-3.0; R8 no private infrastructure in tracked config.

Boundaries: behaviour, URLs, player-seen markup and query counts unchanged; `_bmad`, `_bmad-output`, `.claude`, `.agents`, git history and `AGENTS.md` stay; production setup is out. Open items in the Notes: the layout unknown (architecture entry then move entry), the source conflict with the spine (Modules, AD-2), and the last entry with the author in the loop (the host's name, address and country, the `LEGAL_*` boot check, removal of the legal page's fallback).

## 2. Survey of the codebase

### 2.1 Size and shape

| Layer | Facts |
|---|---|
| Domain Ruby | `packs/accounts` 1,096 lines (43 app files), `catalog` 3,137 (98), `game` 4,787 (154), `steam` 2,114 (49). Each has `models`, `operations`, `queries`, `events`; `game` also `handlers` (1 dir, 10+ files under `handlers/game/handlers`) and `jobs`. 84 operations in all. |
| Web Ruby | `app/`: 31 top-level controllers + 14 under `back_office/` + 8 concerns, 23 helpers, 12 components, policies, jobs, channels. Production Ruby outside `packs` and `db/schema.rb` is about 5,300 lines in `app/`. |
| TypeScript | 12,651 lines in non-test `.ts` (57 Stimulus controllers, 78 lib modules, 68 test files). |
| CSS | 14,416 lines in 19 files in `app/frontend/styles`. |
| ERB | 5,216 lines; largest `app/views/cards/_detail.html.erb` 235. |
| Tests | About 50,300 lines of Ruby tests under `test/` (`test/packs/<pack>` 30/36/70/17 files for accounts/catalog/game/steam), plus Vitest. |
| Locales | `config/locales/en.yml` 2,366 lines, `fr.yml` 2,092. |

### 2.2 Files over the limits (Done when 3)

- Ruby: none over 400 (largest production file `packs/game/lib/open_pack_benchmark.rb` 379; `db/schema.rb` 615 is generated).
- TypeScript, 3 files: `app/frontend/controllers/booster_controller.ts` 1,322; `app/frontend/lib/booster.ts` 602; `app/frontend/controllers/trade_board_controller.ts` 544. Next largest `lib/trade_board.ts` 362, `lib/booster_motion.ts` 312, `lib/tilt.ts` 305. (The port review, `epic-port-off-react/review-before-the-refactor-sweep.md`, "Out of scope", names the 1,324-line booster controller as belonging to this epic.)
- CSS, 11 of 19 files over 500: `landing.css` 2,054; `shell.css` 1,615; `booster.css` 1,595; `collection.css` 1,436; `trades.css` 1,066; `hub.css` 955; `card-detail.css` 887; `booster-layouts.css` 791; `settings.css` 683; `card.css` 630; `profile.css` 599. They are all `@import`ed in a fixed order by `app/frontend/entrypoints/application.css`, so a split must preserve the cascade order.
- Not covered by Done when 3 but large: `script/pixel_art/export.mjs` 59 KB (`.mjs`, neither Ruby nor TypeScript); tests up to 1,780 lines (`test/controllers/library_controller_test.rb`), exempt.

### 2.3 Planning ids left in code (Done when 2)

402 lines with a planning reference, in about 285 files. By directory: `packs` 142 lines/100 files (accounts 14, catalog 21, game 63, steam 44); `app` 103/65 (Ruby and views 48, `app/frontend` 55 of which CSS 18); `test` 62/49 (17 files under `test/packs/game`); `db` 55/38 (all in `db/migrate`); `config` 22/13; `script` 15/1 (`script/pixel_art/export.mjs`); `lib` 3/2. Most frequent: `DESIGN.md` 43, `AD-10` 37, `EXPERIENCE.md` 34, `AD-19` 27, `AD-14` 25, `AD-7` 23. Done when 2 lists `app config db lib script test` and omits `packs`; after the move `packs` is inside `app`, so the list becomes complete.

### 2.4 Comment density against the AGENTS.md policy

Comment lines over total lines: `app` Ruby 778/5,338 (15%); `packs` Ruby 2,545/11,134 (23%; accounts 256, catalog 813, game 835, steam 641); `db/migrate` 276/1,897; `lib` 43/272; `config` 392/992 (part of it Rails-generated defaults); TypeScript 911 comment lines; CSS 285 `/*` lines; ERB 98 comment tags; tests 1,262.
Heaviest files: Ruby `app/controllers/cards_controller.rb` 83, `packs/steam/app/clients/steam/web_api.rb` 67, `packs/game/lib/open_pack_benchmark.rb` 63, `app/controllers/concerns/collection_grid_loading.rb` 58, `game/open_pack.rb` 46, `catalog/publish_season.rb` 46; TypeScript `lib/booster_motion.ts` 96, `lib/tilt.ts` 58, `lib/history_trail.ts` 47, `lib/card_art/worker_job.ts` 35; CSS `shell.css` 47, `booster.css` 42, `card-detail.css` 31. Example of the pattern: `packs/game/app/jobs/game/sum_weekly_goal_job.rb` opens with a 9-line comment citing CAP-12, AD-10, AD-12 and "story 6.5". The port review (finding 15) already flagged name-restating comments in `boosters_helper.rb`, `booster_motion.ts`, `packs_helper.rb`, and left "pre-epic comment and planning-id debt, file sizes" to this epic.

### 2.5 Packwerk, rubocop, lint tooling, CI

- packwerk and rubocop (rails-omakase) are clean (see section 0). CI (`.github/workflows/ci.yml`, `config/ci.rb`) runs rubocop, packwerk validate+check, i18n-tasks missing, brakeman, `tsc`, vitest, `script/check_markup_apis`, the schema drift steps and `zeitwerk:check`.
- No ESLint, Prettier or Stylelint config or dependency exists (`package.json` devDependencies hold only happy-dom, typescript, vite, vite-plugin-ruby, vitest). R5 is therefore a new tool chain, with its first run unmeasured.
- The words "packs" and "packs/" appear in: `AGENTS.md`, `README.md`, `package.yml`, `packwerk.yml`, the four `packs/*/package.yml`, `packs/game/lib/tasks/game_benchmark.rake`, `test/packs_test.rb` (asserts `Packs.all` names), `test/support/rake_tasks.rb`, `Gemfile` (`packs-rails ~> 0.1.0`). No `packs.yml` exists. "pack" is also the booster product (`Game::Pack`, `PacksController`, `PacksHelper`), which is the reason for the rename to domains.

### 2.6 Rules of AGENTS.md checked against the code

- Controller actions without a policy: `ApplicationController` has `after_action :verify_authorized` (line 19), so none can pass unnoticed.
- `style=` in views, helpers, packs: 0 occurrences.
- Writes outside operations (controllers, jobs, handlers): two found. `packs/game/app/jobs/game/sum_weekly_goal_job.rb` calls `WeeklyGoal.insert` and `update_all` (lines 24, 32); `packs/game/app/handlers/game/handlers/player_activity.rb` calls `PlayerState.upsert` (line 19). AGENTS.md says jobs and handlers never write a model. Whether these are accepted exceptions is an open question (section 5).
- Database ids in views: 13 `.id` hits in `app/views`, all inspected ones are slugs, view-model ids or hash keys; none shown to be a database id. Not re-verified exhaustively.
- French plurals without `zero` (AGENTS.md pitfall): 19 keys in `config/locales/fr.yml` have `one` and `other` but no `zero` (for example `shell.packs.in_reserve`, `pages.home.menu.reserve`, `friends.show.presence.minutes_ago`, `trades.row.expires`, several under `back_office`).
- Planning-doc wording "island": only in `test/lib/post_deploy_hook_test.rb` (6 fixture strings), which the port review keeps.

### 2.7 Duplication and divergent conventions

- The test helper `hold` is defined 30 times (`git grep 'def hold' test`); the deferred-work entry "Deferred from: build of story-request-test-helpers-shared-plan (2026-10-13)" said about 20, with differing signatures.
- Controllers: 19 files call `rate_limit`; 9 repeat the same `with: -> { redirect_to home_path, alert: t("x.create.throttled"), status: :see_other }` shape (for example `daily_bonuses_controller.rb:13`, `goal_rewards_controller.rb:11`, `reports_controller.rb:15`, `accounts_controller.rb:4`). Two controllers define their own `answer` helper with different signatures (`reposts_controller.rb:22`, `trades_controller.rb:216`) beside `ApplicationController#refuse_with`. 37 `success?` branches across controllers.
- The port's own duplications (root wiring written twice, template cloning in three variants, copied writers, `opensElsewhere`) were swept by the port epic's refactor sweep (review findings 1 to 13); not repeated here.
- Deferred-work entries that name this epic or its material: epic 6 retrospective (2026-10-21) "Fold the epic 6 leftovers into `epic-human-readable-codebase`" (planning ids in `weekly_goal.rb`, `sum_weekly_goal_job.rb`, `grant_goal_rewards_job.rb`, `pack_opened_feed.rb`, `event_store.rb` and five friends-and-trades migrations; optionally read the tier through `Catalog::CardSeasonTiers` in `pack_opened_feed.rb` and `trade_accepted.rb`, and share the feed visibility rule); "The `hold` test helper is still copied"; "`bundle exec i18n-tasks unused` reports `rate_limit.reading_throttled` and `rate_limit.throttled`" (slicing of epic-easier-trades, 2026-10-15); "Remove `Catalog::UpsertDraftCard`, or move `db/seeds.rb` and the tests to the staged operations" and "Drop the unused `steam_apps.carded_run_id` column" (epic-season-preparation, sweep of epic-recognizable-sets, 2026-10-19). Checked still true: `UpsertDraftCard` is used by `db/seeds.rb:35` and `packs/catalog/app/operations/catalog/upsert_draft_card.rb`; `carded_run_id` is in `db/schema.rb:526,528,611`. Checked already gone: `Game::SetCompletion`, `CardsController#named_grid`, `collection_set_path` (no hit in `app`, `packs`, `db/schema.rb`), so those entries need no story.
- Rejected as not this epic's: the lock races (publish lock), the freeze trigger, ruby-openid prepend, throttling/caching of public pages, the product calls (feed window bound, goal broadcast), the unverified phone items. All are behaviour or design work and sit in `deferred-work.md` as the Boundaries ask.

### 2.8 Newcomer-facing state (Done when 5, 6)

- `LICENSE` is the GNU Affero GPL v3 text; `package.json` says `AGPL-3.0-only`; `LICENSE-ASSETS` exists. R7 is substantially met; what remains is naming it in the README.
- `README.md` is 277 lines: setup (line 12), run (23), test (35), then deployment, Discord announcement, Sentry, staffing, retention, backups, job queue, Steam import, calibration (lines 42 to 268), i.e. most of it is operations runbook. `RELEASING.md` 219 lines. `CONTRIBUTING.md` (111 lines) is a guide for players to report bugs and ideas, with a link to the staging site; it is not a developer guide.
- Missing: `.env.example` (27 distinct `ENV` names are read in `app`, `config`, `lib`, `packs`, `script`; none documented in one place), an architecture overview, a glossary. There is no `docs/` directory. Database listens on 5433 (`compose.yaml`, `config/database.yml`).
- Private infrastructure (Done when 6): 6 lines with `192.168.x.x` and 17 with `dotsncircles` in 17 tracked files outside the AI tooling: `config/deploy.staging.yml` (host list, proxy host, `192.168.1.6`), `config/deploy.production.yml` (`192.168.1.44`, `ssh.gameble.net`, `LEGAL_HOST_NAME: Thomas Eyermann`, `LEGAL_HOST_ADDRESS: France`), `config/deploy.yml` (comments), `.github/workflows/deploy-staging.yml`, `deploy-production.yml`, `close-main-pull-requests.yml`, `README.md`, `RELEASING.md`, `CONTRIBUTING.md`, `script/backup/gameble-backup.service`, `script/backup/restore_drill`, `script/github_board/sync.py`, `app/helpers/external_links_helper.rb` (donation and source URLs), and tests with fixed hosts (`test/lib/connection_budget_test.rb`, `connection_budget_task_test.rb`, `post_deploy_hook_test.rb`, `test/config/public_url_test.rb`, `test/controllers/pages_controller_test.rb`, `settings_controller_test.rb`, `test/system/settings_test.rb`). No `/home/...` path found outside the AI tooling. `config/initializers/legal.rb` reads the three `LEGAL_*` variables with `.presence` and does not refuse to boot when one is missing.

## 3. Proposed stories, in build order

Ids are the epic-local numbers a `tickets.toml` would carry. `after` uses `epic-<slug>` where no entry exists. The epic's own whole-epic `after` list already holds epics 5, 6, 7, 11, 13, 14, 16, 18, 20, 21; stories that need it name the sentinel `epic-port-off-react` (the last to land, and the one that fixes the front-end tree) and rely on the epic gate for the rest. `covers` uses R-ids of the epic's Requirements.

```toml
# tickets.toml: epic 12, the epic's agreed children, in build order (draft, not written).

[[entry]]
id = 1
type = "spike"
title = "Settle the domain layout by a trial"
description = "On a throwaway branch, moves `accounts` (the pack that depends on nothing) to `app/domains/accounts/` and finds the layout that packwerk, packs-rails (`pack_paths` in `packs.yml`, or a few lines of autoload configuration) and Zeitwerk all accept without making `app/domains` a `Domains` namespace, covering the nested `package.yml`, `Packs.all`, the rake tasks and the test directory; records the finding as a dated Decision in the epic Notes, then amends the architecture spine (Modules, AD-1, AD-2, the layer table) through bmad-architecture so that it says `app/domains/<name>`."
verify = "On the trial branch `bundle exec packwerk validate && bundle exec packwerk check`, `bin/rails zeitwerk:check` and `bin/rails test test/packs` pass with `accounts` moved; the epic Notes hold the layout Decision and the spine no longer says `packs/<name>`."
covers = ["R1"]
after = ["epic-port-off-react"]
hitl = true
risk = "high"
unknown = "Whether `app/domains/<name>/` can hold `app/models/<ns>/...` below it (so `Accounts::Player` stays at that constant) or the domain's code sits directly in `app/domains/<name>/`; the trial answers it."

[[entry]]
id = 2
type = "story"
title = "The four packs become domains"
description = "Moves `packs/accounts`, `catalog`, `steam` and `game` to `app/domains/<name>/` by `git mv` in the layout of entry 1, updates `packwerk.yml`, the root and domain `package.yml`, the autoload configuration, `test/packs_test.rb`, `test/support/rake_tasks.rb`, `game_benchmark.rake`, and moves `test/packs/<pack>` beside the new name; says domain, not pack, wherever the word means the module (the booster `Game::Pack` keeps its name); updates AGENTS.md, README.md and `config/ci.rb` wording. Ruby namespaces, constants and behaviour are unchanged."
verify = "`bundle exec packwerk validate && bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop` and `bin/rails test` pass; `git diff -M --stat` shows the Ruby files as renames with no content change other than the files named above; no `packs/` path remains outside the AI tooling (`git grep 'packs/'`)."
covers = ["R1"]
after = [1]
hitl = false
risk = "high"

[[entry]]
id = 3
type = "story"
title = "Two mechanical checks: planning references and file sizes"
description = "Adds `script/check_planning_references` (fails on any `AD-n`, `CAP-n`, `R-n`, `story n.n`, `epic n`, `DESIGN.md`, `EXPERIENCE.md` in `app`, `config`, `db`, `lib`, `script`, `test`, and `packs` while it exists, naming the offending lines) and `script/check_file_sizes` (Ruby and TypeScript over 400 lines, CSS over 500, tests and generated `db/schema.rb`, `db/queue_schema.rb` exempt), each with a test under `test/script`; both are runnable and print the current offenders but are not yet in CI, which entry 27 does once they pass."
verify = "Run on the current tree, the two scripts exit non-zero and list the 402 reference lines and the 3 TypeScript and 11 CSS files named in the survey; their tests plant one offender each."
covers = ["R2", "R3"]
after = ["epic-port-off-react"]
hitl = false
risk = "low"

[[entry]]
id = 4
type = "story"
title = "The game domain: models and operations read without comments"
description = "In `app/domains/game/app/models` and `.../operations` (63 files), removes every planning reference, turns each comment that restates a name or narrates a story into a better name or an extracted method, and keeps a comment only for an external constraint, in one line; folds in the epic 6 leftovers for `weekly_goal.rb`, `pack.rb` and `holding.rb` (whose comment about `last_gained_at` is wrong, deferred-work 2026-10-13). No behaviour or query change."
verify = "`script/check_planning_references` reports nothing under `app/domains/game/app/models` and `.../operations`; `bin/rails test test/domains/game`, `bin/rubocop` and `packwerk check` pass; the diff touches no test."
covers = ["R2", "R4"]
after = [2, 3]
hitl = false
risk = "medium"

[[entry]]
id = 5
type = "story"
title = "The game domain: queries, events, jobs and handlers read without comments"
description = "Same cleanup for `app/domains/game/app/queries` (46), `events` (24), `jobs` (9), `handlers` and `lib` (including the 379-line `open_pack_benchmark.rb`'s 63 comment lines); folds in the epic 6 leftovers for `sum_weekly_goal_job.rb`, `grant_goal_rewards_job.rb`, `pack_opened_feed.rb`, and optionally reads the rarity tier through `Catalog::CardSeasonTiers` in `pack_opened_feed.rb` and `trade_accepted.rb` and shares the feed visibility rule between the feed readers, when the existing tests pin the behaviour."
verify = "`script/check_planning_references` reports nothing under the game domain; `bin/rails test test/domains/game`, `bin/rubocop` and `packwerk check` pass."
covers = ["R2", "R4"]
after = [2, 3]
hitl = false
risk = "medium"

[[entry]]
id = 6
type = "story"
title = "The catalog and accounts domains read without comments"
description = "Same cleanup for `app/domains/catalog` (98 files, 813 comment lines, 21 reference lines) and `app/domains/accounts` (43 files, 256 comment lines, 14 reference lines)."
verify = "`script/check_planning_references` reports nothing under the two domains; their tests, `bin/rubocop` and `packwerk check` pass."
covers = ["R2", "R4"]
after = [2, 3]
hitl = false
risk = "medium"

[[entry]]
id = 7
type = "story"
title = "The steam domain reads without comments"
description = "Same cleanup for `app/domains/steam` (49 files, 641 comment lines, 44 reference lines), including the Steam API client's 67 comment lines and `details_policy.rb`, keeping the comments that state a Steam API limit."
verify = "`script/check_planning_references` reports nothing under `app/domains/steam`; its tests, `bin/rubocop` and `packwerk check` pass."
covers = ["R2", "R4"]
after = [2, 3]
hitl = false
risk = "medium"

[[entry]]
id = 8
type = "story"
title = "The web layer's Ruby reads without comments"
description = "Cleans `app/controllers` (with `concerns`), `helpers`, `policies`, `components`, `jobs`, `channels`, `models` and the ERB comments (48 reference lines, 778 comment lines in `app` Ruby, led by `cards_controller.rb`, `collection_grid_loading.rb`, `application_controller.rb`, `shell_helper.rb`); no markup change."
verify = "`script/check_planning_references` reports nothing under `app/controllers`, `helpers`, `policies`, `components`, `jobs`, `channels`, `models`, `views`; `bin/rails test` for those directories and the controller suites, and `bin/rubocop`, pass; rendered HTML of the controller tests is unchanged."
covers = ["R2", "R4"]
after = [3]
hitl = false
risk = "medium"

[[entry]]
id = 9
type = "story"
title = "Config, migrations, lib and scripts read without planning references"
description = "Removes the planning references and name-restating comments from `config` (22 lines), `db/migrate` (55 lines in 38 files; comments only, no statement changes), `lib` (3) and `script` (15 lines, all in `script/pixel_art/export.mjs`, by editing the script, never `app/frontend/images/pixel`), and from `db/seeds.rb`."
verify = "`script/check_planning_references` reports nothing under these directories; `git diff db/migrate` shows only comment lines; `db/schema.rb` is unchanged after the CI migration-drift step; `node script/pixel_art/export.mjs --check` passes."
covers = ["R2"]
after = [2, 3]
hitl = false
risk = "low"

[[entry]]
id = 10
type = "story"
title = "The tests carry no planning references"
description = "Removes the planning references from 49 test files (62 lines; 17 under `test/domains/game`) and the story-narrating comments next to them, keeping test names and assertions; `test/lib/post_deploy_hook_test.rb` fixture strings are left."
verify = "`script/check_planning_references` reports nothing under `test`; `bin/rails test` is green with the same test count."
covers = ["R2"]
after = [2, 3]
hitl = false
risk = "low"

[[entry]]
id = 11
type = "story"
title = "One shared `hold` test helper"
description = "Replaces the 30 copies of `def hold` in the tests with one helper in `test/support/` (the `LibraryRequests#hold` of the request tests being the seed), keeping each call site's arguments (`reserved:`, `gained_at:`, `player:`)."
verify = "`git grep -c 'def hold' test` returns one definition; `bin/rails test` is green with the same test count."
covers = ["R4"]
after = [10]
hitl = false
risk = "low"

[[entry]]
id = 12
type = "story"
title = "One convention where build sessions diverged"
description = "Unifies the throttled-redirect lambda repeated in 9 of the 19 controllers using `rate_limit`, the two controller-local `answer` helpers (`reposts_controller.rb`, `trades_controller.rb`) beside `ApplicationController#refuse_with`, and the operation-result handling where three or more controllers share the same shape; adds the 19 missing `zero` forms to the French plural keys (text identical to `one`) and the dynamic `rate_limit.*` keys to `ignore_unused` in `config/i18n-tasks.yml`. Status codes, redirects and messages stay as they are."
verify = "The controller tests and `test/integration` pass unchanged; `bundle exec i18n-tasks missing` and `unused` are clean; every French plural key under `config/locales/fr.yml` has a `zero` form."
covers = ["R4"]
after = [8, 11]
hitl = false
risk = "medium"
unknown = "Which of the 37 `success?` branches really share one shape; the plan lists the groups it unifies and leaves the others."

[[entry]]
id = 13
type = "story"
title = "Remove the dead code the sweeps recorded"
description = "Removes `Catalog::UpsertDraftCard` (moving `db/seeds.rb` and its tests to the staged operations) and drops the unused `steam_apps.carded_run_id` column with its foreign key and index in an expand/contract pair of migrations, regenerating `db/schema.rb` as CI does."
verify = "`git grep UpsertDraftCard` finds nothing; `db/schema.rb` has no `carded_run_id`; the CI schema-drift steps and `bin/rails test` pass."
covers = ["R4"]
after = [6, 7, 10]
hitl = true
risk = "medium"

[[entry]]
id = 14
type = "story"
title = "The booster's state module is cut under 400 lines"
description = "Splits `app/frontend/lib/booster.ts` (602 lines) and its 869-line test into cohesive modules (for example the opening exchange, the reveal sequence, the layout and tray rules) with unchanged exports used by the controllers."
verify = "`npm run test:js`, `npm run typecheck` pass; each new file is at most 400 lines; the booster system tests (`bin/rails test test/system/booster_test.rb`) pass."
covers = ["R3"]
after = ["epic-port-off-react"]
hitl = false
risk = "medium"

[[entry]]
id = 15
type = "story"
title = "The booster's root controller is cut under 400 lines"
description = "Cuts `app/frontend/controllers/booster_controller.ts` (1,322 lines) along its regions into modules under `app/frontend/lib` and, where a region owns DOM, child controllers talking by dispatch and outlets (the anatomy AGENTS.md prescribes), without changing the markup, `data-*` names, events or timings."
verify = "`npm run test:js`, `npm run typecheck`, `script/check_markup_apis` pass; each file is at most 400 lines; `bin/rails test test/system/booster_test.rb` passes unchanged."
covers = ["R3"]
after = [14]
hitl = false
risk = "high"
unknown = "How many sessions the 1,322 lines need; the plan decides whether to split into two on a branch merged once."

[[entry]]
id = 16
type = "story"
title = "The trade board's root controller is cut under 400 lines"
description = "Cuts `app/frontend/controllers/trade_board_controller.ts` (544 lines) the same way, keeping the swap animation's classes and the `trade-board--editing` and `--swapping` classes."
verify = "`npm run test:js`, `npm run typecheck` pass; each file is at most 400 lines; `bin/rails test test/system/trades_test.rb` passes unchanged."
covers = ["R3"]
after = ["epic-port-off-react"]
hitl = false
risk = "medium"

[[entry]]
id = 17
type = "story"
title = "The booster and trade board front end reads without comments"
description = "Removes planning references and name-restating comments from the booster and trade board files left by entries 14 to 16 and their lib modules (`booster_motion.ts` has 96 comment lines)."
verify = "`script/check_planning_references` reports nothing under those files; `npm run test:js`, `typecheck`, `bin/rails test test/system/booster_test.rb test/system/trades_test.rb` pass."
covers = ["R2"]
after = [15, 16]
hitl = false
risk = "low"

[[entry]]
id = 18
type = "story"
title = "The rest of the front end's TypeScript reads without comments"
description = "Same cleanup for every other `app/frontend/lib` and `app/frontend/controllers` file (37 reference lines in all, 911 comment lines; led by `tilt.ts` 58, `history_trail.ts` 47, `card_art/worker_job.ts` 35, `history_back_controller.ts` 34, `sub_view_controller.ts` 31); the unrelated booster and trade board files are entry 17's."
verify = "`script/check_planning_references` reports nothing under `app/frontend` TypeScript; `npm run test:js` and `typecheck` pass."
covers = ["R2"]
after = ["epic-port-off-react", 3]
hitl = false
risk = "low"

[[entry]]
id = 19
type = "story"
title = "landing.css is cut under 500 lines"
description = "Splits `landing.css` (2,054 lines) into per-section files of at most 500 lines, imported in the same cascade order from `app/frontend/entrypoints/application.css`, and cleans its comments."
verify = "The compiled stylesheet's rules are identical in content and order before and after (a script concatenating the resolved imports, comments and whitespace stripped, diffed); `script/check_file_sizes` clean for these files; the landing system tests pass."
covers = ["R2", "R3"]
after = ["epic-port-off-react", 3]
hitl = false
risk = "medium"

[[entry]]
id = 20
type = "story"
title = "shell.css and hub.css are cut under 500 lines"
description = "Splits `shell.css` (1,615 lines, 10 planning references) and `hub.css` (955 lines) the same way."
verify = "Same compiled-order diff; `script/check_file_sizes` clean; `bin/rails test test/system/shell_test.rb` and the hub system tests pass."
covers = ["R2", "R3"]
after = ["epic-port-off-react", 3]
hitl = false
risk = "medium"

[[entry]]
id = 21
type = "story"
title = "booster.css and booster-layouts.css are cut under 500 lines"
description = "Splits `booster.css` (1,595 lines) and `booster-layouts.css` (791 lines) the same way, after the booster's anatomy of entries 14 and 15 is settled."
verify = "Same compiled-order diff; `script/check_file_sizes` clean; `bin/rails test test/system/booster_test.rb` passes."
covers = ["R2", "R3"]
after = [15, 3]
hitl = false
risk = "medium"

[[entry]]
id = 22
type = "story"
title = "collection.css, card-detail.css and card.css are cut under 500 lines"
description = "Splits `collection.css` (1,436), `card-detail.css` (887) and `card.css` (630) the same way."
verify = "Same compiled-order diff; `script/check_file_sizes` clean; the library and card detail system tests pass."
covers = ["R2", "R3"]
after = ["epic-port-off-react", 3]
hitl = false
risk = "medium"

[[entry]]
id = 23
type = "story"
title = "trades.css, settings.css and profile.css are cut under 500 lines"
description = "Splits `trades.css` (1,066), `settings.css` (683, 3 planning references) and `profile.css` (599) the same way, and clears the references left in `tokens.css` (3) and `application.css` (1)."
verify = "Same compiled-order diff; `script/check_file_sizes` and `script/check_planning_references` clean for `app/frontend/styles` and `entrypoints`; the trades, settings and profile system tests pass."
covers = ["R2", "R3"]
after = ["epic-port-off-react", 3]
hitl = false
risk = "medium"

[[entry]]
id = 24
type = "story"
title = "No private infrastructure in tracked configuration"
description = "Replaces the staging and production hosts, the LAN addresses and the personal names hard-coded in `config/deploy.staging.yml`, `config/deploy.production.yml`, `config/deploy.yml` comments, the three deploy-related workflows, `script/backup/*`, `script/github_board/sync.py` and the tests that pin a staging host, with values read from the environment (Kamal ERB, GitHub variables, `.kamal/secrets`) documented in `.env.example`'s sibling for deployment; the tests build their host from a constant."
verify = "`git grep -nE '192\\.168\\.|dotsncircles' -- . ':(exclude)_bmad' ':(exclude)_bmad-output' ':(exclude).claude' ':(exclude).agents'` returns nothing; `bin/kamal config -d staging` and `-d production` still render with the variables set; `bin/rails test` passes."
covers = ["R8"]
after = [10, 11]
hitl = true
risk = "high"
unknown = "Which names count as private (section 5, question 3), and where the author keeps the values (GitHub variables, a local file)."

[[entry]]
id = 25
type = "story"
title = "Prettier and Stylelint on the front end"
description = "Adds Prettier (TypeScript, CSS, JSON) and Stylelint with configs and npm scripts, formats the whole front end in one mechanical commit with no logic change, and fixes the Stylelint findings or records a short list of relaxed rules in the config."
verify = "`npx prettier --check app/frontend` and `npx stylelint 'app/frontend/**/*.css'` exit 0; `npm run test:js`, `typecheck` pass; the compiled stylesheet diff of entry 19 passes."
covers = ["R5"]
after = [17, 18, 19, 20, 21, 22, 23]
hitl = false
risk = "medium"

[[entry]]
id = 26
type = "story"
title = "ESLint on the front end"
description = "Adds ESLint (flat config, typescript-eslint) and its npm script and fixes or consciously disables each finding with a reason in the config, not in the code."
verify = "`npx eslint app/frontend` exits 0; `npm run test:js`, `typecheck` and the markup-API check pass."
covers = ["R5"]
after = [25]
hitl = false
risk = "medium"

[[entry]]
id = 27
type = "story"
title = "CI refuses what this epic cleaned"
description = "Wires `script/check_planning_references`, `script/check_file_sizes`, ESLint, Prettier and Stylelint into `.github/workflows/ci.yml` and `config/ci.rb` (the `bin/ci` list), next to the existing markup-API check, and records the new commands in AGENTS.md."
verify = "Both CI files run the five commands; a planted planning id, a 401-line Ruby file, a CSS file over 500 and a badly formatted TypeScript file each fail them; the full suite, `npm run test:js`, `zeitwerk:check` and `packwerk check` pass."
covers = ["R2", "R3", "R5"]
after = [4, 5, 6, 7, 8, 9, 10, 12, 13, 26]
hitl = false
risk = "low"

[[entry]]
id = 28
type = "story"
title = "README, CONTRIBUTING and .env.example for a newcomer"
description = "Rewrites `README.md` (what gameble is, setup on Postgres 18 at port 5433, running, tests and their parts, deploy summary, licence AGPL-3.0), moves the operations runbooks (Sentry, staffing, retention, backups, job queue, import, calibration) to a `docs/operations.md`, makes CONTRIBUTING a developer guide with the player feedback guide kept as a section, and adds `.env.example` listing the 27 environment variables the code reads."
verify = "A reader can find setup, run and test commands in the README alone; every variable read through `ENV` in `app config lib packs script` appears in `.env.example` (a script compares the two lists); README links resolve."
covers = ["R6", "R7"]
after = [2, 24]
hitl = false
risk = "low"

[[entry]]
id = 29
type = "story"
title = "Architecture overview and glossary"
description = "Writes `docs/architecture.md` (the domains and their dependency diagram, the operation/event/query anatomy, the front-end screen anatomy, the CI checks and where to look first) and `docs/glossary.md` (the domain terms as the code spells them: season, set, tier, edition, card-season, holding, bank, pack versus domain, capsule, and so on), in English, from the spine as amended by entry 1, without planning ids."
verify = "Every constant and path named in the two documents exists (`git grep` check script or a reviewer's pass over the list); no planning id appears; README links to both."
covers = ["R6"]
after = [1, 2, 15, 16, 28]
hitl = false
risk = "low"

[[entry]]
id = 30
type = "story"
title = "The host line: legal host and the boot check"
description = "Once the author has chosen the host, writes its name, postal address and data-centre country into `config/deploy.production.yml` (`LEGAL_HOST_NAME`, `LEGAL_HOST_ADDRESS`) and the privacy notice's processors, makes the app refuse to boot in production when a `LEGAL_*` variable is missing (`config/initializers/legal.rb`), and removes the legal page's `access_publisher` fallback."
verify = "A production-mode boot without `LEGAL_HOST_NAME` fails with a message naming it; the legal page test shows the host from the variables; the processors list in the privacy notice names the host."
covers = ["R8"]
after = [24]
hitl = true
risk = "medium"

[[entry]]
id = 31
type = "story"
title = "A fresh machine follows the README"
description = "On a clean clone (a container or a machine without the project's tooling), follows only the README to start Postgres, install, run the app and the Ruby and JavaScript tests, fixes the documentation where it fails, and walks the six Done when checks."
verify = "The setup, `bin/rails test`, `npm run test:js` and the app's home page succeed from a clean clone with no step outside the README; the six Done when checks are ticked in the epic Notes."
covers = ["R6", "R7"]
after = [27, 28, 29, 30]
hitl = true
risk = "low"
```

## 4. What can run in parallel

Lanes are disjoint in the files they edit; entries inside a lane are serial.

- **Spine lane (serial, first):** 1, then 2. While 1 and 2 are in flight, nothing may edit `packs/`, `test/packs/`, `config/` or `AGENTS.md`/`README.md`.
- **Free from the start (do not touch `packs/`, `config/` or `test/packs`):** 3 (new scripts), 8 (web Ruby; touches `app/controllers`, `helpers`, `policies`, `components`, `jobs`, `channels`, `models`, `views` only), 14 and 16 (front-end TypeScript), 18 (the other TypeScript files), 19, 20, 22, 23 (CSS). 14 and 16 are disjoint files; 18 excludes the booster and trade board files. 3 is not needed to start 8 beyond the check script, so it runs first or beside it.
- **After 2 and 3, in parallel:** 4, 5, 6, 7 (four disjoint directory sets: game models and operations; game queries, events, jobs, handlers, lib; catalog and accounts; steam), 9 (config, db, lib, script), 10 (tests). If a story renames a method, it fixes its callers inside its own directories and reports a cross-domain caller instead of editing it.
- **Front-end chain:** 14 then 15 then 21 (booster files) while 16 then 17 follows 15 and 16; 19, 20, 22, 23 are file-disjoint from each other. The only shared file is `app/frontend/entrypoints/application.css`: each CSS story adds its new imports at its file's position in the import list, so a conflict is a one-line merge; if sessions run at once, take them in the order 19, 20, 22, 23.
- **Serial after the above:** 11 (after 10), 12 (after 8 and 11), 13 (after 6, 7, 10), 24 (after 10 and 11, since it edits test files), 25, 26, 27, 28, 29, 30, 31.
- Never together: 24 and 28 (both edit README), 25 with any front-end story, 27 with any story still failing a check.

Tracer path: 1, 2, then one small domain (6, accounts half) through 3's check, which proves the layout, the checks and the cleanup recipe end to end before the larger domains repeat it.

## 5. Assumptions and open questions

Assumptions:

1. Epic 21 is merged to `develop` before this epic starts; all counts are from `epic/port-off-react` head 4d331726, not from `develop`.
2. The size rule applies to `.ts` and `.rb` and `.css` files only: `script/pixel_art/export.mjs` (59 KB) and `db/schema.rb` (615 lines, generated) are not split; tests are not held to the limits (the epic's Assumption).
3. Cleaning old migrations means editing comments only (the schema and the migration statements stay), which leaves `db/schema.rb` unchanged.
4. In tests, R2 is met by removing the planning references and story-narrating comments next to them (62 lines), not by a full comment pass over the 1,262 test comment lines.
5. The domain rename moves the tests too (`test/packs/<name>` to `test/domains/<name>`), and the booster `Game::Pack` keeps its name.
6. Stories 4 to 7 are cleanup in the AGENTS.md sense: named after the policy there ("code reads without comments"), judged story by story in review; the check script can only prove the planning references are gone, not the comment quality.
7. Linters start from the standard presets (typescript-eslint recommended, Prettier defaults, `stylelint-config-standard`), with any relaxed rule listed and justified in its config.

Open questions only the author can answer:

1. `sum_weekly_goal_job.rb` (lines 24, 32) and `handlers/player_activity.rb` (line 19) write models from a job and a handler, against the AGENTS.md rule. Should entries 4 and 5 move these writes behind operations (a behaviour-preserving but non-trivial change), or are they accepted exceptions to document in AGENTS.md?
2. Entry 13: may the epic drop `steam_apps.carded_run_id` and remove `Catalog::UpsertDraftCard` while production is in maintenance on v0.1.1, or do you want the contract migration kept for after the first import?
3. Entry 24: which names are "private"? Is the staging site `gameble.dotsncircles.com` (published to testers in CONTRIBUTING and RELEASING) to be replaced by `staging.gameble.net` before this epic (deferred-work, slicing of epic-easier-trades, 2026-10-15), or only moved out of tracked config into variables? Are `theiereman` (image and repository names, donation URL) and the `LEGAL_*` personal name acceptable in tracked files?
4. Entry 28: should the player feedback guide stay in `CONTRIBUTING.md` (as a section) or move out? And is `docs/` the place for the architecture overview and glossary?
5. Entry 30: the host is not yet chosen; the story waits on your choice. `config/deploy.production.yml` currently carries `LEGAL_HOST_NAME: Thomas Eyermann`, `LEGAL_HOST_ADDRESS: France`; is that a placeholder to replace?
6. Entry 15: the 1,322-line booster controller may need two sessions; do you accept the plan splitting it into two entries when it starts?

## 6. Deliberately left out

- All behaviour, copy and visual changes: the product calls in `deferred-work.md` (feed window bound, goal broadcast, friends-only live entries, the bold figure token audit, the glitter animation budget), and the lock-on-throw and "Reveal all" items the author left alone on 2026-10-27.
- The lock-race, freeze-trigger, nonce-store, index and CSP findings in `deferred-work.md`; the Number-the-seasons contract migration (waits on production); the throttling/caching of public pages; every "check on a real device" entry.
- The system tests marked stale in `deferred-work.md` ("when system tests are rebuilt") and the card-face baselines; they are test rebuilds, not readability, and CI runs system tests once before a release.
- Dropping `Game::SetCompletion` and `game_set_completions`: no hit remains in `app`, `packs`, `db/schema.rb`, so there is nothing to do.
- Epics 15 (back-office UX), 17, 19, 22, the 0.5.0 milestone, and the production setup itself (the epic's Boundaries).
- The `_bmad`, `_bmad-output`, `.claude`, `.agents` trees and the git history; AGENTS.md except its factual updates in entries 2 and 27.
- Splitting very large test files (up to 1,780 lines), renaming the booster `Pack`, merging `trades.*` and `trade_board.*` locale layouts, and the transition naming differences (all "Leave" items of the port review).
- A check of how the CSS split is verified beyond the compiled-order diff (visual regression): none exists in the repo, so none is proposed.
- Validation by independent agents (`validate.md`): the set check has been walked by hand only (every Done when item has an owning entry: 1 by 1 to 2, 2 by 3 to 10, 17, 18, 27, 3 by 14 to 16 and 19 to 23 and 27, 4 by 25 to 27, 5 by 28 to 31, 6 by 24 and 30); it still needs the independent run before approval.
