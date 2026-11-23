---
title: 'A goal suggests ordering its missing cards'
type: 'feature'
ticket: '18'
created: '2026-11-23'
status: 'built'
baseline_revision: 'ca6b31826d4b0b587bdf0832c56156932256dcc9'
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

**Problem:** A goal's missing cards can each be ordered from their card detail, but nothing in OBJECTIFS or the goal's album points at them, so a player chasing a set has to hunt each card down.

**Approach:** One game query gives, per goal, the missing cards the player has no open order on, in set order, and nothing unless a player is signed in and the market is open. OBJECTIFS draws a suggestion line after each goal row naming up to two of them as links to the order form; the goal's album header gets "PASSER DES ORDRES · n", which opens the order form on the first and chains: each placed order opens the next card's form with a one-line result above its h1, and the last returns to the album with that line as a polite toast.

## Boundaries & Constraints

**Always:** GETs never write; no new operation, event or migration (placing stays `Game::Market::PlaceOrder`); the market-open and signed-in gate lives in the query only; never database ids in URLs or HTML (cards by slug, the chain by goal number); server-rendered markup only, no `style` attributes, no new Stimulus controller; every string in `en.yml` and `fr.yml` (French as the ticket and EXPERIENCE.md's Copy deck "Goal suggestion" and "Ordre d'achat" rows draw it, U+202F before `:` `?` `!` `;`, plural keys with `zero`); CSS tokens only; files ≤400 lines Ruby/TS, ≤500 CSS; no planning ids; never name a model in a test class body.

**Never:** a chain from the OBJECTIFS links (each opens one form, the placed order goes to MES ORDRES as today); a suggestion on a public profile or another player's album; a count gate on missing cards; changes to `PlaceOrder`, `GoalNeeds` or the MES ORDRES result panel; a "goals" back target on the order form.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Line, several | market open; goal 4 misses A, B, C, D in set order, no order | after goal 4's row, its sibling (outside the row link): "4 cartes à commander : A · B · + 2"; A and B link to `new_market_card_order_path(slug:)`, named "Passer un ordre sur A, objectif 4 : <set>"; "+ 2" plain text | — |
| Line, one | one missing card without order | "1 carte à commander : A", no "+" | — |
| Ordered cards skipped | A has an open order, B, C missing | line "2 cartes à commander : B · C"; album button "· 2" opening B | — |
| All ordered / complete | every missing card has an open order, or none missing | no line, no album button | — |
| Market closed | never opened, or suspended | no line, no button | — |
| Album button | own album of goal n, missing cards without order | beside "OBJECTIF n · RETIRER", inside `#set-album-goal`, a secondary link "PASSER DES ORDRES · 2", named "Passer des ordres, 2 cartes manquantes", to the form on the first in set order with `goal=n&of=2` | — |
| Not a goal | own album of a set that is no goal | no orders button | — |
| Goal toggled by stream | MARQUER COMME OBJECTIF / RETIRER / slot bought on the album | the redrawn control shows or drops the orders button | — |
| Chain next | POST order on A with `goal=4&of=2`, B still missing without order | 303 to the form on B with `goal=4&of=2`; above B's h1 `p#order-chain-result` "Ordre passé sur A : 100 PiCoins bloqués. Carte 1 sur 2."; h1 `tabindex=-1`, `autofocus`, `aria-describedby="order-chain-result"`; form carries hidden `goal`, `of` | — |
| Chain last | POST on B with `goal=4&of=2`, none left | 303 to goal 4's album; toast (flash notice) "Ordre passé sur B : … Carte 2 sur 2." once; album h1 autofocused; no orders button | — |
| Chain index bounds | `of` missing, tampered or smaller than what remains | `of = max(of, remaining + 1)`, index `= of - remaining` | — |
| Chain refused | PlaceOrder fails mid-chain | 422 form as today, hidden `goal`/`of` kept | the refusal as today |
| Chain goal gone | `goal` not one of the player's goal numbers | MES ORDRES with its result panel, as without a chain | — |
| No chain | no `goal` param | MES ORDRES as today | — |

</intent-contract>

## Code Map

- Worktree: work only in `/home/teyermann/projets/gameble-mv-l` (branch `mv/l`); start every shell command with `cd /home/teyermann/projets/gameble-mv-l &&`; call git only as `/usr/bin/git`; never stage, commit or push (the orchestrating session commits). No migration.
- `app/domains/game/app/queries/game/goal_needs.rb` -- `Need` (`goal_id`, `position`, `card_ids` in set order, `missing_card_ids`, `custom?`, `set`); `GoalNeeds.call(player)` gives them in position order. Read-only.
- `app/domains/game/app/models/game/market/order.rb` -- open orders are `status: "open"` (as `PlayerOrders.open_on`). `queries/game/market/market_state.rb`-style `Game::Market::MarketState.call` (`open?`). `queries/game/market/player_orders.rb` -- the card-view idiom: `Catalog::LatestPublishedCardSeasons.call(card_ids)` → `{card_id => card_season_id}`, `Catalog::CardViews.call(ids, locale:)` → views (`id` is the slug, `title`); skip a card with no view.
- `app/models/goal_marks.rb`, `app/controllers/concerns/goal_marks_loading.rb` (`goal_marks.needs`, memoized) -- LibraryController and CustomSetsController already use `goal_marks`; `Market::OrdersController` includes `GoalMarksLoading`.
- OBJECTIFS: `app/controllers/library_controller.rb#show` → `load_goals` (`@goals = goal_marks.needs`); `app/views/library/show.html.erb` → `_entry.html.erb` → `_goals.html.erb` (each `<li>` holds `goals/row`, a link: the suggestion goes after it inside the `<li>`). `app/helpers/goals_helper.rb` (`goal_set_name`, `goal_album_path`). CSS `app/frontend/styles/collection-goals.css` (444 lines: the new rules may go in a new `collection-goal-orders.css` imported beside it in `app/frontend/entrypoints/application.css`).
- Album: `app/controllers/concerns/goal_control_loading.rb#load_goal_control` (used by `LibraryController#set`, `CustomSetsController#show`, `GoalsController#control_stream`, `SlotPurchasesController#goal_bought`); `app/views/goals/_control.html.erb` (`#set-album-goal`, a flex column; `goal_control_controller.ts` refocuses `.goal-button` after its stream: the orders link must not carry that class); render sites `app/views/library/set.html.erb`, `app/views/custom_sets/show.html.erb`, `goals_controller.rb` line ~55, `slot_purchases_controller.rb` line ~91 -- all pass the new `orders:` local. `app/views/library/_album.html.erb` h1 `#set-album-heading` (`tabindex=-1`). `ButtonComponent` (`variant: :secondary, size: :small, href:, aria_label:`).
- Order form: `app/controllers/market/orders_controller.rb` (62 lines; `create` redirects to MES ORDRES with `flash[:placed_order]` on success; `result.value!` is the order, `.price`), `app/views/market/orders/new.html.erb` (h1 `#order-form-heading`), `_form.html.erb` (hidden `settings_token`, `from`), `app/helpers/market_orders_helper.rb` (`picoins`). Toasts: `app/views/shell/_toasts.html.erb` shows `flash[:notice]` in a polite live region.
- Locales: `library.entry.goals.*` (fr ~1571), `goals.*` (fr ~4251), `market.orders.*` (fr ~2809); same paths in `en.yml`.
- Tests to mirror: `test/controllers/library_goals_test.rb` (OBJECTIFS and album goal button; helpers `insert_set`, `unheld_cards`, `hold`, `add`, `count_queries`), `test/controllers/market/orders_controller_test.rb`, `test/controllers/goals_controller_test.rb`, `test/controllers/library_controller_test.rb` and `library_set_test.rb` (query counts), `test/system/market_orders_test.rb` (`sign_in_through_the_site`, `open_market!`, `fund!`), `test/system/goals_test.rb`; supports `test/support/{market,market_orders,game_sets,holdings,steam_sign_in}.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/market/cards_to_order.rb` -- `Game::Market::CardsToOrder.call(player, needs, locale:)` → `{goal_id => [card view, ...]}`: each need's `missing_card_ids` less the player's open-order card ids, in set order, mapped to views (cards with none dropped); `{}` when `player` is nil or `MarketState.call.open?` is false. One reading of "cards to order" for every screen.
- [x] `app/controllers/library_controller.rb`, `library/show.html.erb`, `_entry.html.erb`, `_goals.html.erb` -- `@cards_to_order` in `load_goals`; after each row, when the goal has cards, `<p class="goal-orders">` with the count sentence, up to two name links separated by " · ", then "· + n" in plain text.
- [x] `goal_control_loading.rb` -- `@goal_orders` (the cards of `@goal` from `CardsToOrder` over `goal_marks.needs`, `[]` without a goal; include `GoalMarksLoading` if a caller lacks it); `goals/_control.html.erb` -- `orders: []` local; with a goal and cards, a row holding the goal button and the orders link (`new_market_card_order_path(slug: first.id, goal: goal.position, of: cards.size)`); every render site passes `orders: @goal_orders`.
- [x] `market/orders_controller.rb` -- `create` success with a valid `goal` param: recompute that goal's cards to order, flash the chain line, redirect to the next form (`flash[:order_chain]`) or to `goal_album_path` (`flash[:notice]` plus a marker the album reads to autofocus its h1); otherwise as today. `new`/`create` keep `goal`, `of` for the form. Keep the file ≤400 lines; a private method or concern is fine.
- [x] `market/orders/new.html.erb`, `_form.html.erb` -- the chain line above the h1 and the h1 attributes per the matrix; hidden `goal`, `of` fields when chaining.
- [x] `library/_album.html.erb` -- h1 `autofocus` when the chain just ended.
- [x] CSS -- the suggestion line (small body text, muted, wrapped under the row, links in the link colour) and the control's button row (right-aligned, wraps on a phone). Tokens only; `npm run lint:css`, `npm run format:check`.
- [x] Locales en + fr -- `library.entry.goals.to_order` (zero/one/other "… carte(s) à commander :" / "… card(s) to order:"), `to_order_more` ("+ %{count}"), `to_order_label` ("Passer un ordre sur %{card}, objectif %{number} : %{set}" / "Place an order on %{card}, goal %{number}: %{set}"); `goals.orders.button` ("Passer des ordres · %{count}" / "Place orders · %{count}", case as `goals.button.*`), `goals.orders.label` (zero/one/other "Passer des ordres, 1 carte manquante" / "Place orders, 1 missing card"); `market.orders.create.chain` ("Ordre passé sur %{card} : %{amount} PiCoins bloqués. Carte %{index} sur %{count}." / "Order placed on %{card}: %{amount} PiCoins held. Card %{index} of %{count}.").
- [x] Tests -- `test/domains/game/market/cards_to_order_test.rb` (set order, open orders skipped, served/cancelled orders not skipping, closed/suspended/nil player empty); OBJECTIFS and album rows of the matrix in `library_goals_test.rb` (or a new `library_goal_orders_test.rb`), the custom set album once, a goals stream; chain rows in `test/controllers/market/orders_controller_test.rb`; query counts adjusted only where the new reads land; `test/system/goal_orders_test.rb` -- the Verify flow below.

**Acceptance Criteria:**
- Given a player with a goal missing two cards and an open market, when they open the Collection, then the line names both cards; when they follow PASSER DES ORDRES · 2 on the album and place both orders, then the second form shows "Carte 1 sur 2" above its h1, and the album opens with "Carte 2 sur 2" in a toast and no PASSER DES ORDRES; back on the Collection, the line is gone.

## Implementation Notes

- Built by one implementing subagent from this plan; the orchestrating session read the diff and reran the targeted tests and checks.
- The OBJECTIFS line is built by `GoalsHelper#goal_orders_line`; the styles live in a new `collection-goal-orders.css` (`collection-goals.css` was near its limit), the chain line in `market-orders.css`.
- `GoalControlLoading` now includes `GoalMarksLoading`; `CardsToOrder` returns early (no query) when no goal misses a card, so no query count moved.
- The chain ends with `flash[:notice]` (the polite toast) and `flash[:order_chain_ended]`, which `library/_album.html.erb` reads to autofocus its h1.
- Created the test database `gameble_test_l`.

## Plan Change Log

## Review Triage Log

## Design Notes

- The ticket's `unknown` (at most two names then "+ n"; the undrawn chain ending on the album with a one-line result) is settled by the ticket's description and EXPERIENCE.md's Goal suggestion and Focus rows; built as written, copy marked for the author's approval with the rest of the market-volume copy.
- "Carte i sur n": i is the card whose order was just placed, n the chain's length at its start (Focus row: "Ordre passé sur Transistor : … Carte 2 sur 3." above the third card). The chain carries only the goal number and n; the remaining cards are recomputed after each order, so a card ordered elsewhere meanwhile is skipped.
- The orders link sits inside `#set-album-goal` so every stream that redraws the goal control redraws it too.

## Verification

**Commands:** (export `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_l PARALLEL_WORKERS=4`; create it with `RAILS_ENV=test bin/rails db:create db:schema:load` if missing)
- `bin/rails test test/domains/game/market/cards_to_order_test.rb test/controllers/library_goals_test.rb test/controllers/library_controller_test.rb test/controllers/library_set_test.rb test/controllers/goals_controller_test.rb test/controllers/custom_sets_controller_test.rb test/controllers/slot_purchases_controller_test.rb test/controllers/market/orders_controller_test.rb test/controllers/card_order_button_test.rb test/controllers/read_only_requests_test.rb` (plus any new test file) -- expected: green
- `npm run format:check`, `npm run lint:css` -- expected: pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec rubocop` on touched Ruby files, `bundle exec i18n-tasks missing` -- expected: pass
- Do not run the full suite or any system test (the orchestrator runs them); write `test/system/goal_orders_test.rb` anyway.

## Auto Run Result

- **Summary:** `Game::Market::CardsToOrder` gives each goal's missing cards with no open order, in set order, only for a signed-in player while the market is open. OBJECTIFS draws "<n> cartes à commander : A · B · + n" after each goal row, each name a link to the order form; the goal's album control holds "PASSER DES ORDRES · n", which chains through the goal's cards: each placed order opens the next card's form with "Ordre passé sur … Carte i sur n." above its focused h1, and the last returns to the album with that line as a toast and the h1 focused.
- **Files:** `cards_to_order.rb` (new query); `library_controller.rb`, `goal_control_loading.rb`, `goals_controller.rb`, `slot_purchases_controller.rb`, `market/orders_controller.rb` (chain); `goals_helper.rb`; views `library/{show,_entry,_goals,_album,set}`, `custom_sets/show`, `goals/_control`, `market/orders/{new,_form}`; CSS `collection-goal-orders.css` (new), `market-orders.css`, `application.css`; `en.yml`, `fr.yml`; tests `cards_to_order_test.rb`, `library_goal_orders_test.rb`, chain tests in `market/orders_controller_test.rb`, `test/system/goal_orders_test.rb`.
- **Review:** none, no lenses launched (the author's choice: one review pass at the end of the epic).
- **Verification:** targeted Ruby tests 202 runs, 0 failures (`gameble_test_l`, `PARALLEL_WORKERS=4`); `format:check`, `lint:css`, `zeitwerk:check`, `packwerk check`, `check_planning_references`, `check_file_sizes`, `i18n-tasks missing`, rubocop on touched Ruby files pass. System test written, not run.
- **Residual risks:** nothing seen in a browser (focus on the next form's h1 and the album's h1, the button row on a phone); `of` is not capped (a tampered value only changes the count in the line); the copy awaits the author's approval with the rest of the market-volume copy.
