---
title: "A deck card's copy is named and freed on the trade, sale and entrust screens"
type: 'feature'
ticket: '5'
created: '2026-11-15'
status: 'built'
baseline_revision: '50909e25e483d9462db146b5967be2c7375f63b0'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/duel-rules.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Since decks landed, an edition in a deck holds 1 of its holding's `reserved`, but every screen reads that copy as "in a trade", the owner cannot see which decks block a card on the trade, sale and entrust screens nor free it there, a friend's trade picker still offers a deck-blocked copy, and spare copies are counted three different ways.

**Approach:** `Game::ReservedCopies` gains the in-deck share; `Game::DecksHolding` names the decks holding an edition; `Game::RemoveFromDecks` takes an edition out of every deck of the player; the owner's card picker, Confier and Mettre en vente show the "Dans un deck" tag, "Dans : <decks>" and "RETIRER DES DECKS" (a confirm dialog posting to one HTML endpoint that redirects back); the friend's side treats a deck-blocked copy as absent; one `Game::SpareCopies` feeds suggestions, the market desk and the collection report.

## Boundaries & Constraints

**Always:**
- In-deck share: an edition (card-season) in at least one of the player's decks counts exactly 1, whatever the number of decks. `ReservedCopies::Reserved` becomes `(in_deck, on_sale, in_trade)` per card id (game): `in_deck` = number of the game's editions in a deck; per holding `on_sale = LEAST(listed, reserved - in_deck_flag)`; `in_trade = reserved - in_deck - on_sale`, never below 0.
- "Dans un deck" (en "In a deck") is the Reserved tag of a decked edition; deck names, the tag and "RETIRER DES DECKS" show to the owner only. On a friend's side a decked edition offers `quantity - 1` copies (0 → unavailable, greyed, no tag, no deck name), and the server refuses a request above that (`request_exceeds_holdings`).
- `Game::RemoveFromDecks.call(player:, card_season_id:)`: `require_player`; one transaction: `lock_bank`, the player's decks holding the edition `FOR UPDATE` in ascending id, their deck cards for it `FOR UPDATE` in ascending id, then the holding (`TradeLocks.holdings`), delete those deck cards, lower `reserved` by exactly 1 (relative SQL) when at least one was deleted, publish one `Game::CardRemovedFromDecks` (ids only: player_id, card_season_id, deck_ids) to `stream_name(player.id)`; returns `Success(<number of decks>)`. In no deck → `Success(0)`, no write, no event. A complete deck becomes a draft (no extra state).
- Trade releases (decline, cancel, expire, close, going private) and market releases (cancel, settle) keep subtracting only what they reserved: no code change expected, tests prove it.
- Spare copies of a game = `GREATEST(SUM(quantity - reserved) - 1, 0)` over its held editions with a rarity: one module `Game::SpareCopies` is the only place this rule lives; `Game::Market::PlayerDesk#spare_copies`, the collection report's duplicates (`ReservedCopies.duplicates` today) and the suggestions' spare test (`FreeEditions.copies(editions) >= DUPLICATE_COPIES` in `Spares.from_friends`/`from_player`) all read it. The desk's per-edition `quantity - GREATEST(reserved, 1)` goes away (behaviour change, by AD-52 Costs).
- No database ids in the DOM: editions by ref `slug:season` (`Game::Market::EntrustableCopies.ref`/`.resolve`); dialog ids built from slug and season.
- Server-rendered markup only, no `style`, no markup built in script; every string in `en.yml` and `fr.yml` (French narrow no-break space U+202F before `:` and `?`; plural keys with `zero`); labels sentence case, capitals by CSS.

**Never:** no migration; no change to the deck editor's own rules; no Duels screen, tab or coverage work (entries 2, 4); no card-detail CONFIER/METTRE EN VENTE enabling change (only its reserved words gain the deck share); no change to how trades or listings reserve; no planning ids in code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Deck only | Portal S1 ×1, in deck A | ReservedCopies: in_deck 1, on_sale 0, in_trade 0; collection grid and card page say "Dans un deck" | — |
| Deck + listing + trade | Portal S1 ×4, reserved 3 (deck, 1 listing, 1 trade) | in_deck 1, on_sale 1, in_trade 1 | — |
| Two decks | Portal S1 in decks A and B | tag "Dans un deck" once; "Dans : A, B" in deck creation order | — |
| Remove over two decks | Portal S1 ×1 in A and B (reserved 1) | both deck cards gone, reserved 0, one event; a full A shows 11 / 12 | — |
| Remove, not decked | edition in no deck | Success(0), nothing written | — |
| Remove, unknown ref / signed out | bad ref; visitor | redirect back with the refusal toast (`card_not_owned`); visitor sent to sign in by policy | Pundit / Failure code |
| Friend's side | friend holds Portal S1 ×1 in a deck | pick unavailable (max 0), no tag, no deck name; posting it in `take` | `Failure(:request_exceeds_holdings)` |
| Friend ×2, one decked | friend holds ×2, one in a deck | max 1 | — |
| Owner picker | own Portal S1 ×1 in deck A | pick unavailable, tag "Dans un deck", "Dans : A", "Retirer des decks"; after confirm, page reloads, draft restored, pick available | — |
| Entrust / sale | own decked edition, free 0 | the cell shows (grid now includes decked editions), unavailable, tag + names + action | ListCard / EntrustCards still refuse `copy_not_free`/`insufficient_copies` on a forged post |
| Releases | deck-blocked copy plus a trade or listing on another copy; decline/cancel/expire the trade, cancel/sell the listing, go private | reserved drops only by the trade's/listing's copies; deck block (1) stays; deck untouched | — |
| Spares | ×3 of a game, one in a deck | `SpareCopies` = 1 for suggestions, desk and collection report alike | — |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/reserved_copies.rb` -- add the in-deck share (LEFT JOIN the player's decked card-seasons: `game_deck_cards` JOIN `game_decks` on player, `DISTINCT card_season_id`); `Reserved = Data.define(:in_deck, :on_sale, :in_trade)`; move `duplicates`/`DUPLICATES` out to `SpareCopies`. Tests `test/domains/game/reserved_copies_test.rb` (helpers there: `set_apart`), `test/controllers/collection_reserved_copies_test.rb`.
- `app/views/library/_reserved.html.erb`, `app/helpers/card_details_helper.rb:78-84` (`card_detail_copies`) -- add the in_deck reason first; keys `library.grid.reserved.in_deck`, `card_details.reserved.in_deck` (fr one "Dans un deck", other "%{count} dans des decks"; en "In a deck"/"%{count} in decks"; zero form).
- New `app/domains/game/app/queries/game/spare_copies.rb` -- `Game::SpareCopies`: one SQL per (player, game) over holdings with `quantity > 0` and `catalog_card_seasons.rarity IS NOT NULL`; `.by_game(player_ids, card_ids: nil)` → `{ [player_id, card_id] => spare }` (only positive), `.total(player)` → Integer (0 for nil). Callers: `app/controllers/concerns/collection_grid_loading.rb:137`, `app/domains/game/app/queries/game/market/player_desk.rb` (drop its private `spare_copies`), `app/domains/game/app/queries/game/trade_suggestions/spares.rb` (a game is a spare when `by_game` ≥ 1; keep `FreeEditions` for the placed edition and `copies`). Keep `TradeSuggestions::DUPLICATE_COPIES` only if still read. Tests `test/domains/game/market/player_desk_test.rb:49` (expected count may change), `test/domains/game/trade_suggestion_spares_test.rb`, `trade_suggestions_test.rb`.
- New `app/domains/game/app/queries/game/decks_holding.rb` -- `Game::DecksHolding.call(player, card_season_ids = nil)` → `{ card_season_id => [deck names] }` ordered by `game_decks.created_at, game_decks.id`; `{}` for nil player; nil ids = every decked edition.
- `app/domains/game/app/queries/game/held_copies.rb` -- `Row` gains `in_deck` (Boolean, from an EXISTS on the player's deck cards) and `def offerable = [ quantity - (in_deck ? 1 : 0), 0 ].max`; `free` unchanged. Other constructor: `app/models/deck_editor.rb:29` reads it (no change needed if keyword added in `call`); grep tests building `HeldCopies::Row`.
- New `app/domains/game/app/operations/game/remove_from_decks.rb` + `app/domains/game/app/events/game/card_removed_from_decks.rb` -- per Always; reuse `DeckSteps` (`lock_holdings`, `release_copies`) and `Operation` (`require_player`, `lock_bank`, `stream_name`). Templates `remove_card_from_deck.rb`, `delete_deck.rb`. No subscriber in `config/initializers/event_store.rb`.
- `app/domains/game/app/operations/game/trade_steps.rb:30-33` (`requestable`) -- subtract 1 for each requested edition in one of the holder's decks.
- `app/helpers/trades_helper.rb` -- `trade_card_limit(:friend, row)` → `row.offerable`; friend side `copies` counted with `offerable` (`trade_game_copies(..., count: :offerable)`); `BoardPick` gains `decks` (names Array, own side only, `[]` for friend); `trade_pick_label` adds "dans un deck : <decks>" words when decked. Keep under 400 lines (252 now).
- `app/controllers/trades_controller.rb:202-207` (`load_holdings`) -- `@deck_names = Game::DecksHolding.call(current_player, @own_cards.keys)` passed through `trade_board_editor`/`trade_board_side` (find where `own_held:` flows: `trade_board_locals`, `trade_draft_editor`, views `trades/_draft_board.html.erb`, `_board.html.erb`).
- `app/views/trades/_pick.html.erb` -- for a decked own pick: tag text `t("decks.holding.tag")` instead of the count tag; a foot line "Dans : <decks>" and a `ButtonComponent`/`button` "Retirer des decks" (`type=button`, `data-controller="dialog-opener"`, `data-action="dialog-opener#open"`, `data-dialog-opener-dialog-value=<dialog id>`). Picks are moved (not cloned) between stash and grid (`trade_board_picker_controller.ts:226-240`), so the button keeps working; make sure `trade-board-picker#keydown` (grid) and `#toggle` ignore events whose target is this button (check the handler; add a guard and a vitest if needed).
- New `app/views/decks/_removal_dialog.html.erb` (locals: `ref:`, `title:`, `decks:`) -- a `<dialog class="modal" data-controller="dialog">` like `app/views/decks/_delete_dialog.html.erb`: title `t("decks.removal.title", card:, count:)`, text "Un deck complet redevient un brouillon.", a `form_with url: deck_removals_path, method: :post, data: { turbo: false }` with hidden `ref`, "Retirer"/"Annuler". Render one dialog per decked edition of the player (≤ 60: five decks of twelve), once per screen, OUTSIDE any other `<form>` (a nested form is dropped by the HTML parser) and outside the trade picker dialog: trade board → beside `trades/_picker` (verify the picker is not inside `trade-draft-form`/`trade-counter-form`); entrust → after `form#entrust` inside `market/entrustments/_region.html.erb` (the grid frame sits inside that form); sale → after `#listing-form` in `market/sales/new.html.erb` (the grid frame sits inside that form). A shared partial `decks/_removal_dialogs.html.erb` (locals: `holding:` the `DecksHolding` hash, `titles:` by card_season_id) keeps the three alike; titles via `Catalog::CardViews`/`Game::Market::CardNames`.
- `config/routes.rb:84-88` -- `post "duels/decks/removals" => "deck_removals#create", as: :deck_removals` (before the `:token` routes, or constrained so it never matches a token).
- New `app/controllers/deck_removals_controller.rb` -- `authorize :deck, :remove_card?, policy_class: DeckPolicy` (add `remove_card? = player?` to `app/policies/deck_policy.rb` + test `test/policies/deck_policy_test.rb`); resolve `params[:ref]` with `EntrustableCopies.resolve`, unknown → `card_not_owned`; `throttle_player to: 60` like `decks_controller.rb:5`; `redirect_back_or_to new_deck_path, notice: t("decks.removal.done", card:), status: :see_other` or `alert:` the failure message (`Game::RemoveFromDecks.failure_message`).
- `app/domains/game/app/queries/game/market/entrustable_copies.rb` and `sellable_copies.rb` -- `FROM` keeps `quantity > reserved OR the edition is in one of the player's decks` (EXISTS); `count` follows. `Copy` gains nothing (free may be 0).
- `app/controllers/market/entrustments_controller.rb`, `sales_controller.rb` -- load `@deck_names = Game::DecksHolding.call(current_player)` once when listed (map by ref through `EntrustableCopies.ref` of the copies, or resolve card_season ids). Sales: `choose(@copies.first.ref) if @pagy.count == 1 …` only when that copy's `free.positive?`; `choose` refuses a copy with `free < 1`.
- `app/views/market/entrustments/_cell.html.erb` -- decked cell: tag "Dans un deck", "Dans : <decks>", the "Retirer des decks" button (sibling of the toggle, inside the `li`); free 0 → toggle `aria-disabled="true"` (state in `app/frontend/lib/entrust.ts` already skips `free < 1`; check `entrust_grid_controller.ts` toggle honours it). `entrust_cell_label` adds the deck words.
- `app/views/market/sales/_cell.html.erb` + `_grid.html.erb` -- a decked cell (an `li role=option`) carries the tag and "Dans : <decks>" as text; free 0 → `aria-disabled="true"` and `listing_grid_controller.ts#pick` ignores an `aria-disabled` cell. Interactive content cannot live in an option, so `_grid.html.erb` renders, inside the frame right after the listbox, a list of this page's decked editions: "<title> · S<n>" and the "Retirer des decks" button (labelled with the card) opening its dialog.
- `app/frontend/styles/` -- the tag reuses `.trade-card__reserved`'s look; add small rules for the deck line and button in the existing trade picker, entrust and sale stylesheets (find them via `entrypoints/application.css`); tokens only; each file < 500 lines.
- `config/locales/en.yml`, `fr.yml` -- `decks.holding.tag` "Dans un deck"/"In a deck"; `decks.holding.names` "Dans : %{decks}"/"In: %{decks}"; `decks.holding.remove` "Retirer des decks"/"Remove from decks"; `decks.holding.remove_label` "Retirer %{card} des decks"/"Remove %{card} from its decks"; `decks.removal.title` (zero/one/other) "Retirer %{card} de %{count} deck(s) ?"/"Remove %{card} from %{count} deck(s)?"; `decks.removal.text` "Un deck complet redevient un brouillon."/"A complete deck becomes a draft again."; `decks.removal.confirm` "Retirer"/"Remove"; `decks.removal.cancel` "Annuler"/"Cancel"; `decks.removal.close` "Fermer"/"Close"; `decks.removal.done` "%{card} n'est plus dans aucun deck."/"%{card} is in no deck any more." (assumption); `decks.removal.throttled`; the two reserved `in_deck` keys; trade label words. `errors.game.card_not_owned` exists in both.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/{reserved_copies,spare_copies,decks_holding,held_copies}.rb` -- in-deck share, one spare function, deck names, offerable copies
- [x] `app/domains/game/app/operations/game/remove_from_decks.rb`, `events/game/card_removed_from_decks.rb`, `trade_steps.rb` -- the release operation; friend requests above offerable refused
- [x] `player_desk.rb`, `trade_suggestions/spares.rb`, `concerns/collection_grid_loading.rb` -- read `SpareCopies`
- [x] `market/entrustable_copies.rb`, `market/sellable_copies.rb`, `market/entrustments_controller.rb`, `market/sales_controller.rb` -- decked editions shown, never chosen with 0 free
- [x] `config/routes.rb`, `deck_removals_controller.rb`, `deck_policy.rb` -- the POST endpoint
- [x] `trades_helper.rb`, `trades_controller.rb`, trade views, entrust and sale views, `decks/_removal_dialog.html.erb`, `library/_reserved.html.erb`, `card_details_helper.rb` -- tag, names, action, dialogs, friend side
- [x] `listing_grid_controller.ts` (and the trade picker/entrust guards if needed) + vitest -- disabled cells and the remove button never toggle
- [x] styles, `en.yml`, `fr.yml` -- copy and look
- [x] tests -- every matrix row: `test/domains/game/reserved_copies_test.rb` (in-deck beside listings and trades), new `decks_holding_test.rb`, new `remove_from_decks_test.rb` (two decks, one release, one event, lock order recorded as in `deck_card_operations_test.rb`, no-op), new `spare_copies_test.rb` (suggestions, desk and `SpareCopies.total` agree, deck-blocked copy reserved), new `deck_block_releases_test.rb` (decline, cancel, expire a trade; cancel and settle a listing; go private → deck card still there, reserved keeps 1), controller tests (friend's pick for a decked edition has `data-max="0"` and no deck name; a `take` of it refused; owner pick shows tag and names; removal endpoint success/refusal/visitor/throttle; entrust and sale grids show the decked cell), `test/system/deck_blocked_copies_test.rb`

**Acceptance Criteria:**
- Given a player whose only Portal S1 is in deck "Vieux briscards" and a friend, when they open the trade board with that friend, open their own picker, see "In a deck" and "In: Vieux briscards", choose "Remove from decks", confirm "Remove", then reopen the picker and pick Portal S1 and place it, then the card is on their side; and Confier and Mettre en vente show the same tag, names and action for a decked edition (`test/system/deck_blocked_copies_test.rb`).
- Given a player with a deck-blocked copy, when the collection grid, the set album or the card page render it, then it reads "In a deck", never "in a trade".
- Given a friend whose only copy of a card is in a deck, when the player opens the friend's picker, then the card is unavailable and no deck is named.

## Implementation Notes

- `decks/_removal_dialogs` takes `holding:` and `views:` (the `Catalog::CardViews` of the decked editions) rather than `titles:`, since each dialog needs the edition's ref as well as its title. The deck line and the "Remove from decks" button are one shared partial, `decks/_holding` (locals `names:`, `ref:`, `title:`), used by the trade pick, the entrust cell and the sale page's list of decked editions. `DeckHoldingHelper` builds the ref, the dialog id (`deck-removal-<slug>--s<n>`) and the deck words. `DeckHoldingLoading` loads the deck names once per sale or entrust page.
- The sale page's list of decked editions has the id `#sale-decked`, and the next-page turbo stream appends to it as it does to the cells.
- The picker's "all reserved" empty line is now split by side. A friend whose copies are all held by decks now reads "%{name} has no copy to offer for now" instead of "Your copies…", and the own-side copy now names decks and sales as well as trades. Without this, the friend side would have shown "Your copies are all reserved in other trades."
- `card_details.reserved.in_deck` reads "1 in a deck" / "1 dans un deck" because it sits mid-sentence. The grid's `library.grid.reserved.in_deck` reads "In a deck" / "Dans un deck" as planned.
- `TradeSuggestions.still_spared` is unchanged, so `DUPLICATE_COPIES` stays. Its `minimum_copies` test is generic, it already reads the deck block as reserved, and the trades controller still reads the constant.
- The entrust grid's "Select all (n)" counts decked editions that have no free copy. The client already skips them when it selects.
- Added at verification (matrix audit): a controller test that a forged sale or entrustment of a deck-blocked copy is refused (422) and moves nothing.
- Review patches: `BoardPick#reserved_elsewhere` (reserved minus the deck's copy) feeds the trade pick's label, so a decked card no longer reads "reserved elsewhere"; the removal route sits above the decks comment; `load_holdings` asks `DecksHolding` for every decked edition rather than an IN list of all held editions; tests added for the card-filtered entrust page of a lone decked edition, an existing trade's board, the sale page-2 stream, the sale and entrust labels' deck words, a deck counting only for its owner (`HeldCopies`, `requestable`), unrated editions in suggestions, and the freed sale cell being chosen in the system test.

## Plan Change Log

## Review Triage Log

### 2026-11-15 — Review pass
- verdicts: 33 findings — high 0, medium 5, low 20, false 6, maybe-false 2
- findings:
  - `[medium]` `[patch]` (blind-hunter) The own decked pick's label says "1 reserved in another trade/elsewhere" because `pick.reserved` includes the deck copy — `BoardPick#reserved_elsewhere` subtracts the deck's copy; label shows it only when positive; controller assertion added.
  - `[low]` `[reject]` (blind-hunter) The "In a deck" tag replaces the reserved-count tag when other copies are also reserved — the count stays in the label and "n disponibles"; showing two tags adds a branch for a rare state.
  - `[low]` `[reject]` (blind-hunter) The spare rule still lives in `TradeSuggestions.still_spared` and the copy filter's doubles — `still_spared` differs from `SpareCopies` only on unrated editions, which players do not hold in play; the doubles chip is a per-edition filter, not a spare count, and predates the story.
  - `[low]` `[reject]` (blind-hunter) The entrust screen's default doubles filter hides a lone decked copy — the default view hides every lone copy by design; the card page and a cleared filter show it.
  - `[low]` `[reject]` (blind-hunter) "Select all (n)" counts unselectable decked cells; a deck-only player sees disabled cells instead of the empty state — the grid of disabled cells is the point (freeing them there); a separate free count adds a query for a label number.
  - `[false]` `[reject]` (blind-hunter) The answering player's board (`:theirs`) has no deck names when a deck blocks a requested copy — the player whose turn it is sees state `:yours`, which runs `load_holdings` and loads the deck names.
  - `[low]` `[reject]` (blind-hunter) The 61st removal in a minute redirects to the deck editor — sixty removals a minute is not an everyday path; going back to the referer needs a guarded path lambda.
  - `[low]` `[reject]` (blind-hunter) The deck-block test is written four times (`HeldCopies::IN_DECK`, `ReservedCopies.decked`, `requestable`, `DecksHolding`) — each is a different query shape; a shared relation is a refactor with no named divergence yet.
  - `[medium]` `[patch]` (blind-hunter) Missing tests: `lone_card_edition?`, the trade show/edit boards, `HeldCopies` in_deck/offerable, the meaningless `data-chosen='false'` assertion, CloseTrade, unsold settlement, CounterTrade, draft restore — patched the first four (with the verification-gap rows) and made the sale system test choose the freed cell; CloseTrade, unsold settlement and CounterTrade share the release and `requestable` code already covered by decline/cancel/expire/sale and ProposeTrade; draft restore is the board's existing behaviour.
  - `[low]` `[reject]` (blind-hunter) `.deck-holding__tag` repeats `.trade-card__reserved`, `.sale-cell__decks` repeats `.deck-holding__names` — cosmetic, with no reader or screen harmed; a shared class is a later tidy-up.
  - `[low]` `[patch]` (blind-hunter) The new route and comment orphan the decks comment — moved above it.
  - `[low]` `[patch]` (blind-hunter) `load_holdings` passes every held edition to `DecksHolding` — calls it with no ids (decked editions are always held).
  - `[low]` `[reject]` (blind-hunter) `decks: @deck_names || {}` repeated in four views — cosmetic.
  - `[false]` `[reject]` (edge-case) A ref in no deck shows "is in no deck any more" — the sentence is true in that case and nothing was written.
  - `[low]` `[reject]` (edge-case) The throttle redirects to the deck editor — same as the blind-hunter throttle row.
  - `[maybe-false]` `[reject]` (edge-case) A decked edition with no card text in the locale gets no tag, button or dialog — settle by checking whether every card has texts in both locales; low if true, since the deck editor still frees it.
  - `[maybe-false]` `[reject]` (edge-case) The sale grid's decked list can miss an edition `CardViews` skipped — same root as the previous row; low if true.
  - `[low]` `[reject]` (edge-case, claim) `still_spared` restates the spare rule — same as the blind-hunter spare row.
  - `[false]` `[reject]` (edge-case, claim) `Spare.copies` can exceed the `SpareCopies` figure — `Spare.copies` is neither shown nor used in the ranking; the gate reads `SpareCopies`.
  - `[low]` `[patch]` (verification-gap) The card-filtered entrust page's lone decked edition opening ticked is untested — test added (`data-ticked='0'`, empty selection, no tick spans).
  - `[medium]` `[patch]` (verification-gap) Deck names on an existing trade's board are untested — controller test on a `:yours` trade's board added.
  - `[medium]` `[patch]` (verification-gap) The sale page-2 stream to `#sale-decked` is untested — 61-edition stream test added.
  - `[low]` `[patch]` (verification-gap) The deck words in the sale and entrust labels are unasserted — `aria-label*=` assertions added.
  - `[medium]` `[patch]` (verification-gap) Nothing proves a deck counts only for its owner's holding (`IN_DECK`, `requestable`) — `held_copies_test` and a requester-decks-too case added.
  - `[low]` `[patch]` (verification-gap) The suggestions' switch to `SpareCopies` is not pinned — unrated-copy suggestion case added.
  - `[low]` `[reject]` (verification-gap, other) `still_spared` and `Spare.copies` keep `FreeEditions` — same as the blind-hunter spare row.
  - `[false]` `[reject]` (intent) The suggestion's count differs from the desk's — `Spare.copies` is never displayed; the spare decision itself reads `SpareCopies`, and the desk and report read the same total.
  - `[low]` `[reject]` (intent) On Mettre en vente the action sits in a list after the listbox, not in the cell — an `option` cannot hold a button (plan decision); the cell carries the tag and names.
  - `[low]` `[patch]` (intent) "After which … listed" is not shown end to end on the sale screen — the system test now chooses the freed cell (same fix as the blind-hunter test row).
  - `[false]` `[reject]` (intent) The friend's picker is proven by a controller test, not a query test — the controller test reads the rendered picker, the outer surface, and the `ProposeTrade` refusal covers the operation.
  - `[low]` `[reject]` (intent) The card page reads "1 dans un deck" and a game with two decked editions "2 dans des decks" — per-edition counting per AD-52; the card page phrase sits mid-sentence.
  - `[low]` `[reject]` (intent) Two English system test methods rather than one French test — one file covers the flow; the French strings are asserted in controller tests.
  - `[false]` `[reject]` (intent) Scope beyond the intent (grid reasons, picker empty copy, grids listing decked editions, requestable) — each serves the intent: the deferred grid reading, the friend's side, and freeing copies on the market screens.

## Design Notes

Why one HTML endpoint and a reload: the three screens differ (a stimulus-rich trade board, a paged entrust grid, a listbox inside a form); a confirm dialog posting a plain form and redirecting back keeps them free of new client state. The trade board restores its draft from `localStorage` on load (`lib/trade_board_draft.ts`), so the player re-opens the picker and places the freed card. The dialogs use the existing `dialog` and `dialog-opener` controllers.

Why decked editions join the entrust and sale grids even with no free copy: the ticket's "after which the copy can be entrusted or listed" needs the blocked copy on screen to be freed there.

Spare rule (the trade suggestions decision and AD-52): a spare is a free copy of a game, summed over its editions, beyond the one its holder keeps. Sketch:

```sql
SELECT game_holdings.player_id, catalog_card_seasons.card_id,
       GREATEST(SUM(game_holdings.quantity - game_holdings.reserved) - 1, 0) AS spare
  FROM game_holdings JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
 WHERE game_holdings.player_id IN (:player_ids) AND game_holdings.quantity > 0
   AND catalog_card_seasons.rarity IS NOT NULL
 GROUP BY 1, 2
```

## Verification

**Commands:**
- `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w42_5 CHROME_BIN=/usr/bin/chromium` before any Rails command; never run `bin/setup`.
- `bin/rails test test/domains/game test/domains/accounts test/controllers test/policies test/models test/helpers test/config` -- green except the known `library_controller_test.rb:119`
- `bin/rails test test/system/deck_blocked_copies_test.rb test/system/trade_board_test.rb test/system/market_entrust_test.rb test/system/market_sales_test.rb test/system/deck_editor_test.rb` -- green
- `bundle exec rubocop`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks missing`, `npm run test:js`, `npm run typecheck` (if defined), `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes` -- green

## Auto Run Result

**Summary:** a copy a deck blocks is now named and can be freed where free copies count.
- `Game::ReservedCopies` splits `reserved` into in a deck, on sale and in trade. The collection grid, the set album and the card page read "Dans un deck" for a deck's copy, never "en échange".
- `Game::DecksHolding` names the decks holding an edition, oldest first.
- `Game::RemoveFromDecks` takes an edition out of every deck of the player in one transaction. It locks the bank, then the decks, then their cards, then the holding. It lowers `reserved` once and publishes one `Game::CardRemovedFromDecks`.
- The owner's trade picker, Confier and Mettre en vente show the "Dans un deck" tag, "Dans : <decks>" and "Retirer des decks". The button opens a confirmation dialog that posts to `POST /:locale/duels/decks/removals` and redirects back to the screen.
- The entrust and sale grids now list decked editions even with no free copy, disabled until freed. On the sale screen the button sits in a list after the listbox, since an option cannot hold a button.
- On a friend's side a decked edition offers one copy fewer (0 means unavailable, with no tag and no deck name), and `TradeSteps#requestable` refuses a request above that.
- One `Game::SpareCopies` (free copies of a game, over its editions with a rarity, beyond one) feeds the market desk, the collection report and the suggestions' spare test. The desk now counts per game, not per edition.

**Files changed**
- `app/domains/game/app/queries/game/{reserved_copies,spare_copies,decks_holding,held_copies}.rb`, `market/{entrustable_copies,sellable_copies,player_desk}.rb`, `trade_suggestions/spares.rb`: the in-deck share, the spare rule, deck names, offerable copies, decked editions in the market grids.
- `app/domains/game/app/operations/game/{remove_from_decks,trade_steps}.rb`, `events/game/card_removed_from_decks.rb`: the removal and the friend-request check.
- `config/routes.rb`, `app/controllers/deck_removals_controller.rb`, `app/policies/deck_policy.rb`, `app/controllers/concerns/{deck_holding_loading,collection_grid_loading}.rb`, `app/controllers/{trades_controller,market/entrustments_controller,market/sales_controller}.rb`: the endpoint, its policy and the loading of deck names.
- `app/helpers/{deck_holding_helper,trades_helper,market_entrustments_helper,market_sales_helper,card_details_helper}.rb`, `app/views/decks/{_holding,_removal_dialog,_removal_dialogs}.html.erb`, trade, entrust, sale and library views: the tag, names, button, dialogs and labels.
- `app/frontend/controllers/listing_grid_controller.ts` (+ vitest): a disabled sale cell is never chosen.
- `app/frontend/styles/deck-holding.css`, `market-entrust.css`, `market-sale.css`, `trades-picker.css`, `entrypoints/application.css`: styles.
- `config/locales/en.yml`, `fr.yml`: the copy.
- Tests: `reserved_copies`, `spare_copies`, `decks_holding`, `remove_from_decks`, `deck_block_releases`, `held_copies`, `player_desk`, the deck policy, `collection_reserved_copies`, `deck_blocked_copies` (controller), and the system test `test/system/deck_blocked_copies_test.rb`.
- `_bmad-output/initiative-gameble/deferred-work.md`: the deck editor story's "in a trade" deferral marked resolved.

**Review:** thorough, four lenses, 33 findings: 5 medium, 20 low, 6 false, 2 maybe-false.
- Patched, medium (5):
  - the decked pick's label read the deck's copy as reserved elsewhere;
  - missing tests for a lone decked edition on the card's entrust page and for the sale system flow choosing the freed cell;
  - deck names on an existing trade's board;
  - the sale page-2 stream;
  - a deck counting only for its owner (`HeldCopies`, `requestable`).
- Patched, low: the orphaned route comment, the IN list of every held edition, the label words on sale and entrust cells, the unrated-edition suggestion case.
- Deferred: none.
- Rejected, each with its reason in the triage log: the tag hiding other reservations, `still_spared`/doubles filter keeping their own rules (differ only on unrated editions), the default doubles filter hiding a lone copy, the select-all count, the throttle redirect, the four deck-block queries, duplicated CSS, the repeated view fallback, a missing locale text (maybe-false), the sale action placed after the listbox, the card-page wording, the system test shape.

**Follow-up review recommended:** true. This pass patched five medium entries. The named unverified risk: after "Retirer", the trade board reloads and relies on its existing localStorage draft restore; no test removes a card with lines already placed, on the draft board or on a counter board, so a lost draft after the reload is unproven either way.

**Verification** (own test database `gameble_test_w42_5`; `bin/setup` and bin/ci's setup step not run):
- `bin/rails test test/domains/game test/domains/accounts test/controllers test/policies test/models test/helpers test/config`: 4582 runs, 1 failure, the known `library_controller_test.rb:119`.
- System tests `deck_blocked_copies`, `trade_board`, `market_entrust`, `market_sales`, `deck_editor`, `trades`: 41 runs, green.
- `rubocop`, `packwerk check`, `zeitwerk:check`, `i18n-tasks missing`, `npm run typecheck`, `format:check`, `lint:css`, `script/check_planning_references`, `script/check_file_sizes`: clean.
- `npm run test:js`: 135 files, 1411 tests passed; one run reported the known unhandled error from `annonce_controller.test.ts`.
- No migration, so `db/schema.rb` is unchanged.

**Residual risks:**
- Players' desk spare count changes value (per game, beyond one free copy).
- `TradeSuggestions.still_spared` still checks spares through `FreeEditions`, which also counts unrated editions.
- The removal toast "%{card} n'est plus dans aucun deck." and the throttle line are copy assumptions outside the Copy deck; the picker's split "all reserved" line is new copy too.
- A decked edition with no card text in the current locale would show no removal on the market screens (the deck editor still frees it).
