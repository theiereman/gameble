---
title: 'Personal data kept only as long as the privacy notice says'
type: 'feature'
ticket: '14'
created: '2026-10-09'
status: 'built'
baseline_revision: 'be6fe2e1380f634944f88d199c71133fd82e0778'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: true
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred:
  - summary: >-
      The 30-day server log limit needs a one-time journald drop-in on the production host that nothing enforces.
    evidence: |-
      config/deploy.production.yml sends every container to journald; MaxRetentionSec=30day and MaxFileSec=1day are host settings (README, Retention). Until applied, journald keeps logs by size only.
    location: >-
      README.md (Production checks, Retention)
    severity: medium
  - summary: >-
      Staging keeps Docker's default json-file driver, rotated by size, so its logs have no age limit.
    evidence: |-
      Deliberate: staging deploys on every push to develop and journald on the home-lab LXC is unverified. The notice does not distinguish staging.
    location: >-
      config/deploy.staging.yml
    severity: medium
  - summary: >-
      The notice says Sentry keeps errors "90 days at most, depending on the plan"; the author's plan retention is unconfirmed.
    evidence: |-
      Settles once the author names the Sentry plan and its error retention; then state the exact period in privacy.retention.errors.
    location: >-
      config/locales/fr.yml privacy.retention.errors
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** The privacy notice states no retention period and nothing purges personal data: idle accounts, handled reports and the moderation history (ban reasons included) are kept forever, and the production server's Docker logs have no age limit.

**Approach:** A daily recurring job in `Accounts` runs three batched, idempotent operations: delete accounts idle for three years through `Accounts::DeletePlayer`, purge reports one year after handling, purge moderation history rows one year after their end. Production containers log to journald, whose 30-day retention the host sets (README). The legal page gets a `privacy.retention` list in both locales, and the texts that promised a never-erased history are corrected.

## Boundaries & Constraints

**Always:**
- Periods (author, 2026-10-09): idle account 3 years; handled report 1 year after `handled_at`; moderation history 1 year after its end; server logs 30 days; Sentry: its plan's retention (90 days at most, notice text only).
- Idle = `COALESCE(last_seen_at, created_at) < now - 3.years` (strict `<`). `last_seen_at` is written by `Accounts::NoteLastSeen` on any signed-in request (throttled to a minute); a sign-in is followed by such a request, so it counts. Only `role = player`, not banned, not deleted: staff accounts are exempt (made by hand from the console), banned accounts keep their Steam id while the ban lasts.
- Each idle account is deleted in its own transaction by `Accounts::DeleteInactivePlayer`, which locks the row `FOR NO KEY UPDATE`, re-checks idleness, role and standing on the locked row, then `step DeletePlayer.new.call(player:)` (same `PlayerDeleted` event, same Game release). A player seen meanwhile is refused `Failure(:player_active)`, never deleted.
- Report expiry: `handled_at < cutoff`, or the reported player was deleted before the cutoff (a report against a deleted account is never handled).
- Moderation row end: rows of a deleted player end at `deleted_at`; otherwise a `ban` row ends at the first `unban` row of that player after it (by `created_at, id`) and never ends while none follows (ban in force); `unban` and `dismissal` rows end when made.
- Moderation purge batches by player: one DELETE removes every expired row of up to N players, so a ban and the unban that ends it always go together (a lone unban deleted first would leave its ban row forever).
- Purges are housekeeping writes and publish no event (an event naming purged rows would keep the trace they remove). Operations take `now:`; the job passes its start time. Batches: inactive players 100, reports 1000, moderation players 500. The job logs the three counts; a failure for one player is reported (`Rails.error.report`) and the job goes on.
- The deleted player's event streams stay: every event carries ids only and no IP since the previous story, and the record they name is stripped of Steam id and name.

**Never:**
- No change to `Accounts::DeletePlayer`'s refusal of banned players, to `BanPlayer`/`UnbanPlayer`, or to staff-only rules.
- No migration; no planning ids in code or tests; never `i18n-tasks normalize`; never touch the `gameble_test` database or the main checkout.
- The notice never says "anonymis" (an existing test forbids it).
- No logging change for the staging destination (its deploy runs on every push to develop; journald there is unverified).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Idle player | role player, last seen 3 years + 1 s ago | deleted as by DeletePlayer: Steam id nil, PlayerDeleted published, game released | No error expected |
| Boundary | last seen 3 years − 1 s ago, or exactly 3 years ago | untouched | No error expected |
| Never seen | last_seen_at nil, created 3 years + 1 s ago / 3 years − 1 s ago | deleted / untouched | No error expected |
| Staff or banned idle | moderator, administrator, or banned player idle 4 years | untouched, Steam id kept | No error expected |
| Seen meanwhile | idle at selection, last_seen_at moved before the lock | untouched | `Failure(:player_active)`, job skips |
| Handled report | handled 1 year + 1 s / 1 year − 1 s ago | purged / kept | No error expected |
| Open report | unhandled, made 5 years ago against a player in good standing | kept | No error expected |
| Report against deleted account | unhandled, reported deleted 1 year + 1 s / − 1 s ago | purged / kept | No error expected |
| Ban in force | ban row 5 years old, no later unban | kept; `CurrentBanReason` still returns its reason | No error expected |
| Lifted ban | ban, unban 1 year + 1 s ago (player since banned again) | old ban and unban purged together, current ban kept | No error expected |
| Recent unban | ban 3 years ago, unban 1 year − 1 s ago | both kept | No error expected |
| Dismissal | dismissal row 1 year + 1 s / − 1 s ago | purged / kept | No error expected |
| Deleted account history | rows of a player deleted 1 year + 1 s / − 1 s ago | purged / kept, whatever the rows' age | No error expected |
| Run twice or late | job run again, or after missed days | second run purges nothing; a late run purges everything due | No error expected |

</intent-contract>

## Code Map

- `packs/accounts/app/operations/accounts/delete_player.rb` -- reuse as is; locks `FOR NO KEY UPDATE`, re-checks, publishes `PlayerDeleted` (Game::Handlers::PlayerDeleted releases the game, PlayerStream notifies partners after commit).
- `packs/accounts/app/models/accounts/player.rb` -- scopes `in_good_standing`, `removed`; roles enum; add the idle scope here.
- `packs/accounts/app/models/accounts/report.rb`, `moderation_action.rb` -- tables `accounts_reports` (`handled_at`, `reported_id`), `accounts_moderation_actions` (`kind`, `player_id`, `created_at`; index `player_id, created_at`).
- `packs/accounts/app/queries/accounts/current_ban_reason.rb` -- reads the latest ban/unban row: must keep working for a ban in force.
- `packs/accounts/app/operations/accounts/note_last_seen.rb`, `app/controllers/application_controller.rb#note_presence` -- what writes `last_seen_at`.
- `packs/game/app/jobs/game/expire_trades_job.rb` -- pattern for a recurring job: batches, per-item rescue with `Rails.error.report`.
- `config/recurring.yml` -- add the daily job to development and production; `test/config/queue_config_test.rb` reads it with YAML.
- `config/deploy.production.yml`, `config/deploy.yml` -- Kamal 2.12: root `logging:` (driver, options) applies to every role and accessory; kamal-proxy takes `proxy.run.log_max_size` (default "10m", passed as `--log-opt max-size`, which journald rejects: set it to `""`) and `proxy.run.options` (extra `docker run` options, e.g. `log-driver: journald`).
- `app/views/pages/legal.html.erb`, `config/locales/{fr,en}.yml` `pages.legal.privacy` -- the notice; `test/controllers/pages_controller_test.rb` (legal tests near line 560) checks sections and forbids "anonymis".
- `config/locales/{fr,en}.yml` `back_office.history.index.intro` -- says "Rien ne s'efface de l'historique" / "Nothing is erased from the history": now false.
- `README.md` line 95 ("Rows are never edited or deleted") and the "Production checks" section -- runbook text.

## Tasks & Acceptance

**Execution:**
- [x] `packs/accounts/app/models/accounts/player.rb` -- `IDLE_PERIOD = 3.years`; scope `idle(now)`: role player, in good standing, `COALESCE(last_seen_at, created_at) < now - IDLE_PERIOD`.
- [x] `packs/accounts/app/queries/accounts/idle_players.rb` -- the relation of idle players, for the job.
- [x] `packs/accounts/app/operations/accounts/delete_inactive_player.rb` -- `call(player:, now:)`; locks, re-checks with `Player.idle(now).exists?(id:)` after the lock, steps DeletePlayer; `Failure(:player_required | :player_active)`.
- [x] `packs/accounts/app/operations/accounts/purge_reports.rb` -- `call(now:, limit:)` → `Success(count)`; `RETENTION = 1.year`; one DELETE by id subquery with LIMIT.
- [x] `packs/accounts/app/operations/accounts/purge_moderation_history.rb` -- `call(now:, limit:)` → `Success(count)`; `RETENTION = 1.year`; picks up to `limit` player ids with an expired row, deletes all their expired rows in one statement.
- [x] `packs/accounts/app/jobs/accounts/apply_retention_job.rb` -- runs the three in batches until a batch is empty (idle players by id with `in_batches`), logs the counts, rescues and reports per player.
- [x] `config/recurring.yml` -- `apply_retention`: the job, queue default, `every day at 4am`, in development and production.
- [x] `config/locales/{fr,en}.yml` -- `errors.accounts.player_active` in both; `pages.legal.privacy.retention` (intro + items: account, reports, moderation, banned_steam_id, logs, errors, leftovers) per Design Notes; `privacy.deletion` ends "pendant les durées indiquées plus haut" / "for the periods given above"; `back_office.history.index.intro` drops "Nothing is erased" for "Each row is erased one year after its end, as the privacy notice says" (fr: "Chaque ligne s'efface un an après sa fin, comme le dit la notice de confidentialité").
- [x] `app/views/pages/legal.html.erb` -- after the services list and before `privacy.deletion`: `<p>` intro then `<ul class="legal__list legal__retention">` of the items.
- [x] `config/deploy.production.yml` -- `logging: driver: journald`; `proxy.run: { log_max_size: "", options: { log-driver: journald } }`, with a one-line comment that journald's retention is the host's (README).
- [x] `README.md` -- moderation bullet: rows are erased one year after their end; new "Retention" subsection under Production checks: the job, the periods, staff exemption, and the host step: `/etc/systemd/journald.conf.d/retention.conf` with `[Journal]` `MaxRetentionSec=30day`, `systemctl restart systemd-journald`, then `bin/kamal proxy reboot -d production` and a deploy; staging keeps Docker's default driver.
- [x] Tests -- `test/packs/accounts/delete_inactive_player_test.rb`, `purge_reports_test.rb`, `purge_moderation_history_test.rb`, `test/jobs/apply_retention_job_test.rb` covering every matrix row (use `travel_to`, `update_columns` for timestamps); `test/config/queue_config_test.rb` (job scheduled daily in production; production deploy logs to journald, proxy too, without max-size); `test/controllers/pages_controller_test.rb` (retention list in both locales: 7 items, mentions "trois ans", "30 jours", "un an").

**Acceptance Criteria:**
- Given the job runs, when it finishes, then the log line counts deleted accounts, purged reports and purged history rows, and nothing younger than its period is touched.
- Given a visitor opens `/fr/legal` and `/en/legal`, when they read the privacy section, then a retention list names every period (3 years, 1 year, 30 days, Sentry's at most 90 days, the banned Steam id while the ban lasts) and the deletion paragraph refers to it.
- Given the back-office history page, when staff read its intro, then it no longer claims nothing is erased.

## Implementation Notes

- The job skips `DeleteInactivePlayer::SEEN_MEANWHILE` (`Failure(:player_active)`) silently, as `ExpireTradesJob` skips `CLOSED_MEANWHILE`; any other failure is unwrapped and reported.
- Kamal applies root `logging:` to accessories too, so the database container moves to journald as well; the README's host step adds `bin/kamal accessory reboot db -d production`, since a running container keeps the log driver it started with. Checked with Kamal 2.12's configuration objects: app, import and db get `--log-driver journald`, the proxy gets it without `--log-opt max-size`.
- The job's schedule test lives in `test/config/queue_config_test.rb` with the journald test; the back-office history controller test now asserts the new intro.

- Review patches: the failure code became `:no_longer_idle` (`NO_LONGER_IDLE`); `Accounts::SignIn` writes `last_seen_at` with `update_columns` (keeps `updated_at`); `test/controllers/presence_test.rb` now expects no `NoteLastSeenJob` in the minute after a sign-in, since the sign-in noted the visit itself.

## Plan Change Log

### 2026-10-09 — review pass 1 (patch, no re-derivation)
- Trigger: a player unbanned after a ban of three years or more, or a moderator idle three years then demoted, was idle at once and deleted the next night (`NoteLastSeen` writes only for players in good standing).
- Amended: idleness is measured from `GREATEST(last_seen_at, updated_at)` instead of the intent contract's `COALESCE(last_seen_at, created_at)`; `updated_at` moves on every `update!` (unban, role change, settings, persona name) and is never older than `created_at`. The contract block is left as written; this entry supersedes its idle formula. It only keeps accounts longer, never deletes one the old formula kept.
- Also: `Accounts::SignIn` writes `last_seen_at` synchronously, so a sign-in just before the run is seen under the row lock; a ban lifted by hand (no unban row, player not banned) ends at `GREATEST(ban.created_at, player.updated_at)`.
- KEEP: per-player batching of the moderation purge; the row-lock re-check in `DeleteInactivePlayer`; no event from the purges.

## Review Triage Log

### 2026-10-09 — Review pass
- verdicts: 30 findings — high 1, medium 10, low 13, false 4, maybe-false 2
- findings:
  - `[low]` `[patch]` (verification-gap) a handled report erased lets the same reporter report again and requeue the player, undocumented — README Retention says so.
  - `[medium]` `[patch]` (verification-gap) a ban lifted by hand in the console has no unban row, so its row and reason were kept forever — new CASE branch: ends at `GREATEST(created_at, player.updated_at)` when the player is not banned; tested both sides of the year.
  - `[medium]` `[defer]` (intent-alignment) the 30-day log limit rests on a documented host step nothing enforces or checks — the repo cannot set journald retention; README gives the exact drop-in; author must apply it on the VPS.
  - `[medium]` `[patch]` (intent-alignment) `MaxRetentionSec` alone can leave entries ~60 days — `MaxFileSec=1day` added to the drop-in.
  - `[medium]` `[defer]` (intent-alignment) staging keeps Docker's size-rotated json-file logs, no age limit — deliberate (staging deploys on every push to develop; journald there unverified); author to decide.
  - `[low]` `[patch]` (intent-alignment) no test asserts a deleted idle player's invitations go — `delete_inactive_player_test` now creates a sent and a received invitation and asserts none remain.
  - `[low]` `[reject]` (intent-alignment) moderation boundaries tested on the operation, not through the job — the job only loops the operation; operation tests cover every boundary.
  - `[false]` `[reject]` (intent-alignment) dismissals and unbans of never-banned players erased after a year go beyond the intent — the intent says the history is purged "one year after"; a dismissal has no ban to be lifted, ending it when made is the decision recorded for the author, not a defect.
  - `[low]` `[reject]` (intent-alignment) unhandled reports against an account deleted over a year ago are erased, beyond "handled reports" — such a report can never be handled (the queue lists players in good standing only); kept as a stated decision.
  - `[high]` `[patch]` (blind) an unbanned player (or demoted idle moderator) is deleted the night after — idle now measured from `GREATEST(last_seen_at, updated_at)`; tests through `UnbanPlayer` and `SetRole`.
  - `[medium]` `[patch]` (blind) the event store keeps `PlayerBanned`/`PlayerUnbanned`/`ReportsDismissed` (ids, no reason) after the history rows go — the notice's moderation item now says the log of game actions keeps each decision's date and the accounts concerned, without the reason; events are never modified (architecture).
  - `[medium]` `[patch]` (blind) journald `MaxFileSec` — same root cause as the intent-alignment row; patched there.
  - `[medium]` `[defer]` (blind) staging logs have no age limit — same as the intent-alignment row.
  - `[low]` `[patch]` (blind) `:player_active` also returned for banned, deleted or promoted players — renamed `:no_longer_idle`, neutral message in both locales.
  - `[false]` `[reject]` (blind) purges publish no event, against the one-event rule — the architecture's event rule exempts housekeeping writes (last seen, the NOUVEAU watermark publish none); an event naming purged rows would keep their trace.
  - `[low]` `[reject]` (blind) a failing purge step stops the later ones and the log line — the job fails visibly in Mission Control and the next day's run catches up; isolating steps adds branches for an unobserved failure.
  - `[medium]` `[patch]` (blind) a 3-year-idle player signing in just before the run could be deleted because `last_seen_at` is written by a later job — `Accounts::SignIn` writes it under the row lock `DeleteInactivePlayer` also takes; tested.
  - `[low]` `[patch]` (blind) the notice exempts "a moderator's" account while the code exempts all staff — now "moderators and administrators" in both locales.
  - `[false]` `[reject]` (blind) a banned account's other data is kept indefinitely, unstated — the account item says "as long as the account exists"; a banned account exists.
  - `[low]` `[reject]` (blind) Cloudflare's retention is not given — outside this ticket's periods; the services list already names Cloudflare.
  - `[maybe-false]` `[defer]` (blind) "90 days at most, depending on the plan" is vague — settles when the author names the Sentry plan's retention (Developer 30 days, Team 90 days as far as known); notice text to adjust then (if-true medium).
  - `[false]` `[reject]` (blind) header comments break the comment policy — every operation and query in the pack carries such a header (DeletePlayer, BanPlayer, ReportQueue); `IdlePlayers` exists because jobs read through queries.
  - `[low]` `[reject]` (blind) daily purges scan whole tables (no index on `handled_at`, expression on players) — tables are small; an index needs a concurrent migration for no measured cost.
  - `[low]` `[reject]` (blind) missing tests (English history intro, admin through the job, report against an account deleted the same run) — admin and staff exemptions are tested on the operation; the others are direct reads of fixed text or follow from `deleted_at = now`.
  - `[medium]` `[patch]` (edge-case) sign-in race — same root cause as the blind row; patched there.
  - `[medium]` `[patch]` (edge-case) console-lifted ban kept forever — same as the verification-gap row; patched there.
  - `[maybe-false]` `[reject]` (edge-case) an unban with the same `created_at` but a lower id than its ban is not seen as lifting it — only reachable if the history backfill inserted an unban before its ban with the same timestamp; it copied events in store order (ban first). Would settle by querying production rows for equal ban/unban timestamps. If it happened, the new branch ends such a ban at the player's last update, so it is not kept forever (if-true low).
  - `[low]` `[patch]` (edge-case) old containers kept by Kamal hold json-file logs after the switch — README adds `docker container prune -f` on the VPS after the redeploy.
  - `[low]` `[reject]` (edge-case) the deleted-account count is not logged if a purge then raises — same as the blind row on step isolation; each deletion published its `PlayerDeleted` event.
  - `[low]` `[patch]` (edge-case) the notice names moderators only while administrators are exempt too — same root cause as the blind row; patched there.

## Design Notes

Moderation expiry, in SQL on `accounts_moderation_actions m JOIN accounts_players p`:

```sql
CASE
  WHEN p.deleted_at IS NOT NULL THEN p.deleted_at < :cutoff
  WHEN m.kind = 'ban' THEN EXISTS (SELECT 1 FROM accounts_moderation_actions l
    WHERE l.player_id = m.player_id AND l.kind = 'unban'
      AND (l.created_at, l.id) > (m.created_at, m.id) AND l.created_at < :cutoff)
  ELSE m.created_at < :cutoff
END
```

French retention text (English mirrors it, same keys):
- intro: « Combien de temps vos données sont conservées : »
- account: « votre compte, votre activité de jeu et vos réglages : tant que le compte existe ; un compte sans aucune visite connectée depuis trois ans est supprimé comme si vous l'aviez supprimé vous-même, sauf celui d'un modérateur ; »
- reports: « un signalement : jusqu'à ce qu'un modérateur le traite, puis un an ; s'il vise un compte supprimé avant d'être traité, un an après la suppression ; »
- moderation: « l'historique de modération, motifs compris : une suspension tant qu'elle dure, puis un an après sa levée ; un classement de signalements, un an ; l'historique d'un compte supprimé, jusqu'à un an après la suppression ; »
- banned_steam_id: « l'identifiant Steam d'un compte suspendu : tant que la suspension dure, pour refuser une nouvelle inscription ; »
- logs: « les journaux du serveur : 30 jours ; »
- errors: « les erreurs techniques reçues par Sentry : 90 jours au plus, selon l'offre Sentry de l'éditeur ; »
- leftovers: « ce qu'un compte supprimé laisse et qui concerne d'autres joueurs ou la communauté (échanges passés, premières découvertes, contributions à l'objectif communautaire, journal des actions du jeu) : tant que le jeu existe, sans identifiant Steam ni nom. »

## Verification

Every Rails command runs with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w714 CHROME_BIN=/usr/bin/chromium`.

**Commands:**
- `bin/rails test` -- expected: 0 failures, 0 errors
- `bin/rails test:system TEST=test/system/hub_test.rb` and `test/system/moderation_test.rb` -- expected: pass
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

**Summary:** a daily `Accounts::ApplyRetentionJob` (4am) deletes accounts idle three years through `Accounts::DeleteInactivePlayer` (row lock, re-check, then `Accounts::DeletePlayer`), erases reports one year after handling (or one year after the deletion of the account they target) with `Accounts::PurgeReports`, and erases moderation history rows one year after their end with `Accounts::PurgeModerationHistory`; it logs the three counts. Staff and banned accounts are never idle. Production containers and kamal-proxy log to journald, whose 30-day retention the host sets (README). The legal page lists every period in French and English; the deletion paragraph and the back-office history intro were brought in line.

**Files changed:**
- `packs/accounts/app/models/accounts/player.rb` -- `IDLE_PERIOD`, `idle(now)` scope (`GREATEST(last_seen_at, updated_at)`, role player, good standing).
- `packs/accounts/app/queries/accounts/idle_players.rb` -- idle players for the job.
- `packs/accounts/app/operations/accounts/delete_inactive_player.rb` -- locked re-check then `DeletePlayer`.
- `packs/accounts/app/operations/accounts/purge_reports.rb`, `purge_moderation_history.rb` -- batched purges, no event.
- `packs/accounts/app/operations/accounts/sign_in.rb` -- notes `last_seen_at` at sign-in.
- `packs/accounts/app/jobs/accounts/apply_retention_job.rb`, `config/recurring.yml` -- the daily job.
- `config/deploy.production.yml` -- journald for every container and the proxy.
- `app/views/pages/legal.html.erb`, `config/locales/{fr,en}.yml` -- `privacy.retention`, deletion paragraph, history intro, `errors.accounts.no_longer_idle`.
- `README.md` -- moderation bullet, new Retention section with the host step.
- Tests: new `test/jobs/apply_retention_job_test.rb`, `test/packs/accounts/{delete_inactive_player,purge_reports,purge_moderation_history}_test.rb`; extended `queue_config_test`, `pages_controller_test`, `back_office/history_controller_test`, `sign_in_test`, `presence_test`.

**Review:** 30 findings. Patched: 1 high entry (unbanned player deleted the next night), 5 medium entries (sign-in race, console-lifted ban kept forever, event-store trace missing from the notice, journald `MaxFileSec`, old json-file containers), 4 low (failure code name, notice staff wording, invitation test, README report note). Deferred 3 (host journald step, staging logs, Sentry plan period). The rest rejected with reasons in the triage log.

**Follow-up review recommended:** true -- a high was patched: idleness moved to `GREATEST(last_seen_at, updated_at)` and `SignIn` now writes `last_seen_at`; both are tested but not re-reviewed by a fresh lens.

**Verification:** `bin/rails test` 2121 runs, 0 failures (after updating `presence_test` for the synchronous sign-in write); `bin/rails test:system` 174 runs, 1 failure in `live_updates_test.rb:205` (trade swap timing, untouched area), which passed 3 of 3 re-runs of that file; `npm run test:js` 210 passed; `zeitwerk:check` all good; `packwerk check` no violations; `bin/rubocop` no offenses; `i18n-tasks missing` and `unused` clean. No migration; `db/schema.rb` unchanged.

**Residual risks:** journald retention is a host step (deferred); staging logs keep no age limit (deferred); Sentry period to confirm (deferred); the purges scan whole tables (fine at current size).
