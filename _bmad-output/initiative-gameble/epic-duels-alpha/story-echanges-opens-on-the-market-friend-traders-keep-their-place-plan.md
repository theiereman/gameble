---
title: 'ÉCHANGES opens on the market, friend traders keep their place, and the apps get DUELS back'
type: 'feature'
ticket: '3'
created: '2026-11-20'
status: 'built'
baseline_revision: '9daccbb6353b8a3397c5801df7edb849bba7a5dc'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** ÉCHANGES still opens on ENTRE AMIS with MARCHÉ second, and the native apps show PONT · CAPSULE · SETS · TRADES · MARKET (commits 30e6f4a0 and 6661f3b7) while the web shows PONT · CAPSULE · SETS · ÉCHANGES · DUELS.

**Approach:** MARCHÉ first and `Game::ExchangesTab::DEFAULT = "market"`; a bulk operation, run once by a rake task, stores `friends` for players with an accepted friend trade closed in the last 30 days and no stored tab; the apps get the DUELS tab back (badge + ALPHA mark) after a single ÉCHANGES tab rooted at `/exchanges`, `/trades`, `/market`, and the page reports the ÉCHANGES and DUELS badges instead of the friend-trades and market ones.

## Boundaries & Constraints

**Always:** writes only through the operation; one event published in its transaction; every string in `en.yml` and `fr.yml`; the ÉCHANGES sub-tab bar stays on the native app (`exchanges/_tabs` keeps `if current_player`); the tab order PONT · CAPSULE · SETS · ÉCHANGES · DUELS on both apps; the `exchanges_tab` check constraint unchanged (no migration).

**Never:** the backfill in `bin/docker-entrypoint`; a stored tab overwritten; a style attribute; a native build here.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Recent friend trader | accepted trade, `closed_at` 3 days ago, no stored tab (with or without a state row) | `exchanges_tab = friends`, both parties | none |
| Older trader | accepted trade closed 31 days ago | tab stays nil, ÉCHANGES opens on MARCHÉ | none |
| Other recent trade | declined / expired / open trade in the window | untouched | none |
| Already chose | stored `market` and a recent accepted trade | stays `market` | race-safe: COALESCE in the upsert |
| Deleted player | recent accepted trade, `deleted_at` set | untouched | none |
| Rerun | backfill run twice | second run changes nothing, returns 0 | none |
| New player | no stored tab | `/exchanges` redirects to `/market`; sub-tabs MARCHÉ, ENTRE AMIS | none |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/exchanges_tab.rb` -- `DEFAULT = "market"`; `call(nil)` returns it.
- `app/controllers/exchanges_controller.rb` -- `kept_tab` collapses to `Game::ExchangesTab.call(current_player)` (nil gives the default, market).
- `app/views/exchanges/_tabs.html.erb` -- swap the two `<li>`: market first.
- New `app/domains/game/app/operations/game/backfill_exchanges_tabs.rb` -- `Game::BackfillExchangesTabs < ApplicationOperation` (no player: like `ComputeDuelStats`), `call(now: Time.current)`: players = both parties of `Game::Trade` with `status: "accepted"`, `closed_at: (now - 30.days)..now`, in `Accounts::Player.where(deleted_at: nil)`, minus `PlayerState.where.not(exchanges_tab: nil)`; `PlayerState.upsert_all` rows `{ player_id, exchanges_tab: "friends", created_at, updated_at, **PlayerState.markers_at_published_season }`, `unique_by: :player_id`, `record_timestamps: false`, `on_duplicate: Arel.sql("exchanges_tab = COALESCE(game_player_states.exchanges_tab, excluded.exchanges_tab), updated_at = excluded.updated_at")` (pattern: `KeepExchangesTab#store`); publishes `Game::ExchangesTabsBackfilled` (`STREAM = "Game::ExchangesTabs$backfilled"`, data `{ players: n }`, pattern `DuelStatsComputed`); returns n.
- New event `app/domains/game/app/events/game/exchanges_tabs_backfilled.rb`.
- `app/domains/game/lib/tasks/game.rake` -- `game:backfill_exchanges_tabs` calls `.value!` and prints the count. Not in `bin/docker-entrypoint`.
- Web, reverse of 6661f3b7: `app/frontend/lib/native_top_bar.ts` (`trades` reads `#tab-trades-badge .tab-bar__badge`; `market` becomes `duels` reading `#tab-duels-badge .tab-bar__badge`) and `native_top_bar.test.ts`; `app/views/shell/_native_tab_badges.html.erb` (`tab-trades-badge` with `shell/tab_trades_badge` waiting+outbid, `tab-duels-badge` with `shell/tab_duels_badge` count `shell_duels_in_progress`); `app/views/top_bars/show.turbo_stream.erb` (same two updates). `PlayerStreamJob` already streams `tab-trades-badge` and `tab-duels-badge`.
- Dead after that, delete: `shell/_tab_friend_trades_badge`, `shell/_tab_market_badge`, `pages/_menu_friend_trades_badge`, `pages/_menu_market_badge` (their DOM targets are no longer rendered since entry 1), their four lines in `player_streams/_update.turbo_stream.erb`, keys `shell.tabs.trades_waiting`, `shell.tabs.market_outbid`, `pages.home.menu.trades_waiting`, `pages.home.menu.market_outbid` in both locales (keep `exchanges.tabs.market_outbid` and the other `market_outbid` keys).
- iOS: `mobile/ios/Gameble/Tabs.swift` (paths `["", "/booster", "/library", "/exchanges", "/duels"]`, roots as before 30e6f4a0, DUELS `HotwireTab` with `tab-duels`), `TopBar/TopBarStore.swift` (`market` → `duels`), `Gameble.swift` Palette (`onGold` 0x120D05, `onAccent` 0x0B1520 from `tokens.css`), restore `Assets.xcassets/tab-duels.imageset/` from `30e6f4a0^`, delete `tab-market.imageset/`.
- Android: `Tabs.kt` (same paths/roots/NAMES `trades`, `duels`, tab 4 `R.string.tab_duels`, `R.drawable.ic_tab_duels`, `R.id.duels_host`), `TopBarState.kt` (`market` → `duels`), `res/layout/activity_main.xml` (`market_host` → `duels_host`), `res/values{,-fr}/strings.xml` (`tab_market` → `tab_duels` "Duels"), `res/values/colors.xml` (`on_gold`, `on_accent`), restore `res/drawable/ic_tab_duels.xml` from `30e6f4a0^`, delete `ic_tab_market.xml`.

## Tasks & Acceptance

**Execution:**
- [x] `exchanges_tab.rb`, `exchanges_controller.rb`, `exchanges/_tabs.html.erb` -- market default and first -- R5
- [x] `backfill_exchanges_tabs.rb`, `exchanges_tabs_backfilled.rb`, `game.rake` -- the release backfill -- R5
- [x] `native_top_bar.ts`, `_native_tab_badges`, `top_bars/show.turbo_stream.erb`, `player_streams/_update`, the four partials, locales -- page reports ÉCHANGES and DUELS badges -- R5
- [x] iOS and Android files above -- five tabs ending in DUELS, badge and ALPHA -- R5
- [x] Tests: new `test/domains/game/backfill_exchanges_tabs_test.rb` (the matrix); `keep_exchanges_tab_test.rb` (default market: the first-time tests flip to market); `exchanges_controller_test.rb` (first time → market, sub-tab order MARCHÉ then ENTRE AMIS, kept value market on the trades page); `test/system/duels_test.rb` (phone: ÉCHANGES opens on MARCHÉ first, then ENTRE AMIS once used); `test/system/hub_test.rb` (key 3 → market); `hotwire_native_test.rb` and `top_bars_controller_test.rb` (`tab-trades-badge`, `tab-duels-badge`); `player_stream_job_test.rb:186` (targets list without the four); `native_top_bar.test.ts` (`duels`).

**Acceptance Criteria:**
- Given a new player on a phone, when they tap ÉCHANGES, then `/market` opens with MARCHÉ current and listed before ENTRE AMIS.
- Given the app with the native bar, when any screen loads or `/top_bar` streams, then `.native-tab-badges` holds `#tab-trades-badge` and `#tab-duels-badge` and nothing targets `tab-friend-trades-badge` or `tab-market-badge`.
- Given both apps built, when launched signed in, then the tab bar reads PONT · CAPSULE · SETS · ÉCHANGES · DUELS, DUELS shows ALPHA, or its count in accent while a duel waits, and ÉCHANGES shows the sub-tabs.

## Implementation Notes

- Two tests outside the plan's list relied on the friends default and were updated: `exchange_tabs_controller_test.rb` (the kept tab is now `friends`, since keeping the default writes nothing) and `test/system/trades_test.rb` (the desktop trades test keeps `friends` before menu 03).
- Android's ALPHA badge uses `BadgeDrawable.setText`/`clearNumber`, and the count path calls `clearText()` first; neither native app was built here.
- After review, `Game::ExchangesTabsBackfilled` carries no data (events carry identifiers only); the operation still returns the count, which the rake task prints.

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 4, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `exchanges_controller_test.rb` "the market screens carry the bar…" keeps `market`, which now writes nothing since it is the default — the setup line is deleted; the test checks the default.
  - `[low]` `[reject]` the backfill's returned count can include a player who stores a sub-tab between the pluck and the upsert (COALESCE keeps their choice, `updated_at` bumps) — the task runs once at release in a window of milliseconds and only the printed count is off; a race-exact count needs a RETURNING upsert with a WHERE clause Rails' `upsert_all` cannot express.
  - `[low]` `[patch]` `game:backfill_exchanges_tabs` had no test, unlike its neighbours — a rake test in `backfill_exchanges_tabs_test.rb` (`RakeTasks`, `capture_io`) checks the printed count and both parties on friends.
  - `[low]` `[patch]` `ExchangesTabsBackfilled` carried a count against "events carry identifiers only" (`lib/application_operation.rb`) — the event carries no data; tests count the stream's events.

## Design Notes

Assumptions (no one to ask):
- ALPHA mark on a native tab (ticket's unknown): a tab item has one badge, so the DUELS badge shows the duel count in accent (as the web's `tab-bar__badge--accent`) while a duel waits, and the text "ALPHA" in gold on on-gold otherwise; the title stays "Duels", which fits a 5-tab bar at 320 pt. Android sets `text` on the Material 1.12 `BadgeDrawable` (clearing `number`), and `clearText()` before a number.
- The backfill publishes one global event (no data, since events carry identifiers only; review), as `ComputeDuelStats` does, rather than one `ExchangesTabKept` per player, keeping the rule of one event per operation.
- "Friend trade" is any `game_trades` row (the market has its own tables); both parties count; deleted players are skipped, banned ones are not filtered (their tab is never read).
- A player without a `game_player_states` row gets one with the season markers, as `KeepExchangesTab` does.
- The rake task is run by the author once in production at release (entry 8); it is idempotent.
- The ÉCHANGES sub-tab bar already showed on the native app since entry 1 (`exchanges/_tabs` checks `current_player` only); nothing to change there.
- Native builds cannot run here: the author builds and launches both apps (Xcode simulator, Android emulator) and checks the five tabs, the DUELS badge and ALPHA, and the ÉCHANGES sub-tabs.

## Verification

Per the coordinator, suites run once in the main tree: the implementer runs no test, linter, check or native build, and calls git only as `/usr/bin/git` (to restore files: `/usr/bin/git show 30e6f4a0^:<path>`).

**Commands (coordinator):**
- `bin/rails test test/domains/game/backfill_exchanges_tabs_test.rb test/domains/game/keep_exchanges_tab_test.rb test/controllers/exchanges_controller_test.rb test/controllers/hotwire_native_test.rb test/controllers/top_bars_controller_test.rb test/jobs/player_stream_job_test.rb` -- expected: green
- `bin/rails test test/system/duels_test.rb test/system/hub_test.rb` and `npm run test:js` -- expected: green
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/ci` -- expected: green

**Manual checks:**
- Author: build and launch iOS (Xcode simulator) and Android (emulator); five tabs ending in DUELS, ALPHA on DUELS, ÉCHANGES opening on the kept sub-tab with its sub-tab bar.

## Auto Run Result

Status: built

**Summary:** ÉCHANGES opens on MARCHÉ for a player who never chose (`Game::ExchangesTab::DEFAULT = "market"`), with MARCHÉ the first sub-tab; `Game::BackfillExchangesTabs`, run once by `game:backfill_exchanges_tabs` (not a deploy step), stores `friends` for both parties of an accepted trade closed in the last 30 days who have no stored tab, and publishes one `Game::ExchangesTabsBackfilled`; the iOS and Android apps show PONT · CAPSULE · SETS · ÉCHANGES · DUELS again, ÉCHANGES rooted at `/exchanges`, `/trades`, `/market`, DUELS badged with its count in accent or ALPHA in gold; the page reports `#tab-trades-badge` and `#tab-duels-badge` to the apps, and the friend-trades and market tab and menu badge partials, their stream lines and keys are gone.

**Files changed:**
- `app/domains/game/app/queries/game/exchanges_tab.rb`, `app/controllers/exchanges_controller.rb`, `app/views/exchanges/_tabs.html.erb` — market default and first.
- `app/domains/game/app/operations/game/backfill_exchanges_tabs.rb`, `app/domains/game/app/events/game/exchanges_tabs_backfilled.rb`, `app/domains/game/lib/tasks/game.rake` — the release backfill.
- `app/frontend/lib/native_top_bar.ts` (+ test), `app/views/shell/_native_tab_badges.html.erb`, `app/views/top_bars/show.turbo_stream.erb`, `app/views/player_streams/_update.turbo_stream.erb` — trades and duels badges for the apps.
- Deleted `shell/_tab_friend_trades_badge`, `shell/_tab_market_badge`, `pages/_menu_friend_trades_badge`, `pages/_menu_market_badge`; four keys per locale removed from `config/locales/{en,fr}.yml`.
- `mobile/ios/Gameble/Tabs.swift`, `TopBar/TopBarStore.swift`, `Gameble.swift`, `Assets.xcassets/tab-duels.imageset` (restored), `tab-market.imageset` (deleted) — iOS DUELS tab.
- `mobile/android/.../Tabs.kt`, `TopBarState.kt`, `res/layout/activity_main.xml`, `res/values{,-fr}/strings.xml`, `res/values/colors.xml`, `res/drawable/ic_tab_duels.xml` (restored), `ic_tab_market.xml` (deleted) — Android DUELS tab.
- Tests — new `test/domains/game/backfill_exchanges_tabs_test.rb`; `keep_exchanges_tab_test.rb`, `exchanges_controller_test.rb`, `exchange_tabs_controller_test.rb`, `hotwire_native_test.rb`, `top_bars_controller_test.rb`, `player_stream_job_test.rb`, `test/system/duels_test.rb`, `hub_test.rb`, `trades_test.rb` adjusted.

**Review:** 3 patches applied (3 low), 0 deferred, 1 rejected (the backfill count under a concurrent sub-tab choice: one run at release, only the printed figure is off, an exact count needs SQL `upsert_all` cannot express).

**Follow-up review recommended:** false — no high and no medium patched.

**Verification:** no suite, check or native build run in this build, by the coordinator's instruction; greps over app, test, config find no `tab-friend-trades-badge`, `tab-market-badge`, `menu-friend-trades-badge`, `menu-market-badge`, `tabs.trades_waiting`, `tabs.market_outbid`, `menu.trades_waiting`, `menu.market_outbid`. The backfill test was corrected for the `player_states` fixtures (player, moderator and administrator already have rows).

**Open verification (hitl):** the author builds and launches the iOS app (Xcode simulator) and the Android app (emulator), signed in, and checks the five tabs PONT · CAPSULE · SETS · ÉCHANGES · DUELS, ALPHA on DUELS (the count in accent while a duel waits), the ÉCHANGES badge, and the ÉCHANGES sub-tabs; then runs `bin/rails game:backfill_exchanges_tabs` once in production at release (entry 8).

**Residual risks:** neither native app was compiled (Material 1.12 `BadgeDrawable.setText`/`clearText`/`clearNumber`, the iOS `badgeValue` "ALPHA" width on a 320 pt bar); `i18n-tasks` may flag key ordering.
