---
title: 'Moderation by rank, a hidden back-office and staff reading every profile'
type: 'feature'
ticket: '13'
created: '2026-10-09'
status: 'built'
baseline_revision: 'd08a06c886aee7effce227d50e49ff6c1957b82e'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Planning ids remain in comments and a heading this story did not write, in files it touched.
    evidence: |-
      Review pass 2026-10-09 (blind hunter): `### Steam import (AD-19)` in README.md, `(CAP-14)` in packs/accounts/app/models/accounts/player.rb, ids in the comments of seasons_controller_test.rb, import_runs_controller_test.rb, jobs_test.rb, public_profiles_controller_test.rb, reports_controller_test.rb and delete_player_concurrency_test.rb. Pre-existing; AGENTS.md forbids planning ids in code and tests.
    location: >-
      README.md, packs/accounts/app/models/accounts/player.rb, test/
    severity: low
---

<intent-contract>

## Intent

**Problem:** After story 5, any staff member bans, unbans and classes the reports of any other non-administrator, moderators included; the back-office tells a visitor and a player it exists (sign-in redirect, 403) where EXPERIENCE.md wants "the address answers as if it did not exist"; and a moderator following the queue to a private, friends-only or banned profile lands on "Profil indisponible" (author's decisions of 2026-10-09, R4, R1).

**Approach:** A rank order (player < moderator < administrator) decides who acts on whom in `BanPlayer`, `UnbanPlayer` and `DismissReports`, whose class-level `refusal` the queue and the banned list ask; a `BackOffice::BaseController` answers 404 before anything else to whoever is not staff; `Game::Visibility` gains a staff rule (every owner but a deleted one), applied on the public profile and the report endpoint, opted out on the feed and the friend profile. Closes story 5's follow-up review: `DismissReports` locks and re-checks like a ban, and `ReportQueue.rows` reads one consistent query.

## Boundaries & Constraints

**Always:** the acting staff member must outrank the target (`Accounts::Player#outranks?`), checked in the operation before the transaction and again after locking the target row; self keeps its own code (`cannot_ban_self`, `cannot_dismiss_self`) ahead of the rank code; one rank code `outranked` for the three operations, with copy in `fr.yml` and `en.yml` (English translated from the French, "vous", "officier"); the 404 is raised as `ActionController::RoutingError` from a `prepend_before_action`, so it fires before CSRF, `allow_browser`, `rate_limit` and Pundit, and renders the same `public/404.html` an unknown address gets; staff keep today's behaviour (a moderator on an administrator page still gets 403); Pundit still authorizes every action; a deleted owner is visible to no one; no planning ids in code or comments (remove the `AD-n` ids from comments you edit).

**Never:** changing who reaches what among staff; a role page; a staff marker on the profile page (deferred); changing `ApplicationController#refuse` or the refusals outside the back-office; a migration; touching the "Settled on 2026-10-09" section of `pending-approvals.md`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Moderator → player | ban, unban, dismiss | succeeds as today | none |
| Moderator → moderator | ban, unban a banned moderator, dismiss | nothing changes, no event; queue/banned rows show the refusal instead of the button | `Failure(:outranked)`, alert |
| Administrator → moderator | ban, unban, dismiss | succeeds | none |
| Anyone → administrator | ban, unban, dismiss (moderator or administrator actor) | nothing changes | `Failure(:outranked)` |
| Self | ban / dismiss own reports | nothing changes | `:cannot_ban_self` / `:cannot_dismiss_self` (before `outranked`) |
| Promoted meanwhile | target's role raised after the page was read, before the action | lock reloads the row; refusal re-checked | `Failure(:outranked)`, no event |
| Dismiss vs ban | a ban commits while a dismiss waits on the row | dismiss sees the reports handled | `Failure(:no_open_reports)`, no event |
| Queue race | reports handled (or handled then reported anew) between page read and row read | the row is skipped or shows the fresh counts; never a row with total 0, never a 500 | none |
| Not staff on back-office | visitor or non-staff player, any verb, any back-office address incl. `/back-office/jobs/...`, with or without CSRF token, past the rate limit | 404, same body as an unknown address; nothing changes | `ActionController::RoutingError` |
| Banned or deleted staff | session of a staff member since banned | 404 (signed out as a visitor) | as above |
| Staff on profile | moderator opens a private, friends-only or banned player's profile, or reports it | the profile renders; the report is accepted | none |
| Deleted owner | staff opens a deleted player's profile | unavailable page, 404 | existing |
| Non-staff on profile | visitor or player on a private / friends-only (not friend) / banned profile | unavailable page, 404, unchanged | existing |
| Feed, friend profile | staff viewer | same entries / same profile a player would see (no staff rule) | none |

</intent-contract>

## Code Map

- `packs/accounts/app/models/accounts/player.rb` -- enum `role` (player, moderator, administrator), `staff?`, `Player.acting_staff?` (staff, persisted, not banned or deleted). Add `outranks?(other)` from an explicit rank order.
- `packs/accounts/app/operations/accounts/ban_player.rb` -- `refusal(staff:, player:)` (class method) used before and after `player.lock!("FOR NO KEY UPDATE")` and by the queue view; replace `:cannot_ban_administrator` by `:outranked` after `:cannot_ban_self`.
- `packs/accounts/app/operations/accounts/unban_player.rb` -- private `permitted`; turn it into a class `refusal` (`:staff_required | :player_not_found | :outranked | :not_banned`) as `BanPlayer` does, used by the bans view.
- `packs/accounts/app/operations/accounts/dismiss_reports.rb` -- `refusal` has `:cannot_dismiss_self`; add `:outranked`; the transaction must now `player.lock!("FOR NO KEY UPDATE")` and re-check `refusal` before `update_all` (lock order player row → reports, the same as `BanPlayer`).
- `packs/accounts/app/queries/accounts/report_queue.rb` -- `rows` runs two grouped queries (`counts`, `latest`) that a commit between them can disagree on; read count and `MAX(created_at)` per `(reported_id, reason)` in one `pluck`, derive per-player counts, total and latest from it, skip players absent from it.
- `packs/game/app/models/game/visibility.rb` -- `visible?(viewer, owner)`; add keyword `staff_sees_all: true`: deleted (or nil) owner → false; then `Accounts::Player.acting_staff?(viewer)` → true when `staff_sees_all`; then today's banned / self / public / friends-only rules. Comment rewritten without planning ids.
- Callers: `app/controllers/public_profiles_controller.rb#load_owner` (keep default: staff read), `app/controllers/reports_controller.rb#create` (keep default: what staff see they may report), `packs/game/app/queries/game/feed_entries.rb` (`shown` hash: `staff_sees_all: false`), `app/controllers/friend_profiles_controller.rb` (`staff_sees_all: false`). `app/controllers/cards_controller.rb` (shared card page) does not ask: the card page names no owner; nothing to change. Friends list, trades, invitations, export ask no visibility question.
- `app/controllers/back_office/{dashboard,reports,bans,seasons,import_runs,cards}_controller.rb`, `jobs_base_controller.rb` -- all `< ApplicationController` today; make each inherit a new `BackOffice::BaseController`. Mission Control's controllers inherit `JobsBaseController` (`config/initializers/mission_control.rb`); its concerns add plain `before_action`s, so a prepended callback stays first.
- `app/controllers/application_controller.rb` -- `current_player` (nil for banned/deleted), `refuse` (unchanged). Around actions `read_only_unless_writing`, `switch_locale`; a prepended callback runs before them, which is fine: it only reads the player.
- `app/policies/back_office/*_policy.rb` -- comments say "A visitor is asked to sign in; a player is refused (403)"; rewrite: non-staff never reach the policy (404); a moderator is refused 403 on administrator pages.
- `app/views/back_office/reports/index.html.erb` -- refusal columns already read `BanPlayer.refusal` / `DismissReports.refusal`; nothing but the codes change. `app/views/back_office/bans/index.html.erb` -- show `UnbanPlayer.refusal` text (`data-unban-refusal`) instead of LEVER LE BAN when refused; link the name to `brother_path` (staff can now open a banned profile).
- `config/locales/{fr,en}.yml` -- `errors.accounts.cannot_ban_administrator` (lines ~986 / ~964) becomes `outranked`; `back_office.bans.index.intro` may mention the rank.
- `README.md` "### Staff accounts and moderation" and "### Job queue" -- who acts on whom; anyone not staff gets 404.
- Tests to update: `test/controllers/back_office/*_controller_test.rb` and `jobs_test.rb` (visitor redirect / player 403 → 404), `test/packs/accounts/{ban_player,unban_player,dismiss_reports}_test.rb`, `test/controllers/back_office/{reports,bans}_controller_test.rb` (`cannot_ban_administrator`), `test/system/moderation_test.rb:44`, `test/integration/shell_test.rb` ("an alert is an alert toast" uses the back-office as a visitor: use `settings_path` instead), `test/system/shell_test.rb:129` (same), `test/packs/game/visibility_test.rb` (if present; else the existing visibility tests). Fixtures `accounts_players(:player, :moderator, :administrator, :banned)`; `test/packs/game/delete_player_concurrency_test.rb` and `test/packs/accounts/ban_player_concurrency_test.rb` hold the two-thread pattern.

## Tasks & Acceptance

**Execution:**
- [x] `packs/accounts/app/models/accounts/player.rb` -- `outranks?(other)` -- the one rank rule
- [x] `packs/accounts/app/operations/accounts/{ban_player,unban_player,dismiss_reports}.rb` -- `outranked` after the self check; `UnbanPlayer.refusal`; `DismissReports` locks the target row and re-checks; update each doc comment's failure list -- rank rule enforced under the lock
- [x] `packs/accounts/app/queries/accounts/report_queue.rb` -- one grouped query in `rows` -- consistent rows under concurrent handling
- [x] `packs/game/app/models/game/visibility.rb`, `packs/game/app/queries/game/feed_entries.rb`, `app/controllers/friend_profiles_controller.rb`, `app/controllers/public_profiles_controller.rb`, `app/controllers/reports_controller.rb` -- staff rule and per-surface opt-out; refresh the comments that describe who sees what
- [x] `app/controllers/back_office/base_controller.rb` (new) and the seven back-office controllers -- `prepend_before_action` raising `ActionController::RoutingError` unless `current_player&.staff?` -- the hidden back-office
- [x] `app/policies/back_office/*_policy.rb` -- comments
- [x] `app/views/back_office/bans/index.html.erb`, `config/locales/{fr,en}.yml`, `README.md` -- refusal text, profile link, copy, runbook
- [x] Tests: operations (every matrix row: moderator→moderator refused for ban/unban/dismiss, administrator→moderator allowed for all three, anyone→administrator refused, self codes first, no event on refusal); concurrency: `test/packs/accounts/moderation_rank_concurrency_test.rb` (a promotion committed while a ban/dismiss holds a stale target gives `outranked`; a dismiss racing a ban ends with one `PlayerBanned`, no `ReportsDismissed`, `no_open_reports`); `test/packs/accounts/report_queue_test.rb` (reports handled after the page read, and handled then reported anew: no total-0 row); `Game::Visibility` (staff sees private, friends-only, banned; not deleted; `staff_sees_all: false` falls back; banned staff is no staff); feed (staff does not see a private player's entry); friend profile unchanged for staff; public profile and report controller (moderator opens private, friends-only, banned profiles; a player and a visitor still get the unavailable page); back-office: every route of `Rails.application.routes` under `back-office` plus `/back-office/jobs` and an engine sub-path, for a visitor and a player, every verb → 404 with the body of an unknown address, rate limit not consumed, and a forged POST without CSRF token also 404 (enable forgery protection for that test); staff behaviour unchanged (moderator 403 on administrator pages); views (refusal texts in queue and banned list; banned list links the profile); `test/system/moderation_test.rb` updated, plus a system test: a moderator opens a banned player's profile, a visitor gets "Profil indisponible"

**Acceptance Criteria:**
- Given a moderator in the queue with a reported moderator and a reported administrator, then both rows show the `outranked` refusal instead of BANNIR and CLASSER; given an administrator, the moderator's row shows both buttons and the ban succeeds.
- Given a visitor or a non-staff player, when they request `/fr/back-office`, any page under it, or `/back-office/jobs`, then the response is 404 with the same body as `/fr/back-office/nonexistent`.
- Given a moderator, when they open a private, a friends-only and a banned player's profile, then each renders; given a visitor or a non-friend player, each is "Profil indisponible" (404).
- Given the suite, when the verification commands run, then all pass.

## Implementation Notes

- The rank order is `Accounts::Player::RANKS` (player, moderator, administrator); `outranks?` compares indexes, so equal ranks never outrank each other.
- `UnbanPlayer` has no self code: a banned member of staff is no acting staff, so `staff_required` already covers it.
- In the test environment an unknown address renders the detailed exception page, not `public/404.html`. `test/support/hidden_back_office.rb` switches `action_dispatch.show_detailed_exceptions` off for the back-office tests (restored in teardown), so the body comparison is the production one; `test/controllers/back_office/hidden_test.rb` also compares against a real `/fr/back-office/nonexistent` response.
- The lock-race helpers duplicated in `ban_player_concurrency_test.rb` and `delete_player_concurrency_test.rb` moved to `test/support/lock_races.rb`, also used by the new `moderation_rank_concurrency_test.rb`.
- Besides `test/system/shell_test.rb:129`, "on a phone the toasts sit at the top" also used the back-office as a visitor to get a toast; both now use `settings_path`.
- The test fixtures' moderator served as a "stranger" or "friend" in the visibility, public profile and report tests; those now use a plain player created in the test, since staff now see every profile.

- After review: `RANKS` is the role enum's single source (`enum :role, RANKS.index_by(&:to_sym)`); the back-office check reads the player through `read_only_unless_writing`, so a GET reads it on the reading role; the profile's visibility lines name the officers; the queue's intro says the profile disappears for players and states the rank rule.

## Plan Change Log

## Review Triage Log

### 2026-10-09 — Review pass
- verdicts: 25 findings — high 0, medium 1, low 19, false 5, maybe-false 0 (pass also closes story 5's follow-up: the self-dismiss refusal, now before the rank and under the lock, and the queue's row skip, now one query, were read by the blind and edge-case lenses and tested under two threads)
- findings:
  - `[low]` `[patch]` (blind) `package-lock.json`'s name rewritten to the worktree's — grouped with the edge-case, verification-gap and intent rows on the same hunk: reverted; the commit holds no `package-lock.json` change.
  - `[medium]` `[patch]` (blind) The owner is told "Private profile: only you can see it" and "Visible to your friends only", false now that staff read every profile — both lines reworded in both locales to name the Brotherhood's officers; the profile tests assert the new copy.
  - `[low]` `[reject]` (blind) Staff get no sign a profile is banned or hidden; a banned public profile shows "Visible to all players" to staff — staff reach a banned profile from the banned list or the queue, knowing its state; a marker is a new branch and copy; recorded in `deferred-work.md`.
  - `[low]` `[reject]` (blind) Staff may report a banned player; that report stays out of the queue and appears on unban — needs staff to report a player they or a peer already banned; refusing it adds a branch in `ReportPlayer` or the profile; a report filed by staff surfacing after an unban is not wrong.
  - `[low]` `[patch]` (blind) The prepended check memoizes `current_player` before the GET switches to the reading role — grouped with the edge-case row: the read now runs through `read_only_unless_writing { current_player&.staff? }`, and the class comment says so.
  - `[low]` `[reject]` (blind) The acting staff member is not re-read under the lock, so one demoted or banned mid-request still acts — grouped with the edge-case row; as in story 5, needs a console role change or a ban landing within the request's milliseconds; the rank rule removes the one symmetric race (two moderators banning each other); re-reading the actor adds lock-order rules.
  - `[low]` `[patch]` (blind) `RANKS` repeats the enum's keys, so a role added to one only makes `outranks?` raise — grouped with the edge-case row: the enum is built from `RANKS`.
  - `[low]` `[reject]` (blind) `staff_sees_all:` defaults to true, so a new surface shows staff hidden players unless it opts out — the author's decision puts the staff rule in `Game::Visibility` itself ("lets staff see every profile"); the exposure is to staff only, and both opt-outs are tested.
  - `[low]` `[patch]` (blind) The queue's intro says a ban makes the profile disappear and does not state the rank rule — reworded in both locales ("pour les joueurs", the bans intro's rank sentence).
  - `[low]` `[defer]` (blind) Planning ids remain in lines this diff did not write (`AD-19` README heading, `CAP-14` in `player.rb`, ids in several test comments) — pre-existing; the lines the diff wrote carry none; recorded in `deferred` for a sweep.
  - `[low]` `[patch]` (blind) `PublicProfilesController`'s header comment half-rewrapped, and the staff case tacked on after the banned case — rewrapped; one sentence now says who gets the unavailable page, staff excepted.
  - `[low]` `[patch]` (blind) `HiddenTest::VERBS` omits HEAD; `HiddenBackOffice` mutates `env_config`; a stray blank line — HEAD added (404 asserted, no body); blank line removed; the `env_config` change is restored in teardown and the suite parallelizes by processes, not threads.
  - `[low]` `[patch]` (edge) Player memoized before the role switch — grouped with the blind row above; patched there.
  - `[low]` `[reject]` (edge) Staff demoted or banned mid-request still acts — grouped with the blind row above; rejected there.
  - `[low]` `[patch]` (edge) `RANKS` and the enum can drift — grouped with the blind row above; patched there.
  - `[low]` `[reject]` (edge) Staff report on a banned profile reappears on unban — grouped with the blind row above; rejected there.
  - `[low]` `[patch]` (edge) `package-lock.json` name — grouped with the first row; reverted.
  - `[low]` `[patch]` (verification gap, other) `package-lock.json` name — grouped with the first row; reverted. The lens found no verification gap.
  - `[false]` `[reject]` (intent) The feed and the friend profile opt out of the staff rule, diverging from a module-wide reading — the dispatch asked for a per-surface decision recorded in the plan; Design Notes and `pending-approvals.md` record it for the author.
  - `[low]` `[reject]` (intent) Staff reading turned into staff reporting, a write the intent does not name — chosen so SIGNALER on a profile staff read does not answer 404; recorded in `pending-approvals.md` for the author.
  - `[false]` `[reject]` (intent) The follow-up review is a process the diff cannot show — this pass is that review: the blind and edge-case lenses read `DismissReports.refusal` and `ReportQueue.rows`; the dismiss/ban race has a two-thread test and the row skip's two-query race is gone by construction.
  - `[low]` `[reject]` (intent) The 404 tests compare status and body, not headers, and no system test visits the 404 — the integration tests run every route and verb against the unknown address's body; a browser adds nothing to a static 404.
  - `[false]` `[reject]` (intent) An administrator classing a moderator's reports is tested only in the operation — the controller test shows CLASSER on that row and the operation test performs it; not a defect.
  - `[false]` `[reject]` (intent) Outside-intent changes: the lock-race helper moved, the banned list links profiles, ids dropped from edited comments — not defects (`package-lock.json` grouped with the first row).
  - `[false]` `[reject]` (intent) Unban has no self code — a banned staff member is no acting staff, so `staff_required` answers first; nothing reaches a self unban.

## Design Notes

Per-surface staff rule, the reasons:
- Public profile: applies, the reason for the change (the queue links there).
- Report endpoint: applies, so the SIGNALER of a profile staff can read works rather than answering 404 on a page they see.
- Shared card page: asks nothing (the card page names no owner); unchanged.
- Feed: does not apply. It is the community's stream; staff reading it should see what players see, and a banned or private player's pulls add nothing to moderation, which happens on the profile.
- Friend profile: does not apply. It is a friendship surface; a private player hides from friends, staff friends included. Staff read the public profile instead.

A single `outranked` code, not one per target rank: the rule is one comparison, and its copy reads the same for ban, unban and dismiss.

## Verification

Environment for every command: `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w7_13`, `CHROME_BIN=/usr/bin/chromium`.

**Commands:**
- `bin/ci` -- expected: green
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: clean
- `bin/rails test test/system/moderation_test.rb test/system/public_profile_test.rb test/system/share_card_test.rb test/system/shell_test.rb test/system/import_run_test.rb test/system/card_preview_test.rb test/system/settings_test.rb` -- expected: green

## Auto Run Result

Status: built.

**Summary:** staff act only on a lower rank: `Accounts::Player#outranks?` (player < moderator < administrator, `RANKS` the role enum's single source) backs one refusal, `outranked`, in `BanPlayer`, `UnbanPlayer` (now with a class-level `refusal`) and `DismissReports`, after the self codes and again under the target's row lock; the queue and the banned list show it instead of the buttons. `DismissReports` locks the target row like a ban, and `ReportQueue.rows` reads counts and latest time in one query (story 5's follow-up). Every back-office address, Mission Control's included, answers a visitor, a non-staff player and a member of staff since banned or deleted with the 404 of an unknown address, from `BackOffice::BaseController`'s prepended check, before the browser, forgery and rate-limit checks and Pundit; staff keep their 403s. `Game::Visibility.visible?` shows staff in good standing every owner but a deleted one (`staff_sees_all: true`); the public profile and the report endpoint use it, the feed and the friend profile opt out; the shared card page asks nothing. The banned list links each name to the profile; the profile's visibility lines name the officers.

**Files changed:**
- `app/controllers/back_office/base_controller.rb` (new), the seven back-office controllers, `config/initializers/mission_control.rb`, `app/policies/back_office/*` -- the hidden back-office; policy comments.
- `packs/accounts/app/models/accounts/player.rb`, `packs/accounts/app/operations/accounts/{ban_player,unban_player,dismiss_reports}.rb`, `packs/accounts/app/queries/accounts/report_queue.rb` -- the rank rule, the dismissal's lock, the one-query rows.
- `packs/game/app/models/game/visibility.rb`, `packs/game/app/queries/game/feed_entries.rb`, `app/controllers/{public_profiles,friend_profiles,reports}_controller.rb` -- staff read every profile; per-surface choice.
- `app/views/back_office/bans/index.html.erb`, `config/locales/{fr,en}.yml`, `README.md` -- refusal and profile link in the banned list, copy, runbook.
- Tests: `test/controllers/back_office/hidden_test.rb` (every back-office and engine route, six verbs, visitor and player, body equal to an unknown address, before rate limit, forgery and browser checks, banned/deleted staff, staff 403 kept), `test/packs/accounts/moderation_rank_concurrency_test.rb`, operation, queue, visibility, feed, profile, report and back-office tests updated, `test/support/{hidden_back_office,lock_races}.rb`, `test/system/moderation_test.rb` (a moderator opens a banned profile, a visitor finds it unavailable), toast tests moved off the back-office.
- `_bmad-output/initiative-gameble/deferred-work.md`, `pending-approvals.md` -- story 5's hidden-profile entry resolved, a staff-marker follow-up, the choices to confirm.

**Review findings:** thorough review (four lenses), 25 findings. Patched: 1 medium (the owner's visibility copy claimed no one else sees a private or friends-only profile) and 6 low entries (`package-lock.json` name, player read before the role switch, `RANKS` drift, the queue's intro, the profile controller's comment, HEAD in the hidden test and a stray blank line). Deferred: planning ids left in lines this story did not write. Rejected: no staff marker on a hidden profile (deferred-work entry), staff reports on a banned player, the unlocked actor, the default of `staff_sees_all`, staff reporting as a write, header comparison in the 404 tests, and five false findings — each with its reason in the triage log.

**Follow-up review recommended:** false -- one medium entry patched (high 0, medium 1, low 6), a copy change.

**Verification:** `bin/ci` (setup, rubocop, packwerk, i18n-tasks missing, typecheck, bundler-audit, brakeman, migration safety, 1797 Rails tests, seeds): green; `npm run test:js` (168): green; `bin/rails zeitwerk:check`: all good; `bundle exec packwerk check`: no offenses; system tests `moderation`, `public_profile`, `share_card`, `shell`, `import_run`, `card_preview`, `settings`, `friends`: 43 runs, 0 failures. No migration. `bin/setup` rewrote `package-lock.json`'s name; reverted.

**Residual risks:** a staff member demoted or banned while a ban, unban or dismissal is in flight still completes it (the actor is not re-read); a staff report on a banned player waits out of the queue until an unban; staff see a hidden profile with no sign that players do not; the back-office reads the player before the forgery check, so a non-staff POST never reaches CSRF verification (by design, it answers 404).
