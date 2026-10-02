---
title: 'CI gates'
type: 'chore'
ticket: '2'
created: '2026-10-02'
status: done
baseline_revision: '68f23708f961db17eb65e75407b3b361a9466139'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The generated GitHub Actions workflow runs only Brakeman, bundler-audit, RuboCop and the tests, and its test job has no Node, so the Vite-backed page test fails there. Nothing enforces the pack dependency direction (AD-2), translations or migration safety (AD-21, AD-22).

**Approach:** Adapt `.github/workflows/ci.yml` so every pull request runs Minitest (with Node and `npm ci`), Packwerk, strong_migrations (by running the migrations from scratch), i18n-tasks and RuboCop, and fails on any of them. Configure Packwerk with the arrows of AD-2: root package (web layer) → all four packs; `game` → `catalog`, `accounts`; `steam` → `catalog`; `catalog` and `accounts` → none; no pack depends on the root package. Configure i18n-tasks to scan `app/` and `packs/` and read `config/locales`, with `en` as the only locale until story 1.4 adds `fr`. Pin the new gems from the Stack table.

</intent-contract>

## Implementation Notes

Oneshot: configuration and workflow only, well under 100 hand-written lines.

- Gems: `strong_migrations ~> 2.8.0` (runtime, as its initializer needs it), `packwerk ~> 3.3.1` and `i18n-tasks ~> 1.1.2` (development and test). Packwerk was already in the lockfile through packs-rails; it is now pinned directly.
- Packwerk: `packwerk init` created the root `package.yml` and `packwerk.yml`; the root package and every pack enforce dependencies with the AD-2 arrows. `_bmad` folders are excluded from the scan.
- strong_migrations: `start_after` is the generator's timestamp (no migration exists yet); `target_version = 18`. CI checks migrations by running them from scratch (`db:create db:migrate`) before the tests, since `db:test:prepare` loads the schema and would skip the check.
- i18n-tasks: reads `config/locales/**/*%{locale}.yml`, scans `app/` and `packs/`; `locales: [en]` until story 1.4 adds `fr`.
- CI: the lint job runs Packwerk and i18n-tasks after RuboCop; the test and system-test jobs set up Node from `.tool-versions` and run `npm ci`; PostgreSQL pinned to 18. `config/ci.rb` (local `bin/ci`) runs the same gates. Dependabot also watches npm.
- Negative checks run locally: a `Catalog` class referencing `Game::Probe` made `packwerk check` exit 1; `t("missing.key")` in a view made `i18n-tasks missing` exit 1; a migration removing a column stopped with "Dangerous operation detected #strong_migrations". All reverted.
- Running `db:migrate` with no migration dumps an empty `db/schema.rb`. After review it is committed, and the migration step fails when the dumped schema differs from the committed one.

## Plan Change Log

## Review Triage Log

### 2026-10-02 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The CI migration step dumps `db/schema.rb` and the tests then load that dump, so a committed schema that drifted from its migrations is never caught — the empty `db/schema.rb` is now committed and the step runs `git diff --exit-code -- db/schema.rb` after migrating.
  - `[low]` `[patch]` The local `bin/ci` migration step recreates an untracked `db/schema.rb` on every run — same fix: the schema is committed and the local step checks it for drift too.
  - `[low]` `[reject]` The migration check covers only the primary database, not queue, cache or cable — those are Solid gems' databases loaded from `db/*_schema.rb`, with no migrations in this app. Covering them needs extra test databases, which is more complexity than a gap nobody is likely to hit.

## Verification

**Commands:**
- `bin/rails test` -- expected: all green
- `bundle exec packwerk validate && bundle exec packwerk check` -- expected: no violations
- `bundle exec i18n-tasks missing` -- expected: no missing keys
- `bin/rubocop` -- expected: no offenses
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` -- expected: succeeds
- `ruby -ryaml -e 'YAML.load_file(".github/workflows/ci.yml")'` -- expected: valid YAML

**Manual checks (if no CLI):**
- Temporarily reference a `Game` constant from `packs/catalog`: `packwerk check` fails. Temporarily call `t("missing.key")` in a view: `i18n-tasks missing` fails. Temporarily add a migration that removes a column: `db:migrate` fails with a strong_migrations error. Revert each.

## Auto Run Result

**Summary:** CI now runs Minitest (with Node and `npm ci`), Packwerk, strong_migrations (migrations run from scratch, then a schema drift check), i18n-tasks and RuboCop on every pull request, alongside the generated Brakeman and bundler-audit jobs. Local `bin/ci` runs the same gates.

**Files changed:**
- `.github/workflows/ci.yml` -- Packwerk and i18n-tasks in the lint job; Node, `npm ci`, migration safety and schema drift check in the test job; Node in the system-test job; PostgreSQL 18
- `config/ci.rb` -- the same gates for local `bin/ci`
- `.github/dependabot.yml` -- watch npm too
- `Gemfile`, `Gemfile.lock` -- strong_migrations, packwerk, i18n-tasks
- `packwerk.yml`, `package.yml`, `packs/*/package.yml` -- AD-2 dependency direction, enforced
- `config/i18n-tasks.yml` -- `en` only until story 1.4; scans `app/` and `packs/`
- `config/initializers/strong_migrations.rb` -- generated; target PostgreSQL 18
- `db/schema.rb` -- the empty schema, committed so drift is detected

**Review findings:** 2 patches applied (1 medium, 1 low, same root cause); 0 deferred; 1 rejected (queue/cache/cable migrations: no migrations exist in those paths, and covering them needs extra test databases).

**Follow-up review recommended:** false — one medium patch, no high.

**Verification:** `bin/rails test` (4 runs, 0 failures), `packwerk validate` and `check` (no offenses), `i18n-tasks missing` (none), `bin/rubocop` (no offenses), Brakeman (no warnings), bundler-audit (no vulnerabilities), `db:drop db:create db:migrate` (succeeds), workflow YAML parses. Each gate was shown to fail on a temporary violation (pack boundary, missing key, column removal).

**Residual risks:** The workflow has not run on GitHub yet; the first pull request will show whether `ruby/setup-ruby` has Ruby 4.0.7 and whether `packwerk validate` boots without a database there.
