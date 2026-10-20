<!-- bmad:context -->
<!-- Verified 2026-10-07 against 3d62a7c. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## gameble

A free web trading card game where every card is a Steam game. Rails 8 with domain code in packwerk packs (`packs/accounts`, `catalog`, `game`, `steam`), Hotwire with TypeScript Stimulus controllers and one React island, Postgres 18. Planning lives in `_bmad-output/initiative-gameble/`: the spec, the architecture (`architecture-gameble/architecture-gameble.md`, which holds the reasons behind the rules below) and the UX (`ux-gameble/`).

## Policy

- Never write planning ids in code, tests, config or migrations: no AD-n, CAP-n, R-n, story n.n, epic n, DESIGN.md or EXPERIENCE.md. A reader of the code does not have those documents.
- Write code that reads without comments: carry intent in names, extracted methods and objects. Comment only an external constraint the code cannot state (a Steam API limit, a browser bug), in one line.
- Write all repo text in English, whatever language the conversation is in; French belongs only in `config/locales/fr.yml`.
- Work on `develop` or a branch cut from it; never push or merge to `main`, which is the author's production release.
- Before starting any work, run `git fetch origin` and bring local `develop` level with `origin/develop`. Other sessions, local and cloud, change it, and the ticket you are about to build may already be built. If local `develop` has diverged from `origin/develop`, stop and reconcile before building.
- Unless the session works for the author (GitHub user `theiereman`), work on a branch cut from `develop` and finish by opening a pull request to `develop`; never push to `develop`. The author reviews and merges.
- Never commit `config/*.key`.
- Never hand-edit `app/frontend/images/pixel/`; run `node script/pixel_art/export.mjs` (`--check` verifies).
- Never edit a plan's `<frozen-after-approval>` block or settle an entry in `pending-approvals.md`; only the author does.

## Rules that break other files

- Write only through an operation (`ApplicationOperation`, named `Pack::VerbNoun`, returning `Success` or `Failure(:code)`); controllers, jobs, handlers and components never write a model, and read through the pack's queries.
- An operation publishes one event inside its transaction; handlers run in that transaction and never publish.
- A GET never writes: GET actions run on the reading role with writes prevented (`ApplicationController`); put the write behind a POST or a job.
- Jobs are enqueued only after commit; broadcasts go through a job, never inside a transaction.
- Never expose database ids in URLs, HTML, JSON, DOM ids or stream names; use tokens.
- Give every controller action a Pundit policy.
- Put every string in both `en.yml` and `fr.yml`; the locale is the first URL segment. `i18n-tasks` cannot see dynamic `errors.<pack>.<code>` keys, so add both by hand.
- Pack dependencies follow the architecture diagram (Game → Catalog, Accounts; Steam → Catalog; no pack → web layer); `bundle exec packwerk check` fails otherwise.
- Islands talk only through the `gameble:*` events declared in `app/frontend/lib/events.ts`; server HTML carries no `style` attribute.
- Make schema changes expand/contract (strong_migrations): a concurrent index in its own migration, a check added then validated in a second one.

## Running and verifying

- Start Postgres with `docker compose up -d`; it listens on 5433, not 5432.
- Run `npm install` before `bin/rails test`: the Ruby suite builds the Vite assets first and aborts without them.
- System tests are disabled, in CI and as a check of your work, until they are rebuilt to be stable: `bin/rails test` skips them, do not run `bin/rails test:system` to verify a change. A change that breaks a system test is not blocked by it.
- `bin/ci` skips vitest, `zeitwerk:check` and system tests; run `npm run test:js` and `bin/rails zeitwerk:check` as well.
- Run packwerk as `bundle exec packwerk check`; there is no binstub.
- After a migration, regenerate `db/schema.rb` from the migrations as CI does, on Postgres 18: `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb`, then commit the diff. A plain `db:migrate` on an empty database loads the existing `db/schema.rb` instead of running the migrations. Never hand-edit or hand-merge it; CI fails on any drift.

## Known pitfalls

- In system tests, assert timing-dependent state with retrying Capybara matchers, never a one-shot read, and restore anything a test changes globally (window size); four flaky-test fixes came from this.
- French plural keys need a `zero` form.
- Never name a model in a test class body (a constant such as `TABLES = [ Game::Pack ]`): it loads `ApplicationRecord` before the parallel workers fork, a worker's GET then writes unprevented, and `ReadOnlyRequestsTest` fails only in the full parallel run. Name models inside methods.

<!-- /bmad:context -->

## Tickets live on GitHub

Tickets and their state live on GitHub: one issue per epic and ticket, one milestone per release, and the board https://github.com/users/theiereman/projects/1, whose Status column decides a ticket's state. The files under `_bmad-output/initiative-gameble/` are the agents' working copy, kept in step by `script/github_board/sync.py` (gh CLI, main checkout only; without `--apply` it is a dry run).

- Run `python3 script/github_board/sync.py --apply` before choosing a ticket, and again after every build, ticket change, or commit of a plan; then pick from `tickets.py next --synced`.
- Change a ticket's state with `python3 script/github_board/sync.py set <ref> <state> --apply` (backlog, in-progress, review, done, dropped); `tickets.py mark` is refused on this store.
- Give a new epic a `release` (its milestone, e.g. `0.3.0`) in `tickets.toml` before the sync; the sync stops without one.
- Issues opened on GitHub arrive with the `triage` label; only the author triages them (a milestone to accept, a close to refuse), and the sync drops the label. Turn an accepted one into a ticket with `python3 script/github_board/sync.py import <issue> <epic-slug> --apply` when the author names its epic; the request stays the requester's issue and closes when its ticket is done.
- Commit the files the sync lists as `local <path>`, by exact path, with the work that changed them.
