# Contributing to gameble

This guide is for developers. If you only want to report a bug or suggest an idea, open an [issue](https://github.com/theiereman/gameble/issues/new/choose) and read [Reporting a problem](docs/reporting-problems.md).

gameble is a free web trading card game where every card is a Steam game. The [README](README.md) gives the overview; [docs/architecture.md](docs/architecture.md) is the map of the code.

## Set up

You need the Ruby and Node versions of `.tool-versions` (an older asdf Ruby plugin may not know the Ruby version: `asdf plugin update ruby`, then `asdf install`) and Docker.

```sh
docker compose up -d          # PostgreSQL 18 on localhost:5433, not 5432
npm install                   # the Ruby suite builds the Vite assets first and aborts without them
bin/setup --skip-server       # gems, npm packages, databases
```

The database connection reads `DB_HOST`, `DB_PORT`, `DB_USER` and `DB_PASSWORD`, with defaults matching `compose.yaml`. Every variable the app reads is listed, with an example, in [.env.example](.env.example). `PUBLIC_URL` is required in production only. The Steam import reads `STEAM_API_KEY`, or, outside production, the ignored file `config/steam_api.key`.

## Run

```sh
bin/dev                       # Rails on http://localhost:3000, the Vite dev server, the jobs and the import worker
```

Set `PORT` to use another port for Rails.

## Test and check

```sh
bin/rails test                # Ruby tests; system tests are skipped
npm run test:js               # vitest
bin/rails zeitwerk:check
bin/ci                        # CI's Ruby checks (it skips vitest, zeitwerk and system tests)
```

- **System tests** drive a real browser. Run the ones of what you touch, not the whole suite: `bin/rails test test/system/<file>.rb -n /name/`. CI runs them all once, before a release goes to production.
- **Flaky tests are defects.** In a system test, assert timing-dependent state with a retrying Capybara matcher, never a one-shot read, and restore anything the test changes globally (such as the window size). Fix or remove a test that fails at random; never retry or skip it.
- Never name a model in a test class body (a constant such as `TABLES = [ Game::Pack ]`): it loads `ApplicationRecord` before the parallel workers fork, and a worker's GET then writes unprevented. Name models inside methods.
- Run these on what you touch: `bundle exec packwerk check` (there is no binstub), `npm run format:check` (`npm run format` fixes it), `npm run lint:css`, `script/check_planning_references` and `script/check_file_sizes`.

## Workflow

- Branch from `develop` and open a pull request to `develop`. Never push to or merge into `main`: it is the production release, and the author releases it (see [RELEASING.md](RELEASING.md)).
- Run `git fetch origin` and bring `develop` level with `origin/develop` before starting: other sessions change it, and what you are about to build may already exist.
- The author reviews and merges. The test site changes at the author's next release, not at the merge.
- Never commit `config/*.key` or any secret.
- After a migration, regenerate `db/schema.rb` from the migrations on Postgres 18, as CI does, and commit the diff; never edit it by hand: `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb`.

## Conventions

The rules behind these, and their reasons, are in [docs/architecture.md](docs/architecture.md); `AGENTS.md` is the same list for AI agents.

- **Writes**: only through an operation (`ApplicationOperation`, named `Domain::VerbNoun`, returning `Success` or `Failure(:code)`). Controllers, jobs, handlers and components never write a model; they read through the domain's queries. An operation publishes one event inside its transaction; handlers run in that transaction and never publish.
- **GET never writes**: GET actions run on the reading database role with writes prevented. Put the write behind a POST or a job.
- **Jobs and broadcasts**: enqueue a job only after commit; broadcast through a job, never inside a transaction.
- **No database ids** in URLs, HTML, JSON, DOM ids or stream names: use tokens.
- **Authorization**: every controller action has a Pundit policy.
- **Strings**: every string is in both `config/locales/en.yml` and `fr.yml`, and the locale is the first URL segment. Failure messages live under `errors.<domain>.<code>`; `i18n-tasks` cannot see those dynamic keys, so add both by hand. French plural keys need a `zero` form.
- **Domains**: dependencies follow the architecture diagram (`game` depends on `catalog` and `accounts`, `steam` on `catalog`, no domain on the web layer); `bundle exec packwerk check` fails otherwise.
- **Frontend**: the server renders HTML; never add React or build markup in script. Controllers clone server-rendered `<template>`s. A rich screen has one root controller holding its state module from `app/frontend/lib/<screen>.ts`; children talk to it by `dispatch` and it drives them through outlets. A screen talks to the page chrome only through the `gameble:*` events of `app/frontend/lib/events.ts`, and server HTML carries no `style` attribute.
- **Migrations** are expand/contract (strong_migrations): a concurrent index in its own migration, a check added then validated in a second one.
- **Code reads without comments**: carry intent in names and extracted methods; comment only an external constraint the code cannot state, in one line.
- **English everywhere** in the repository, except `config/locales/fr.yml`.
- **Generated files**: never hand-edit `app/frontend/images/pixel/`; run `node script/pixel_art/export.mjs` (`--check` verifies).

## Read the codebase

1. [docs/glossary.md](docs/glossary.md) for the words (card, season, set, holding, bank).
2. [docs/architecture.md](docs/architecture.md) for the layout, the four domains, the write and read paths, the jobs and the Stimulus screens.
3. A domain's `app/domains/<name>/app/operations/` lists everything it can do; its `queries/` lists what it can be asked. Tests mirror the code in `test/domains/<name>/`.
4. [docs/operations.md](docs/operations.md) for deployment, backups, the job queue and the Steam import.

## Work with an AI agent

You can change the game by asking an AI coding agent such as Claude Code or Codex to do it. It reads `AGENTS.md`, works on its own branch and opens a pull request to `develop`; ask it to run the tests and say in the pull request if it could not. Leave the database and the game's rules (`db/`, `app/domains/`) to developers, or ask the author first. In Claude Code, the planning skills in `.claude/skills/` (`bmad-brainstorming`, `bmad-forge-idea`, `bmad-party-mode`, `bmad-ux`) write to `_bmad-output/`, which reaches the author through the same pull request. Never mark a plan as approved: only the author does.

## License of your contribution

By opening a pull request, you agree that your contribution is released under the license of the files it changes (the GNU AGPL v3.0 for code, Creative Commons BY-NC-SA 4.0 for artwork; see the License section of the [README](README.md)), and you grant Thomas Eyermann the right to release it under other license terms as well, so the project can change its license later without asking every contributor.
