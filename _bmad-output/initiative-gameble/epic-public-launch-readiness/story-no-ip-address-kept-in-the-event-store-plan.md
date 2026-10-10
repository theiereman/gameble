---
title: 'No IP address kept in the event store'
type: 'bugfix'
ticket: '23'
created: '2026-10-09'
status: done
baseline_revision: '1cf0684aebee0452c121667358a547eb86645888'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** `RailsEventStore::JSONClient` keeps its default `request_metadata` (rails_event_store 3.2.0, `RailsEventStore::Client#default_request_metadata`), so its Railtie middleware merges `{ remote_ip:, request_id: }` into the metadata of every event published during a request. Events live in streams named after the player and an account deletion leaves them, so the IP is personal data kept forever and undisclosed.

**Approach:** Build the client in `config/initializers/event_store.rb` with `request_metadata: ->(env) { { request_id: ActionDispatch::Request.new(env).uuid } }`, and add a batched data migration that strips `remote_ip` from every stored event's `metadata` (jsonb): the top-level key and its type entry `types.metadata.remote_ip` written by the JSON client's `PreserveTypes`; every other key, the event data and the event rows stay unchanged. The migration's `down` is a no-op.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [ ] `config/initializers/event_store.rb` -- pass the request-id-only `request_metadata` to `RailsEventStore::JSONClient.new` -- the gem default adds the client IP
- [ ] `db/migrate/20261009150000_strip_remote_ip_from_event_store_metadata.rb` -- `disable_ddl_transaction!`; walk `event_store_events` by primary-key ranges of 10,000 up to `max(id)`, each range one autocommitted `UPDATE ... SET metadata = (metadata - 'remote_ip') #- '{types,metadata,remote_ip}' WHERE id range AND metadata ? 'remote_ip'` under `safety_assured`; `down` does nothing -- row locks only per batch, no table lock, linear in table size via the primary key
- [ ] `test/integration/event_store_metadata_test.rb` -- a first sign-in from a given `REMOTE_ADDR` publishes `Accounts::PlayerRegistered` whose metadata holds the response's `X-Request-Id` and whose stored jsonb holds neither `remote_ip` nor the IP; the migration on a stored event with `remote_ip` (old-style metadata written by a client with the gem default) removes it and its type entry and keeps the rest and the data; on one without, leaves the row identical; the migrated event still reads back through the event store
- [ ] `db/schema.rb` -- regenerated: only the schema version changes

**Acceptance Criteria:**
- Given a request that publishes an event, when it is stored, then its metadata carries the request id and no `remote_ip`.
- Given stored events with and without `remote_ip`, when the migration runs, then no stored metadata holds `remote_ip` and every other key, the data and the rows are unchanged.

## Implementation Notes

Oneshot: one initializer argument, one data migration, one test file; well under 100 lines.

- The JSON client's `PreserveTypes` writes each metadata key's type under `metadata.types.metadata`, so a stored event carries `remote_ip` twice (value and type entry); the migration removes both. `restore_type` walks the stored keys, not the type entries, so migrated events read back unchanged.
- `RubyEventStore::ActiveRecord::Event` is a private constant: the test reads `event_store_events` rows through SQL.
- The request test fails against the previous initializer (checked by restoring it): the stored metadata held `remote_ip`.
- Files: `config/initializers/event_store.rb`, `db/migrate/20261009150000_strip_remote_ip_from_event_store_metadata.rb`, `test/integration/event_store_metadata_test.rb`, `db/schema.rb` (version only).

## Plan Change Log

## Review Triage Log

### 2026-10-09 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` During a Kamal deploy the old container keeps serving while the new one runs the migration, so an event the old code writes after `max(id)` is read, or commits into an already cleaned range, keeps `remote_ip` — real, but production has never been deployed (its first deploy has no old container), and on staging the window is the seconds of one boot; the fix is a second strip in a later deploy, more than a direct correction. Recorded as a residual risk.

## Verification

**Commands:**
- `bin/rails test test/integration/event_store_metadata_test.rb` -- expected: green
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bin/ci` strong_migrations step -- expected: green
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate db:schema:dump` then diff `db/schema.rb` -- expected: version line only

## Auto Run Result

- **Summary:** the event store records the request id only; a batched data migration strips `remote_ip` (value and type entry) from the metadata of stored events and leaves everything else as it was.
- **Files changed:**
  - `config/initializers/event_store.rb` -- `JSONClient` built with a request-id-only `request_metadata`
  - `db/migrate/20261009150000_strip_remote_ip_from_event_store_metadata.rb` -- data migration, outside a DDL transaction, primary-key ranges of 10,000 rows each committed alone, only rows holding `remote_ip` updated; `down` is a no-op
  - `test/integration/event_store_metadata_test.rb` -- request metadata, migration with and without `remote_ip`, read-back
  - `db/schema.rb` -- version only
- **Review:** quick lens, 1 finding: 0 patched, 0 deferred, 1 rejected (low, the deploy-window race above).
- **Follow-up review recommended:** false (no patched entry).
- **Verification:** `bin/rails test` 2062 runs, 0 failures; `bin/rails test:system` 171 runs, 0 failures; `npm run test:js` 210 tests passed; `bin/rails zeitwerk:check`, `bundle exec packwerk validate` and `check`, `bin/rubocop`, `bin/brakeman` clean; schema rebuilt from migrations under strong_migrations, diff is the version line only.
- **Residual risk:** on a database already serving the old code (staging), events written by the old container during the deploy that runs the migration keep `remote_ip`; running the same strip once more after that deploy closes it.

