<p align="center"><img src=".github/assets/gameble-header.gif" width="800" alt="gameble"></p>

# gameble

A free web trading card game where every card is a Steam game. Players open capsules, complete sets in their album and trade cards with friends.

## How it is built

A Rails 8 application with Hotwire and TypeScript Stimulus controllers: the server renders every screen and script only enhances it. Assets are served by Vite, data lives in PostgreSQL 18.

- Domain code sits in four packwerk domains under `app/domains/`: `catalog`, `steam`, `accounts` and `game`. Each state change is an operation that publishes an event.
- A thin web layer (controllers, policies, components, views) sits in `app/`.
- The frontend is in `app/frontend/`.

The map of the code is [docs/architecture.md](docs/architecture.md), and the game's vocabulary is [docs/glossary.md](docs/glossary.md).

## Quick start

You need the Ruby and Node versions of `.tool-versions` and Docker.

```sh
docker compose up -d          # PostgreSQL 18 on localhost:5433
bin/setup --skip-server       # gems, npm packages, databases
bin/dev                       # Rails on http://localhost:3000, Vite, jobs
bin/rails test                # the Ruby test suite
npm run test:js               # the TypeScript tests
```

The environment variables the app reads are listed in [.env.example](.env.example); none is needed to run it locally.

## Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md): setup, conventions, tests and workflow for developers
- [docs/architecture.md](docs/architecture.md): where things live and the rules that keep them apart
- [docs/glossary.md](docs/glossary.md): the game's vocabulary
- [docs/operations.md](docs/operations.md): deployment, backups, jobs and the Steam import
- [RELEASING.md](RELEASING.md): how a release goes to production
- [docs/reporting-problems.md](docs/reporting-problems.md): how to report a bug or an idea

## License

gameble is free software under the [GNU Affero General Public License v3.0](LICENSE) (AGPL-3.0): anyone may run, change and sell it, but whoever runs a modified gameble as an online service must publish its source code to its players under the same license.

- **Artwork**: the pixel art, the card preview sample, the error pages' wordmark and starfield and this header are under [Creative Commons Attribution-NonCommercial-ShareAlike 4.0](LICENSE-ASSETS), never for a commercial purpose.
- **Name and logo**: neither license grants any right to the name "gameble", its wordmark or its logo. A fork must use its own name.
- **Third parties**: the JetBrains Mono and VT323 fonts are under the SIL Open Font License (`app/frontend/fonts/OFL-*.txt`); the "Sign in through Steam" button belongs to Valve; Steam game names and artwork belong to their publishers and artists. gameble is not affiliated with Valve or Steam.

Copyright © 2026 Thomas Eyermann.
