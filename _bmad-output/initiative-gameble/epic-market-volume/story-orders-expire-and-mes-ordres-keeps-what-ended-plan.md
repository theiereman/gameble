---
title: 'Orders expire, and MES ORDRES keeps what ended'
type: 'feature'
ticket: '9'
created: '2026-11-23'
status: 'built'
baseline_revision: '49a314d71e43bb9a9b6ab1da32c40a4fbd458d4e'
route: 'full'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/docs/design-system.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A buy order's PiCoins stay held forever once its duration passes: nothing expires a due order, the health check cannot see a stuck expiry, and MES ORDRES forgets an order the moment it ends, so a player never sees that it was served, expired or cancelled. A cancel confirmed on an order served a moment before reads as a generic "no longer in progress".

**Approach:** `Game::Market::ExpireOrder` (owner's bank lock, recheck, release, `OrderExpired`) run once per due open order by `Game::Market::ExpireDueOrdersJob` every minute; `OldestDueOrder` read by `CheckMarketHealthJob` and the back-office health page; `PlayerOrders` returns EN COURS and TERMINÉS RÉCEMMENT (7 days) with the served seller and edition; `CancelOrder` refuses a served order with its own code; the suspended banner mentions held orders.

## Boundaries & Constraints

**Always:** writes only through operations, one event per operation; the job runs each order in its own operation call (own transaction); no market-open check in expiry (it runs while the market is closed or suspended); tokens, never ids, in HTML; every string in `en.yml` and `fr.yml` (French plurals with `zero`), `errors.game.order_served` added by hand in both; U+202F before `:` `;` `?` in French strings (the typography test refuses plain spaces); additive edits to locales and `config/recurring.yml`; no planning ids; files ≤ 400 lines; no `style` attributes.

**Never:** bell lines or push for an expiry (entry 12); the "listed above your order" line (entry 12); withdrawing a banned or deleted owner's orders (entry 20); a migration (the end of an ended order is its `updated_at`); changing `SellToOrder`, `ApplyWantedChoices` or the order form; refactoring MES VENTES / MES ENCHÈRES.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Expire due | open order, `expires_at <= now` | status `expired`; one `release` (available +price, committed −price, `order_id`, the order's `settings_id`); one `OrderExpired` on the owner's stream | none |
| Not due | open, `expires_at > now` | nothing written | `NOT_DUE` (`Failure(:order_not_due)`) |
| Already ended | served, cancelled, expired or withdrawn | nothing written | `NOT_DUE` |
| Second run | job runs twice | second run writes nothing, reports nothing | none |
| Market closed | `close_market!` | the job still expires due orders | none |
| Banned owner | owner banned (not deleted) | expires, money released (`require_account`) | none |
| One failing order | `ExpireOrder` raises for one order | the others expire; the error reported with `context: { order_id: }` | `Rails.error.report` |
| Deadlock | `ActiveRecord::Deadlocked` | nothing | `:market_busy` (reported by the job) |
| Health under 5 min | oldest due open order 4 min | no report | none |
| Health over 5 min | oldest due open order 6 min | one `CheckMarketHealthJob::StaleExpiry` report with `age_seconds` | handled report |
| Cancel served | order served before the cancel | nothing moves | `:order_served` → "Cet ordre vient d'être servi." / "This order has just been served." |
| Cancel other ended | cancelled / expired | nothing | `:order_not_open` (unchanged) |
| MES ORDRES recent | served, expired, cancelled within 7 days; one ended 8 days ago; one withdrawn | TERMINÉS RÉCEMMENT lists the three, newest end first; the 8-day-old and the withdrawn one absent | none |

</intent-contract>

## Code Map

Backend (`app/domains/game/app/`):
- `operations/game/market/cancel_order.rb` -- the shape to copy for `ExpireOrder` (`lock_bank`, `Order.lock.find_by(id:, player_id:)`, `update!`, `Ledger.post` release with `order.settings_id`, `publish(..., stream_name: stream_name(player.id))`, `rescue ActiveRecord::Deadlocked` → `:market_busy`). `still_open` returns `Failure(:order_not_open)`; make it return `Failure(:order_served)` when `status == "served"`.
- `operations/game/operation.rb` -- `require_account` (banned allowed), `lock_bank` (fails `:player_required` for a deleted owner: leave it; a deleted owner's orders are another story's).
- `operations/game/market/close_auction.rb` -- `CLOSED_MEANWHILE = Dry::Monads::Failure(...)` constant the job compares against; mirror as `ExpireOrder::NOT_DUE`.
- `models/game/market/order.rb` -- add `scope :due, ->(now) { where(status: "open", expires_at: ..now) }` (complement of `open_at`). Partial index `index_game_market_orders_open_expires_at` serves it.
- `events/game/market/order_expired.rb` -- `OrderExpired.about(order)`; already in `PlayerStream::BALANCE_EVENTS` and `WantedRefresh` (no `event_store.rb` edit).
- `jobs/game/close_due_auctions_job.rb` -- the job shape (`in_batches(of: 100)`, pluck id + owner id, index owners, per-row `rescue StandardError => error; Rails.error.report(error, context: {...})`). New job goes in `jobs/game/market/expire_due_orders_job.rb` (`Game::Market::ExpireDueOrdersJob`, `queue_as :default`).
- `jobs/game/check_market_health_job.rb` + `queries/game/market/oldest_due_listing.rb` -- add `queries/game/market/oldest_due_order.rb` (`OldestDueOrder.call(now: Time.current)` → whole seconds since the oldest due open order's `expires_at`, or nil) and a `StaleExpiry` error reported the same way as `StaleClose` (share one private reporting method).
- `queries/game/market/player_orders.rb` -- today returns open rows only. Return `Groups = Data.define(:in_progress, :recent)`; `Row` gains `status`, `ended_at` (`updated_at` when not open, else nil), `seller` (`Accounts::Player` or nil), `served` (`Catalog::CardViews` view of `served_card_season_id`, or nil). Recent = status in served/expired/cancelled with `updated_at >= now - 7.days` (withdrawn excluded), sorted by `ended_at` desc; in-progress keeps `expires_at, id` order. Qualify `updated_at` (the settings join also has one): hash `where` and symbol `pluck` on `Order` qualify it. Keep `open_on` and the drop of a card with no face as today. Caller: `app/controllers/market/my_orders_controller.rb` (`@placed` must search `in_progress`).

Web:
- `app/controllers/market/my_orders_controller.rb`, `app/views/market/my_orders/{show,_group}.html.erb` -- render EN COURS (heading `my-orders-in-progress-heading`) then TERMINÉS RÉCEMMENT (`my-orders-recent-heading`), each only when it has rows; `EmptyStateComponent` only when both are empty. Generalize `_group` with `group:` and `heading:` locals; the cancel action and dialog only on open rows; ended rows get `MarketRowComponent`'s `note` slot.
- `app/components/market_row_component.{rb,html.erb}` -- unchanged; use `tone:` (`:lime` served, `:muted` expired/cancelled, `:accent` open) and `with_note`.
- `app/helpers/market_orders_helper.rb` -- `order_row_facts` uses `row_end(row.expires_at, row.ended_at)` (`MarketRowsHelper`); add status label (open → `market.rows.status.in_progress`, else `market.my_orders.status.<status>`), tone, and the note: served → `market.my_orders.served_html` with `name:` rendered by `PlayerNameComponent.new(player: row.seller, viewer: current_player)` (it shows removed players as anonymous), `rarity:` `CardStrings.new.rarity_name(row.served.rarity)`, `season:` `row.served.season_number`; no note when `row.served` is nil; expired/cancelled → `market.my_orders.returned`.
- `app/controllers/back_office/market_health_controller.rb` + `app/views/back_office/market_health/show.html.erb` -- `@oldest_due_order_seconds = Game::Market::OldestDueOrder.call`; in the `data-health-oldest-due` section add `<p data-health-oldest-due-order>` beside the listing's paragraph (keep the listing's text, which tests assert); heading broadened to cover both. `health_age` in `app/helpers/market_health_helper.rb`.
- `app/views/market/_suspended_banner.html.erb` -- unchanged; edit `market.suspended_banner.body` in both locales.
- `config/recurring.yml` -- `expire_due_orders: &expire_due_orders` (`class: Game::Market::ExpireDueOrdersJob`, `queue: default`, `schedule: every minute`, a one-line comment like its neighbours), listed in both `development` and `production`.

Tests to mirror: `test/domains/game/market/cancel_order_test.rb` (helpers `fund!`, `figures`, `events`, `open_market!`, `close_market!`), `test/domains/game/close_due_auctions_job_test.rb` (failing-row via `stub_singleton(..., :new, -> { failing })`), `test/domains/game/check_market_health_job_test.rb`, `test/domains/game/market/oldest_due_listing_test.rb`, `test/support/market_orders.rb` (`order!(player, card_season, price, expires_at:)`, `buyer!`), `test/domains/game/market/sell_to_order_test.rb` (serving an order: `hold(seller, card.id, 1)` + `SellToOrder.new.call(player:, card_season_id:, order_token:, settings_token:)`), `test/controllers/market/{my_orders,order_cancellations}_controller_test.rb`, `test/controllers/back_office/market_health_controller_test.rb`, `test/system/market_orders_test.rb`. Fixtures: card `common_card` is "Tin Soldier" (`catalog_card_seasons(:common_card_one)`), `rare_card_one`, players `accounts_players(:player)`, `(:moderator)`.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/models/game/market/order.rb` -- `due` scope.
- [x] `app/domains/game/app/operations/game/market/expire_order.rb` -- `ExpireOrder#call(player:, order_id:)`: `require_account`; transaction: `lock_bank`, `Order.lock.find_by(id:, player_id:)` (missing → `:order_not_found`), open and `expires_at <= Time.current` else `NOT_DUE`, `update!(status: "expired")`, release, publish `OrderExpired`; rescue Deadlocked → `:market_busy`.
- [x] `app/domains/game/app/operations/game/market/cancel_order.rb` -- `:order_served` for a served order.
- [x] `app/domains/game/app/jobs/game/market/expire_due_orders_job.rb` -- per Code Map; `result.value! unless result == ExpireOrder::NOT_DUE`.
- [x] `app/domains/game/app/queries/game/market/oldest_due_order.rb`, `app/domains/game/app/jobs/game/check_market_health_job.rb` -- per Code Map.
- [x] `config/recurring.yml` -- per Code Map.
- [x] `app/domains/game/app/queries/game/market/player_orders.rb`, `app/controllers/market/my_orders_controller.rb`, `app/views/market/my_orders/{show,_group}.html.erb`, `app/helpers/market_orders_helper.rb` -- per Code Map.
- [x] `app/controllers/back_office/market_health_controller.rb`, `app/views/back_office/market_health/show.html.erb` -- per Code Map.
- [x] `config/locales/en.yml`, `fr.yml` -- `market.my_orders.groups.recent` ("RECENTLY ENDED" / "TERMINÉS RÉCEMMENT"); `market.my_orders.status.{served,expired,cancelled}` ("SERVED", "EXPIRED", "CANCELLED" / "SERVI", "EXPIRÉ", "ANNULÉ"); `market.my_orders.served_html` ("Sold by %{name} · %{rarity} S%{season}" / "Vendue par %{name} · %{rarity} S%{season}"); `market.my_orders.returned` ("PiCoins returned" / "PiCoins rendus"); `errors.game.order_served` ("This order has just been served." / "Cet ordre vient d'être servi."); back-office health: the broadened heading and `oldest_due_order.{age,none}` ("The oldest buy order due to expire is %{age} overdue." / "No buy order is due." · "L'ordre d'achat le plus ancien à expirer a %{age} de retard." / "Aucun ordre d'achat n'est à expirer."); `market.suspended_banner.body` French "La Confrérie procède à un audit de ses procédures. Les enchères en cours se terminent normalement et les ordres d'achat restent bloqués jusqu'à leur fin. Il n'est plus possible de confier, de vendre, d'enchérir ou de passer un ordre pour le moment." and the English beside it.
- [x] Tests -- `test/domains/game/market/expire_order_test.rb` (expire with release and one event, not due, each ended status, banned owner, deadlock → `:market_busy`); `test/domains/game/market/expire_due_orders_job_test.rb` (due expire once; second run changes nothing; undue and ended orders left alone; a raising order does not stop the others and is reported with `order_id`; runs while the market is closed); `test/domains/game/market/oldest_due_order_test.rb`; `test/domains/game/check_market_health_job_test.rb` (order due 4 min silent, 6 min reports `StaleExpiry` with its age); `cancel_order_test.rb` (served → `:order_served`, nothing moves); `order_cancellations_controller_test.rb` (served → alert "This order has just been served."); `my_orders_controller_test.rb` (recent group rows with chips, lines and no cancel button, 8-day-old and withdrawn absent, French chips); `market_health_controller_test.rb` (order age shown, "Aucun ordre d'achat" when none); `test/system/market_orders_test.rb` -- one test per Verify: served, expired and cancelled orders under RECENTLY ENDED with their lines, and an open order served after the page drew is refused on cancel with the served line, the row then SERVED; update the existing cancel test, whose cancelled order now shows under RECENTLY ENDED instead of the empty state.

**Acceptance Criteria:**
- Given an order past its end, when `ExpireDueOrdersJob` runs (market open or closed), then the order reads EXPIRÉ under TERMINÉS RÉCEMMENT with "PiCoins rendus" and the owner's available balance is back.
- Given a served order, when its buyer opens MES ORDRES, then its row reads SERVI with "Vendue par <seller> · <rarity> S<n>" of the edition received.
- Given MES ORDRES drawn with an open order that another player then serves, when the buyer confirms ANNULER, then "Cet ordre vient d'être servi." shows, nothing moves, and the row reads SERVI.
- Given a due order stuck over 5 minutes, when `CheckMarketHealthJob` runs, then it reports the age; the back-office health page shows that age beside the listing's.

## Implementation Notes

- `config/i18n-tasks.yml` ignores `market.my_orders.status.*` as unused: the helper builds those keys from the status.
- `test/config/recurring_expire_due_orders_test.rb` pins the schedule, as the other recurring jobs' tests do.
- System tests written, not run (per Verification).

## Plan Change Log

## Review Triage Log

## Design Notes

- An ended order's end is its `updated_at`: serving, expiring and cancelling each `update!` the row once and nothing writes it after, so no column is needed; "Fin" for an ended row shows that time.
- Withdrawn orders belong to banned or deleted owners and are left out of TERMINÉS RÉCEMMENT: a deleted owner's money is forfeited, so "PiCoins rendus" would be false.
- `lock_bank` refuses a deleted owner (`:player_required`), so the job reports such an order every minute until the removal story withdraws it at deletion; expiring into a deleted wallet would race the forfeit.
- The served line names the seller (the ticket's description settles the Left-open question).

## Verification

**Commands:** (with `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_d PARALLEL_WORKERS=4`; create it with `RAILS_ENV=test bin/rails db:create db:schema:load` if missing)
- `bin/rails test test/domains/game/market/expire_order_test.rb test/domains/game/market/expire_due_orders_job_test.rb test/domains/game/market/oldest_due_order_test.rb test/domains/game/check_market_health_job_test.rb test/domains/game/market/cancel_order_test.rb test/controllers/market/my_orders_controller_test.rb test/controllers/market/order_cancellations_controller_test.rb test/controllers/back_office/market_health_controller_test.rb test/models/player_stream_test.rb` -- green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing` -- pass (`config/routes.rb` already over at baseline is not this story's)
- Write the system test but do not run system tests or the full suite; do not commit.

## Auto Run Result

- **Summary:** due buy orders now expire. `ExpireOrder` takes the owner's bank lock, rechecks that the order is still open and due, releases its price and publishes `OrderExpired`; otherwise it returns `NOT_DUE` and writes nothing. `ExpireDueOrdersJob` runs it once per due order every minute, even with the market closed, and reports a failing order then moves on. `CheckMarketHealthJob` reports an expiry stuck for over 5 minutes, and the back-office health page shows its age beside the listing's. MES ORDRES adds TERMINÉS RÉCEMMENT: orders served, expired or cancelled in the last 7 days, with their status chips. A served order's line reads "Vendue par <seller> · <rarity> S<n>"; an expired or cancelled one reads "PiCoins rendus". A cancel on an order served meanwhile is refused with "Cet ordre vient d'être servi." The suspended banner says that buy orders stay held until they end.
- **Files:** `expire_order.rb` (new op); `cancel_order.rb` (`:order_served`); `order.rb` (`due` scope); `jobs/game/market/expire_due_orders_job.rb` (new); `check_market_health_job.rb` (`StaleExpiry`); `queries/game/market/oldest_due_order.rb` (new); `player_orders.rb` (two groups, seller and edition served); `my_orders_controller.rb`, `market/my_orders/{show,_group}.html.erb`, `market_orders_helper.rb` (the recent group, status, line); `back_office/market_health_controller.rb` and `show.html.erb` (order age); `config/recurring.yml`; `config/i18n-tasks.yml`; `en.yml`, `fr.yml`; tests: `expire_order_test`, `expire_due_orders_job_test`, `oldest_due_order_test`, `recurring_expire_due_orders_test` (new), `check_market_health_job_test`, `cancel_order_test`, `my_orders_controller_test`, `order_cancellations_controller_test`, `market_health_controller_test`, `test/system/market_orders_test.rb` (two new tests, one updated).
- **Review:** none, by the author's choice; no lenses were launched.
- **Verification:** 186 targeted runs green (the plan's list plus `test/config`, `orders_controller_test` and `sell_to_order_test`; private database `gameble_test_d`, `PARALLEL_WORKERS=4`). `zeitwerk:check`, `packwerk check`, `check_planning_references`, `check_file_sizes` and `i18n-tasks missing` pass. System tests were written but not run; the orchestrator runs them.
- **Residual risks:**
  - A due order whose owner deleted their account fails `lock_bank` with `:player_required`, so it is reported every minute until the removal story withdraws it.
  - The English copy and the broadened health heading are drafts for the author to approve.
