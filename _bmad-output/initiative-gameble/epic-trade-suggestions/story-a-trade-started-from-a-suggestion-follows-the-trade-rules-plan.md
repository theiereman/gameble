---
title: 'A trade started from a suggestion follows the trade rules'
type: 'feature'
ticket: '4'
created: '2026-11-01'
status: 'built'
baseline_revision: 'c0c7ca4672bda64f2d74f31f1b372ea205f62a24'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A suggestion is read when the list renders, but its two ways in (the opener's prefilled board and ENVOYER) trust that read: a card the friend traded away since still lands on the board or in the proposal, and the prefilled board never becomes the friend's stored draft, so an edit is lost on reload and the address keeps re-applying the suggestion.

**Approach:** `Game::TradeSuggestions` gains one public reader that re-applies AD-38's spare rule to given card-seasons of one holder for one other player; the prefill (`TradesController#new`) and ENVOYER (`TradeSuggestionsController#create`) keep only the cards still spared. On the client, a prefilled board adopts its lines as the friend's stored draft the first time the player changes it or sends it, and replaces its address with the friend's plain new-trade address.

## Boundaries & Constraints

**Always:**
- Spare check per card-season X of game G, holder H, other player O: H's free copies of G (`quantity - reserved`, per edition, all seasons) minus the kept one (the free edition of best rarity, ties earliest season, exactly as `placed_edition` keeps it); X is still spared when X keeps ≥ 1 free copy after that, and G is not on H's side of an open, unexpired trade between H and O (H's offer in a trade H proposed to O, the request of a trade O proposed to H). The same rule serves the friend's side (H = friend, O = player) and the player's side (H = player, O = friend). Order of the given ids is kept; unknown ids are dropped.
- Prefill: after the existing key parsing (at most 4 per side, `Catalog::PublishedCardSeasonIds`), `take` keeps the card-seasons the friend still spares for the player, `give` those the player still spares for the friend; then the existing `trade_board_initial_lines` rules apply unchanged. A refused friend (private, banned, removed, not a friend) is refused as today, before any spare read. No prefill params: `new` is unchanged.
- ENVOYER: after `sent_sides`, the request keeps the card-seasons the friend still spares and the offer those the player still spares; a request that was non-empty and is left empty is refused with `:requested_cards_unavailable` through `refuse_suggestion` (existing copy and "insufficient" title), and nothing is created. Otherwise `Game::ProposeTrade` runs with the kept cards and the success path is unchanged (title-only toast, focus flash, no `trade_forget`).
- Prefilled board (`trade_board_controller.ts`, `prefilled` value true): on load and morph it neither reads, saves nor forgets the stored draft (as today). The first applied change that makes its lines differ from the prefilled lines, or a submit of its send form, adopts it: the `prefilled` value becomes false, the board's start lines become empty (so it then persists as a plain board: saves non-empty lines, forgets an empty board), the hidden prefill line markers are removed, the stored draft is saved from the current lines, and the address is replaced with the friend's plain new-trade address (`new_trade_path(friend: token)`, passed as the board's `board-url` value only when prefilled). The address replacement compares the full URL (path and query), keeps `history.state`, and the edit/restore replacements of the counter board keep working.
- A board send then forgets the stored draft as any board send (`flash[:trade_forget]`); a refused send lands on the plain new-trade page, which shows the stored draft that was sent.
- Opening a suggestion without changing it writes nothing on the server or in storage; the suggestion stays in the list; ABANDONNER on an unadopted board keeps the stored draft.
- The trade screen stays exempt from the Turbo cache (`turbo_exempts_page_from_cache`), so Back always re-fetches the address of the history entry.

**Never:** no new route, param, table, column or copy (the prefill address of the earlier entry is the only way in); no change to `Game::ProposeTrade`, the board's own `TradesController#create`, the stored-draft format, `FREE_EDITIONS`, `IN_OPEN_TRADES`, `fill` or the suggestion ranking; no reading of friends' goals or mutual suggestions (built in parallel inside `Game::TradeSuggestions`: touch only what this ticket adds there, and keep existing method bodies except the `placed_edition` extraction below); no spare check on a board send.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Six candidates | Friend spares 6 games of the player's goals | Opener address holds 4 keys in AD-38 order; the board places those 4 in that order | No error expected |
| Traded away since read | List read; friend then left with 1 copy of A (or A reserved, or A put on the friend's side of an open trade with the player) | Opening the read opener: A not placed, the other cards are; ENVOYER with the read params: trade requests the other cards only | All friend cards gone: refusal toast `requested_cards_unavailable`, no trade, redirect to the list |
| Player's give card | Prefill or ENVOYER `give` with a card the player holds once, or offers in an open trade to that friend | That card dropped from the player's side | No error expected |
| Editions | Friend holds A s1 ×1 (rarer) and A s2 ×1 | `A--s2` kept, `A--s1` dropped (the kept copy) | No error expected |
| Expired trade | A on the friend's side of an open trade past `expires_at` | A still spared | No error expected |
| Crafted prefill | Private or non-friend token; cards the friend lacks; unknown keys | Refused as today; lacking/unknown cards ignored | Existing refusal flash |
| Look without change | Stored draft D for the friend; open the suggestion, then ABANDONNER or Back | D unchanged; suggestion still listed | No error expected |
| Change the prefilled board | Remove or add a card, or change a quantity | Stored draft = the board's lines; address = plain new-trade; reload shows that draft, not the suggestion | No error expected |
| Send the prefilled board | ENVOYER LA PROPOSITION unchanged | Trade proposed with those cards; Back lands on the plain new-trade address with an empty board | Refused send: plain new-trade page with the sent lines as the stored draft |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/trade_suggestions.rb` -- the query (built by the earlier entry; the mutual entry is being built in parallel in this same file). Reuse `free_editions(friend_ids, card_ids)` (returns `{[holder_id, card_id] => [Edition]}`) and the kept-copy rule inside `placed_edition` (l.105-109): extract its first two lines into a private `spare_editions(editions)` (empty for no editions) and make `placed_edition` call it. Add one public `self.still_spared(card_season_ids, holder:, other:, now: Time.current)`, a small card-season→card id read (raw SQL on `catalog_card_seasons`, as this file already joins catalog tables), and a new SQL constant for H's side of open trades between H and O (pattern: `IN_OPEN_TRADES` l.40-49, `status = 'open' AND expires_at > :now`). Declare the new private methods on their own `private_class_method` line; leave the existing line as is. Skip all reads for an empty list.
- `app/controllers/trades_controller.rb` -- `board_prefill(friend)` (l.159-166): apply `still_spared` to each side after the id resolution, holder friend for `take`, `current_player` for `give`. File 210 lines (limit 400).
- `app/controllers/trade_suggestions_controller.rb` -- `create` (l.6-18): insert the spare filter between `sent_sides` and `Game::ProposeTrade` (a private method returning `Success({offer:, request:})` or `Failure(:requested_cards_unavailable)`; `Dry::Monads` is used as in `TradeProposals#sent_sides`); `sent_sides` returns `{offer: {card_season_id => "qty"}, request: {...}}`.
- `app/views/trades/_draft_board.html.erb` -- `trade_board_root_data(..., prefilled:)` (l.2-3): also pass `board_url: new_trade_path(friend: friend.token)` when prefilled; add `action: "submit->trade-board#send"` to the send form's data (beside `controller: "trade-board-send"`; the ABANDONNER span already uses a `click->trade-board#abandon` action the same way).
- `app/helpers/trades_helper.rb` -- `trade_board_root_data` (l.154-166) already maps `board_url` to `trade_board_board_url_value`; no change expected.
- `app/frontend/controllers/trade_board_controller.ts` (361 lines, limit 400) -- `prefilledValue` (make it writable), `persist()` (l.301-310), `storedDraftKey` (l.312), `replaceUrl()` (l.352-358: today returns when pathnames match, which would skip the prefill → plain replacement; compare `href`), `lineTargets`, `boardUrlValue`. Add a `send()` action and a private adopt step called from `persist()` when prefilled and `changed(state)`. Keep the logic small: the state change goes in the lib.
- `app/frontend/lib/trade_board.ts` (377 lines) -- `start`, `changed`, `restore`, `bySide`: add a pure `adopted(state)` (start lines emptied, lines kept) exported for the controller; test in `app/frontend/lib/trade_board.test.ts`.
- `app/views/trades/_screen.html.erb` l.3 -- `turbo_exempts_page_from_cache`: relied on, not changed.
- Tests to copy from: `test/domains/game/trade_suggestions_test.rb` (setup, `new_friend`, `goal`, `spare`, `second_edition`, `GameSets#unheld_cards` for extra cards: only 5 card-season fixtures exist), `test/controllers/trades_controller_test.rb` l.1186-1210 and l.1315-1366 (`goal_on`, `suggest_from_lea`, `board_lines`, prefill asserts), `test/controllers/trade_suggestions_controller_test.rb` (setup, `send_suggestion`, `items`), `test/system/trade_suggestions_test.rb` (setup, `sign_in`, `lea_draft`, `store_draft_for_lea`, `eventually`), `test/support/holdings.rb` (`hold(player, id, qty, reserved:)`), `Game::ProposeTrade` for open trades.
- Existing test that encodes the old behavior: `test/system/trade_suggestions_test.rb` "a suggestion opens on the board prefilled, leaving the friend's stored draft as it was" removes Green Hills on the prefilled board and asserts the stored draft unchanged; under this ticket that removal adopts the board. Drop only the removal step and its assert there (keep the rest), and cover the change in the new system test file. The mutual entry may edit that file in parallel: keep the edit to those lines.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/trade_suggestions.rb` -- `still_spared` + `spare_editions` extraction + the two reads -- the one place AD-38's rule lives.
- [x] `test/domains/game/trade_suggestion_spares_test.rb` (new file, to stay clear of the parallel edits) -- one test per query row of the matrix: spare kept; single copy, reserved copy and lacking dropped; editions (kept rarer edition dropped, other kept); friend's side of an open trade either proposer dropped, expired not; player as holder: own offer to that friend and the friend's request of the player dropped, a trade with another friend not; order kept; unknown ids and empty list (no query).
- [x] `app/controllers/trades_controller.rb` -- spare-filter the prefill sides.
- [x] `app/controllers/trade_suggestions_controller.rb` -- spare-filter the sent sides; empty request refusal.
- [x] `app/views/trades/_draft_board.html.erb` -- plain board URL value when prefilled; send action.
- [x] `app/frontend/lib/trade_board.ts` + `trade_board.test.ts` -- `adopted(state)`; vitest: lines kept, start emptied, `changed` true for non-empty lines and false for empty ones, picker and filters kept.
- [x] `app/frontend/controllers/trade_board_controller.ts` -- adopt on first change and on send; full-URL address replacement.
- [x] `test/controllers/trade_suggestion_prefills_test.rb` (new file) -- six candidates (opener href keys and board lines, 4 in order); opener read, then the friend's copy traded away / reserved / put in an open trade: not placed; give card the player no longer spares dropped; prefilled root carries `board-url` = plain new-trade path and the send form carries the send action, a plain board neither; ENVOYER with the read params after a card is gone: trade requests the rest; all gone: no trade, alert "Exemplaires insuffisants : une carte demandée n'est plus disponible. Rien n'a bougé." (fr, U+202F) with the insufficient title, redirect to the list; a crafted prefill for a single-copy card ignores it.
- [x] `test/system/trade_suggestions_test.rb` -- the minimal edit above.
- [x] `test/system/trade_suggestion_boards_test.rb` (new file) -- see AC.

**Acceptance Criteria:**
- Given a stored draft for Lea and her suggestion, when the player opens it and goes Back (and, separately, presses ABANDONNER), then the stored draft is byte-identical and the suggestion is still in the list.
- Given the prefilled board, when the player removes a card, then the address is the plain new-trade address (no `take`), the stored draft for Lea holds the board's remaining lines, and a reload shows those lines on the plain board.
- Given the prefilled board unchanged, when the player presses the board's send, then the trade requests the suggested cards, and Back lands on the plain new-trade address with no suggested card placed and no stored draft.
- Given a suggestion read on the list, when the friend's copy of one card is traded away before the opener is followed, then the board does not place that card and places the rest.

## Design Notes

Reading of "drops ... when the board opens or the proposal is sent": the suggestion's two ways in, the opener (board opens) and ENVOYER (the suggestion's proposal is sent). A send from the board is the player's own proposal of what the board showed, already filtered when it opened, and runs under the trade rules as any other; it is not filtered again.

Controller sketch:

```ruby
def board_prefill(friend)
  ...
  take = Game::TradeSuggestions.still_spared(sides[:take], holder: friend, other: current_player)
  give = Game::TradeSuggestions.still_spared(sides[:give], holder: current_player, other: friend)
  TradeSuggestionsHelper::Prefill.new(friend:, take:, give:)
end
```

No new copy: the empty-request refusal reuses `errors.game.requested_cards_unavailable` and `trades.insufficient`.

## Verification

Environment: work only in /home/teyermann/projets/gameble/.claude/worktrees/build-29-4 (never /home/teyermann/projets/gameble itself); before any rails command `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w29_4 CHROME_BIN=/usr/bin/chromium` (Postgres on 5433, schema loaded); other builds run in parallel, so use `PARALLEL_WORKERS=3` for the full suite. Shell output may be compressed by `rtk`; prefix `rtk proxy` for raw output. Do not commit.

**Commands:**
- `bin/rails test test/domains/game/trade_suggestion_spares_test.rb test/domains/game/trade_suggestions_test.rb test/controllers/trade_suggestion_prefills_test.rb test/controllers/trades_controller_test.rb test/controllers/trade_suggestions_controller_test.rb` -- expected: pass
- `bin/rails test test/system/trade_suggestion_boards_test.rb test/system/trade_suggestions_test.rb test/system/trades_test.rb` -- expected: pass
- `PARALLEL_WORKERS=3 bin/rails test` -- expected: pass
- `bundle exec packwerk check && bin/rails zeitwerk:check && bin/rubocop` -- expected: pass
- `npm run test:js && npm run format:check && npm run lint:css && npm run typecheck --if-present` -- expected: pass
- `script/check_planning_references && script/check_file_sizes` -- expected: pass

## Implementation Notes

- `still_spared` costs three reads (card ids of the given card-seasons, the holder's side of open trades with the other player, the holder's free editions) and none for an empty list or one of unknown ids only.
- The send action and the plain `board-url` value are rendered only on a prefilled board; `send()` adopts the board, then saves its lines, before Turbo submits the form.
- In the existing system test, the removal and its `assert_no_selector` were dropped; the stored-draft equality after opening is kept.
- Matrix audit added two tests: ENVOYER drops the player's give cards no longer spared (controller), and a refused send of the prefilled board lands on the plain board with what was sent as the stored draft, less a card the friend no longer holds, which the plain board prunes as for any draft (system).

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` The Implementation Notes say `still_spared` reads nothing for a list of unknown ids only, but `card_ids_of` still runs one read before the early return; only the empty list reads nothing — the claim is in this plan's notes, and the code is right (one cheap read for a crafted address), so the only fix is a plan edit, which triage rejects. Recorded here as the correction: unknown ids only cost one read.
  - `[low]` `[patch]` The editions test paired an epic season-1 edition with a common season-2 one, so it would pass if the kept copy were chosen by earliest season and rarity ignored — the test now holds one common season-1 copy and one rare season-2 copy of the same card and asserts the season-1 common stays (the rare later edition is the kept copy); 7 runs, 0 failures.

## Auto Run Result

- **Summary:** a suggestion's two ways in now check AD-38's spare rule again when they are followed, not when the list was read. `Game::TradeSuggestions.still_spared(card_season_ids, holder:, other:)` keeps the card-seasons of which the holder has a free copy beyond the kept one and whose game is not on the holder's side of an open, unexpired trade with the other player. The opener's prefilled board (`TradesController#new`) drops friend cards the friend no longer spares and give cards the player no longer spares. ENVOYER drops them too, and refuses with "Exemplaires insuffisants" when no friend card is left. On the client, a prefilled board stays untouched by storage while the player only looks. The first change, or a send, adopts it: it becomes the friend's stored draft and its address is replaced with the friend's plain new-trade address, so a reload or Back resumes the stored draft and never re-applies the suggestion.
- **Files changed:**
  - `app/domains/game/app/queries/game/trade_suggestions.rb`: `still_spared`, the kept-copy rule extracted into `spare_editions`, two small reads (`CARDS_OF_SEASONS`, `ON_HOLDER_SIDE`).
  - `app/controllers/trades_controller.rb`: the prefill keeps only still-spared cards on each side.
  - `app/controllers/trade_suggestions_controller.rb`: ENVOYER keeps only still-spared cards; empty request refused.
  - `app/views/trades/_draft_board.html.erb`: a prefilled board carries the plain new-trade address and the send action.
  - `app/frontend/lib/trade_board.ts`: `adopted(state)`.
  - `app/frontend/controllers/trade_board_controller.ts`: adopt on first change or send; address replacement compares path and query.
  - Tests: `test/domains/game/trade_suggestion_spares_test.rb`, `test/controllers/trade_suggestion_prefills_test.rb`, `test/system/trade_suggestion_boards_test.rb` (new), `app/frontend/lib/trade_board.test.ts`, and two lines dropped from `test/system/trade_suggestions_test.rb`, whose removal step encoded the old no-write-on-change behaviour.
- **Review findings:** 1 patched (low), 0 deferred, 1 rejected: the unknown-ids "no read" claim in these notes is wrong (one read), the code is right, and the fix would only edit the plan.
- **Follow-up review recommendation:** false (patched by verdict: high 0, medium 0, low 1).
- **Verification:**
  - Domain and controller tests (trade suggestion spares, prefills, trade suggestions, trades, suggestions controller): 100 runs, 0 failures; the patched spares test: 7 runs, 0 failures.
  - System tests `trade_suggestion_boards_test.rb`, `trade_suggestions_test.rb`, `trades_test.rb`: 24 runs, 0 failures.
  - Full `PARALLEL_WORKERS=3 bin/rails test`: 4082 runs, 0 failures (before the test-only review patch).
  - packwerk, zeitwerk, rubocop, vitest (797), prettier, stylelint, tsc, `script/check_planning_references` and `script/check_file_sizes` pass.
- **Residual risks:**
  - A send from the board is not filtered again: it is the player's own proposal of what the board showed, already filtered when it opened, and runs under the trade rules (a friend's last copy may be requested there).
  - Emptying a prefilled board adopts it as an empty board, which forgets an older stored draft for that friend; sending a prefilled board unchanged replaces the stored draft just before the send (forgotten on success).
  - After adoption, the suggestion row keeps its "current" look until the next render of the list.
  - `trade_suggestions.rb` and `test/system/trade_suggestions_test.rb` are also edited by the mutual-suggestions entry built in parallel; expect conflicts around `placed_edition` and the `private_class_method` lines.
  - No new copy was written.

