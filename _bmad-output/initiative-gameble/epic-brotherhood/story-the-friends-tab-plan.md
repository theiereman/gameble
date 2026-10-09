---
title: 'The Friends tab'
type: 'feature'
ticket: '8'
created: '2026-10-08'
status: done
baseline_revision: '5fedea5dce83b10b3a3c2d53b2e4ffa4c1da04d2'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md', '{project-root}/_bmad-output/initiative-gameble/epic-brotherhood/epic-brotherhood.md', '{project-root}/_bmad-output/initiative-gameble/epic-brotherhood/bug-the-feed-is-narrower-than-the-other-screens-and-shows-tout-t.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The feed shows everyone's events only; a signed-in player cannot follow their friends' pulls, trades and reposts. Bug 13 hid the lone TOUS tab until this story brings TOUS and AMIS together.

**Approach:** Above the type filters, a tab row TOUS · AMIS (segmented control, `tab=friends` in the URL). AMIS shows only the viewer's friends' entries, read at render from the friendship query (not live), through the same visibility, ordering and fallback as TOUS, and combines with the type filter ("AMIS · TIRAGES" = friends' pulls): each tab keeps the current filter and each filter keeps the current tab. A player without friends sees "Ajoutez des amis pour suivre leurs tirages." with "AJOUTER DES AMIS" leading to Amis. Signed out, AMIS is a button opening the sign-in panel, and `?tab=friends` signed out renders TOUS.

## Boundaries & Constraints

**Always:** one « Tout » per row's meaning: the tab row reads TOUS / AMIS (`feeds.show.tabs.all` "Tous"/"All", `feeds.show.tabs.friends` "Amis"/"Friends"), the filter row keeps TOUT. `Game::Visibility` still decides each entry (a private friend's entries stay hidden). A GET writes nothing. Every string in `en.yml` and `fr.yml`. The current tab is `aria-current` like the filters. The feed keeps the full content width bug 13 gave it; phone layout without sideways scroll.

**Never:** no live update of the AMIS tab; no friends' entries cached in a table; no tab row for anything but TOUS and AMIS; no change to the LIVE ticker; no planning ids in code or tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| TOUS | `/feed` | everyone's visible entries, TOUS current | — |
| AMIS with friends | signed in, friends with entries, `?tab=friends` | only friends' entries (not the viewer's own, not strangers'), AMIS current | — |
| AMIS + filter | `?tab=friends&filter=pulls` | friends' pulls only; filter links keep `tab=friends`, tab links keep `filter=pulls` | — |
| AMIS, no friends | signed in, no friendship | the no-friends line + "AJOUTER DES AMIS" → `friends_path` | — |
| AMIS, friends but nothing in filter | friends, none matching | the filter's empty line | — |
| Private friend | a friend with private visibility | their entries absent from AMIS | — |
| Signed out | visitor | AMIS is a button opening `sign-in-panel`; `?tab=friends` renders TOUS | — |
| Unknown tab | `?tab=zzz` | TOUS | — |

</intent-contract>

## Code Map

- `app/controllers/feeds_controller.rb` -- `show` reads `filter` (`FILTERS`), calls `Game::FeedEntries.call(current_player, kind:)`, then `Catalog::CardViews`. Add `@tab` (`"friends"` only for a signed-in player, else nil) and pass the friends scope; update the header comment (it says only TOUS exists).
- `packs/game/app/queries/game/feed_entries.rb` -- `call(viewer, kind:)` builds `scope` then `visible(...)`; fillers are added for no kind or `pull`. Add an optional `players:` (ids) restricting both the notable scope and the fillers to those players.
- `packs/game/app/queries/game/friends_of.rb` / `Friendship.other_ids(player.id)` -- the viewer's friends (good standing); use the ids for AMIS.
- `app/views/feeds/show.html.erb` L18-26 -- restore a tab row above `.feed__filters` (`<nav class="feed__tabs segmented" aria-label=…>`): two links for a signed-in player; for a visitor TOUS is a link and AMIS a `ButtonComponent`-like control with `opens: "sign-in-panel"` styled as a segmented option. Filter links carry `tab:`; tab links carry `filter:`. The no-friends state replaces the list on AMIS when the viewer has no friend (`PanelComponent` like `.feed__empty`, with a primary button to `friends_path`).
- `app/frontend/styles/feed.css` -- `.feed__tabs { margin: 0 }` was removed by bug 13; restore what the tab row needs.
- `config/locales/en.yml`, `fr.yml` `feeds.show` -- `tabs.all` "All"/"Tous", `tabs.friends` "Friends"/"Amis", `tabs_label` "Whose events"/"Événements de", `no_friends` "Add friends to follow their pulls."/"Ajoutez des amis pour suivre leurs tirages.", `add_friends` "Add friends"/"Ajouter des amis".
- Tests: `test/controllers/feeds_controller_test.rb` (setup `@player` "Hugo", `open_epic`), `test/packs/game/feed_test.rb` (`add_entries`), `test/system/feed_test.rb` (bug 13's checks: one « Tout » — now the tab row reads TOUS and the filter row TOUT, so assert the filter row has one TOUT and the tab row TOUS/AMIS; width checks stay), `test/system/hub_test.rb` / sign-in panel opening pattern in existing system tests.

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/queries/game/feed_entries.rb` (+ `test/packs/game/feed_test.rb`) -- `players:` restriction applied to notable entries and fillers.
- [x] `app/controllers/feeds_controller.rb` -- `tab`, friends ids, no-friends flag.
- [x] `app/views/feeds/show.html.erb`, `feed.css` -- tab row, combined links, no-friends state, visitor's AMIS opening the sign-in panel.
- [x] `config/locales/en.yml`, `fr.yml` -- keys above.
- [x] Tests -- controller: every matrix row; system: signed in AMIS shows a friend's pull and not a stranger's, AMIS · TIRAGES, no-friends button leads to Amis, signed out AMIS opens the sign-in panel, bug 13's width and single TOUT checks kept (adapted to the tab row).

**Acceptance Criteria:**
- Given a player with friends, when they choose AMIS, then only their friends' pulls, trades and reposts show, and TOUS shows everyone's.
- Given a player without friends, when they choose AMIS, then "Ajoutez des amis pour suivre leurs tirages." and "AJOUTER DES AMIS" show, and the button opens Amis.
- Given a visitor, when they press AMIS, then the sign-in panel opens.

## Implementation Notes

## Plan Change Log

## Review Triage Log

### 2026-10-08 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` New comments explaining code (above `TABS`, `items`, `friends_and_strangers`) against AGENTS.md — fixed: removed.
  - `[low]` `[patch]` French UI labels used as words in comments and test names (TOUS, AMIS, TIRAGES…) against "repo text in English" — fixed: All, Friends, Friends · Pulls in comments and test names, including three older test names in the touched file; French only in assertions on rendered `fr` strings.


## Verification

All Ruby commands need Ruby 4.0.7 from rbenv: prefix them with `export PATH=/opt/rbenv/shims:$PATH && `; system tests also need `CHROME_BIN=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/chrome.sh SE_CHROMEDRIVER=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/cd/chromedriver`. Never run `npm install`.

**Commands:**
- `bin/rails test` -- expected: all green
- `bin/rails test test/system/feed_test.rb test/system/hub_test.rb` (system env above), 3× -- expected: green
- `bin/rubocop && bundle exec packwerk check && bin/rails zeitwerk:check && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

**Summary.** The feed has a tab row All · Friends above the type filters. Friends shows only the viewer's friends' entries (read at render from `Game::FriendsOf`, through the same visibility, order and fallback, `Game::FeedEntries.call(..., players:)`), combines with the type filter, offers "Add friends" to Amis when the player has none, and for a visitor is a button opening the sign-in panel (`?tab=friends` signed out reads All).

**Files.**
- `packs/game/app/queries/game/feed_entries.rb` -- `players:` restriction for notable entries and fillers.
- `app/controllers/feeds_controller.rb` -- `tab`, friend ids, no-friends state.
- `app/views/feeds/show.html.erb`, `feed.css` -- tab row, combined links, no-friends panel, visitor's Friends button.
- `config/locales/en.yml`, `fr.yml` -- tabs, no-friends line and button.
- Tests: `test/packs/game/feed_test.rb`, `test/controllers/feeds_controller_test.rb`, `test/system/feed_test.rb`.

**Review.** One quick pass: 2 low patches (comments, English repo text), nothing deferred or rejected.

**Follow-up review recommended:** false.

**Verification.** `bin/rails test` green; rubocop, packwerk, zeitwerk, i18n-tasks clean; `feed_test.rb` and `hub_test.rb` green.

**Residual risks.** A player with friends but no entry at all on Friends sees the general empty line.
