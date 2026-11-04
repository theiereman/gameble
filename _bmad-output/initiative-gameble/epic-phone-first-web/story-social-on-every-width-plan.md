---
title: 'Social on every width'
type: 'feature'
ticket: '15'
created: '2026-11-04'
status: 'built'
baseline_revision: '092972dce0f0dc4fefda3f623e0dc9d3e33c0b21'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/mockups/social.html'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Social exists only as a phone screen: the desktop hub lists Trades, Friends and Feed separately and nothing leads to /social, so the bell's weekly-mission line drops a desktop player on a screen laid out for a phone.

**Approach:** Make Social one screen at every width, as specified in EXPERIENCE.md (section Social, Desktop navigation, Back button, Count badge) and drawn in mockups/social.html (direction A, section 6 compact 3): one 04 SOCIAL hub entry, Social opening on the weekly mission, then trades and friends, then a live feed preview, a two-column desktop layout, a compact phone trade row, and Social named as the parent in the back button.

## Boundaries & Constraints

**Always:** server-rendered ERB, no markup built in script; every string in en.yml and fr.yml; no database id in the DOM; a GET writes nothing; no `style` attribute; the ids `community-goal`, `community-goal-progress`, `goal-reward`, `menu-trades-badge`, `menu-friends-badge`, `plus-trades-badge`, `plus-friends-badge` and every `tab-*` slot keep working as live targets; the weekly mission stays on the hub; file size limits (CSS 500, Ruby/TS 400).

**Never:** touch the trades board or list files (`trades/_side`, `trades/_board`, `trades-board.css`, `.trade-row`/`.trade-chip` base rules) or the bell files (`bell.ts`, `bell_controller.ts`, `_bell.html.erb`, `shell-bell.css`) or `config/routes.rb`: other work is in flight there. No new feed query: reuse `Game::FeedEntries`. Do not reuse the `feed-entries` id or the feed stream for the preview. Do not change the phone trade board's back ("◀ LISTE" to the list).

**Decisions (author, 2026-11-04):** the plan is kept whole despite its length; on the phone a trade's board keeps "◀ LISTE" to the trade list, and "◀ SOCIAL" applies to the trade list, Amis, the feed, and a trade at 720px and wider. Social's order at every width is mission, trades, friends, then the feed preview, the actions last on the phone; trades matter most (supersedes the plan's first order, mission then feed). Invitation badges are accent blue, trades badges orange.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Hub menu | signed-in player on the hub | seven entries 01–07, keys 1–7; 04 SOCIAL links to Social with "n en ligne" when friends are online, then the trades badge (orange) and the invitations badge (accent blue) side by side, each absent at zero | — |
| Live badges | a trade or invitation arrives | the 04 SOCIAL badges update through the existing stream slots | — |
| Desktop Social | ≥ 1180px | mission band, trades (wide) beside friends (380px), then three feed entries across the width with the LIVE marker and "Voir le fil" in the head, the two actions in the page heading | — |
| Phone Social | < 720px | mission, trades as compact rows, friends, two feed entries, actions above the tab bar | — |
| Empty feed | no entry yet | the feed section shows "Rien pour l'instant." | — |
| New feed entry | a pull happens while Social is open | the preview shows it on top and stays three entries long | — |
| Back | Trades, Friends, Feed or a trade at ≥ 720px, opened from the hub or the bell | a "◀ SOCIAL" back leading to Social | — |

</frozen-after-approval>

## Code Map

- `app/views/pages/_menu.html.erb` + `_menu_trades.html.erb`, `_menu_friends.html.erb`, `_menu_feed.html.erb`, `_menu_achievements.html.erb`, `_menu_how_it_works.html.erb`, `app/helpers/external_links_helper.rb:19` (support number) -- numbers and `aria-keyshortcuts` hard-coded per partial; `_menu_friends` holds the online meta and `#menu-friends-badge`, `_menu_trades` holds `#menu-trades-badge`. `menu_key.ts` and `hub_menu_controller.ts` need no change.
- `app/views/player_streams/_update.turbo_stream.erb` -- replaces `menu-trades-badge` / `menu-friends-badge`; keeping both ids inside the new Social entry keeps it unchanged.
- `app/controllers/pages_controller.rb#social` (L29-38) -- add the feed preview data; `@friends_online` comes from `Game::FriendsPresence.online_count`.
- `app/views/pages/social.html.erb`, `app/frontend/styles/social.css` (258 lines; one phone media query L222) -- reorder, desktop grid, page heading with actions.
- `app/views/pages/_goal.html.erb` (+ `hub-goal.css`) -- shared with the hub and live streams; give Social a band layout through a Social-scoped class, not by changing the partial's ids.
- `app/models/live_stream.rb` (`strip_items` L53, `STRIP_SIZE`), `app/jobs/live_feed_job.rb`, `app/views/live_streams/_feed.turbo_stream.erb` (replaces `live-strip`) -- precedent for a capped live preview: add a Social preview list replaced the same way under its own id.
- `app/views/feeds/_entry.html.erb` -- reuse for preview rows (`lazy: true` reactions, as the live prepend does).
- `app/views/pages/_social_trade_row.html.erb`, `_social_trade_side.html.erb`, `app/helpers/social_helper.rb` -- the phone compact row (turn under the name, tone edge, avatar hidden < 720px).
- `app/views/friends/show.html.erb:5-9`, `feeds/show.html.erb:4-10`, `trades/_screen.html.erb:4-15` (phone back), `shell/_top_bar.html.erb`, `shell-top-bar.css:42-49`, `shell-screens.css:160-182`, `previous_screen_controller.ts`, `history_trail.ts`, `ShellHelper::SCREEN_LABELS` -- desktop shows only the trail-based previous button, none after the hub.
- Tests: `test/controllers/pages_controller_test.rb:97-146,394` (menu count, keys, numbers, per-link), `achievements_controller_test.rb:190`, `friends_controller_test.rb:109-137`, `trades_controller_test.rb` (~193, 221; file under edit by another session: change only the hub-menu assertions), `test/system/trades_test.rb:48-49,74-75`, `test/system/hub_test.rb`, `test/system/live_updates_test.rb:65-90`, `test/controllers/social_page_test.rb` (L163 heading order), `test/integration/phone_tabs_test.rb:45`, `test/integration/shell_test.rb:136-138,314`, `test/jobs/live_feed_job_test.rb` if present.

## Tasks & Acceptance

**Execution:**
- [x] `app/views/pages/_menu.html.erb` + new `_menu_social.html.erb` -- seven entries; 04 SOCIAL carries online meta and both badge slots; renumber achievements 05, how it works 06, support 07; delete `_menu_trades`, `_menu_friends`, `_menu_feed` if unused; add `pages.home.menu.social` in both locales.
- [x] `app/models/live_stream.rb`, `app/jobs/live_feed_job.rb`, `live_streams/_feed.turbo_stream.erb`, new `pages/_social_feed.html.erb` -- three latest entries under id `social-feed-preview`, replaced live on each new entry.
- [x] `pages_controller.rb#social`, `pages/social.html.erb` -- order mission, trades, friends, feed preview; page heading with h1 and both actions (desktop), actions kept above the tab bar on the phone; mission band.
- [x] `social.css` (and `hub-goal.css` only if needed) -- desktop grid ≥ 1180px (trades wide, friends 380px), one column below; feed third entry hidden < 720px; compact phone trade row.
- [x] `_social_trade_row.html.erb`, `social_helper.rb` -- turn text under the name for the phone variant with its tone; chip kept for desktop.
- [x] back buttons -- at ≥ 720px Trades, Friends, Feed and a trade show "◀ SOCIAL" to Social (the phone back link made visible on desktop, the trail button hidden there); phone board back unchanged.
- [x] tests -- update menu assertions to seven entries and new numbers/keys; Social order, feed preview (three entries, empty line, live replace target), desktop back on the four screens; LiveFeedJob renders the preview replace.

**Acceptance Criteria:**
- Given a signed-in player on the hub, when they press 4 in the menu, then Social opens.
- Given Social at 1440px, then nothing in its markup carries a `style` attribute and a GET writes nothing.

## Design Notes

Back on desktop: the trail button (`.top-bar__previous`) already reads "Social" when coming from Social; the decision is that these four screens always name Social. Rendering their existing `phone_back` link at every width and hiding the trail button on those screens keeps one server-rendered link and no script change.

## Spec Change Log

Author decisions relayed during the build, after the frozen block was approved (the frozen block is left as approved; these rows override it):
- The invitations badge is violet (`--color-goal-3` on `--color-on-goal`), not accent blue: blue and green belong to the standard and special capsules. Classes `menu-item__badge--friends` and `tab-bar__badge--friends`.
- Social shows only trades in progress, "À vous" then "À son tour"; ended trades live in All trades only. The Recently block, `SOCIAL_RECENT_TRADES` and the quiet row are gone.
- Trades and friends are capped at five rows (`SocialRows::LIMIT`). Past five, four rows show and the fifth is an outlined "others" line linking to All trades or Friends. It names the hidden people, up to three names and then "et n autre(s)". The trades line carries "À vous" if any hidden trade waits on the player, else "À son tour". Friends: online first. More than five online gives four online plus "… en ligne". Five or fewer online are completed with offline friends up to five. Mock: `ux-gameble/.working/social-capped-lists.html`.
- From 1180px trades and friends share the width equally (`repeat(2, minmax(0, 1fr))`), instead of a 380px friends column.
- Resolves the deferred item "Open trades and friends are uncapped on Social".

## Verification

**Commands:**
- `bin/rails test test/controllers/pages_controller_test.rb test/controllers/social_page_test.rb test/integration/phone_tabs_test.rb test/integration/shell_test.rb` -- expected: 0 failures
- `npm run format:check && npm run lint:css && script/check_file_sizes && script/check_planning_references` -- expected: pass
- `bin/rails test test/system/hub_test.rb test/system/trades_test.rb test/system/live_updates_test.rb` -- expected: 0 failures

**Manual checks (if no CLI):**
- Social at 1440 × 900 and 390 × 844 against mockups/social.html.

## Review Triage Log

| Finding | Verdict | Route | Evidence |
|---|---|---|---|
| Feed preview rendered with the viewer's scope, replaced live with the public scope | medium | patch | `social_preview_entries` took `current_player` while `LiveFeedJob` broadcasts `FeedEntries.call(nil)`; the page now uses the public scope like the strip. |
| Trades "others" line repeats a friend with several hidden trades | low | patch | names mapped per trade; `.uniq` added before `names_and_others`. |
| Trades "others" line loses hover and focus ring | medium | patch | `.trade-row.social-trade.social-trade--others` (0,3,0) beat `.trade-row:focus-visible` which also drops the outline; hover and focus-visible rules added at the same specificity. |
| Menu shows "0 en ligne" with no friend online | false | reject | Carried over unchanged from the former 05 AMIS entry; `pages_controller_test.rb:387` asserted "0 online" before this change. |
| Actions shown in the heading from 720px but reached last by keyboard | medium | patch | Actions moved after the h1 in the DOM; on the phone `order: 1` keeps them last above the tab bar. |
| Hub system test name claims a wordmark check it never makes | low | patch | Renamed to what it checks. |
| No width-dependent test pins the phone board keeping only "◀ LISTE" and desktop hiding the trail button | maybe-false (medium) | defer | Markup is asserted; the CSS works today but no system test at 390/1440px covers it. |

