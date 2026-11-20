---
title: 'An administrator prices the Archive cards and the slots'
type: 'feature'
ticket: '3'
created: '2026-11-20'
status: 'built'
baseline_revision: 'ae21a36542b1522663c28af4746692cb72a736d6'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The settings version has no Archive prices nor slot prices, so the shop and the slot purchases (later stories) have nothing to read, and the back-office form cannot edit them nor the order duration (whose drawing would crash `MarketSettingsForm#moment` today).

**Approach:** Expand migrations add `archive_price_<rarity>` (nullable, checked against the rarity's minimum, `NOT VALID` then validated) and the slot prices with `market-economy.md`'s defaults; `Settings` answers `archive_price(rarity)` and `slot_price(kind, slot)`; `SettingsRules` bounds both families; the form draws the Archive row, the slot prices and the order duration; `EconomyAlerts` raises an Archive price a proposed minimum would pass.

## Boundaries & Constraints

**Always:** strong_migrations expand/contract; regenerate `db/schema.rb` from the migrations on PG18; every new string in `en.yml` and `fr.yml` (additive edits only: other lanes edit the same files); no planning ids in code; prices are settings values, never constants (defaults live only in the migration).

**Never:** no shop, purchase, `BuySlot`, `BuyFromArchives` or capacity change; no change to orders (46.2) or the wanted table (46.6); no new controller or route; the Légendaire Archive price stays null.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First Archive price | current null, candidate ≥ minimum, any size | accepted (no double/halve bound) | — |
| First Archive price under minimum | current null, candidate < candidate minimum | refused on the Archive field | `:archive_below_minimum` (values rarity, minimum) |
| Archive price changed | current 500 | double/halve bound, then ≥ minimum | `:more_than_double` / `:less_than_half` / `:archive_below_minimum` |
| Minimum raised over Archive price | Archive unchanged, minimum > it | refused, beside the Archive field | `:archive_below_minimum` |
| Archive price blanked | candidate nil | accepted, stored null (out of the shop) | — |
| Slot price tripled | `slot_price_goal_6` 500 → 1,500 | refused | `:more_than_double` |
| Order duration | 0 or 31 | refused | `:out_of_range` (existing) |
| Alert prefill | proposed minimum_price_rare > archive_price_rare | `changes` also sets `archive_price_rare` to that minimum, and the candidate validates | — |
| Alert prefill, Archive null or above | proposed minimum ≤ Archive price, or Archive null | no Archive change | — |
| `slot_price(:goal, 3)` / unknown kind | outside the priced slots | raises | `ArgumentError` |

</intent-contract>

## Code Map

- `db/migrate/20261120184008_add_order_duration_days_to_game_market_settings.rb`, `20261120184005/184006` -- patterns: `add_column`, `add_check_constraint … validate: false` then `validate_check_constraint` in a second migration. Amounts are `bigint`.
- `app/domains/game/app/models/game/market/settings.rb` -- readers `entrustment/stamp/minimum_price(rarity)` to mirror.
- `app/domains/game/app/queries/game/capacity.rb` -- `FREE`/`CEILING` by kind (`goal`, `custom_set`, `deck`): the priced slots are `FREE+1..CEILING`; derive the slot fields from them, never retype 6..10 / 4..5.
- `app/domains/game/app/models/game/market/settings_rules.rb` -- `AMOUNTS` (double/halve via `amount_limits`, which reads the current value and must tolerate nil), `OPTIONAL` (nil skips checks), `check_amount`, `check_floor` pattern; `EDITABLE` drives the controller's permitted params, `ChangeSettings`' slice and the form.
- `app/domains/game/app/operations/game/market/change_settings.rb` -- unchanged: it already validates the whole candidate.
- `app/models/back_office/market_settings_form.rb` -- `SINGLE_GROUPS` (fieldsets with labels), `MOMENTS` (rarity rows by row name, single groups by group), `hint` (optional hint), `bounds` (uses `amount_limits`: no bound hint when nil), `violation_message` (values passed through `shown`; a rarity value must be translated with `catalog.rarity.<rarity>`).
- `app/views/back_office/markets/_settings_rarities.html.erb` -- rows `%i[entrustment stamp minimum_price income_days_target]`: add `archive_price` after `minimum_price`.
- `app/views/back_office/markets/_settings.html.erb` -- draws `SINGLE_GROUPS`; no change needed.
- `app/domains/game/app/queries/game/market/economy_alerts.rb` -- `proposal` builds `changes` then checks them with `allowed?`; `Alert#minimum_field` style for an `archive_price_field`.
- `app/views/back_office/market_health/_alert.html.erb` -- proposal lines; add one when `changes` holds the Archive price.
- Locales `back_office.markets.settings` (en ~640, fr same block): `groups`, `labels`, `moments`, `rows`, `hints`, `violations`; `back_office.market_health.alert.proposal_minimum` (en 514, fr 846). `i18n-tasks` ignores unused keys under those settings scopes.
- Tests: `test/domains/game/market/settings_rules_test.rb`, `change_settings_test.rb`, `economy_alerts_test.rb`, `test/models/back_office/market_settings_form_test.rb`, `test/controllers/back_office/market_settings_controller_test.rb`, `markets_controller_test.rb` (moderator read-only, prepared alert), `test/system/back_office_market_test.rb`; helpers `open_market!(**overrides)` in `test/support/market.rb`.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/20261120193000_add_archive_and_slot_prices_to_game_market_settings.rb` -- `archive_price_<rarity>` bigint null for the five rarities; `slot_price_goal_6.._10` and `slot_price_custom_set_6.._10` bigint null false defaults 500, 1_000, 2_000, 3_000, 5_000; `slot_price_deck_4`, `_5` defaults 1_000, 2_000; one check per rarity `archive_price_<r> IS NULL OR archive_price_<r> >= minimum_price_<r>`, name `game_market_settings_archive_price_<r>_check`, `validate: false`.
- [ ] `db/migrate/20261120193001_validate_game_market_settings_archive_price_checks.rb` -- validate the five checks.
- [ ] `db/schema.rb` -- regenerated from the migrations.
- [ ] `settings.rb` -- `archive_price(rarity)`; `slot_price(kind, slot)` raising `ArgumentError` outside the priced slots.
- [ ] `settings_rules.rb` -- `ARCHIVE_PRICES` (in `AMOUNTS` and `OPTIONAL`), `SLOT_PRICES` (in `AMOUNTS`), a priced-slots map shared with `Settings#slot_price`; `amount_limits` returns nil for a null current value and `check_amount` then skips the double/halve bound; Archive check against the candidate's minimum, violation `:archive_below_minimum` with `rarity`, `minimum`.
- [ ] `market_settings_form.rb` -- groups `slots` (the twelve slot fields) and `orders` (`order_duration_days`); moments `archive_price: :now`, `slots: :now`, `orders: :order_placement`; the optional hint for an Archive price says blank is not sold; `violation_message` translates `rarity`.
- [ ] `_settings_rarities.html.erb` -- `archive_price` row.
- [ ] `economy_alerts.rb`, `_alert.html.erb` -- the Archive raise and its proposal line.
- [ ] Locales en + fr -- groups `slots`, `orders`; labels for twelve slot fields and `order_duration_days`; row `archive_price`; moment `order_placement`; hint `not_sold`; violation `archive_below_minimum` (fr "Un prix des Archives ne peut pas être sous le prix minimum d'une %{rarity} : %{minimum}.", en "An Archive price cannot be below a %{rarity}'s minimum price: %{minimum}."); `proposal_archive_price`.
- [ ] Tests -- the matrix in `settings_rules_test.rb` / `change_settings_test.rb` (accepted values reach the new version), `economy_alerts_test.rb` (prefill raises the Archive price and validates; null Archive untouched), settings `slot_price`/`archive_price` readers, form test (moment/hint for every `EDITABLE` field does not raise; Archive refusal copy), controller tests (an administrator saves Archive, slot and duration values through the drawn form; a moderator sees those inputs disabled), migration defaults on a new version.

**Acceptance Criteria:**
- Given an open market, when an administrator draws the back-office settings form, then it shows an Archive price per rarity (blank when null), the twelve slot prices and the order duration, each with its hint and moment, in English and French.
- Given that form, when the administrator saves it with Archive prices, a slot price and a duration within bounds, then the next version stores them; a blank Archive price stays null.
- Given an Archive price under its minimum, when the form is saved, then it re-renders refused with the Archive refusal copy beside that field and no version is written.
- Given a moderator, when they open the page, then the new inputs are disabled.
- Given the migrations run on an empty PG18 database, when the schema is dumped, then it equals the committed `db/schema.rb`.

## Implementation Notes

- Slot fields derive from `Game::Capacity::FREE`/`CEILING` (`SettingsRules::PRICED_SLOTS`); `Settings#slot_price` reads the same map, so the slot numbers are written once, in the migration's defaults.
- `check_amount` split into the doubling, floor and Archive checks; `amount_limits` returns nil for a null current value, which also drops the form's bound hint for an unset Archive price.
- The labels, group names, moment, `not_sold` hint and alert proposal line were written by the implementer (the plan named the keys, not the copy); the English refusal copy was reworded at review ("below the <rarity> minimum price") since "a <rarity>'s" read "a Epic's".
- The implementing subagent left its run waiting on a background test job; the orchestrating session regenerated the schema, ran the review and applied the one patch itself.

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 1, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` quick: the English refusal copy reads "a Epic's" / "a Uncommon's" — reworded to "An Archive price cannot be below the %{rarity} minimum price: %{minimum}." and the two English asserts updated; French unchanged.
  - `[false]` `[reject]` quick: the Légendaire Archive price is editable though "stays null" — the entry asks for an Archive price for the five rarities in the form, and the spec has Légendaires opened later by setting their price; "stays null" is the migration's value, which nothing changes until an administrator does.

## Design Notes

The Archive check sits on the Archive field only, comparing the two candidate values, so "raising a minimum over an Archive price" and "an Archive price under its minimum" are one rule refused in one place. A first Archive price (current null) has no double/halve bound; the alert prefill raises an Archive price to the proposed minimum, which the minimum's own double bound keeps within the Archive price's double bound.

## Verification

**Commands:**
- `rm -f tmp/migrated_schema.rb; RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate db:schema:dump && cp tmp/migrated_schema.rb db/schema.rb` (with the worktree's `DATABASE_URL`) -- expected: only the new columns and checks in the diff
- `bin/rails test test/domains/game/market test/models/back_office test/controllers/back_office` -- expected: green
- `bin/rails test` -- expected: green
- `bin/rails test test/system/back_office_market_test.rb test/system/back_office_market_health_test.rb` -- expected: green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bin/rubocop` on touched files, `bundle exec i18n-tasks missing` -- expected: pass

## Auto Run Result

- **Summary:** the settings version holds an Archive price per rarity (null, out of the shop; never under the rarity's minimum, checked by the database and by `SettingsRules` both ways, a first price bounded by the minimum only), twelve slot prices with `market-economy.md`'s defaults under the double-or-halve bound, and the order duration; `Settings#archive_price` and `#slot_price` are the readers; the back-office form draws the Archive row, the slots and the orders groups (clearing entry 1's deferred moment crash) with the refusal copy in both locales; an alert's prefill that raises a minimum over an Archive price raises the Archive price with it, and its proposal says so.
- **Files:** `db/migrate/20261120193000_add_archive_and_slot_prices_to_game_market_settings.rb`, `20261120193001_validate_game_market_settings_archive_price_checks.rb`, `db/schema.rb`; `settings.rb` (readers), `settings_rules.rb` (fields, bounds, Archive check), `economy_alerts.rb` (Archive raise); `back_office/market_settings_form.rb` (groups, moments, hint, rarity in refusals); `_settings_rarities.html.erb`, `market_health/_alert.html.erb`; `en.yml`, `fr.yml`; tests: new `settings_test.rb`, additions to settings rules, change settings, economy alerts, settings form, settings, markets and health controller tests.
- **Review:** quick lens, 2 findings: 1 low patched (English refusal copy), 1 false rejected (Légendaire editable); nothing deferred. Entry 1's deferred moment crash for `order_duration_days` is resolved by the new `orders` group.
- **Follow-up review:** false (no high or medium patched).
- **Verification:** schema regenerated from the migrations on Postgres 18 is identical to `db/schema.rb`; `bin/rails test` 6236 runs green (implementer, `PARALLEL_WORKERS=4`); after the patch, market, back-office model and controller tests 916 runs green; `test/system/back_office_market_test.rb` and `back_office_market_health_test.rb` 4 runs green; rubocop, `script/check_planning_references`, `script/check_file_sizes`, `i18n-tasks missing`, packwerk and zeitwerk pass. `npm run test:js` not run: no frontend file changed.
- **Residual risks:** the copy the implementer wrote (slot labels, group names, hints, proposal line) awaits the author's approval with the rest of the market-volume copy; migration `20261120193000`'s `schema.rb` lines may collide with parallel lanes at merge (regenerate).

