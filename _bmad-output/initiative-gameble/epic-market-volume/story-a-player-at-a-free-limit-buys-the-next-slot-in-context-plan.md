---
title: 'A player at a free limit buys the next slot in context'
type: 'feature'
ticket: '17'
created: '2026-11-23'
status: 'built'
baseline_revision: 'ba6499b9e169301aed8ca8cdc493c1bea3fd0fab'
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

**Problem:** A player at a free limit (5 goals, 5 custom sets, 3 decks) meets a refusal; the capacity table, the slot prices and the reusable purchase confirmation exist, but nothing sells the next slot.

**Approach:** `Game::BuySlot` buys exactly the next slot under the bank lock, destroys its price through the ledger and, for a goal, adds the goal in the same transaction. At a free limit below the ceiling, MARQUER COMME OBJECTIF, the new set tile and "+ NOUVEAU DECK" become links that open a slot purchase dialog built on `PurchaseConfirmationComponent`; bought, the goal control redraws with the goal, or the custom set editor or the new deck's editor opens.

## Boundaries & Constraints

**Always:** writes only through `Game::BuySlot`; GETs never write; lock order: bank lock, then the player's capacity row (then the goal step); `Market::Ledger.post` once, then one `Game::SlotBought.with(player_id:, kind: kind.to_s, goal_id:)` on the player's stream (`wanted_refresh.rb` and `PlayerStream` already hear it: no subscription change); BuySlot never reads `settings.open`; deadlock → `:market_busy`; prices only from `Settings#slot_price(kind, slot)`; free counts and ceilings only from `Game::Capacity`; a slot is kept for good; Pundit on every action; rate limited per player; never database ids in URLs or HTML; every string in `en.yml` and `fr.yml` (French as EXPERIENCE.md's Copy deck "Slot purchase" row draws it, U+202F before `?` `:` `!` `;`; English beside it with correct ordinals 4 to 10, "AN 8TH"/"An eighth" included); new `errors.game.*` keys by hand in both; server-rendered markup, no `style` attributes, script only toggles and focuses; no planning ids; files ≤400 lines Ruby/TS, ≤500 CSS.

**Never:** slots in the shop; export or privacy copy for bought slots (removal story); a dialog at the ceiling (10 goals, 10 sets, 5 decks keep today's refusals); creating an empty custom set or a deck at purchase (AD-62's assumption, confirmed by the code: the custom set editor creates on save, `new_deck_path` "writes nothing until its first change"); event subscription changes; any change to `AddGoal`'s behaviour.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Goal slot | 5 goals, no slot row, slot 6, current token, available ≥ `slot_price_goal_6`, aim an incomplete published set | row goal bought 1; goal at position 6; one `slot_purchase` entry (−price, version id); `SlotBought` kind "goal" with goal_id; `Success(goal)` | — |
| Custom set / deck slot | 5 sets (or 3 decks), slot 6 (or 4) | bought 1 (row inserted), or +1 on an existing row; no set or deck created; `SlotBought` goal_id nil; `Success` | — |
| Slot taken | slot ≠ limit + 1 (bought in another tab; a double submission's second call) | nothing moves, charged once overall | `:slot_already_bought` |
| Ceiling | limit already the ceiling, or slot > ceiling | nothing | `:slot_ceiling` |
| Stale / no settings | token ≠ current version's, or no version | nothing | `:amounts_changed` |
| Short | available < price | nothing | `:more_than_available` |
| Goal step refuses | aim complete / unknown / not the player's custom set / already a goal / empty library set | slot row, ledger, wallet unchanged; no event | the step's code (`:goal_set_complete`, `:goal_set_not_found`, `:custom_set_not_found`, `:goal_already_set`, `:library_set_empty`) |
| Market closed or suspended | settings `open: false`, current token | bought as usual | — |
| Removed / busy | banned or deleted player / deadlock | nothing | `:player_required` / `:market_busy` |
| Kept | goal bought, then `RemoveGoal` (or set or deck deleted) | `bought` unchanged | — |
| Reconciliation | after slot purchases | `ReconcileWallets` balanced, the slot price counted destroyed | — |

</intent-contract>

## Code Map

- Worktree: work only in `/home/teyermann/projets/gameble-mv-h` (branch `mv/h`); start every shell command with `cd /home/teyermann/projets/gameble-mv-h &&`; call git only as `/usr/bin/git`; never commit, stage or push (the orchestrating session commits). No migration is needed.
- `app/domains/game/app/queries/game/capacity.rb` (`FREE`, `CEILING`, `limit`), `models/game/capacity_slot.rb` (table `game_capacity_slots`: player_id, kind string, bought; unique `[player_id, kind]`; check bought 1..5, decks 1..2).
- `app/domains/game/app/operations/game/add_goal.rb` + `goal_steps.rb` -- extract the insertion (`free_position`, `incomplete`, `Goal.create!`) into a `GoalSteps` method both use; `AddGoal` keeps returning an existing goal as success and publishing `GoalAdded`; BuySlot fails `:goal_already_set` on an existing goal and publishes no `GoalAdded`.
- `app/domains/game/app/operations/game/market/buy_from_archives.rb` -- shape to mirror (`require_player`, `transaction`, `lock_bank`, settings token check, `Balance.call(player).available`, `Ledger.post(Ledger::Entry.new(player_id:, kind: :slot_purchase, available_delta: -price, settings_id:))`, publish, `rescue ActiveRecord::Deadlocked`). `Game::Operation` (`operation.rb`) requires a `player:` keyword.
- `app/domains/game/app/models/game/market/settings.rb#slot_price` (raises outside `SettingsRules::PRICED_SLOTS`), `queries/game/market/current_settings.rb`, `balance.rb`, `events/game/slot_bought.rb`.
- `app/controllers/market/archive_purchases_controller.rb`, `app/views/market/archive_purchases/{new.html.erb,create.turbo_stream.erb,_confirmation.html.erb}`, `app/views/market/shops/_dialog.html.erb` -- the confirmation pattern to mirror: GET renders the component in a `turbo_frame_tag`; POST answers a stream updating the frame (200 / 422), html renders `new`; `throttle_player to: 10, only: :create, path:, alert:`; refusal per code redrawn from fresh state.
- `app/components/purchase_confirmation_component.{rb,html.erb}` -- `state:` `:buyable`/`:short`/`:closed`, `entrust:`, slots `visual`/`facts`/`note`, `title:` (may be HTML-safe), `missing_line:`, `refusal:`, `fields:`. Add a `lead` slot drawn under the head, before the summary, for the free count sentence.
- `app/frontend/controllers/purchase_dialog_controller.ts` (`open` needs an `<a>` opener; targets dialog, frame, loading, title, optional heading; focuses the title when the frame loads), `dialog_controller.ts` (restores focus to the opener on close; a dialog rendered with `open` becomes modal on connect).
- Goal button: `app/views/goals/_control.html.erb` (`#set-album-goal`, `data-controller="goal-control"`, refusal `p[role=status]`), `app/controllers/concerns/goal_control_loading.rb` (used by `LibraryController#set`, `CustomSetsController#show`, `GoalsController#control_stream`), `app/frontend/controllers/goal_control_controller.ts` (refocuses the first button after any stream), `app/views/library/set.html.erb`, `app/views/custom_sets/show.html.erb`; `app/helpers/goals_helper.rb#goal_set_name`.
- Custom sets: `app/controllers/library_controller.rb#show` (`@custom_set_tiles`, `@custom_set_slots`), `app/views/library/show.html.erb` → `_entry.html.erb` → `_custom_sets.html.erb` (new set tile is a `dialog-opener` button; `custom_sets/_editor` rendered only with room; its name field has `autofocus`), `app/frontend/styles/collection-custom-sets.css`.
- Decks: `app/controllers/duels_controller.rb#show`, `app/models/deck_list.rb` (`count`, `limit`, `room_left?`), `app/views/duels/_decks.html.erb` ("+ NOUVEAU DECK" `link_to new_deck_path, class: "deck-new"`), `app/views/decks/new.html.erb` → `decks/_editor.html.erb` (name field `#deck-name`), `app/frontend/styles/duels.css`.
- `config/routes.rb` -- additive, beside `library/goals`, one-line comment.
- Locales: `purchase_confirmation.*` (shared buttons), `goals.*`, `library.entry.custom_sets.*`, `duels.decks.*`, `errors.game.*` (codes read by `failure_message`).
- Tests to mirror: `test/domains/game/market/buy_from_archives_test.rb`, `test/domains/game/goal_operations_test.rb`, `capacity_test.rb`, `test/domains/game/market/reconcile_wallets_test.rb`, `test/controllers/market/archive_purchases_controller_test.rb`, `goals_controller_test.rb`, `library_controller_test.rb` (query count), `duels_controller_test.rb`, `test/system/market_shop_test.rb`, `goals_test.rb`, `custom_sets_test.rb`, `duels_test.rb`; supports `test/support/market.rb` (`open_market!(**overrides)`, `close_market!`, `fund!`), `steam_sign_in`.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/slot_offer.rb` -- `Game::SlotOffer.call(kind, limit:, used:)` → `Offer(kind, slot, price)` when `used >= limit`, `limit < CEILING[kind]` and a settings version exists (price `slot_price(kind, limit + 1)`), else nil -- one reading of "at a free limit" for every screen.
- [x] `goal_steps.rb`, `add_goal.rb` -- extract the goal insertion per Code Map.
- [x] `app/domains/game/app/operations/game/buy_slot.rb` -- `call(player:, kind:, slot:, settings_token:, aim: nil)` (kind `goal`/`custom_set`/`deck`, symbol or string, unknown raises `ArgumentError`; `aim` the `AddGoal` keywords): `require_player`; transaction: `lock_bank`; `CapacitySlot.lock.find_by`; ceiling (`:slot_ceiling`); slot = limit + 1 (`:slot_already_bought`); current settings token (`:amounts_changed`, also with no version); price; covered (`:more_than_available`); insert bought 1 or increment; goal: aim → `:goal_already_set` if a goal exists → the extracted step; `Ledger.post`; publish `SlotBought`; returns the goal (goal) or the capacity row; deadlock → `:market_busy`.
- [x] `config/locales/en.yml`, `fr.yml` `errors.game` -- `slot_already_bought` ("Cet emplacement est déjà acheté." / "This slot is already bought."), `slot_ceiling` ("Vous avez déjà tous les emplacements possibles." / "You already have every slot there is."), `goal_already_set` ("Ce set est déjà un objectif." / "This set is already a goal.").
- [x] `config/routes.rb` -- `get "slots/:capacity/:slot" => "slot_purchases#new", as: :new_slot_purchase` and `post` the same path `=> "slot_purchases#create", as: :slot_purchase`; constraints `capacity: /goals|custom-sets|decks/`, `slot: /\d+/` (the goal aim travels as `kind`/`key` or `custom_set` params, so the slot kind is `capacity`).
- [x] `app/policies/slot_purchase_policy.rb` -- `new? = create? = player?`.
- [x] `app/controllers/slot_purchases_controller.rb` -- `new`: resolve kind and aim (goal: set name as `goal_set_name` would give it, via `Catalog::PublishedSeason`/`Catalog::SetAlbum`/`SetLabel` or `Game::CustomSetStandings`; unknown → 404), limit, settings (none → 404), available, `@state` (`:closed` with the refusal when the URL slot ≠ limit + 1 — `:slot_already_bought` — or at the ceiling — `:slot_ceiling`; `:short` when available < price; else `:buyable`), `entrust: settings.open`; `create`: call `BuySlot` with `params[:slot].to_i`, `params[:settings_token].to_s`, the aim; success: goal → `turbo_stream.replace "set-album-goal"` (morph) with `goals/control` (`bought: true`) loaded by `load_goal_control`, html → redirect to the album with that line as `flash[:notice]`; custom set → `flash[:slot_bought] = "custom_set"`, `redirect_to library_path, status: :see_other`; deck → `flash[:slot_bought] = "deck"`, `redirect_to new_deck_path, status: :see_other`; failure → fresh terms plus the refusal line (none for `:more_than_available`, which redraws the short state), stream updating the frame with 422, html `new`; `throttle_player to: 10, only: :create, path: -> { new_slot_purchase_path(...) }, alert: "slot_purchases.create.throttled"`.
- [x] `app/views/slot_purchases/{_dialog.html.erb,new.html.erb,create.turbo_stream.erb,_confirmation.html.erb}` -- `_dialog`: as `market/shops/_dialog` with id `slot-purchase-dialog`, `aria-labelledby="slot-purchase-title"`, `turbo_frame_tag "slot-purchase", target: "_top"` (redirects leave the frame; streams still apply); `_confirmation`: the component with the title (visible "UN 6E OBJECTIF ?" `aria-hidden`, spoken "Un sixième objectif ?" visually hidden; sets "UN 6E SET ?", decks "UN 4E DECK ?"), the lead (Copy deck free lines with `Capacity::FREE`, the set name and the goal number), Prix, Solde après, hidden `settings_token` and the aim, short line "Il vous manque <amount> PiCoins." (`picoins(price - available)`), CONFIER DES CARTES only while the market is open.
- [x] `app/components/purchase_confirmation_component.{rb,html.erb}` -- `lead` slot.
- [x] `goal_control_loading.rb`, `goals/_control.html.erb`, `goals_controller.rb` -- load `@goal_slot = SlotOffer.call(:goal, limit: Capacity.limit(player, :goal), used: targets.size)` when the set is not a goal; with an offer and no goal, draw MARQUER COMME OBJECTIF as a link (`button button--secondary button--small goal-button`) to `new_slot_purchase_path(capacity: "goals", slot:, **aim)` with `aria-haspopup="dialog"`, `data-action="purchase-dialog#open"`, `aria-describedby` the price line "Emplacements gratuits pris : le suivant coûte <price>." (`PicoinAmountComponent`), the control also carrying `purchase-dialog` and rendering `slot_purchases/_dialog`; a `too_many_goals` answer with an offer redraws that link without the ceiling refusal; `bought: true` writes in the status paragraph "6E OBJECTIF ACHETÉ" (spoken "Sixième objectif acheté") and "<set> est votre objectif 6." and marks the control for the guard.
- [x] `app/frontend/controllers/goal_control_controller.ts` (+ a pure helper in `app/frontend/lib/goal_control.ts` with `.test.ts`) -- refocus only after a stream whose target is the control, focusing its `.goal-button`; after a bought control renders, ignore submits of the goal form for 400 ms -- so a dialog refusal never steals focus and a repeated press never removes the goal just bought.
- [x] `library_controller.rb#show`, `library/_entry`, `_custom_sets.html.erb` -- `@custom_set_slot` offer; with an offer the new set tile is an `<a class="new-set-tile">` to the purchase (`capacity: "custom-sets"`), described by the price line beside the count, the section adding `purchase-dialog` and the dialog; the editor renders with `open` when `flash[:slot_bought] == "custom_set"`; CSS so the link tile looks as the button tile.
- [x] `deck_list.rb` (`slot_offer`), `duels/_decks.html.erb`, `decks/_editor.html.erb` -- at a free limit with an offer, "+ NOUVEAU DECK" links to the purchase (`capacity: "decks"`), described by the price line beside the heading count, the panel adding `purchase-dialog` and the dialog; no refusal line then; the deck name field gets `autofocus` when `flash[:slot_bought] == "deck"`.
- [x] CSS (`collection-goals.css`, `collection-custom-sets.css`, `duels.css`, `market-shop.css` for `.purchase-confirmation__lead`) -- tokens only.
- [x] Locales en + fr -- `slot_purchases.*` (titles, ordinals 4–10 visible and in words, lead lines, short line, loading, throttled, bought lines), the price line, `goals.bought.*`.
- [x] Tests -- `test/domains/game/buy_slot_test.rb` (every matrix row; a double submission charges once; the goal step's refusal leaves no row, ledger entry, wallet change or event); `test/domains/game/slot_offer_test.rb`; `test/controllers/slot_purchases_controller_test.rb` (visitor refused; confirmation facts, title, lead, price, balance after; short with and without CONFIER DES CARTES; slot taken shows "Cet emplacement est déjà acheté."; changed price redrawn with the settings line; goal stream with "OBJECTIF 6 · RETIRER"; custom set and deck redirects with the editor open or autofocused; throttle; no database ids); additions to `goals_controller_test.rb`/`library_set_test.rb`, `library_controller_test.rb` (query count if it moves), `duels_controller_test.rb` (opener and price line at a free limit, today's refusal at the ceiling); `test/system/capacity_slots_test.rb` (Verify: five goals → MARQUER COMME OBJECTIF → ACHETER → the album shows OBJECTIF 6 and the Collection OBJECTIFS 6 / 6; three decks → + NOUVEAU DECK → ACHETER → the deck editor); vitest for the goal control helper.

**Acceptance Criteria:**
- Given a player with five goals, 1 000 PiCoins and an open market, when they press MARQUER COMME OBJECTIF on an album and ACHETER · 500, then the button reads "OBJECTIF 6 · RETIRER", the status line says the sixth goal is bought, and the Collection reads OBJECTIFS 6 / 6.
- Given a player with three decks, when they press "+ NOUVEAU DECK" and buy the fourth slot, then the new deck's editor opens with its name field focused.
- Given a player with five custom sets, when they buy the sixth slot from the new set tile, then the Collection shows the custom set editor open on its name field.
- Given a suspended market and a player short of PiCoins, when they open the dialog, then it gives the missing amount with ANNULER alone.
- Given ten goals, when the player presses MARQUER COMME OBJECTIF, then today's refusal shows and no dialog opens.

## Implementation Notes

- Built by one implementing subagent from this plan; the orchestrating session read the diff and reran the targeted tests and checks.
- The goal insertion lives in `GoalSteps#goal_inserted`, shared by `AddGoal` and `BuySlot`; `SlotPurchasesHelper` holds the ordinal, title and bought-line words.
- `load_goal_control` now reads `Capacity.limit` on every album: `library_set_test.rb` query counts rose by one (24 → 25, 23 → 24).
- The goal-button additions went into `test/controllers/library_goals_test.rb`, which holds those tests.
- The dynamic `slot_purchases` keys are listed under `ignore_unused` in `config/i18n-tasks.yml`.
- `PicoinAmountComponent` leaves trailing whitespace, so the price line renders "coûte 500 ." with a space before the period; shared component, left as is.

## Plan Change Log

## Review Triage Log

## Design Notes

- The slot kind travels as `capacity` in the path because a goal's aim already uses `kind` and `key`.
- No settings version at all means no price: `SlotOffer` is nil and the screens keep today's refusal; with a version, a closed or suspended market still sells slots (short: ANNULER alone, since Confier is closed).
- The double submission and the other tab are the same case: the purchase is keyed to the slot number under the bank lock, so the second call meets `:slot_already_bought`.

## Verification

**Commands:** (export `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_h PARALLEL_WORKERS=4`; create it with `RAILS_ENV=test bin/rails db:create db:schema:load` if missing)
- `bin/rails test test/domains/game/buy_slot_test.rb test/domains/game/slot_offer_test.rb test/domains/game/goal_operations_test.rb test/domains/game/capacity_test.rb test/domains/game/market/reconcile_wallets_test.rb test/controllers/slot_purchases_controller_test.rb test/controllers/goals_controller_test.rb test/controllers/library_controller_test.rb test/controllers/library_set_test.rb test/controllers/custom_sets_controller_test.rb test/controllers/duels_controller_test.rb test/controllers/decks_controller_test.rb test/controllers/market/archive_purchases_controller_test.rb test/controllers/read_only_requests_test.rb test/components` -- expected: green
- `npm run test:js`, `npm run format:check`, `npm run lint:css` -- expected: pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec rubocop` on touched Ruby files, `bundle exec i18n-tasks missing` -- expected: pass
- Do not run the full suite or any system test (the orchestrator runs them); write `test/system/capacity_slots_test.rb` anyway.

## Auto Run Result

- **Summary:** `Game::BuySlot` buys exactly the next goal, custom set or deck slot under the bank lock then the capacity row, refusing `:slot_ceiling`, `:slot_already_bought`, `:amounts_changed`, `:more_than_available` and, for a goal, the goal step's code (`:goal_already_set` included) with everything rolled back; it posts `slot_purchase` (destroyed) and publishes `SlotBought`, never asking whether the market is open. `Game::SlotOffer` gives the next slot and its price at a free limit. MARQUER COMME OBJECTIF, the new set tile and "+ NOUVEAU DECK" open the slot purchase dialog (`PurchaseConfirmationComponent` with a new `lead` slot); bought, the goal control redraws as OBJECTIF n with a polite status line and a 400 ms guard, the custom set editor opens on the Collection, or the new deck's editor opens with its name focused.
- **Files:** `buy_slot.rb`, `slot_offer.rb`, `goal_steps.rb`, `add_goal.rb`; `slot_purchases_controller.rb`, `slot_purchase_policy.rb`, `slot_purchases_helper.rb`, `config/routes.rb`; views `slot_purchases/*`, `goals/_control`, `library/{set,show,_entry,_custom_sets}`, `custom_sets/{show,_editor}`, `duels/_decks`, `decks/_editor`; `purchase_confirmation_component.{rb,html.erb}`; `goal_control_loading.rb`, `goals_controller.rb`, `library_controller.rb`, `deck_list.rb`; `goal_control_controller.ts`, `lib/goal_control.ts` (+ test); CSS `collection-goals`, `collection-custom-sets`, `duels`, `market-shop`; `en.yml`, `fr.yml`, `i18n-tasks.yml`; tests `buy_slot_test`, `slot_offer_test`, `slot_purchases_controller_test`, additions to goals, library goals, library set, custom sets and duels controller tests, `test/system/capacity_slots_test.rb`.
- **Review:** none, no lenses launched (the author's choice: one review pass at the end of the epic).
- **Verification:** targeted Ruby tests 377 runs, 0 failures (`gameble_test_h`, `PARALLEL_WORKERS=4`); implementer: `npm run test:js` 1555 passed, typecheck, `zeitwerk:check`, rubocop on touched files, `i18n-tasks missing`, `check_markup_apis` pass; rerun here: `check_planning_references`, `check_file_sizes`, `packwerk check`, `format:check`, `lint:css` pass. System test written, not run.
- **Residual risks:** nothing seen in a browser (the morph closing the modal, the 400 ms guard, focus after purchase); the price line's space before the period; the bought line reads the goal's position, which equals the slot except on a stale tab; the copy awaits the author's approval with the rest of the market-volume copy.
