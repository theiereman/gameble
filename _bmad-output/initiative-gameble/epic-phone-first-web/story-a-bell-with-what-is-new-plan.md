---
title: 'A bell with what is new'
type: 'feature'
ticket: '10'
created: '2026-11-03'
status: 'built'
baseline_revision: '6bd3e054028f0cde891e0529b87cf8326265a7ec'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      Every signed-in page view makes one extra GET for the bell frame, including phone drill-downs where the bell is hidden.
    evidence: |-
      The frame has no HTTP caching and is not permanent across Turbo visits. Whether it matters needs the frame's cost measured under production traffic.
    location: >-
      app/views/shell/_bell.html.erb
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** A player learns of a friend request, a trade waiting on them, a ready daily capsule or the weekly mission only by visiting each screen; the header has no place that says what is new, on phone or desktop.

**Approach:** A pixel bell in the header (phone top-level screens and every signed-in desktop page) opens a native popover under the top bar listing lines computed from current state: friend requests received, trades waiting on the player, the daily capsule when collectable, and one weekly-mission line. Each line is one sentence and one link to its target. The browser remembers, per device, which lines were seen: a line clears when its target page is opened (by the line or any other way) or its state ends; the counter shows the unseen lines.

## Boundaries & Constraints

**Always:** the lines come from a read-only `Game::BellItems` query served by a GET `bell` frame (`BellsController#show`, `BellPolicy#show?` = player); the GET writes nothing on the server; the seen set lives in `localStorage` only (key `gameble:bell-seen`, capped, every access in try/catch); line keys are built from tokens, revisions and dates, never database ids; every string in `en.yml` and `fr.yml` (French plurals with `zero`); the bell icon is drawn in `script/pixel_art/export.mjs` and exported; live reload of the frame on `gameble:trades-updated` and `gameble:friends-updated` through `onGameble`; reduced motion honoured; file size limits (400 Ruby/TS, 500 CSS).

**Decisions (agent, recorded in pending-approvals):** the weekly-mission line reads "The weekly mission is accomplished: a rare capsule awaits you." with "Collect" when the player has an unclaimed goal reward, otherwise "This week's mission: open %{target} capsules together." with "See"; both lead to Social's mission panel. "Clears when its target is opened" is held per device in the browser, not on the server (entry 11 adds the server marker for trades). Lines per kind are capped at five.

**Never:** a server-side seen marker or migration (entry 11); achievements or "trade updated" lines; editing `app/frontend/images/pixel/` by hand; markup built in script (lines are server HTML; the controller only hides lines and writes the counter text); `style` attributes; touching the player chip, the Me tab or the bank counter beyond placing the bell; adding tests to `test/system/shell_test.rb` or `test/integration/shell_test.rb`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| All kinds | 1 pending request, 1 trade waiting on player, daily collectable, no reward | counter 4; lines: trade → `/en/trades/<token>`, request → `/en/friends`, daily → `/en/booster`, mission → `/en/social#community-goal` | none |
| Target opened | player lands on `/en/trades/<token>` | that trade's line hidden, counter 3, on every later page | storage refused: nothing is remembered, all lines stay |
| New turn | trade countered back to player (new revision) | the trade's line shows again (new key) | none |
| Daily | collected / next day | line gone / a new day's line (new key) replaces it | no published season: no daily line |
| Reward | unclaimed goal reward | reward line instead of the week line | none |
| Nothing new | no lines unseen | no counter; panel says "Nothing new for now." | frame fails to load: counter stays hidden |
| Excluded | banned sender/proposer, expired trade, trade waiting on the friend | no line | none |
| Visitor / back office | no player / back-office page | no bell | frame GET as visitor refused by policy |

</intent-contract>

## Code Map

- `app/views/shell/_top_bar.html.erb` -- insert one line `<%= render "shell/bell" unless back_office_page? %>` inside `if current_player`, just before `render "shell/player_chip"` (outside the `top_bar_status` block so the collection screen keeps it). Story 12 may edit this file: keep the change to that line.
- `app/views/shell/_bank_counter.html.erb` + `app/frontend/styles/shell-top-bar.css:294` `.shell-popover` -- the pattern to copy: `<button popovertarget>` + `<div popover class="shell-popover">`. CSS files are near their limits: new `app/frontend/styles/shell-bell.css`, imported after `shell-header-phone.css` in `app/frontend/entrypoints/application.css`. Phone (`max-width: 719px`): bell only on `.top-bar--top-level`; tap target ≥ `--space-touch-min`; counter in `var(--font-number)` like `.bank-counter__count`.
- `app/helpers/shell_helper.rb` (190 lines) -- `shell_trades_waiting`, `shell_invitations_waiting` show the existing state rules; `app/helpers/friends_helper.rb` `friend_name(player)` for names.
- `app/domains/game/app/queries/game/trades_waiting.rb`, `invitations_waiting.rb`, `bank_summary.rb` (`DailyBonusClaim.day_of`, `Catalog::PublishedSeason.call`), `goal_reward_status.rb` (unclaimed = `claimed: false`), `current_goal.rb`, `WeeklyGoal.week_start` -- reuse their exact conditions in a new `app/domains/game/app/queries/game/bell_items.rb` returning a `Data` with `trades` (token, player, revision), `invitations` (token, player), `daily` (day or nil), `goal` (week_start, reward_ready, target). One `Accounts::Player.where(id:)` query for both lists. `Trade#revision` is `proposed_at` iso8601(6).
- Routes: inside the `:locale` scope, `resource :bell, only: :show` (near `packs_chip`, line 39). Controller pattern: `app/controllers/packs_chips_controller.rb`, policy `app/policies/packs_chip_policy.rb`. turbo-rails serves frame requests with its frame layout.
- `app/views/bells/show.html.erb` -- `<turbo-frame id="bell-items" target="_top">` with `ul` of lines (`data-bell-target="item"`, `data-bell-key`, `data-bell-path` = target pathname) and the empty message (`data-bell-target="empty"`). Partial per line in `app/views/bells/_line.html.erb`.
- `app/frontend/lib/events.ts` -- `onGameble("gameble:trades-updated" | "gameble:friends-updated")` exist (broadcast by `PlayerStreamJob` signals); add no new event.
- `app/frontend/lib/i18n.ts` `t(Template, {count})` for the button's accessible name; `app/frontend/lib/last_album.ts` -- the storage try/catch pattern.
- New `app/frontend/lib/bell.ts` (pure: read/write/cap the seen set, `opensTarget(path, location.pathname)`, unseen count) + `bell.test.ts`; new `app/frontend/controllers/bell_controller.ts` (targets `item`, `empty`, `count`, `label`, `frame`; values `labels` Object; marks the current page's lines seen on `itemTargetConnected`, marks a line seen on its link click, hides seen lines, writes the counter and label, reloads the frame on the two signals). Check `app/frontend/controllers/index.ts` or the registration convention.
- Pixel: `script/pixel_art/export.mjs` -- add `"bell"` (11 × 11, `c` = currentColor) next to `tab-me` (~line 624) and its `"bell.svg"` DESCRIPTIONS entry (~line 1175); run `node script/pixel_art/export.mjs`.
- Locales: `shell.bell.*` in `config/locales/en.yml` and `fr.yml`.
- Tests: `test/support/steam_sign_in.rb`, `test/support/catalog_seeds.rb` (`publish_sets_draft`), `test/system/friends_test.rb` (setup pattern), `Game::ProposeTrade` (see `test/support/game_trades.rb`), `test/jobs/player_stream_job_test.rb`, `test/controllers/read_only_requests_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `script/pixel_art/export.mjs` + export -- bell icon -- header icon
- [x] `app/domains/game/app/queries/game/bell_items.rb` + `test/domains/game/bell_items_test.rb` -- the state rules and every Excluded/Reward/Daily row of the matrix
- [x] `config/routes.rb`, `app/controllers/bells_controller.rb`, `app/policies/bell_policy.rb`, `app/views/bells/*`, `app/helpers/bell_helper.rb` (line key, path, sentence) + `test/controllers/bells_controller_test.rb` -- frame with lines and links, keys free of ids, visitor refused, GET writes nothing
- [x] `app/views/shell/_bell.html.erb`, `_top_bar.html.erb` line + `test/integration/bell_slot_test.rb` -- slot for a player on top-level and drill-down pages, none for visitor or back office
- [x] `app/frontend/lib/bell.ts`, `bell.test.ts`, `app/frontend/controllers/bell_controller.ts` -- seen set, counter, live reload
- [x] `app/frontend/styles/shell-bell.css` + import -- desktop and phone layout
- [x] `config/locales/en.yml`, `fr.yml` -- `shell.bell.*`
- [x] `test/system/bell_test.rb` -- one desktop flow and one 390×844 check (restore the window size)
- [x] `_bmad-output/initiative-gameble/pending-approvals.md` -- the mission line wording and the per-device seen set

**Acceptance Criteria:**
- Given a pending request, a trade waiting on the player and a ready daily capsule, when a desktop page loads, then the bell shows a counter and the panel has a line each (plus the mission line) leading to its target.
- Given those lines, when the player follows the trade line, then on the trade page and later pages the counter has dropped by one and the trade line is gone.
- Given 390×844 on a top-level screen, when it loads, then the same bell shows in the header and opens the same panel.
- Given the pixel source, when `node script/pixel_art/export.mjs --check` runs, then it passes.

## Implementation Notes

**Decisions**
- Line keys: `trade:<token>:<revision>`, `invitation:<token>`, `daily:<YYYY-MM-DD>`, `mission:<week start>`, `mission-reward:<reward week start>`. They carry no locale, so a line seen under `/en` stays seen under `/fr`; `data-bell-path` is the locale's pathname of the target (`/en/social` for both mission lines, whose link adds `#community-goal`).
- Each line is a single link: the sentence plus a short action label ("Answer" for a trade, "See" for a request and the week's mission, "Collect" for the daily capsule and the mission reward). The link's accessible name is the whole sentence, and the tap target is the whole row.
- The mission line is always rendered, so the server never sends zero lines. "Nothing new for now." is server HTML that the controller shows once every line is seen.
- `Game::BellItems` copies the conditions of `TradesWaiting`, `InvitationsWaiting`, `BankSummary` (daily) and `GoalRewardStatus` (unclaimed = `claimed: false`). It orders trades by `expires_at` and requests newest first, at most five of each, and loads both senders with one `Accounts::Player.where(id:)`. The week's target comes from `CurrentGoal`.
- `BellsController#show` answers only frame requests; a plain visit to `/en/bell` is redirected home, as `custom_sets#games` does, so a full page never holds two `#bell-items` frames.
- Seen set: a JSON array in `localStorage["gameble:bell-seen"]`, capped at the 100 newest keys. Damaged JSON or non-string entries read as unseen. Every read and write is wrapped in try/catch.
- The count is shown in `--color-alert`, in `--font-number`. No animation was added, so reduced motion has nothing to stop.
- On the phone the bell shows only in `.top-bar--top-level`, with a 44px tap target. It is still rendered on drill-down pages (hidden by CSS), so opening a trade page on the phone still marks that trade's line as seen.

**Files**
- New: `app/domains/game/app/queries/game/bell_items.rb`, `app/controllers/bells_controller.rb`, `app/policies/bell_policy.rb`, `app/helpers/bell_helper.rb`, `app/views/bells/show.html.erb`, `app/views/bells/_line.html.erb`, `app/views/shell/_bell.html.erb`, `app/frontend/lib/bell.ts`, `app/frontend/lib/bell.test.ts`, `app/frontend/controllers/bell_controller.ts`, `app/frontend/styles/shell-bell.css`, `app/frontend/images/pixel/bell.svg` (exported), `test/domains/game/bell_items_test.rb`, `test/controllers/bells_controller_test.rb`, `test/integration/bell_slot_test.rb`, `test/system/bell_test.rb`.
- Changed: `app/views/shell/_top_bar.html.erb` (one line), `config/routes.rb`, `app/frontend/entrypoints/application.css`, `config/locales/en.yml`, `config/locales/fr.yml`, `script/pixel_art/export.mjs`.

**Surprises**
- The fixture player's Steam sign-in lands on `/en/booster`, which marks the daily line seen once the frame arrives. The system test waits for the frame, then clears the seen set before it starts counting.
- Every signed-in page now makes one extra GET (the `bell` frame). It is small, but it adds a request to each page view.
- `pending-approvals.md` already held this entry, written by the orchestrator; it was not touched here.
- Verification ran against a shared local Postgres whose `/dev/shm` was 96% full. The parallel `bin/rails test` could not prepare its worker databases (`PG::DiskFull`). A serial full run was then polluted by the non-transactional race tests, so it was stopped and the test database reloaded from `db/schema.rb`.
- Run serially and green: `test/integration`, `test/controllers`, `test/policies`, `test/helpers`, `bell_items_test` and `player_stream_job_test` (1743 runs). One `ShellTest` deadlock appeared once under that load and passed on two reruns. Also green: `bell_test.rb` (system), vitest, typecheck, `format:check`, `lint:css`, the pixel `--check`, `check_file_sizes`, `check_planning_references`, `check_markup_apis`, packwerk, `zeitwerk:check`, rubocop, brakeman and `i18n-tasks missing`. The full `bin/ci` was not run, because its schema steps drop and recreate the test database on the shared server.

**Review patches (orchestrator, 2026-11-03)**
- The daily line and the mission-reward line are lasting: they never clear on opening their page, only when their state ends (the ticket's "the daily item replacing itself", the brainstorm's "vanishes once collected"; the capsule screen is the sign-in landing, so it would otherwise hide the daily line at once). `daily_bonuses/create` and `goal_rewards/create` streams remove `#bell-daily` / `#bell-mission-reward`.
- The seen set is kept per player: `localStorage["gameble:bell-seen:<player token>"]`.
- The controller recomputes on `turbo:frame-render` (a morph reload keeps the `li`s and strips `hidden`), on `turbo:morph@document` (a page morph resets the count), and after `follow`; the current page's lines are marked seen on every recompute, not only on connect. `turbo:frame-missing` keeps the old content.
- `TradesWaiting.relation` and `InvitationsWaiting.relation` are shared with `BellItems` instead of copied conditions.
- The week's line says the mission is accomplished once it is (`mission_reached`); the zero label reads "What is new, all seen"; the panel scrolls within the viewport; French colons take U+202F.
- `package-lock.json`'s name, renamed by the worktree's npm install, was restored.

## Plan Change Log

- 2026-11-03, review pass 1: no loopback. Patches applied in place (see Review Triage Log). The intent-contract's general rule "a line clears when its target page is opened" is left as written; the daily line and the mission-reward line are its exception, from the ticket's own wording ("the daily item replacing itself") and the brainstorm ("vanishes once collected"). KEEP: lines from server state in a GET frame, the per-device seen set, keys from tokens/revisions/dates.

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 39 findings — high 5, medium 13, low 17, false 3, maybe-false 1
- findings:
  - verification-gap
    - `[medium]` `[patch]` clearing by opening a target without the line is untested — the desktop system test visits `/en/friends` directly and asserts the count drops by both request lines.
    - `[medium]` `[patch]` the `friends-updated` reload is untested — the desktop test adds a request, sends a friends signal and asserts the count rises.
    - `[medium]` `[patch]` the all-seen state is never reached — a third system test reaches zero (daily claimed, friends and Social opened): no count, "all seen" label, "Nothing new for now.".
    - `[low]` `[patch]` the order that keeps five per kind is not pinned — the cap test asserts the five trades expiring soonest and the five newest requests.
    - `[low]` `[patch]` `package-lock.json` name renamed to the worktree — restored.
    - `[low]` `[reject]` the plan says pending-approvals was not touched — a plan edit; the task box is ticked and the review notes say who wrote it.
  - intent-alignment
    - `[high]` `[patch]` the daily line is marked seen on the capsule landing before it is ever shown — daily and mission-reward lines are now lasting (state only), removed by the collect streams.
    - `[low]` `[reject]` friend requests clear as a group — opening the friends page shows every request; one page, one target, by design.
    - `[false]` `[reject]` trades: ticket's "waiting on the player" versus the epic's "trade updated" — the ticket names the waiting trade; updated trades are entry 11.
    - `[low]` `[reject]` "Collect" navigates instead of collecting — a recorded choice in pending-approvals; the line leads to its target as the verify asks.
    - `[medium]` `[reject]` the always-present mission line keeps the counter up weekly — the ticket's open unknown, queued for the author in pending-approvals.
    - `[false]` `[reject]` the counter does not use the pixel digits — it uses `--font-number`, the header counter's own digits (`.bank-counter__count`).
    - `[low]` `[reject]` the pixel export check is in no test file — it runs in the verification commands and passes.
    - `[low]` `[patch]` `package-lock.json` rename — same fix as above.
  - blind-hunter
    - `[high]` `[patch]` a morph reload brings seen lines back — `turbo:frame-render->bell#show`; the desktop test renames a sender, reloads and asserts two visible lines (it failed without the fix).
    - `[high]` `[patch]` daily and reward lines marked seen without being collected — lasting lines, as above.
    - `[medium]` `[patch]` the seen set is shared by every account of the browser — storage key scoped by the player's token.
    - `[low]` `[reject]` seen lines take the five slots per kind — only past five waiting trades or requests; a fix needs paging or a server-side seen set.
    - `[medium]` `[patch]` `BellItems` copies the waiting conditions — `TradesWaiting.relation` and `InvitationsWaiting.relation` shared; the daily rule stays two lines beside `BankSummary`.
    - `[low]` `[patch]` `package-lock.json` rename — same fix.
    - `[medium]` `[reject]` the mission line is counter noise — the open unknown, queued for the author.
    - `[maybe-false]` `[defer]` every page refetches the frame — settled by measuring the frame's cost under production traffic.
    - `[low]` `[patch]` a refused frame shows "Content missing" — `turbo:frame-missing->bell#keep` prevents it.
    - `[medium]` `[patch]` no test of the controller's wiring — the marking and hiding rules moved to `linesSeenHere`/`hiddenLines` in `bell.ts` with vitest, and the system tests now cover open-elsewhere, reload and all-seen.
    - `[low]` `[reject]` the plan contradicts the diff — a plan edit.
    - `[low]` `[patch]` the zero label reads awkwardly — "What is new, all seen" / "Nouveautés, tout est vu"; fr key order rejected as cosmetic.
  - edge-case-hunter
    - `[high]` `[patch]` frame reload morphs in place, `show()` never runs — same fix as the blind hunter's.
    - `[medium]` `[patch]` a page morph resets the count and label — `turbo:morph@document->bell#show`.
    - `[medium]` `[patch]` a counter arriving while the trade page is open is never marked — the current page's lines are marked seen on every recompute.
    - `[low]` `[patch]` `turbo:frame-missing` shows "Content missing" — same fix as above.
    - `[low]` `[reject]` two tabs racing on the seen set — rare, and the fix needs a storage listener and re-reads.
    - `[low]` `[patch]` ctrl-click leaves the line in the original tab — `follow` recomputes.
    - `[low]` `[reject]` FIFO eviction past 100 keys — 100 keys of trades, requests and weeks before one line returns.
    - `[false]` `[reject]` trailing slash on the target — every link to the target is the route helper's path, without a slash.
    - `[medium]` `[patch]` twelve lines overflow the phone viewport — the panel scrolls within `100dvh` less the top bar.
    - `[medium]` `[patch]` the week's line still says "open N" once the mission is accomplished — `mission_reached` wording.
    - `[low]` `[patch]` `package-lock.json` rename — same fix.
    - `[high]` `[patch]` claim: the counter goes stale after a live signal — same as the morph reload fix.
    - `[medium]` `[patch]` claim: lines morphed in place are never marked — same as the recompute fix.

### 2026-11-03 — Review pass (follow-up, after rebasing onto 44b77e92)
- verdicts: 30 findings — high 0, medium 9, low 20, false 1, maybe-false 0
- findings:
  - intent-alignment
    - `[low]` `[reject]` the daily line clears on collection, not on opening its target — the recorded exception, from the ticket's "the daily item replacing itself"; queued in pending-approvals.
    - `[medium]` `[patch]` the collect-removes-the-line behaviour is checked only at the stream surface — a system test now collects the daily capsule and watches the count drop.
    - `[low]` `[reject]` carried: per-device rather than cross-device clearing — a recorded decision, accepted until entry 11.
    - `[medium]` `[reject]` carried: the mission line always counts — queued for the author.
    - `[low]` `[reject]` the dropdown's form (under the bell or a top sheet) is untested visually — it is the existing header popover, like the bank detail.
    - `[low]` `[reject]` the phone hides the bell on drill-downs — the top-level-only header is entry 1's rule.
    - `[false]` `[reject]` the pixel check runs only through the manual commands — `test/lib/pixel_art_export_test.rb` runs it in the Ruby suite and `bin/ci`.
  - verification-gap
    - `[medium]` `[patch]` the lasting rule is not checked in a browser — the new system test opens `/en/booster` with the seen set intact and asserts the daily line still counts; it fails with `lasting: false` in the controller.
    - `[medium]` `[patch]` the removal after a collect is not checked against the count — same system test: Collect, count 3 → 2, the booster link gone, still 2 on the next page.
    - `[low]` `[reject]` the per-player storage key is not checked through the controller — needs a second sign-in in a browser test; revisit if entry 11 moves the set server-side.
  - edge-case-hunter
    - `[low]` `[patch]` a failed daily collect removed the lasting line — the remove is skipped while the capsule stays collectable.
    - `[medium]` `[patch]` collecting one reward removed the line while another week's reward still waits — removed only when no unclaimed reward remains.
    - `[medium]` `[patch]` a page restored from the Turbo cache kept a collected lasting line — `turbo:before-cache` drops the frame's `complete` so the restored frame reloads.
    - `[low]` `[patch]` teardown recomputes after Turbo moves to the next URL — `itemTargetDisconnected` recomputes only while the bell is connected.
    - `[low]` `[reject]` the mission key does not change once reached — one mission notification a week is the queued choice; the reached wording shows to whoever opens the panel.
    - `[low]` `[reject]` another tab keeps counting a line collected elsewhere — rare, and a reload on every bank change would refetch on each opening.
  - blind-hunter
    - `[medium]` `[patch]` the id-leak regex can match timestamp segments and fail at random — removed; the exact key list already pins every key to tokens, revisions and dates.
    - `[low]` `[reject]` carried with the deferred extra GET: the count appears after the frame's round trip on each visit — a permanent bell is a larger change.
    - `[low]` `[reject]` the daily rule is two lines beside `BankSummary`'s — carried from the first pass; both read `DailyBonusClaim` and the published season.
    - `[low]` `[reject]` carried: lines past five have no "more" sign.
    - `[low]` `[reject]` the mission key and the reached state — same as the edge-case row.
    - `[low]` `[patch]` `lasting_id` was both the DOM id and the flag — `BellLine` now has `lasting` and `dom_id`.
    - `[medium]` `[patch]` no end-to-end test of the lasting-line removal — same new system test.
    - `[low]` `[reject]` no phone check that drill-downs hide the bell — layout assertions were dropped from the browser suite on purpose; the CSS rule is one selector.
    - `[low]` `[reject]` each recompute rereads storage — a dozen lines, microseconds.
    - `[low]` `[reject]` stale on changes other than trades and friends — same as the edge-case row.
    - `[low]` `[reject]` the plan's notes lag the code — a plan edit.
    - `[low]` `[patch]` no policy test — `test/policies/bell_policy_test.rb`.
    - `[low]` `[reject]` `bellStorage()` throwing is untested — a two-line try/catch.
    - `[medium]` `[patch]` the panel has no accessible name — `aria-labelledby="bell-title"`; a live announcement of the count rejected, as the tab badges are not announced either.

## Verification

**Commands:**
- `bin/rails test test/domains/game/bell_items_test.rb test/controllers/bells_controller_test.rb test/integration/bell_slot_test.rb test/controllers/read_only_requests_test.rb test/jobs/player_stream_job_test.rb` -- expected: pass
- `bin/rails test test/system/bell_test.rb` -- expected: pass
- `npm run test:js && npm run format:check && npm run lint:css` -- expected: pass
- `node script/pixel_art/export.mjs --check && script/check_file_sizes && script/check_planning_references && bundle exec packwerk check && bin/rails zeitwerk:check` -- expected: pass
- `bin/ci` -- expected: pass

## Auto Run Result

**Summary:** a pixel bell sits in the header on every signed-in page except the back office; on a phone it shows only on top-level screens. It opens a native popover under the top bar. The popover's lines come from a read-only GET frame (`/:locale/bell`) holding up to five trades waiting on the player, up to five friend requests received, the daily capsule while it can be collected, and one weekly-mission line. Each line is one sentence and one link to its target.
- The counter shows the lines not yet seen. The browser remembers, per player, which lines were seen; a line clears once its target page is opened, by the line or any other way.
- The daily line and the mission-reward line stay until they are collected. The collect streams remove them.
- Live updates reload the frame on the trades and friends signals.

**Files**
- New:
  - `bell_items.rb`: the lines' state rules.
  - `bells_controller.rb`, `bell_policy.rb`, `bell_helper.rb`, `bells/show.html.erb`, `bells/_line.html.erb`: the frame.
  - `shell/_bell.html.erb`: the header slot.
  - `bell.ts`, `bell_controller.ts`: the seen set and the counter.
  - `shell-bell.css`: the layout.
  - `bell.svg`: the exported icon.
  - Four test files.
- Changed:
  - `_top_bar.html.erb`: one line.
  - `routes.rb`: the `bell` route.
  - `application.css`: the import.
  - `en.yml`, `fr.yml`: `shell.bell.*`.
  - `export.mjs`: the bell grid.
  - `trades_waiting.rb`, `invitations_waiting.rb`: a shared `relation`.
  - `daily_bonuses/create` and `goal_rewards/create` streams: they remove the lasting lines.
  - Two controller tests: assertions for those streams.

**Review:** one thorough pass with four lenses.
- 39 findings: high 5, medium 13, low 17, false 3, maybe-false 1.
- Patched, by entry verdict: high 2 (the morph reload, the lasting daily and reward lines), medium 9, low 6.
- Deferred: 1, the extra GET per page view.
- Rejected, with the reasons given in the triage log: the false findings, the plan edits, the mission line's weekly count (queued for the author), the five-slot cap, the two-tab race, FIFO eviction, the trailing slash, and "Collect" navigating rather than collecting.

**Follow-up review recommended: true.** Two high entries were patched without a second review. These patches have not been re-reviewed:
- the lasting-line rule and its stream removals;
- the controller recomputing on `turbo:frame-render` and `turbo:morph`, including how it behaves during a page morph on Social and Friends.

**Verification**
- These Ruby test files: bell items, bells controller, bell slot, read-only requests, player stream job, daily bonuses, goal rewards, invitations waiting, trades of, French typography. All green.
- `test/system/bell_test.rb`: 3 tests, green in three consecutive runs. The reload test fails without the `turbo:frame-render` binding.
- `npm run test:js`: 874 tests green.
- `format:check`, `lint:css`, `node script/pixel_art/export.mjs --check` (393 files up to date), `check_file_sizes`, `check_planning_references`, packwerk, `zeitwerk:check`, rubocop and `i18n-tasks missing` all pass.
- `bin/ci` passes with `PARALLEL_WORKERS=4` (4318 runs, 0 failures). Earlier runs failed for environmental reasons: shared Postgres shared memory, a concurrent run on the same database, and a scratchpad log overwritten by another lane. The one real failure among them was French colons missing U+202F, which is fixed.

**Residual risks**
- The seen set is per device. A line cleared on the phone still shows on the computer; entry 11 could move it server-side.
- Every signed-in page view makes one extra GET (deferred).
- The week's mission line counts as new once a week (queued for the author).

### Follow-up pass (2026-11-03)

- **Rebase:** the story was rebased onto 44b77e92 (stories 7 and 12) with no conflicts. The bell sits beside the reworked player chip, and `/me` (`own_profiles#show`, now a top-level screen) carries it; `bell_slot_test.rb` checks this. `baseline_revision` now points at that base.
- **Review:** 30 findings: high 0, medium 9, low 20, false 1.
- **Patches:**
  - a browser test for the lasting daily line (it stays on the capsule screen and leaves the count when collected);
  - the collect streams remove a lasting line only once its state has ended;
  - a page restored from the cache reloads its frame;
  - recomputing on teardown is guarded;
  - the flaky regex that checked keys for ids is removed;
  - `BellLine` separates `lasting` from `dom_id`;
  - a test for the bell policy;
  - the panel's accessible name.
- **Follow-up review recommended: false.** No high finding was patched in this pass.
- **Verification:**
  - the bell's Ruby files, the policy, daily bonuses, goal rewards, read-only requests, player stream and French typography tests: green;
  - `bell_test.rb` and `me_page_test.rb`: 12 runs green, and the new test fails when the lasting rule is removed;
  - vitest 847, format, CSS lint, pixel `--check`, file sizes, planning references, packwerk and zeitwerk: all pass;
  - `bin/ci` with `PARALLEL_WORKERS=4`.

## Code Review

### 2026-11-04 — 0 decision-needed, 0 patch, 4 defer, 3 rejected

- [x] [Review][Defer] The lasting-line removal streams are pinned only for the success case — deferred: add the failed-collect and other-reward negative assertions
- [x] [Review][Defer] Cache restore, morph and frame-missing reloads of the bell are asserted only as attribute strings — deferred: browser history system tests, run before release
- [x] [Review][Defer] A middle click marks nothing and a click on a failed navigation marks the line seen; bursts of signals reload the frame many times — deferred: minor, settle with the author
- [x] [Review][Defer] The counter never reaches zero while the daily or mission line stands — deferred: already an open question for the author

**Rejected**
- Wording, plural, fr key order, CSS tokens and dead classes: low.
- Extra GET per page on hidden phone drill-downs: already deferred by the build.
- Plan counts and one flaky shell test mentioned in the plan: process notes, edits the plan.
