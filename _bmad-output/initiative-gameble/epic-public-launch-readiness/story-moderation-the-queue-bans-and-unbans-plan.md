---
title: 'Moderation: the queue, bans and unbans'
type: 'feature'
ticket: '5'
created: '2026-10-08'
status: 'built'
baseline_revision: '7879f9ec2e17014f19f5c42312201f986ce49185'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md', '{project-root}/_bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness.md']
warnings: ['oversized']
deferred:
  - summary: >-
      The moderation queue keeps every report on players in good standing forever and loads them all.
    evidence: |-
      Accounts::ReportQueue has no limit and reports have no status, so a player reviewed and kept, or unbanned, stays in the queue with all their reports; it needs a reviewed/dismissed state or a cap decided by the author.
    location: >-
      packs/accounts/app/queries/accounts/report_queue.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** Players can report a profile, but staff have nowhere to see the reports and no way to ban or unban: bans are set by hand in the console, and `Accounts::PlayerBanned` (whose Game handler drops the banned player's friendships and trades) is never published.

**Approach:** A back-office "Reports" page for staff (moderators and administrators): the reports on players not banned, newest first, each naming the reported player, the reason, the reporter and the date, with a "Ban" action per reported player; below, the banned players with an "Unban" action. `Accounts::BanPlayer` sets `banned_at` (which already blocks sign-in, ends the session on the next request, rotates the private stream key and makes `Game::Visibility` hide the profile) and publishes `Accounts::PlayerBanned` in its transaction; `Accounts::UnbanPlayer` clears it and publishes `Accounts::PlayerUnbanned`. No one bans an administrator or themselves. The README gains a "Staff accounts and bans" section: making a moderator or administrator from the console, and banning from the console through the operation.

## Boundaries & Constraints

**Always:** writes only through the operations (`Accounts::VerbNoun`, `Success`/`Failure(:code)`, one event in the transaction, the player row locked `FOR NO KEY UPDATE` as `DeletePlayer` does); failure codes `cannot_ban_administrator`, `cannot_ban_self`, `already_banned`, `not_banned`, `player_not_found` with `errors.accounts.<code>` added by hand in both `en.yml` and `fr.yml`; every action has a Pundit policy (`BackOffice::ReportsPolicy` and ban/unban policies: `moderator?`, which administrators also pass); a visitor and a non-staff player are refused as the back-office already refuses them (redirect with `authorization.sign_in_required` for a visitor, 403 `authorization.forbidden` for a player — the convention of the roles story); players are named by token in URLs and forms, never by id; GET pages read only; staff copy in the back-office's plain functional style and its "officer" voice; every string in both locales; tests for each policy signed out and as a non-staff player.

**Never:** a reporter's identity outside the back-office; deleting reports; a ban reason or duration; banning an administrator or oneself, whatever the actor's role; a change to sign-in, `current_player` or `Game::Visibility` (they already honour `banned_at`); a change to the 403/redirect refusal convention; editing `pending-approvals.md`; planning ids in code, tests or README.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Queue | staff opens Reports | reports on non-banned players, newest first (reported, reason, reporter, date) + banned players list | — |
| Ban | moderator bans a reported player | `banned_at` set, `PlayerBanned` published (friends and trades dropped), the player leaves the queue for the banned list; notice | — |
| Banned can't sign in | banned player signs in | refused with `errors.accounts.banned`; their public profile is the unavailable page (404) | — |
| Unban | staff unbans | `banned_at` cleared, `PlayerUnbanned` published; sign-in works and the profile shows again | — |
| Ban an administrator | any staff → administrator | `Failure(:cannot_ban_administrator)`, nothing changes | alert with the error message |
| Ban oneself | staff → self | `Failure(:cannot_ban_self)` | alert |
| Ban twice / unban not banned | — | `already_banned` / `not_banned` | alert |
| Unknown token | — | `player_not_found` (or 404) | — |
| Visitor / non-staff | GET Reports, POST ban | redirect with sign-in required / 403 | — |

</intent-contract>

## Code Map

- `config/routes.rb` -- `scope "back-office", module: :back_office, as: :back_office` (import runs, seasons, cards): add `resources :reports, only: :index` and ban/unban as POSTs by player token (e.g. `resources :bans, only: %i[create destroy], param: :token` or `post "players/:token/ban"` / `post "players/:token/unban"`), token constraint as `brothers` uses (`/[1-9A-HJ-NP-Za-km-z]{24}/`).
- `app/controllers/back_office/import_runs_controller.rb` -- pattern: `authorize [ :back_office, :x ], :action?` first, `rate_limit to: 10, within: 1.minute, only: …`, redirect with `notice: t(".done")` or `alert: Op.failure_message(result.failure)`; `app/views/back_office/import_runs/index.html.erb` -- `<table class="ledger">`, `PanelComponent`, `content_for :back_button`.
- `app/controllers/back_office/dashboard_controller.rb` + `app/views/back_office/dashboard/show.html.erb` -- the shell (comment "An empty shell for now"), one `ButtonComponent` link per section guarded by `policy([:back_office, :x]).index?`: add "Reports"; the `empty` line no longer fits once moderation exists — reword it.
- `app/policies/application_policy.rb` (`visitor?`, `player?`, `moderator?` true for administrators, `administrator?`), `app/policies/back_office/dashboard_policy.rb` (`show? = moderator?`) and its test `test/policies/back_office/dashboard_policy_test.rb` (loop over visitor/player/moderator/administrator with `policy_for`).
- `packs/accounts/app/models/accounts/player.rb` -- `role` enum, `banned?`, `staff?`, `in_good_standing`, `before_save :rotate_stream_key, if: :banned_or_deleted_now?` (setting `banned_at` rotates; clearing does not).
- `packs/accounts/app/models/accounts/report.rb` -- reasons `inappropriate_name cheating harassment other`, `reporter`/`reported`; no status. Add a query `Accounts::ReportQueue` (reports on players in good standing, newest first, with reporter and reported preloaded) and `Accounts::BannedPlayers` (banned, not deleted, newest ban first).
- `packs/accounts/app/operations/accounts/delete_player.rb` -- lock and publish pattern, stream `"Accounts::Player$#{id}"`. New `ban_player.rb` (`call(actor:, player:)` or by token) and `unban_player.rb`; `packs/accounts/app/events/accounts/player_banned.rb` exists (empty), add `player_unbanned.rb`; `config/initializers/event_store.rb` L11-15 already subscribes `Game::Handlers::PlayerBanned` and `PlayerStream` (`CUT_OFF_EVENTS`) to `PlayerBanned`.
- `packs/accounts/app/queries/accounts/player_by_token.rb` -- returns banned players too (needed for unban).
- `config/locales/en.yml` L172 / `fr.yml` L177 `back_office.*`, `errors.accounts.*` (en L998-1007, fr L1020+), reason labels already exist for the report dialog (reuse them).
- `README.md` "## Production checks" (L64+, `###` sections, `sh` blocks; console through `bin/kamal console` or `bin/kamal app exec --reuse 'bin/rails runner "…"'`) -- add "### Staff accounts and bans".
- Tests: `test/packs/accounts/` (operations: ban by moderator and administrator, refusals, event published once inside the transaction, friendships and trades dropped through the handler, unban), `test/controllers/back_office/reports_controller_test.rb` (+ ban/unban), policies tests, `test/controllers/authorization_test.rb` L85-130 (banned sign-in), `test/controllers/public_profiles_controller_test.rb` (profile unavailable when banned, back after unban), a system test: a moderator bans a reported player from the queue and the player's profile is unavailable; unban restores it.

## Tasks & Acceptance

**Execution:**
- [x] `packs/accounts/app/operations/accounts/ban_player.rb`, `unban_player.rb`, `events/accounts/player_unbanned.rb`, `queries/accounts/report_queue.rb`, `banned_players.rb` (+ tests) -- the operations, rules and reads.
- [x] `config/routes.rb`, `app/controllers/back_office/reports_controller.rb` (+ ban/unban controller or actions), `app/policies/back_office/*_policy.rb` -- staff-only pages and actions, rate-limited writes.
- [x] `app/views/back_office/reports/index.html.erb`, dashboard link and wording -- the queue and the banned list, actions as `button_to` POSTs with a browser confirm.
- [x] `config/locales/en.yml`, `fr.yml` -- back-office copy, `errors.accounts.*` codes.
- [x] `README.md` -- "Staff accounts and bans".
- [x] Tests -- every matrix row; policies signed out and as a non-staff player; system test ban → unavailable profile → unban.

**Acceptance Criteria:**
- Given a moderator on the Reports page, when they ban a reported player, then that player can no longer sign in, their public profile shows as unavailable, and they appear under the banned players; when unbanned, sign-in and the profile come back.
- Given a moderator or an administrator, when they try to ban an administrator or themselves, then it is refused with a message and nothing changes.
- Given a visitor or a non-staff player, when they open the Reports page or post a ban, then they are refused as the back-office refuses them.

## Implementation Notes

- Both operations share `Accounts::ModerationSteps`: the actor must be staff in good standing (a new code, `staff_required`, for a console call naming a non-staff or removed actor; the web layer never reaches it past the policy), the target a saved, undeleted player; the checks run again after the `FOR NO KEY UPDATE` lock, so a stale copy is refused (`already_banned`) and a role changed meanwhile is seen. Self is checked before administrator, so an administrator banning themselves reads `cannot_ban_self`.
- As in `DeletePlayer`, the event is published (and the Game handler run) before the row update.
- The queue groups the reports by reported player (latest report first), one Ban button per player; the reported name links to their public profile. Unban is `POST /back-office/players/:token/unban` (`bans#destroy`).
- The dashboard's `empty` line became `intro`; the old "empty shell" controller comment is gone.

## Plan Change Log

## Review Triage Log

### 2026-10-08 — Review pass
- verdicts: 5 findings — high 0, medium 1, low 4, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` A reported moderator or administrator reading Reports saw who reported them, against the report dialog's promise — fixed: `ReportQueue.call(viewer:)` leaves out the reports on the viewer; no Ban button on an administrator's or the viewer's own reports.
  - `[low]` `[patch]` The reported player's name linked to a 404 for a friends-only or private profile — fixed: a link only when `Game::Visibility.visible?(nil, reported)`, else the plain name.
  - `[low]` `[defer]` The queue loads every report ever filed on players in good standing and never shrinks (reports have no status) — settling it needs a report status or a reviewed mark, a design choice beyond this story.
  - `[low]` `[patch]` The actor's staff standing was read from the object passed in, so a stale console object of a demoted or banned officer could still ban — fixed: `reread_staff` looks the actor up again inside the transaction.
  - `[low]` `[patch]` The routes comment called the whole back-office scope administrators-only — fixed: staff only, each group naming its role.


## Verification

All Ruby commands need Ruby 4.0.7 from rbenv: prefix them with `export PATH=/opt/rbenv/shims:$PATH && `; system tests also need `CHROME_BIN=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/chrome.sh SE_CHROMEDRIVER=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/cd/chromedriver`. Never run `npm install`.

**Commands:**
- `bin/rails test` -- expected: all green
- the new and touched system tests (system env above), 3× -- expected: green
- `bin/rubocop && bundle exec packwerk check && bin/rails zeitwerk:check && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused && bin/brakeman -q` -- expected: clean

## Auto Run Result

**Summary.** Staff (moderators and administrators) get a back-office Reports page: the reports on players not banned, newest first (reported, reason, reporter, date; none on the viewer), a Ban action per reported player, and the banned players with Unban. `Accounts::BanPlayer` / `UnbanPlayer` lock the player, publish `PlayerBanned` / `PlayerUnbanned` in their transaction (the ban drops friendships and trades through the existing Game handler) and set or clear `banned_at`, which already blocks sign-in and hides the profile. No one bans an administrator or themselves. The README documents staff accounts and bans from the console.

**Files.**
- `packs/accounts/app/operations/accounts/{ban_player,unban_player,moderation_steps}.rb`, `events/accounts/player_unbanned.rb`, `queries/accounts/{report_queue,banned_players}.rb`.
- `app/controllers/back_office/{reports,bans}_controller.rb`, `app/policies/back_office/{reports,bans}_policy.rb`, `config/routes.rb`.
- `app/views/back_office/reports/index.html.erb`, dashboard link and wording.
- `config/locales/en.yml`, `fr.yml`; `README.md` "Staff accounts and bans".
- Tests: operations, queries, policies, controllers, authorization, public profiles, `test/system/moderation_test.rb`.

**Review.** One quick pass: 1 medium + 3 low patched, 1 low deferred (unbounded queue).

**Follow-up review recommended:** false.

**Verification.** `bin/rails test` 1869 runs green; rubocop, packwerk, zeitwerk, i18n-tasks, brakeman clean; system moderation, import_run, shell, public_profile: 22 runs green.

**Residual risks.**
- The back-office still refuses a non-staff player with 403 and a visitor with a redirect, while EXPERIENCE.md asks it to answer "as if it did not exist".
- `staff_required` refuses a non-staff actor (reachable only from the console).
- The ban publishes before writing `banned_at`, as the deletion does; a trade created in that instant is caught by the existing sweep task.
