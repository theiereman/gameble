---
title: 'Moderation: the queue, bans and unbans'
type: 'feature'
ticket: '5'
created: '2026-10-09'
status: 'built'
baseline_revision: '58ab6e4edc99487a26f39faa1241e6d5967e9717'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Reports (story 7.4) reach no one, and a ban can only be set from the console, where nothing publishes `Accounts::PlayerBanned`, so a banned player's trades and friendships stay until `bin/rails game:drop_friends_and_trades` runs (R4, CAP-15).

**Approach:** A back-office queue of reported players for moderators and administrators, with BANNIR and CLASSER per player, and a list of banned players with LEVER LE BAN. `Accounts::BanPlayer` publishes `Accounts::PlayerBanned` (Game's existing handler drops the player's trades and friendships); `Accounts::UnbanPlayer` and `Accounts::DismissReports` publish their own events. Staff roles are set by a rake task through `Accounts::SetRole`, and the README's runbook says how.

## Boundaries & Constraints

**Always:** only staff (moderator or administrator) reach the new pages and actions: Pundit refuses a visitor (sign-in redirect) and a player (403), as the existing back-office does; the operations check the acting staff member again; no one bans an administrator or themselves; a ban marks the player's open reports handled so an unban does not bring them back into the queue; players are addressed by token, never by id (URLs, HTML, DOM); events carry ids only (`player_id`, `staff_id`); the ban locks the player row `FOR NO KEY UPDATE`, publishes, and only then writes `banned_at` (the write rotates `stream_key`, a unique column, so it takes `FOR UPDATE`, as `Accounts::DeletePlayer` explains); every string in `fr.yml` and `en.yml` (English translated from the French); strong_migrations rules.

**Never:** a role-assignment page; restoring friendships or trades on unban; changing `Game::Visibility`, `Accounts::SignIn` or `ApplicationController#current_player` (they already refuse a banned player); removing `game:drop_friends_and_trades` (still needed for console bans and old data); changing how the back-office refuses non-staff (403 / sign-in redirect).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Queue | moderator; reports on players in good standing, some handled | one row per reported player with open reports, latest report first: name, count per reason, total, latest time, BANNIR, CLASSER | none |
| Ban | moderator bans a reported player | `banned_at` set, open reports handled, `PlayerBanned` published (trades cancelled, friendships dropped), the player leaves the queue and appears in the banned list; notice | none |
| Banned afterwards | banned player signs in; anyone opens their profile | sign-in refused with `errors.accounts.banned`; profile shows the unavailable page (404) | existing behavior |
| Unban | moderator lifts the ban | `banned_at` cleared, `PlayerUnbanned` published; sign-in and profile work again; old reports stay handled | none |
| Dismiss | moderator classes a player's reports | open reports of that player handled, `ReportsDismissed` published; row leaves the queue | none |
| Administrator target | moderator or administrator bans an administrator | nothing changes; the queue row shows the refusal instead of BANNIR | `Failure(:cannot_ban_administrator)`, alert |
| Self | staff bans themselves | nothing changes | `Failure(:cannot_ban_self)`, alert |
| Twice | ban a banned player / unban a player not banned | nothing changes, no event | `Failure(:already_banned)` / `Failure(:not_banned)`, alert |
| Unknown / deleted target | token unknown or account deleted | nothing changes | `Failure(:player_not_found)`, alert |
| Not staff | visitor or player hits any new page or action; operation called with a non-staff actor | visitor redirected to sign in, player 403; nothing changes | Pundit; `Failure(:staff_required)` |
| Role | `bin/rails "accounts:set_role[<steam id>,moderator]"` | role stored, `RoleChanged` published, task prints it | unknown Steam id, deleted account or role: task aborts with a message |

</intent-contract>

## Code Map

- `packs/accounts/app/models/accounts/player.rb` -- roles, `banned?`, `deleted?`, `staff?`, `in_good_standing`, `stream_key` rotation on ban (`before_save`).
- `packs/accounts/app/models/accounts/report.rb`, `report_player.rb` -- the report model and its operation (a repeat by the same reporter returns the existing row, even if handled: leave as is).
- `packs/accounts/app/operations/accounts/delete_player.rb` -- the pattern to copy for locking and publishing (`player.lock!("FOR NO KEY UPDATE")`, `publish(..., stream_name: "Accounts::Player$#{id}")`, then `update!`).
- `packs/accounts/app/events/accounts/player_banned.rb` -- exists, published by nothing yet. `config/initializers/event_store.rb` already subscribes `PlayerStream` (reads ties first) and `Game::Handlers::PlayerBanned` (runs `Game::DropFriendsAndTrades`, accepts any persisted player) -- keep that order; new events need no subscriber.
- `lib/application_operation.rb` -- `transaction`, `publish`, `failure_message` (`errors.accounts.<code>`).
- `packs/game/lib/tasks/game.rake`, `test/support/rake_tasks.rb`, `test/packs/game/drop_friends_and_trades_test.rb` -- rake task and test patterns; that test's `ban` helper can stay.
- `test/packs/game/delete_player_concurrency_test.rb` -- the two-thread pattern for the ban concurrency test.
- `app/controllers/back_office/seasons_controller.rb`, `import_runs_controller.rb`, `app/policies/back_office/seasons_policy.rb` -- controller (`authorize [ :back_office, :x ], :y?`, `rate_limit`, redirect with notice or `Op.failure_message`) and headless policy patterns; `Steam::ResumeImport.refusal` is the pattern for a class-level `refusal` a view asks.
- `app/views/back_office/seasons/index.html.erb`, `dashboard/show.html.erb`, `import_runs/_time.html.erb` -- `ledger` table, `PanelComponent`, `ButtonComponent` (`variant: :danger`, `size: :small`, `method: :post|:delete`, `params:`, `confirm:`), time partial.
- `app/helpers/public_profiles_helper.rb` (`public_profile_title`) -- the player's display name with the code fallback; reuse it.
- `app/controllers/concerns/shelf_loading.rb` -- Pagy usage (`pagy(:offset, relation, limit:, page:)`).
- `config/routes.rb` -- the `scope "back-office", module: :back_office, as: :back_office` block; the token constraint `/[1-9A-HJ-NP-Za-km-z]{24}/`.
- `test/controllers/back_office/dashboard_controller_test.rb`, `test/policies/back_office/dashboard_policy_test.rb`, `test/system/import_run_test.rb` -- sign-in helpers and test shapes. `test/fixtures/accounts/players.yml` has `player`, `moderator`, `administrator`, `banned`.
- `README.md` "## Production checks" -- where the runbook section goes.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/<ts>_add_handled_at_to_accounts_reports.rb`, `db/schema.rb` -- nullable `handled_at` datetime; regenerate the schema from a fresh database -- the queue's state
- [x] `packs/accounts/app/events/accounts/{player_unbanned,reports_dismissed,role_changed}.rb` -- events like `player_banned.rb`
- [x] `packs/accounts/app/operations/accounts/ban_player.rb` -- `call(staff:, player:)` → `Success(player) | Failure(:staff_required | :player_not_found | :cannot_ban_self | :cannot_ban_administrator | :already_banned)`; class method `refusal(staff:, player:)` (code or nil) used by `call` before and after the lock and by the queue view; in the transaction: lock, re-check, publish `PlayerBanned` (`player_id`, `staff_id`), mark the player's open reports handled, set `banned_at`
- [x] `packs/accounts/app/operations/accounts/unban_player.rb` -- `call(staff:, player:)`; `:staff_required | :player_not_found | :not_banned`; publishes `PlayerUnbanned`
- [x] `packs/accounts/app/operations/accounts/dismiss_reports.rb` -- `call(staff:, player:)`; marks the player's open reports handled; `Failure(:no_open_reports)` when none (no event); publishes `ReportsDismissed`
- [x] `packs/accounts/app/operations/accounts/set_role.rb`, `packs/accounts/lib/tasks/accounts.rake` -- `SetRole.new.call(steam_id:, role:)` (`:player_not_found | :invalid_role`), `accounts:set_role[steam_id,role]` prints the result or aborts with the translated failure
- [x] `packs/accounts/app/queries/accounts/{report_queue,banned_players}.rb` -- the queue: players in good standing with open reports, ordered by latest open report desc (a relation Pagy can count), plus the per-reason counts and latest time for a page of players; open-queue size for the dashboard; banned (not deleted) players, latest ban first
- [x] `config/routes.rb` -- `resources :reports, only: :index` + `post "reports/:token/dismiss"`; `resources :bans, only: %i[index create destroy], param: :token` (create reads `params[:token]`), token constraints
- [x] `app/policies/back_office/{reports,bans}_policy.rb` -- `index?`, `dismiss?`, `create?`, `destroy?` = `moderator?`
- [x] `app/controllers/back_office/{reports,bans}_controller.rb` -- index pages (Pagy, 50 a page) and the actions; `rate_limit to: 30, within: 1.minute` on writes; redirect to the queue (ban, dismiss) or the banned list (unban) with a notice naming the player (`public_profile_title`) or the failure message
- [x] `app/views/back_office/reports/index.html.erb`, `app/views/back_office/bans/index.html.erb`, `app/views/back_office/dashboard/show.html.erb` -- ledger tables; queue row: name linking to the public profile, the four reason counts (labels `reports.reasons.*`), total, latest time, BANNIR (danger, confirm) or the refusal text, CLASSER (secondary, confirm); banned list: name, ban time, LEVER LE BAN; empty states; dashboard: the queue size line replaces the "empty" panel, links to both pages shown by policy; rows carry the player token as a data attribute for tests, no ids
- [x] `config/locales/{fr,en}.yml` -- page copy, notices, `errors.accounts.{staff_required,cannot_ban_self,cannot_ban_administrator,already_banned,not_banned,no_open_reports,invalid_role}`
- [x] `README.md` -- "### Staff accounts and moderation": the rake task (locally and through `bin/kamal app exec`), who can do what, ban from the back-office rather than the console (a console ban still needs `game:drop_friends_and_trades`)
- [x] `packs/accounts/app/models/accounts/player.rb` (comment only if it names the console ban), `app/controllers/back_office/dashboard_controller.rb` -- drop the stale "empty shell" wording
- [x] Tests: `test/packs/accounts/{ban_player,unban_player,dismiss_reports,set_role}_test.rb` (every matrix row of its operation; the ban drops a friendship and cancels an open trade through the real handler; the event data); `test/packs/accounts/ban_player_concurrency_test.rb` (a ban racing a trade acceptance between the banned player and a friend ends without deadlock, the trade closed); `test/packs/accounts/report_queue_test.rb`; `test/policies/back_office/{reports,bans}_policy_test.rb` (visitor, player, moderator, administrator); `test/controllers/back_office/{reports,bans}_controller_test.rb` (visitor redirected, player 403 on every action, moderator paths, refusals, no database id in the HTML); dashboard test updated; rake task test; `test/system/moderation_test.rb` (below)

**Acceptance Criteria:**
- Given a reported player, when a moderator opens the back-office, follows "Les signalements" and bans them (confirming), then the player can no longer sign in (the Steam callback shows the banned alert) and their profile shows "Profil indisponible"; when the moderator lifts the ban from "Les bannis", then both work again -- in `test/system/moderation_test.rb`.
- Given a moderator in the queue, an administrator's row shows the refusal instead of BANNIR.
- Given the suite, when the verification commands run, then all pass.

## Design Notes

A queue row leaves the queue when its reports are handled (ban or dismiss) or when the player is banned or deleted; a new report after that brings the player back. `handled_at` on the report rows is the queue's only state: no separate moderation table. The refusal rules live in `Accounts::BanPlayer.refusal`, so the view and the operation cannot disagree.

## Verification

Environment for every command (own database): `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w7_5`, `CHROME_BIN=/usr/bin/chromium`; Postgres runs on 5433 (`docker ps`).

**Commands:**
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` -- expected: no strong_migrations error; `db/schema.rb` diff is only the new column
- `bin/ci` -- expected: green (stage `db/schema.rb` first: its migration step runs `git diff --exit-code -- db/schema.rb`)
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` -- expected: clean
- `bin/rails test test/system/moderation_test.rb test/system/public_profile_test.rb test/system/import_run_test.rb test/system/settings_test.rb` -- expected: green

## Implementation Notes

- `Accounts::Player.acting_staff?` (staff role, persisted, neither banned nor deleted) is the staff check shared by the four operations; `Accounts::Report.unhandled` is the open-report scope (`open` would shadow `Kernel#open`).
- `RoleChanged` carries `role` beside `player_id`: an enum value, not personal data. Setting the role a player already holds succeeds without an event.
- `DismissReports` returns `Success(count)` of the reports it handled; it accepts a banned (not deleted) player, so a console-banned player's leftover reports can be classed.
- After review: `DismissReports.refusal` adds `:cannot_dismiss_self`, and the staff member's own row shows it instead of CLASSER. `ReportQueue.rows` skips a paged player whose reports were handled after the page was read.
- The queue's refusal column shows `cannot_ban_self` on the staff member's own row as well as `cannot_ban_administrator`.
- No index on `handled_at`: the plan asks for a schema diff of the column only; the queue groups by `reported_id`, already indexed.
- The rake task prints in the default locale (English).

## Plan Change Log

## Review Triage Log

### 2026-10-09 — Review pass
- verdicts: 32 findings — high 0, medium 6, low 22, false 4, maybe-false 0 (rows sharing a root cause are grouped; entries patched: medium 4 — the queue race, the rate-limit tests, the paging tests, the self-dismiss refusal — and low 8)
- findings:
  - `[low]` `[patch]` (intent) The queue shows no reporter while `Accounts::Report`'s comment says it names the reporter "for the staff's queue" — grouped with the blind hunter's reporter finding: the comment now says what is true (the reporter is kept, the queue counts open reports).
  - `[low]` `[patch]` (intent) Moderator against moderator neither decided nor tested — grouped with the blind hunter's finding: a test pins that a moderator bans another moderator (the rule: no one bans an administrator or themselves).
  - `[false]` `[reject]` (intent) Staff accounts are not made in a literal Rails console — the runbook gives a command run from a shell or `bin/kamal app exec`, through `Accounts::SetRole`; that is a console recipe, and AGENTS.md wants writes through an operation.
  - `[false]` `[reject]` (intent) No test of a signed-in player being signed out when the ban lands — `test/controllers/authorization_test.rb:85` ("a player banned meanwhile is signed out on their next request") covers `current_player`, which this change does not touch.
  - `[low]` `[reject]` (intent) The system test does not visit the back-office as a visitor or a player — the integration tests refuse both on every new action (redirect, 403); a browser run adds nothing the request tests do not show.
  - `[medium]` `[patch]` (blind) `ReportQueue.rows` raised KeyError when a paged player's reports were handled between its queries (500 on the queue) — grouped with the edge-case and verification-gap rows: `latest[player.id]` with `filter_map`, a test handles reports after the page is read.
  - `[low]` `[patch]` (blind) The edited `Accounts::Report` comment kept "(CAP-15, AD-14)" — ids removed.
  - `[low]` `[patch]` (blind) `errors.accounts.cannot_ban_self` used "tu" among "vous" messages — reworded with "vous".
  - `[low]` `[reject]` (blind) No index on `handled_at` for the queue's GROUP BY — reports are few (one per reporter and reported player, five a day per reporter); a partial index is a migration for a cost not met at launch.
  - `[low]` `[reject]` (blind) A console ban leaves open reports that come back on unban — the README advises against console bans, and the resurfaced reports were never reviewed, so seeing them again is not wrong.
  - `[low]` `[patch]` (blind) The queue never names reporters, contrary to the `Report` comment — grouped with the intent row above (comment corrected); showing reporters is a feature the ticket does not ask for.
  - `[low]` `[reject]` (blind) No audit trail or ban reason on any page — the events record the staff member's id; a page for it is a feature beyond the ticket; recorded in `deferred-work.md`.
  - `[low]` `[reject]` (blind) `SetRole` can demote the last administrator or promote a banned account — an operator's console action, undone by the same task; guards add branches for a case met by hand only.
  - `[low]` `[patch]` (blind) Moderator banning moderator undecided and untested — grouped with the intent row; test added.
  - `[low]` `[patch]` (blind) `UnbanPlayer`'s re-check under the lock untested — test added: a stale copy of an unbanned player gets `Failure(:not_banned)` and no event.
  - `[low]` `[reject]` (blind) The "player exists" condition is repeated in three operations — one-line identical checks; a shared predicate adds surface without a named divergence today.
  - `[low]` `[reject]` (blind) Redirects after BAN, CLASSER or LEVER LE BAN lose the page — the acted-on row leaves the list, shifting pages anyway; the queue rarely passes 50 rows.
  - `[low]` `[reject]` (blind) Paging constants duplicated in two controllers — two lines each, no divergence named.
  - `[low]` `[patch]` (blind) The two new controllers' class comments are hard to parse and restate the policies — deleted.
  - `[false]` `[reject]` (blind) Two Code Map bullets merged by a missing newline — the fix edits this build's plan (already corrected outside the review).
  - `[low]` `[reject]` (blind) The template asks `BanPlayer.refusal` and `Report.reasons` itself — a layering preference with no named harm; the refusal is tested through the controller.
  - `[medium]` `[patch]` (verification gap) The `rate_limit` on ban, unban and dismiss is untested — throttle tests with `with_counting_rate_limit` for bans and dismiss (31st request is 429).
  - `[medium]` `[patch]` (verification gap) Paging of the queue and the banned list untested at the controller — page-2 tests with 51 rows each, checking the remaining row and the page links.
  - `[medium]` `[patch]` (verification gap, other) KeyError race in `ReportQueue.rows` — grouped with the blind hunter's row; patched there.
  - `[low]` `[patch]` (verification gap, other) README and the queue's intro said "a new report brings the player back", but a repeat by the same reporter keeps the handled row — reworded: a report from a player who had not reported them yet.
  - `[medium]` `[patch]` (edge) KeyError race in `ReportQueue.rows` — grouped with the blind hunter's row; patched there.
  - `[low]` `[reject]` (edge) A report committed between the ban's `update_all` and its `banned_at` write stays open — needs a report racing the ban within milliseconds, and the result (a report seen after an unban) is benign; reordering does not close the race either, as a report can still follow the commit.
  - `[low]` `[reject]` (edge) The acting staff member is never locked, so two moderators can ban each other at once — needs two moderators acting on each other in the same instant; locking the actor adds lock-order rules for it.
  - `[medium]` `[patch]` (edge) A staff member could CLASSER the reports filed against themselves — `DismissReports.refusal` returns `:cannot_dismiss_self`, their own row shows the refusal instead of the button, tests in the operation and controller.
  - `[low]` `[reject]` (edge) The queue links a private profile to the unavailable page — the queue shows the name, which a name report concerns; staff seeing hidden profiles changes the one visibility question; recorded in `deferred-work.md`.
  - `[false]` `[reject]` (edge) A page past the last says the queue is empty — Pagy is given the page from the URL and an out-of-range page only comes from a hand-made link; it shows nothing false about the first page, which the dashboard counts.
  - `[low]` `[patch]` (edge) "A new report brings them back" overstated — grouped with the verification-gap row; reworded.

## Auto Run Result

Status: built.

**Summary:** staff reach a queue of reported players at `/<locale>/back-office/reports` (one row per player in good standing with open reports, counts per reason, latest first, 50 a page) with BANNIR and CLASSER, and the banned players at `/<locale>/back-office/bans` with LEVER LE BAN. `Accounts::BanPlayer` (no one bans an administrator or themselves) locks the player row, publishes `Accounts::PlayerBanned` (Game's existing handler cancels trades and drops friendships and invitations), marks the open reports handled and sets `banned_at`; sign-in refusal and the unavailable profile follow from the existing ban checks and `Game::Visibility`. `Accounts::UnbanPlayer` and `Accounts::DismissReports` (no one classes the reports against themselves) publish their own events. Staff roles are set with `bin/rails "accounts:set_role[<steam id>,<role>]"` through `Accounts::SetRole`; the README's runbook says how. The dashboard shows the queue's size.

**Files changed:**
- `db/migrate/20261009120000_add_handled_at_to_accounts_reports.rb`, `db/schema.rb` -- nullable `accounts_reports.handled_at`.
- `packs/accounts/app/operations/accounts/{ban_player,unban_player,dismiss_reports,set_role}.rb`, `packs/accounts/app/events/accounts/{player_unbanned,reports_dismissed,role_changed}.rb` -- the operations and events.
- `packs/accounts/app/queries/accounts/{report_queue,banned_players}.rb` -- the queue and the banned list.
- `packs/accounts/app/models/accounts/{player,report}.rb` -- `Player.acting_staff?`, `Report.unhandled`, comment.
- `packs/accounts/lib/tasks/accounts.rake` -- `accounts:set_role`.
- `app/controllers/back_office/{reports,bans,dashboard}_controller.rb`, `app/policies/back_office/{reports,bans}_policy.rb`, `config/routes.rb` -- the pages and actions, staff only.
- `app/views/back_office/{reports,bans}/index.html.erb`, `app/views/back_office/dashboard/show.html.erb`, `config/locales/{fr,en}.yml` -- the ledgers, links, copy and error messages.
- `README.md` -- "Staff accounts and moderation".
- Tests: operations, concurrency (ban against a trade acceptance, both orders), query, policies, controllers (refusals, 403 and sign-in redirect, throttles, page 2), dashboard, rake task, `test/system/moderation_test.rb`.
- `_bmad-output/initiative-gameble/pending-approvals.md`, `deferred-work.md` -- the moderation choices to confirm, the console-ban note, two follow-ups.

**Review findings:** thorough review (four lenses), 32 findings. Patched: 4 medium entries (the queue's KeyError race, the untested rate limits, the untested paging, a staff member classing the reports against themselves) and 8 low (planning ids in a comment, the Report comment's reporter claim, "tu" in French, controller comments, moderator-bans-moderator test, unban re-check test, "a new report brings them back" wording, grouped rows). Deferred: none in this plan (two follow-ups written to `deferred-work.md`: staff cannot read a hidden reported profile; no page records bans and dismissals). Rejected: the rows marked `reject` above, each with its reason (no index on `handled_at`, console-ban leftovers on unban, audit page, `SetRole` guards, repeated predicate, page lost on redirect, duplicated paging constants, template layering, report racing the ban, unlocked actor, private profile link, browser test of refusals, and four false findings).

**Follow-up review recommended:** true -- four medium entries were patched (high 0, medium 4, low 8). The risk not yet reviewed by a lens: the self-dismiss refusal (`DismissReports.refusal`, the queue row's two refusal columns) and the `ReportQueue.rows` skip were written in the fix pass and checked only by their own tests.

**Verification:** `bin/ci` (setup, rubocop, packwerk, i18n-tasks missing, typecheck, bundler-audit, brakeman, migrations from scratch with no schema drift, 1766 Rails tests, seeds): green; `npm run test:js` (168): green; `bin/rails zeitwerk:check`: all good; `bundle exec packwerk check`: no offenses; system tests `moderation_test.rb`, `public_profile_test.rb`, `import_run_test.rb`, `settings_test.rb`, `shell_test.rb`: 31 runs, 0 failures. `bin/setup` rewrote `package-lock.json`'s name to the worktree's; reverted.

**Residual risks:** a ban drops friendships and trades for good, an unban restores neither; a ban set by hand in the console still needs `game:drop_friends_and_trades`; the back-office refuses non-staff with 403 or the sign-in redirect where EXPERIENCE.md wants it to look absent (pending approval).

## Remote build (4b65cd6), superseded at the 2026-10-09 reconciliation

The same story was also built on the remote `develop` in commit `4b65cd6` (a quick review, a reports page with ban and unban by player token, `Accounts::ModerationSteps`, failure code `cannot_ban_administrator`, no ban reason and no handled reports). When the two histories were reconciled on 2026-10-09 the author kept this local build, on which the moderation by rank, the players list and the moderation history were built; the remote controllers, views, policies, operations, queries, routes, locale keys and tests were dropped. Two parts were carried over: the remote tests that ban and unban through the operations and check sign-in and the visitor's view of the profile both ways (now in `test/controllers/authorization_test.rb` and `test/controllers/public_profiles_controller_test.rb`, with `staff:` and `reason:`), and the re-read of the acting member of staff inside the transaction, so `BanPlayer` and `UnbanPlayer` refuse a member of staff demoted or banned since they were read.
