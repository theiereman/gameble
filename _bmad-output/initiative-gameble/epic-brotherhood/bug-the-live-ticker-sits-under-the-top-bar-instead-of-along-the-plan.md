---
title: 'The LIVE ticker sits under the top bar instead of along the bottom of the hub'
type: 'bugfix'
ticket: '14'
created: '2026-10-09'
status: done
baseline_revision: '1c2c77e989f64c74103e4de74f6b8d3dd2da1dfa'
route: 'oneshot'
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

**Problem:** The hub fills the layout's ticker slot, which `app/views/layouts/application.html.erb` yields right under the top bar, so the LIVE ticker is a band between the top bar and the hub's columns. DESIGN.md ("a band on {colors.steam-bar} along the bottom of the hub"), EXPERIENCE.md ("Bottom: the LIVE ticker"; "Hub on the phone: … set progress rows, LIVE ticker") and the mockups (a `footer.ticker` after the hub's `main`) put it at the bottom.

**Approach:** The layout yields the ticker slot after `main` instead of before it, so the band follows the hub's columns: full width like the top bar (DESIGN: ticker backgrounds run full width), its 2px rule now on top, toward the content; with the body's sticky-footer column it rests on the window's bottom edge when the hub is shorter than the window. On the phone it is the last block of the page, after the set progress rows, and the tab bar's clearance moves from `main` to under the ticker so the fixed tab bar never covers it. The fixed version label rises above the band so it never sits on the LIVE marker. The ticker's markup, controller, stream, hover pause, reduced-motion stop and `aria-hidden` stay unchanged; no other screen fills the slot, so none gains or loses a ticker.

</intent-contract>

## Implementation Notes

Oneshot: about 80 lines across the layout, the hub's comment, `shell.css`, `tokens.css` and the tests that pin the ticker's position (`test/controllers/pages_controller_test.rb` L53 and L414, `test/integration/shell_test.rb` L191), plus a system test in `test/system/live_updates_test.rb` or `hub_test.rb` measuring positions at desktop and phone width (restoring the window size).

Placement chosen: the slot after `main` (a full-width band, the mockups' `footer.ticker`) rather than a grid row inside `.hub` (content-width, which DESIGN's "ticker backgrounds run full width" rules out).

- `app/views/layouts/application.html.erb` yields `:ticker` after `main`; `pages/home.html.erb` comment updated. The ticker partial, controller and streams are untouched.
- `shell.css`: the band's rule moves on top (`--ticker-rule` in `tokens.css`, the top bar's rule mirrored, as in the mockups); `body:has(> .ticker)` lifts the fixed version label (desktop and phone) and, from 720 px, the bottom-anchored toasts above the band — at 1280 px and below the version label sat exactly on the LIVE marker, and the welcome toast covered the band. On the phone the tab bar's clearance moves from `main` (`.main:has(+ .ticker)`) to the ticker's bottom margin.
- Surprise: the hub's two public stream sources now come in the order goal, live (the ticker's source moved after `main`); three tests compared that order (`pages_controller_test.rb`, `player_stream_tag_test.rb`) and were updated.
- Tests: `test/system/hub_test.rb` measures the band at 1400 px (under every column, full width, ending the page, version label and toasts above it) and at 390 px (after the set progress rows, resting on the tab bar at the end of the scroll); `test/integration/shell_test.rb` checks that only the hub carries a ticker (visitor and player screens).
- The dead `.ticker:focus-within` pause rule (nothing in the ticker is focusable) is left as it was: out of this ticket's scope.

## Plan Change Log

## Review Triage Log

### 2026-10-09 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` A new three-line comment above `.ticker` in `shell.css` explains the code's own layout, against the rule to comment only external constraints — fixed: comment removed.
  - `[low]` `[patch]` The layout's shell comment, rewrapped by this change, still opens with planning references ("AD-28; DESIGN.md, Chrome") — fixed: the references dropped from the rewritten block.

## Verification

**Commands:**
- `bin/rails test` -- expected: all green
- `bin/rails test test/system/live_updates_test.rb test/system/hub_test.rb test/system/shell_test.rb test/system/feed_test.rb` -- expected: green
- `npm run test:js && bin/rails zeitwerk:check && bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: clean

**Manual checks (if no CLI):**
- Hub screenshots at 1400 px and 390 px: the band under the columns (desktop, on the window's bottom edge when the hub is short) and after the set progress rows above the tab bar (phone); the version label not over the LIVE marker.

## Auto Run Result

**Summary.** The layout now yields the hub's ticker slot after `main`, so the LIVE ticker is a full-width band along the bottom of the hub: under its columns on a desktop (resting on the window's bottom edge when the hub is shorter than the window), and the last block after the set progress rows on the phone, resting on the tab bar at the end of the scroll. Its 2px rule now sits on top, toward the content. The fixed version label (desktop and phone) and the desktop toasts rise above the band; on the phone the tab bar's clearance moved from `main` to under the ticker. The ticker's markup, Stimulus controller, streams, hover pause, reduced-motion stop and `aria-hidden` are unchanged. No other screen gains or loses a ticker.

**Files.**
- `app/views/layouts/application.html.erb` — the ticker slot is yielded after `main`; the shell comment is updated.
- `app/views/pages/home.html.erb` — the comment names the band's place.
- `app/frontend/styles/tokens.css` — adds `--ticker-rule`, the top bar's rule mirrored.
- `app/frontend/styles/shell.css` — the rule on top; the version label and desktop toasts lifted above the band; on the phone, the tab bar clearance moved under the ticker.
- `test/system/hub_test.rb` — placement at 1400 px and 390 px.
- `test/integration/shell_test.rb` — only the hub carries a ticker, plus the new DOM order.
- `test/controllers/pages_controller_test.rb`, `test/integration/player_stream_tag_test.rb` — the new DOM order: ticker after main, goal stream before live.

**Review.** One quick pass found 2 low findings, both patched (an explanatory CSS comment, and the planning references in a rewritten comment block). Nothing was deferred and nothing was rejected.

**Follow-up review recommended:** false. Patched: 0 high, 0 medium, 2 low.

**Verification.**
- `bin/rails test`: 2046 runs, all green.
- System tests for hub, live_updates, shell and feed: 48 runs green, three times (once after the patches); the new hub tests passed in 6 runs.
- Full `bin/rails test:system`: 171 runs, 1 failure. The failure is `LiveUpdatesTest` "the swap after an acceptance plays out before…", on the trade board, which has no ticker. It passed 3 times out of 3 when rerun alone, so it is a timing flake under load.
- `npm run test:js`: 210 passed. `npm run typecheck`, `zeitwerk:check`, `packwerk check`, `rubocop` and `i18n-tasks missing`: all clean.

**Residual risks.**
- The phone and desktop rules rely on `:has()` (`body:has(> .ticker)`, `.main:has(+ .ticker)`). Browsers without it would leave the version label over the band and the phone ticker under the tab bar.
- On a long hub, the lifted version label and desktop toasts float above the band's height even while the band is scrolled out of view.
- The `.ticker:focus-within` pause rule is still in place, though it can never apply. It is out of scope here.

