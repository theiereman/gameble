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

## Operations

Branches, deployment, production checks, backups, staffing, retention, the job queue, the Steam import and season calibration are in [docs/operations.md](docs/operations.md).

## License

gameble is free software with its artwork kept for non-commercial use.

- **Code**: every file not listed below is released under the [GNU Affero General Public License v3.0](LICENSE). Anyone may run, change and sell it, but whoever runs a modified gameble as an online service must publish its full source code to its players under the same license.
- **Artwork**: the pixel art and its definitions (`app/frontend/images/pixel/`, `script/pixel_art/`), the card preview sample (`app/frontend/images/card_preview/`), the error pages' wordmark and starfield (`public/errors/*.svg`) and the README header (`.github/assets/`) are released under [Creative Commons Attribution-NonCommercial-ShareAlike 4.0](LICENSE-ASSETS): free to reuse with credit, never for a commercial purpose, and only under the same license.
- **Name and logo**: neither license grants any right to the name "gameble", its wordmark or its logo. A fork must use its own name.
- **Third parties**: the JetBrains Mono and VT323 fonts are under the SIL Open Font License (`app/frontend/fonts/OFL-*.txt`); the "Sign in through Steam" button (`app/frontend/images/steam/`) belongs to Valve; the reference images under `_bmad-output/**/imports/` belong to their owners. Steam game names and artwork are loaded from Steam and belong to the games' publishers and artists. gameble is not affiliated with Valve or Steam.

Copyright © 2026 Thomas Eyermann.
