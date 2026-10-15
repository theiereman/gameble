---
title: 'An open trade request'
type: 'feature'
ticket: '6'
created: '2026-10-15'
status: 'built'
baseline_revision: 'fa43567e68bcfc3f8f9802c5dc68ca3c6b1a95c2'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/AGENTS.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** A player who knows which of a friend's cards they want, but not what the friend wants in return, must guess: a proposal is sent only when each side holds a card (issue 63, point 5).

**Approach:** At every send, proposal or counter-proposal, the sender's own side (the offer) may be empty while the friend's side (the request) still needs one to four cards; an empty offer reserves nothing. `Game::AcceptTrade` refuses a trade with an empty side, on the locked trade after the current-terms check, with its own failure code. The send button enables once the friend's side holds a card, and the board, its states, the send toast and the list summary follow EXPERIENCE.md's open-request copy.

## Boundaries & Constraints

**Always:** Writes only through the existing operations; the refusal is inside `AcceptTrade`'s transaction, after `current_terms`, before `lock_holdings`, and moves nothing. One open trade per pair, at most 4 cards per side, private profiles, cancel, decline and 7-day expiry unchanged. Every string in both `en.yml` and `fr.yml`; the new `errors.game.<code>` added by hand to both; French plural keys get a `zero` form. Copy naming the friend is neutral in gender (any name fills it). Tokens only; no `style` attribute; islands talk only through `gameble:*` events in `app/frontend/lib/events.ts`. English repo text, no planning ids or comments in code.

**Never:** No gift: an empty side is never accepted, on the screen or by the server. No empty request side, no trade with both sides empty. No stored mode, state, migration or new reservation rule. No "first game +n" list format (deferred). No trade filters (entry 2). No new trade gesture: sending with an empty own side is the open request.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open proposal | `ProposeTrade` with `offer: {}`, request 1 card | trade created, its request item only, no copy reserved, `TradeProposed` published | — |
| Empty request | `ProposeTrade` or `CounterTrade` with `request: {}` | refused | `Failure(:invalid_request)`, nothing written |
| Bad offer | `offer: nil`, `[]`, 5 cards, a 0 or non-integer quantity | refused as today | `Failure(:invalid_offer)` |
| Open counter | `CounterTrade` with `offer: {}` on a trade whose offer was not empty | previous offer released, nothing reserved, turn handed over, 7 days restarted | — |
| Answering an open request | `CounterTrade` by the recipient of an open request, offer 1 card, request 1 card | the previous (empty) offer releases nothing, the new offer is reserved | — |
| Accept empty-sided | `AcceptTrade` on an open request (current revision) | refused, no card moves, no feed entry, no weekly contribution, trade stays open | `Failure(:trade_side_empty)`, copy "Rien à recevoir pour l'instant : choisissez ce que vous voulez dans la collection de %{name}, puis renvoyez." / "Nothing to receive yet: choose what you want from %{name}'s collection, then send it back." |
| Accept stale revision | `AcceptTrade` on an empty-sided trade with an old revision | `trade_changed` first, as today | `Failure(:trade_changed)` |
| Draft send rule | draft or counter form with the own side empty and the friend's side holding a card | "ENVOYER LA PROPOSITION" / "RENVOYER LA CONTRE-PROPOSITION" enabled; with the friend's side empty it stays disabled with its reason | — |
| Toast | proposal or counter sent with an empty own side | "PROPOSITION ENVOYÉE · Léa a 7 jours pour choisir ce qui lui plaît en retour." | — |
| Board, sender waiting | `theirs`, own side empty | the own side reads "À choisir par Léa", no card counter, nothing tagged reserved | — |
| Board, recipient | `yours`, friend's side empty | the friend's side reads "À vous de choisir"; no "ACCEPTER"; the line "Hugo vous laisse choisir. Prenez ce que vous voulez dans sa collection, puis renvoyez." in its place; "CONTRE-PROPOSER" and "REFUSER" stay | — |
| Editing help | draft or counter in edition, own side empty | "Laissez ce côté vide : Léa choisira ce qui lui plaît en retour." under the own side | — |
| List | a row with an empty side | that side reads "À choisir" in the row summary | — |

</intent-contract>

## Code Map

- `packs/game/app/operations/game/trade_steps.rb:6` -- `normalise(side, code)` refuses any side outside 1..4 lines; the only guard against an empty offer. Give it a lower bound so the offer accepts 0..4 and the request keeps 1..4 (`nil`/`[]` stay invalid). `create_items` (:73-78) `insert_all!`s both sides: safe because the request is never empty. `reserve`/`release`/`shift_reserved` (:80-92) and `enough_copies` (:64-67) already no-op on `{}`.
- `packs/game/app/operations/game/propose_trade.rb:7-8`, `counter_trade.rb:7-8` -- the `normalise` calls; the counter's `previous` offer may now be `{}` (`release` copes).
- `packs/game/app/operations/game/accept_trade.rb:11-21` -- order: `lock_trade`, `turn`, `still_open`, `current_terms` (:14), `not_expired`, `friends`, `side_of` offer/request (:18-19), `lock_holdings` (:20), `enough_copies` (:21). Add a step after :19, before :20, returning `Failure(:trade_side_empty)` when either side is empty.
- `lib/application_operation.rb:36` -- `failure_message(code, **values)` reads `errors.game.<code>`; en `config/locales/en.yml:~1468-1504`, fr `fr.yml:~1516-1552`. Reword `invalid_offer` (fr "Proposez au plus quatre cartes différentes, avec une quantité d'au moins un chacune.", en "Offer at most four different cards, each with a quantity of at least one.") and add `trade_side_empty`.
- `app/controllers/trades_controller.rb` -- `quantities` already returns `{}` for an absent or all-"0" `give`; `create` (:56) and `counter` (:86) toast `trades.sent.text`: pick `trades.sent.open_text` when the sent offer is empty. `accept` refusals go through `refused(code, friend)` with the friend's name.
- `app/helpers/trades_helper.rb` -- `trade_side_title` (:26-29, "—" for empty) → `trades.row.to_choose`; `trade_side_count` (:78-85); `trade_side_labels` (:57-64); `trade_message` (:70-76); `trade_board_props`/`trade_draft_props`/`trade_island_side`/`trade_island_strings` (:119-189) feed the island.
- `app/views/trades/_side.html.erb:6-14` -- header with `trade_side_count(lines)`; add the empty-side text ("À choisir par %{name}" for the player's own empty side on someone else's turn, "À vous de choisir" for the friend's empty side on the player's turn) and omit the counter when the side is empty and not in edition.
- `app/views/trades/_board.html.erb:42-49` -- `readActions`; render the open-request line instead of the ACCEPTER button when `trade.friend_side.empty?`. `:57` and `_draft_board.html.erb:27` -- the send reason, now about the friend's side only.
- `app/frontend/controllers/trade_send_controller.ts:12-21` -- `const empty = give.cards === 0 || take.cards === 0` → only `take` (the friend's side) gates sending.
- `app/frontend/components/TradeBoard.tsx:157-225` -- `countText`, `renderSide` (edit mode lists lines and the "+" slot); add the help line under the own side when it is empty in edition, from a new island string.
- `app/frontend/lib/trade_board.ts`, `trade_draft.ts`, `events.ts:33` -- `sideCount`, drafts and `TradeChangedDetail` already accept empty sides; no event change.
- Tests: `test/packs/game/trade_test.rb:117-125` (the `{}` offer in the invalid list; a successful empty offer must get its own test, as one trade per pair breaks the loop), `test/packs/game/trade_accept_counter_expire_test.rb:254-260` (`counter(trade, offer: {})` expected `invalid_offer`; `:114` is the template for a refused accept writing no feed or weekly row), `test/controllers/trades_controller_test.rb` "a counter that empties a side is refused on its form" (~:382+, sends `give: {"portal--s1" => "0"}`) and "a draft refused goes back to the draft…" (posts with no `give`), `test/system/trades_test.rb:~280-290` (send waits for a card on each side; not run, system tests are disabled, update it to the new rule).
- `Handlers::TradeAccepted`, `FeedEntry.record_trade` assume both sides; reachable only through an accept, which now refuses. Do not change them.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md:103-105, 358-362` -- open-request copy; align the "Léa choisira ce qu'elle veut" lines to the neutral wording and add the refusal copy.

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/operations/game/trade_steps.rb`, `propose_trade.rb`, `counter_trade.rb` -- the offer normalises with 0..4 lines, the request with 1..4 -- the open request at every send.
- [x] `packs/game/app/operations/game/accept_trade.rb` -- an empty-side step after `side_of`, before `lock_holdings`, `Failure(:trade_side_empty)` -- the server refuses a gift.
- [x] `config/locales/en.yml`, `fr.yml` -- `errors.game.trade_side_empty`, reworded `errors.game.invalid_offer`, `trades.sent.open_text` (fr "%{name} a 7 jours pour choisir ce qui lui plaît en retour.", en "%{name} has 7 days to choose what they want in return."), `trades.row.to_choose` ("À choisir" / "To choose"), side texts ("À choisir par %{name}" / "For %{name} to choose", "À vous de choisir" / "Yours to choose"), board lines (help "Laissez ce côté vide : %{name} choisira ce qui lui plaît en retour." / "Leave this side empty: %{name} will choose what they want in return."; recipient "%{name} vous laisse choisir. Prenez ce que vous voulez dans sa collection, puis renvoyez." / "%{name} lets you choose. Take what you want from their collection, then send it back."), send reason ("Placez au moins une carte du côté de %{name}." / "Place at least one card on %{name}'s side.") -- both locales.
- [x] `app/controllers/trades_controller.rb` -- the open toast text when the sent offer is empty -- copy deck.
- [x] `app/helpers/trades_helper.rb`, `app/views/trades/_side.html.erb`, `_board.html.erb`, `_draft_board.html.erb` -- empty-side texts and counter, the recipient line in place of ACCEPTER, the send reason, the list's "À choisir", the help line in the server-rendered fallback, the island strings -- the board's states.
- [x] `app/frontend/controllers/trade_send_controller.ts`, `app/frontend/components/TradeBoard.tsx` -- sending gated by the friend's side only; the help line under the empty own side in edition -- the island's empty own side, which entry 2 keeps.
- [x] `test/packs/game/trade_test.rb`, `trade_accept_counter_expire_test.rb` -- every operation row of the matrix (open proposal and counter reserving nothing, empty request refused, bad offers, answering an open request, empty-sided accept refused with nothing moved and no feed or weekly row, stale revision first), the two `invalid_offer` expectations updated -- the operations' verification.
- [x] `test/controllers/trades_controller_test.rb` -- the two changed tests, plus sending a draft with only the friend's side, the toast, the recipient board without ACCEPTER and with the line, the sender's "À choisir par Lea", the help line in the fallback, the accept refusal message on the board, the list's "À choisir" -- the screen's verification.
- [x] `app/frontend/**/*.test.ts` -- a vitest for the help line or the send rule where a pure function carries it -- front-end coverage.
- [x] `test/system/trades_test.rb` -- the send rule's expectations follow the new rule (not run) -- keeps the disabled suite truthful.
- [x] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- neutral open-request wording, the refusal copy and the send reason in the Copy deck -- the copy deck stays the single source.

**Acceptance Criteria:**
- Given Hugo's draft with only Lea's card placed, when he sends, then the trade is proposed, nothing of his is reserved, the toast names Lea's 7 days to choose, and his board reads "À choisir par Lea".
- Given Lea opens that trade, then she sees no "ACCEPTER" but the line inviting her to choose; when she counters with a card of Hugo's, Hugo accepts and the swap happens.
- Given a stale tab or a hand-made POST accepting an empty-sided trade, then it is refused with the new copy and nothing moves.

## Implementation Notes

## Plan Change Log

## Review Triage Log

### 2026-10-15 — Review pass
- verdicts: 25 findings — high 0, medium 6, low 14, false 5, maybe-false 0
- findings:
  - `[low]` `[reject]` (intent-alignment) the full flow's accept and swap are tested at the operation level, not on the board — the answer to an open request is an ordinary two-sided trade whose acceptance and swap the existing controller test "accepting swaps the cards…" covers; system tests are disabled.
  - `[false]` `[reject]` (intent-alignment) EXPERIENCE.md is edited to fit the build — the ticket leaves the refusal copy and counter to the build, and the Design Notes justify the gender-neutral wording for a dynamic name.
  - `[low]` `[reject]` (intent-alignment) the refusal code and copy were not proposed to the author before being fixed — an unattended run cannot ask; they are listed under Auto Run Result for the author's approval.
  - `[low]` `[reject]` (intent-alignment) an empty own side in edition still reads "0 carte" — the count is accurate in edition and the help line explains the empty side.
  - `[false]` `[reject]` (intent-alignment) the list's "À choisir" is asserted on the show page, not the index — both render the same `_list` partial and helper.
  - `[false]` `[reject]` (intent-alignment) the list keeps comma-joined titles, not "first +n" — deferred by the epic (deferred-work.md).
  - `[medium]` `[patch]` (verification-gap) the send rule's wiring is pinned by no running test — `sendable` now takes the whole `TradeChangedDetail`, the controller passes the event detail, vitest covers give empty/take filled and the reverse.
  - `[medium]` `[patch]` (verification-gap) the counter island's `help` prop is asserted nowhere — the counter island props test asserts friend `help` nil and own `help` the help line.
  - `[medium]` `[patch]` (verification-gap, other) a closed open request still reads "À vous de choisir" — grouped with the closed-labels entry below.
  - `[medium]` `[patch]` (blind-hunter) closed open requests read as if still open — the empty-side label is passed only while `trade.open?`, `_side` shows it only when given, a closed trade falls back to its count and empty list; controller test on a declined open request.
  - `[low]` `[patch]` (blind-hunter) a side whose card views do not resolve reads "À choisir" — `trade_side_title` returns it only for `lines.empty?`, "—" otherwise.
  - `[low]` `[patch]` (blind-hunter) no test closes an open request — an operation test declines, cancels and expires one, releasing nothing.
  - `[low]` `[reject]` (blind-hunter) `sent_offer` is captured through a closure — behavior is correct and the fix is a restructure, not a direct correction; no caller diverges.
  - `[low]` `[patch]` (blind-hunter) `both_sides_held` reads as a holdings check — renamed `no_empty_side`.
  - `[low]` `[reject]` (blind-hunter) the help rule is written in the island and the partial — the helper sets `help` only on the own side, so both render the same; no divergence shown.
  - `[low]` `[patch]` (blind-hunter) the partial's `empty:` local collides in name with the draft's `empty` hash — renamed `empty_label:`, helper `trade_empty_side_label`.
  - `[false]` `[reject]` (blind-hunter) `.trade-board__open`'s `flex-basis` rule reaches outside the actions bar — the class is rendered only inside `.trade-board__actions` (`_board.html.erb:46`).
  - `[low]` `[reject]` (blind-hunter) a stale accept of an open request repeats the instruction in the error, toast and line — cosmetic, on a stale tab only; the fix needs new copy or a redirect.
  - `[low]` `[patch]` (blind-hunter) `invalid_offer` in English no longer parallels `invalid_request` — reworded "Offer at most four different cards, with a quantity of at least one each."
  - `[low]` `[reject]` (blind-hunter) the help line is not tied to the send button for screen readers — it follows the side in reading order; tying it adds wiring for a rare path.
  - `[false]` `[reject]` (blind-hunter) EXPERIENCE.md may keep "ce qu'elle veut" elsewhere — grep finds none; English already reads "what they want".
  - `[medium]` `[patch]` (blind-hunter) no direct test for `trade_send_controller.ts` — grouped with the send-rule entry above.
  - `[medium]` `[patch]` (edge-case-hunter) a closed open request keeps its open labels — grouped with the closed-labels entry above.
  - `[low]` `[patch]` (edge-case-hunter) "To choose" for a side with unresolvable cards — grouped with the `trade_side_title` entry above.
  - `[low]` `[patch]` (edge-case-hunter) cancelling an open request toasts "Vos cartes ne sont plus réservées." though nothing was reserved — `trades.cancelled.open_text` ("%{name} n'a plus rien à choisir." / "%{name} has nothing left to choose.") when the own side is empty, in EXPERIENCE.md's Trade toasts, with a controller test.

## Auto Run Result

- **Summary:** the sender's own side may be empty at every send (proposal and counter) while the friend's side needs one to four cards; an empty offer reserves nothing. `Game::AcceptTrade` refuses a trade with an empty side with `trade_side_empty`, after the current-terms check and before any holding lock, moving nothing. Sending is gated by the friend's side only; the board shows "À choisir par Lea" / "À vous de choisir" on an open trade's empty side, the recipient's line in place of ACCEPTER, the help line under the empty own side in edition, the open send and cancel toasts, and the list's "À choisir".
- **Files:** `packs/game/app/operations/game/{trade_steps,propose_trade,counter_trade,accept_trade}.rb` (offer 0..4, request 1..4, `no_empty_side`), `app/controllers/trades_controller.rb` (open send and cancel toasts), `app/helpers/trades_helper.rb` (empty-side label, help, list "À choisir"), `app/views/trades/{_side,_board,_draft_board}.html.erb`, `app/frontend/lib/trade_board.ts`, `controllers/trade_send_controller.ts`, `components/TradeBoard.tsx`, `styles/trades.css`, `config/locales/{en,fr}.yml`, tests in `test/packs/game`, `test/controllers/trades_controller_test.rb`, `app/frontend/lib/trade_board.test.ts`, `test/system/trades_test.rb` (not run), `ux-gameble/EXPERIENCE.md`.
- **Review:** thorough (blind-hunter, edge-case-hunter, verification-gap, intent-alignment); 25 findings: 9 entries patched (3 medium, 6 low), none deferred, 11 rejected with reasons in the triage log. Follow-up review recommended: 3 medium entries patched; the unverified risk is the Stimulus send gate and the island's help line, still exercised in a browser only by the disabled system test.
- **For the author to approve:** failure code `trade_side_empty` and its copy ("Rien à recevoir pour l'instant : choisissez ce que vous voulez dans la collection de %{name}, puis renvoyez."); no card counter on an open trade's empty side; the neutral "ce qui lui plaît en retour" replacing "ce qu'elle veut"; the send reason "Placez au moins une carte du côté de %{name}."; the cancel toast "%{name} n'a plus rien à choisir.".
- **Verification:** `bin/rails test` 2597 runs, 0 failures; `npm run test:js` 328 passed; `npm run typecheck`, `i18n-tasks missing`, `bin/rubocop`, `packwerk check`, `zeitwerk:check` clean.
- **Residual risks:** not seen in a browser; the full send-counter-accept-swap flow is verified in pieces (operations and controller), not end to end.

## Design Notes

The ticket left the refusal code and copy, and the empty side's counter, to the build. The code `trade_side_empty` names AD-8's rule; the accepter is always the recipient and the request is never empty, so the empty side is always the one the accepter would receive, hence "Rien à recevoir pour l'instant". An empty side shows its text instead of a "0 carte" counter (English has no zero form, and the text already says it). EXPERIENCE.md's example lines gender Léa ("ce qu'elle veut"); the friend's name is dynamic, so the French copy uses "ce qui lui plaît" and EXPERIENCE.md is aligned to it.

## Verification

**Commands:**
- `bin/rails test test/packs/game test/controllers/trades_controller_test.rb` -- expected: all pass
- `bin/rails test` -- expected: all pass (system tests are skipped)
- `npm run test:js` and `npm run typecheck` -- expected: all pass
- `bundle exec i18n-tasks missing` -- expected: no missing key
- `bin/rubocop` -- expected: no offense
- `bundle exec packwerk check` and `bin/rails zeitwerk:check` -- expected: no violation
