---
title: 'Walking skeleton running locally'
type: 'feature'
ticket: '1'
created: '2026-10-02'
status: 'ready-for-dev'
baseline_revision: ''
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The repository holds only planning documents. Nothing can be built or shown until an application exists.

**Approach:** Create the Rails 8.1 application named `gameble` at the repository root, with PostgreSQL, Vite and the four empty packs, serving one placeholder page that runs and passes its tests locally. Production deployment is a separate, later piece of work.

## Boundaries & Constraints

**Always:**
- The application name is `gameble` (decided by the author on 2026-10-02).
- Follow the architecture spine: the versions of its Stack table and the four packs `catalog`, `steam`, `accounts`, `game` (AD-1).
- Ruby 4.0.7; fall back to Ruby 3.4.11 only if the application cannot boot or pass its tests on 4.0.7, and record why.
- Local configuration comes from environment variables with working defaults. No secret is committed.
- All repository text is in English.
- Styles go through Vite: a Vite stylesheet entrypoint replaces Propshaft's `stylesheet_link_tag` in the layout. Propshaft is left aside: installed as generated, unused by the application's own assets (author's decision, 2026-10-02).

**Never:**
- No production deployment in this story: there is no server, no domain and no Cloudflare setup yet. The author will deploy himself, with Kamal and its default Let's Encrypt certificate, once a working version exists. The files `rails new` generates for Kamal and Docker stay as generated.
- No CI workflow, Packwerk check, RuboCop or translation gate written by hand (story 1.2). The CI, Dependabot, RuboCop, Brakeman and bundler-audit files that `rails new` generates stay as generated (author's decision, 2026-10-02); story 1.2 adapts them.
- No dry-operation or Rails Event Store (story 1.3). No locales, layout shell, design tokens or view components (story 1.4).
- No TypeScript, Stimulus, Turbo or React (story 1.5). No sign-in, roles, attic page or Sentry (stories 1.6 to 1.9).
- No domain model, migration or game code in any pack.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Placeholder page | `GET /` | 200, an HTML page naming gameble, with its Vite script and stylesheet tags | No error expected |
| Health check | `GET /up` | 200 when the application boots | 500 when it cannot boot (not tested) |
| Unknown path | `GET /nope` | 404 | Standard Rails 404 |

</frozen-after-approval>

## Code Map

Greenfield: the repository root holds only `.agents/`, `.claude/`, `_bmad/`, `_bmad-output/` and `skills-lock.json`. Nothing collides with `rails new .`.

- Local toolchain -- asdf has Ruby 3.4.6, 4.0.3 and 4.0.5, none selected; its Ruby plugin lists versions only up to 4.0.6, so it must be updated before 4.0.7 (or 3.4.11) can be installed. Node 24.15.0, Docker 29.7.2 and the PostgreSQL 18.6 client are present. Port 5434 is taken by an unrelated `postgres_db` container; 5432 and 5433 are free.
- `rails new . --name=gameble --database=postgresql --skip-javascript` -- keeps Kamal, Solid Queue/Cache/Cable, Thruster and the Dockerfile; also skips Hotwire, which story 1.5 adds. Do not pass `--skip-git`: it would drop `.gitignore` and `.gitattributes`.
- `vite_rails` 3.11.1 -- `bundle exec vite install` creates `bin/vite`, `vite.config.ts`, `config/vite.json`, `app/frontend/entrypoints/application.js`, `package.json` and `Procfile.dev`, and adds the Vite tags to the layout.
- `packs-rails` 0.1.0 -- in the Gemfile outside any group; detects `packs/<name>/package.yml`, which may be empty, and names each pack by its path (`packs/catalog`). It brings `packwerk` into `Gemfile.lock` as a dependency; no `packwerk.yml` in this story.
- `config/database.yml` -- generated with one database each for development and test, and four for production; leave production as generated.
- `bin/setup` -- generated without `npm install` because of `--skip-javascript`, and it ends by starting `bin/dev` unless given `--skip-server`.
- `bin/dev` -- generated as a plain `rails server`; it ignores `Procfile.dev`, so the Vite dev server does not start.
- Test environment -- `vite_javascript_tag` builds assets on demand and needs `node_modules`; Rails 8.1 renders 404s in tests (`show_exceptions = :rescuable`).
- Rails issue 58069 -- an intermittent `FrozenError` on autoload paths at boot, reported with Ruby 4.0.5 and many engines. Packs add autoload paths: if it appears, apply the Ruby fallback.

## Tasks & Acceptance

**Execution:**
- [ ] `.tool-versions` -- pin `ruby 4.0.7` and `nodejs 24.15.0`; run `asdf plugin update ruby`, install that Ruby, then `gem install rails -v 8.1.4` -- one toolchain for every session
- [ ] repository root -- run `rails new . --name=gameble --database=postgresql --skip-javascript` with Rails 8.1.4 -- the application skeleton
- [ ] `Gemfile` -- add `vite_rails` (`~> 3.11.1`) and `packs-rails` (`~> 0.1.0`) -- bundling and packs
- [ ] `vite.config.ts`, `config/vite.json`, `app/frontend/entrypoints/application.js`, `package.json` -- run `bundle exec vite install` -- Vite serves the page's assets
- [ ] `packs/catalog/package.yml`, `packs/steam/package.yml`, `packs/accounts/package.yml`, `packs/game/package.yml` -- create the four empty packs, each with `app/models/.keep` -- AD-1
- [ ] `compose.yaml` -- PostgreSQL 18 for development and test, published on port 5433 -- a local database that does not collide with port 5432
- [ ] `config/database.yml` -- development and test read `DB_HOST` (default `localhost`), `DB_PORT` (`5433`), `DB_USER` and `DB_PASSWORD` (both `postgres`), matching `compose.yaml` -- runs with no manual setup
- [ ] `bin/setup` -- run `npm install` after `bundle install` -- tests and Vite need `node_modules`
- [ ] `bin/dev` -- run `Procfile.dev` (Rails server and Vite dev server) through foreman, installing it if missing -- live reload in development
- [ ] `app/frontend/entrypoints/application.css`, `app/views/layouts/application.html.erb` -- add a Vite stylesheet entrypoint with `vite_stylesheet_tag`, and remove the Propshaft `stylesheet_link_tag` -- one home for CSS
- [ ] `config/routes.rb`, `app/controllers/pages_controller.rb`, `app/views/pages/home.html.erb` -- root route to a placeholder page -- the tracer's visible end
- [ ] `test/controllers/pages_controller_test.rb`, `test/packs_test.rb` -- test the tested rows of the I/O matrix, and that `Packs.all` names `packs/catalog`, `packs/steam`, `packs/accounts`, `packs/game` -- proof the skeleton holds
- [ ] `README.md` -- local setup, run and test in a few lines -- the next session starts without guessing

**Acceptance Criteria:**
- Given a clone with the pinned Ruby and Node and `docker compose up -d`, when `bin/setup --skip-server` then `bin/rails test` run, then every test passes.
- Given the booted application, when its packs are listed, then `packs/catalog`, `packs/steam`, `packs/accounts` and `packs/game` are present, and `bin/rails zeitwerk:check` passes.
- Given `bin/dev` running, when a browser opens the root URL, then the placeholder page shows with its assets served by the Vite dev server.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `docker compose up -d` -- expected: PostgreSQL 18 healthy on port 5433
- `bin/rails test` -- expected: all green
- `bin/rails zeitwerk:check` -- expected: "All is good!"
- `bin/vite build` -- expected: the build completes without error

**Manual checks (if no CLI):**
- Run `bin/dev` and open the root URL: the placeholder page shows.
