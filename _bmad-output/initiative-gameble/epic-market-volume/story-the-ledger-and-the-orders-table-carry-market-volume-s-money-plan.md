---
title: "The ledger and the orders table carry market volume's money"
type: 'feature'
ticket: '1'
created: '2026-11-20'
status: 'built'
baseline_revision: '392e76600b0e8b71c66729156a27a3323e2ffb7e'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred:
  - summary: >-
      order_duration_days is in SettingsRules::EDITABLE but in neither MarketSettingsForm::MOMENTS nor SINGLE_GROUPS, so hint or moment for it raises NoMethodError once the field is drawn.
    evidence: |-
      MarketSettingsForm#moment ends in MOMENTS.find { ... }.last, which is nil.last for this field. Nothing draws the field today; the story that adds the back-office field must add its group, moment and label keys in both locales.
    location: >-
      app/models/back_office/market_settings_form.rb
    severity: low
  - summary: >-
      Order.reaching(rarity) is an SQL scope over saved orders; a caller that needs one order's rarities, or a price checked before insert, must not write a second comparison of minimums.
    evidence: |-
      Unverified. PlaceOrder refuses a price reaching no rarity, and the wanted refresh and MES ORDRES need an order's reached rarities. Settle it in the order-placing story: insert and check through the scope inside the transaction, or add one query that selects every rarity's reach from the same SQL expression.
    location: >-
      app/domains/game/app/models/game/market/order.rb
    severity: medium (unverified)
  - summary: >-
      Nothing in the schema ties served_card_season_id to the order's card_id, so a served copy of another game would be accepted by the database.
    evidence: |-
      Unverified. The serving operation draws its order through the eligibility query on the edition's game, which is where the guard belongs; check that SellToOrder and ApplyWantedChoices assert it when they are built.
    location: >-
      db/migrate/20261120184000_create_game_market_orders.rb
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** Every market-volume lane (orders, direct sales, Archive shop, slots, wanted table) needs one money contract first: a ledger that can point at a buy order and record the two purchase kinds as destroyed, an orders table with its invariants, the order formulas, the order duration setting and the event classes with their data keys.

**Approach:** Expand-only migrations (each concurrent index in its own migration, FKs and checks `NOT VALID` then validated), a `Game::Market::Order` model owning `open_at(now)` and `reaching(rarity)`, one `LedgerEntry::DESTROYED_KINDS` read by the reconciliation, `DailyFigures` and so the snapshot, `order_duration_days` (default 7, range in `SettingsRules`), and the declared event classes. No operation writes an order yet.

## Boundaries & Constraints

**Always:** strong_migrations expand/contract; check expressions written so `db/schema.rb` round-trips (regex `~ '^(a|b)$'` for kinds/statuses, equalities, never `IN`); regenerate `db/schema.rb` from migrations on PG18; both locales for every changed string; no planning ids in code.

**Never:** no operation, controller, view, job or handler for orders (stories 2+); no Archive/slot price columns or back-office field (story 3); no capacity or alt-signal/tied-account code (stories 4, 5, built in parallel); no change to `Mint.credit`; no event subscriptions.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Entry with listing and order | insert with both ids | refused | `ActiveRecord::StatementInvalid` (check) |
| Second hold of one order | two `hold` rows, same order and player | second refused | `RecordNotUnique` |
| Purchase kinds | `Ledger.post` `archive_purchase`/`slot_purchase`, and `hold` with `order_id` | wallet moves, entries kept | none |
| Destroyed totals | mint, archive_purchase, slot_purchase | reconciliation balanced, destroyed counts both; `DailyFigures.destroyed` too | none |
| Second open order | same player and card, both `open` | refused; a new open after the first is cancelled passes | `RecordNotUnique` |
| Served columns | `served` without seller, or seller while `open` | refused | check violation |
| Open scope | `expires_at == now` or past | not in `open_at(now)` | none |
| Reaching | order on version v1, current v2 raises minimum above price | still reaches per v1 | unknown rarity raises `ArgumentError` |

</intent-contract>

## Code Map

- `db/migrate/20261110090000_create_game_market_tables.rb`, `20261110120000_create_game_market_listings.rb`, `20261110120001…05`, `20261118100000/100100` -- patterns: create table + inline token index, separate concurrent index migrations (`disable_ddl_transaction!`), FK `validate: false` then `validate_foreign_key`, check `validate: false` then `validate_check_constraint`; ledger kind check is `kind ~ '^(...)$'`, name `game_market_ledger_entries_kind_check`.
- `app/domains/game/app/models/game/market/ledger.rb` -- `Ledger::Entry` Data: add `order_id` (default nil); `insert_all!` takes `entry.to_h`.
- `app/domains/game/app/models/game/market/ledger_entry.rb` -- `KINDS` gains both purchases; add `DESTROYED_KINDS`.
- `app/domains/game/app/queries/game/market/daily_figures.rb` -- drop `DESTROYING_KINDS`, read `LedgerEntry::DESTROYED_KINDS`.
- `app/domains/game/app/queries/game/market/reconcile_wallets.rb` -- `TOTALS` literal `kind IN (...)` built from `DESTROYED_KINDS`.
- `app/domains/game/app/models/game/market/listing.rb` -- model shape to mirror (`has_secure_token :token, length: 24`, `STATUSES`).
- `app/domains/game/app/models/game/market/settings_rules.rb` -- `RANGES` gains `order_duration_days: 1..30` (thus `EDITABLE`/`REQUIRED`).
- `app/models/back_office/market_settings_form.rb` `from_params` -- today every `EDITABLE` field absent from params becomes nil (refused); keep an unsubmitted field at the version's value so the existing form (no order duration field until story 3) still saves.
- `app/domains/game/app/events/game/market/*.rb` -- event style: `class X < RubyEventStore::Event`, optional `def self.about(record) = new(data: {...})`.
- `Catalog::Rarity::TIERS` / `SettingsRules::RARITIES` -- rarity names (`common`…`legendary`); `Settings#minimum_price(rarity)`.
- `test/support/market.rb` `forget_market!` -- deletes entries, wallets, settings; orders must go between entries and settings.
- Locales: `charts.reactor.words.series.destroyed` (fr 3818, en 1595) -> "Détruits (timbres, efforts et achats à la Confrérie)" / "Destroyed (stamps, efforts and purchases from the Brotherhood)"; health page `destroyed_share.what` (fr ~864, en ~532) names Brotherhood purchases.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/20261120184000_create_game_market_orders.rb` -- table: token (unique, inline), player/card(`catalog_cards`)/settings FKs, `price bigint > 0`, status regex check (open served expired cancelled withdrawn, default open), `expires_at`, seller/served_card_season FKs, `served_at`, `average_after_sale bigint`, timestamps; check: the four served columns all null or all set, and set exactly when `status = 'served'`.
- [ ] `db/migrate/20261120184001…04` -- concurrent partial indexes, one per migration: unique `(player_id, card_id) WHERE status='open'`; `expires_at WHERE open`; `(card_id, price DESC, created_at, id) WHERE open`; `(served_card_season_id, served_at) WHERE status='served'`.
- [ ] `db/migrate/20261120184005_add_order_and_purchase_kinds_to_game_market_ledger_entries.rb` -- `order_id bigint`, FK to orders `validate: false`, check `listing_id IS NULL OR order_id IS NULL` `validate: false`, kind check replaced with the two purchase kinds `validate: false`.
- [ ] `db/migrate/20261120184006_validate_…` -- validate the FK and both checks.
- [ ] `db/migrate/20261120184007_…one_order_entry…` -- concurrent unique `(order_id, player_id, kind) WHERE order_id IS NOT NULL`.
- [ ] `db/migrate/20261120184008_add_order_duration_days_to_game_market_settings.rb` -- integer, null false, default 7.
- [ ] `db/schema.rb` -- regenerated from migrations.
- [ ] `app/domains/game/app/models/game/market/order.rb` -- `STATUSES`, token, `belongs_to :player`, `:settings`; `scope :open_at, ->(now)` (status open, `expires_at > now`); `scope :reaching, ->(rarity)` joining settings, `minimum_price_<rarity> <= price`, rarity checked against `SettingsRules::RARITIES`.
- [ ] Ledger files, `daily_figures.rb`, `reconcile_wallets.rb`, `settings_rules.rb`, `market_settings_form.rb` -- per Code Map.
- [ ] Events -- `Game::Market::OrderPlaced/OrderCancelled/OrderExpired/OrderWithdrawn` (`.about(order)`: order_id, player_id, card_id, amount), `OrderServed.about(order)` (order_id, buyer_id, seller_id, card_season_id, price), `WantedChoicesApplied.with(seller_id:, sales:, listing_ids:, entrusted:)` (sale keys order_id, buyer_id, card_season_id, price; entrusted keys card_season_id, quantity), `ArchivePurchased.with(player_id:, card_season_id:, price:)`, `Game::SlotBought.with(player_id:, kind:, goal_id: nil)`.
- [ ] Locales -- both files, per Code Map.
- [ ] Tests -- `test/domains/game/market/order_test.rb` (model/index/check/scopes), extend `ledger_test.rb`, `listing_test.rb` or a new ledger-order test, `reconcile_wallets_test.rb`, a `DailyFigures`/snapshot destroyed case, `settings_rules_test.rb` range, form test for an unsubmitted field, an events-data test; `test/support/market.rb` clears orders.

**Acceptance Criteria:**
- Given the migrations run on an empty PG18 database, when the schema is dumped, then it equals the committed `db/schema.rb`.
- Given the back-office settings form as rendered today (no order duration field), when an administrator saves a valid change, then it saves and `order_duration_days` carries over.
- Given ledger entries of every destroyed kind, when `ReconcileWallets` and `WriteDailySnapshot` run, then both count archive and slot purchases as destroyed and balance.

## Implementation Notes

- The implementing subagent was cut off by an API rate limit before it reported; the orchestrating session verified and finished the work.
- `safety_assured` on the four-column best-price index: strong_migrations refuses a non-unique index of more than three columns.
- The account-deletion test lists `game_market_orders` among the tables kept as market history, with the existing copy; naming buy orders in that copy belongs to the removal story.
- Local test runs used a private database (`DATABASE_URL=.../gameble_test_w46_1`): another session was running tests on `gameble_test` in this checkout, which produced deadlocks and duplicate keys unrelated to this change.

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 30 findings — high 0, medium 1, low 18, false 6, maybe-false 5
- findings:
  - `[false]` `[reject]` blind: StartingSettings lacks order_duration_days — the column default gives every new version 7; no version lacks it.
  - `[low]` `[defer]` blind: MarketSettingsForm#moment raises for order_duration_days — latent until the field is drawn, which the intent leaves to story 3; deferred so it adds the group, moment and labels.
  - `[low]` `[reject]` blind: from_params now keeps any omitted field — the drawn form always submits every text input; only a hand-crafted admin POST differs, and narrowing it adds a branch.
  - `[maybe-false]` `[defer]` blind: Order.reaching is only an SQL scope (N+1, no check before insert) — depends on how later stories read it; deferred with what settles it.
  - `[low]` `[reject]` blind: no seller_id index — the intent lists the order indexes exactly; the story that reads served orders by seller adds its own concurrently.
  - `[low]` `[reject]` blind: no seller_id <> player_id check — not among AD-58's checks; EligibleOrders excludes the seller's own orders by rule.
  - `[low]` `[patch]` blind: no test that a due but still open order blocks a new one — added to order_test.rb (absent from open_at, second order refused by the index).
  - `[low]` `[reject]` blind: SlotBought.with accepts any kind — its one publisher validates the kind; a guard adds surface no caller needs yet.
  - `[low]` `[patch]` blind: reconcile_wallets_job_test#clear does not delete orders before settings — added `Game::Market::Order.delete_all`.
  - `[false]` `[reject]` blind: package-lock.json modified — another session's change, not in this diff; the commit stages exact files.
  - `[false]` `[reject]` edge: unique index refuses while open_at says none — intended: a due order blocks a new one until the expiry job runs (AD-58); pinned by the new test.
  - `[maybe-false]` `[defer]` edge: served_card_season_id may name another card's season — the guard lives in the serving operation's eligibility read; deferred.
  - `[low]` `[reject]` edge: self-served order — same as the seller check above.
  - `[low]` `[reject]` edge: Entry with both ids fails at insert_all! — the transaction rolls back the wallet update; a programmer error refused by the database check.
  - `[low]` `[defer]` edge: moment crash for order_duration_days — same root as the deferred form item.
  - `[low]` `[reject]` edge: OrderServed.about on an unserved order — a programmer error in the one serving operation; a guard adds surface.
  - `[low]` `[reject]` edge: WantedChoicesApplied with string keys raises KeyError — its one caller builds symbol-keyed rows; a loud failure is correct.
  - `[low]` `[reject]` edge: rolling back the kind-check migration fails once purchase rows exist — expand migrations are not rolled back past data, as the repo's other check widenings.
  - `[low]` `[reject]` edge: from_params carry-over — same as the blind finding.
  - `[medium]` `[patch]` verification-gap: the ledger's order_id foreign key is pinned by no test — added "a ledger entry can only point at an existing order" to listing_test.rb.
  - `[low]` `[defer]` verification-gap: moment crash — same root as the deferred form item.
  - `[maybe-false]` `[defer]` intent: reaching cannot judge an unsaved order — same root as the deferred reaching item.
  - `[low]` `[reject]` intent: the open scope is named open_at, not open — `open` would shadow Kernel#open on the class; behaviour matches.
  - `[false]` `[reject]` intent: purchase kinds not posted with an order_id — Archive and slot purchases name no order (AD-41's kind table); the hold is posted with one.
  - `[low]` `[reject]` intent: both-ids refusal only at the database — same as the edge finding.
  - `[false]` `[reject]` intent: the Reactor intro sentence is unchanged — no such string exists in the locales; the legend is the line's label.
  - `[low]` `[reject]` intent: the Reactor surface is untested — it reads the snapshot's destroyed_total, which the snapshot test asserts.
  - `[maybe-false]` `[reject]` intent: from_params ripple — same as the blind finding.
  - `[false]` `[reject]` intent: schema round trip unverified — regenerated from the migrations on Postgres 18, identical to db/schema.rb.
  - `[maybe-false]` `[reject]` intent: event payloads not enforced on `new` — the builders are the declared handoff; the lanes publish through them.

## Design Notes

`Order.reaching(rarity)` is the only formula: later stories derive an order's rarities as `SettingsRules::RARITIES.select { Order.reaching(it).exists?(id:) }` or similar, never by re-comparing minimums. Order duration range 1..30 days is this story's choice (spec gives none).

## Verification

**Commands:**
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && diff tmp/migrated_schema.rb db/schema.rb` -- expected: no diff after copy
- `bin/rails test test/domains/game/market test/models/back_office test/controllers/back_office` -- expected: green
- `bin/rails test` (full non-system suite) -- expected: green
- `bin/ci`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: pass
- `bin/rails test test/system/<back-office market settings file>.rb` -- expected: green

## Auto Run Result

- **Summary:** the money contract for market volume: the ledger names a buy order (never with a listing) and takes the Archive and slot purchase kinds, both destroyed through `LedgerEntry::DESTROYED_KINDS`; `game_market_orders` with its checks and four concurrent indexes; `Game::Market::Order` with `open_at(now)` and `reaching(rarity)`; `order_duration_days` (default 7, range 1..30); the eight market-volume event classes with their data keys; the destroyed legend and health explanation in both locales.
- **Files:** nine migrations (`db/migrate/20261120184000` to `184008`) and the regenerated `db/schema.rb`; `order.rb`; `ledger.rb`, `ledger_entry.rb` (kinds, destroyed kinds); `daily_figures.rb`, `reconcile_wallets.rb` (read the constant); `settings_rules.rb` (range); `back_office/market_settings_form.rb` (an unsubmitted field keeps the version's value); eight event files; `en.yml`, `fr.yml`; tests: `order_test.rb`, `order_events_test.rb` and additions to ledger, listing, reconciliation, reconciliation job, snapshot, settings rules, settings form and controller, account deletion; `test/support/market.rb`.
- **Review:** 30 findings; patched 3 (1 medium, 2 low: the order foreign-key test, the due-order test, the job test cleanup); deferred 3 (form moment for the order duration, the reaching formula's shape for unsaved orders, served card-season tied to the order's card); every other finding rejected with its reason in the triage log.
- **Follow-up review:** false (no high patched, one medium patched).
- **Verification:** schema regenerated from the migrations on Postgres 18 is identical to `db/schema.rb`; `bin/rails test` 6198 runs green; market, game, back-office and account tests green after the patches (2368 runs); back-office market system tests green (4 runs); `bin/ci` green except Brakeman (exits 5 only because 8.1.1 is out) and the schema round trip (fails only on the uncommitted `db/schema.rb`; the dump equals the file); zeitwerk, packwerk, planning-id and file-size checks pass. `npm run test:js` not run: no frontend file changed.
- **Residual risks:** the deferred items; Brakeman's version check fails `bin/ci` until the gem is bumped.

