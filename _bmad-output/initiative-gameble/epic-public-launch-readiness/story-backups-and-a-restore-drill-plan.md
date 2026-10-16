---
title: 'Backups and a restore drill'
type: 'feature'
ticket: '11'
created: '2026-10-16'
status: done
baseline_revision: '14d30ca624e5be5d2bf41ffd84a56cff38ff43b2'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Production's only copy of the players' collections, trades and accounts is the PostgreSQL data directory on one home lab LXC with a 9.8 GB disk; a lost disk, a bad migration or a mistaken console command loses the game for good.

**Approach:** A systemd timer on the production LXC streams a `pg_dump` of the primary database straight into an encrypted, deduplicated restic repository kept off the server, then thins it by a fixed retention; a failure posts to the production Discord channel. A restore-drill script, run from the author's machine, restores the latest backup into a throwaway PostgreSQL 18, boots the release image on it and checks `/up` and the player count. The README gains a runbook, and the privacy notice states how long backups keep personal data.

## Boundaries & Constraints

**Always:**
- Back up the primary database only (`gameble_production`, about 34 MB as a custom-format dump on staging today). Cache, queue and cable are rebuilt empty by `db:prepare` at boot; a job in flight at the moment of loss is lost, and an import resumes from its run's cursor, which lives in primary.
- Dump with the server's own `pg_dump` (`docker exec gameble-db pg_dump -Fc`), streamed to `restic backup --stdin`: nothing is written to the LXC's disk.
- The script fails as a whole when any stage of the pipe fails (`set -o pipefail`), so an empty or truncated dump is never kept as a good backup.
- The restic password and the storage credentials live in one root-only file on the LXC (`/etc/gameble-backup/env`, mode 600) and in the author's password manager; the repo holds none.
- The privacy notice gains a backups line in both `fr.yml` and `en.yml`, and names the storage provider among the outside services when it is a third party.

**Decisions (author, 2026-10-16):**
- The backups are kept in OVHcloud Object Storage (S3 API, Standard class, 3-AZ Paris region `eu-west-par`, else 1-AZ Gravelines), bucket `gameble-backups`, reached by restic's `s3:` backend with an S3 user allowed on that bucket only; the privacy notice names OVH SAS among the outside services, the backups encrypted before they leave the server and kept in France.
- No bucket versioning: a kept version would outlive the 7-day retention the notice states, and versioning can only be suspended once enabled.
- Retention is 7 daily snapshots (`restic forget --keep-daily 7`): a deleted account leaves every backup after 7 days, which the notice's backups line states.
- (author, after review) When nights fail, the last 7 good backups are kept rather than a strict 7 calendar days: `--keep-daily 7` stays, `prune` runs with `--max-unused 0` so nothing a forgotten snapshot held lingers in the bucket, and the notice says "the last 7 daily backups, that is 7 days in normal times", a deleted account leaving them after 7 days, or a little longer when a backup failed.

**Never:**
- No backup of staging; no Kamal accessory or custom image for backups; no change to the app's code paths.
- No restore drill against the production database or on the production LXC (its disk is too small for a second copy).
- No planning ids in scripts, units, tests or the README.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Nightly backup | timer fires, db up, storage reachable | one new restic snapshot tagged `gameble_production`; snapshots beyond the retention are forgotten and pruned | exit 0, journald logs the snapshot id |
| Database down | `docker exec` fails | no snapshot is kept | non-zero exit; the failure unit posts to Discord |
| Dump dies mid-stream | `pg_dump` exits non-zero after some bytes | restic's partial snapshot is not left as the latest good one (the script forgets it) | non-zero exit; Discord |
| Storage unreachable | restic cannot reach the repository | nothing changes remotely | non-zero exit; Discord |
| Restore drill | latest snapshot, release tag given | scratch Postgres restored, app answers `/up` 200 and prints the player count; containers and network removed | any failed step stops the drill, prints which, and still removes the scratch containers |

</frozen-after-approval>

## Code Map

- `config/database.yml` (production) -- four databases on `DB_HOST` with user `gameble`; only `gameble_production` is backed up.
- `config/deploy.yml` -- accessory `db` (`postgres:18`, container `gameble-db`, data under `/root/gameble-db/data` on the host); the app reads `GAMEBLE_DATABASE_PASSWORD`, `DB_HOST`, `PUBLIC_URL`, `RAILS_MASTER_KEY`, `SECRET_KEY_BASE`.
- `bin/docker-entrypoint` -- `db:prepare` at server boot: creates and loads cache, queue and cable when missing. The drill relies on it.
- `.kamal/hooks/post-deploy` -- reuse its Discord payload shape for the failure message (plain `content`, no embeds needed).
- `README.md` "Production checks" (`### Retention` is the closest sibling) -- the runbook goes beside it as `### Backups`.
- `app/views/pages/legal.html.erb:91-99` -- the retention list; add one `<li>` for backups, and one service `<li>` for OVH at the services list.
- `config/locales/fr.yml` / `en.yml` `pages.legal.privacy.retention` and `.services` -- new keys `retention.backups` and `services.ovh`.
- `test/controllers/pages_controller_test.rb` -- asserts the legal page's lines; extend for the new ones.
- `test/lib/post_deploy_hook_test.rb` -- pattern for testing a shell script with stub commands on `PATH` in a tmpdir.
- Production LXC: Ubuntu 24.04, no restic yet (`apt install restic` gives 0.16), no crontab; journald keeps 30 days.

## Tasks & Acceptance

**Execution:**
- [x] `script/backup/gameble-backup` -- bash: source nothing itself (systemd's `EnvironmentFile` supplies `RESTIC_*` and provider variables); `pg_dump -Fc` through `docker exec` piped to `restic backup --stdin --stdin-filename gameble_production.dump --tag gameble_production`; on a failed pipe, forget the snapshot that run made; then `restic forget --tag gameble_production --keep-daily 7 --prune`; log the snapshot id.
- [x] `script/backup/gameble-backup.service`, `gameble-backup.timer`, `gameble-backup-failed.service` -- oneshot service with `EnvironmentFile=/etc/gameble-backup/env` and `OnFailure=`; the timer at 03:30 local (before the 4am retention job), `Persistent=true`, small random delay; the failure unit posts `gameble production: backup failed on <host>, see journalctl -u gameble-backup` to `DISCORD_WEBHOOK`.
- [x] `script/backup/restore_drill` -- run from the author's machine with a release tag: reads the restic env from a local git-ignored file, starts a scratch `postgres:18` on a private docker network, `restic dump latest` into `pg_restore`, runs `ghcr.io/theiereman/gameble-releases:<sha>` against it with `RAILS_MASTER_KEY` from `config/master.key`, a throwaway `SECRET_KEY_BASE` and `PUBLIC_URL=http://localhost`, waits for `/up`, prints the snapshot time and the player count, removes everything on exit (trap).
- [x] `test/script/gameble_backup_test.rb` -- with stub `docker` and `restic` on `PATH`: a good run backs up then forgets with the retention; a failing `docker` exits non-zero and never runs the retention; a failing restic exits non-zero.
- [x] `README.md` -- `### Backups` runbook: what is kept and what is not, schedule, retention, where; one-time install on the LXC (restic, `/etc/gameble-backup/env`, `restic init`, copy and enable the units); checking (`restic snapshots`, `systemctl list-timers`); a real restore into production; the drill and how often to run it.
- [x] `config/locales/fr.yml`, `config/locales/en.yml`, `app/views/pages/legal.html.erb`, `test/controllers/pages_controller_test.rb` -- the backups retention line and the OVH service line, tested.
- [x] `.gitignore` -- the drill's local env file under `config/` is already covered by `/config/*.key`; name it `config/backup_restic.key` (an env file) so no new rule is needed.

**Acceptance Criteria:**
- Given the units installed on the production LXC, when the timer fires, then `restic snapshots` lists a new snapshot and `journalctl -u gameble-backup` shows its id.
- Given a stopped `gameble-db`, when the service runs, then it fails and the production Discord channel receives the failure message.
- Given the latest snapshot, when the author runs the drill with the deployed release tag, then the release image answers `/up` with 200 on the restored data and the printed player count matches production's.
- Given the legal page in either locale, when it is shown, then the retention list includes how long backups keep data.

## Implementation Notes

- Matrix audit (orchestrator): "Database down" gained its own test (`docker exec` fails with no output: empty stdin, the snapshot forgotten, no retention). "Restore drill" has no automated test (it needs Docker, restic and a release image); the implementer ran it end to end with `v0.0.14-beta` (passed, `/up` 200, 6 players), with a garbage snapshot (failed, step named) and checked every container and network was removed.
- The legal page's "updated" date moved to 16 October 2026 with the privacy notice change.
- Done (author, 2026-10-16): the units run on the production LXC, the first backup (snapshot a8b221d5) reached OVH and the retention ran. The author signed the ticket off before the restore drill against the real repository, which waits for the first import; run `script/backup/restore_drill` then.

## Review Triage Log

Pass 1 (quick lens): high 1, medium 2, low 3, false 0, maybe-false 0.

| Finding | Verdict | Route | Evidence / action |
|---|---|---|---|
| `restore_drill` `clean_up` leaves the anonymous `/var/lib/postgresql` volume holding the restored database | high | patch | `postgres:18` declares `VOLUME /var/lib/postgresql`; three dangling PG18 volumes from the implementer's drill runs found and removed. Fix: `docker rm --force --volumes`. |
| Notice promises 7 days but `--keep-daily 7`, retention skipped on failure and prune's 5% unused break it | medium | intent_gap | Real; the author chose to keep the last 7 good backups. Resolved in the frozen block; fix: `--max-unused 0` and the notice wording, both locales and tests. |
| `restic forget "$snapshot" \|\| true` hides a failed forget of a partial snapshot | medium | patch | Real: the partial snapshot keeps the tag and the drill would pick it. Fix: say so on stderr with the command to forget it. |
| Good-run test sorts calls, so "then" is unchecked | low | patch | Real; fix: assert the retention forget is the last call. |
| `set -E` makes the ERR trap fire twice for a failure inside `$(...)` | low | patch | Reproduced by the reviewer; fix: print only at `BASH_SUBSHELL` 0. |
| `legal__backups` class marks the OVH services line | low | patch | Misleading name; fix: rename to `legal__backup_host`. |

## Design Notes

Retention bounds how long a deleted account survives in a backup; the privacy notice states that bound. restic is chosen over a plain dump-and-upload because it encrypts client-side (the provider never reads Steam ids), deduplicates (daily 34 MB dumps cost little) and applies retention itself. Streaming via `--stdin` keeps the 9.8 GB disk out of the picture.

## Verification

**Commands:**
- `bin/rails test test/script/gameble_backup_test.rb test/controllers/pages_controller_test.rb` -- expected: green.
- `bundle exec i18n-tasks missing` and `bundle exec i18n-tasks unused` -- expected: nothing new.
- `shellcheck script/backup/gameble-backup script/backup/restore_drill` (if installed) -- expected: no warning.
- `systemd-analyze verify script/backup/*.service script/backup/*.timer` -- expected: no error beyond the missing env file.

**Manual checks (if no CLI):**
- The author installs the units, runs `systemctl start gameble-backup` once, then the drill, and signs it off (hitl).
