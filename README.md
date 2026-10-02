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

## Run

```sh
bin/dev                       # Rails on http://localhost:3000 and the Vite dev server
```

Set `PORT` to use another port for Rails.

## Writing an operation

Every state change is an operation (AD-3). Inherit `ApplicationOperation`, name it `Pack::VerbNoun`, and wrap its writes and its `publish(event, stream_name:)` call in `transaction do ... end`, so the rows and the event (identifiers only) commit or roll back together. Call another operation of the pack only through `step`: the inner `transaction` joins the outer one, so an inner `Failure` handled without `step` would keep the inner rows and event, while `step` halts the outer flow and rolls back the whole transaction. Return `Success(value)`, or `Failure(:code)` with a message under the locale key `errors.<pack>.<code>` (`Game::OpenPack.failure_message(:no_pack)` reads `errors.game.no_pack`). `test/lib/application_operation_test.rb` shows a complete example.

## Test

```sh
bin/rails test
bin/rails zeitwerk:check
```

## Production checks

### Sentry (AD-21)

Sentry receives production errors only (no tracing, no profiling, no personal data; the player id is the only thing attached about a player). It starts only when `SENTRY_DSN` is set, so development and test send nothing.

1. Create the Sentry project (platform: Rails) and copy its DSN.
2. Export it in the shell you deploy from: `export SENTRY_DSN=https://…` (`.kamal/secrets` reads it from there; never commit it).
3. Deploy: `bin/kamal deploy`. The release is the deployed `KAMAL_VERSION`.
4. Send a test event and check it appears in the Sentry project, tagged `production` and the release:

   ```sh
   bin/kamal app exec --reuse 'bin/rails runner "Sentry.capture_message(%(gameble test event))"'
   ```

### Sign-in throttle

`POST /auth/steam`, `GET /auth/steam/callback` and `GET /auth/failure` accept 10 requests a minute per client IP (Rack::Attack, counts in `Rails.cache`); the 11th gets 429. Page reads are never throttled. Behind Cloudflare, the client IP must be the visitor's real IP, not Cloudflare's: that is deployment work.

### Job queue

Administrators open Mission Control Jobs at `/back-office/jobs` (linked from the back-office). Anyone else is refused.
