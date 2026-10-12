---
title: 'Trade from the friend row'
type: 'feature'
ticket: '21'
created: '2026-10-12'
status: in-progress
baseline_revision: '224cc3934833c61bacd0d4b7a95d6a1a2d065e08'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md', '{project-root}/_bmad-output/initiative-gameble/change-profile-privacy/change-profile-privacy.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The friend row already carries PROPOSER UN ÉCHANGE and the trades-closed line (commit c6f022e, `plan-friend-row-actions.md`, built outside the ticket tree), but the button always links to the new-draft URL. With a trade already open with that friend, the click lands on that trade through `TradesController#new`'s "Un échange à la fois" refusal toast, so the row does not simply open the trade in progress as the UX says ("opens the trade already in progress with that friend, or a new draft").

**Approach:** The Friends screen reads the player's open, unexpired trades once, keyed by friend; a row whose friend has one links PROPOSER UN ÉCHANGE straight to that trade, any other row keeps the new-draft link, and the trades-closed line keeps its place when either profile is private. `TradesController#new`'s redirect stays as the fallback for a stale page.

**Decision (author, 2026-10-12):** the friend row opens the trade in progress directly, with no one-at-a-time refusal; `EXPERIENCE.md` "One trade per pair" is amended to say so. The friend profile dialog's PROPOSER UN ÉCHANGE (`app/views/friend_profiles/show.html.erb`, `FriendProfilesController#show`) is aligned the same way: it links straight to the trade in progress with that friend, or to a new draft. The saved patch, applied, holds the row's part.

</intent-contract>

## Code Map

- `app/views/friends/show.html.erb` -- friend row: the `new_trade_path(friend:)` button gets `trade_path(token:)` when the friend has an open trade.
- `app/controllers/friends_controller.rb` -- `show` reads the open trades by friend.
- `packs/game/app/queries/game/` -- new query: the player's in-progress, unexpired trades as `{ friend id => trade token }` (same filter as `TradesWaiting`: `Trade.in_progress`, `expires_at > now`, either side).
- Tests: `test/controllers/friends_controller_test.rb:52-85`, a query test in `test/packs/game/`, `test/system/friends_test.rb:58`.

## Implementation Notes

Oneshot: one query, one controller line, one view branch and their tests, well under 100 lines. The trades-closed line and the draft link were built by `plan-friend-row-actions.md`; this story adds the open-trade link and the tests the ticket's verify needs.

- `Game::OpenTradesByFriend.call(player, now:)` returns `{ friend id => trade token }` for in-progress trades not yet past `expires_at`, either side; ids stay server-side, the HTML carries only the token.
- `FriendsController#show` reads it once; the row picks `trade_path(token:)` or `new_trade_path(friend:)`. The trades-closed branch is unchanged, so a private party still gets the line, never a link.
- The friend profile dialog's PROPOSER UN ÉCHANGE still goes through `TradesController#new` (redirect with the "one at a time" toast when a trade is open): the ticket names the row only.
- Tests: `test/packs/game/open_trades_by_friend_test.rb` (both sides, closed, expired, signed out), `friends_controller_test.rb` (row links to the open trade, then to a new draft once cancelled), `test/system/friends_test.rb` (click lands on the trade with no "one at a time" toast).
- Surprise: the full suite has two failures outside this diff, `trades_of_test.rb:62` and `sessions_controller_test.rb:316`. Both fail alone too and come from today's date: their 14- and 30-day windows cross the 2026-10-25 daylight-saving change, an hour off. Not touched here.

## Plan Change Log

## Review Triage Log

### 2026-10-12 — Review pass
- verdicts: 1 findings — high 0, medium 1, low 0, false 0, maybe-false 0
- findings:
  - `[medium]` `[intent_gap]` The row's direct link to the open trade drops the one-at-a-time refusal that `ux-gameble/EXPERIENCE.md:282` ("One trade per pair | Friend row, friend profile | ... opens that trade, with the one-at-a-time refusal") requires, the new system test asserts its absence, and the row now diverges from the friend profile dialog's identical button — verified: line 282 names the friend row; the baseline row already linked to `new_trade_path`, whose `TradesController#new:31-34` redirect is exactly that pattern. The root cause is this plan's Approach inside the intent contract; the attempted change is saved in [story-trade-from-the-friend-row-plan.patch](story-trade-from-the-friend-row-plan.patch) and the code reverted.

## Verification

**Commands:**
- `bin/rails test test/controllers/friends_controller_test.rb test/packs/game` -- expected: 0 failures
- `bin/rails test test/system/friends_test.rb` -- expected: 0 failures
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: green

## Auto Run Result

- **Status:** blocked (intent gap), at the quick review.
- **Finding:** develop already holds this ticket's behaviour. Commit c6f022e (`plan-friend-row-actions.md`) added PROPOSER UN ÉCHANGE to the friend row, linking to `new_trade_path(friend:)`, which opens the trade in progress through `TradesController#new` with the one-at-a-time refusal, or a new draft, and the trades-closed line when either profile is private. That matches `EXPERIENCE.md:211` and `:282`. The existing tests already cover it: `friends_controller_test.rb` (draft link, trades-closed line both ways) and `test/system/friends_test.rb`.
- **Attempted change (reverted):** `Game::OpenTradesByFriend`, plus a row link straight to `trade_path(token:)` when a trade is open, with query, controller and system tests. It is saved in `story-trade-from-the-friend-row-plan.patch`. It passed its tests, rubocop, packwerk, i18n-tasks, tsc, brakeman, bundler-audit, zeitwerk and vitest. The review found it contradicts `EXPERIENCE.md:282`.
- **Author's decision:** either close 7.21 as built by c6f022e, or amend `EXPERIENCE.md:282` to drop the refusal from the row and apply the patch. If you apply it, align the friend profile dialog's button too, so the two stay consistent.
- **Follow-up review recommended:** false (nothing patched).
- **Deferred:** none.
- **Residual risks:** two full-suite failures not caused by this ticket, which fail alone on 2026-10-12 too. `test/packs/game/trades_of_test.rb:62` and `test/controllers/sessions_controller_test.rb:316` use 14- and 30-day windows that cross the 2026-10-25 daylight-saving change, so both are an hour off. Every build run before the end of October will hit them.
