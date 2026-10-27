<p align="center"><img src=".github/assets/gameble-header.gif" width="800" alt="gameble"></p>

# gameble

A Rails 8.1 application: four domains under `app/domains/` (`catalog`, `steam`, `accounts`, `game`) and a thin web layer in `app/`. Assets are served by Vite.

## Requirements

- Ruby and Node at the versions of `.tool-versions` (`asdf plugin update ruby`, then `asdf install`; an older asdf Ruby plugin does not know Ruby 4.0.7)
- Docker, for the local PostgreSQL 18

## Setup

```sh
docker compose up -d          # PostgreSQL on localhost:5433
bin/setup --skip-server       # gems, npm packages, databases
```

The database connection reads `DB_HOST`, `DB_PORT`, `DB_USER` and `DB_PASSWORD`, with defaults matching `compose.yaml`.

`PUBLIC_URL` is the public base of shared links (`https://host` or `http://host:port`, no path, query or user info), checked at boot: a malformed value refuses to boot in every environment, and production refuses to boot without one (except the Docker build's `assets:precompile`); in development and test, links fall back to the request's base when it is unset.

## Run

```sh
bin/dev                       # Rails on http://localhost:3000, the Vite dev server, the jobs and the import worker
```

Set `PORT` to use another port for Rails. The Steam import reads its API key from `STEAM_API_KEY`, or, outside production, from the git-ignored `config/steam_api.key`.

## Writing an operation

Every state change is an operation. Inherit `ApplicationOperation`, name it `Pack::VerbNoun`, and wrap its writes and its `publish(event, stream_name:)` call in `transaction do ... end`, so the rows and the event (identifiers only) commit or roll back together. Call another operation of the pack only through `step`: the inner `transaction` joins the outer one, so an inner `Failure` handled without `step` would keep the inner rows and event, while `step` halts the outer flow and rolls back the whole transaction. Return `Success(value)`, or `Failure(:code)` with a message under the locale key `errors.<pack>.<code>` (`Game::OpenPack.failure_message(:no_pack_available)` reads `errors.game.no_pack_available`). `test/lib/application_operation_test.rb` shows a complete example.

## Test

```sh
bin/rails test
bin/rails zeitwerk:check
```

## Branches and deployment

[RELEASING.md](RELEASING.md) is the release flow, step by step: versions, cutting a candidate, the acceptance checklist, the promotion, the production approval, rollback and the one-time setup. In short, the image built and tested for a release candidate is the image production runs.

- `develop` carries the work in progress. Feature branches start from it and come back to it.
- Staging (https://gameble.dotsncircles.com) runs release candidates, never a push: publishing a GitHub pre-release `vX.Y.Z-rc.N` whose tag is on `develop` runs the full CI on its commit, deploys it, and sets the commit status `staging` to success (`.github/workflows/deploy-staging.yml`). A release that is not a pre-release, or a pre-release whose tag is not on `develop`, deploys nothing there.
- `main` is production's (https://gameble.net) and only moves through `bin/promote`, which fast-forwards it to an accepted candidate's commit and publishes the release `vX.Y.Z` on that commit. The release copies the candidate's image to `ghcr.io/theiereman/gameble-releases` and, once the author approves the run in the GitHub environment `production`, deploys it with `bin/kamal deploy -d production --skip-push` (`.github/workflows/deploy-production.yml`). Production never builds an image. Never merge into `main`.

The staging workflow needs these secrets of the `staging` environment: `SSH_KEY` (private key allowed on the LXC) and `SSH_KNOWN_HOSTS` (the host key line for `[gameble.dotsncircles.com]:2224`), each environment holding its own under the same name, `SECRET_KEY_BASE` and `DATABASE_PASSWORD` (staging's own), `RAILS_MASTER_KEY`, `SENTRY_DSN` and `STEAM_API_KEY` (repository secrets, shared with production), all written to the same `config/*.key` files that `.kamal/secrets.staging` reads, and `DISCORD_WEBHOOK_STAGING` (the webhook URL of the Discord channel: Edit channel → Integrations → Webhooks → New webhook). The image and its build cache are pushed to GitHub's container registry (`ghcr.io/theiereman/gameble` and `gameble-build-cache`) with the job's own `GITHUB_TOKEN`, so no secret is needed for them; the workflow keeps the last five images and drops the build caches replaced. The release images live in their own package, `gameble-releases`, which nothing cleans. The production workflow's secrets, in the `production` environment, are listed in RELEASING.md (Setup, once).

### Discord announcement

After each deploy, `.kamal/hooks/post-deploy` posts one message to the destination's channel: the release, who published it, the destination's URL, and a simplified changelog. Commits are read as conventional commits: `feat` lands under "Nouveautés", `fix` under "Corrections", the rest under "Autres changements"; `docs`, `chore`, `ci`, `test`, `style` and `build` commits are counted, not listed.

The changelog always starts at the version last deployed to the destination, not at the previous tag: the hook keeps it as the tag `deployed/<destination>`, moved to the announced version after each announcement (a rollback too) and pushed to origin (a push that fails is printed, and the next changelog simply starts further back). A release tag never deployed, or a release on another branch, therefore never shortens a changelog. Before the first recorded deploy the nearest release below is used, and before any tag, the last 10 commits. A `redeploy`, or a deploy of the version already deployed, announces nothing; a `rollback` lists the changes taken back.

The deployed version is shown in the bottom-left corner of every page (`ShellHelper.app_version`). The image carries none: `config/deploy.yml` reads it when Kamal renders the config (`env.clear.GAMEBLE_VERSION`), as the highest tag of the deployed commit, a release above its candidate, else the commit's short sha; `dev` locally. One image therefore shows `v1.0.0-rc.2` on staging and `v1.0.0` in production.

`.kamal/hooks/pre-deploy` refuses a deploy of a commit without a tag, or of a dirty checkout, for every destination, and in production a commit without a release tag `vX.Y.Z` or other than `origin/main` (fetched first; offline, the local `origin/main`). A rollback is let through. A deploy from a machine follows the same rules. To deploy an untagged commit to staging on purpose, `bin/kamal deploy -d staging --skip-hooks` (no announcement either).

To deploy staging from a machine instead of the workflow, tag the commit first (`git tag v1.2.0-rc.1 && git push origin v1.2.0-rc.1`), put a GitHub token allowed to write packages in `config/registry_password.key` (`gh auth refresh -s write:packages && gh auth token > config/registry_password.key`), put the webhook URL in `config/discord_webhook.staging.key` (git-ignored like `master.key`; without it the hook announces nothing, and a Discord error never fails the deploy), and `bin/kamal deploy -d staging`. Such a deploy sets no `staging` status, so its candidate cannot be promoted. The message can be read before deploying:
```sh
KAMAL_DESTINATION=staging KAMAL_VERSION=$(git rev-parse HEAD) KAMAL_PERFORMER=$USER KAMAL_COMMAND=deploy .kamal/hooks/post-deploy --dry-run
```
Another destination gets the same with its own `config/discord_webhook.<destination>.key` and `deployed/<destination>` tag.

Production (https://gameble.net, its own LXC, reached through a Cloudflare Tunnel) is deployed by its workflow only; before its first deploy, `bin/kamal accessory boot db -d production` is run once by hand (RELEASING.md). Both destinations read the same shared files (`master.key`, `sentry_dsn.key`, `steam_api.key`, `registry_password.key`) and two of their own: `config/secret_key_base.<destination>.key` (`bin/rails secret`; each destination signs its sessions and cookies with it, so no staging session is valid in production, and the credentials' `secret_key_base` is never used) and `config/database_password.<destination>.key`. Keep both outside the machine too: losing the database password locks the app out of its data, and changing the secret signs every player out.

Always name the destination (`-d staging`, `-d production`). A Kamal command without one deploys containers named without the destination (`gameble-web-<version>`, `gameble-import-<version>`) that a later `bin/kamal deploy -d staging` neither replaces nor stops. They keep running their old code against the same database and take jobs from the same queues, so an import or a rescore is written by whichever version picks each page up. List what runs on the host with `bin/kamal server exec -d staging 'docker ps'`; stop and remove any `gameble-*` container whose name lacks the destination. `test/lib/post_deploy_hook_test.rb` runs both hooks against a throwaway repository and a local webhook, and `test/bin/promote_test.rb` runs `bin/promote` against a throwaway repository and a stub `gh`.

## Production checks

### Sentry

Sentry receives production errors only (no tracing, no profiling, no personal data; the player id is the only thing attached about a player). It starts only when `SENTRY_DSN` is set, so development and test send nothing.

1. Create the Sentry project (platform: Rails) and copy its DSN.
2. Put it in `config/sentry_dsn.key` (git-ignored like `master.key`, kept out of the image); `.kamal/secrets` reads it from there. Never commit it.
3. Deploy a release (RELEASING.md). The release is the deployed `KAMAL_VERSION`.
4. Send a test event and check it appears in the Sentry project, tagged `production` and the release:

   ```sh
   bin/kamal app exec -d production --roles web --reuse 'bin/rails runner "Sentry.capture_message(%(gameble test event))"'
   ```

### Sign-in throttle

`POST /auth/steam`, `GET /auth/steam/callback` and `GET /auth/failure` accept 10 requests a minute per client IP (Rack::Attack, counts in `Rails.cache`); the 11th gets 429. Page reads are never throttled. Behind Cloudflare, the client IP must be the visitor's real IP, not Cloudflare's: that is deployment work.

### Staff accounts and moderation

No page assigns roles. A player signs in with Steam once, then the role is set from their Steam id (`player`, `moderator` or `administrator`):

```sh
bin/rails "accounts:set_role[76561197960287002,moderator]"                          # locally
bin/kamal app exec -d production --roles web --reuse 'bin/rails "accounts:set_role[76561197960287002,moderator]"'  # in production
```

The task prints the new role, or aborts with the reason (unknown Steam id, deleted account, unknown role). Setting `player` takes a role away.

- Moderators and administrators open the back-office: every player at `/<locale>/back-office/players`, searched by part of the name or by the full Steam id, with each one's role, visibility and standing (BAN without waiting for a report, or LIFT THE BAN); the queue of reported players at `/<locale>/back-office/reports` (BAN, or DISMISS to set the reports aside; a report from a player who has not reported them yet brings them back) and the banned players at `/<locale>/back-office/bans` (LIFT THE BAN).
- A ban requires a reason, typed in the field next to BAN (500 characters at most). Every ban, lifted ban and dismissal is kept, with who acted and when, in the moderation history at `/<locale>/back-office/history` (linked from the back-office and its lists), the latest first; each row of the players list opens that player's history (`?player=<token>`). The reason is shown there only, never in an event or a message. Bans, lifted bans and dismissals made before the history existed were copied from the event store, without a reason; a ban set by hand in the console never appears. Rows are never edited; each is erased one year after its end, a ban lifted by hand in the console at the player's last update (see Retention below), and until then outlives a deleted account ("Deleted account").
- Staff act only on a lower rank (player < moderator < administrator): a moderator bans, unbans and dismisses the reports of players; an administrator also those of moderators; no one acts on an administrator. No one bans themselves or dismisses the reports against themselves.
- Administrators alone also reach the Steam import, the seasons, the card press and the job queue.
- Anyone not staff (a visitor, a player, a member of staff since banned) gets 404 on every back-office address, the same page as an unknown address. A moderator on an administrator's page gets 403.
- Staff read every player's public profile, private, friends-only or banned (not a deleted one), and may report it; the feed and the friend profile show staff what a player would see.
- A ban signs the player out, refuses their sign-in, hides their profile, cancels their open trades and drops their friendships and invitations. Lifting it gives back the sign-in and the profile, not the friendships or trades.

Ban from the back-office, not from the console: setting `banned_at` by hand publishes nothing, so the player's trades and friendships stay until `bin/rails game:drop_friends_and_trades` runs.

### Retention

Every day at 4am `Accounts::ApplyRetentionJob` (`config/recurring.yml`) keeps personal data no longer than the privacy notice says, and logs how many accounts, reports and history rows it removed:

- an account with no signed-in visit and no change for three years (the later of `last_seen_at` and `updated_at`, which a sign-in, an unban, a role change or a setting moves) is deleted as `Accounts::DeletePlayer` deletes it. Staff accounts and banned accounts are exempt: a banned account keeps its Steam id while the ban lasts;
- a report is erased one year after it was handled, or one year after the deletion of the account it targets. Once a handled report is erased, a new report from the same reporter brings the player back to the queue;
- a moderation history row is erased one year after its end: a ban ends at the unban that lifts it (never while in force), or, lifted by hand in the console with no unban, at the player's last update; an unban or a dismissal ends when made; every row of a deleted account at its deletion.

The server logs are kept 30 days. In production every container (app, import worker, database, kamal-proxy) logs to journald, which keeps them as long as the host says. Set it once, on the production LXC:

```sh
sudo mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nMaxRetentionSec=30day\nMaxFileSec=1day\n' | sudo tee /etc/systemd/journald.conf.d/retention.conf
sudo systemctl restart systemd-journald
```

A container keeps the log driver it was started with: on a host already running containers, move them all to journald from your machine, in a checkout of the release production runs (the deploy pulls its image, it never builds one):

```sh
bin/kamal proxy reboot -d production
bin/kamal accessory reboot db -d production
bin/kamal deploy -d production --skip-push
```

Then, on the production LXC, remove the stopped containers Kamal kept, which still hold their json-file logs:

```sh
docker container prune -f
```

Staging keeps Docker's default log driver. Sentry keeps errors 30 days, the retention of its Developer plan.

### Backups

Every night at 03:30 (the LXC's time, up to 10 minutes later) the systemd timer `gameble-backup.timer` on the production LXC runs `script/backup/gameble-backup`: `pg_dump` in `gameble-db` streams the primary database, `gameble_production`, straight into a [restic](https://restic.net) repository, so nothing is written to the LXC's disk. restic encrypts the dump before it leaves the server and deduplicates it. A failed or truncated dump fails the run and its snapshot is forgotten; a failed run posts `gameble production: backup failed on <host>, see journalctl -u gameble-backup` to the production Discord channel (`gameble-backup-failed.service`).

- **Kept:** the primary database: accounts, collections, trades, moderation, import runs and their cursors.
- **Not kept:** the cache, queue and cable databases, which `db:prepare` recreates empty when the app boots. A job in flight at the moment of loss is lost; an import resumes from its run's cursor.
- **Retention:** 7 daily snapshots (`restic forget --keep-daily 7 --prune --max-unused 0` after each backup, so nothing a forgotten snapshot held stays in the bucket). The privacy notice tells players the backups are the last 7 daily ones, 7 days in normal times, and that a deleted account is gone from them after 7 days, a little longer if a backup failed: change both together.
- **Where:** OVHcloud Object Storage, bucket `gameble-backups`, Standard class, region `eu-west-par` (3-AZ Paris; else `gra`, Gravelines), without versioning: a kept version would outlive the 7 days. The S3 user is allowed on that bucket only.
- **Secrets:** the restic password and the S3 user's keys live in `/etc/gameble-backup/env` on the LXC (root only) and in the author's password manager. Without the restic password, the backups cannot be read by anyone.

One-time install. In the OVHcloud console, create the bucket (no versioning) and an S3 user whose policy allows that bucket only. On the production LXC, install restic and create the env file, root only:

```sh
apt install restic curl
install -d -m 700 /etc/gameble-backup
install -m 600 /dev/null /etc/gameble-backup/env
```

Fill it with an editor. systemd and the shell both read it, so write each value bare, without quotes, spaces or `$`:

```sh
RESTIC_REPOSITORY=s3:https://s3.eu-west-par.io.cloud.ovh.net/gameble-backups
RESTIC_PASSWORD=<openssl rand -hex 32, kept in the password manager>
AWS_ACCESS_KEY_ID=<the S3 user's access key>
AWS_SECRET_ACCESS_KEY=<the S3 user's secret key>
AWS_DEFAULT_REGION=eu-west-par
DISCORD_WEBHOOK=<the production channel's webhook, as in config/discord_webhook.production.key>
```

Then create the repository:

```sh
set -a; . /etc/gameble-backup/env; set +a
restic init
```

Then, from your machine (which reaches the LXC as `ssh.gameble.net` through the tunnel, RELEASING.md, Setup), copy the script and the units, and on the LXC enable the timer and run a first backup:

```sh
scp script/backup/gameble-backup ssh.gameble.net:/usr/local/bin/gameble-backup
scp script/backup/gameble-backup.service script/backup/gameble-backup.timer script/backup/gameble-backup-failed.service ssh.gameble.net:/etc/systemd/system/
```

```sh
chmod 755 /usr/local/bin/gameble-backup
systemctl daemon-reload
systemctl enable --now gameble-backup.timer
systemctl start gameble-backup
systemctl start gameble-backup-failed   # posts the failure message once, to check the webhook
```

Copy the script and the units again whenever they change in the repository, then `systemctl daemon-reload`.

Checking, on the LXC:

```sh
systemctl list-timers gameble-backup.timer      # the next and the last run
journalctl -u gameble-backup -n 30              # "gameble-backup: snapshot <id> saved", then the retention
set -a; . /etc/gameble-backup/env; set +a
restic snapshots --tag gameble_production       # one a day, 7 at most
restic check                                    # the repository's own consistency
```

A run killed in the middle can leave a stale lock that refuses the next one: `restic unlock`.

**Restoring production.** Restoring replaces the whole primary database with the snapshot: everything since is lost, and an account deleted since comes back (delete it again). From your machine, stop the app (both roles), then on the LXC pick the snapshot and restore it into an empty `gameble_production`:

```sh
bin/kamal app stop -d production
```

```sh
set -a; . /etc/gameble-backup/env; set +a
restic snapshots --tag gameble_production
docker exec gameble-db dropdb --username=gameble gameble_production
docker exec gameble-db createdb --username=gameble gameble_production
restic dump <snapshot id> /gameble_production.dump | docker exec -i gameble-db pg_restore --username=gameble --dbname=gameble_production --no-owner --exit-on-error
```

On a new LXC, run `bin/kamal accessory boot db -d production` first (it creates an empty `gameble_production`), restore, and only then deploy: the app's `db:prepare` would otherwise load an empty schema. Finally `bin/kamal app boot -d production` (or the deploy), and check `/up` and the player count below.

**The restore drill.** `script/backup/restore_drill`, run from your machine, proves a backup restores and that the release production runs boots on it, without touching production. It reads the repository's settings from `config/backup_restic.key` (git-ignored like `master.key`: the same `RESTIC_*` and `AWS_*` lines as the LXC's env file, without `DISCORD_WEBHOOK`) and needs restic, Docker, Ruby, OpenSSL and `config/master.key`. The release images are private: log in once with `docker login ghcr.io -u theiereman --password-stdin < config/registry_password.key`.

```sh
script/backup/restore_drill v1.2.0          # the release production runs
```

It restores the latest snapshot into a scratch `postgres:18`, boots `ghcr.io/theiereman/gameble-releases:<sha>` on it, on a private Docker network with no way out (no job runs, nothing reaches Steam, Sentry or Discord), waits for `/up` to answer 200, prints the snapshot's time and the player count, and removes its containers and network whatever happens; a failed step is named. Compare the count with production's, which differs only by the accounts created or deleted since the snapshot:

```sh
bin/kamal app exec -d production --roles web --reuse 'bin/rails runner "puts Accounts::Player.where(deleted_at: nil).count"'
```

Run the drill once a month, after any change to the backup, and before a PostgreSQL major upgrade.

### Job queue

Administrators open Mission Control Jobs at `/back-office/jobs` (linked from the back-office). A moderator is refused (403); anyone not staff gets 404.

### Steam import

Administrators start and watch import runs at `/<locale>/back-office/import-runs`. The `import` queue has its own process, one thread (`bin/jobs -c config/queue_import.yml --skip-recurring`, the `import` role of `config/deploy.yml`); the key comes from `config/steam_api.key` through `.kamal/secrets`. A run that fails after its retries can be resumed from its cursor on its page, or, while it is the latest run that was not abandoned, abandoned ("Abandon this run", `Steam::AbandonImport`): an abandoned run is finished for good, blocks no new run, discards its staged rows, and is skipped when deciding whether a season can be published (the latest run that was not abandoned decides, and a failed one can be abandoned in turn). A failed run keeps its staged rows so a resume continues.

A run goes through five steps: the app list (`GetAppList`), the review pass (`GetItems`, 100 games a call), the tag names (`GetTagList`), the details of the kept games (`GetItems`, in English and French), then the cards, whose scores are staged beside the draft season. Only the Steam Web API is called; the keyless store API (`appdetails`) is not, so a run takes minutes rather than hours. A card's genres are its tags among the curated list of `Steam::GenreTags`, most-voted first, and it sits in the tome of the first; a change of that list takes effect on "Rescore the cards" (without calling Steam) while the run's draft is unpublished, otherwise on the next import.

The cards pass never touches the draft: each card's identity is refreshed in place and its scores are staged (`Catalog::StageCardSeason`). When the pass ends, the run is `ready` and waits. The administrator reviews it on the run page (gap with the draft, rarity spread, preview) and promotes it (`Steam::PromoteImport`), which replaces the draft's card-seasons in one transaction, or discards it (`Steam::DiscardImport`), which deletes the staged rows and leaves the draft as it was. While a run waits, no import starts and publishing stays refused; promoting a run whose season was published since is refused as stale. "Rescore the cards" stages a new batch from the stored Steam data, reviewed and promoted the same way; discarding it restores the run so it can be rescored again.

A malformed app never fails a page: Steam's values are read defensively (`Steam::RawValue`). An appid listed twice in a `GetAppList` page is kept once and an entry without a valid appid is skipped, both named in the run's errors (`repeated_in_page`, `malformed_entries`); a review count or percent out of shape excludes the game as `malformed_reviews`; a malformed store field gives the matching details exclusion or is dropped; a stored review value out of range is refused at the cards step (`invalid_reviews`).

Stopping the import worker gracefully (`TERM`) hands its job back, and the run goes on from its cursor when the worker restarts. A worker killed outright (`KILL`, out of memory) loses its job: every 5 minutes `Steam::RecoverStalledImportsJob` (`config/recurring.yml`) puts a running run that has not moved for 10 minutes back on the import queue, and it goes on from its cursor, without duplicates.

### Calibrating a season

The prestige formula, the tier shares and the tome size are starting values; they are checked against the real catalog before a season is published.

1. **Run the import where it will be published.** The first real import runs on the test server, after `bin/kamal deploy -d staging`; start it at `/<locale>/back-office/import-runs` and let it complete. The constants below live in the code, so a change made for that server needs a commit and another `bin/kamal deploy -d staging` before it takes effect there.
2. **Read the preview.** `/<locale>/back-office/seasons` shows, under the seasons, what publishing the draft now would produce (`Catalog::DraftPreview`): the prestige score percentiles, each rarity's size and lowest score, the ten highest and ten lowest cards, the cards and tomes per first genre, and the sets per kind. Nothing is written; the page computes it on every load, even while an import is unfinished.
3. **Change the constant that is off:**
   - `Steam::PrestigeScore` (`app/domains/steam/app/models/steam/prestige_score.rb`): the formula, a function of the rating and the rating count only (the count ranks, the positive percent in thousandths only orders equal counts; bump `VERSION` with any change);
   - `Catalog::RarityThresholds::SHARES` (`app/domains/catalog/app/models/catalog/rarity_thresholds.rb`): each rarity's share of the season, in basis points from the top;
   - `Catalog::SetBuilder::TOME_SIZE` (`app/domains/catalog/app/models/catalog/set_builder.rb`): the cards per tome volume.
4. **Rescore after a formula change.** The scores are written into the draft by the import, so a new formula needs them written again: on the latest completed run's page, "Rescore the cards" (`Steam::RescoreCards`) runs its cards step again from the start, without calling Steam, and the run completes again; a card the rescore now refuses leaves the draft. Only the latest run can be rescored, so once a later run is abandoned, the completed run before it no longer can: start a new run instead. The rescore publishes the cards step's `ImportStepFinished` and the run's `ImportRunFinished` a second time and rewrites `finished_at`, so record the step durations of the import before any rescore (the `Steam::CardsRescoreStarted` event marks the boundary). Once the draft is published, its run can no longer be rescored. A change of `SHARES` or `TOME_SIZE` needs no rescore: the preview shows it on the next page load.
5. **Publish.** Once the preview reads right and the latest run has completed (an abandoned run is skipped: the run before it must have completed, or be abandoned in turn), publish the draft from the same page. A published season never changes again.

## License

gameble is free software with its artwork kept for non-commercial use.

- **Code**: every file not listed below is released under the [GNU Affero General Public License v3.0](LICENSE). Anyone may run, change and sell it, but whoever runs a modified gameble as an online service must publish its full source code to its players under the same license.
- **Artwork**: the pixel art and its definitions (`app/frontend/images/pixel/`, `script/pixel_art/`), the card preview sample (`app/frontend/images/card_preview/`), the error pages' wordmark and starfield (`public/errors/*.svg`) and the README header (`.github/assets/`) are released under [Creative Commons Attribution-NonCommercial-ShareAlike 4.0](LICENSE-ASSETS): free to reuse with credit, never for a commercial purpose, and only under the same license.
- **Name and logo**: neither license grants any right to the name "gameble", its wordmark or its logo. A fork must use its own name.
- **Third parties**: the JetBrains Mono and VT323 fonts are under the SIL Open Font License (`app/frontend/fonts/OFL-*.txt`); the "Sign in through Steam" button (`app/frontend/images/steam/`) belongs to Valve; the reference images under `_bmad-output/**/imports/` belong to their owners. Steam game names and artwork are loaded from Steam and belong to the games' publishers and artists. gameble is not affiliated with Valve or Steam.

Copyright © 2026 Thomas Eyermann.
