---
title: 'Contract migrations owed by the import rework and the dust tier'
type: 'chore'
ticket: '34'
created: '2026-10-14'
status: 'built'
baseline_revision: '8c4b180b641af7a2655865b9b5b6a7a91a3e06df'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The import rework left columns that no code reads, ignored by the models until a contract step drops them: `steam_apps` genres, credit, app_details, genres_run_id (with its foreign key to the import runs) and genres_exclusion (with its check), and `catalog_cards` credit; `Catalog::CardSeason` still ignores `dust_tier`, already dropped.

**Approach:** One migration drops those columns, the foreign key and the check; the models stop ignoring them and `dust_tier`; `db/schema.rb` is regenerated. The deployed code already ignores the columns, so the old container keeps working while the new one migrates. `catalog_cards.genres` stays: it is the cards' themes.

</frozen-after-approval>

## Verification

**Commands:**
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` -- expected: `db/schema.rb` loses exactly those columns, the foreign key and the check
- `bin/ci` -- expected: green, including the import and publication tests and the schema round trip

**Manual checks (if no CLI):**
- Staging migrates on deploy (author).

## Implementation Notes

Oneshot: one migration, three model lines, one test assertion that read `catalog_cards.credit` by SQL.

- `db/migrate/20261014120000_remove_columns_left_by_the_import_rework.rb`: reversible; the column types and the check's expression match the migrations that added them.
- `db/schema.rb` regenerated on Postgres 18 (`RAILS_ENV=test bin/rails db:drop db:create db:migrate`); rollback and migrate again leave it unchanged; the CI round trip passes once the schema is staged, since it diffs against git.

## Review Triage Log

### Pass 1 (quick, 2026-10-14) — high 0, medium 0, low 1, false 0, maybe-false 0

- `low` patch — `test/packs/catalog/schema_test.rb` said the model ignores `dust_tier`, false once the ignore is gone; the comment now gives the real reason (SQL string writes, column information reset), and the test name lost its planning id.
