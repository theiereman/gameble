---
title: 'Trade board island: the draft, the counter and the swap'
type: 'feature'
ticket: '8'
created: '2026-10-07'
status: 'built'
baseline_revision: '80054deb4c433a5fea1a5f195a1a531d950c28b6'
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
      A board waiting for the player (show, and the list when that trade comes first) now carries the island's props, a card-s face for every card both players hold, as the counter page did.
    evidence: |-
      TradesHelper#trade_board_props renders CardComponent for each Game::HeldCopies row of both players on every À VOUS board so CONTRE-PROPOSER can open in place; on the phone the list page carries it though the board is hidden. Unverified: today's collections are small; what would settle it is the page weight of /trades for a player holding several hundred distinct cards. A fix would load the picker's faces when the edition opens.
    location: >-
      app/controllers/trades_controller.rb (load_board), app/helpers/trades_helper.rb (trade_board_props)
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** A player cannot start a trade from the screens (no draft, PROPOSER UN ÉCHANGE on a friend's profile is disabled), countering leaves the board for a separate form whose picks are lost on a refusal, "ANNULER LES MODIFICATIONS" asks nothing, and accepting moves the cards without the swap (R2, R6).

**Approach:** A draft board (`GET /:locale/trades/new?friend=<token>`, "BROUILLON") drawn by the TradeBoard island and kept only in the browser's localStorage until "ENVOYER LA PROPOSITION" posts it (`POST /:locale/trades` → `Game::ProposeTrade`); the island also mounts on an "À VOUS" board and toggles in place into "EN ÉDITION" (CONTRE-PROPOSER) and back ("ANNULER LES MODIFICATIONS", confirmed when something changed), its edits kept in the browser per round so a refused counter keeps them; after an acceptance the concluded board plays the swap (about 0.75 s), a crossfade under reduced motion.

**Decisions (autonomous run, author away):**
- Entry points: the friend profile's PROPOSER UN ÉCHANGE and a closed board's "NOUVEL ÉCHANGE AVEC LÉA" (still friends only) link to the draft URL; when the pair already has an open trade it redirects to that board with the one-at-a-time refusal ("UN ÉCHANGE À LA FOIS · Un échange est déjà ouvert avec Léa.", inline and toast). The friend row on Amis gets no button here (its layout belongs to Amis).
- The draft URL for a non-friend, a banned or deleted player, an unknown token or oneself answers 404; nothing is written by the GET.
- Browser storage: one localStorage entry per draft (player token + friend token) and per counter round (player token + trade token + expiry second, which a counter restarts); an entry exists only while the sides differ from where they started; it is removed when the proposal or counter is sent (the next board forgets it), by ABANDONNER, and by ANNULER LES MODIFICATIONS. Unreadable storage degrades to no draft.
- ABANDONNER deletes the draft and goes to the trades list, without confirmation.
- The concluded board shows the sides crossed: the friend's column "LÉA A REÇU" holds what the player gave, the player's "VOUS AVEZ REÇU" what they received, tagged "NOUVEAU" while still new in the collection (the collection's own watermark).
- The swap plays once, on the board the accept redirects to; the focus then goes to the status line. A board just opened (show, draft) focuses its heading; entering edition focuses the player's add slot.
- Trade pages are exempted from Turbo's cache (architecture: trade pages are never cached).
- English and the lines outside the copy deck (validity line, confirmation dialog) are autonomous wording.

## Boundaries & Constraints

**Always:** writes only through `Game::ProposeTrade` / `Game::CounterTrade` (no new operation, no migration); GETs never write; tokens only (no database id in props, fields, storage keys or URLs); faces from CardComponent; no `style` attribute in server HTML; strings in fr and en; island ↔ page only through `gameble:*` events declared in `lib/events.ts`; no form nested in another (the counter and draft forms sit in the actions area, the island's hidden fields reach them with the `form` attribute); without JavaScript the counter page and its quantity fields keep working.

**Never:** live updates or broadcasts (5.9); changes to trade operations; a draft row on the server; a client router or store; new rules for who may trade.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open a draft | friend, no open trade | BROUILLON board, both sides EN ÉDITION and empty, validity line, ENVOYER disabled with its reason | n/a |
| Leave and return | picks made, navigate away, reopen | same picks restored from the browser; no row on the server | storage unusable: empty draft |
| Send draft | each side ≥ 1 card | ProposeTrade, toast "PROPOSITION ENVOYÉE", board EN ATTENTE, draft forgotten | refusal: back to the draft with its message inline + toast, picks kept |
| Pair already trading | open trade exists | redirect to that board, one-at-a-time refusal | n/a |
| Not a friend / unknown / self | GET or POST | 404 (GET), "not friends" refusal to the list (POST) | n/a |
| Abandon | ABANDONNER | entry removed, trades list | n/a |
| Counter in place | À VOUS, CONTRE-PROPOSER | no navigation; chip EN ÉDITION, sides editable, RENVOYER / ANNULER LES MODIFICATIONS; URL becomes the counter URL | no JS: the counter page |
| Undo unchanged | nothing changed | back to the received proposal at once | n/a |
| Undo changed | something changed | confirmation dialog; confirm restores and forgets, continue keeps editing | n/a |
| Counter refused | server refusal | counter page, edits restored from the browser | n/a |
| Accept | ACCEPTER succeeds | concluded board, cards arc across (~0.75 s), ring, confetti, faint flash; focus on the status line | reduced motion: a 200 ms crossfade |
| Closed board | CLOS, still friends | "NOUVEL ÉCHANGE AVEC LÉA" | no longer friends: no button |

</intent-contract>

## Code Map

- `config/routes.rb` -- `resources :trades` gains `new`, `create` (token constraint stays on members).
- `app/policies/trade_policy.rb` -- `new?`, `create?` (player).
- `app/controllers/trades_controller.rb` -- `new` (friend via `Accounts::PlayerByToken` + `Game::FriendshipBetween`, not banned/deleted; open trade from the `Game::TradesOf` lists by friend id), `create` (keys resolved like `counter` via `quantities`, then `Game::ProposeTrade`); island data for a `:yours` board on `index`/`show` (shared private loader with `edit`); `accept` sets `flash[:trade_swap]`; success of create/counter sets `flash[:trade_forget]` (the storage key); `rate_limit` covers `create`; concluded board loads `Game::CollectionSlots` for NOUVEAU; closed board asks `FriendshipBetween`.
- `app/helpers/trades_helper.rb` -- `trade_board_props` gains `editing`, `draftKey`, `formId`, `readMessage`, per side `readHtml`; new `trade_draft_props`, `trade_draft_key`, `trade_counter_key`; `trade_side_labels`/board columns crossed for `:concluded`.
- `app/views/trades/_board.html.erb` -- body no longer a form; actions area holds the read set (button_to forms) and the counter `<form id>` set, the confirmation `<dialog>`, chip pair; `data-controller="trade-board"`; closed: NOUVEL ÉCHANGE; concluded: `trade-swap`. `_side.html.erb` -- quantity fields get `form:`; NOUVEAU tag. New `_draft_board.html.erb`, `new.html.erb`; `_screen.html.erb` renders the draft board; `index/show/edit/new` exempt from Turbo cache.
- `app/frontend/components/TradeBoard.tsx` -- read mode (sides from `readHtml`), editing toggle on `gameble:trade-editing`, restore from / save to storage, `changed` in `gameble:trade-changed`, hidden inputs with `form`.
- New `app/frontend/lib/trade_draft.ts` (+ test) -- storage key prefix, read/save/forget, lines equality.
- New `app/frontend/lib/trade_swap.ts` (+ test) -- arc path and keyframes.
- `app/frontend/lib/events.ts` -- `gameble:trade-editing`; `TradeChangedDetail.changed`.
- New `app/frontend/controllers/trade_board_controller.ts` (edit/undo/restore/abandon/forget, heading focus, URL replace) and `trade_swap_controller.ts`; `trade_send_controller.ts` unchanged.
- `app/frontend/styles/trades.css` -- action sets, static wrapper, NOUVEAU tag, swap ring/confetti/flash, validity line.
- `app/views/friend_profiles/show.html.erb` -- button links to the draft; `friend_profiles.show.soon` removed.
- `config/locales/{en,fr}.yml` -- `trades.chip.draft`, `trades.board.valid`, `trades.actions.{send,abandon,again}`, `trades.one_at_a_time.*`, `trades.undo_dialog.*`, `trades.side.new`.
- Tests: `test/controllers/trades_controller_test.rb`, `test/controllers/friend_profiles_controller_test.rb` (the disabled button assertion), `test/system/trades_test.rb`, `test/system/friends_test.rb` (if it asserts "Bientôt disponible"), vitest for the two libs.

## Tasks & Acceptance

**Execution:**
- [ ] `config/routes.rb`, `app/policies/trade_policy.rb`, `app/controllers/trades_controller.rb` -- draft and create, island data on À VOUS boards, flashes for forget and swap, NOUVEAU and trade-again reads
- [ ] `app/helpers/trades_helper.rb` -- props, keys, crossed concluded columns
- [ ] `app/views/trades/*`, `app/views/friend_profiles/show.html.erb` -- boards, draft, actions, dialog, cache exemption, profile button
- [ ] `app/frontend/lib/{trade_draft,trade_swap,events}.ts`, `components/TradeBoard.tsx`, `controllers/{trade_board,trade_swap}_controller.ts`, `styles/trades.css` -- island modes, toggle, storage, swap
- [ ] `config/locales/{en,fr}.yml` -- strings
- [ ] tests: controller (draft 200/404/redirect, create success and refusals, counter/accept flashes, concluded columns and NOUVEAU, NOUVEL ÉCHANGE), vitest (storage, equality, arc), system (draft kept across a visit then sent; in-place counter with undo confirmation; accept plays the swap and reduced motion skips it; profile button opens the draft)

**Acceptance Criteria:**
- Given two friends without a trade, when one opens PROPOSER UN ÉCHANGE, picks a card on each side, leaves for the hub and comes back, then the picks are there and no trade exists; sending it creates the trade and the board shows EN ATTENTE.
- Given an À VOUS board, when the player presses CONTRE-PROPOSER, changes a side and presses ANNULER LES MODIFICATIONS, then a confirmation appears, and confirming restores the received proposal in place.
- Given an À VOUS board, when the player accepts, then the cards animate across and the focus lands on the status line; with Animations réduites, no card moves.

## Implementation Notes

- Subagents unavailable, done in-session (implementation and the quick review lens).
- Draft: `GET /:locale/trades/new?friend=<token>` (TradesController#new) renders the list beside `trades/_draft_board` (BROUILLON chip, validity line, the island with both sides empty and in edition, `form#trade-draft-form` in the actions with the friend's token, ENVOYER LA PROPOSITION, ABANDONNER); `POST /:locale/trades` (#create) resolves the card keys like the counter (`with_sides`, shared with #counter) and runs `Game::ProposeTrade`. A friend must be a friend, not banned, not deleted (`tradable?`); otherwise the GET answers 404 and the POST goes to the list with the not-friends refusal. An open trade with the friend (from the `Game::TradesOf` lists) redirects to its board with "UN ÉCHANGE À LA FOIS".
- Browser storage (`lib/trade_draft.ts`): `gameble:trade-draft:<player token>:<friend token>` for a draft, `…:<player token>:<trade token>:<expiry second>` for a counter round. The island writes an entry only while its sides differ from where they started (`sameLines`), removes it otherwise, and restores an entry through `initialLines`, so a card no longer available drops. After a successful send the controller sets `flash[:trade_forget]` and the next board's `trade-board` controller forgets the entry; ABANDONNER forgets it before the link; ANNULER LES MODIFICATIONS resets the island, which forgets it.
- In-place counter: on an À VOUS board (show, and index when the first trade is the player's) the controller loads both holders' cards and the island mounts in read mode, drawing each side from the server-rendered `_side` HTML (`readHtml`) and the received line. The actions hold two sets: the read set (button_to forms, CONTRE-PROPOSER link wrapped for `trade-board#edit`) and `form#trade-counter-form` (RENVOYER, ANNULER LES MODIFICATIONS wrapped for `trade-board#undo`), shown one at a time with the matching chip; the island's hidden fields and the no-JS quantity fields reach the form through the `form` attribute (no nested forms). The `trade-board` controller dispatches `gameble:trade-editing`, swaps the sets and chips, replaces the URL (board ↔ counter, keeping Turbo's history state) and opens `trade-undo-dialog` when `gameble:trade-changed` said something changed. The counter page keeps working without JavaScript and is where a refusal lands, with the edits restored.
- Swap: `accept` sets `flash[:trade_swap]`; the concluded board (`trade-swap` controller) moves each `.trade-card` of a column from the other column's centre along `swapKeyframes` (`lib/trade_swap.ts`: quadratic arc pushed along the flight's normal, friend's column over, player's under, left/right on a stacked board; squash before landing) for 750 ms, with the ring, confetti and a faint flash at mid-flight, then focuses the status line; under reduced motion (setting or system, read at use) both columns fade in over 200 ms. The play value is cleared on connect so a restored page never replays it.
- Concluded boards show the crossed columns (`trade_board_lines`): the friend's column holds what the player gave, the player's what they received, tagged NOUVEAU while `Game::CollectionSlots` still calls them new. Closed boards offer NOUVEL ÉCHANGE AVEC LÉA while the two may still trade.
- Board heading focused when a board or a draft opens (show, new); trade pages exempted from Turbo's cache (index, show, edit, new).
- Friend profile: PROPOSER UN ÉCHANGE links to the draft URL (which opens the open trade instead when there is one); `friend_profiles.show.soon` and `.friend-profile__soon` removed. The friend row on Amis has no button (not in this ticket).
- Shared surfaces: `config/routes.rb` (trades `new`, `create`), `config/locales/{en,fr}.yml` (`trades.one_at_a_time`, `trades.undo_dialog`, `trades.chip.draft`, `trades.board.valid`, `trades.side.new`, `trades.actions.{send,abandon,again}`; `friend_profiles.show.soon` removed), `app/frontend/lib/events.ts` (`gameble:trade-editing`, `changed`), `app/views/trades/_board.html.erb` (rewritten actions and mount).
- Visual check by throwaway screenshots (desktop and phone: draft, À VOUS, in-place edition, undo dialog, swap mid-flight, concluded), not committed.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 2, false 1, maybe-false 1 (quick lens run in-session, subagents unavailable)
- findings:
  - `[low]` `[patch]` replacing the URL between the board and the counter page left the history trail of the contextual back (lib/history_trail.ts) naming the old path for that entry — `trade-board#replaceUrl` now records the new path for the current entry.
  - `[low]` `[reject]` the browser entry of a counter round stays in localStorage when the round ends without the player sending or discarding it (the friend cancels, the trade expires) — a few bytes per abandoned round, never read again (the key carries the round); pruning would add a sweep for no visible effect.
  - `[false]` `[reject]` Turbo's own record of the current location goes stale after `history.replaceState` — Turbo reads `window.location` on a restoration visit and same-page detection needs an anchor; the trade pages are exempt from its cache, so no stale snapshot is shown (system test: in-place counter, undo, then send).
  - `[maybe-false]` `[defer]` every À VOUS board now carries both players' card faces for the in-place edition — recorded in `deferred` (medium, unverified); what would settle it: the page weight of /trades for a player holding several hundred cards.

## Design Notes

Storage value: `{"take":[{"key":"portal--s1","quantity":2}],"give":[…]}` under `gameble:trade-draft:<key>`; restored through `initialLines` against the current maxima, so a card no longer held drops. Arc: quadratic Bezier from the opposite column's offset to 0, control point at the middle pushed along the normal (friend's column over, player's under; on a stacked phone board left/right), squash `scale(1.1, 0.88)` just before landing.

## Verification

**Commands:**
- `bin/rails test` (non-system, PARALLEL_WORKERS=2, lane DB) -- green
- `bin/rails test test/system/trades_test.rb test/system/friends_test.rb` (PARALLEL_WORKERS=1) -- green
- `npm run typecheck`, `npx vitest run`, `bin/rubocop` on changed Ruby, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` / `unused` -- clean

## Auto Run Result

- **Summary:** a new trade starts as a draft: PROPOSER UN ÉCHANGE on a friend's profile and NOUVEL ÉCHANGE AVEC LÉA on a closed board open `/trades/new?friend=<token>`, a board marked BROUILLON with the validity line, both sides in edition and empty, drawn by the TradeBoard island and kept only in the browser (localStorage) until ENVOYER LA PROPOSITION posts it to `Game::ProposeTrade`; ABANDONNER deletes it; a pair already trading lands on its open trade with "UN ÉCHANGE À LA FOIS". An À VOUS board now carries the island: CONTRE-PROPOSER turns it into EN ÉDITION in place (chip, actions, URL), ANNULER LES MODIFICATIONS restores the received proposal at once or, when something changed, after a confirmation dialog; the edits of a round are kept in the browser, so a counter refused by the server comes back with them. Accepting plays the swap (each column's cards arc from the other side, one over and one under, squash, ring, confetti and faint flash, about 0.75 s, then focus on the status line), a 200 ms crossfade under Animations réduites; the concluded board shows the crossed columns with NOUVEAU on the cards still new. The board heading takes the focus when a board or a draft opens; trade pages are no longer cached by Turbo. fr and en copy.
- **Files:**
  - `config/routes.rb`, `app/policies/trade_policy.rb` -- trades `new` and `create`.
  - `app/controllers/trades_controller.rb` -- draft and sending, island data on À VOUS boards, forget and swap flashes, NOUVEAU and trade-again reads, shared side reading.
  - `app/helpers/trades_helper.rb` -- island props for the board and the draft, storage keys, crossed concluded columns.
  - `app/views/trades/{_board,_side,_screen,index,show,edit}.html.erb`, new `_draft_board`, `_undo_dialog`, `new` -- boards, actions, dialog, cache exemption.
  - `app/views/friend_profiles/show.html.erb`, `app/frontend/styles/friends.css` -- PROPOSER UN ÉCHANGE links to the draft.
  - `app/frontend/components/TradeBoard.tsx`, new `controllers/{trade_board,trade_swap}_controller.ts`, new `lib/{trade_draft,trade_swap}.ts` (+ tests), `lib/events.ts`, `styles/trades.css` -- read mode, toggle, storage, swap.
  - `config/locales/{en,fr}.yml` -- new trade strings; `friend_profiles.show.soon` removed.
  - Tests: `test/controllers/trades_controller_test.rb`, `test/controllers/friend_profiles_controller_test.rb`, `test/policies/trade_policy_test.rb`, `test/system/trades_test.rb`, `test/system/friends_test.rb`.
- **Review:** 1 patch (low: history trail after the URL replacement), 1 deferred (props weight on À VOUS boards, medium unverified), 2 rejected (stale counter-round entries in localStorage: negligible; Turbo location after replaceState: false).
- **Follow-up review recommended:** false (patched: 0 high, 0 medium, 1 low).
- **Verification:** `bin/rails test` (non-system, PARALLEL_WORKERS=2, lane DB): 1641 runs, 0 failures; `bin/rails test test/system/trades_test.rb test/system/friends_test.rb` (PARALLEL_WORKERS=1): 13 runs, 0 failures (after the patch); `npm run typecheck`: clean; `npx vitest run`: 18 files, 160 tests passed; `bin/rubocop` on changed Ruby, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused`, `bin/brakeman`: clean. Screenshots checked by eye (desktop and phone: draft, À VOUS, in-place edition, undo dialog, swap mid-flight, concluded), not committed.
- **Residual risks:** the friend row on Amis still has no PROPOSER UN ÉCHANGE (the profile has it); English copy and the lines outside the copy deck (validity line, confirmation dialog, "Abandon") are autonomous wording; the concluded board's columns changed meaning (crossed); props weight on À VOUS boards (deferred); 5.9 (live updates) may replace the board by stream: a replaced board re-mounts the island, whose edits survive in the browser.

### Merge of develop (0bb5424) and the live refresh

- develop merged into the lane branch (merge commit), bringing the private stream and live updates. Conflicts in `app/frontend/lib/events.ts` (both sides' events kept: `trades-updated`, `friends-updated`, `trade-editing`, `changed` on `trade-changed`) and `app/views/trades/_screen.html.erb` (the draft branch and the board locals kept, with the live refresh).
- The trades screen now carries the live refresh on every page, the counter page and the draft included, and an element can hold it back with `data-live-refresh-hold`: `live_refresh_controller.ts` waits while one is present and retries when it goes (a MutationObserver on that attribute). The `trade-board` controller sets it while the board is in edition (the counter page and the draft from the start, the in-place counter from CONTRE-PROPOSER) and removes it when the edition ends, so a partner's update never morphs over unsent picks; when the edited trade was closed meanwhile, the board catches up on leaving the edition (ANNULER LES MODIFICATIONS), and sending the counter gets the server's refusal. The draft page never refreshes (its picks live in the browser anyway). The `trade-swap` controller holds the refresh while the swap plays, so the accepter's own update morphs the board only after the cards have landed.
- Outside edition, a refresh remounts the island with the new props (turbo-mount keeps its element out of the morph); a counter round's edits survive in the browser.
- Tests: two new system tests in `test/system/live_updates_test.rb` (a partner's proposal and cancel during an in-place counter keep the picks, and the board shows the cancelled trade once the edition is discarded; the swap's refresh comes after the cards land), both checked to fail without the hold; `test/integration/player_stream_tag_test.rb` now expects the live refresh on the counter page and the draft, held by a board in edition.
- Verification after the merge: `bin/rails test` (PARALLEL_WORKERS=2): 1676 runs, 0 failures; `bin/rails test test/system/live_updates_test.rb test/system/trades_test.rb test/system/friends_test.rb` (PARALLEL_WORKERS=1): 18 runs, 0 failures; `npm run typecheck`, `npx vitest run` (163 tests), `bin/rubocop`, `bundle exec packwerk check`, `i18n-tasks missing` and `unused`: clean.
