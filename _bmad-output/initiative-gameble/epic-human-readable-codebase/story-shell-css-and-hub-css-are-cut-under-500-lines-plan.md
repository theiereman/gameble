---
title: 'shell.css and hub.css are cut under 500 lines'
type: 'refactor'
ticket: '21'
created: '2026-10-27'
status: 'built'
baseline_revision: '8893d6e8'
route: 'oneshot'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [self-review]
review_loop_iteration: 0
followup_review_recommended: false
warnings: []
---

<intent-contract>

## Intent

**Problem:** shell.css (1,615 lines) and hub.css (955 lines) are over the 500-line limit.

**Approach:** Split each at top-level section boundaries into files imported in the same cascade order, proving the cascade unchanged with script/compare_css_cascade.

</intent-contract>

## Implementation Notes

Pure line slices, so rule order is untouched. shell.css (200) keeps base, focus ring, atmosphere and page widths; shell-top-bar.css (398), shell-status.css (367: LIVE marker, tab bar, version, toasts), shell-controls.css (284: buttons, panels, modal), shell-screens.css (366: transitions, breakpoints, reduced motion, back-office). hub.css (338) keeps kicker, menu and showcase; hub-daily-sets.css (409), hub-responsive.css (88), hub-goal.css (120).
Planning ids (AD-27, DESIGN.md, EXPERIENCE.md) dropped from the comments; the shell header now states the cascade-order constraint instead of "kept whole".
Two vitest files read shell.css raw (wordmark_shine, collection-grid): they now join the five shell files in cascade order. vitest.config.ts lists the new files, since vitest empties unlisted raw stylesheets.

## Verification

- `script/compare_css_cascade origin/develop` -- Cascade identical
- `script/check_file_sizes` -- no shell or hub file listed
- `npm run test:js` -- 722 passed
- shell_test.rb 23 runs, hub_test.rb 16 runs -- 0 failures

## Auto Run Result

Built as above; all verification green.
