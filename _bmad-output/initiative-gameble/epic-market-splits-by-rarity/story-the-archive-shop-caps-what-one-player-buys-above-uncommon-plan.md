---
title: 'The Archive shop caps what one player buys above Uncommon'
type: 'feature'
ticket: '4'
created: '2026-11-24'
status: 'built'
baseline_revision: '0bc2147aaa15b41986f04d4ba73460935f4b4598'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/docs/design-system.md'
warnings: ['oversized']
deferred:
  - summary: >-
      test/system/market_orders_test.rb "served, expired and cancelled orders" raises on develop since the direct-sale restriction.
    evidence: |-
      The test serves a Rare order through SellToOrder, which now returns Failure(:direct_sale_not_for_rarity); value! raises. Not in code this change touches.
    location: >-
      test/system/market_orders_test.rb:104
    severity: medium
  - summary: >-
      The shop's rarity chips do not show what is left of each cap.
    evidence: |-
      The experience copy says a rarity's chip and each of its tiles show the cap; the tiles, the grid, the shop panel and the order form do, the chips do not.
    location: >-
      app/views/market/shops/_filters.html.erb
    severity: low
---

<intent-contract>

## Intent

**Problem:** Money alone lets a rich player buy every Rare, Epic and Legendary copy the Archives hold. The settings already carry `archive_cap_<rarity>` and `archive_cap_window_days_<rarity>` (Rare, Epic, Legendary; Common and Uncommon have none), but nothing reads them.

**Approach:** `BuyFromArchives` counts, under the player's bank lock, the player's withdrawals of the purchased rarity inside the settings version's window and refuses at the cap with `Failure(:archive_cap_reached)`, charging nothing. A query returns what is left of each cap, and the shop, the market grid's Archive offers, the order form's Archive offers and the purchase confirmation show it; the confirmation draws no form past the cap. The order form also says an order becomes an auction when a player lists at or below its price.

## Boundaries & Constraints

**Always:** Count withdrawals by joining `catalog_card_seasons` for the rarity; the existing index on `game_market_archive_withdrawals` (player, time) stays the access path; add no migration and no column. A purchase counts while `created_at > now - window_days days`, `now` being read once under the bank lock and reused for the withdrawal's `created_at`. The next purchase time is the oldest counted purchase's time plus the window (when more are counted than the cap, the time at which the count falls below the cap: the counted purchase at index `count - cap` in time order plus the window). A Common and an Uncommon are never refused and show no cap. A visitor sees no cap line. Read caps through a query in the controllers and pass them to views as a local; no view or helper queries. Every string in both `en.yml` and `fr.yml` (French plural keys carry a `zero` form); add `errors.market.archive_cap_reached` in both by hand. No planning ids, no comments except one-line external constraints, no `style` attribute, no database id in HTML or URLs.

**Never:** Re-add the settings columns, bounds or back-office fields of the settings entry. Change the order, auction or direct-sale paths. Write a model from a controller or view. Run the whole system suite.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| At the cap | Rare cap 1 a day, one Rare bought 2 hours ago, a second Rare bought | refused | `Failure(:archive_cap_reached)`, no ledger entry, stock, holding, withdrawal or event written |
| Under the cap | Epic cap 2 a week, one Epic bought | passes; the standing then reads 0 left | none |
| After the window | The only Rare was bought 25 hours ago, cap 1 a day | passes | none |
| Uncapped rarity | Common or Uncommon bought many times | never refused | none |
| Per rarity | A Rare bought, then an Epic | the Epic passes (counts are per rarity) | none |
| Per player | Another player bought the capped rarity | not counted | none |
| Window boundary | Oldest purchase exactly `window_days` old | no longer counted | none |
| Replayed token | The same purchase token after the cap is reached | answers the earlier purchase, moves nothing | none |
| Shop, none left | Epic cap 1 a week, one bought | tile reads "1 Épique par semaine · prochaine le <date>" | none |
| Shop, some left | Epic cap 2 a week, one bought | tile reads what is left, e.g. "Encore 1 Épique par semaine" | none |
| Confirmation past the cap | Opening a capped edition's purchase | no form, only cancel; says "Vous avez atteint la limite des Archives pour cette rareté. Prochain achat le <date>." | none |
| Cap reached at the press | Cap reached from another tab, then the press | 422, same message, nothing charged | `archive_cap_reached` |
| Visitor | Signed out | tiles without any cap line | none |

</intent-contract>

## Code Map

- `app/domains/game/app/operations/game/market/buy_from_archives.rb` -- add the cap step under the bank lock (after `covered`); read `now = Time.current` once right after the lock and reuse it for the withdrawal and the cap; turn the rarity into a name (`Catalog::Rarity::TIERS[tier]` or the enum string from `Catalog::CardSeason.where(id:).pick(:rarity)`, which already returns the name string) for `archive_price` and the cap; keep `:not_in_shop` for a missing rarity.
- `app/domains/game/app/queries/game/market/archive_caps.rb` -- NEW query module `ArchiveCaps.call(player:, settings:, now: Time.current)` returning `{ rare: Standing, epic: Standing, legendary: Standing }` for `SettingsRules::CAPPED_RARITIES` (symbol keys; `{}` for a nil player). `Standing = Data.define(:cap, :window_days, :left, :next_at)`, `reached?` = `left.zero?`, `next_at` nil unless reached. One query: `ArchiveWithdrawal` joined to `catalog_card_seasons` on `card_season_id`, `player_id`, OR of one `(rarity tier = ? AND created_at > ?)` per rarity, ordered by time, `pluck` rarity tier and time; group in Ruby with `Catalog::Rarity::TIERS`. `settings.archive_cap(rarity)` and `settings.archive_cap_window_days(rarity)` exist on `Game::Market::Settings`. `BuyFromArchives` uses it too, so there is one counting rule.
- `app/domains/game/app/queries/game/market/archive_offers.rb` -- rows are `Row(card, price, stock)`; do not change them; `card.rarity` is the rarity name string (enum), use `.to_sym` to read a caps hash.
- `app/controllers/market/shops_controller.rb` (`load_market`), `app/controllers/markets_controller.rb` (`load_shop_panel`, grid tiles), `app/controllers/market/orders_controller.rb` (`load_terms`), `app/controllers/market/archive_purchases_controller.rb` (`load_terms`, `purchase_state`, `standing_refusal`, `refusal`) -- load `@archive_caps = Game::Market::ArchiveCaps.call(player: current_player, settings: @settings)` (visitor: `{}`) and pass `caps:` on. In the purchase controller, `load_terms` runs after the operation, so the caps are fresh after a press. `purchase_state` returns `:capped` when the offer's rarity standing is reached (check after `:closed`, before `:short`). A refusal `:archive_cap_reached` and a standing capped state both say `operation.failure_message(:archive_cap_reached, date: <localized next date>)`; when the standing has no `next_at` at that moment (the window passed between the press and the reload) use today's date.
- `app/components/purchase_confirmation_component.rb` and `.html.erb` -- add a `:capped` state: no form, no missing line, only the cancel button, the refusal paragraph (role alert) carries the message.
- `app/views/market/archive_purchases/_confirmation.html.erb` -- the capped state's title is the usual title; `create.turbo_stream.erb` and `new.html.erb` pass `caps:` to the replaced tile.
- `app/views/market/shops/_offer.html.erb` (locals gain `caps: {}`), `_offers.html.erb`, `show.html.erb`, `show.turbo_stream.erb`, `app/views/markets/_tiles.html.erb`, `screen.html.erb`, `screen.turbo_stream.erb`, `app/views/markets/_shop_panel.html.erb` and its render site -- thread `caps:` to every render of the offer tile; the tile shows one `listing-tile__line archive-offer__cap` line (hidden from the visual-only aria tree like the other facts; add the line to `archive_offer_label` in `app/helpers/archive_shop_helper.rb` so the link's spoken label carries it). Commons and Uncommons: no line.
- `app/helpers/archive_shop_helper.rb` -- `archive_cap_line(card, caps)` returning the string or nil, and the localized next date helper; pure formatting of the standing passed in.
- `app/views/market/orders/_available.html.erb` -- the Archive offer row shows the same cap line; `app/views/market/orders/_form.html.erb` -- under the `order-form__sentence` paragraph add `<p class="order-form__conversion">` with `t("market.orders.new.conversion")`.
- `app/frontend/styles/market-shop.css` (tile cap line) and the order form's stylesheet (conversion line, find it with `grep -rn order-form__sentence app/frontend/styles`) -- small muted-text rules from existing tokens; follow `docs/design-system.md`; keep each CSS file at 500 lines or fewer; `npm run lint:css`.
- `config/locales/en.yml`, `config/locales/fr.yml` -- keys in sorted order beside their neighbours: `errors.market.archive_cap_reached`; `market.archive_cap.{left,reached,window.{day,week,days},rarity.{rare,epic,legendary}}` (rarity names with one/other forms, the French ones with a `zero` too; `days` plural with `zero`); `market.orders.new.conversion`. Copy: reached "1 Épique par semaine · prochaine le 3 décembre" (`"%{cap} %{rarity} %{window} · prochaine le %{date}"`; en `"%{cap} %{rarity} %{window} · next on %{date}"`), left "Encore 1 Épique par semaine" (en "1 more Epic per week"), window "par jour" / "par semaine" / "sur %{count} jours" (en "per day" / "per week" / "per %{count} days"; the helper picks day for 1, week for 7, else days), error "Vous avez atteint la limite des Archives pour cette rareté. Prochain achat le %{date}." (en "You have reached the Archives limit for this rarity. Next purchase on %{date}."), conversion "Si un joueur met cette carte aux enchères à ce prix ou moins, votre ordre devient une enchère et vos PiCoins y restent bloqués." (en "If a player lists this card at auction at this price or lower, your order becomes a bid and your PiCoins stay held in it."). Date format: `l(date, format: :day_month)` exists in both locales.
- Existing tests that buy two copies of one capped rarity in a window (default Rare cap is 1 a day) will now be refused: grep the tests for `BuyFromArchives` / `archive_purchase` / `Archive` buying flows (`test/domains/game/market/buy_from_archives_test.rb` "a second purchase token buys a second copy", `test/controllers/market/archive_purchases_controller_test.rb`, `test/system/market_shop_test.rb`, `test/system/market_archive_offers_test.rb`, `test/controllers/market_shop_panel_test.rb`, `test/support/market.rb`) and raise the cap through `open_market!(archive_cap_rare: ...)` where the test is not about the cap.
- Do not touch: `db/schema.rb`, migrations, the settings columns, `SettingsRules`, the back-office form.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/market/archive_caps.rb` -- the standing query -- one counting rule for the operation and the screens
- [ ] `app/domains/game/app/operations/game/market/buy_from_archives.rb` -- refuse at the cap with `:archive_cap_reached`, nothing charged
- [ ] the four controllers, the confirmation component, the tile, order-form and confirmation views, helper, CSS -- show what is left, no form past the cap
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- all strings and the error key
- [ ] `test/domains/game/market/archive_caps_test.rb` and `test/domains/game/market/buy_from_archives_test.rb` -- the matrix rows: second Epic within a week refused with `:archive_cap_reached` and nothing written, a Common and an Uncommon never refused, a purchase after the window passes, per rarity, per player, window boundary, replayed token; raise the cap in the existing tests that buy twice
- [ ] `test/controllers/market/archive_purchases_controller_test.rb`, `test/controllers/market/shops_controller_test.rb`, `test/controllers/market/orders_controller_test.rb` -- the confirmation draws no form and says the message past the cap, a refused press says it with 422 and nothing charged, the tile and order-form offer carry the cap line, a visitor and a Common carry none, the order form carries the conversion line
- [ ] `test/system/market_shop_cap_test.rb` -- NEW: signed in, an Epic (find the fixture, e.g. `catalog_card_seasons(:epic_card_one)` or the like) with `archive_cap_epic: 1` and a withdrawal made through `BuyFromArchives` or created directly; the shop tile names "prochaine le <date>", opening the tile's confirmation draws no form (`assert_no_button`/`assert_no_selector "form"` inside the dialog) and shows the message; use retrying matchers only

**Acceptance Criteria:**
- Given a player who bought an Epic inside the Epic window at its cap, when they buy another Epic, then `BuyFromArchives` returns `Failure(:archive_cap_reached)` and no ledger entry, holding, stock change, withdrawal or event is written.
- Given the same player, when they buy a Common or an Uncommon, or an Epic after the window, then the purchase passes.
- Given a capped rarity with none left, when the shop, the market grid, the market's shop panel or the order form's Archive offer draws its tile, then it reads "<cap> <rarity> <window> · prochaine le <date>" in French and the English one in English; a visitor and a Common or Uncommon show no cap line.
- Given a capped edition, when its purchase confirmation opens, then no form is drawn and the message says "Vous avez atteint la limite des Archives pour cette rareté. Prochain achat le <date>."; and when the press is refused for the cap, the response is the same message with status 422 and nothing charged.
- Given the order form, then under the price sentence the conversion line is drawn.

## Implementation Notes

Full route. The cap is counted by one query (`ArchiveCaps`) that both the operation (under the bank lock, `now` read once after the lock) and the screens use; the rarity comes from a join to `catalog_card_seasons`, so no column or migration. The cap check runs before the balance check, so a capped player is told about the cap, not about money. A capped confirmation draws no price and no balance row. Existing Archive buying tests that bought twice raise `archive_cap_rare`.

## Plan Change Log

## Review Triage Log

### 2026-11-24 - Review pass
- verdicts: 7 findings - high 0, medium 1, low 6, false 0, maybe-false 0
- findings:
  - `[medium]` `patch` a press refused for money while the cap was reached meanwhile gave a dialog with no form and no message - the cap check now runs before the balance check, with a test for capped and short.
  - `[low]` `patch` the capped confirmation drew the price and a "balance after" dash implying the player was short - the view passes no price when capped.
  - `[low]` `patch` two descriptive comments in archive_caps.rb and archive_shop_helper.rb against the no-comment rule - removed.
  - `[low]` `reject` no test of the cap line on the market grid tiles and the shop panel - the same partial renders every tile and the shop and order-form tests cover it; the fix is only more tests.
  - `[low]` `reject` no order-form test for a Common offer without a cap line - the helper returns nil for a rarity without a standing, covered by the shops test.
  - `[low]` `reject` the under-the-cap row does not assert the standing reads 0 left - archive_caps_test covers the standing.
  - `[low]` `reject` the fallback to today's date is untested - it only covers a window that passes between a press and a reload.

## Auto Run Result

- Summary: BuyFromArchives refuses a purchase past the rarity's cap in its window with Failure(:archive_cap_reached), nothing charged; ArchiveCaps reads what is left of each cap; the shop, market grid, shop panel and order form's Archive offers show it; the confirmation draws no form past it and says so, also when refused at the press; the order form carries the conversion line.
- Files: archive_caps.rb (new), buy_from_archives.rb, four controllers, purchase_confirmation_component, offer tile and its callers, order form views, archive_shop_helper, two stylesheets, en.yml and fr.yml, and tests (archive_caps_test, buy_from_archives_test, controller and component tests, system market_shop_cap_test). No migration.
- Review: quick, 7 findings: 3 patches applied (medium 1, low 2), 4 rejected low (test gaps), 2 deferred items recorded (a pre-existing system test failure, cap on chips). No follow-up review recommended; patched counts: medium 1, low 2.
- Verification: see the report of the run; unit suite, touched system tests, lints and bin/ci.
- Residual risk: market_orders_test system test fails on develop (deferred); cap line shows "Encore n ..." to every signed-in player.

## Design Notes

The cap standing is read twice by design: the operation recomputes it under the bank lock (the money check), the screens read it without a lock (display). A purchase passing a stale screen is refused by the operation. The join to `catalog_card_seasons` keeps the (player, time) index useful: the index narrows to the player's window rows, the join is by primary key on a handful of rows, so no column or migration is needed.

## Verification

**Commands:**
- Environment for every test command: `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w484 CHROME_BIN=/usr/bin/chromium PARALLEL_WORKERS=4`.
- `bin/rails test` -- expected: pass (the unit suite in full is fine)
- `bin/rails test test/system/market_shop_cap_test.rb` and, one or two at a time with `PARALLEL_WORKERS=2`, `test/system/market_shop_test.rb`, `test/system/market_archive_offers_test.rb`, `test/system/market_orders_test.rb` (the order-form system test if it exists; `ls test/system | grep market`) -- expected: pass; never run `bin/rails test:system` as a whole
- `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `npm run test:js`, `bin/ci` -- expected: pass
