---
epic: epic-public-launch-readiness
date: 2026-10-21
verdict: accepted-with-open-items
criteria: declared
headless: false
---

# Retrospective: Ready for the public (epic 7, release 0.2.0)

Run on 2026-10-21 in interactive mode. The author gave two answers up front: no going-in concern to weigh, and no team discussion (Phase 3 skipped). Phases 1, 2 and 4 were run; this file is the only thing written. No ticket status, plan, story or epic file was changed, and no git command that writes was run.

## Epic summary

**Epic.** `epic-public-launch-readiness` (id 7, release 0.2.0), covering CAP-14 and CAP-15, requirements R1 to R7, eight Done-when criteria (declared in `epic-public-launch-readiness.md:36-45`).

**Tickets.** `tickets.py status` returns 57 tickets: 55 `done`, 2 `dropped` (7.1 the CI production image, dropped 2026-10-08 in favour of the Kamal deploy to staging, `epic-public-launch-readiness.md:70`; 7.15 error tracking in the EU, dropped because Sentry was already in the EU). `pending_tickets` is empty: no ticket is unfinished, so the machine rule that forces `rejected` does not apply.

| Group | Refs |
|---|---|
| Account data | 7.2 visibility, 7.7 export, 7.8 deletion, 7.20 private profile closes its social side, 7.21 trade from the friend row, 7.42 remove a friend, 7.48 deletion dialog, 7.51 legal page lists the erasure |
| Moderation | 7.4 reports, 7.5 queue/bans/unbans, 7.17 rank, hidden back-office, staff read every profile, 7.18 players list, 7.19 moderation history |
| Legal and privacy | 7.3 legal page, 7.14 retention, 7.22 legal page says what the app does, 7.23 no IP in the event store, 7.24 publisher named, 7.59 credits |
| Bank | 7.6 healing at publication, 7.9 races between bank operations, 7.31 bank refresh |
| Production readiness | 7.10 CSP enforced, 7.11 backups and restore drill, 7.13 CI image job removed, 7.25 real client address, 7.26 language redirect never cached, 7.53 Sentry environments, 7.54 error pages, 7.55 public pages throttled, 7.57 production LXC, 7.58 release candidate is the release |
| Tests and tooling | 7.34 contract migrations, 7.35 schema round trip, 7.36 request-test helpers, 7.37 clock-change tests, 7.38 flaky live-update tests, 7.39 system tests rebuilt, 7.41 private notes leave the agent instructions, 7.43 drift step |
| Polish | 7.27, 7.28, 7.29, 7.30, 7.32, 7.33, 7.40, 7.44, 7.45, 7.46, 7.47, 7.49, 7.50, 7.52 |
| Sweep | 7.12 refactor sweep |

**Tickets still at `built`.** 7.12 (Refactor sweep): `story-refactor-sweep-plan.md:6` says `status: built`; the board row says `done` (commit 354f3855, "7.38, 6.12 and 7.12 done"). The plan was written 2026-10-21 by the session that did the sweep, so the plan and its author are the same hand. Its baseline is `7f8baff5` and its only commit is 79664fab. Also unaligned: the plan of 7.59 still says `status: 'draft'` (`story-a-credits-section-names-gameble-s-inspirations-plan.md`) while its board state is `done`.

**Plan ranges.** Plans were ordered by the place of their baselines in history; each range runs to the next baseline, the last one to the sweep's own commit (inferred end, 79664fab; 354f3855 follows it and only changes tickets). Tickets sharing a baseline are one range. `git_evidence.py` ran once per distinct range (39 runs).

| Refs | Range | Commits (merges) |
|---|---|---|
| 7.2 | fa1676d0..47cea18b | 12 (4) |
| 7.4 | 47cea18b..e419296b | 214 (14), baseline not an ancestor of the next one; spans history before the epic |
| 7.1, 7.6, 7.8 | e419296b..58ab6e4e | 60 (26) |
| 7.5 | 58ab6e4e..d08a06c8 | 2 |
| 7.17 | d08a06c8..fb919801 | 3, baseline not an ancestor of the next one |
| 7.3 | fb919801..82e9a602 | 8, baseline not an ancestor of the next one |
| 7.19 | 82e9a602..a3230dcd | 3 |
| 7.20 | a3230dcd..5df87f99 | 71 (16), baseline not an ancestor of the next one |
| 7.13 | 5df87f99..bb7d8819 | 6 (2) |
| 7.9 | bb7d8819..1cf0684a | 55 (5) |
| 7.22, 7.23 | 1cf0684a..5ba943c8 | 4 |
| 7.24 | 5ba943c8..be6fe2e1 | 2 |
| 7.14 | be6fe2e1..224cc393 | 37 |
| 7.21 | 224cc393..1f4d44e8 | 50 (5) |
| 7.28, 7.35 | 1f4d44e8..500c21f9 | 2 |
| 7.29 | 500c21f9..47f2a2ed | 3 |
| 7.31 | 47f2a2ed..d24977f2 | 3 |
| 7.36 | d24977f2..4ab26584 | 2 |
| 7.42, 7.43 | 4ab26584..8da410f4 | 7 |
| 7.46 | 8da410f4..9dd2e8bc | 4 |
| 7.44 | 9dd2e8bc..0eca4691 | 4 |
| 7.47 | 0eca4691..29eea28a | 4 |
| 7.45 | 29eea28a..d4bb544d | 6 |
| 7.48, 7.49 | d4bb544d..a2d72926 | 8 |
| 7.7 | a2d72926..b40b779b | 10 |
| 7.10 | b40b779b..236faa02 | 5 |
| 7.25 | 236faa02..b121dfef | 1 |
| 7.52 | b121dfef..e5fd391d | 1 |
| 7.53 | e5fd391d..d6fe23cb | 2 |
| 7.55 | d6fe23cb..8c4b180b | 1 |
| 7.34 | 8c4b180b..47391d33 | 1 |
| 7.50 | 47391d33..2d934a62 | 1 |
| 7.32 | 2d934a62..5716e673 | 2 |
| 7.33 | 5716e673..68da4820 | 5 |
| 7.40 | 68da4820..4582ccb6 | 35 |
| 7.58 | 4582ccb6..bac8e2da | 27 |
| 7.54 | bac8e2da..14d30ca6 | 14 |
| 7.11 | 14d30ca6..7f8baff5 | 173; also holds the work of 7.38, 7.39, 7.41, 7.51, 7.57, 7.59, which have no plan baseline, and much of other epics |
| 7.12 | 7f8baff5..79664fab | 1 |

**Tickets with no range.**
- Baseline commit missing from the repository: 7.18 (398610cd), 7.26 (769b063f), 7.27 (15e23568), 7.30 (4b1584fd).
- Plan without a baseline: 7.15 (dropped), 7.37, 7.59.
- No plan, only a story file: 7.38, 7.39, 7.41, 7.51, 7.57.
- Their evidence below comes from commits named in the tickets and the author's instructions: 7.38/7.39 are 922cc161..2b6619b5 (922cc161, 7e7e8111, 1f235c80, a4cca1da, 09693b0b, ad0c5f89, a2cd41bd, 2b6619b5), 00042890/1885e9a6, fb8c4010 and e1cf6b75 (all 2026-10-21); 7.41 was already satisfied by d8dc415e (2026-10-14), closed by 08b9697d.

**Evidence inventory.**
- Available: the epic file; 57 ticket rows (`status`, `find`); 52 plans (frontmatter, Review Triage Logs, Plan Change Logs, Verification); 7 story files; `deferred-work.md`; `pending-approvals.md`; `git_evidence.py` output for 39 ranges; the repository at HEAD 38ab84c3; `gh run list` and `gh run view` (read only); the previous retrospective.
- Missing: session logs. Process-lesson analysis is from plans only. No dependency graph was taken before and after (architecture delta narrowed to `packwerk check` at HEAD).
- Range quality: 848 distinct commits across the ranges, of which 27 are not reachable from HEAD (side-branch history) and 21 subjects appear twice under different hashes (for example "story 7.6", "story 7.1", "story 7.2", "story 7.4" each appear twice, in ranges 0 to 2). The ranges of the early tickets and of 7.11 mix in other epics, so file churn per range cannot be attributed to this epic alone. For the size view below, the commit set was narrowed by subject (236 matches, 227 reachable from HEAD, tickets/docs commits excluded) and read as an approximation.

## Findings

Each finding: severity (high, medium, low), source, disposition (fix now, defer, accept). Dispositions that name an action item point to the Action items section.

### Aggregate views

**AV1. Architecture delta (narrowed).** `bundle exec packwerk check` at HEAD: "No offenses detected, No stale violations detected" (1,035 files inspected, run for this retro). No before/after graph diff was taken, so a new cross-pack dependency that packwerk accepts as declared would not show here. Disposition: accept as checked-and-clean for forbidden dependencies, never checked for graph shape.

**AV2. Size growth.** No production file owned by this epic is large: `app/controllers/application_controller.rb` 172 lines, `app/models/player_export.rb` 114, `packs/accounts/app/models/accounts/player.rb` 99, `packs/game/app/models/game/visibility.rb` 16, `app/controllers/back_office/*.rb` 508 lines in 13 files. The growth sits in text and tests: `config/locales/en.yml` 1,922 and `fr.yml` 1,971 lines (59 and 60 of the approximated commits touch them), `test/controllers/pages_controller_test.rb` 958 lines (20 commits), `test/controllers/public_profiles_controller_test.rb` 750 lines (14 commits), `README.md` 277 lines. Locale and test growth is expected for a legal and data epic. Disposition: accept; the churn ranking is contaminated by other epics (Booster.tsx and booster.css top it and belong to the opening, not to this epic).

**AV3. Duplication: the `hold` test helper keeps growing.** `grep -rn "def hold" test` finds 39 definitions in 34 files at HEAD. The deferred entry written by ticket 7.36 on 2026-10-13 said "about 20 test files" (`deferred-work.md:155`, entry of 2026-10-13); the sweep says "about 34" (`story-refactor-sweep-plan.md:33`). Ticket 7.36 shared only the sign-in helpers. A copy-paste finding with no owner grew by about 14 files in the span of the epic. Severity low. Disposition: defer (already registered); process lesson in AI-8.

**AV4. Pattern divergence: planning ids still in code.** AGENTS.md forbids planning ids in code. At HEAD, my pattern (`AD-n`, `CAP-n`, `story n.n`, `epic n`, `DESIGN.md`, `EXPERIENCE.md`) over `app packs config test script lib bin db/migrate .github README.md RELEASING.md` gives 449 matches (313 of them `AD-`/`CAP-`; the `epic n` and file-name matches include some false positives). In this epic's own code: `packs/accounts/app/operations/accounts/delete_player.rb:2` ("CAP-14, AD-14") and `:15` ("AD-10's"), `update_settings.rb:6`, and the Pundit policies (`app/policies/account_policy.rb:1`, `settings_policy.rb:1`, `report_policy.rb:1`). The sweep (79664fab) fixed five files and left the rest to the "repo-wide cleanup entry" (`story-refactor-sweep-plan.md:31`). The recurrence cost: the Review Triage Logs of 7.17, 7.28, 7.36 and 7.45 each defer "pre-existing ids" for a sweep. Epic 12 owns the cleanup and plans a CI step (`epic-human-readable-codebase.md:30,41`). Disposition: defer to epic 12 (AI-9).

**AV5. Spec-to-implementation reconciliation.**

- **SR1, Done when 4 (backup restored).** Evidence is thin; see the Acceptance verdict. The plan of 7.11 records that the implementer ran the drill end to end with `v0.0.14-beta` (passed, `/up` 200, 6 players), and that the author signed off on 2026-10-16 "before the restore drill against the real repository, which waits for the first import; run `script/backup/restore_drill` then" (`story-backups-and-a-restore-drill-plan.md:89,91`). No later record of that drill exists: no commit, no `pending-approvals.md` entry (the 2026-10-20 settled block lists the production setup and log retention but not the drill), and `README.md:225-228` only documents it. Severity high for the criterion, low for risk (the script exists and ran once). Disposition: fix now (AI-1).
- **SR2, ticket 7.39 closed on a different promise than its Verify.** 7.39 asks for "ten full runs in a row locally and five CI runs in a row with no failure", "the CI system-test job runs again" and a rule in AGENTS.md (`story-system-tests-rebuilt-to-be-stable.md`, Verify). What was built: the suite runs once, before a release reaches production (`e1cf6b75`, `.github/workflows/system-tests.yml:3-8`, `deploy-production.yml:35-37`); AGENTS.md asks again for targeted system tests (`AGENTS.md:37`); the commit messages record "twice in eleven full runs", "once in ten full runs" (a2cd41bd, fb8c4010, 1885e9a6), so about ten full local runs happened, but no record shows ten consecutive green runs. `gh run list --workflow=system-tests.yml` shows one run, a `workflow_dispatch` on develop on 2026-10-21 (success, 4m21s). The author accepted this by closing the ticket on 2026-10-21 (354f3855), but the story's Verify text was not reconciled. Ticket 7.38's Verify ("20 consecutive parallel runs or five CI runs, and breaking the live update still makes the test fail") has no recorded run count or mutation check either; its cause (922cc161) is explained in the commit message. Disposition: accept as a deviation, reconcile the story text (AI-2).
- **SR3, coverage removed by the rebuild (accept).** The rebuild removed tests rather than stabilizing them: the pixel-for-pixel card face tests with their five PNG baselines (ad0c5f89, 189 lines gone), the desktop filtered-collection walk (a2cd41bd), three timing-bound booster, shell and trades tests (fb8c4010, 125 lines), the 300-card theme art test (1885e9a6; its message states "the lazy drawing of the art is no longer covered"), two hub tests whose subject was the sign-in panel and the CORS fallback test (7e7e8111, 1f235c80). Each removal is justified in its commit message, and the AGENTS.md rule now says a random failure is fixed or removed (`AGENTS.md:37`). Disposition: accept; the uncovered behaviors are the lazy art drawing and the phone tray thumbnails (`deferred-work.md:213`).
- **SR4, sweep plan 7.12 states things the repository contradicts.** `story-refactor-sweep-plan.md:34` says "left open on purpose: the account-deletion paragraph of the legal page against what deletion now erases". The legal paragraph lists achievements, showcase, set tiers, goal rewards, friendships, invitations and friend code (`config/locales/en.yml:235`), matching `Game::ReleasePlayer` (`packs/game/app/operations/game/release_player.rb`), and ticket 7.51 closed that on 2026-10-21 with the author's approval (a625d87a, d6ecbd53). The same line says the ban reason is "missing from the data export"; the export carries it (`app/models/player_export.rb:43`, `packs/accounts/app/queries/accounts/export_of.rb:17-18`, test `test/models/player_export_test.rb:130`, plan 7.7 Plan Change Log of 2026-10-14). `story-refactor-sweep-plan.md:36` says the `LEGAL_*` variables must be set before launch; they are set in `config/deploy.production.yml:51-54`. Severity low (the plan is not read by the app), but the next reader will re-open settled questions. The sweep also did not touch `deferred-work.md` (79664fab changes 7 files, none of them it), so two entries the sweep calls resolved still read open: the backfill bank lock (`deferred-work.md:107`, fixed by d7341c3e and 15fda010, GitHub #38) and the stale card-face baselines (`deferred-work.md:198`, deleted by ad0c5f89). Disposition: fix now (AI-3).
- **SR5, banned players and erasure on request.** The privacy notice tells a suspended player to "write to the contact ... to have your account erased" (`config/locales/en.yml:243`). `Accounts::DeletePlayer` refuses a banned player (`packs/accounts/app/operations/accounts/delete_player.rb:43`, `!player.banned?`), the 3-year inactivity deletion exempts banned accounts (`README.md:116`), and the README documents no console path or runbook entry to erase a banned account (grep of README.md and RELEASING.md for erase/DeletePlayer finds only line 116). The only route is to lift the ban (which writes a moderation-history row) and delete, undocumented. Severity medium: a legal promise without a mechanism. Disposition: fix now (AI-4).
- **SR6, ticket wording versus build (accept).** Criterion 5 says the legal page is reached from "Mentions légales" in the profile; the link sits on the settings screen (`app/views/settings/show.html.erb:111`, asserted in `test/controllers/settings_controller_test.rb:57`), in the shell version line (`app/views/shell/_version.html.erb:5`), the public card footer and the landing footer. The author reviewed those screens; accept.

### Diff-scope review, by boundary

`bmad-review` was not invoked: the epic diff is 800+ commits mixed with other epics, which exceeds a narrow pass. The adversarial, edge-case and verification-gap lenses were run inline on four boundaries, reading the code at HEAD and the plans' Review Triage Logs. The narrowing is: no line-by-line read of the epic's full diff; boundaries only.

**B1. Ban, sign-in, profile visibility (checked, clean, one gap in SR5).**
- Sign-in refuses a banned player after the row is locked: `packs/accounts/app/operations/accounts/sign_in.rb:43-45`.
- A live session of a banned or deleted player is dropped: `app/controllers/application_controller.rb:86`.
- `Game::Visibility.visible?` returns false for a deleted owner, true for acting staff (never a removed one: `player.rb:62-63`), false for a banned owner before looking at friendship (`packs/game/app/models/game/visibility.rb:4-9`), so a banned friends-only profile is hidden from friends.
- The back-office answers 404 to non-staff, banned staff included, before any other callback (`app/controllers/back_office/base_controller.rb:10-17`).
- Verified by the test run (see Behavior verification). Ban set from the console publishes nothing, so trades and friendships stay until `game:drop_friends_and_trades` runs (`README.md:110`); the author accepted this and ran the task on staging and production (`pending-approvals.md`, settled 2026-10-20). Disposition: accept.

**B2. Deletion, export, moderation history (checked, one open question).**
- Deletion removes the stored export (`delete_player.rb` deletes `DataExport` rows and clears `last_exported_at`), releases Game rows under the bank lock (`release_player.rb`), and the export includes the player's own moderation decisions with reasons (`player_export.rb:43`).
- Moderation history rows outlive a deleted account for a year, reasons included (`README.md:118`, `config/locales/en.yml:229`); the free text of a staff-typed reason (500 characters) is kept after deletion. The sweep lists this as a product call for the author (`story-refactor-sweep-plan.md:34`); the notice states it, so it is disclosed.
- Open question: the export filters `ModerationAction.where(player_id: ...)` only (`export_of.rb:17`), so a staff member's own actions as the actor are in no export; whether they count as the staff member's personal data is a legal call (see Open questions).
- Review log gaps: 7.8's deferred friends/trades/invitations case was closed by story 5.11 (98333541) and tests (`deleted_player_partner_test.rb`, `delete_player_concurrency_test.rb`) pass.

**B3. Throttling and CSP versus the shell (checked, three low findings).**
- The CSP is enforced in every environment, no report-only mode remains (`config/initializers/content_security_policy.rb:1-2`; `grep report_only config` finds nothing); no `style` attribute or `<style>` element in server HTML except the mailer layout (`grep` of `app/views`), and `test/integration/content_security_policy_test.rb` passes.
- Low: the public-read throttle covers `cards brothers library landing feed` (`config/initializers/rack_attack.rb:26`); the public `legal`, `credits` and `how-it-works` pages are neither throttled nor cached. They are cheap static renders and the criterion's text ("public pages") does not name them. Disposition: accept; reopen if abuse shows.
- Low: a throttled non-frame request gets a plain-text 429 (`rack_attack.rb:61`), not one of the themed pages that ticket 7.54 added (`public/` holds 400, 404, 406, 422, 500 only). Disposition: defer (AI-10).
- Low (verification): the CSP report URI is wired only when `SENTRY_DSN` is set (`content_security_policy.rb:42`), so "enforced after a run on staging with no violation" depends on the staging DSN; the only record is the author's commit subject 236faa02 ("the CSP enforced on staging with no violation, done") with no report count. Declaration, not evidence.
- Checked clean: `public/errors.css` is cached for a year but linked with a content hash (`public/404.fr.html:8`, `?v=00dcb157`), which settles the concern rejected in plan 7.10's triage.

**B4. System tests versus the CI and deploy workflows (checked, three findings).**
- `ci.yml` has no system-test job and no image build (only a `postgres:18` service), so "CI builds no image" holds and the old CI system job is gone.
- `deploy-production.yml:35-41` runs `system-tests` first, `release-image` needs it, `deploy` needs `release-image`; a rollback (`workflow_dispatch`) skips the suite and still reaches `rollback` through separate jobs.
- Medium (verification gap): the called path has never run on a real release. The only system-tests run on record is the manual dispatch (39612835070). The first production release after e1cf6b75 is the first test of the gate. Disposition: defer (AI-2).
- Low (ordering): the suite runs before the release checks (tag format, main's head, staging status at `deploy-production.yml:60-80`). A release published with a non-release tag now spends a 4m21s suite before failing a check that takes 7 seconds; the run 39110108636 (v0.1.2-rc.1, published as a release) failed exactly that check. Disposition: accept or move the checks first (AI-2).
- Low (supporting text): `system-tests.yml` runs `db:test:prepare test:system` without `RAILS_MASTER_KEY`, as the old job did; the one successful run shows it is not needed.

### Process lessons (from plans only)

**P1. Three plans ended with `followup_review_recommended: true` and no follow-up review exists.** 7.3 (legal page, `followup_review_recommended` line 14), 7.5 (moderation, line 14; the unreviewed risk is "the self-dismiss refusal ... checked only by their own tests", plan lines 178), 7.14 (retention, line 14; a high was patched by moving idleness to `GREATEST(last_seen_at, updated_at)` and writing `last_seen_at` in `SignIn`, plan line 226). None carries a second dated block (`review_loop_iteration: 0`). The tests I ran for those paths pass (`delete_inactive_player_test`, `dismiss_reports_test`, `sign_in_test`), so no defect is shown, but the high-severity patch was never re-reviewed. Disposition: defer (AI-5).

**P2. Builds are not in the shared history (fifth time carried).** Four baselines are not in the repository (7.18, 7.26, 7.27, 7.30), four more are not ancestors of the next baseline (7.4, 7.17, 7.3, 7.20), 27 commits in the ranges are unreachable from HEAD, and none of the 52 plans has `built_revision`. The previous retrospective carried this as action item 11 (`epic-space-terminal-screens-retrospective.md`, item 11). Effect here: no commit-level attribution for 11 tickets. Disposition: fix now as a process change (AI-6).

**P3. Production facts were closed on the author's word with no recorded observation.** 7.11 was marked done with the drill still owed (SR1); 7.10's staging run is a commit subject (B3); the epic closing on "the author accepted v0.2.0-rc.1 on staging" (354f3855) names no observation. For `hitl` tickets (the ticket rows flag 7.3, 7.7, 7.10, 7.11, 7.15, 7.41, 7.51, 7.53, 7.54, 7.57, 7.58, 7.59 as `hitl: true`) the sign-off line in the plan should say what was seen. Disposition: process change (AI-7).

**P4. Review depth varied and some tickets have no record.** Thorough (four-lens) review on 7.5, 7.14, 7.17, 7.20, 7.42; quick on the rest; none on 7.12 (`review: 'none'`), empty on 7.59, and no plan at all for 7.38, 7.39, 7.41, 7.51, 7.57. The previous retrospective asked for a review on every ticket (item 10). The plan of 7.12 lists three verification commands with "expected" outcomes and no results, and no Auto Run Result (`story-refactor-sweep-plan.md:38-43`), although the story's Verify asks for the full suite, lint, packwerk and typecheck. Disposition: fix now for 7.12 (AI-3), process change (AI-6).

**P5. Triage worked where it ran.** The plans' Review Triage Logs show real catches: the deletion deadlock found by the concurrency test (7.8 Implementation Notes), the idle-deletion high (7.14), the media-query listener and stale bank (7.31 review loop 1), the dropped one-at-a-time refusal on the friend row (7.21, `intent_gap`). Confirmed strength; no action.

### Confirmed strengths (checked)

- Race and concurrency coverage for deletion, ban and bank operations: `test/packs/game/bank_races_test.rb`, `bank_lock_order_races_test.rb`, `delete_player_concurrency_test.rb`, `test/packs/accounts/ban_player_concurrency_test.rb`, `moderation_rank_concurrency_test.rb` all pass.
- The epic file records each decision with a date and an author (`epic-public-launch-readiness.md:58-75`), which made the verdict checkable.
- Production flow is code, not memory: staging status required before release (`deploy-production.yml:60-80`), `gh run list` shows deploy-staging runs succeeding and production releases v0.1.0 and v0.1.1 deploying.

## Behavior verification

**Staging was walked through by the author, not by me.** The author accepted v0.2.0-rc.1 on staging (354f3855, "the author accepted v0.2.0-rc.1 on staging"), settled the 2026-10-19 and 2026-10-20 staging checks in `pending-approvals.md`, and set up and deployed production on 2026-10-20. I did not open staging or production, start a server, or run a system test (the checkout holds another session's uncommitted work, so only non-system suites ran).

**What ran, on the working tree at HEAD 38ab84c3 (two files of other sessions modified, not mine):**

- `bin/rails test` on these files, 8 parallel processes, seed 63366: `test/packs/accounts` (whole directory: sign-in, ban/unban, visibility, export, deletion, inactive deletion, reports, moderation history, retention purges), `test/packs/game/{bank_lock_order_races,bank_races,delete_player_concurrency,deleted_player_partner,drop_friends_and_trades,fill_bank,heal_banks_job,top_up_bank,visibility,remove_friend,open_trades_by_friend}_test.rb`, `test/controllers/{accounts,data_exports,settings,reports,public_profiles,sessions,pages,read_only_requests,authorization}_test.rb` and `test/controllers/back_office/`, `test/policies/{account,data_export,settings}_policy_test.rb` and `test/policies/back_office/`, `test/models/player_export_test.rb`, `test/jobs/apply_retention_job_test.rb`, `test/integration/` (CSP, rate limit, error pages, shell, event store, Steam OpenID, player stream), `test/script/gameble_backup_test.rb`. Result: 981 runs, 9,590 assertions, 0 failures, 0 errors, 0 skips.
- `npm run test:js`: 46 files, 504 tests passed.
- `bundle exec packwerk check`: no offenses, no stale violations.
- `gh run list` and `gh run view` (read only): CI, deploy-staging, deploy-production and system-tests runs, as cited in findings.

**What did not run:** the full `bin/rails test` suite, system tests (any), `bin/rails zeitwerk:check`, rubocop, `i18n-tasks`, `npm run typecheck`, `bin/ci`. The restore drill and the Kamal staging deploy were not run, and no Sentry data was seen. Passing tests do not stand in for the production facts listed under the Acceptance verdict.

## Previous-retro follow-through

Previous epic in the order of `tickets.py status`: `epic-space-terminal-screens` (id 10); its retrospective dated 2026-10-08 (`epic-space-terminal-screens/epic-space-terminal-screens-retrospective.md`) holds 13 action items. The epic file also names the retrospectives of epics 3 and 4 as the source of Done when 6; that criterion is followed up below. The epic-10 items were mostly executed after the retrospective as tickets of that epic (closed 2026-10-13, `epic-space-terminal-screens.md:62-64`); line by line:

1. Fix S6, collection opens on every slot, owned first (dev loop). **Landed:** bug 10.9 `done` (`tickets.py status` of that epic), epic file `:43,62`.
2. Reconcile the spec with S6 (author). **Landed in the epic file:** `epic-space-terminal-screens.md:43,62` amend R7 and Done when 6. EXPERIENCE.md:174 not checked: no evidence found.
3. Fix B2, previous/next follows the grid (dev loop). **Landed:** bug 10.8 `done`, epic file `:61`.
4. Fix S5, NON overrides the OS (dev loop). **Landed:** commit 23662bed, `app/controllers/application_controller.rb:29`, `app/frontend/lib/motion.ts:14`.
5. Fix B6, the `zero` form of `fr.public_profiles.set.copies` (dev loop). **No evidence found:** the key `public_profiles.set.copies` is not present in `config/locales/fr.yml`; it may have moved with the profile rework.
6. Record S1 as accepted (author). **Landed:** `epic-space-terminal-screens.md:64` records the NOUVEAU deviation as accepted.
7. One collection-cleanup ticket for A1, A2, B3, B4, B5 (dev loop). **No evidence found:** the epic file says the items without a home are in `deferred-work.md` (`:64`); no ticket was found.
8. Reconcile Done when 6 and R7 with 6362b0f, record S3 and S4 (author). **Landed:** `epic-space-terminal-screens.md:63-64`.
9. Close the epic (author). **Landed:** `epic-space-terminal-screens.md:64`, status `done` in `tickets.py status`.
10. Process: a review on every ticket, record each system-test run (orchestrator). **Not landed in this epic:** 7.12 has `review: 'none'`, 7.59 none, five tickets have no plan (P4).
11. Process: record `built_revision`, keep builds in shared history (author and orchestrator). **Not landed, and it recurred:** 0 of 52 plans have `built_revision`; 8 baselines unusable (P2).
12. Process: author remarks that become spec decisions are quoted verbatim and confirmed one by one (author). **No evidence found** either way in this epic's records.
13. Process: a plan names the earlier invariant a ticket must keep (author). **No evidence found:** none of the 52 plans has such a section; for example 7.20 (private profile) and 7.42 (remove a friend) touch invariants of 7.2 and 7.21 without naming them.

Done when 6, from the epic 3 retrospective (2026-10-03, decided 2026-10-07): delivered by 7.6 and 7.9 (`test/packs/game/top_up_bank_test.rb`, `heal_banks_job_test.rb`, `bank_races_test.rb` pass); the deferred AD-7 wording was amended by the author on 2026-10-08 (`pending-approvals.md`, settled 2026-10-08).

## Action items

All items are proposed. Nothing was applied. "Remediation" is for the dev loop; "spec reconciliation" is for the human to apply.

- **AI-1 (dropped by the author on 2026-10-21). Run the restore drill against the real backup repository and record the result.** `script/backup/restore_drill <release>` from the author's machine, then add one line to the 7.11 plan's Implementation Notes (snapshot id, release, `/up` status, player count) or to `pending-approvals.md`. Closes SR1 and the weakest Done-when criterion. Owner: author (hitl). *Proposed, the author's to execute.*
- **AI-2. Reconcile 7.39 and the system-test gate.** (a) Amend 7.39's Verify and description to what was built (suite once before a production release, targeted runs by agents), and record the deviation in the epic Notes; (b) after the first production release past e1cf6b75, record the gate's run (the first real one); (c) decide whether the release checks (`deploy-production.yml:60-80`) run before the suite. Owner: author, then dev loop for (c). *Proposed spec reconciliation and remediation.*
- **AI-3. Correct the sweep's record.** In the 7.12 plan's Implementation Notes: the legal deletion paragraph is settled by 7.51, the ban reason is in the export, the `LEGAL_*` variables are set; add the results of the verification commands (full suite, lint, packwerk, typecheck) so the plan can leave `built`. In `deferred-work.md`: add `resolved:` lines to the backfill lock entry (`:107`, d7341c3e and 15fda010) and the card-baseline entry (`:198`, ad0c5f89). Owner: dev loop (the plan's Intent block stays untouched). *Proposed remediation.*
- **AI-4. Give a banned account an erasure path.** Either document in README.md the console steps (unban, then `Accounts::DeletePlayer`, noting the history row) or allow the operation for a banned player when staff run it; the legal page (`config/locales/en.yml:243`) already promises the erasure. Owner: author decides (legal and product), dev loop implements. *Proposed remediation.*
- **AI-5. Review the three pieces no lens saw twice:** the self-dismiss refusal and `ReportQueue.rows` skip (7.5), the idleness rule `GREATEST(last_seen_at, updated_at)` and the synchronous `last_seen_at` write in `SignIn` (7.14), and the legal page copy (7.3, already author-read). One targeted pass, or the author accepts them as tested. Owner: dev loop. *Proposed remediation.*
- **AI-6. Process: make builds traceable.** The plan template records `built_revision` and a closing step refuses `done` when the baseline is not an ancestor of HEAD; a `done` plan needs a review block or an explicit `review: none` reason. Carried a fifth time (previous items 10 and 11). Owner: author and orchestrator (BMad configuration, `bmad-ticket`).
- **AI-7. Process: a `hitl` sign-off records the observation.** Template line for hitl tickets: what was seen, where, when (drill output, CSP report count on staging, release run id). Criteria 4 and 8 rest on declarations because of its absence. Owner: author (`bmad-ticket`).
- **AI-8. Process: a deferred copy-paste finding gets an owner or a guard.** The `hold` helper grew from about 20 to 34 files while registered (AV3). Either a ticket that shares it, or a lint/test that fails on a new `def hold` in a test file. Owner: author.
- **AI-9. Confirm epic 12 owns the planning-id cleanup.** 313 `AD-`/`CAP-` matches remain; epic 12's R2 and Done when 2 already cover them (`epic-human-readable-codebase.md:30,41`). No new work; confirm its CI step runs on the files this epic changed. Owner: author. *Accepted as deferred.*
- **AI-10. Optional: a themed 429 page and the three unthrottled public pages.** Give `rack_attack.rb:61` a themed body, and decide whether `legal`, `credits`, `how-it-works` join `PublicReadThrottle::PAGES`. Owner: dev loop, when abuse or a complaint shows. *Proposed remediation, low.*

Action-item count: 10.

## Acceptance verdict

**Accepted-with-open-items.** Criteria are **declared** (the epic file holds eight Done-when entries). No ticket is unfinished (`pending_tickets` empty; 7.12 is `built` in its plan and `done` on the board), so the machine rule for `rejected` does not apply. This is the machine verdict, rendered on the evidence; a human decision overrides it. The open items are AI-1 to AI-7.

Criterion by criterion:

| # | Done when | Status | Evidence, and what it rests on |
|---|---|---|---|
| 1 | Visibility, export, deletion from the profile, end to end | Met, evidenced | Plans 7.2, 7.7, 7.8, 7.20, 7.48; routes and controllers; `set_visibility_test`, `data_exports_controller_test`, `accounts_controller_test`, `delete_player_test`, `delete_player_concurrency_test`, `player_export_test` pass in my run |
| 2 | A report appears in the back-office; a ban blocks sign-in and hides the profile | Met, evidenced | `sign_in.rb:43-45`, `application_controller.rb:86`, `visibility.rb:6`; `reports_controller_test`, `back_office/reports_controller_test`, `bans_controller_test`, `ban_player_test` pass |
| 3 | Only staff reach the back-office | Met, evidenced | `back_office/base_controller.rb:10-17`; `back_office/hidden_test.rb` and the back-office policy tests pass |
| 4 | A database backup has been restored at least once | **Rests on the author's declaration and the implementer's self-report** | The plan records an end-to-end drill by the implementer on `v0.0.14-beta` (6 players) and the author's sign-off with the real-repository drill still owed (`story-backups-and-a-restore-drill-plan.md:89,91`); I could not see the drill, and no later record exists. Held open by AI-1 |
| 5 | Legal page with the notices; `card_details.notice` dropped | Met, evidenced for presence | `config/locales/{en,fr}.yml` legal keys (`fr.yml:176-188`, « Toutes les illustrations appartiennent aux éditeurs des jeux et à leurs artistes, que nous respectons. » at `:188`), route `config/routes.rb:121`, links (SR6), no `card_details.notice` key or use; `pages_controller_test` passes. The accuracy of the legal text is the author's; its approvals (7.3, 7.22, 7.51, 7.59) are declarations |
| 6 | Healing at publication, all packs at once; races tested | Met, evidenced | `top_up_bank_test`, `heal_banks_job_test`, `bank_races_test`, `bank_lock_order_races_test` pass |
| 7 | Image built and answering /up in the Kamal deploy to staging before production; CI builds no image | Met; the probe itself not seen | `ci.yml` has no image build; `deploy-production.yml:60-80` requires a staging success status; `gh run list` shows deploy-staging runs succeeding and production releases v0.1.0, v0.1.1 deploying. The `/up` health probe is Kamal's default (no healthcheck path in `config/deploy.yml`), and I did not read it in a log |
| 8 | Public pages throttled or cached; CSP enforced after a run on staging | Throttling and enforcement evidenced; **the staging run rests on declaration** | `rack_attack.rb:23-44`, `rate_limit_test` (passes); `content_security_policy.rb` has no report-only mode, `content_security_policy_test` passes; the staging run is the author's commit 236faa02 with no report count |

**Criteria resting on declaration rather than on evidence I saw:** 4 (backup restore), the staging-run half of 8 (CSP after a run on staging), and the `/up` probe inside 7. The production setup, its log retention, and the first production releases are the author's statements in `pending-approvals.md` (settled 2026-10-20) and the plans' "Done (author, ...)" lines.

**Open items:** AI-1 (drill), AI-2 (7.39 reconciliation and first real gate run), AI-3 (sweep record), AI-4 (banned erasure), AI-5 (follow-up reviews), AI-6 and AI-7 (process). If the author reads criterion 4 as requiring a restore of the real repository, the verdict is **rejected** until AI-1 lands; I rendered accepted-with-open-items because the criterion's literal text ("restored successfully at least once") is met by the implementer's recorded drill, and the author has signed it off.

**Human decision (2026-10-21):** the author accepts the implementer's end-to-end restore drill (`v0.0.14-beta`) as meeting Done when 4. The verdict stays accepted-with-open-items, and AI-1 (a drill against the real backup repository) is dropped.

## Open questions

1. Does Done when 4 mean any restore drill, or a restore of the real OVH repository? The answer decides between accepted-with-open-items and rejected.
2. Should a staff member's own moderation actions (as actor) appear in their data export (`export_of.rb:17` filters on the target only)?
3. Is the release-only system-test gate permanent, or does the author want them on every push again (7.39's original text)?
4. Should `legal`, `credits` and `how-it-works` count as public pages for the throttle?
5. How many `v0.1.x` releases ran without the system-test gate, and was any release published with a non-release tag (v0.1.2-rc.1 failed the tag check, run 39110108636)? Not resolvable from the repository.
6. Never checked: staging and production behavior, the Sentry CSP reports, the OVH repository's contents, dependency graph before and after, the line-by-line diff of the epic.
