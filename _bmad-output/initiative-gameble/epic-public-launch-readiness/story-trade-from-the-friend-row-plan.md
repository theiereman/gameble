---
title: 'Trade from the friend row'
type: 'feature'
ticket: '21'
created: '2026-10-12'
status: done
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

**Decision (author, 2026-10-12):** the button on the friend row and on the friend profile dialog is renamed from "PROPOSER UN ÉCHANGE" / "Propose a trade" to "ÉCHANGE" / "TRADE", since one label covers both the trade in progress and a new trade; the row's accessible name becomes "Échange avec %{name}" / "Trade with %{name}". `EXPERIENCE.md` and `DESIGN.md` follow; other screens' labels (the trades screen's "NOUVEL ÉCHANGE") stay.

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
- The friend profile dialog's button, after the author's decision, links straight to the trade in progress too: `FriendProfilesController#show` reads `Game::OpenTradesByFriend.call(current_player)[@owner.id]` (a player's open trades are bounded by their friends, so one small query) and the view picks `trade_path(token:)` or `new_trade_path(friend:)`. The trades-closed line for a private viewer is unchanged; a private friend still gets the not-available frame.
- The label rename: keys `friends.show.trade` / `trade_with` and `friend_profiles.show.trade` replace `propose_trade` / `propose_trade_to` in both locales ("Échange" / "Trade", "Échange avec %{name}" / "Trade with %{name}"; the button's uppercase comes from its style, as before). `EXPERIENCE.md` (Échanges entry points, Friend row, Friend profile, One trade per pair, the trade journey) and `DESIGN.md` (Friend row, Friend profile) quote "ÉCHANGE". Historical plans, retrospectives and `.working`/mockup HTML keep the old wording.
- Tests added for the dialog: `friend_profiles_controller_test.rb` (the dialog links to the open trade whoever proposed it, then to a new draft once cancelled) and `test/system/friends_test.rb` (TRADE in the dialog lands on the trade with no "one at a time" toast). Tests asserting the old label now assert "Échange" / "Trade" / "Échange avec Sam"; `trades_test.rb` clicks "Trade" from the row.
- Tests: `test/packs/game/open_trades_by_friend_test.rb` (both sides, closed, expired, signed out), `friends_controller_test.rb` (row links to the open trade, then to a new draft once cancelled), `test/system/friends_test.rb` (click lands on the trade with no "one at a time" toast).
- Surprise: the full suite has two failures outside this diff, `trades_of_test.rb:62` and `sessions_controller_test.rb:316`. Both fail alone too and come from today's date: their 14- and 30-day windows cross the 2026-10-25 daylight-saving change, an hour off. Not touched here.

## Plan Change Log

## Review Triage Log

### 2026-10-12 — Review pass
- verdicts: 1 findings — high 0, medium 1, low 0, false 0, maybe-false 0
- findings:
  - `[medium]` `[intent_gap]` The row's direct link to the open trade drops the one-at-a-time refusal that `ux-gameble/EXPERIENCE.md:282` ("One trade per pair | Friend row, friend profile | ... opens that trade, with the one-at-a-time refusal") requires, the new system test asserts its absence, and the row now diverges from the friend profile dialog's identical button — verified: line 282 names the friend row; the baseline row already linked to `new_trade_path`, whose `TradesController#new:31-34` redirect is exactly that pattern. The root cause is this plan's Approach inside the intent contract; the attempted change is saved in [story-trade-from-the-friend-row-plan.patch](story-trade-from-the-friend-row-plan.patch) and the code reverted.

### 2026-10-12 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` A Friends page rendered while a trade was open keeps linking ÉCHANGE (row and the lazily loaded profile dialog) to that trade after it closes, and a Turbo back navigation restores that snapshot; the click then lands on the closed trade board instead of a new draft — verified: the section refreshes only on `friends-updated` and the page was cacheable; the closed board does offer the "again" link to a new draft, so the player is one click away. Fix applied: `turbo_exempts_page_from_cache` on `app/views/friends/show.html.erb`, as `trades/_screen.html.erb` does, so a back navigation reloads the links; a page left open across a friend's cancel still lands on the closed board with its "again" link.
  - `[false]` `[reject]` The plan's earlier triage row and Auto Run Result still describe the reverted, blocked attempt, the `.patch` file remains and the Plan Change Log is empty — the earlier rows are the record of the first pass, which this log appends to; the Auto Run Result is rewritten at finalize; the intent changes are the author's decisions recorded in the intent contract, not plan amendments. The fix would be an edit of this build's plan.
  - `[low]` `[patch]` `@open_trade` (friend profile) and `open_trade` (friend row) hold a trade token, not a trade, against the repo's "carry intent in names" rule — verified in both views. Fix applied: renamed to `@open_trade_token` / `open_trade_token`, and the row's map to `@open_trade_tokens`.

## Verification

**Commands:**
- `bin/rails test test/controllers/friends_controller_test.rb test/packs/game` -- expected: 0 failures
- `bin/rails test test/system/friends_test.rb` -- expected: 0 failures
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: green

## Auto Run Result

- **Status:** built (follow-up run after the author's decisions of 2026-10-12).
- **Summary:** ÉCHANGE / TRADE (renamed from PROPOSER UN ÉCHANGE / Propose a trade) on a friend row and in the friend profile dialog opens the trade in progress with that friend directly, with no one-at-a-time refusal, or a new draft; the trades-closed line keeps its place when a profile is private. The row part (`Game::OpenTradesByFriend`, the row link, query, controller and system tests) was committed by the author in e345aa4cb75015ba84b9028ebf98bc7be7d44c29 from the saved patch; this run added the dialog, the rename and the review patches.
- **Files changed (whole ticket since the baseline):**
  - `packs/game/app/queries/game/open_trades_by_friend.rb` -- `{ friend id => trade token }` for in-progress, unexpired trades, either side.
  - `app/controllers/friends_controller.rb` -- reads the open trade tokens once.
  - `app/views/friends/show.html.erb` -- the row links to the open trade or a new draft; label and accessible name renamed; the page is exempt from the Turbo cache.
  - `app/controllers/friend_profiles_controller.rb`, `app/views/friend_profiles/show.html.erb` -- the dialog's button links to the open trade or a new draft; label renamed.
  - `config/locales/en.yml`, `config/locales/fr.yml` -- `trade` / `trade_with` replace `propose_trade` / `propose_trade_to` ("Échange", "Échange avec %{name}" / "Trade", "Trade with %{name}").
  - `test/packs/game/open_trades_by_friend_test.rb`, `test/controllers/friends_controller_test.rb`, `test/controllers/friend_profiles_controller_test.rb`, `test/system/friends_test.rb`, `test/system/trades_test.rb` -- open-trade link from row and dialog, new draft once closed, the new label.
  - `ux-gameble/EXPERIENCE.md`, `ux-gameble/DESIGN.md` -- "ÉCHANGE" for the friend row and friend profile button, direct opening in "One trade per pair".
- **Review findings:** 3 — 2 patched (low: Turbo cache exemption on the Friends page; low: token-holding variables renamed), 0 deferred, 1 rejected (false: the plan's earlier result sections describe the first, blocked pass; fixing it is an edit of this build's plan).
- **Follow-up review recommended:** false — patched counts by verdict: high 0, medium 0, low 2.
- **Verification:** `bin/rails test` 2198 runs, 2 failures, both the known date failures below; system tests `friends_test.rb`, `trades_test.rb`, `live_updates_test.rb`, `settings_test.rb`, `shell_test.rb`, `feed_test.rb` 69 runs, 0 failures; `bin/rubocop`, `packwerk validate` and `check`, `i18n-tasks missing` and `unused`, `npm run typecheck`, `bin/brakeman`, `bin/bundler-audit`, `bin/rails zeitwerk:check` and `npm run test:js` (217 tests) green. `bin/setup` and the migration step from `bin/ci` were not run (no migration; the shared database must not be reset).
- **Deferred:** none.
- **Residual risks:** a Friends page left open while the friend cancels or the trade expires still links ÉCHANGE to the closed trade until it refreshes; the closed board then offers the "again" link to a new draft. The two full-suite failures `test/packs/game/trades_of_test.rb:62` and `test/controllers/sessions_controller_test.rb:316` come from the 2026-10-25 daylight-saving change and fail without this diff too.
