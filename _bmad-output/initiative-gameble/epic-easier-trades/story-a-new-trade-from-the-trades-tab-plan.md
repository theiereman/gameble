---
title: 'A new trade from the Trades tab'
type: 'feature'
ticket: '1'
created: '2026-10-15'
status: 'built'
baseline_revision: '3c25b58a9514612eddf1b7b9163f3f93929f9be7'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** A player can only start a trade from a friend row or a friend profile; the Trades tab, empty or not, offers no way to start one (issue 63, point 1).

**Approach:** A "NOUVEL ÉCHANGE" action at the top of the Trades list opens a friend chooser, served by `trades#new` when no `friend` param is given, in the board pane of the Trades screen. Each friend row shows the friend's name and presence and leads to today's draft board (`new_trade_path(friend:)`), whose existing refusals still apply; a player with no friend is pointed to the invitation panel.

## Boundaries & Constraints

**Always:** Reads only through `Game` queries (`Game::FriendsPresence`, `Game::OpenTradesByFriend`) and `TradesHelper#trades_refusal`; the chooser GET writes nothing. Reuse the `trade` Pundit policy's `new?`. Every new string in both `config/locales/en.yml` and `fr.yml`, new keys only under `trades.list.new` and `trades.chooser.*` (another lane adds keys elsewhere under `trades`). Tokens only in URLs and DOM, never ids. No `style` attribute. English repo text, no planning ids or comments in code.

**Never:** No change to the friend row's or friend profile's trade button, to `trades#new` with a `friend` param, to trade operations, or to the trade board island. No new route or controller action. No dialog. No change to the trade list's empty copy.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Chooser with friends | GET `/fr/trades/new`, player with friends | Trades screen, list on the left, chooser panel with one row per friend: name, presence, "ÉCHANGER" (accessible name "Échange avec <name>") linking to `new_trade_path(friend: token)` | — |
| Private friend | a friend with visibility private | the row shows the "Profil privé" presence and `trades_closed_line` instead of the button | — |
| Player private | current player private | every row shows the own-private closed line with its RÉGLAGES link | — |
| Open trade with a friend | a trade open between the pair | the row's button links to `new_trade_path(friend:)`, which redirects to that trade with the one-at-a-time refusal (today's behavior) | — |
| No friend | player without friends | chooser shows "Aucun ami pour l'instant." with a link "Invitez-en un avec votre lien ou votre code." to `friends_path(anchor: "friends-invite")`; no row | — |
| Unknown or non-friend token | `friend` param present but unresolvable | 404, as today | unchanged |
| Visitor | not signed in | sent home to sign in, as for every trade page | unchanged |

</intent-contract>

## Code Map

- `app/controllers/trades_controller.rb` -- `new` raises 404 when `befriended(params[:friend])` is nil; branch first on `params[:friend].blank?` to load `@trades = Game::TradesOf.call(current_player)`, `@cards = card_views(@trades, nil)`, `@friends = Game::FriendsPresence.call(current_player)` and render `:choose`. Keep the rest of `new` as is.
- `app/views/trades/new.html.erb` -- the draft template; model a new `app/views/trades/choose.html.erb` on it (`content_for :title, t("trades.chooser.title")`, render `trades/screen` with `view: :board, trades:, trade: nil, cards:, chooser: @friends`).
- `app/views/trades/_screen.html.erb` -- renders the draft or board pane; add a `local_assigns[:chooser]` branch rendering `trades/chooser`. `view: :board` already hides the list on phones (`trades.css` ~line 794) and adds the "◀ LISTE" phone back.
- `app/views/trades/_list.html.erb` -- add the "NOUVEL ÉCHANGE" button (`ButtonComponent.new(href: new_trade_path, size: :small)`) at the top of the nav, before the empty panel, so it shows with and without trades.
- `app/views/friends/show.html.erb` lines ~71-95 -- the friend row to mirror (name, `render "friends/presence", presence: friend`, `trades_refusal` / `trades_closed_line`, `ButtonComponent` with `aria_label`). Do not edit it.
- `app/views/friends/_presence.html.erb`, `PresenceHelper#presence_text` -- reuse as is; `friends.css` styles are global.
- `app/helpers/trades_helper.rb` -- `trades_refusal(friend)`, `trades_closed_line(refusal, friend)`.
- `app/helpers/friends_helper.rb` -- `friend_name(player)`.
- `packs/game/app/queries/game/friends_presence.rb` -- `Game::FriendsPresence.call(player)` returns `Row(player, state, ...)`, empty array without friends; read-only.
- `app/frontend/styles/trades.css` -- add `.trade-chooser*` rules (list without bullets, rows flex-wrap with space-between, like `.friends__friend`/`.friends__actions` in `friends.css`) and the list action's spacing. Tokens only.
- `config/locales/fr.yml`, `config/locales/en.yml` -- `trades.list.new`, `trades.chooser.{title,line,label,trade,trade_with,empty,empty_invite}`.
- `test/controllers/trades_controller_test.rb` -- setup befriends Hugo (`@alice`) with Lea (`@bob`) and Max (`@carol`); test at line ~566 asserts `get new_trade_path(locale: :fr)` is 404, which this story changes; test at ~733 covers the empty list.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- Échanges table (~line 240) and Copy deck (~line 103); add the chooser.

## Tasks & Acceptance

**Execution:**
- [x] `app/controllers/trades_controller.rb` -- in `new`, after `authorize`, render the chooser when `params[:friend]` is blank (extract a private `choose_friend` method) -- the chooser is the draft step before a friend is known.
- [x] `app/views/trades/choose.html.erb`, `app/views/trades/_chooser.html.erb`, `app/views/trades/_screen.html.erb` -- the chooser pane: a `PanelComponent` section with brackets labelled by an `h2` (`trades.chooser.title`, tabindex -1), the line `trades.chooser.line`, then either the no-friend panel or a `ul` of friend rows as in the matrix -- one screen, same shell as the board.
- [x] `app/views/trades/_list.html.erb` -- the "NOUVEL ÉCHANGE" button at the top of the list -- the entry point with and without trades.
- [x] `app/frontend/styles/trades.css` -- chooser and list-action styles at desktop and phone widths -- no inline style.
- [x] `config/locales/fr.yml`, `config/locales/en.yml` -- fr: list.new "Nouvel échange"; chooser.title "Nouvel échange", line "Choisissez l'ami avec qui échanger.", label "Vos amis", trade "Échanger", trade_with "Échange avec %{name}", empty "Aucun ami pour l'instant.", empty_invite "Invitez-en un avec votre lien ou votre code."; en: "New trade", "New trade", "Choose the friend to trade with.", "Your friends", "Trade", "Trade with %{name}", "No friends yet.", "Invite one with your link or your code." -- both locales.
- [x] `test/controllers/trades_controller_test.rb` -- replace the `get new_trade_path(locale: :fr)` 404 assertion with a chooser test; add tests for every matrix row (rows and links, private friend line, own-private line, open trade redirect with the one-at-a-time toast, no friend invite link, the list's NOUVEL ÉCHANGE link with and without trades, English copy) -- the story's verification.
- [x] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- add a "Friend chooser" row to the Échanges table and the chooser's copy to the Copy deck; add "NOUVEL ÉCHANGE" on the Trades list to the Échanges entry points row -- the chooser's copy is the story's to write.

**Acceptance Criteria:**
- Given a player with trades, when they open the Trades tab, then "NOUVEL ÉCHANGE" shows above the groups; given none, it shows with the empty line.
- Given the chooser, when the player presses "ÉCHANGER" on Lea's row, then the draft board with Lea opens as today.
- Given the friend row on Amis, when the player presses "ÉCHANGE", then it still opens the trade in progress or a new draft (unchanged).
- Given the chooser GET, then nothing is written (the read-only request guard passes) and `TradePolicy#new?` authorizes it.

## Implementation Notes

- The list's "NOUVEL ÉCHANGE" and the chooser's "ÉCHANGER" are secondary buttons, not the Code Map's default primary: the Trades screen already carries the board's primary action (ENVOYER, ACCEPTER, NOUVEL ÉCHANGE AVEC …), and EXPERIENCE.md allows one primary per view.
- The no-friend line is a plain muted paragraph inside the chooser panel rather than a nested panel.
- `Game::OpenTradesByFriend` is not read: per the Design Notes, every chooser button links to `new_trade_path(friend:)` and relies on `new`'s redirect.
- On phones the list action spans the column and each chooser row's presence and action wrap under the name.
- Review patch: the chooser heading carries no `tabindex` (the plan's task asked for -1): nothing focuses it, unlike the board heading the `trade-board` controller focuses.

## Plan Change Log

## Review Triage Log

### 2026-10-15 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `new` shows the chooser for a present but empty `friend` param (`?friend=`), which returned 404 before and the matrix keeps at 404 — guard changed to `params.key?(:friend)`; the draft test now asserts `friend: ""` is 404.
  - `[low]` `[patch]` the chooser heading's `tabindex="-1"` and its `:focus` outline rule are dead, nothing focuses the heading — both deleted, test assertion updated.

## Auto Run Result

- **Summary:** "NOUVEL ÉCHANGE" at the top of the Trades list, with or without trades, opens a friend chooser served by `trades#new` without a `friend` param, in the board pane (phone: alone with "◀ LISTE"). Each row shows the friend's name and presence and "ÉCHANGER" to today's draft board, or the trades-closed line when either profile is private; a friend with an open trade lands on it under the one-at-a-time refusal; no friend points to the invite panel.
- **Files:** `app/controllers/trades_controller.rb` (chooser branch in `new`), `app/views/trades/choose.html.erb` and `_chooser.html.erb` (new), `_screen.html.erb` (chooser pane), `_list.html.erb` (the action), `app/frontend/styles/trades.css` (chooser and action styles), `config/locales/{en,fr}.yml` (`trades.list.new`, `trades.chooser.*`), `test/controllers/trades_controller_test.rb` (7 new tests, empty-param 404), `ux-gameble/EXPERIENCE.md` (entry point, Friend chooser behavior and copy).
- **Review:** quick lens; 2 low findings patched, none deferred or rejected. Follow-up review not recommended (0 high, 0 medium patched).
- **Verification:** `bin/rails test` 2584 runs, 0 failures; `npm run test:js` 326 passed; `i18n-tasks missing`, `bin/rubocop`, `packwerk check`, `zeitwerk:check` clean.
- **Residual risks:** layout not seen in a browser at desktop or phone width; buttons are secondary rather than primary (one primary per view), for the author to confirm on staging; the chooser heading is not focused on open, and EXPERIENCE.md's focus table has no row for it.

## Design Notes

The ticket left open whether the chooser is `trades#new` without a friend, its own action, or a dialog. `trades#new` without `friend` is chosen: it is the same "new trade" resource before a friend is picked, needs no route or policy, and lands in the Trades screen's board pane so the phone gets "◀ LISTE" for free. A friend with an open trade keeps the chooser button and relies on `new`'s existing redirect, so the player sees today's one-at-a-time refusal on that trade rather than a second copy of it in the chooser.

## Verification

**Commands:**
- `bin/rails test test/controllers/trades_controller_test.rb test/controllers/friends_controller_test.rb` -- expected: all pass
- `bin/rails test` -- expected: all pass (system tests are skipped)
- `bundle exec i18n-tasks missing` -- expected: no missing key
- `bin/rubocop` -- expected: no offense
- `bundle exec packwerk check` and `bin/rails zeitwerk:check` -- expected: no violation
- `npm run test:js` -- expected: all pass
