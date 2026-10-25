---
title: "The feed's tabs and filters are designed as one control"
type: 'feature'
ticket: 31
created: '2026-10-25'
status: 'blocked'
baseline_revision: '9ec8aeb2f7bf1a6c773285d98ede884bb63f0144'
route: 'oneshot'
route_source: 'pinned'
review: 'quick'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** On the activity feed the TOUS / AMIS tabs and the kind filters (TOUT, TIRAGES, DÉCOUVERTES, ÉCHANGES, REPOSTS) sit as two unrelated segmented rows, with no hierarchy between scope and kind and no tie to the list below (author, staging, 2026-10-23).

**Approach:** As the author settled (2026-10-24), the scope and the kinds become one zone: one line of chips drawn like the catalog's FILTRES chips (control-bordered plates spaced apart, the chosen one filled with accent, with a check mark and the deep base), TOUS and AMIS first, set apart from the kinds by a divider, the zone's left edge on the list's. The line never wraps into a wall of chips: when it does not fit (the phone), it scrolls sideways inside its own zone, the page never does. A visitor's AMIS is the same chip greyed and disabled. The two navigation landmarks, their names, the links, the keyboard order and the accessible names stay as they are (the check mark is decoration with empty alternative text). EXPERIENCE.md's feed tabs row and DESIGN.md's tabs/filters and feed tabs lines follow. The feed entry's own redesign is another ticket.

</intent-contract>

## Implementation Notes

Oneshot (pinned): one view, one stylesheet, the shared chip rules and their tests, no data or behaviour change.

- The worktree was cut 282 commits behind `origin/develop` (ticket 16.31 absent); the empty build branch was moved to `origin/develop` (9ec8aeb2) before planning. `tickets.py find` needs the folder `_bmad-output/initiative-gameble` here (no `config.user.toml` in the worktree).
- `app/views/feeds/show.html.erb`: the two navs (same classes `feed__tabs` / `feed__filters`, same `aria-label`s, same links and order) now sit in one `.feed__controls` zone; every tab and filter is a `filter-chip` link wrapping a `filter-chip__text` plate (`FeedHelper#feed_chip_link`); a visitor's AMIS is a disabled `button.filter-chip`. The `segmented` classes are gone from the feed.
- `app/frontend/styles/collection.css` (shared chip rules): a link or button can be a `.filter-chip`; `[aria-current="true"]` draws as a checked chip (accent, deep base, "✓"), the mark given empty alternative text (`content: "\2713" / ""`, after a plain fallback) so a link's accessible name stays "Tous"; a disabled chip is greyed with a not-allowed cursor. The catalog's checkbox chips are unchanged.
- `app/frontend/styles/feed.css`: `.feed__controls` is one flex line that never wraps and scrolls sideways inside itself (`overflow-x: auto`) when too long; padding + equal negative margin of the focus ring's reach keeps focus rings unclipped and the first chip on the list's left edge. The divider is a 2px inset `line-deep` edge on the kinds nav. Phone: chips 44px tall (catalog's existing touch rule) and 8px apart.
- Docs: DESIGN.md (Tabs and filters; Activity feed "Feed tabs and filters") and EXPERIENCE.md (Feed tabs row) describe the zone.
- Tests: controller test for the zone's structure and the visitor's disabled chip; system tests for one line + tabs before filters + left alignment + accessible names on desktop (French), and one scrolling line, no page sideways scroll, last chip reachable on a 390px phone.
- Choice the author should check on staging: on the phone the line scrolls sideways within its zone rather than wrapping onto two or three lines (the reading of "reachable without a wall of chips" that keeps the settled "same line").

## Verification

**Commands:**
- `bin/rails test test/controllers/feeds_controller_test.rb` -- expected: green
- `bin/rails test test/system/feed_test.rb test/system/landing_live_feed_test.rb` -- expected: green
- `bin/rails test test/system/library_test.rb test/system/collection_set_test.rb` (the shared chip rules) -- expected: green
- `PARALLEL_WORKERS=2 bin/rails test`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec packwerk check`, `bin/brakeman` -- expected: green

**Results (2026-10-25, Postgres 16, Chromium 141):**
- feeds controller test: 40 runs, 0 failures.
- feed + landing live feed system tests: 12 runs, 0 failures (after the accessible-name check was made case-insensitive: Chromium names the chip "TOUS" through its text-transform, as before the change; the point checked is that no "✓" enters it).
- library + collection set system tests: 9 runs, 0 failures.
- Full suite, `PARALLEL_WORKERS=2`: first run 3172 runs, 1 failure whose details were lost to a truncated log on a host at load ~28 shared by nine builds; rerun with the full log: 3172 runs, 33372 assertions, 0 failures, 0 errors.
- vitest 53 files / 561 tests passed; tsc clean; zeitwerk all good; rubocop 943 files, no offenses; i18n-tasks no missing keys; packwerk no violations; brakeman no warnings; whitespace check clean.
- Built CSS keeps `content:"✓" / ""` after the plain `content:"✓"` fallback.
- Screenshots (throwaway test, deleted): desktop visitor FR (TOUS current, AMIS greyed, divider, TIRAGES current), phone visitor FR (one line scrolling inside its zone), desktop player EN (FRIENDS · TRADES current, focus ring unclipped).

**Manual checks (if no CLI):**
- The author checks the zone on staging: desktop and phone, French and English, player and visitor.

## Auto Run Result

Status: blocked
Blocking condition: no subagents

- Implemented, verified and committed on `build/16.31-feed-filters-one-control` (e5aeb1b717c2736a4e59b5c3288e7aa3e5a736cd), from baseline 9ec8aeb2f7bf1a6c773285d98ede884bb63f0144.
- Halted at step 4: the Quick review lens needs a subagent and this session has no subagent tool; no lens ran (`lenses_ran` empty). The coordinator runs the review on the diff since the baseline.
- `tickets.py mark` was not run (refused on this store; `gh` unauthenticated); the status is set in this frontmatter instead.
- hitl: the author checks the zone on staging, in particular the phone's sideways-scrolling line.
