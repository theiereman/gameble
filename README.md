# gameble

A Rails 8.1 application: four domain packs under `packs/` (`catalog`, `steam`, `accounts`, `game`) and a thin web layer in `app/`. Assets are served by Vite.

## Requirements

- Ruby and Node at the versions of `.tool-versions` (`asdf plugin update ruby`, then `asdf install`; an older asdf Ruby plugin does not know Ruby 4.0.7)
- Docker, for the local PostgreSQL 18

## Setup

```sh
docker compose up -d          # PostgreSQL on localhost:5433
bin/setup --skip-server       # gems, npm packages, databases
```

The database connection reads `DB_HOST`, `DB_PORT`, `DB_USER` and `DB_PASSWORD`, with defaults matching `compose.yaml`.

`PUBLIC_URL` is the public base of shared links (`https://host`, no trailing slash): required in production; in development and test, links fall back to the request's base.

## Run

```sh
bin/dev                       # Rails on http://localhost:3000, the Vite dev server, the jobs and the import worker
```

Set `PORT` to use another port for Rails. The Steam import reads its API key from `STEAM_API_KEY`, or, outside production, from the git-ignored `config/steam_api.key`.

## Writing an operation

Every state change is an operation (AD-3). Inherit `ApplicationOperation`, name it `Pack::VerbNoun`, and wrap its writes and its `publish(event, stream_name:)` call in `transaction do ... end`, so the rows and the event (identifiers only) commit or roll back together. Call another operation of the pack only through `step`: the inner `transaction` joins the outer one, so an inner `Failure` handled without `step` would keep the inner rows and event, while `step` halts the outer flow and rolls back the whole transaction. Return `Success(value)`, or `Failure(:code)` with a message under the locale key `errors.<pack>.<code>` (`Game::OpenPack.failure_message(:no_pack_available)` reads `errors.game.no_pack_available`). `test/lib/application_operation_test.rb` shows a complete example.

## Test

```sh
bin/rails test
bin/rails zeitwerk:check
```

## Production checks

### Sentry (AD-21)

Sentry receives production errors only (no tracing, no profiling, no personal data; the player id is the only thing attached about a player). It starts only when `SENTRY_DSN` is set, so development and test send nothing.

1. Create the Sentry project (platform: Rails) and copy its DSN.
2. Put it in `config/sentry_dsn.key` (git-ignored like `master.key`, kept out of the image); `.kamal/secrets` reads it from there. Never commit it.
3. Deploy: `bin/kamal deploy`. The release is the deployed `KAMAL_VERSION`.
4. Send a test event and check it appears in the Sentry project, tagged `production` and the release:

   ```sh
   bin/kamal app exec --reuse 'bin/rails runner "Sentry.capture_message(%(gameble test event))"'
   ```

### Sign-in throttle

`POST /auth/steam`, `GET /auth/steam/callback` and `GET /auth/failure` accept 10 requests a minute per client IP (Rack::Attack, counts in `Rails.cache`); the 11th gets 429. Page reads are never throttled. Behind Cloudflare, the client IP must be the visitor's real IP, not Cloudflare's: that is deployment work.

### Job queue

Administrators open Mission Control Jobs at `/back-office/jobs` (linked from the back-office). Anyone else is refused.

### Steam import (AD-19)

Administrators start and watch import runs at `/<locale>/back-office/import-runs`. The `import` queue has its own process, one thread (`bin/jobs -c config/queue_import.yml --skip-recurring`, the `import` role of `config/deploy.yml`); the key comes from `config/steam_api.key` through `.kamal/secrets`. A run that fails after its retries can be resumed from its cursor on its page, or, while it is the latest run, abandoned ("Abandon this run", `Steam::AbandonImport`): an abandoned run is finished for good, blocks no new run, and is skipped when deciding whether a season can be published (the latest run that was not abandoned decides). A run that failed on its cards step after writing at least one card cannot be abandoned, as those cards replaced the previous run's in the draft: resume it, or start a new run.

A run goes through five steps: the app list (`GetAppList`), the review pass (`GetItems`, 100 games a call), the tag names (`GetTagList`), the details of the kept games (`GetItems`, in English and French), then the cards written into the draft season. Only the Steam Web API is called; the keyless store API (`appdetails`) is not, so a run takes minutes rather than hours. A card's genres are its tags among the curated list of `Steam::GenreTags`, most-voted first, and it sits in the tome of the first; a change of that list takes effect on "Rescore the cards" (without calling Steam) while the run's draft is unpublished, otherwise on the next import.

At the end of each cards pass (an import's or a rescore's), the draft season keeps only the cards that pass wrote (`Catalog::PruneDraft`): a game an earlier run carded and this one no longer keeps leaves the draft, its card row kept, and the run page counts it under "Cards struck from the draft". Nothing is pruned when a run starts or in the middle of a pass, so while a run is unfinished the draft still holds the previous pass's cards, and publishing stays refused.

A malformed app never fails a page: Steam's values are read defensively (`Steam::RawValue`). An appid listed twice in a `GetAppList` page is kept once and an entry without a valid appid is skipped, both named in the run's errors (`repeated_in_page`, `malformed_entries`); a review count or percent out of shape excludes the game as `malformed_reviews`; a malformed store field gives the matching details exclusion or is dropped; a stored review value out of range is refused at the cards step (`invalid_reviews`).

Stopping the import worker gracefully (`TERM`) hands its job back, and the run goes on from its cursor when the worker restarts. A worker killed outright (`KILL`, out of memory) loses its job: every 5 minutes `Steam::RecoverStalledImportsJob` (`config/recurring.yml`) puts a running run that has not moved for 10 minutes back on the import queue, and it goes on from its cursor, without duplicates.

### Calibrating a season

The prestige formula, the tier shares and the tome size are starting values; they are checked against the real catalog before a season is published.

1. **Run the import where it will be published.** The first real import runs on the test server, after `bin/kamal deploy`; start it at `/<locale>/back-office/import-runs` and let it complete. The constants below live in the code, so a change made for that server needs a commit and another `bin/kamal deploy` before it takes effect there.
2. **Read the preview.** `/<locale>/back-office/seasons` shows, under the seasons, what publishing the draft now would produce (`Catalog::DraftPreview`): the prestige score percentiles, each rarity's size and lowest score, the dust shares, the ten highest and ten lowest cards, the cards and tomes per first genre, and the sets per kind. Nothing is written; the page computes it on every load, even while an import is unfinished.
3. **Change the constant that is off:**
   - `Steam::PrestigeScore` (`packs/steam/app/models/steam/prestige_score.rb`): the formula, a function of the rating and the rating count only (`COUNT_WEIGHT` weighs the count);
   - `Catalog::RarityThresholds::SHARES` (`packs/catalog/app/models/catalog/rarity_thresholds.rb`): each rarity's share of the season, in basis points from the top;
   - `Catalog::SetBuilder::TOME_SIZE` (`packs/catalog/app/models/catalog/set_builder.rb`): the cards per tome volume.
4. **Rescore after a formula change.** The scores are written into the draft by the import, so a new formula needs them written again: on the latest completed run's page, "Rescore the cards" (`Steam::RescoreCards`) runs its cards step again from the start, without calling Steam, and the run completes again; a card the rescore now refuses leaves the draft. Only the latest run can be rescored, so once a later run is abandoned, the completed run before it no longer can: start a new run instead. The rescore publishes the cards step's `ImportStepFinished` and the run's `ImportRunFinished` a second time and rewrites `finished_at`, so record the step durations of the import before any rescore (the `Steam::CardsRescoreStarted` event marks the boundary). Once the draft is published, its run can no longer be rescored. A change of `SHARES` or `TOME_SIZE` needs no rescore: the preview shows it on the next page load.
5. **Publish.** Once the preview reads right and the latest run has completed (an abandoned run is skipped: the run before it must have completed), publish the draft from the same page. A published season never changes again.
