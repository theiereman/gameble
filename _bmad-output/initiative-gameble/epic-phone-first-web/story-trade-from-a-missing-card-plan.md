---
title: 'Trade from a missing card'
type: 'feature'
ticket: '9'
created: '2026-11-03'
status: 'built'
baseline_revision: '6bd3e054028f0cde891e0529b87cf8326265a7ec'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** A player who sees a card they miss (a goal tile's thumbnail leads to its detail) has no way to ask a friend for it from there: the trade board needs a friend, then the card picked by hand.

**Approach:** On the detail of a card the player holds no copy of, a Trade button opens a bottom sheet listing every friend who has a free copy of it (a single copy included, any missing card, goal or not). Choosing one posts a trade through `Game::ProposeTrade` with the player's side empty and the card requested, then lands on the sent trade where the player waits; the friend sees the existing open request ("lets you choose").

## Boundaries & Constraints

**Always:** server-rendered ERB and `BottomSheetComponent`; the write goes through `Game::ProposeTrade` only; a GET writes nothing; a Pundit policy on the new action; strings in `en.yml` and `fr.yml` (French plural with `zero`); no database id in HTML or params (friend token, card slug, season number); no `style` attribute; tap targets at least 44px; a private friend, a private player, a non-friend, or a friend who already has the same open request from the player is refused exactly as the trade board refuses; friends are ranked: no open request first, more free copies first, then token.

**Decisions (conservative, recorded in `pending-approvals.md`):** the listed edition is the shown edition when the friend has a free copy of it, else the friend's edition with most free copies (earliest season on a tie); a friend who already has an open request from the player for this card shows in the sheet as plain text, not a button; the button is hidden when no friend qualifies or when the player's own profile is private; the sent trade lands on the trade board with the "sent" toast.

**Never:** the trade board's card picker, `Game::ProposeTrade`, the suggestions query and rows, the goal tiles, the Social tab, a new table or migration.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Missing card | signed-in player with no copy, two friends hold it (one with a single copy) | Trade button; sheet lists both, more copies first | none |
| Owned card | player holds a copy | no Trade button | none |
| Nobody holds it / visitor | no friend with a free copy, or signed out | no button, no sheet | none |
| Private friend | friend with a free copy but a private profile | not listed | forged POST refused with the friend-private message |
| Reserved copy | friend's only copy sits in a trade | not listed | none |
| Choose | POST with a listed friend's token | open trade created, own side empty, friend's side the card, redirect 303 to the trade, "sent" toast | none |
| Open request exists | player already asked this friend for the card | friend shown as "Already asked", no button | forged POST: "already sent" refusal back to the card |
| Forged | non-friend token, friend without the card, private player | nothing written, back to the card with the refusal alert | refusal message |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/friends_holding.rb` (new) -- `FriendsHolding.call(player, card_id:, card_season_id:)`: `FriendsPresence`, `TradeSuggestions::FreeEditions`, `TradeSuggestions::OpenTrades.requested_by`.
- `app/controllers/card_trades_controller.rb`, `app/policies/card_trade_policy.rb` (new), `config/routes.rb` -- `POST cards/:slug/seasons/:number/trade`.
- `app/controllers/concerns/trade_proposals.rb`, `trades_controller.rb` -- `toast_sent` moves to the concern.
- `app/controllers/cards_controller.rb` -- loads the holders for a signed-in player with no copy.
- `app/views/cards/_detail.html.erb`, new `_trade_sheet.html.erb`, `app/frontend/styles/card-trade.css` (imported after `card-detail-public.css`), locales `card_details.trade.*`.
- Tests: `test/domains/game/friends_holding_test.rb`, `test/controllers/card_trades_controller_test.rb`, `test/policies/card_trade_policy_test.rb`, `test/system/card_trade_test.rb`; `cards_controller_test.rb` query budget if it moves.

## Tasks & Acceptance

**Execution:**
- [ ] Query, controller, policy, route, concern move -- the write path.
- [ ] Card detail button, sheet, CSS, locales -- the surface.
- [ ] Tests for every matrix row; one phone system test.
- [ ] `pending-approvals.md` entry for the decisions.

**Acceptance Criteria:**
- Given a missing card and a friend holding it, when the player opens the card on a phone, taps Trade and picks the friend, then a trade is sent with their side empty and the friend's side filled, and the friend reads the open request.
- Given a private friend or one already asked, when the sheet opens, then they cannot be chosen, and a forged request is refused as the board refuses it.

## Implementation Notes

- `Game::FriendsHolding` lists friends from `FriendsPresence`, free editions from the suggestions' `FreeEditions`, and marks as asked a friend with an open, unexpired trade from the player requesting this card with an empty offer; ranking is asked last, more free copies first, then token.
- `CardTradesController#create` re-reads the holders, so a forged friend, a reserved copy or an already asked friend is refused; refusals go back to the card with the alert only (`trade_error` dropped, as the suggestion send did). `toast_sent` moved into `TradeProposals`.
- The card detail costs one more query for a missing card (`FriendsPresence`' friends read); the opened-pack budgets in `cards_controller_test.rb` moved 16 to 17 and 18 to 19.

## Plan Change Log

## Review Triage Log

### 2026-11-03 - Review pass
- verdicts: 6 findings - high 0, medium 1, low 5, false 0, maybe-false 0
- findings:
  - `medium` `patch` "Already asked" used the suggestions' open-trade read, which also matched a trade the friend proposed offering the card and trades with an offer - now a read of the player's own open trades requesting the card with an empty offer; a domain test covers both shapes.
  - `low` `patch` edition choice untested - a domain test covers the shown edition and the most-copies fallback.
  - `low` `patch` forged request for a friend whose only copy is reserved untested - controller test added.
  - `low` `patch` route and test header comments restated the code - removed.
  - `low` `reject` `card-detail__trade` has no rule of its own - the generic `.button` and the stepping layout size it; a rule would duplicate them.
  - `low` `reject` no `:focus-visible` rule on the friend button - the global focus ring applies.

## Verification

**Commands:**
- `bin/rails test test/domains/game/friends_holding_test.rb test/controllers/card_trades_controller_test.rb test/policies test/controllers/cards_controller_test.rb test/controllers/trades_controller_test.rb` -- expected: pass
- `bin/rails test test/system/card_trade_test.rb` -- expected: pass
- `bin/ci && npm run test:js && bin/rails zeitwerk:check && bundle exec packwerk check` -- expected: pass
- `npm run format:check && npm run lint:css && script/check_planning_references && script/check_file_sizes` -- expected: pass

## Auto Run Result

- **Summary:** the detail of a card the player holds no copy of shows a Trade button when a friend has a free copy (a single copy included); it opens a bottom sheet of those friends (not yet asked first, then more copies); choosing one posts through `Game::ProposeTrade` with the player's side empty and the friend's edition requested, then lands on the sent trade with the usual toast, where the friend reads the existing open request. Private friend, private player, non-friend, reserved copy and an already asked friend are refused.
- **Files:** `friends_holding.rb`, `card_trades_controller.rb`, `card_trade_policy.rb`, `trade_proposals.rb` (`toast_sent` moved), `trades_controller.rb`, `cards_controller.rb`, `cards/_detail`, `_trade_sheet`, `show`, `card-trade.css`, routes, locales, `pending-approvals.md`; tests: domain, controller, policy, one phone system test, two budgets in `cards_controller_test.rb`.
- **Review:** 6 findings: 4 patched (medium 1, low 3), 2 rejected with reasons in the log, 0 deferred.
- **Follow-up review recommended:** false - one medium patched, no high.
- **Verification:** `bin/ci` passed (3979 runs, 0 failures); system `card_trade_test.rb` passed; vitest, prettier, stylelint, zeitwerk, packwerk, i18n-tasks missing, planning references and file sizes pass.
- **Residual risks:** the conservative readings in `pending-approvals.md`; the 44px height of the Trade button rests on the shared button styles.

## Code Review

### 2026-11-04 — 0 decision-needed, 1 patch, 3 defer, 3 rejected

- [x] [Review][Patch] Pin that an expired request, a closed one or one for another card does not mark the friend as asked [test/domains/game/friends_holding_test.rb]
- [x] [Review][Defer] The Trade button shows when every holder is already asked, and holders are computed on every missing-card view — deferred: low, fold into the next touch of the card detail
- [x] [Review][Defer] A forged POST for an owned card, two concurrent POSTs and an unpublished edition are accepted by the controller — deferred: ProposeTrade is the real guard, verify there
- [x] [Review][Defer] A private player's card page has no test that the button is absent — deferred: low

**Rejected**
- Nil player with a browse context raises: false, open_to_friends? returns false and the query returns an empty list.
- Missing error keys: false, the refusal keys exist in en.yml.
- Avatar, 44 px target, naming and plan hygiene: low or edits the plan.
