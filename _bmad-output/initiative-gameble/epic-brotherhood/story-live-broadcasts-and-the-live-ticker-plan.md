---
title: 'Live broadcasts and the LIVE ticker'
type: 'feature'
ticket: '4'
created: '2026-10-08'
status: done
baseline_revision: '3da25457dc7f6391b95fb8f1c9100eff137b4b6a'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: true
context: ['{project-root}/AGENTS.md', '{project-root}/_bmad-output/initiative-gameble/epic-brotherhood/epic-brotherhood.md']
warnings: ['oversized']
deferred:
  - summary: >-
      The LIVE ticker cannot pause on keyboard focus: it is hidden from assistive technology and holds nothing focusable.
    evidence: |-
      EXPERIENCE.md asks the ticker to pause on hover and focus and to be hidden from assistive technology; the `.ticker:focus-within` pause rule in shell.css can never apply, and a keyboard user stops the motion only through "Animations réduites". Settling it needs the author's choice between a focusable pause control and the reduced-motion setting as the only way.
    location: >-
      app/views/shell/_ticker.html.erb
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Nothing on gameble moves without a reload: the hub's community gauge only changes on refresh, new feed entries appear only on revisit, the layout's ticker slot is empty and the public card page's LIVE strip shows three empty rows.

**Approach:** Two public, per-locale Turbo streams (no ids, no player data beyond what the public feed already shows) fed by jobs, never inside a transaction: (1) the gauge — a web-layer recurring job about every 10 seconds re-renders the community goal panel (it holds no per-player figure) and replaces it on every hub; (2) the feed — a web-layer event handler, like `PlayerStream`, collects the openings and reposts of a transaction and enqueues one job after commit, which renders the new notable entries of public, non-banned players and prepends them to the feed's All view, adds the allowed kinds to the LIVE ticker and refreshes the public card page's LIVE strip. The LIVE ticker fills the layout's ticker slot on the hub: a Space Mono line scrolling right to left behind the LIVE marker, items separated by "◆", rarity names in their colour, pulls of Épique or better, first discoveries and trades only, never reposts; new items join at the loop boundary; it pauses on hover and focus, stops still under "Animations réduites" (or the system preference), and is hidden from assistive technology. On the feed, a polite status line announces new entries in batches at most every 30 seconds while the feed is not focused, silent under reduced motion.

## Boundaries & Constraints

**Always:** broadcasts only from jobs, enqueued after commit (`enqueue_after_transaction_commit` is on); stream names carry no database id (fixed public names such as `live:<locale>`); only entries `Game::Visibility.visible?(nil, player)` allows are broadcast (a hidden or banned player's entry never leaves); each locale rendered once per batch; every string in `en.yml` and `fr.yml`; no `style` attribute in server HTML (positions and durations through classes or CSS custom properties set by JS); continuous motion on transforms only; every looping or blinking effect gets both reduced-motion rules (`@media (prefers-reduced-motion: reduce)` and `html[data-motion="reduced"]`); a GET writes nothing; new `gameble:*` events declared in `app/frontend/lib/events.ts`.

**Never:** reposts or filler entries in the ticker; live updates of the feed's Friends tab or a filtered view (they stay read at render); a broadcast inside an open transaction; per-player data on the public streams; the ticker exposed to assistive technology; blinking faster than once a second; a change to how the goal is summed or rewarded; planning ids in code or tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Gauge tick | goal total changed by an opening | within ~10 s every open hub's goal panel shows the new figures and segments, in its own locale, no reload | — |
| Feed entry live | a public player opens a pack with an Épique | after commit one job; open feeds (All, no filter) get the entry at the top, the ticker gets it at its next loop, the public card page's strip shows the three latest | — |
| Private/banned player | entry by a hidden owner | nothing broadcast | — |
| Repost | a repost committed | prepended to the feed's All view; not in the ticker | — |
| Filler only | a pack of commons | filler is not broadcast to the ticker; the feed's All view gets it only if the rendered feed would show it — keep it simple: fillers are not broadcast | — |
| Rolled back | opening fails | nothing enqueued | — |
| Reduced motion | `data-motion="reduced"` or system pref | ticker still, latest items shown; LIVE dot lit, not blinking; no feed announcements | — |
| Hover / focus | pointer over or focus inside the ticker | scrolling pauses; resumes after | — |
| Feed announcement | 3 entries arrive within 30 s, feed list not focused | one polite message ("3 nouvelles entrées dans le fil." / "3 new entries in the feed."), at most every 30 s | — |

</intent-contract>

## Code Map

- `app/models/player_stream.rb` -- the pattern to copy: a handler subscribed in `config/initializers/event_store.rb` (L12, L26) that `collect`s per transaction (`ApplicationRecord.current_transaction`, `after_commit` enqueue, `after_rollback` drop) and `app/jobs/player_stream_job.rb` rendering a turbo-stream partial per locale with `ApplicationController.render(partial:, formats: [:turbo_stream], locals:)` then `Turbo::StreamsChannel.broadcast_stream_to`. Add a `LiveStream` (web layer) subscribed to `Game::PackOpened` and `Game::CardReposted`, and a `LiveFeedJob`.
- `app/channels/player_stream_channel.rb`, `app/helpers/shell_helper.rb#player_stream_tag` -- the private stream; the public ones use plain `turbo_stream_from "live", I18n.locale` (signed names, default channel) for visitors and players.
- `packs/game/app/models/game/feed_entry.rb` -- `record_pack` uses `insert_all` (no records returned), `NOTABLE_TIER = 4`, `KINDS`; the job loads entries by the event's pack id (or player and repost time) with `notable: true`.
- `packs/game/app/queries/game/feed_entries.rb` -- `call(viewer, kind:, players:)`; use `call(nil)` minus reposts and fillers for the ticker's initial items, and the first three for the public card page strip.
- `packs/game/app/queries/game/current_goal.rb`, `app/views/pages/_goal.html.erb` (`id: "community-goal"`, no per-player figure), `packs/game/app/jobs/game/sum_weekly_goal_job.rb`, `config/recurring.yml` L19-38 (`sum_weekly_goal` every 10 s in development and production) -- add a web-layer `LiveGoalJob` scheduled the same way, broadcasting `turbo_stream.replace "community-goal"` per locale; the hub subscribes with `turbo_stream_from`.
- `app/views/feeds/show.html.erb` L46-71 -- entry markup inline inside `ul.feed__list` (no id): extract `feeds/_entry.html.erb` (used by the page and the job), give the All view's list an id (e.g. `feed-entries`) and subscribe only there (no `tab`, no `filter`).
- `app/views/layouts/application.html.erb` L17 (`yield :ticker`), `app/frontend/styles/tokens.css` L153-154 (`--space-ticker-height` 32px / phone 30px), `card-detail.css` L762-797 & L859-874 (`.live-marker`, `.live-marker__dot`, the public strip, their reduced-motion rules — move the marker to `shell.css` when the ticker reuses it).
- `app/views/pages/home.html.erb` -- `content_for :ticker` with a `shell/_ticker.html.erb` (LIVE marker + `aria-hidden` list), and the goal panel subscription.
- `app/views/cards/_public.html.erb` L50-61 -- the LIVE strip: render the three latest entries (compact entry) and give the list an id the job replaces.
- `app/frontend/lib/motion.ts` (`motionReduced()`, `onMotionChange`) -- the ticker and the feed announcer read it. `app/frontend/lib/events.ts`, `app/frontend/lib/stream_actions.ts` (`STREAM_SIGNALS`) -- only if a signal is needed.
- New Stimulus controllers (`app/frontend/controllers/`): `ticker_controller.ts` (duplicated track for a seamless loop, CSS keyframes on `transform`, items arriving through the stream are queued and joined on `animationiteration`, pause through CSS `:hover`/`:focus-within`, still under reduced motion) and `feed_announcer_controller.ts` (counts `turbo:before-stream-render` targeting the feed list, announces in a `role="status"` line at most every 30 s while focus is not inside the list, off under reduced motion), with vitest for their pure parts (`lib/ticker.ts`, `lib/announce_batch.ts`).
- DESIGN (read-only): ticker band on `{colors.steam-bar}` #171a21, 32 px (phone 30), LIVE marker on the left, Space Mono line, items separated by a pixel "◆", rarity names in their colour, no rarity icon; LIVE marker blinks once per second, the only blinking element.
- Tests: `test/models/player_stream_test.rb` L74-102 (`ActionCable::TestHelper`, `assert_no_broadcasts` inside a transaction, `assert_broadcasts` after commit, rollback) as the model for `test/models/live_stream_test.rb`; `test/system/live_updates_test.rb` (`using_session`, `perform_enqueued_jobs(only:)`, `listening`, `not_reloaded?`) for a two-browser test; `test/packs/game/weekly_goal_test.rb`, `test/controllers/pages_controller_test.rb` L323-370 (goal panel), `test/support/game_packs.rb` (`create_pack`, `fixture_tier_ids`, `Game::OpenPack.new.call(player:).value!`).

## Tasks & Acceptance

**Execution:**
- [x] `app/models/live_stream.rb`, `app/jobs/live_feed_job.rb`, `app/views/live_streams/_feed.turbo_stream.erb` (or equivalent), `config/initializers/event_store.rb` -- per-transaction collection, after-commit job, public visible entries only, per-locale render: prepend to the feed list, push ticker items (no reposts, no fillers), replace the public strip.
- [x] `app/jobs/live_goal_job.rb`, `config/recurring.yml` -- the goal panel replaced on the public stream about every 10 s, per locale.
- [x] `app/views/feeds/_entry.html.erb`, `feeds/show.html.erb` -- extracted entry, list id and subscription on the All view only, the status line.
- [x] `app/views/shell/_ticker.html.erb`, `pages/home.html.erb`, `shell.css` (ticker + LIVE marker), `card-detail.css` (marker moved) -- the ticker in the hub's slot with initial items.
- [x] `app/views/cards/_public.html.erb` (+ `cards_controller.rb` reading the three latest entries) -- the LIVE strip filled and live.
- [x] `ticker_controller.ts`, `feed_announcer_controller.ts`, `lib/ticker.ts`, `lib/announce_batch.ts` (+ vitest) -- loop boundary joins, pause, reduced motion, batched announcements.
- [x] `config/locales/en.yml`, `fr.yml` -- ticker item words (reuse the feed's sentences where they fit), the announcement ("%{count} nouvelles entrées dans le fil." with `zero`/`one`/`other` in French), any new label.
- [x] Tests -- `test/models/live_stream_test.rb` (no broadcast inside a transaction, one job after commit, nothing on rollback, a private or banned owner's entry not broadcast, repost not in ticker items), job tests (rendered per locale, goal panel replaced), controller tests (hub has the ticker with allowed kinds only and the goal subscription; feed All view subscribes, a filtered view or Friends tab does not; the public card page shows three entries), system: two browsers — an opening moves the gauge and adds a feed entry without a reload; the ticker pauses on hover and is still under reduced motion (assert the animation state with retrying matchers).

**Acceptance Criteria:**
- Given two browsers on the hub and the feed, when a public player opens a pack with an Épique, then without a reload the other browser's gauge moves (after the next tick) and the feed shows the entry at the top.
- Given the hub, when the ticker renders, then it shows only pulls of Épique or better, first discoveries and trades — never a repost — pauses under the pointer and stands still under "Animations réduites".
- Given an opening that rolls back, then nothing is broadcast; given any opening, no broadcast is sent inside its transaction.
- Given a visitor on a public card page, then the LIVE strip shows the three latest public entries.

## Implementation Notes

- Streams: `live:<locale>` (feed entries, ticker queue, public strip; `LiveFeedJob`) and `goal:<locale>` (goal panel; `LiveGoalJob`, `broadcast_goal` in `config/recurring.yml`, every 10 s in development and production). Default `Turbo::StreamsChannel`, signed names, no id.
- The per-transaction collection of `PlayerStream` moved into `AfterCommitBatch` (app/models), shared by `PlayerStream` and `LiveStream`; `PlayerStream::BATCHES` keeps its key.
- New pack query `Game::NewFeedEntries` (by pack ids, or a repost's player, card and event timestamp; notable only; `Visibility.visible?(nil, …)`), and `FeedItems` (web layer) pairing entries with card views, now also used by `FeedsController`.
- The ticker reads `Game::FeedEntries.call(nil, kind: LiveStream::TICKER_KINDS)` (a list of kinds gets no filler); the strip reads `Game::FeedEntries.call(nil).first(3)`. Hub queries +1, public card page +2 (test counts updated).
- The ticker sits in the existing layout slot, under the top bar (DESIGN/EXPERIENCE place it at the bottom of the hub; the slot was kept as the plan names it). It is `data-turbo-permanent` so the hub's morph refresh keeps its loop and queue.
- Trade entries have no writer yet; the feed renders them with the pull sentence, and the ticker and strip do the same through the shared `FeedHelper#feed_sentence`.
- `cards.show.live.marker` moved to `shell.live.marker` (shared `shell/_live_marker` partial).

## Plan Change Log

## Review Triage Log

### 2026-10-08 — Review pass
- verdicts: 7 findings — high 0, medium 3, low 4, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Arrivals beyond the ticker's size stayed in the hidden queue and came back later as new, out of order — fixed: `join()` empties the queue; vitest and the system test check it.
  - `[medium]` `[patch]` Joining at the loop boundary put the arrivals at the start of the run, the part on screen, so the line jumped — fixed: `joinQueued` keeps the items in view first (`keep` from `itemsInView`), inserts the arrivals after them and drops the oldest from the end; vitest and system test.
  - `[medium]` `[defer]` "Pauses on focus" cannot happen: the ticker is hidden from assistive technology and holds nothing focusable, so a keyboard user can stop it only through "Animations réduites" — the two design rules conflict (focusable content under `aria-hidden` is itself an accessibility fault); left for the author.
  - `[low]` `[reject]` An entry can show twice when a page renders between the commit and the job — the window is the job's latency and a reload clears it; deduplicating needs a stable DOM key for an entry without exposing its id.
  - `[low]` `[patch]` The live All list grew without limit — fixed: after a stream render the feed keeps `Game::FeedEntries::LIMIT` entries; vitest and a system test.
  - `[low]` `[patch]` Explanatory comments (announce_batch.ts, shell.css, live_updates_test.rb) — fixed: removed.
  - `[low]` `[patch]` A French section heading in card-detail.css — fixed: English.


## Verification

All Ruby commands need Ruby 4.0.7 from rbenv: prefix them with `export PATH=/opt/rbenv/shims:$PATH && `; system tests also need `CHROME_BIN=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/chrome.sh SE_CHROMEDRIVER=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/cd/chromedriver`. Never run `npm install`.

**Commands:**
- `bin/rails test` -- expected: all green
- `bin/rails test test/system/live_updates_test.rb test/system/hub_test.rb test/system/feed_test.rb test/system/card_preview_test.rb test/system/share_card_test.rb` (system env above), 3× -- expected: green
- `npm run test:js && npm run typecheck` -- expected: pass
- `bin/rubocop && bundle exec packwerk check && bin/rails zeitwerk:check && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

**Summary.** Two public per-locale Turbo streams fed by jobs after commit: `LiveStream` collects each transaction's openings and reposts and enqueues one `LiveFeedJob`, which renders the new entries of publicly visible players once per locale (prepended to the feed's All view, queued on the hub's LIVE ticker — no reposts, no fillers — and the public card page's strip refreshed); a recurring `LiveGoalJob` replaces the hub's goal panel about every 10 s. The hub's ticker fills the layout slot: a looping line on transforms, items joining at the loop boundary, paused under the pointer, still under reduced motion, hidden from assistive technology. The feed announces new entries in batches at most every 30 s and keeps 30 rows.

**Files.**
- `app/models/live_stream.rb`, `app/models/after_commit_batch.rb` (shared with `PlayerStream`), `app/jobs/live_feed_job.rb`, `app/jobs/live_goal_job.rb`, `app/views/live_streams/*`, `config/initializers/event_store.rb`, `config/recurring.yml`.
- `packs/game/app/queries/game/new_feed_entries.rb`, `app/models/feed_items.rb`, `app/helpers/feed_helper.rb`, `app/controllers/feeds_controller.rb`.
- `app/views/feeds/_entry.html.erb`, `feeds/show.html.erb`, `shell/_ticker*.html.erb`, `shell/_live_marker.html.erb`, `pages/home.html.erb`, `cards/_public.html.erb`, `cards_controller.rb`.
- `app/frontend/controllers/ticker_controller.ts`, `feed_announcer_controller.ts`, `lib/ticker.ts`, `lib/announce_batch.ts`, styles (`shell.css`, `card-detail.css`, `feed.css`).
- Locales and tests (models, jobs, controllers, system live updates).

**Review.** One quick pass: 2 medium + 3 low patched, 1 medium deferred (ticker focus pause vs. hidden from assistive technology), 1 low rejected (a transient duplicate between commit and job).

**Follow-up review recommended:** true — two medium findings were patched in the ticker's loop-boundary join; its window measurement (`itemsInView`) and the order kept at the boundary are only checked by vitest and one system test at the default width.

**Verification.** `bin/rails test` 1812 runs green; vitest 210, typecheck, rubocop, packwerk, zeitwerk, i18n-tasks clean; system live_updates, hub, feed, card_preview, share_card, shell, settings: 65 runs green.

**Residual risks.**
- Ticker placement follows the layout slot under the top bar; DESIGN.md describes it along the bottom of the hub.
- `LiveGoalJob` broadcasts every 10 s even when nothing changed.
- A friends-only player's entries are never broadcast live (friends see them on reload).
- Trade entries (not written yet) will reuse the pull sentence.
