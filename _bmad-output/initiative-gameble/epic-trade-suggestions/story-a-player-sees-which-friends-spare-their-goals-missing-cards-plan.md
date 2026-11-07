---
title: 'A player sees which friends spare their goals'' missing cards and starts a trade from one'
type: 'feature'
ticket: '2'
created: '2026-11-01'
status: done
baseline_revision: '438ef8b0c978b4abbe848030ccb12bc6f32e4314'
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

**Problem:** A player working on goals cannot see which friends hold spare copies of the games their goals miss, so trading never moves a goal forward unless they search every friend's collection by hand.

**Approach:** A new read-only query `Game::TradeSuggestions` computes at most 3 one-sided suggestions (one per friend, up to 4 friend cards each) by AD-38's spare and ranking rules; the trade list on every Échanges page shows them in a SUGGESTIONS section as DESIGN.md/EXPERIENCE.md draw it; each row's ENVOYER posts the suggestion as a proposal through `Game::ProposeTrade`, and its opener is a GET link to the new-trade board prefilled from the address (friend token plus `slug--sN` card keys), which never writes the friend's stored draft.

## Boundaries & Constraints

**Always:**
- Spare rule (AD-38), per holder and game: free copies are `quantity - reserved` per card-season, summed over the game's editions (any season). The holder keeps one free copy, taken from the free edition of best rarity (ties: earliest season number); the game is a spare when at least one free copy remains after that. The placed edition is, among the remaining free copies, the edition with the most free copies, then the earliest season number. Two copies with one reserved is no spare.
- A game already on the friend's side of an open, unexpired trade between the two (`status: "open"`, `expires_at > now`; the request of a trade the player proposed, the offer of one the friend proposed) is not a spare of that friend.
- Player's missing games: the union of `missing_card_ids` of all their `Game::GoalNeeds` (game sets and custom sets); each game's goal positions are those of the needs that miss it.
- Friends considered: `Game::FriendsPresence.call(player)` rows whose state is not `:private` (good standing, not removed, not private). No suggestions at all when the player is not `Game::Visibility.open_to_friends?`, has no goal, or nothing is missing.
- Ranking: a friend's spare games for the player rank by lowest goal position holding the game, then placed edition rarity (rarest first), then card slug. Friends rank by the number of distinct spare games (before any cap), then friendship `created_at` ascending, then friend token. Fill in friend order: skip games already placed on a higher suggestion, keep the first 4 remaining, drop a friend left with none, stop at 3 suggestions. Every placed line has quantity 1. The player's side stays empty (mutual suggestions are a later entry, but the prefill and the send already accept a give side).
- The query runs inside GETs on the reading role and writes nothing; its query count must not depend on the number of friends (batched reads only).
- Every Échanges page that renders the trade list (index, show, new, choose, counter/edit) shows the section; none when there is no suggestion (no heading, line or empty state).
- Row (EXPERIENCE.md Échanges "Suggestion row", Accessibility Floor "Trade suggestions", DESIGN.md "SUGGESTIONS"/"Suggestion row"): avatar, name over presence, ENVOYER; bookmarks of goals served in number order with "×n" when n > 1 placed cards serve that goal; title summary. The opener is a link sibling stretched over the row by CSS (never wrapping ENVOYER), first in tab order; its accessible name is the copy deck row name followed by the presence. Name, presence, summary, bookmarks, ×n and avatar are `aria-hidden`; ENVOYER stays exposed with its own name. The row whose friend and cards equal the board's current prefill carries `aria-current="true"` and the opened look.
- The suggestion names the friend and the player's own goals and cards only, never anything about the friend's goals.
- ENVOYER: POST with the friend token and the cards as `take[slug--sN]=1` (and `give[...]` when present); the server checks it as any proposal (friendship, privacy, holdings). Success: no `trade_forget` (the stored draft stays), the title-only toast, redirect to `trades_path`; the focus lands on the opener of the suggestion now at the sent row's position, else on the sent trade's row in the list. Failure: the same refusal flash as the board's send, redirect to `trades_path`.
- Prefill: `GET new_trade_path(friend: token, take: [keys], give: [keys])`; keys parse with `trade_card_key_parts`, resolve through `Catalog::PublishedCardSeasonIds`, at most 4 per side; a card the side's holder lacks or cannot place is ignored (existing `trade_board_initial_lines` rules). A prefilled board neither reads, saves nor forgets the stored draft, on load, on edit, on morph or on ABANDONNER; sending from it forgets the stored draft as any board send does. Without prefill params, `new` behaves exactly as today.
- While focus is inside the SUGGESTIONS section, live refresh is held (the existing `data-live-refresh-hold` mechanism), so a recomputed list never removes the focused row.
- Copy in both locales; French uses U+202F before `:` and as the copy deck shows; the UX-specified French copy is used verbatim (EXPERIENCE.md Copy deck "Trade suggestions" and "Trade toasts"); the English below is new.
- Every new controller action has a Pundit policy; no database id in URLs, HTML, DOM ids or params (tokens, slugs and season numbers only); no `style` attribute; no markup built in script.

**Never:** no table, column, cache or broadcast for suggestions; no dismissal; no mutual suggestions or reading of friends' goals (entry 3); no write-on-change of the prefilled draft and no address replacement (entry 4); no goal bookmarks on board cards (entry 9); no change to `Game::ProposeTrade`, the trade list's group order, or the stored-draft format.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Spare of each missing game | Goal misses A and B; friend F holds 2 free copies of each | One suggestion for F with A and B, empty player side | No error expected |
| Single copy | Friend G holds 1 copy of A | G not suggested | No error expected |
| Reserved spare | Friend H holds 2 copies of A, 1 reserved | H not suggested | No error expected |
| Editions summed | F holds A in two editions, 1 free copy each | Spare; kept copy is the rarer edition, the other is placed | No error expected |
| In an open trade | F's 2 copies of A; A on F's side of an open trade between the pair (either proposer) | A not placed for F | Expired-but-unswept trade does not exclude |
| Private, banned, deleted friend | Friend with spares is private / banned / deleted | Never in the result or the page | No error expected |
| Private player | The player is private | No suggestions; section absent | No error expected |
| No goal / nothing missing | No goals, or goal complete | Empty result | No error expected |
| More than 4 spares | F spares 6 games across goals 1 and 2 | 4 placed: goal 1 games first, then rarest, then slug | No error expected |
| Same game, two friends | F (3 spares) and G both spare A | A placed only for F; G keeps its other games, or is dropped when A was its only one | No error expected |
| More than 3 friends | 4 friends with spares | 3 suggestions in rank order (count, friendship age, token) | No error expected |
| Library set | Goals never include it; a library set exists | It never feeds suggestions | No error expected |
| ENVOYER | Row sent | Trade open to F with those cards requested; toast "Proposition transmise" alone; row gone (F's games now in a trade); stored draft for F intact | Refusal flash (e.g. friend went private, card gone) and redirect to the list |
| Prefill opener | GET new with friend and take keys | Draft board with those cards on F's side; stored draft neither read nor written | Unknown, unpublished or unheld keys ignored; non-friend or private friend refused as today |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/goal_needs.rb` -- `GoalNeeds.call(player)` → `Need` (position, `missing_card_ids` = catalog card ids, `custom?`, `set`); reuse as is.
- `app/domains/game/app/queries/game/friends_presence.rb` -- `FriendsPresence.call(player)` rows (`player`, `state`, …), state `:private` when not open to friends; use as the friend list and keep the row for the presence line.
- `app/domains/game/app/queries/game/held_games.rb` -- raw SQL joining `game_holdings` to `catalog_card_seasons` (pattern for the friends' holdings read; also join `catalog_seasons.number` and `catalog_cards.slug`). Rarity is `catalog_card_seasons.rarity` smallint 1..5 (`Catalog::Rarity::TIERS`).
- `app/domains/game/app/queries/game/open_trade_counts_by_friend.rb`, `models/game/trade.rb`, `trade_item.rb` -- trade/item columns (`proposer_id`, `recipient_id`, `status`, `expires_at`, `side` offer/request, `card_season_id`).
- `app/domains/game/app/models/game/friendship.rb` -- `Friendship.of(id)` with `low_player_id`, `high_player_id`, `created_at`.
- `app/controllers/trades_controller.rb` -- `new` (l.24-37), `create` (l.46-64), private `befriended`, `sent_sides`/`quantities` (l.170-190), `refused`/`show_refusal`/`toast` (l.220-238), `INSUFFICIENT`. Every action rendering `trades/screen` must also load the suggestions (`index`, `show`, `new`, `choose_friend`, `edit`). File is 240 lines (limit 400): extract the shared proposal helpers into a concern rather than duplicating them.
- `app/helpers/trades_helper.rb` -- `trade_card_key(view)` = `"slug--sN"`, `trade_card_key_parts`, `trade_board_editor(friend_lines, own_lines, own_held:, friend_held:, picks:)` (builds lines and `faces` from received lines), `trade_draft_editor`, `trade_board_root_data`. Lines passed in need `card_season_id` and `quantity` (`Game::TradesOf::Line` fits). The file is near 230 lines: put suggestion helpers in a new `TradeSuggestionsHelper`.
- `app/views/trades/_screen.html.erb`, `_list.html.erb` -- the list column; insert the section after `.trades__new`, before the empty panel and groups. `_list` row markup and `trade-row` classes are the model for the row.
- `app/views/trades/_draft_board.html.erb` -- renders `_edit_side` with `lines: []` and no faces: render `editor[:friend|:own][:lines]`, the `trades/faces` partial for `editor[:faces]`, and hidden markers `data-trade-board-target="line"` with `side`, `key`, `quantity` (what `startFromMarkup` reads; see `_side.html.erb:17`).
- `app/frontend/controllers/trade_board_controller.ts` (354 lines) -- `startFromMarkup` passes `readDraft(draftKey)`; `persist()` saves or forgets; `abandon()` forgets; `morphed()` re-reads and persists. Add a `prefilled` Boolean value that bypasses all four.
- `app/helpers/goals_helper.rb` -- `goal_bookmark(number, size:)` (decorative, aria-hidden), `goal_set_name(target)`.
- `app/helpers/presence_helper.rb` -- `presence_text(row)`; `app/views/friends/_presence.html.erb` the visible presence.
- `app/helpers/friends_helper.rb` -- `friend_name(player)`.
- `app/components/button_component.rb` -- supports `href`, `method: :post`, `params`, `size: :small`, `variant: :secondary`, `aria_label`.
- `app/views/shell/_toasts.html.erb`, `app/components/toast_component.html.erb` -- a toast renders only from `notice`/`alert` and always prints a message paragraph: add a title-only toast (blank message prints no paragraph), driven by its own flash key; check `toast_controller.ts` shows it.
- Focus after a redirect: existing pattern is a flash value turned into `autofocus` (`personalizations/show.html.erb:12`, `public_profiles/_showcase.html.erb`).
- `app/frontend/lib/live_refresh_hold.ts` -- `holdLiveRefresh(element, hold)`; `live_refresh_controller` refreshes when the hold attribute disappears.
- `app/frontend/styles/trades.css` (198 lines; `.trades__group`, `.trade-row`, `[aria-current]` look at l.133), `collection-goals.css` (bookmarks), `trades-responsive.css`; import a new `trades-suggestions.css` in `app/frontend/entrypoints/application.css` beside the trades imports (l.33-37).
- `config/routes.rb:143-155` -- trades resources; add a collection POST for the suggestion send.
- `app/policies/trade_policy.rb` / `test/policies/trade_policy_test.rb` -- `player?` pattern.
- Locales: `en.yml` is sorted (i18n-tasks normalised; `trades.suggestions` goes between `trades.side` and `trades.throttled`); `fr.yml` `trades:` block l.1713-1837; dynamic keys need no special handling here.
- Tests to copy from: `test/domains/game/goal_needs_test.rb` (`GameSets#insert_set`, `unheld_cards`, `CustomSets`, `Holdings#hold(player, card_season_id, qty, reserved:)`, `Game::AddGoal`), `test/controllers/trades_controller_test.rb` (setup l.13-45: Hugo/Lea/Max, `befriend`, `propose`, fr sign-in, toast asserts), `test/system/trades_test.rb` (sign-in l.35, toast asserts), `test/support/library_requests.rb#assert_request_queries`, `assert_queries_count`. Rarity is set with `RatedCards#rate`. Deleted player: `Accounts::DeletePlayer.new.call(player:)`; private: `update_columns(visibility: "private")`; banned: fixture `:banned`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/trade_suggestions.rb` -- `Game::TradeSuggestions.call(player, now: Time.current)` returning `Result(goals:, suggestions:)` with `goals` = the player's `GoalNeeds` (for the key line) and each `Suggestion(friend:, lines:)` holding the `FriendsPresence` row and `Line(card_season_id:, card_id:, goal_positions:)` in placement order, plus small readers (e.g. served goals with counts, `card_season_ids`, `empty?`). Batched reads: goals, presence rows, friendships, one holdings read for all friends and missing games, one open-trade items read -- AD-38.
- [ ] `test/domains/game/trade_suggestions_test.rb` -- one test per I/O matrix query row, plus the ranking order of games and friends, the cross-friend de-duplication, and a query count equal for 1 and 3 friends.
- [ ] `app/controllers/concerns/trade_proposals.rb` (name free) -- move `befriended`, `befriended?`, `sent_sides`, `quantities`, `refused`, `show_refusal`, `toast`, `INSUFFICIENT` out of `TradesController` unchanged; include it in both controllers.
- [ ] `app/controllers/trades_controller.rb` -- load the suggestions (and the card views of their card-seasons) for every screen action; in `new`, read the `take`/`give` prefill keys into prefill lines, build the editor with `trade_board_editor`, and expose the prefill so the matching row is current.
- [ ] `app/controllers/trade_suggestions_controller.rb` + `app/policies/trade_suggestion_policy.rb` + `config/routes.rb` -- `create`: authorize, throttle like trades, refuse non-friends/private as `TradesController#create`, propose, set the title-only toast and the focus flash (sent row position and trade token), redirect to `trades_path` (303).
- [ ] `app/helpers/trade_suggestions_helper.rb` -- summary, opener name, ENVOYER name, served marks, opener path, ENVOYER params, current-row check.
- [ ] `app/views/trades/_suggestions.html.erb` (+ row partial if useful), `_list.html.erb`, `_screen.html.erb`, `_draft_board.html.erb` -- the section, rows, autofocus target, prefilled draft board.
- [ ] `app/frontend/controllers/trade_board_controller.ts` -- `prefilled` value: no draft read, no save/forget, abandon keeps storage.
- [ ] `app/frontend/controllers/trade_suggestions_controller.ts` (name free) -- hold live refresh while focus is within the section; register it as the other controllers are.
- [ ] `app/frontend/styles/trades-suggestions.css` + `application.css` import -- section and row per DESIGN.md (sunken ground, 2px dashed `line-deep` edge, accent on hover, 12px padding, avatar 75% → 100% on hover/opened, rows 8px apart, closing 2px `line-soft` rule 14px under; key line 11px bold muted with small bookmarks; row bookmarks default size 14px apart; ×n and summary JetBrains Mono bold 12px; opened = `panel-raised` with 5px accent left edge; focus ring around the whole row via `:has(:focus-visible)`; phone: 44px targets, ENVOYER with ≥ 8px of row target around it). No opacity/filter on the row or its text.
- [ ] `app/components/toast_component.html.erb`, `app/views/shell/_toasts.html.erb` -- the title-only toast.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- the keys below.
- [ ] `test/policies/trade_suggestion_policy_test.rb`, `test/controllers/trade_suggestions_controller_test.rb`, `test/controllers/trades_controller_test.rb`, `test/system/trade_suggestions_test.rb`, a vitest for the prefilled board if the logic lands in `app/frontend/lib` -- see AC.

**Acceptance Criteria:**
- Given a player whose goal misses two games, a friend holding a spare of each, a friend with a single copy, one whose spare is reserved and a private friend, when they open Échanges in French and in English, then only the first friend is suggested, with the Brotherhood line, the key line and the row as designed, and the opener's accessible name names both cards with their goals and the presence.
- Given that player goes private, when they open Échanges, then no SUGGESTIONS section shows.
- Given a suggestion, when the player presses ENVOYER, then a trade to that friend requesting those cards opens, the toast "Proposition transmise" shows with no line, the suggestion leaves the list, the focus is on the next row's opener (or the sent trade's row), and a draft stored for that friend is still there.
- Given a draft stored for a friend, when the player opens that friend's suggestion, then the board shows the suggested cards on the friend's side with an empty player side, the row is current, and after a reload of the plain new-trade page (or ABANDONNER on the prefilled board) the stored draft is unchanged.
- Given a crafted prefill with a card the friend lacks or an unknown key, when the board opens, then those cards are ignored; given a private or non-friend token, then the existing refusal applies.
- Given the suggestions page as a GET, then it writes nothing (reading role) and the controller test's query count does not grow from 1 to 3 friends.

## Design Notes

Copy (French from the copy deck; English new). Keys under `trades.suggestions`:
- `heading`: "Suggestions" / "Suggestions" (drawn uppercase as the group headings).
- `line`: "La Confrérie a identifié des opportunités de collaboration entre ses membres." / "The Brotherhood has identified opportunities for collaboration among its members."
- `key`: "Pour vos objectifs :" / "For your goals:"; `goal`: "objectif %{number} : %{set}" / "goal %{number}: %{set}".
- `summary_open`: "%{cards} · à %{name} de choisir en retour" / "%{cards} · for %{name} to choose in return".
- `card`: "%{title} (%{goals})" with goals joined ", "; `label_open`: "Suggestion de %{name} : %{cards}, %{name} choisit en retour. %{presence}." / "Suggestion from %{name}: %{cards}, %{name} chooses in return. %{presence}."
- `send`: "Envoyer" / "Send"; `send_label`: "Envoyer la suggestion à %{name}" / "Send the suggestion to %{name}".
- `sent`: "Proposition transmise" / "Proposal forwarded".
Card titles in the summary and name join with ", " in placement order.

Spare computation sketch per (friend, game): free editions `[(card_season_id, free, rarity, season_number)]` with `free > 0`; keep one from `max_by [rarity, -season_number]`; placed = remaining `max_by [free, -season_number]`; spare when any remains.

The "trade appears at the top of EN ATTENTE DE LEUR RÉPONSE" and "where the board lands" are drawn, not decided (EXPERIENCE.md open questions): keep the list's order and land on `trades_path`.

## Verification

Environment: work only in /home/teyermann/projets/gameble/.claude/worktrees/build-29-2 (never /home/teyermann/projets/gameble itself); before any rails command `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w29_2 CHROME_BIN=/usr/bin/chromium` (Postgres on 5433, schema loaded); other builds run in parallel, so use `PARALLEL_WORKERS=3` for the full suite. Do not commit.

**Commands:**
- `bin/rails test test/domains/game/trade_suggestions_test.rb test/controllers/trades_controller_test.rb test/controllers/trade_suggestions_controller_test.rb test/policies` -- expected: pass
- `bin/rails test test/system/trade_suggestions_test.rb test/system/trades_test.rb` -- expected: pass
- `PARALLEL_WORKERS=3 bin/rails test` -- expected: pass
- `bundle exec packwerk check && bin/rails zeitwerk:check && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused && bin/rubocop` -- expected: pass
- `npm run test:js && npm run format:check && npm run lint:css && npm run typecheck --if-present` -- expected: pass
- `script/check_planning_references && script/check_file_sizes` -- expected: pass
- `bin/rails test test/config/french_typography_test.rb` -- expected: pass

## Implementation Notes

- `Game::TradeSuggestions` (`app/domains/game/app/queries/game/trade_suggestions.rb`) returns `Result(goals:, suggestions:)`; a fixed set of reads (goals, presence rows, one friendship pluck, one raw-SQL read of free editions for all friends and missing games, one read of open-trade items), nothing written; the query count is equal for 1 and 3 friends (domain and controller tests).
- The shared proposal helpers moved unchanged from `TradesController` into `app/controllers/concerns/trade_proposals.rb`; `TradeSuggestionsController#create` (`POST /trades/suggestions`, `suggestions_trades_path`) uses them, with its private refusal method named `refuse_suggestion` because `ApplicationController#refuse` already exists. A refused suggestion keeps the alert toast but drops `flash[:trade_error]`, so no unrelated board on the list shows the error inline.
- `TradesController#new` reads `take[]`/`give[]` into `TradeSuggestionsHelper::Prefill` (at most 4 per side, through `Catalog::PublishedCardSeasonIds`); the controller references that helper constant.
- `_draft_board` draws the prefilled lines, their face templates and hidden line markers; `trade_board_controller.ts` has a `prefilled` value through which it never reads, saves or forgets the stored draft (including ABANDONNER and morphs).
- `trade_suggestions_controller.ts` holds live refresh while focus is in the section, deciding after the focus move settles, so losing window focus keeps the hold.
- `ToastComponent` takes an optional message (nil prints no message line); `shell/_toasts` renders `flash[:title_toast]` as a title-only toast.
- The key line lists all of the player's goals, as the mock does.
- Packwerk's ERB parser misread `render "trades/picker", editor:, friend:` followed by another line (the shorthand swallowed it); the call is wrapped in parentheses.
- No vitest was added: the prefill guard lives in the Stimulus controller, not in `app/frontend/lib`; the system test covers it (stored draft byte-identical after an edit, ABANDONNER and a reload).

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 5 findings — high 0, medium 2, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` A refused ENVOYER left `flash[:trade_error]` set and redirected to the list, so `_board_middle` printed the refusal as `role="alert"` inside whatever trade the index board showed — `refuse_suggestion` now deletes `flash[:trade_error]` after `refused`; the controller test opens a board on the list and asserts the alert toast and no `.trade-board__error`.
  - `[medium]` `[patch]` `trade_suggestions_controller.ts` released the live-refresh hold on a `focusout` with a null `relatedTarget` (window or tab blur) while focus stayed in the section, so a pending refresh could morph away the focused row — the hold is now recomputed after the focus move settles from `this.element.contains(document.activeElement)`.
  - `[low]` `[patch]` The ENVOYER form (ButtonComponent with `method: :post`) sat inside a `span`, invalid nesting — the wrapper is now a `div` with the same class.
  - `[low]` `[patch]` The "Steam library set never feeds suggestions" query test had no goal, so it passed vacuously — the player now has a real game-set goal while the friend spares only library-set games.
  - `[low]` `[patch]` A one-shot `focused?` read in `test/system/trade_suggestions_test.rb` broke the retrying-matcher rule — now `eventually(...)`.

### 2026-11-01 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 3, false 2, maybe-false 0
- findings:
  - `[low]` `[reject]` After ENVOYER the focus lands on the next suggestion's opener, so the screen-wide live refresh stays held until the player moves the focus — the intent contract asks for both the hold while focus is in the section and that landing focus. The hold lifts on the first focus move, and the deferred refresh then runs (`live_refresh_controller` observes the attribute). Narrowing it would contradict the intent, and morph refresh is page-wide by design (the trade board holds the same way).
  - `[low]` `[reject]` ENVOYER's `throttle_player` budget is separate from the board's send, because Rails 8.1 keys `rate_limit` by `scope` (the controller path), so a player could alternate them for up to 40 proposals a minute — the invitation controllers already split their budgets the same way. No player meets this in everyday use, and merging the budgets would add a `scope:` parameter to `throttle_player`.
  - `[false]` `[reject]` `FREE_EDITIONS` accepts unrated or unpublished editions that the prefill resolver drops — holdings are written only by `Game::OpenPack` from `Catalog::PublishedSeason`, rarity is set when a season is published, and nothing unpublishes a season, so no held edition is unrated or in a draft season.
  - `[false]` `[reject]` The row's focus ring shows only when the opener is focused, not when ENVOYER is — DESIGN.md's whole-row ring is the row's own keyboard focus (the opener is the row's target). ENVOYER is a separate target with its own ring, and ringing the row too would show two rings for one focus.
  - `[low]` `[patch]` No browser test checked that the focus lands on the next suggestion's opener after ENVOYER, or that the hold then holds — added a system test in `test/system/trade_suggestions_test.rb`. It covers two suggestions, a send of the first, real focus on the remaining opener, the hold set, the hold kept after a `focusout` with no `relatedTarget` while the focus stays (a window or tab blur), and the hold released once the focus leaves. Mutating `focusLeft` to release on every `focusout` makes it fail.

## Auto Run Result

- **Summary:** the Échanges trade list shows a SUGGESTIONS section, at most 3 one-sided rows, one per friend, computed on read by `Game::TradeSuggestions` from the player's goals and AD-38's spare rule (free copies beyond the kept one, minus games already on the friend's side of an open trade between the pair). The section is hidden when there is no suggestion and absent for a private player, and it never names a private, banned or deleted friend. ENVOYER proposes the row's cards through `Game::ProposeTrade`, shows the title-only "Proposition transmise" toast, keeps the friend's stored draft and moves the focus as designed. The row's opener is a GET link (`friend` token plus `take[]` `slug--sN` keys) that renders the prefilled draft board without reading or writing the stored draft.
- **Files changed:**
  - `app/domains/game/app/queries/game/trade_suggestions.rb`: the query.
  - `app/controllers/concerns/trade_proposals.rb`: the shared proposal helpers, moved out of `TradesController`.
  - `app/controllers/trades_controller.rb`: suggestions on every list screen; prefill parsing in `new`.
  - `app/controllers/trade_suggestions_controller.rb`, `app/policies/trade_suggestion_policy.rb`, `config/routes.rb`: ENVOYER.
  - `app/helpers/trade_suggestions_helper.rb`, `app/helpers/trades_helper.rb`: row copy, paths, params, the current row, focus, prefill editor.
  - `app/views/trades/_suggestions.html.erb`, `_suggestion.html.erb`, `_list`, `_screen`, `_draft_board`, `index`/`show`/`new`/`choose`/`edit`: the section, rows and prefilled board.
  - `app/frontend/controllers/trade_board_controller.ts`: the `prefilled` value.
  - `app/frontend/controllers/trade_suggestions_controller.ts`: holds live refresh while focus is in the section.
  - `app/frontend/styles/trades-suggestions.css`, `app/frontend/entrypoints/application.css`: the row look.
  - `app/components/toast_component.*`, `app/views/shell/_toasts.html.erb`: the title-only toast.
  - `config/locales/en.yml`, `config/locales/fr.yml`: `trades.suggestions.*`.
  - Tests: `test/domains/game/trade_suggestions_test.rb`, `test/controllers/trade_suggestions_controller_test.rb`, `test/controllers/trades_controller_test.rb`, `test/policies/trade_suggestion_policy_test.rb`, `test/components/toast_component_test.rb`, `test/system/trade_suggestions_test.rb`.
- **Review findings:** 5 patched (2 medium, 3 low), 0 deferred, 0 rejected.
- **Follow-up review recommendation:** true, because two medium findings were patched. The specific unverified risk is the live-refresh hold after the focus leaves the window or moves within the section, which now settles in a timeout. No automated test covers that path, or a refresh morph that removes the focused row.
- **Verification:**
  - Full `PARALLEL_WORKERS=3 bin/rails test`: 3992 runs, 0 failures, both before and after the patches.
  - `test/system/trade_suggestions_test.rb` and `test/system/trades_test.rb`: 18 runs, 0 failures.
  - The domain, controller, policy, French typography and toast tests: 307 runs, 0 failures.
  - packwerk, zeitwerk, i18n-tasks missing and unused, rubocop, vitest (795), prettier, stylelint, tsc, `script/check_planning_references` and `script/check_file_sizes` all pass.
- **Residual risks:**
  - The English suggestion copy and the "Proposal forwarded" toast are new, since the UX deck has French only.
  - After ENVOYER the page lands on the trade list and keeps the existing group order. The sent trade therefore sits by expiry in "En attente de leur réponse", not at its top as the mock draws it. EXPERIENCE.md leaves both points undecided.
  - A friend with more than 4 spare games gets a fresh suggestion right after a send, with the remaining games.
  - Edits on a prefilled board are not stored, and the address is not replaced. Entry 4 owns that.
  - The key line lists all of the player's goals.
  - Server time of the read at scale is not yet measured; entry 3 does that.

### Follow-up review pass (2026-11-01)

- **Summary:** a follow-up quick review of commit b66e4d27 against its parent. No production code changed. One test was added: the browser path after ENVOYER with two suggestions, and the live-refresh hold through a window blur.
- **Files changed:** `test/system/trade_suggestions_test.rb`: the focus lands on the next suggestion's opener, and the hold survives a window blur and lifts when the focus leaves.
- **Review findings:** 1 patched (low), 0 deferred, 4 rejected. Two low findings were rejected: the screen-wide hold after a send is what the intent prescribes, and the split rate-limit budget matches the invitation controllers and would need a new parameter. Two findings were false: no held edition is unrated or unpublished, and the row ring is meant for the opener's focus.
- **Follow-up review recommendation:** false. This was a follow-up pass with no high patched (patched by verdict: high 0, medium 0, low 1).
- **Verification:** the follow-up's unverified point now has a test. A `focusout` with a null `relatedTarget` while `document.activeElement` stays in the section is what a window or tab blur sends, and it keeps the hold; a real blur to the body releases it. The test fails when `focusLeft` drops the hold unconditionally.
  - `test/system/trade_suggestions_test.rb` + `test/system/trades_test.rb`: 19 runs, 0 failures.
  - The domain, controller and policy tests, plus French typography: 301 runs, 0 failures.
  - Full `PARALLEL_WORKERS=3 bin/rails test`: 4061 runs, 0 failures.
  - packwerk, zeitwerk, i18n-tasks missing and unused, rubocop, vitest (795), prettier, stylelint, tsc, `script/check_planning_references` and `script/check_file_sizes` all pass.
- **Residual risks:** the blur is simulated with a synthetic `focusout`, because headless Chrome does not blur the window reliably. A real window switch in Firefox or Safari was not exercised. After a send, live refresh stays held until the player moves the focus, as the intent prescribes. ENVOYER and the board's send have separate 20-per-minute budgets. The earlier pass's residual risks still stand.
