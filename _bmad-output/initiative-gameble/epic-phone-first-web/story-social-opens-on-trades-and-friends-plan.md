---
title: 'Social opens on trades and friends'
type: 'feature'
ticket: '8'
created: '2026-11-03'
status: 'built'
baseline_revision: 'cde8806c2c85b67249abd94401d398135c98f2a0'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: ['/home/teyermann/projets/gameble/.claude/worktrees/agent-a368f38e8d7d04352/AGENTS.md']
warnings: [oversized]
deferred:
  - summary: >-
      Keyboard focus on a trade row is nearly invisible: `.trade-row:focus-visible` sets `outline: none` and keeps only the near-black focus gap.
    evidence: |-
      trades.css `.trade-row:focus-visible` overrides the global white ring of shell.css `:focus-visible`; the Social rows reuse `.trade-row`, so they inherit it. Predates this change.
    location: >-
      app/frontend/styles/trades.css:126
    severity: medium
  - summary: >-
      `BackOffice::RoadmapsControllerTest` "an administrator reads every milestone" can fail at random: it looks for a record id with `form [id*='7']` and similar substring selectors, which match unrelated attributes when the id is a single digit.
    evidence: |-
      The implementing agent saw it fail in two full runs (matching '8', then '7') and pass alone; the orchestrator's bin/ci run passed all 4296 runs. The test predates this change and nothing here touches the roadmap screens.
    location: >-
      test/controllers/back_office/roadmaps_controller_test.rb:57
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The phone's Social tab opens an interim menu of three links (Trades, Friends, Feed), so a player sees neither whose turn a trade is nor their friends without a further tap; the weekly community goal lives only on the hub; and the feed's two groups of filter chips (whose events, then five types) share one row cut at the right edge of a phone.

**Approach:** `pages#social` becomes the Social home: trades in progress first (waiting on the player, then waiting on the friend), recent ended trades shown quietly, then the friends list, then the weekly community goal, then the feed as a secondary section, with Add a friend and New trade at the bottom (sticky above the tab bar on a phone). A Social trade row shows only the friend (avatar, name), a turn chip derived from the trade's recipient (who did not send last) and the highest rarity among its cards. The feed keeps its All / Friends toggle as two chips and moves its five type filters into the shared bottom sheet, opened by one chip that names the type in force.

## Boundaries & Constraints

**Always:** server-rendered ERB, no markup built in script; no `style` attribute in server HTML; strings in both `en.yml` and `fr.yml`; the page's h1 visually hidden; reads only through domain queries (`Game::TradesOf`, `Game::FriendsPresence`, `Game::CurrentGoal`, `Game::GoalRewardStatus`, `Catalog::CardViews`), one `CardViews` call for every row; no database id in HTML (trade and friend tokens only); keep the `#plus-trades-badge` and `#plus-friends-badge` stream slots on the Social page (the player stream updates them); tap targets at least 44px on the phone; the feed's tab links keep the type filter and the filter links keep the tab, as today; a GET writes nothing.

**Decisions (conservative, put to the author in `pending-approvals.md` under Open):** the trade board's own list (`trades/_list`) keeps its current rows, only the Social rows take the new shape; the feed section on Social is a link to the feed, not embedded entries; the community goal also stays on the hub; the feed's toggle keeps its "All" / "Tous" wording; ended trades on Social are capped at the five most recent.

**Never:** the card list, library, Sets screens, or `BottomSheetComponent` / `bottom_sheet_controller.ts` themselves (other work owns them); the trade board, trade picker or new trade rules; the bell or a last-seen marker; the Me page; adding tests to `test/system/shell_test.rb` or `test/integration/shell_test.rb`; React or `innerHTML` markup.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Waiting first | player is recipient of trade A and proposer of trade B | Social lists A ("Your turn") before B ("Their turn"), each linking to its trade by token | none |
| Row content | trade holding a common and an epic card | row shows the friend's name, the turn chip and "Epic" as highest rarity; no card title or thumbnail | a trade with no resolvable card shows no rarity |
| Turn follows sender | player counters trade A | A now reads "Their turn" | none |
| Quiet history | accepted and expired trades closed within 14 days, seven of them | the five most recent shown under a "Recently" heading with a muted chip (Done / Closed) and their age | none |
| No trades | no open or recent trade | a short empty line; New trade still at the bottom | none |
| Friends | one open friend, one private friend | both listed with presence; the open one links to its friend profile, the private one is plain text | no friend: an empty line pointing to Add a friend |
| Bottom actions | any player | Add a friend leads to `friends#show` at `#friends-invite`; New trade to `trades#new` | none |
| Community goal | current week, reward claimable | the goal panel with progress and its collect button | no reward: no button |
| Feed reach | Social | a link to the feed; links to all trades and to the friends screen carry the two badge slots | none |
| Feed sheet | GET feed `filter=trades` | `.feed__controls` holds the All / Friends tabs and one opener chip naming Trades; a bottom sheet holds the five type links (Everything first), Trades marked current | visitor: Friends stays a disabled chip, the sheet works |
| GET writes nothing | GET social | 200 under the reading role with writes prevented | visitor: redirected to the landing as today |

</intent-contract>

## Code Map

- `app/controllers/pages_controller.rb` `#social` (now only `authorize :page, :play?`) -- load `@trades = Game::TradesOf.call(current_player)`, `@cards` = one `Catalog::CardViews.call(ids, locale: I18n.locale)` over the open rows and the shown recent rows, `@friends = Game::FriendsPresence.call(current_player)`, `@goal = Game::CurrentGoal.call`, `@goal_reward = Game::GoalRewardStatus.call(current_player)`. Recent cap as a named constant. File is 117 lines.
- `Game::TradesOf` (`app/domains/game/app/queries/game/trades_of.rb`) -- `Result(yours, theirs, recent)`; `Row` has `token`, `friend`, `state` (`:yours` when the player is the recipient; `Game::CounterTrade` swaps proposer and recipient, so the recipient is who did not send last), `outcome`, `card_season_ids`, `open?`, `ended_at`. Do not change it.
- `Catalog::CardViews` / `CardView#rarity` (a string such as `"epic"`), `Catalog::Rarity::TIERS` (`{ 1 => :common, ... 5 => :legendary }`) -- highest rarity = max by tier. Rarity icons: `pixel_icon("rarity-#{tier}")`; colours `--color-rarity-commune|peu-commune|rare|epique|legendaire` (see `.feed__tag--*` in `feed.css` 186-204).
- `app/helpers/trades_helper.rb` (224 lines) -- reuse `trade_chip` tones and `trades.chip.*` (Done / Closed), `trade_outcome_age(row)`, `friend_name` (`friends_helper.rb`). New Social-row helpers (highest rarity, turn chip) go in a new `app/helpers/social_helper.rb`.
- `app/views/trades/_list.html.erb` and `trades.css` `.trade-row*`, `.trade-chip*` -- row look to reuse on Social (`pixel_icon("avatar-default", class: "trade-row__avatar")`); do not change `_list`.
- `app/views/pages/social.html.erb` (interim menu, `.plus` classes) -- replace whole. `.plus`/`.menu-item--plus` styles in `settings.css` stay (Me page uses them). Keep `turbo_exempts_page_from_cache`. Badge partials `pages/_menu_trades_badge` (`waiting: shell_trades_waiting`) and `pages/_menu_invitations_badge` (`invitations: shell_invitations_waiting`); `player_streams/_update.turbo_stream.erb` updates `plus-trades-badge` and `plus-friends-badge`.
- Live refresh: `trades/_screen.html.erb` uses `data-controller="live-refresh" data-live-refresh-signal-value="trades-updated"`, `friends/show.html.erb` uses `friends-updated`; one signal per controller, so put each on its own Social section.
- Friends: `Game::FriendsPresence.call` rows (`player`, `state`, ...); `friends/_presence.html.erb` renders presence; `Game::Visibility.open_to_friends?(player)` decides the `friend_profile_path(token:)` link; `friends#show` has `#friends-invite`.
- Community goal: `pages/_goal.html.erb` (`goal:`, `reward:`, ids `community-goal`, `community-goal-progress`, `goal-reward`), styles `hub-goal.css`; live progress needs `turbo_stream_from(*LiveStream.goal_streamables)`; `goal_rewards/create.turbo_stream.erb` replaces `#goal-reward` (other targets it names are absent on Social, which Turbo ignores).
- Phone sticky bottom bar pattern: `trades-responsive.css` 115-121 (`position: sticky; bottom: calc(var(--tabbar-height) + env(safe-area-inset-bottom))`), phone breakpoint `@media (max-width: 719px)`.
- Feed: `app/views/feeds/show.html.erb` 14-31 (`.feed__controls` with `data-controller="current-chips"`, `nav.feed__tabs`, `nav.feed__filters`), `feed_chip_link` in `feed_helper.rb`, `FeedsController::FILTERS`, `feed.css` 22-44 and 332-335. `current_chips_controller.ts` is used only here: remove it with the attribute (check for a sibling test file). Sheet: `render BottomSheetComponent.new(id:, title:) { ... }` outside `.feed__controls`; opener `tag.a(**bottom_sheet_opener(id), class: "filter-chip ...")` (see `library/_filters.html.erb:16` and `library/_quick_filters.html.erb`, `.quick-filters*` in `collection-filters.css` 95-125 for the look; do not edit those files). Keep classes `.feed__filters`, `.feed__filter`, `.feed__tab`, `.feed__tabs` so existing assertions keep meaning.
- New CSS: `app/frontend/styles/social.css`, imported in `app/frontend/entrypoints/application.css` after `friends.css`. File limits: 400 lines Ruby/TS, 500 CSS.
- Locales: `pages.social.*` (en.yml ~2168 alphabetical, fr.yml ~235); drop the unused `subtitle`. Feed keys under `feeds.show` (`filters_label`, `filters.*`).
- Tests to update: `test/integration/phone_tabs_test.rb` 46-53 (interim menu assertions; 39-44 reach test must still pass), `test/integration/player_stream_tag_test.rb` 57-60, 75-78, 92-95 (`.plus a.menu-item[...] #plus-*-badge`), `test/controllers/feeds_controller_test.rb` 260-261 (`a.menu-item--plus` feed link on Social) and 276-288 (controls structure), `test/controllers/pages_controller_test.rb` 417-427 visitor redirect (keep), `test/system/trades_test.rb:166` (`.plus a[href='/en/trades']`), `test/system/live_updates_test.rb` 200-219 (`.plus a.menu-item #plus-friends-badge`), `test/system/feed_test.rb` (desktop one-line chips, phone scrolling chips and `current_filter_in_view?`, Friends · Pulls) -- the feed system tests now open the sheet to choose a type. Seeding helpers: see `test/controllers/trades_controller_test.rb` and `test/controllers/friends_controller_test.rb` for trades and friendships.

## Tasks & Acceptance

**Execution:**
- [x] `app/controllers/pages_controller.rb` -- load trades, card views, friends, goal and reward in `#social` -- the Social home's data in one place.
- [x] `app/helpers/social_helper.rb` -- highest rarity of a row from the card views; turn chip (tone, label) for open rows and quiet chip for ended rows -- keeps the views free of logic.
- [x] `app/views/pages/social.html.erb` + `app/views/pages/_social_trade_row.html.erb` + `app/views/pages/_social_friend.html.erb` -- visually hidden h1; Trades section (head with a link to all trades carrying `#plus-trades-badge`; open rows yours then theirs; "Recently" quiet rows; empty line), live-refreshed on `trades-updated`; Friends section (head link to the friends screen carrying `#plus-friends-badge`; rows avatar, name, presence; empty line), live-refreshed on `friends-updated`; `render "pages/goal"` and the goal stream; Feed section with a link to the feed; bottom actions Add a friend (secondary) and New trade (primary).
- [x] `app/frontend/styles/social.css` + import -- section layout, quiet row (muted, no accent hover border), rarity tag colours, phone sticky actions bar above the tab bar, 44px targets.
- [x] `app/views/feeds/show.html.erb`, `app/helpers/feed_helper.rb` (if a helper is needed), `app/frontend/styles/feed.css`, delete `app/frontend/controllers/current_chips_controller.ts` -- tabs plus one opener chip naming the current type in `.feed__controls` (no overflow scroll needed); a bottom sheet titled "Filter by type" holding `nav.feed__filters` with the five type chips, current marked.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- Social section headings, links, empty lines, turn chips ("Your turn" / "Their turn"; fr "À vous" / "À son tour"), "Recently", highest-rarity accessible prefix, actions ("Add a friend" / "Ajouter un ami", "New trade" / "Nouvel échange"), feed opener label with the current type.
- [x] `test/controllers/social_page_test.rb` (new) -- every Social matrix row except Feed sheet; `test/controllers/feeds_controller_test.rb` -- the Feed sheet row (structure, current marks, links keep tab/filter, visitor).
- [x] Existing tests listed in the Code Map -- update selectors and expectations; rewrite the feed system tests around the sheet (phone: open by the chip, choose Reposts, the opener names Reposts, no sideways scroll; desktop: tabs and opener on one line).
- [x] `_bmad-output/initiative-gameble/pending-approvals.md` -- one Open item with the five conservative decisions above.

**Acceptance Criteria:**
- Given a signed-in phone at 390x844, when Social loads, then the trades come first and Add a friend and New trade sit at the bottom above the tab bar without covering the last section.
- Given the feed on a phone, when it loads, then no chip is cut at the right edge and the page never scrolls sideways.

## Implementation Notes

- System tests were written or updated (`test/system/feed_test.rb`, `test/system/trades_test.rb`, `test/system/live_updates_test.rb`, and a new `test/system/social_test.rb` for the phone acceptance criterion) but not run, at the author's request.
- `test/controllers/friends_controller_test.rb` also asserted the interim Social menu (`.plus__list a.menu-item[href='/fr/friends']`); it now asserts the Social home's link to all friends.
- The "no resolvable card shows no rarity" case is covered in `test/helpers/social_helper_test.rb`: a trade cannot be proposed without cards, so no request test reaches it.
- On a phone a Social trade row shows only the rarity icon; the rarity's name stays in the accessibility tree (clipped), so the friend's name keeps room beside the turn chip.
- The feed opener reads "Type: <type>" ("Type : <type>" in French); the bottom sheet is rendered right after `.feed__controls`, inside `section.feed`. The phone feed chips take the 44px touch height.

## Plan Change Log

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 5 findings — high 0, medium 3, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` `test/system/trades_test.rb` phone test: after "All trades", `.trade-row` matched Social's own rows before the visit landed — fixed: asserts `/en/trades` as the current path, then scopes the rows to `.trades__list .trade-row`.
  - `[medium]` `[patch]` `social.css` `.social__more:focus-visible` and `.social-friend--link:focus-visible` set `outline: none`, dropping the global white focus ring for a near-black gap — fixed: `outline: none` removed, the global ring shows. The same pattern on `.trade-row:focus-visible` in `trades.css` predates this change: deferred.
  - `[low]` `[reject]` a hovered, focused quiet trade row loses its focus ring because `.trade-row.social-trade--quiet:hover` outranks `.trade-row:focus-visible` — mouse hover over a keyboard-focused row is rare, and the fix adds a `:not(:focus-visible)` branch to a rule that already inherits the pre-existing weak trade-row focus.
  - `[medium]` `[patch]` `test/system/social_test.rb` first layout check held only when the page was taller than 844px — fixed: removed; the scrolled-to-end check, true at any height, stays.
  - `[low]` `[patch]` `social.css` intent comment above the phone rarity-label rule broke the no-comment rule — fixed: deleted.

## Design Notes

Highest rarity, one `CardViews` lookup shared by all rows:

```ruby
def trade_top_rarity(row, cards)
  row.card_season_ids.filter_map { cards[it]&.rarity }.max_by { Catalog::Rarity::TIERS.key(it.to_sym) }
end
```

Do not run any system test (the author asked); write and update them, and record in Implementation Notes that they were not run at the author's request.

## Verification

**Environment:** work only in `/home/teyermann/projets/gameble/.claude/worktrees/agent-a368f38e8d7d04352`; export `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w8` (this worktree's own test database, already loaded) for every Rails command; never run a system test; do not commit, stage or touch git branches.

**Commands:**
- `bin/rails test test/controllers/social_page_test.rb test/controllers/feeds_controller_test.rb test/controllers/pages_controller_test.rb test/integration/phone_tabs_test.rb test/integration/player_stream_tag_test.rb test/jobs/player_stream_job_test.rb test/controllers/read_only_requests_test.rb test/helpers` -- expected: pass
- `npm run test:js && npm run format:check && npm run lint:css` -- expected: pass
- `bin/ci && bin/rails zeitwerk:check && bundle exec packwerk check && bundle exec i18n-tasks missing` -- expected: pass
- `script/check_file_sizes && script/check_planning_references` -- expected: pass

## Auto Run Result

- **Summary:** the Social tab is now the Social home: open trades (waiting on the player first, then on the friend), the five most recent ended trades shown quietly, the friends with presence, the weekly community goal, a feed section, and Add a friend / New trade at the bottom (sticky above the tab bar on a phone). A trade row shows the friend, a turn chip derived from the trade's recipient, and the highest rarity among its cards. The feed keeps its All / Friends chips and moves its five type filters into the shared bottom sheet, opened by a "Type: <type>" chip.
- **Files:** `pages_controller.rb` (`#social` reads trades, card views, friends, goal, reward); `social_helper.rb` (highest rarity, turn chip); `pages/social.html.erb`, `_social_trade_row`, `_social_friend` (the page); `social.css` + import (layout, quiet rows, rarity colours, sticky actions); `feeds/show.html.erb`, `feed_helper.rb`, `feed.css` (opener chip and type sheet); `current_chips_controller.ts` deleted (only the feed used it); `en.yml` / `fr.yml` (strings, unused `pages.social.subtitle` removed); tests: new `social_page_test.rb`, `social_helper_test.rb`, `test/system/social_test.rb`, updated feeds, friends, phone tabs, player stream tag tests and the feed, trades and live updates system tests; `pending-approvals.md` (five conservative decisions under Open).
- **Review:** 5 findings; 4 patched (medium 3, low 1), 1 low rejected (hover outranking focus on a quiet row, rare and adds a branch); 2 items deferred (pre-existing trade-row focus ring, pre-existing flaky back-office roadmap test). Follow-up review recommended: false (no high patched; the medium patches are test hygiene and a removed `outline: none`, each verified by reading the patched file).
- **Verification:** the plan's Rails test set 241 runs, 0 failures; `npm run test:js` 854 passed; `format:check`, `lint:css`, `zeitwerk:check`, `packwerk check`, `i18n-tasks missing`, `check_file_sizes`, `check_planning_references` pass; `bin/ci` passed every step (4296 Rails runs, 0 failures). After the review patches (CSS and system tests only): `format:check`, `lint:css`, rubocop, file sizes and planning references pass again. No system test was run, at the author's request.
- **Residual risks:** the system tests written or changed here (`social_test`, `feed_test`, `trades_test`, `live_updates_test`) have never run; the Social page's two live-refresh sections are untested in a browser; the phone layout of the Social page is unverified on a device.

## Code Review

### 2026-11-04 — 0 decision-needed, 1 patch, 3 defer, 3 rejected

- [x] [Review][Patch] Show the no-trade line whenever nothing is in progress, even with recent ended trades [app/views/pages/social.html.erb]
- [x] [Review][Defer] Live refresh of the Social sections is asserted only as attributes — deferred: one system test next to the Social badge test, run before release
- [x] [Review][Defer] Open trades and friends are uncapped on Social — deferred: add a see-all cap when a player has dozens
- [x] [Review][Defer] Keyboard focus ring on quiet trade rows under hover, the wrapped feed opener at 320 px and the screen-reader reading of the rarity badge — deferred: settle on the iPhone pass

**Rejected**
- Unknown open state or unknown rarity raises: low, no such state or rarity exists today.
- Nil current goal on Social: low, the hub shares the same guard-free partial.
- Default avatar on rows, comment inconsistency, plan paths and credentials in the plan: low or edits the plan.
