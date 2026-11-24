---
title: 'The settings, orders and notices carry the rarity rules'
type: 'feature'
ticket: '1'
created: '2026-11-24'
status: 'built'
baseline_revision: '3aabe79241f8eb4d66eba6bd3663fafee9c416f7'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred:
  - summary: >-
      Events stored before this change carry no converted key, so a later reader must read it with a default.
    evidence: |-
      CardListed and WantedChoicesApplied now write converted, nothing reads it yet; a handler that calls data.fetch(:converted) on a replayed older event raises KeyError.
    location: >-
      app/domains/game/app/events/game/market/card_listed.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** The later entries of the epic (conversion, rarity gates, shop cap) need a schema, settings and event contract that does not exist yet: Archive purchase caps, order statuses `bid` and `beaten`, the notice kinds `order_leads` and `order_beaten`, and the converted-order keys of the events.

**Approach:** Add the cap and window columns to the settings version with bounds and back-office fields, widen the order status and notice kind checks (expand, then validate), cover the new kinds with the end-notice index, index Archive withdrawals by player and time, and declare the converted-order keys on the events. No behaviour reads them yet.

</intent-contract>

## Implementation Notes

Oneshot: the change is a contract of columns, checks, constants and form fields, with no operation behaviour. Legendary caps default to 1 a week (the spec names Rare and Epic defaults only; no Archive price is set for Legendaires by default).

## Plan Change Log

## Review Triage Log

### 2026-11-24 - Review pass
- verdicts: 3 findings - high 0, medium 0, low 2, false 0, maybe-false 0 (one rejected)
- findings:
  - `[low]` `patch` no space after the comma in the CardListed publish line of list_card.rb (rubocop would flag it) - fixed; bin/rubocop reports no offenses.
  - `[low]` `reject` the end-notice index is dropped and rebuilt in two migrations, so uniqueness and the upsert's index name are missing between them - the epic records that no order exists in production, so no order_served or order_expired write can land in the gap, and a temporary-name swap would add a constant and a third migration for a window of seconds.
  - `[low]` `defer` older stored events carry no converted key - nothing reads it yet; the later entries read it with a default (recorded in deferred).

## Auto Run Result

- Summary: the settings version gains archive_cap_<rarity> and archive_cap_window_days_<rarity> for Rare, Epic and Legendary (defaults 1 a day, 1 a week, 1 a week), bounded by SettingsRules (at least 1, double or halve) and edited in the back-office group "Archive purchase caps"; orders accept bid and beaten; notices accept order_leads and order_beaten with the end-notice index covering all four end kinds; Archive withdrawals are indexed by player and time; CardListed and WantedChoicesApplied declare the converted-order keys.
- Files: seven migrations (110000 to 110006), db/schema.rb regenerated from them, settings_rules.rb, settings.rb, order.rb, notice.rb, the two events, list_card.rb (builds its event with the new constructor), the back-office settings form, en.yml and fr.yml, and tests (a new contract test plus additions to the settings rules, change settings and settings controller tests, and the three event-data assertions).
- Review: one patch applied (comma), one rejected (index gap), one deferred (old events without converted). No follow-up review recommended; patched counts: low 1.
- Verification: bin/ci passes (rubocop, packwerk, i18n, brakeman, schema build and round trip, 6704 Rails tests, seeds), plus npm run test:js, zeitwerk:check and test/system/back_office_market_test.rb. A first bin/ci run failed the schema build, because the notice index predicate has to be written as Postgres dumps it; the migration was corrected.
- Residual risk: the Legendary cap defaults are an assumption (the spec names Rare and Epic only).

## Verification

**Commands:**
- `bin/rails test` and the touched system test files -- expected: pass
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: pass
