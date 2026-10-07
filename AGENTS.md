<!-- bmad:context -->
<!-- Verified 2026-10-07 against 3d62a7c. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## gameble

A free web trading card game where every card is a Steam game. Rails 8 with domain code in packwerk packs (`packs/accounts`, `catalog`, `game`, `steam`), Hotwire with TypeScript Stimulus controllers and one React island, Postgres 18. Planning lives in `_bmad-output/initiative-gameble/`: the spec, the architecture (`architecture-gameble/architecture-gameble.md`, which holds the reasons behind the rules below) and the UX (`ux-gameble/`).

## Policy

- Never write planning ids in code, tests, config or migrations: no AD-n, CAP-n, R-n, story n.n, epic n, DESIGN.md or EXPERIENCE.md. A reader of the code does not have those documents.
- Write code that reads without comments: carry intent in names, extracted methods and objects. Comment only an external constraint the code cannot state (a Steam API limit, a browser bug), in one line.
- Write all repo text in English, whatever language the conversation is in; French belongs only in `config/locales/fr.yml`.
- Work on `develop` or a branch cut from it; never push or merge to `main`, which is the author's production release.
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
- `bin/rails test` skips system tests; also run `bin/rails test:system` for what you touched (headless Chrome; `CHROME_BIN` points at Chromium). CI runs no system tests on a push to `develop`.
- `bin/ci` skips vitest, `zeitwerk:check` and system tests; run `npm run test:js` and `bin/rails zeitwerk:check` as well.
- Run packwerk as `bundle exec packwerk check`; there is no binstub.
- After a migration, regenerate `db/schema.rb` with `RAILS_ENV=test bin/rails db:drop db:create db:migrate` on Postgres 18 and commit the diff; never hand-edit or hand-merge it, CI fails on any drift.

## Known pitfalls

- In system tests, assert timing-dependent state with retrying Capybara matchers, never a one-shot read, and restore anything a test changes globally (window size); four flaky-test fixes came from this.
- French plural keys need a `zero` form.

<!-- /bmad:context -->
