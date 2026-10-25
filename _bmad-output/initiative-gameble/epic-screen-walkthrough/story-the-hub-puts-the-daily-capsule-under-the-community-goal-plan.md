---
title: 'The hub puts the daily capsule under the community goal'
type: 'feature'
ticket: '19'
created: '2026-10-25'
status: 'built'
baseline_revision: '9ec8aeb2f7bf1a6c773285d98ede884bb63f0144'
route: 'oneshot'
route_source: 'pinned'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** From 1180px the hub's community goal spans the kicker and menu rows of a grid shared with the left column, so the set progress panel under it starts only below the menu and a wide gap opens on the right (author, 2026-10-23, on staging).

**Approach:** Swap the two panels: from 1180px the right column holds the community goal then the daily capsule, stacked on their own so no shared row opens a gap, and the left column holds the kicker, the menu then "SETS EN COURS". From 720px (two columns) and on the phone the blocks stack community goal, daily capsule, then SETS EN COURS (author, 2026-10-24). EXPERIENCE.md's Hub content, the matching DESIGN.md lines, and the hub comments in `hub.css` and the views follow.

</intent-contract>

## Tasks & Acceptance

- Given a signed-in player at 1180px and wider, with or without a daily capsule, when the hub renders, then the right column shows the community goal then the daily capsule directly under it (one row gap, no more) and the left column shows the kicker, the menu then "SETS EN COURS" directly under the menu.
- Given 720 to 1179px, then the left column stacks kicker, menu, community goal, daily capsule, SETS EN COURS; given a phone, then kicker, showcase, community goal, daily capsule, SETS EN COURS.

## Implementation Notes

Oneshot: one stylesheet's grid areas, one wrapper in the hub view, and the docs that describe the layout; no logic or data changes.

- Swapping the grid areas alone would keep the gap: any right-column panel placed on rows shared with the left column waits for the menu's rows. The community goal and the daily panel are wrapped in `div.hub__aside` (no landmark), a flex column spanning every row from 1180px; under 1180px it is `display: contents`, so its two panels rejoin the two-column grid (areas goal, daily) and the phone's flex column in DOM order (kicker, showcase, goal, daily, sets), which is the approved order. Both Turbo Stream replacements target the panels by id (`daily-booster`, the goal's public part), so the wrapper changes nothing for them.
- Files: `app/frontend/styles/hub.css` (grid areas, `.hub__aside`, two-column order goal then daily, header comment), `app/views/pages/home.html.erb` (wrapper, comment), `app/views/pages/_daily_booster.html.erb` (comment), `test/system/hub_test.rb` (desktop test now asserts each column's stacking against the hub's row gap; new two-column test at 1000px; phone order includes the community goal), `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` (Hub content) and `DESIGN.md` (responsive table row, Daily capsule panel line), which described the old placement.
- Surprise: the worktree was cut from an older `develop` without this ticket; the branch was reset to `origin/develop` (9ec8aeb2) before any change. `npm install` rewrites `package-lock.json` (worktree name, libc fields); restored, not committed.
- `i18n-tasks health` exits 1 on a pre-existing inconsistent interpolation in `fr` `back_office.seasons.index.confirm.one`, untouched here; CI runs `i18n-tasks missing`, which passes.
- Verification (2026-10-25, Chromium 141, Postgres 16 on 5433): `test/system/hub_test.rb` 16 runs, 0 failures (the new desktop and two-column tests and the phone order with the community goal; screenshots checked: right column goal then daily, left column menu then sets, no gap); `daily_bonus_test`, `live_updates_test`, `countdown_test`, `shell_test`, `feed_test`, `bridge_cache_test` 50 runs, 0 failures; full suite (`PARALLEL_WORKERS=2 bin/rails test`) 3171 runs, 1 failure: `Catalog::SetBuilderTest` "15,000 rows build quickly" took 6.35s against its 5s budget under a load average of about 24 (nine builds share the machine), and passes run alone; untouched by this change. `npm run test:js` 561 passed; `npm run typecheck`, `bin/rubocop`, `bundle exec packwerk check`, `i18n-tasks missing`, `bin/rails zeitwerk:check`, brakeman: clean.

## Verification

**Commands:**
- `bin/rails test test/system/hub_test.rb test/system/daily_bonus_test.rb test/system/live_updates_test.rb test/system/countdown_test.rb test/system/shell_test.rb` -- expected: all pass
- `PARALLEL_WORKERS=2 bin/rails test`, `npm run test:js`, `bin/rubocop`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/i18n-tasks health` -- expected: all pass

## Auto Run Result

Status: built

- Summary: on the desktop hub the community goal and the daily capsule stack in a right-hand column of their own and SETS EN COURS sits directly under the menu, so no column opens a gap; from 720px the left column stacks kicker, menu, community goal, daily capsule, sets, and the phone stacks kicker, showcase, community goal, daily capsule, sets, as the author settled.
- Files: `app/frontend/styles/hub.css` (the grid areas, `.hub__aside`, the 720px and phone rules, the header comment), `app/views/pages/home.html.erb` (the aside wrapper), `app/views/pages/_daily_booster.html.erb` (comment), `test/system/hub_test.rb` (each column stacks with the plain gap, two columns at 1000px with and without a daily panel, the phone order), `ux-gameble/EXPERIENCE.md` and `DESIGN.md`.
- Review: the Quick lens ran from the coordinating session after the unattended run halted on `no subagents`. 4 findings: 3 patched (1 medium, 2 low), 1 rejected (low); nothing deferred.
- Follow-up review recommended: false (one medium patched).
- Verification: after the patches, `hub_test.rb`, `daily_bonus_test.rb` and `live_updates_test.rb` 32 runs, 0 failures on Chromium 141; the unattended run's full suite 3171 runs with one load-bound timing failure unrelated to this change (`set_builder_test.rb`, green alone), vitest 561, typecheck, rubocop, packwerk, i18n-tasks, zeitwerk, brakeman clean.
- Residual risks: the 720 to 899px band has no automated check; the author approves the orders on staging.
