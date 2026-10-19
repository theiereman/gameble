---
title: 'The LIVE ticker spans the whole window and its blinking square is red'
type: 'bugfix'
ticket: '15'
created: '2026-10-19'
status: 'built'
baseline_revision: '32fee1d122754f42610d4e35418a8912af0ef370'
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

**Problem:** On a desktop wider than the content width, the ticker's band runs full width but `.ticker__inner` caps its LIVE marker and scrolling line at `--space-content-max` with the desktop gutter, and the marker's blinking square is the dark `--color-on-accent`. The author (2026-10-12) wants the marker against the window's left edge, the scrolling line reaching its right edge, and the ticker's blinking square red.

**Approach:** From 720 px up, `.ticker__inner` drops its width cap, centring and gutter, so the marker sits on the window's left edge and `.ticker__window` runs to its right edge; the phone rule keeps its own cap, centring and gutter, so the phone ticker is unchanged. DESIGN.md and `tokens.css` gain a `live-red` colour (`#b3001b`, 3.5:1 on `{colors.accent}`, past the 3:1 a non-text mark needs), used only by the ticker's `.live-marker__dot`; the feed's marker keeps its dark square. DESIGN.md's LIVE marker, LIVE ticker and Width rules say so. Blink timing and the reduced-motion stop are untouched.

</intent-contract>

## Implementation Notes

Oneshot: about 40 lines across `app/frontend/styles/shell.css` (`.ticker__inner` desktop and phone rules, a `.ticker .live-marker__dot` colour), `app/frontend/styles/tokens.css` (`--color-live-red`), DESIGN.md (frontmatter colour, ticker component, prose) and the hub's system tests, which gain the marker/window edge and dot-colour assertions for when system tests run again. System tests are disabled, so the layout and colours are checked in a headless Chrome at 1400 and 390 px against a test-env server instead.

- `shell.css`: `.ticker__inner` keeps only `display: flex` and its height from 720 px; the phone rule now carries `margin: 0 auto` with its existing cap and gutter, so the phone ticker computes as before. `.ticker .live-marker__dot` takes `--color-live-red`; the reduced-motion rules still stop its animation (they set `animation`, not the colour).
- `tokens.css`: `--color-live-red: #b3001b` beside `--color-on-accent`.
- DESIGN.md: `colors.live-red`, `components.ticker.live-square`, a "Live red" colour rule, the Width rule (ticker contents run full width from 720 px), the LIVE marker (dark square except in the ticker) and the LIVE ticker component.
- `test/system/hub_test.rb`: the desktop test also checks the marker at x = 0, the scrolling window's right edge on the viewport's and the red square; the phone test checks the marker keeps the 20 px gutter and the red square.
- Surprise: no feed screen renders `shell/live_marker`; besides the ticker, only the public card page's LIVE strip does (`app/views/cards/_public.html.erb`). That marker is the one checked to keep its dark square.
- Headless check (Chrome, CDP viewport override, `RAILS_ENV=test` server on fixtures): at 1400 px, marker left 0, `.ticker__window` right 1400 = viewport, ticker dot `rgb(179, 0, 27)`, public card dot `rgb(11, 21, 32)`; at 1000 px (scrollbar) marker 0, window right 985 = clientWidth; at 390 px (clientWidth 375) inner 0–375, marker left 20 as before, dot red; with `prefers-reduced-motion` both dots compute `animation-name: none`. No sideways scroll at any width.

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `package-lock.json` renamed the package after the worktree folder, a stray `npm install`/`bin/setup` change outside the plan — fixed: the file is restored from the index and not committed.

## Verification

**Commands:**
- `bin/rails test` -- expected: all green
- `npm run test:js && npm run typecheck && bin/rails zeitwerk:check && bundle exec packwerk check && bin/ci` -- expected: clean

**Manual checks (if no CLI):**
- Headless Chrome on the hub at 1400 px: the LIVE marker's left is 0, `.ticker__window`'s right equals the viewport width, the ticker's `.live-marker__dot` computes to `rgb(179, 0, 27)`, the feed's `.live-marker__dot` to `rgb(11, 21, 32)`. At 390 px: `.ticker__inner` keeps the phone gutter (marker left = 20 px, as before) and the dot is red. With reduced motion the dot's animation is none.

## Auto Run Result

**Summary.** From 720 px up, the LIVE ticker's contents run the whole window: the LIVE marker sits on the window's left edge and the scrolling line reaches its right edge (`.ticker__inner` lost its content-width cap, centring and gutter; the phone rule keeps its own, so the phone ticker is unchanged). The ticker's blinking square is the new `live-red` (`#b3001b`, 3.5:1 on the accent fill); the other LIVE marker (the public card page's LIVE strip) keeps its dark square. DESIGN.md gains the colour token, the ticker component's `live-square`, a "Live red" rule, and updated Width, LIVE marker and LIVE ticker rules.

**Files.**
- `app/frontend/styles/shell.css` — `.ticker__inner` uncapped from 720 px; phone rule keeps cap, centring and gutter; the ticker's dot is red.
- `app/frontend/styles/tokens.css` — `--color-live-red`.
- `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md` — token and rules.
- `test/system/hub_test.rb` — marker and window edges, gutter on the phone, the square's colour.

**Review.** One quick pass, 1 low finding patched (stray `package-lock.json` change reverted). Nothing deferred or rejected.

**Follow-up review recommended:** false. Patched: 0 high, 0 medium, 1 low.

**Verification.**
- `bin/ci` (through the shared slot): green, `bin/rails test` 2826 runs, 0 failures.
- `npm run test:js` 467 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`: clean.
- System tests not run (disabled in this repo); the new hub system-test assertions were checked by hand in headless Chrome at 1400, 1000 and 390 px and with reduced motion (see Implementation Notes).

**Residual risks.**
- Between 720 px and the content width the marker also leaves the gutter and sits on the window's edge; the author's wording named desktops wider than the content width.
- The new hub system-test assertions have not run under Capybara.

