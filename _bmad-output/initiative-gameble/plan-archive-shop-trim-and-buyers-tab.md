---
title: 'Archive shop loses its noise, the showcase shows 2 or 5 cards, and wanted copies move to a Buyers tab'
type: 'feature'
ticket: ''
created: '2026-11-25'
status: 'built'
baseline_revision: 'cc8a229475025ac746877cc901ec8972b1e6de17'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/docs/design-system.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Archive shop tiles and texts carry lines players do not need ("today's price", a buy label on a card the weekly cap no longer lets them buy, the price-mechanics and PiCoin-destruction explanations, "at one price all week" on the showcase), the market showcase shows 4 cards (3 on phone), and the "VOS CARTES VOULUES" panel above the market tabs is a confusing name in a crowded spot.

**Approach:** Remove those lines, show 5 showcase cards on desktop and 2 on phone, and move the wanted-copies panel into a fifth market tab named "ACHETEURS" (en "BUYERS"), placed last in the tab row, whose title carries a counter badge when some of the player's copies are wanted.

## Boundaries & Constraints

**Always:** The buy label (visible and spoken) is hidden on a tile whose rarity cap is reached, and a purchase that reaches the cap hides it on every tile of that rarity on the page, as the cap line already updates. The badge copies the bids badge pattern (visible number `aria-hidden`, visually hidden spoken count, French plural with a `zero` form). The Buyers tab is signed-in only, like the other personal tabs, has its own controller action and Pundit policy, and lists every wanted copy (no 4-tile cut) with the existing tile markup, the empty state and the "see all" link to the filtered sale screen. Every string in en.yml and fr.yml.

**Never:** Do not touch `market.orders.new.fixed`, `market.bids.form.fixed`, or the help page's shop strings. Do not change how wanted copies are computed. No new count query: the badge reads the size of what `load_desk` already loads.

</frozen-after-approval>

## Code Map

- `app/views/market/shops/_offer.html.erb` -- tile: `archive-offer__fixed` l.21 goes; buy label l.25 shows only when `buyable && cap_line.nil?`; `archive-offer__buy` needs a hook (e.g. `data-archive-buy="<rarity>"`) so the purchase stream can drop it.
- `app/helpers/archive_shop_helper.rb` -- `archive_offer_label` (l.12-20) appends `buy_spoken` only when buyable and not capped; `market.shops.offer.label` drops "today's price" wording (keep the price).
- `app/views/market/archive_purchases/create.turbo_stream.erb:9-11` -- when the cap is now reached, also `remove_all` the buy labels of that rarity.
- `config/locales/{en,fr}.yml` -- `market.shops.offer.fixed` (delete), `market.shops.offer.label` (reword), `market.shops.show.how.items` items 2 and 5 (delete; fr.yml ~2657/2660, en.yml ~3554/3557), `markets.shop_panel.line` (drop "au même prix toute la semaine" / "at one price all week"; fr ~3253, en ~4140), `markets.wanted.heading` → reuse as the tab label "ACHETEURS"/"BUYERS", add the chip key and its spoken badge count.
- `app/domains/game/app/queries/game/market/archive_offers.rb:70` + `app/controllers/markets_controller.rb:41` -- `featured(limit: 4)` → 5.
- `app/frontend/styles/market-shop.css` -- `.shop-panel__list` 4 cols (l.184-191) → 5; phone rule (l.308-315) → 2 cols, hide `:nth-child(n+3)`; `.archive-offer__fixed` (l.132) goes.
- `app/views/markets/_tab.html.erb:11` -- stop rendering the wanted panel above the chips.
- `app/views/markets/_chips.html.erb` -- add `[:buyers, market_buyers_path, t(...)]` last; badge like the bids one, from `@wanted_copies.size`.
- `app/views/markets/_bids_badge.html.erb` -- pattern for the new `_buyers_badge`.
- `app/controllers/concerns/market/desk_loading.rb` -- `load_wanted_copies` keeps the copies for the badge; tile/card views loaded only by the Buyers action.
- `app/controllers/market/my_orders_controller.rb` + `app/policies/market/my_order_policy.rb` -- model for `Market::BuyersController#show` + `Market::BuyerPolicy`; route `get "market/buyers"` beside the other personal tabs in `config/routes.rb`.
- `app/views/markets/_wanted_panel.html.erb` -- becomes the Buyers tab body (show all copies; heading becomes the tab's screen title).
- `app/frontend/styles/market-screen.css:25` -- `.market-screen__badge`.
- Tests: `test/controllers/market/shops_controller_test.rb` (l.31-32,51,172), `test/controllers/market_shop_panel_test.rb` (l.39,74,85,100,107+), `test/system/market_shop_test.rb:74`, `test/system/market_archive_offers_test.rb` (l.37,41), `test/controllers/market_wanted_panel_test.rb` (l.34-67, placement assert l.46), `test/system/market_wanted_copies_test.rb` (l.31-56).

## Tasks & Acceptance

**Execution:**
- [ ] tile, helper, purchase stream, locales -- remove "today's price", hide the buy label when capped (render and after purchase).
- [ ] locales -- delete the two shop explanation items and the showcase phrase.
- [ ] query/controller/CSS -- 5 featured offers; 5 columns desktop, 2 on phone.
- [ ] routes, `Market::BuyersController`, policy, view, chips, badge partial, `_tab.html.erb`, desk loading, locales -- the Buyers tab with badge; panel gone from above the chips.
- [ ] tests -- update the listed tests; add a controller test for the Buyers tab (signed-in list, badge count, guest refused) and a tile test for a capped rarity showing no buy label.

**Acceptance Criteria:**
- Given a player whose Epic cap is reached, when they open the shop, then Epic tiles show no buy label and no spoken "buy", and other rarities still do.
- Given a phone-width viewport, when the market loads, then the showcase shows 2 cards; on desktop it shows 5.
- Given a player with 3 wanted copies, when any market tab loads, then the last tab reads ACHETEURS with a badge of 3, and opening it lists the 3 copies; with none, no badge shows.
- Given any shop tile, then no "prix du jour" text appears.

## Verification

The implementation agent writes the tests but does not run any suite; the main session runs these once.

**Commands:**
- `bin/rails test test/controllers/market test/controllers/market_shop_panel_test.rb test/controllers/market_wanted_panel_test.rb` -- expected: green
- `bin/rails test test/system/market_shop_test.rb test/system/market_archive_offers_test.rb test/system/market_wanted_copies_test.rb` -- expected: green
- `npm run format:check && npm run lint:css && script/check_file_sizes && script/check_planning_references` -- expected: clean

## Review Triage Log

Pass 1 (quick): high 0, medium 1, low 0, false 2.
- medium, patch — after a purchase reaches the cap, other tiles keep "Buy" in their render-time aria-label. Fix: spoken buy text in a described-by span carrying `data-archive-buy`, removed by the same stream.
- false — first acceptance criterion's "other rarities still do": `ArchiveCaps` applies one weekly cap to every rarity, so a capped player is capped everywhere; the code follows the domain and the criterion's second half was a planning assumption.
- false — `test/system/market_shop_test.rb:74` untouched: it no longer references the removed text.
