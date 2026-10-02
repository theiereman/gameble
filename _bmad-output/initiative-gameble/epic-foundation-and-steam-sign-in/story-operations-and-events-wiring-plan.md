---
title: 'Operations and events wiring'
type: 'feature'
ticket: '3'
created: '2026-10-02'
status: 'built'
baseline_revision: '2fa766dd07efe1024feb08f3e6f13813f75c6e6c'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** AD-3 and AD-10 require every state change to be a `dry-operation` in one transaction that publishes a Rails Event Store event in that same transaction, with failure codes mapped to locale keys. None of this exists, so no pack can write its first operation.

**Approach:** Add `dry-operation` and Rails Event Store, an `ApplicationOperation` base class that every operation inherits, the event store tables and client, and the `errors.<pack>.<code>` lookup. Prove it with one sample operation, defined in the test, that commits its row and its event together and rolls both back on a `Failure`.

## Boundaries & Constraints

**Always:**
- Gem versions from the Stack table: `dry-operation ~> 1.1.0`, `rails_event_store ~> 3.2.0`.
- Operations return `Success(value)` or `Failure(:symbol_code)`. A failure code's message is the locale key `errors.<pack>.<code>`, where `<pack>` is the underscored first segment of the operation's class name (`Game::OpenPack` → `errors.game.<code>`).
- Events are published through the operation base class, inside the operation's transaction, and carry identifiers only (AD-10).
- Shared infrastructure classes that packs inherit live in a new Packwerk package `lib` (folder `lib/`), which depends on no package. The root package and each of the four packs declare `lib` as a dependency. No pack depends on the root package (AD-2).
- Every new migration passes strong_migrations, and the committed `db/schema.rb` matches the migrations (the CI drift check of story 1.2).
- All code, comments and test names in English.

**Never:**
- No domain model, domain operation, domain event or handler in any pack: the sample operation, its event and its table exist only inside the test.
- No event handler subscriptions, no async dispatch configuration beyond the client's defaults, no RES browser route.
- Do not move `ApplicationRecord` or `ApplicationJob`; that waits for the first pack model.
- No change to CI workflow files.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Success | sample operation called with valid input | returns `Success`; its row exists and its event is in the event store, linked to the expected stream | No error expected |
| Failure after writing | sample operation writes its row, publishes its event, then a later step returns `Failure(:rejected)` | returns `Failure(:rejected)`; neither the row nor the event exists | Transaction rolled back |
| Failure message | `failure_key(:rejected)` on an operation named `Sample::CreateWidget` | `"errors.sample.rejected"`; `failure_message(:rejected)` returns that key's translation in the current locale | No error expected |

</intent-contract>

## Code Map

- `Gemfile` -- add both gems at runtime, after `strong_migrations`, with a one-line comment and link like the neighbouring entries.
- `lib/` -- autoloaded through `config.autoload_lib(ignore: %w[assets tasks])` in `config/application.rb`, so `lib/application_operation.rb` defines `ApplicationOperation`. Today it holds only `assets/` and `tasks/`.
- `package.yml` (root), `packs/{accounts,catalog,game,steam}/package.yml` -- Packwerk packages from story 1.2, each with `enforce_dependencies: true` and a one-line comment; add `lib` to each `dependencies` list, keeping the AD-2 arrows.
- `config/i18n-tasks.yml` -- `en` only; dynamic `errors.*` keys are not detected by i18n-tasks, which is expected.
- `config/locales/en.yml` -- generated file with an unused `hello` key; leave it.
- `config/initializers/strong_migrations.rb` -- checks every migration after `start_after = 20261002133244`.
- `db/schema.rb` -- committed empty schema (version 0); regenerate it with `bin/rails db:migrate`.
- `test/test_helper.rb` -- transactional tests are on; Rails opens the test transaction as non-joinable, so the operation's own `transaction` becomes a savepoint and its rollback is observable inside a test.
- dry-operation 1.1.0 -- `include Dry::Operation::Extensions::ActiveRecord` gives `transaction do ... end`; a `Failure` from a step inside the block raises `ActiveRecord::Rollback` and halts the flow. Its `requires_new` option is documented as unsupported: do not use it.
- rails_event_store 3.2.0 -- `RailsEventStore::JSONClient` pairs with a `jsonb` migration from `bin/rails generate ruby_event_store:active_record:migration --data-type=jsonb`. Its default dispatcher runs synchronous handlers inside the publishing transaction (AD-10).

## Tasks & Acceptance

**Execution:**
- [x] `Gemfile`, `Gemfile.lock` -- add `dry-operation` and `rails_event_store` -- Stack table
- [x] `db/migrate/*_create_event_store_events.rb`, `db/schema.rb` -- generate the RES migration with `--data-type=jsonb`, run it, commit the schema -- event tables
- [x] `config/initializers/event_store.rb` -- set `Rails.configuration.event_store` to a `RailsEventStore::JSONClient` in a `to_prepare` block -- one client for the app
- [x] `lib/package.yml` -- new package `lib`, `enforce_dependencies: true`, no dependencies, with a comment saying it holds shared infrastructure base classes -- packs may inherit them without depending on the web layer
- [x] `package.yml`, `packs/*/package.yml` -- add `lib` to dependencies -- AD-2 still holds
- [x] `lib/application_operation.rb` -- `ApplicationOperation < Dry::Operation` including the ActiveRecord extension; `publish(event, stream_name:)` returning `Success(event)`; class methods `failure_key(code)` and `failure_message(code)` -- AD-3, AD-10 and the Failures convention
- [x] `test/lib/application_operation_test.rb` -- define the sample operation, its event and a temporary table inside the test, and cover every matrix row -- proof of the wiring
- [x] `README.md` -- one short paragraph on writing an operation: inherit `ApplicationOperation`, wrap writes and `publish` in `transaction`, return `Failure(:code)` with a key under `errors.<pack>` -- the next story starts without guessing

**Acceptance Criteria:**
- Given the application, when `bin/rails test` runs, then the operation tests pass with the rest of the suite.
- Given the packages, when `bundle exec packwerk validate && bundle exec packwerk check` runs, then it reports no offense.
- Given a fresh test database, when `bin/rails db:drop db:create db:migrate` runs, then strong_migrations raises nothing and `git diff --exit-code -- db/schema.rb` passes.

## Implementation Notes

- The sample event inherits `RubyEventStore::Event`: rails_event_store 3.2.0 no longer defines `RailsEventStore::Event`.
- The generated RES migration was autocorrected by RuboCop (spaces inside array brackets); the schema is unchanged.
- The failure-message test swaps in a fresh `I18n::Backend::Simple` and restores the original in `ensure`.

## Plan Change Log

## Review Triage Log

### 2026-10-02 — Review pass
- verdicts: 4 findings — high 0, medium 2, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` A nested operation's Failure handled without `step` keeps its rows and event, since its `transaction` joins the outer one and the `ActiveRecord::Rollback` is swallowed — the base class comment and the README now require calling another operation only through `step`, which halts the outer flow and rolls back the whole transaction.
  - `[low]` `[reject]` `publish` does not check that a transaction is open — the rule is documented on the method and in the README; a guard that also works under the non-joinable test transaction adds complexity for a mistake review will catch.
  - `[medium]` `[patch]` `failure_message` on a missing `errors.<pack>.<code>` key returns a placeholder and i18n-tasks cannot see dynamic keys — `raise_on_missing_translations` is on in test and development, and a test shows a missing key raises `I18n::MissingTranslationData`.
  - `[low]` `[reject]` `failure_key` breaks on an anonymous or non-namespaced class — operations are named `Pack::VerbNoun` by convention, and a guard adds code for a case nobody writes.

## Design Notes

The sample lives in the test so no throwaway code or table reaches a pack. The test creates its table with `ActiveRecord::Base.connection.create_table` in `setup` (PostgreSQL DDL is transactional, so the fixture transaction removes it) and an anonymous or test-local model for it. Its `call` wraps the insert, the publish and an optional failing step in `transaction`:

```ruby
def call(name:, reject: false)
  transaction do
    widget = step create_widget(name)
    step publish(Sample::WidgetCreated.new(data: { widget_id: widget.id }), stream_name: "Sample::Widget$#{widget.id}")
    step reject ? Failure(:rejected) : Success(widget)
  end
end
```

The failure test stores a translation for `errors.sample.rejected` with `I18n.backend.store_translations` and restores the backend afterwards.

## Verification

**Commands:**
- `bin/rails test` -- expected: all green, including the operation tests
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate && git diff --exit-code -- db/schema.rb` -- expected: succeeds with no diff after the schema is committed
- `bundle exec packwerk validate && bundle exec packwerk check` -- expected: no offenses
- `bundle exec i18n-tasks missing` -- expected: none missing
- `bin/rubocop` -- expected: no offenses
- `bin/rails zeitwerk:check` -- expected: all is good

## Auto Run Result

**Summary:** `ApplicationOperation` (dry-operation with the ActiveRecord transaction extension, `publish` to Rails Event Store, `failure_key` / `failure_message` for `errors.<pack>.<code>`) lives in a new Packwerk package `lib` that every pack and the web layer depend on. Rails Event Store is configured with a JSON client over `jsonb` tables. A sample operation in the test proves the row and its event commit together and roll back together on a Failure.

**Files changed:**
- `Gemfile`, `Gemfile.lock` -- dry-operation 1.1.0, rails_event_store 3.2.0
- `db/migrate/20261002154022_create_event_store_events.rb`, `db/schema.rb` -- event store tables (jsonb)
- `config/initializers/event_store.rb` -- the app's event store client
- `lib/package.yml`, `package.yml`, `packs/*/package.yml` -- new `lib` package, depended on by all
- `lib/application_operation.rb` -- operation base class
- `config/environments/{test,development}.rb` -- raise on missing translations
- `test/lib/application_operation_test.rb` -- sample operation and matrix tests
- `README.md` -- how to write an operation

**Review findings:** 2 patches applied (2 medium); 0 deferred; 2 rejected (`publish` transaction guard, `failure_key` on unnamed classes — both low, fixes add guards for unlikely mistakes).

**Follow-up review recommended:** true — two medium patches were applied. The open risk is that the nested-operation rule is only documented: an operation that handles another operation's Failure without `step` would still commit the inner rows, and no test can catch it under the non-joinable test transaction.

**Verification:** `bin/rails test` (9 runs, 0 failures), `db:drop db:create db:migrate` (no strong_migrations error, schema unchanged), `packwerk validate` and `check` (clean), `i18n-tasks missing` (none), `bin/rubocop` (clean), `zeitwerk:check` (all is good).

**Residual risks:** `raise_on_missing_translations` now applies to every `I18n.t` call in test and development. `ruby_event_store-browser` comes in as a dependency but is not mounted.
