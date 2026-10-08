---
title: 'Trade board island: the card picker and quantities'
type: 'feature'
ticket: '7'
created: '2026-10-07'
status: 'built'
baseline_revision: '9456caaec83deb65db340e76f3ac5648f565aba2'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      The counter page's props carry a card-s face for every card both players hold, so a very large collection makes a heavy page.
    evidence: |-
      TradesHelper#trade_board_props renders CardComponent (about 1.5 KB of HTML) for each Game::HeldCopies row of the player and of the friend, all in the turbo-mount props attribute. Unverified: today's collections are small; what would settle it is the page weight of the counter form for a player holding several hundred distinct cards. A fix would load the picker's faces on demand (an endpoint per side) or page them.
    location: >-
      app/helpers/trades_helper.rb (trade_board_props)
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** The counter form of 5.6 only edits the quantities of the cards already on each side: a player cannot pick another card, and the trade board island of AD-16 does not exist (R2, R3, R6).

**Approach:** A `TradeBoard` React island mounted on the counter-proposal board (`/trades/:token/counter`) in place of the two quantity-field sides: each side shows its cards with a quantity stepper and "✕", an add slot opens the card picker (a wide dialog, a full-height sheet on the phone) listing the player's cards (copies, reserved elsewhere, free) or the friend's collection, at most 4 different cards per side; the faces come from the server (CardComponent HTML in props), the island writes the side's hidden fields into the server form, and tells the page its sides through a typed `gameble:trade-changed` event that enables the send button.

**Decisions (autonomous run, author away):** the island lives on the counter page only (the draft, the in-place EN ÉDITION toggle, ANNULER LES MODIFICATIONS' confirmation and the swap are 5.8); the counter POST accepts any card the side's holder holds (keys `<slug>--s<season>`, AD-15), a key outside it refuses the side (`invalid_offer` / `invalid_request`), 0 or blank still removes a card (the no-JS fallback keeps 5.6's quantity fields, replaced when the island mounts); the player's maximum is copies held minus reserved (all open trades; on the player's turn their side is the unreserved request), the friend's is what they hold, with no reserved tag on the friend's cards (their other trades stay private); the friend's collection is listed whatever their profile visibility (trading with a friend needs it; visibility governs profile pages); in edition every card on a side is `card-s`, the size of the add slot beside it, so the props carry one face per card; candidates are ordered by season, number, title; a line whose maximum fell to 0 since the proposal starts removed; the send button is disabled while a side is empty, its reason "Choisissez les cartes de chaque côté." beside it.

## Boundaries & Constraints

**Always:** faces only from CardComponent (AD-16), no `style` attribute in server HTML; no database id in props, fields or URLs (AD-15); words from the locale files through props (fr and en); events declared in `app/frontend/lib/events.ts`; the picker grid is one tab stop with arrow keys inside; the stepper is a spinbutton (arrows, + and −, Home/End); writes only through `Game::CounterTrade` (AD-3).

**Never:** a draft, a new trade from the friend row, client storage, the swap or the NOUVEAU tag (5.8); live updates (5.9); empty-state reasons beyond "Aucune carte disponible." (5.11); changes to trade operations; a client router or store.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Pick | picker open, card with free copies | lime frame + ✓, "n cartes · n exemplaires (4 cartes au plus)"; stepper under it when more than 1 is free | n/a |
| Fifth card | 4 picked, pick a 5th | not added | inline "4 cartes au plus · Retirez une carte avant d'en placer une autre." |
| Fully reserved | own card, free 0 | "Réservée" tag, cannot be picked (aria-disabled) | n/a |
| Partly reserved | own card ×3, 1 reserved | "1 réservée" tag, stepper max 2 | n/a |
| Placer / Annuler / Esc | picker | side replaced / unchanged; focus back on the add slot (or the side's first card when 4 are placed) | n/a |
| Stepper | arrows, + −, buttons | 1..max, "/max" | clamped |
| Remove ✕ | card on a side | gone, focus next card's ✕ or the add slot | n/a |
| Empty side | a side without card | send disabled, reason shown | server still refuses `invalid_offer`/`invalid_request` |
| Unheld key posted | `give[x--s1]` not held | nothing changes | refusal inline + toast |

</intent-contract>

## Code Map

- `app/controllers/trades_controller.rb` -- `edit` (props data), `counter` (key resolution against both holders' cards; replaces `quantities`); keep rate limit, `refused`, redirects.
- New `packs/game/app/queries/game/held_copies.rb` -- `{ card_season_id => Row(quantity, reserved, free) }` for every card-season held (quantity > 0); pattern `quantities.rb`, `free_copies.rb` (unchanged, still used elsewhere).
- `app/helpers/trades_helper.rb` -- `trade_board_props`; `trade_card_key` reused; faces `render(CardComponent.new(card:, size: :s)).to_str` (pattern `packs_helper.rb`, `boosters_helper.rb#booster_strings`).
- `app/views/trades/_board.html.erb` -- edit branch: `turbo_mount("TradeBoard", props:, class: "trade-island") { 5.6 sides + middle as fallback }`; actions wrapped with `data-controller="trade-send"` and the reason line.
- `app/frontend/entrypoints/application.ts` -- `registerComponent(turboMount, "TradeBoard", island(TradeBoard))` (eager: React replaces the fallback in place, no empty frame).
- New `app/frontend/lib/trade_board.ts` (+ `.test.ts`) -- pure side logic: toggle with the 4-card limit, step clamp, remove, initial lines, counts, spinbutton keys, grid moves.
- New `app/frontend/components/TradeBoard.tsx`, `TradePicker.tsx`, `QuantityStepper.tsx` -- island; picker is a React-owned `<dialog class="modal">` (shell.css modal styles; `showModal`, Esc = cancel, close before `turbo:before-cache`); flat transparent button over each face (EXPERIENCE.md 3D rule).
- `app/frontend/lib/events.ts` -- `gameble:trade-changed` `{ give: SideCount; take: SideCount }`.
- New `app/frontend/controllers/trade_send_controller.ts` -- disables `button[type=submit]` and shows the reason while a side is empty.
- `app/frontend/styles/trades.css` -- add slot, remove, stepper, picker grid, phone sheet; `.trade-island { display: contents }`.
- `config/locales/{en,fr}.yml` -- `trades.island.*`.
- Tests: `test/controllers/trades_controller_test.rb` (counter tests at lines ~196-250), `test/system/trades_test.rb` (the counter step uses `fill_in "Copies of Portal"`), new `test/packs/game/held_copies_test.rb`. Fixtures: five card-seasons `portal_one`, `common_card_one`, `uncommon_card_one`, `rare_card_one`, `legendary_card_one`.

## Tasks & Acceptance

**Execution:**
- [ ] `packs/game/app/queries/game/held_copies.rb` -- the holder's cards with copies and reserved -- picker data and key resolution
- [ ] `app/controllers/trades_controller.rb`, `app/helpers/trades_helper.rb` -- props and counter keys
- [ ] `app/views/trades/_board.html.erb` -- mount with fallback, send controller and reason
- [ ] `app/frontend/lib/trade_board.ts`, `lib/events.ts`, components, `controllers/trade_send_controller.ts`, `entrypoints/application.ts`, `styles/trades.css` -- the island
- [ ] `config/locales/{en,fr}.yml` -- strings
- [ ] tests: `test/packs/game/held_copies_test.rb`, controller tests (add a card to each side, unheld key refused, props on the counter page), `app/frontend/lib/trade_board.test.ts`, system tests (desktop pick/remove/quantities/limit/reserved/keyboard and send; phone full-height sheet)

**Acceptance Criteria:**
- Given a player countering on desktop, when they open "Placer mes cartes", pick a second card, set ×2 and press "Placer", then send, then the trade holds both cards with those quantities and the toast confirms.
- Given a phone width, when the player opens a picker, then it fills the screen's height and the page does not scroll sideways.
- Given a card fully reserved in another trade, when the picker opens, then it shows "Réservée" and pressing it adds nothing.
- Given four cards picked, when a fifth is pressed, then the inline refusal shows and the side keeps four.
- Given only the keyboard, when the player tabs to an add slot, opens the picker, moves with arrows, picks with Enter, changes the quantity with arrows on the stepper and presses "Placer", then focus returns to the add slot and the side shows the cards.

## Implementation Notes

Subagents unavailable, done in-session (implementation and the quick review lens). `Game::HeldCopies` (one query per holder) feeds the edit page's props and the counter POST's key resolution; `Game::FreeCopies` is no longer read by the web layer (only by its 5.6 test), left for the refactor sweep (5.12). The island is registered eagerly in `application.ts` and mounted with the 5.6 quantity fields as its fallback children, which `createRoot` replaces; `.trade-island { display: contents }` keeps the sides and status line in the board's grid. The picker is a React-owned `<dialog class="modal modal--wide">` mounted while open (pattern of `BoosterZoom.tsx`), focus restored by the island (the add slot, else the side's first "✕"). The stepper is one spinbutton tab stop whose "−"/"+" buttons are pointer-only (`tabIndex=-1`, mouse-down keeps the focus). On the phone the "✕" stays 24px with a 44px hit area (`::after`) and the stepper buttons are 44px wide. Visual check by throwaway screenshots (desktop board and picker, phone board and sheet), not committed. Shared surfaces: `config/locales/{en,fr}.yml` (`trades.board.choose`, `trades.island.*`), `config/i18n-tasks.yml` (ignore `trades.island.*`), `app/frontend/lib/events.ts`, `app/frontend/entrypoints/application.ts`.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 6 findings — high 0, medium 0, low 4, false 0, maybe-false 2 (quick lens run in-session, subagents unavailable)
- findings:
  - `[low]` `[patch]` the picker closed on `turbo:before-cache` through a plain state update, rendered after Turbo took its snapshot, so a page left with the picker open could come back from the cache with an open dialog — the update is now flushed (`flushSync`); the trades system tests pass.
  - `[low]` `[patch]` opening the counter-proposal left the focus at the top of the page, against EXPERIENCE.md's focus table ("CONTRE-PROPOSER" → the add slot on the player's side) — the island focuses that add slot when it mounts, without scrolling; asserted in the keyboard system test.
  - `[low]` `[reject]` a counter refused by the server (copies reserved meanwhile, an expired trade) sends the player back to a form rebuilt from the stored trade, so the picks are lost — rare (an empty side is now caught before sending), the refusal shows inline; keeping the picks means carrying them through the redirect or a draft, the browser draft of story 5.8.
  - `[low]` `[reject]` a card with one copy reserved elsewhere shows the copy deck's "Réservée" (the one form) though it can still be picked — the foot says "n disponibles" and the accessible name "1 réservé ailleurs"; a new string would leave the copy deck.
  - `[maybe-false]` `[reject]` the friend's collection is listed in the picker even when their profile is private (Game::Visibility) — the intent records this choice (trading needs the friend's cards; visibility governs profile pages); the author confirms it (residual risk).
  - `[maybe-false]` `[defer]` every card both players hold travels as a face in the props: heavy for very large collections — recorded in `deferred` (medium, unverified), what would settle it: the counter page's weight for a player holding several hundred cards.

## Design Notes

Props (camelCase, built by `trade_board_props`): `{ sides: [friend, own], message, error, swapIcon, closeIcon, strings }`, a side `{ side, field ("take"|"give"), label, add, pickerTitle, pickerTitleShort, note, cards: [{ key, title, owned, reserved, max, face }], lines: [{ key, quantity }] }`; the friend's cards carry `reserved: 0`, `max: owned`.

## Verification

**Commands:**
- `bin/rails test` (non-system, PARALLEL_WORKERS=2, lane DB) -- green
- `bin/rails test test/system/trades_test.rb` (PARALLEL_WORKERS=1) -- green
- `npm run typecheck`, `npx vitest run`, `bin/rubocop` on changed Ruby, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` -- clean

## Auto Run Result

- **Summary:** the counter-proposal's board (`/trades/:token/counter`) now mounts the `TradeBoard` React island (AD-16) over 5.6's quantity fields: both sides "EN ÉDITION" with each card at card-s, a quantity stepper (spinbutton: arrows, + and −, Home/End; 1 to the player's free copies or what the friend holds) and "✕"; an add slot (under four cards) opens the card picker, a wide dialog (a full-height sheet titled "Cartes de Léa" on the phone) listing every card of the side's holder with its copies, the copies reserved in other trades ("Réservée", a fully reserved card cannot be picked) and a stepper or "n disponibles"; picking adds 1 copy, a fifth card is refused inline ("4 cartes au plus · …"), "Placer" commits, "Annuler"/✕/Esc/scrim discard, the grid is one tab stop with arrow keys; the focus follows EXPERIENCE.md (add slot on opening and after the picker, next card after "✕"). The island writes `give[<slug>--s<n>]`/`take[…]` into the server form and tells the page `gameble:trade-changed`; the send button (`trade-send` controller) is disabled with "Choisissez les cartes de chaque côté." while a side is empty. The counter POST accepts any card the side's holder holds, a key outside it is refused (`invalid_offer`/`invalid_request`). fr and en copy.
- **Files:**
  - `packs/game/app/queries/game/held_copies.rb` (new) -- every card a player holds, copies, reserved, free, one query.
  - `app/controllers/trades_controller.rb` -- `edit` loads both holders' cards; `counter` resolves keys against them.
  - `app/helpers/trades_helper.rb` -- `trade_board_props` (sides, card-s faces, words).
  - `app/views/trades/{_board,_screen,edit}.html.erb` -- island mount with the 5.6 fields as fallback, send controller and its reason.
  - `app/frontend/components/{TradeBoard,TradePicker,QuantityStepper}.tsx` (new), `app/frontend/lib/trade_board.ts` (+ test, new), `app/frontend/lib/events.ts` (`gameble:trade-changed`), `app/frontend/controllers/trade_send_controller.ts` (new), `app/frontend/entrypoints/application.ts` (registration), `app/frontend/styles/trades.css` -- the island.
  - `config/locales/{en,fr}.yml` (`trades.board.choose`, `trades.island.*`), `config/i18n-tasks.yml` (ignore `trades.island.*`).
  - Tests: `test/packs/game/held_copies_test.rb` (new), `test/controllers/trades_controller_test.rb` (props, new cards on both sides, unheld keys), `test/system/trades_test.rb` (stepper in the existing flow; desktop picker and limits, keyboard, phone sheet and the send gate).
- **Review:** 2 patches (low: picker closed before Turbo's snapshot; focus on the player's add slot when the board opens), 1 deferred (props weight for very large collections, medium unverified), 3 rejected (picks lost on a server refusal: rare, the draft of 5.8; "Réservée" one form on a partly reserved card: copy deck's form, foot and name say the rest; friend's collection shown whatever their visibility: the intent's choice, for the author to confirm).
- **Follow-up review recommended:** false (patched: 0 high, 0 medium, 2 low).
- **Verification:** `bin/rails test` (non-system, PARALLEL_WORKERS=2, lane DB): 1621 runs, 0 failures; `bin/rails test test/system/trades_test.rb` (PARALLEL_WORKERS=1): 6 runs, 0 failures (after the patches); `npm run typecheck`: clean; `npx vitest run`: 16 files, 149 tests passed (11 new); `bin/rubocop` on changed Ruby, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused`, `bin/brakeman`: clean. Screenshots checked by eye (desktop board and picker, phone board and sheet), not committed.
- **Residual risks:** the friend's collection is listed in the picker whatever their profile visibility (autonomous choice, author to confirm); a refused counter loses the picks (5.8's draft); the island lives on the counter page only (the in-place EN ÉDITION toggle, ANNULER LES MODIFICATIONS' confirmation, the draft and the swap are 5.8); "Aucune carte disponible." has no reason yet (5.11); `Game::FreeCopies` is no longer read by the web layer (refactor sweep); props weight for very large collections (deferred); English copy and the picker's words outside the copy deck ("aucun disponible", "réservé ailleurs", notes) are autonomous choices.

### Merge of develop (6c66ee4) and repository rules

- develop merged into the lane branch (merge commit 296f8c3), bringing 5.11 and AGENTS.md. Conflicts in `trades_controller.rb`, `_board`, `_screen` and `edit` were resolved keeping both sides: the island mount and send gate, and 5.11's "nothing to place" line on the fallback sides (`trade_nothing_to_place`, fed `@own_held` as copies held, now derived from `Game::HeldCopies`).
- The picker's empty state reuses 5.11's copy instead of its own key: "Aucune carte disponible." (`trades.side.none.title`) with the reason, `none_owned` / `friend_none_owned` when the holder holds no card, `all_reserved` when every card of the player is reserved elsewhere; `trades.island.strings.empty` removed.
- AGENTS.md: the planning ids and the explanatory comments this story had added to code, tests, CSS and config were removed (only one-line browser/Turbo constraints kept); pre-existing comments of other stories were left as they are.
- Verification after the merge: `bin/rails test` (PARALLEL_WORKERS=2): 1632 runs, 0 failures; `bin/rails test test/system/trades_test.rb` (PARALLEL_WORKERS=1): 6 runs, 0 failures; `npm run typecheck`, `npx vitest run` (149 tests), rubocop on changed Ruby, `i18n-tasks missing` and `unused`, `packwerk check`: clean.
