---
title: 'A release grants new achievements from history before it takes traffic'
type: 'feature'
ticket: '4'
created: '2026-11-03'
status: 'built'
baseline_revision: '0f181fa47dcdbce6950e6aadc08413d33efbf527'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** A release that adds achievements must grant them from history before the new code serves a request, so no live grant announces history as new. The entrypoint already runs `./bin/rails db:prepare game:backfill_achievements` for the web server (commit 7eb0953aae6112472ed071823c25a892d526d06f, kept by 6b20e9709a9038db3442bb6ac3e43d3575d63b19), but nothing pins that order or that only the server boot runs it, and RELEASING.md does not say a deploy runs this data step, that it is silent and idempotent, or that it counts inside Kamal's wait for `/up`.

**Approach:** Keep `bin/docker-entrypoint` as it is unless its test shows a defect; add a test that runs the real entrypoint with stand-in `bin/rails` and command scripts in a temporary directory and checks that the server boot runs `db:prepare` then `game:backfill_achievements` in one Rails process before the server command, that the import worker's `bin/jobs` command runs neither, and that a failed prepare or backfill keeps the server from starting; add to RELEASING.md where the deploy runs the backfill, what it does and what the staging acceptance checks of it. Backfill idempotence, silence (retroactive, no toast) and per-player failure reporting are already covered by `Game::BackfillAchievementsJobTest` in `test/domains/game/achievements_test.rb`; do not duplicate them.

</intent-contract>

## Implementation Notes

Oneshot: the code change already exists on develop; what is left is a test of the entrypoint (about 50 lines) and a RELEASING.md paragraph, two files, well under 100 lines.

- Files: `test/config/docker_entrypoint_test.rb` (new), `RELEASING.md`.
- The Dockerfile's command is `./bin/thrust ./bin/rails server`, the import role's `bin/jobs -c config/queue_import.yml --skip-recurring` (`config/deploy.staging.yml`, `config/deploy.production.yml`); the entrypoint matches the last two arguments, so only the web container runs the data steps.
- Kamal 2.12's `deploy_timeout` is not set in `config/deploy.yml`; the backfill's boot time inside that window is the ticket's open question, measured by the author on staging, and is not settled here.

- Built: `bin/docker-entrypoint` needed no change; its test passed against it at the first run. The test reads the web command from the Dockerfile's `CMD` and the import command from both destination files, so a change to either is checked too.
- RELEASING.md: a paragraph after step 1's staging run (the boot runs `db:prepare` then the backfill, silent and idempotent, inside Kamal's `deploy_timeout`, web container only) and an acceptance checklist line for a release that adds achievements.

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The checklist's `bin/kamal app logs -d staging` prints only the last 100 lines per container (kamal 2.12 `cli/app.rb:231`), so after the walk the boot's `done` line is gone — patched: the command now greps, `bin/kamal app logs -d staging -g game:backfill_achievements`, which lifts the line limit.
  - `[low]` `[patch]` The checklist line left out the ticket's "a second boot grants nothing more" — patched: the line asks for a second boot with `bin/kamal app boot -d staging` that grants nothing more.
  - `[low]` `[patch]` The boot time is noted without the limit it counts against; `deploy_timeout` is unset, so Kamal 2.12 waits 30 seconds (`configuration.rb:237`) — patched: the paragraph names `deploy_timeout`, its 30-second default and that running past it fails the deploy; the measured time stays the author's open question.
  - `[low]` `[patch]` "the others are still served" reads as serving requests while the backfill only goes on granting — patched to "the others still get their grants".

## Verification

**Commands:**
- `bin/rails test test/config/docker_entrypoint_test.rb test/domains/game/achievements_test.rb` -- expected: all pass
- `bin/rubocop test/config/docker_entrypoint_test.rb`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check` -- expected: clean

**Manual checks (author, staging, hitl):**
- Deploy a candidate holding Statistical Non-Compliance to staging: a player whose recorded packs hold two Rare-or-better cards in one standard capsule holds it before the first request, with no toast; a second boot grants nothing more; record the boot time the backfill added.

## Auto Run Result

Status: built

**Summary:** The entrypoint already ran `bin/rails db:prepare game:backfill_achievements` before the web server (commit 7eb0953aae6112472ed071823c25a892d526d06f, kept by 6b20e9709a9038db3442bb6ac3e43d3575d63b19); this build pins that boot with a test and documents it in RELEASING.md. The test runs the real `bin/docker-entrypoint` with stand-in `bin/rails`, `bin/thrust` and `bin/jobs` scripts: the Dockerfile's web command runs one Rails process for `db:prepare game:backfill_achievements` before the server; a failed Rails step keeps the server from starting; the import worker's command (staging and production) runs neither. RELEASING.md says where the deploy runs the backfill, that it grants from history silently and idempotently, that per-player failures go to Sentry, that it counts inside Kamal's `deploy_timeout` (30 seconds by default, unset here), and adds a staging acceptance line for a release that adds achievements.

**Files changed:**
- `test/config/docker_entrypoint_test.rb` -- new: the boot order, the failure stop and the import worker's boot
- `RELEASING.md` -- the boot's data steps after step 1, and an acceptance checklist line

**Review findings:** quick lens, 4 findings. Patches applied: 4 (medium 1: the log command now greps past Kamal's 100-line default; low 3: the second-boot check, the 30-second `deploy_timeout`, the "served" wording). Deferred: none. Rejected: none. Follow-up review recommended: false (patched: high 0, medium 1, low 3).

**Verification:** `bin/rails test test/config/docker_entrypoint_test.rb test/domains/game/achievements_test.rb` 76 runs, 0 failures (before and after the patches); `bin/rubocop` on the new test, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check` clean. No frontend, locale or system-test surface changed.

**Left for the author (hitl):** the staging check of the ticket: deploy a candidate holding Statistical Non-Compliance, see it granted from history before the first request with no toast, boot a second time and see nothing more granted, and record the boot time the backfill added. The ticket's open question stays open: whether that boot time stays inside Kamal's health-check window (30 seconds by default) as players grow; if not, the step moves to RELEASING.md.

**Residual risks:** the backfill walks every player in good standing on every web boot, so boot time grows with the player count until the open question is settled.
