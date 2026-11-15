---
title: 'A player builds a deck of twelve cards in the deck editor'
type: 'feature'
ticket: '3'
created: '2026-11-15'
status: 'built'
baseline_revision: 'ad7a35b8a96e5df49b121f8cebc741ef6f17828b'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/duel-rules.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Deck-blocked copies read as "in a trade" on the collection grid, the set album and the card page until Game::ReservedCopies gains the in-deck share.
    evidence: |-
      This story raises game_holdings.reserved for a decked edition, and Game::ReservedCopies computes in_trade as reserved minus listings; the epic gives the in-deck share to the story naming deck cards on the trade, sale and entrust screens. Staging only: release 1.4 ships the epic together.
    location: >-
      app/domains/game/app/queries/game/reserved_copies.rb
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Players cannot build decks yet: the duels epic needs up to five named decks of twelve owned cards per player, each card blocking one copy of its edition, edited in a rich screen that saves every change at once.

**Approach:** One migration creates `game_decks` and `game_deck_cards`; five `Game` operations (create, rename, add a card, remove a card, delete) take `player:`, run under the bank lock in AD-10's order and keep `game_holdings.reserved` in step; a deck editor screen at `/:locale/duels/decks/new` and `/:locale/duels/decks/:token` (owner-only policy, rate-limited JSON POSTs) with one root Stimulus controller and its state module `app/frontend/lib/deck_editor.ts`; `ReleasePlayer` and the export learn decks.

## Boundaries & Constraints

**Always:**
- Tables: `game_decks` (`token` 24 base58 unique, `player_id` FK `accounts_players`, `name` not null, check `char_length(name) BETWEEN 1 AND 24`, unique index on `(player_id, lower(name))`, timestamps); `game_deck_cards` (`deck_id` FK `on_delete: :cascade`, `card_season_id` FK `catalog_card_seasons`, `card_id` FK `catalog_cards` (the card-season's card), `slot` smallint check `BETWEEN 1 AND 12`, timestamps), unique `(deck_id, slot)` and `(deck_id, card_id)`, index on `card_season_id`. No later story migrates them.
- Operations (`Game::CreateDeck`, `RenameDeck`, `AddCardToDeck`, `RemoveCardFromDeck`, `DeleteDeck`) each: `require_player`, then in one `transaction`: `lock_bank`, lock the deck row (`FOR UPDATE`, by token, scoped to the player), then the player's deck cards involved, then the holding (`TradeLocks.holdings`), then write, then publish exactly one event to `stream_name(player.id)` with ids only (`Game::DeckCreated`, `DeckRenamed`, `DeckCardAdded`, `DeckCardRemoved`, `DeckDeleted`; no subscriber). A no-op (same name, adding an edition already in this deck, removing one not in it) succeeds with no write and no event, so a replayed save is harmless.
- Refusal codes (all under `errors.game`, both locales): `too_many_decks` (5 already), `deck_name_required`, `deck_name_too_long` (> 24 after the custom-set name normalisation), `deck_name_taken` (case-insensitive, the player's decks only), `deck_not_found`, `card_not_owned` (no holding with quantity > 0), `not_yet_ranked` (no `Game::DuelProfiles` row, or its discovery stat has no value), `deck_full` (12 cards), `game_already_in_deck` (another edition of the same card), `no_free_copy` (quantity − reserved < 1 and the edition is in no other deck of the player).
- `reserved`: +1 when an edition enters the player's first deck, −1 when it leaves the last (remove or delete); exact relative SQL updates, never clamped. `DeleteDeck` lowers it once for each of its editions held by no other deck.
- `CreateDeck(player:, name: nil)`: a blank/nil name gives `"Deck <n>"`, n the lowest positive integer not used by the player's deck names; an explicit name is validated as rename does.
- Add puts the card in the lowest free slot. Remove leaves its slot empty.
- Reads go through Game/Catalog queries (`HeldCopies`, `Catalog::CardViews`, `DuelProfiles`, new deck queries); the stats are read only through `Game::DuelProfiles`.
- Screen: one root controller + state module; children dispatch intents and are driven through outlets; markup cloned from server `<template>`s; no `style` attribute; no DB ids anywhere (decks by token, editions by ref `slug:season`); labels sentence case in locales, capitals by CSS; every string in `en.yml` and `fr.yml` (French plural keys with `zero`, French typography test).
- Saving: every change is applied on screen at once and sent at once, one request at a time in order. A network error, 5xx or 429 keeps the change on screen, posts "Enregistrement impossible, réessayez." and keeps it pending; the next change resends the pending ones first. A 422 refusal reverts that change and posts the refusal's message (the name refusals inline under the field instead).

**Never:** no Duels screen, deck list, "◀ DUELS", tab, sort, filter, coverage, arrows, COMPLÉTER LES MANQUES, `ReservedCopies`/`DecksHolding`/`RemoveFromDecks` or changes to trade/sale/entrust screens (entries 2, 4, 5); no write from a GET; no React or script-built markup; no planning ids in code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First deck entry | edition owned ×1, reserved 0, in no deck | added to slot 1; reserved 1; `DeckCardAdded` | — |
| Second deck | same edition added to a second deck | added; reserved stays 1 | — |
| Leaves one of two | removed from deck A, still in B | reserved stays 1 | — |
| Leaves the last | removed from B | reserved 0 | — |
| Fully reserved | owned ×1, reserved 1 by a trade, in no deck | — | `Failure(:no_free_copy)`; editor shows the Reserved tag, card `aria-disabled` |
| Fully reserved but decked | owned ×1, reserved 1 by deck A | add to deck B succeeds | — |
| No stats | edition with no row, or row without discovery value | — | `Failure(:not_yet_ranked)`; editor shows "Stats lundi", card `aria-disabled` |
| Second edition | deck holds Portal S1, add Portal S2 | — | `Failure(:game_already_in_deck)`; client refuses before sending with "Ce jeu est déjà dans le deck." |
| 13th card | deck has 12 | — | `Failure(:deck_full)`; client refuses with "Le deck est complet." |
| Sixth deck | player has 5 decks | — | `Failure(:too_many_decks)`; `/decks/new` shows "Cinq decks au plus : supprimez-en un pour en créer un autre." and no editor |
| Name refused | "", 25 chars, a name the player uses ("vieux" vs "Vieux") | inline line under the field, saved name unchanged | `deck_name_required` / `deck_name_too_long` / `deck_name_taken` |
| Delete | deck with 3 editions, one also in another deck | deck and cards gone; reserved lowered for the 2 held by no other deck | — |
| Not the owner | another player's token on GET/PATCH/POST/DELETE | 403 (JSON 403 for JSON) | Pundit refusal |
| Failed save then next change | add A fails (network), then add B | A stays shown; status "Enregistrement impossible, réessayez."; on B, A is resent then B | — |
| Account deletion | player with decks | decks and cards deleted before holdings | — |
| Export | player with a deck | `decks: [{ name, cards: [{ slug, season }] in slot order }]` | — |

</intent-contract>

## Code Map

- `db/migrate/20261115120000_create_game_decks.rb` -- both tables in one migration (new tables carry checks inline); template `db/migrate/20261031100000_create_game_custom_sets.rb`. Regenerate `db/schema.rb` as AGENTS.md says (test DB only; never touch the development DB).
- `app/domains/game/app/models/game/deck.rb`, `deck_card.rb` -- `has_secure_token :token, length: 24`, `NAME_LIMIT = 24`, `SLOTS = 1..12`, `PER_PLAYER = 5`; `has_many :cards, class_name: "Game::DeckCard", inverse_of:`; bare `player_id`/`card_season_id`/`card_id` columns (Game style, see `custom_set.rb`, `custom_set_game.rb`).
- `app/domains/game/app/operations/game/` -- the five operations plus `deck_steps.rb` (shared steps: clean name, name free, locked deck, locked holding, reserve/release, publish). Templates: `create_custom_set.rb`, `edit_custom_set.rb`, `delete_custom_set.rb`, `custom_set_steps.rb` (`clean_name`/`visible` normalisation: reuse it, extracting a shared module only if custom-set behaviour stays identical), `operation.rb` (`require_player`, `lock_bank`, `stream_name`), `models/game/trade_locks.rb` (`TradeLocks.holdings`), `market/list_card.rb` (`free_copy`, relative `reserved` update), `add_goal.rb` (`next existing` no-op).
- `app/domains/game/app/events/game/deck_*.rb` -- empty `RubyEventStore::Event` classes; nothing to register in `config/initializers/event_store.rb`.
- `app/domains/game/app/queries/game/` -- `deck_by_token.rb` (any player's deck, for the policy; String tokens only, as `custom_set_by_token.rb`), `player_decks.rb` (count and names), `deck_slots.rb` (slot → card_season_id), `decked_editions.rb` (card_season_ids in the player's decks other than a given one). Reuse `held_copies.rb` (`Row#free`), `duel_profiles.rb`, `Catalog::CardViews.call(ids, locale:)`, `market/entrustable_copies.rb` `ref`/`resolve` (`slug:season` refs; reuse, or move to a neutral spot if the Game→Market reference reads wrong).
- `app/domains/game/app/operations/game/release_player.rb` -- delete `DeckCard`/`Deck` before `Holding` (line ~24). Tests `test/domains/accounts/delete_player_test.rb:117`.
- `app/domains/game/app/queries/game/export_of.rb` (rows 20-29, `custom_sets` 138-144) and `app/models/player_export.rb` (`to_h` 20-56) -- add `decks`. Tests `test/domains/game/export_of_test.rb`, `test/models/player_export_test.rb` (`SECTIONS` 13-15 lists every key).
- `config/routes.rb` (inside `scope ":locale"`, near custom sets line 81) -- `resources :decks, path: "duels/decks", only: %i[new create show update destroy], param: :token, constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }` with member `post :cards` / `delete :cards` (ref in the body) to a `DeckCardsController` or member actions.
- `app/controllers/decks_controller.rb`, `deck_cards_controller.rb` -- Pundit on every action (`authorize(deck || :deck, policy_class: DeckPolicy)`); JSON answers: success `{ token:, url:, name:, slot:, count: }` as relevant, refusal `{ error: { code:, message: } }` 422 with `Op.failure_message(code)` (`showcases_controller.rb:47-79`); `rate_limit to: 60, within: 1.minute, by: -> { current_player&.id || request.remote_ip }, with: -> { 429 JSON throttled }` on the POST/PATCH/DELETE JSON actions (`market/bids_controller.rb:5`); `destroy` is an HTML form after the dialog, redirects `see_other` to `new_deck_path` with a toast (`custom_sets_controller.rb:54-62`; entry 2 will redirect to the Duels screen). `new` with 5 decks renders the five-deck line. Keep each file < 400 lines; put the view-model assembly in a helper (`app/helpers/deck_editor_helper.rb`) or a PORO in `app/models/`.
- `app/policies/deck_policy.rb` -- `new?`/`create?`: `player?`; others: `record.is_a?(Game::Deck) && record.player_id == player.id`. Pattern `app/policies/custom_set_policy.rb`; test `test/policies/custom_set_policy_test.rb`.
- `app/helpers/shell_helper.rb:39` -- `SCREEN_LABELS` entry for the decks controller (`shell.screens.decks` "Deck"). No tab active yet (entry 2). No back link (entry 2 adds "◀ DUELS").
- `app/views/decks/` -- `new.html.erb`/`show.html.erb` sharing `_editor.html.erb`: root `id="deck-editor"` wired with `screen_actions`/`screen_outlets`/`screen_strings` (`app/helpers/screen_wiring_helper.rb`, `market_entrustments_helper.rb:1-17`); name field (label "Nom du deck", no `maxlength`, inline refusal `<p>` tied by `aria-describedby`); summary line (name + "<n> / 12", "n sur 12" visually hidden) sticky at the top on the phone; `<ol>` of 12 slots (filled: button "Retirer <card> du deck" with thumbnail + name; empty: dashed frame); polite status `<p role="status">`; collection list (one row per owned edition: thumbnail `<img loading=lazy>` from `CardView#image_url`, title, `SeasonMarkComponent` "S1", "Atout · <stat>" or "Stats lundi", right "Dans le deck"/"Ajouter" or the Reserved tag `t("trades.side.reserved", count: 1)` style; button `tabindex=-1` roving, `aria-pressed`, `aria-disabled` when unavailable, name ending ", dans le deck"); `<template>`s for a filled and an empty slot; "Supprimer le deck" `ButtonComponent variant: :danger` opening a confirm dialog (`custom_sets/_delete_dialog.html.erb` pattern; hidden until the deck exists).
- `app/frontend/lib/deck_editor.ts` (+ `.test.ts`) -- immutable state (deck token|null, name, slots[12] of ref|null, entries by ref {game, name, available, reason}, pending queue, active ref) and pure reducers: `choose(ref)` → add/remove/refusal (`full`, `same_game`, `unavailable`), `removeSlot(n)`, `rename`, `saved`, `failed`, `refused` (revert), `nextToSend` (pending in order; create first when token is null), `move(key, columns)` via `lib/grid_keys.ts` `nextIndex`.
- `app/frontend/lib/deck_editor_save.ts` (+ `.test.ts`) -- `sendChange({ url, method, body, csrfToken, fetch? })` → `{kind:"saved", body} | {kind:"refused", code, message} | {kind:"failed"}`; pattern `lib/showcase_order.ts:36-77`, `csrfToken()` from `lib/booster_page.ts:51`.
- `app/frontend/controllers/deck_editor_controller.ts` (root) and children `deck_name_controller.ts`, `deck_slots_controller.ts`, `deck_collection_controller.ts` -- pattern `entrust_controller.ts` + `entrust_grid_controller.ts` (`render(view)`, `focusActive()`, `dispatch("toggle")`, move handling 65-90); `lib/templates.ts` `cloneFirstElement`, `lib/dom_writes.ts` `writeText`/`writeData`; status re-announce trick `showcase_order_controller.ts:228-231`. After the first create: `history.replaceState` to the deck's URL and set the delete form's action. Register controllers as the app does (check `app/frontend/controllers/index`/entrypoint).
- `app/frontend/styles/deck-editor.css` (+ import in `app/frontend/entrypoints/application.css` beside `duel-profile.css`) -- DESIGN.md Duels › Deck editor: slots 4 × 3 desktop, 3 × 4 phone, 8px gap, empty slot dashed `--color-dim` on `--color-panel-sunken`; "<n> / 12" outlined `--color-dim` in `--color-muted`; collection rows ≥ touch-min; tokens only; < 500 lines.
- `config/locales/en.yml`, `fr.yml` -- `decks:` block and `errors.game` codes (Design Notes).
- Tests: `test/domains/game/deck_operations_test.rb` (+ split files if long; template `custom_set_operations_test.rb` `writes`/`assert_refused`, helpers `test/support/holdings.rb` `hold`, `game_sets.rb` `published_cards`, `second_season.rb`, `catalog_seeds.rb`; build stats with `Game::ComputeDuelStats.new.call(reason: "first", now:).value!`, unpulled card as `compute_duel_stats_test.rb:83-97`), `test/models/game/deck_test.rb` or a DB-check test (insert violating rows → `ActiveRecord::StatementInvalid`), `test/controllers/decks_controller_test.rb` (owner, other player 403, visitor, JSON refusals en/fr, throttle via `test/support/counting_rate_limit.rb`), `test/policies/deck_policy_test.rb`, `test/system/deck_editor_test.rb`, vitest files above. Never name a model in a test class body.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261115120000_create_game_decks.rb`, `db/schema.rb` -- tables, checks, indexes; regenerate schema from migrations on the test DB -- storage
- [x] `app/domains/game/app/models/game/deck.rb`, `deck_card.rb` -- models and limits
- [x] `app/domains/game/app/operations/game/{create_deck,rename_deck,add_card_to_deck,remove_card_from_deck,delete_deck,deck_steps}.rb`, `events/game/deck_*.rb` -- the five changes, lock order, reserved, one event each
- [x] `app/domains/game/app/queries/game/{deck_by_token,player_decks,deck_slots,decked_editions}.rb` -- reads for the screen and the policy
- [x] `release_player.rb`, `export_of.rb`, `app/models/player_export.rb` -- deletion and export
- [x] `config/routes.rb`, `app/controllers/decks_controller.rb`, `deck_cards_controller.rb`, `app/policies/deck_policy.rb`, `app/helpers/shell_helper.rb`, `app/helpers/deck_editor_helper.rb` -- addresses, JSON answers, rate limit, policy
- [x] `app/views/decks/*` -- the screen per Code Map and board 8 (no coverage/sort)
- [x] `app/frontend/lib/deck_editor.ts`, `deck_editor_save.ts`, `app/frontend/controllers/deck_*_controller.ts` -- state, saving queue, keyboard, focus, status
- [x] `app/frontend/styles/deck-editor.css`, `entrypoints/application.css` -- styles
- [x] `config/locales/en.yml`, `fr.yml` -- copy
- [x] tests per Code Map -- every matrix row, the DB checks, the lock order (record the SQL of an add and a delete with `ActiveSupport::Notifications` and assert the deck/deck-card `FOR UPDATE` precede the holding `FOR UPDATE`, all after the advisory lock), the export, the drop at deletion, owner-only policy, vitest retry of a failed save

**Acceptance Criteria:**
- Given a signed-in player owning twelve ranked games and a second edition of one of them, when they open `/en/duels/decks/new`, add twelve cards, name the deck, try the second edition and a thirteenth card, take a card out by its slot and delete the deck after its confirmation, then the refusals read "This game is already in the deck." / "The deck is full.", the slot empties, and after deletion the editor offers every card again with no Reserved tag (`test/system/deck_editor_test.rb`).
- Given a pending failed save, when the player makes another change, then the state module resends the failed change before the new one (vitest).
- Given focus on a collection card, when it is added or removed, then focus stays on it; when a slot's card is removed, focus moves to the next filled slot, or the collection's first card; arrow keys move within the collection, which is one tab stop.

## Implementation Notes

- Name cleaning: `CustomSetSteps#visible` moved unchanged into `Game::VisibleName.call`; the custom-set steps call it, so their behaviour is identical (custom-set tests green).
- Refs: `Game::Market::EntrustableCopies.ref`/`.resolve` reused as-is (the sales controller already does); no neutral module was extracted.
- Operations take `card_season_id:`; the controller resolves the `slug:season` ref and answers `card_not_owned` for a ref no edition matches. Add/remove return `Game::DeckSteps::Placed(slot, count)`; the JSON is `{ slot:, count: }`.
- Check order in `AddCardToDeck`: owned → ranked → same game → full → free copy. The client checks same game before full too.
- Lock order: advisory bank lock, deck `FOR UPDATE`, this deck's cards `FOR UPDATE`, the player's other decks' cards for the editions `FOR UPDATE`, then holdings through `TradeLocks.holdings`. The test records the SQL of an add and a delete.
- `game_decks.player_id` has no plain index: the unique `(player_id, lower(name))` index covers it. `game_deck_cards.deck_id` is covered by the two unique indexes.
- An unknown token: HTML → 404, JSON → the operation answers 422 `deck_not_found`. Another player's token → 403 (JSON 403 for JSON).
- `destroy` is an HTML form, so it is throttled with `throttle_player` (redirect with `decks.throttled`); create/update and the card POST/DELETE use the 429 JSON `rate_limit`. Both count against the same per-player key in `DecksController`.
- A refused creation: by a name code, the inline refusal shows and, if cards wait, the creation is retried without a name (default "Deck n"); by any other code (`too_many_decks`), every waiting change is taken back. 403 and other non-422 answers count as a failed save (kept, resent).
- The view model is a PORO, `app/models/deck_editor.rb`. An edition already in this deck is always choosable, so taking it out is never blocked by its own reservation.
- The collection renders with `render partial: collection:` for speed; rows are `<li>` with a full-row toggle `<button>` (board 8 row shape: thumbnail, title, then "S<n>" and "Atout · <stat>", the action on the right). `SeasonMarkComponent` is absolutely positioned by default, so it is set to `position: static` inside a row.
- The delete dialog's copy is split in two: title "Supprimer le deck « %{deck} » ?" and text "Les cartes restent dans votre collection.".
- Added copy that was not in the plan (assumptions): `decks.throttled`, `decks.editor.empty_collection` ("Aucune carte dans votre collection pour l'instant."), and the dialog's "Fermer"/"Close".
- Surprise: `test/controllers/accounts_controller_test.rb` requires every table naming a player to appear in the deletion copy. "vos decks"/"your decks" was added to `settings…delete_dialog.note` and to the privacy page's `deletion` paragraph, in both locales.
- Surprise: packwerk's ERB parser rejects the `editor:` shorthand before `%>`, so the views spell `editor: editor`.
- The status region stays rendered when empty (never `display: none`), so screen readers announce its first message.
- Known failure, not this story's: `test/controllers/library_controller_test.rb:93` expects the rarity legend's "All seasons" column that `f22bf3b7` removed.

## Plan Change Log

## Review Triage Log

### 2026-11-15 — Review pass
- verdicts: 38 findings — high 0, medium 2, low 28, false 4, maybe-false 4
- findings:
  - `[medium]` `[patch]` (verification-gap) No test shows an edition blocked by another deck renders available in the editor (`DeckEditor#availability`, `DeckedEditions`) — controller test added: one copy in deck A, the editor shows it enabled with "Add".
  - `[low]` `[patch]` (verification-gap) The card POST/DELETE throttle has no test — throttle test extended to card changes against one shared counter (see the rate-limit row below).
  - `[low]` `[patch]` (verification-gap) The "decks" screen label is missing from the shell label table — rows added to `shell_helper_test.rb`.
  - `[low]` `[patch]` (verification-gap, other) `rate_limit` is keyed per controller, so decks and deck cards each allow 60 (120 a minute) against the concern's sixty — one shared `scope:` in `limit_deck_changes`.
  - `[low]` `[patch]` (intent) The system test names the deck with Enter; the blur save is never exercised — the test now leaves the field.
  - `[low]` `[reject]` (intent) Retry of a failed save is exercised only in vitest, and a replayed create is not idempotent — same root cause as the blind-hunter create-replay row; the state module's retry is the intent's named test surface.
  - `[low]` `[reject]` (intent) The phone summary line is not tested at phone width — CSS sticky only, checked by screenshot during the build; a phone-width system test adds a window-size dance for one CSS rule.
  - `[low]` `[reject]` (intent) Focus after a deletion does not reach "the deck list's heading" — there is no deck list until the DUELS story; that story's Duels screen takes the redirect and the focus.
  - `[low]` `[reject]` (intent) Only the editor's subset of the Copy deck's Decks row is in the locales, and "Deck <n>" is a Ruby constant — the other strings belong to the Duels screen and deck-blocked trade screens of later stories; unused keys would sit dead; "Deck <n>" reads the same in both languages.
  - `[false]` `[reject]` (intent) The coverage strip and COMPLÉTER LES MANQUES of DESIGN.md are not drawn — the epic gives them to the sort-and-gaps story; the ticket's own list does not name them.
  - `[low]` `[patch]` (intent) The lock-order test covers add and delete, not remove — remove added to the recorded changes.
  - `[low]` `[patch]` (intent) The card throttle is not exercised — same root cause as the rate-limit row; same fix.
  - `[low]` `[reject]` (intent) Account deletion's order (decks before holdings) is asserted by outcome only — no constraint fails either way; the order matters only for locks, all taken under the bank lock first.
  - `[false]` `[reject]` (intent) An edition held only in another deck shows available, not Reserved — that is the rule (no_free_copy waived when already in another deck).
  - `[low]` `[patch]` (blind-hunter) `saved()` ignores the server's slot; after a refused add, later adds sit in other slots on screen than on the server until reload — a saved add now swaps its ref into the server's slot; vitest added.
  - `[low]` `[reject]` (blind-hunter) A create whose answer is lost after it committed is resent and makes a second deck — needs a client idempotency key (new public parameter); it takes a lost response at exactly that moment, and the extra deck can be deleted. Residual risk.
  - `[low]` `[patch]` (blind-hunter) The two controllers each count sixty — same root cause as the verification-gap rate-limit row; same fix.
  - `[low]` `[reject]` (blind-hunter) A 401/403/429 is kept and resent; the throttled message is not shown — the save-failed line is the intent's wording for any failed save; a signed-out player reloads to sign in; new branches for rare cases.
  - `[low]` `[reject]` (blind-hunter) A failed save is retried only by the next change, with no leave warning — exactly the intent's rule ("retried with the next change"), and the failure line stays on screen.
  - `[medium]` `[defer]` (blind-hunter) Deck-blocked copies read as "in a trade" on the collection grid, the set album and the card page until `Game::ReservedCopies` gains the in-deck share — the epic gives `ReservedCopies` to the deck-cards-on-trade-screens story; staging only (release 1.4 ships the epic together).
  - `[low]` `[reject]` (blind-hunter) The five-deck page links to no deck and nothing links to the editor — the epic's decision: until the Duels screen story lands the editor is reached at its own address; that story adds the list.
  - `[low]` `[reject]` (blind-hunter) `game_deck_cards.card_id` is not forced to match the card-season's card; no index leads with `card_id` — only the operations write it, from the card-season; a composite foreign key needs a unique index on the catalog table; catalog cards are not deleted in play.
  - `[low]` `[patch]` (blind-hunter) The ranked rule is written twice (operation and editor) — one `DuelProfiles::Profile#ranked?` used by both.
  - `[low]` `[patch]` (blind-hunter) Duplicate `.deck-entry__action` and season-mark rules; "Add" is never in the accent — one rule, accent for "Add", muted when pressed, duplicate deleted.
  - `[low]` `[patch]` (blind-hunter) `data-in-deck` unused and `count_hidden` duplicated — both removed; the double entry targets are kept (the root reads them to start its state).
  - `[low]` `[reject]` (blind-hunter) The card ref is resolved before the deck, and through a Market query — an unknown token with a bad ref answers `card_not_owned` rather than `deck_not_found`, both refusals; the plan allowed reusing the ref helper.
  - `[low]` `[reject]` (blind-hunter) `ReleasePlayer` deletes deck cards explicitly beside the cascade; the token regex is repeated in routes — cosmetic.
  - `[low]` `[reject]` (blind-hunter) The tab title keeps "Deck" or the old name after a create or rename — cosmetic; the in-page summary line and heading follow.
  - `[low]` `[reject]` (blind-hunter) `flush()`, `DeckEditor` and the helper have no unit tests; the export has no timestamps — the system test drives `flush()` end to end; the editor's availability gets a controller test (above); the intent lists name and cards for the export.
  - `[low]` `[patch]` (edge-case) Slot drift after a refused add — same root cause as the blind-hunter slot row; same fix.
  - `[maybe-false]` `[reject]` (edge-case) A replayed create makes a second deck — same root cause as the blind-hunter create row; low if true.
  - `[maybe-false]` `[reject]` (edge-case) Unsaved changes lost on leaving with no warning — same as the blind-hunter retry row; the intent's rule, low if true.
  - `[maybe-false]` `[reject]` (edge-case) A 401 is retried forever — same as the blind-hunter 401/403 row; low if true.
  - `[low]` `[patch]` (edge-case) Two counters of sixty — same root cause as the rate-limit row; same fix.
  - `[false]` `[reject]` (edge-case) A refused removal after its slot was reused drops a card the server still holds — a removal is refused only when the deck is gone (`deck_not_found`); a removal of a card not there succeeds.
  - `[maybe-false]` `[reject]` (edge-case) A slotted card-season with no `CardView` shows an empty slot — only a card with no rarity (never ranked, cannot enter) or no text in the locale; to settle, check whether every published card has texts in both locales; low if true.
  - `[low]` `[patch]` (edge-case) The CSS duplicates hide the accent — same root cause as the blind-hunter CSS row; same fix.
  - `[false]` `[reject]` (edge-case, claim) One reserved copy per edition rather than per deck card — that is the rule (AD-52, duel-rules: one copy whatever the number of decks).

## Design Notes

Creation (the epic's open question, settled here): `/decks/new` is an empty editor and writes nothing; the deck is created by the first change, named by the field if that change is the name, else "Deck <n>"; the client then switches to the deck's token address. Language-neutral default, so the domain can make it.

Copy (fr / en; `decks.editor.*` unless noted):
- title "Deck"/"Deck"; name label "Nom du deck"/"Deck name"; "<n> / 12" with hidden "%{count} sur 12"/"%{count} of 12"; slots group "Emplacements"/"Slots"; empty slot hidden text "Emplacement vide"/"Empty slot"; slot button "Retirer %{card} du deck"/"Remove %{card} from the deck"; collection "Votre collection"/"Your collection"; row action "Ajouter"/"Add", in deck "Dans le deck"/"In the deck"; trump "Atout · %{stat}" (reuse `duel_stats.trump` and `duel_stats.names.*`); no stats "Stats lundi"/"Stats on Monday"; toggle name suffix ", dans le deck"/", in the deck"; status "%{card} ajoutée, %{count} sur 12"/"%{card} added, %{count} of 12", "%{card} retirée, …"/"%{card} removed, …"; save failed "Enregistrement impossible, réessayez."/"Could not save, try again."; full "Le deck est complet."/"The deck is full."; same game "Ce jeu est déjà dans le deck."/"This game is already in the deck."; delete "Supprimer le deck"/"Delete the deck", dialog "Supprimer le deck « %{deck} » ? Les cartes restent dans votre collection."/"Delete the deck "%{deck}"? The cards stay in your collection.", "Supprimer"/"Delete", "Annuler"/"Cancel"; deleted toast "Deck supprimé."/"Deck deleted." (assumption, not in the Copy deck).
- `errors.game`: `too_many_decks` "Cinq decks au plus : supprimez-en un pour en créer un autre."/"Five decks at most: delete one to make another."; `deck_name_required` "Donnez un nom au deck."/"Name the deck."; `deck_name_too_long` "24 caractères au plus."/"24 characters at most."; `deck_name_taken` "Vous avez déjà un deck de ce nom."/"You already have a deck with this name."; `deck_full`, `game_already_in_deck` as above; `deck_not_found` "Ce deck est introuvable."/"This deck cannot be found."; `not_yet_ranked` "Cette carte aura ses stats lundi."/"This card gets its stats on Monday."; `no_free_copy` "Toutes vos copies de cette carte sont réservées."/"All your copies of this card are reserved."; `card_not_owned` exists in en (check fr). French: narrow no-break space before `:`/`?` per `test/config/french_typography_test.rb`.

The collection renders every owned edition server-side (`HeldCopies` keys → `CardViews` → `DuelProfiles` → `DeckedEditions`), ordered by title then season; plain lazy `<img>` thumbnails rather than `CardComponent` canvases, since a large collection holds thousands of rows. Availability per row: no stats → "Stats lundi"; `free < 1` and not in another deck → Reserved tag; else choosable.

## Verification

**Commands:**
- `docker compose up -d`; `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb` -- only the two new tables in the diff
- `bin/rails test test/domains/game test/domains/accounts test/models test/controllers test/policies test/config` -- green except the known `library_controller_test.rb:119`
- `bin/rails test test/system/deck_editor_test.rb` -- green
- `bin/ci`; `npm run test:js`; `bin/rails zeitwerk:check`; `bundle exec packwerk check`; `npm run format:check`; `npm run lint:css`; `script/check_planning_references`; `script/check_file_sizes` -- green (bin/ci setup may fail on the local development DB's known migration error; not this story's)

## Auto Run Result

**Summary:** players can build up to five named decks of twelve cards. One migration creates `game_decks` and `game_deck_cards` with their checks and unique indexes. Five `Game` operations (create, rename, add a card, remove a card, delete) take `player:` and lock in AD-10's order: bank lock, deck, deck cards, then holdings. Each publishes one event no handler hears, and refuses with a code. An edition holds one `reserved` copy while it is in at least one of the player's decks. The deck editor lives at `/:locale/duels/decks/new` and `/:locale/duels/decks/:token`, and only the owner gets in. A new deck is created by its first change: named by the field if that change is the name, else "Deck <n>". Every change saves at once as JSON, limited to sixty a minute per player. A failed save stays on screen and is resent with the next change. The root controller `deck-editor` holds `app/frontend/lib/deck_editor.ts` and drives three children through outlets. Account deletion drops decks before holdings, and the export lists each deck's name and cards in slot order.

**Files changed**
- `db/migrate/20261115120000_create_game_decks.rb`, `db/schema.rb`: the two tables; the schema is regenerated from the migrations and round-trips.
- `app/domains/game/app/models/game/deck.rb`, `deck_card.rb`: models and limits.
- `app/domains/game/app/operations/game/{create_deck,rename_deck,add_card_to_deck,remove_card_from_deck,delete_deck,deck_steps,visible_name}.rb`, `events/game/deck_*.rb`: the five operations and their events. Name cleaning moved, unchanged, from `custom_set_steps.rb` into `Game::VisibleName`.
- `app/domains/game/app/queries/game/{deck_by_token,player_decks,deck_slots,decked_editions}.rb`, `duel_profiles.rb` (`Profile#ranked?`): reads for the screen, the policy and the add rule.
- `release_player.rb`, `export_of.rb`, `app/models/player_export.rb`: deletion and export.
- `config/routes.rb`, `app/controllers/decks_controller.rb`, `deck_cards_controller.rb`, `concerns/deck_changes.rb`, `app/policies/deck_policy.rb`, `app/helpers/shell_helper.rb`, `deck_editor_helper.rb`, `app/models/deck_editor.rb`: addresses, JSON answers, the shared rate limit, the policy and the view model.
- `app/views/decks/*`: the screen (name field, summary line, 12 slots, status line, collection, delete dialog).
- `app/frontend/lib/deck_editor.ts`, `deck_editor_save.ts`, `app/frontend/controllers/deck_{editor,name,slots,collection}_controller.ts`, `app/frontend/styles/deck-editor.css`, `entrypoints/application.css`: the state, the save queue, keyboard, focus, status and styles.
- `config/locales/en.yml`, `fr.yml`: the `decks:` copy, ten `errors.game` codes, and "vos decks" / "your decks" in the account-deletion copy.
- Tests: the deck and deck-card operations (every rule and code, the lock order of add, remove and delete), the model's database checks, the controller (owner only, JSON refusals in both locales, the shared throttle, an edition blocked by another deck still choosable), the policy, the shell label, the export, account deletion, the system test `test/system/deck_editor_test.rb`, and two vitest files.

**Review:** 38 findings: 2 medium, 28 low, 4 false, 4 maybe-false.
- Patched, 1 medium: no test showed that an edition blocked only by another deck stays choosable in the editor.
- Patched, low:
  - The two controllers counted sixty changes each; they now share one counter, with a test.
  - The shell label test lacked the "Deck" rows.
  - The system test now saves the name on blur.
  - The lock-order test now covers remove.
  - A saved add now moves to the slot the server chose.
  - The ranked rule is one `Profile#ranked?`.
  - The duplicate CSS rules that hid the accent on "Add" are gone.
  - An unused data attribute and a duplicated locale key are gone.
- Deferred, 1 medium: deck-blocked copies read as "in a trade" on the collection, set album and card page until `ReservedCopies` gains the in-deck share. The epic gives that to the trade-screens story.
- Rejected, each with its reason in the triage log:
  - a replayed create that makes a second deck
  - 401/403 kept as a failed save
  - no warning when leaving with a failed save
  - the phone line not tested at phone width
  - focus after deletion (no deck list yet)
  - the Copy deck subset
  - the coverage strip
  - `card_id` not forced by a foreign key
  - ref resolved before the deck
  - cascade beside the explicit delete
  - a stale tab title
  - untested `flush()` and view model
  - a slot with no `CardView`

**Follow-up review recommended:** false. This pass patched no high and one medium.

**Verification:** run on the main checkout after the patches. `bin/ci`'s Setup step was not run: it prepares the development database, which refuses an earlier migration.
- Every other `bin/ci` step was run one by one and passed:
  - rubocop
  - packwerk validate and check
  - `i18n-tasks missing`
  - typecheck
  - markup
  - format
  - CSS lint
  - planning refs
  - file sizes
  - bundler-audit
  - brakeman
  - schema built from the migrations (no diff)
  - schema round trip (no diff)
  - seeds
- `bin/rails test`: 5606 runs, 1 failure. It is the known `library_controller_test.rb:119`.
- `test/system/deck_editor_test.rb`: 2 runs, green.
- `npm run test:js`: 134 files and 1409 tests passed. One earlier run exited 1 on a pre-existing unhandled error in `annonce_controller.test.ts`, also reproduced on the baseline and deferred.
- `bin/rails zeitwerk:check`: all good.

**Residual risks:**
- If a create commits but its answer is lost, the resend makes a second, empty deck. The player can delete it.
- The last change of a session can fail and be left unsaved. The failure line says so, but nothing warns on leaving.
- After a deletion the editor lands on a new deck with a toast; the DUELS story should redirect to the Duels screen and focus the deck list's heading.
- "Deck <n>", "Deck deleted.", the throttle line, the empty-collection line and "Close" are copy assumptions outside the Copy deck.
- Until the trade-screens story lands, a deck card's copy shows "in a trade" outside the editor.
