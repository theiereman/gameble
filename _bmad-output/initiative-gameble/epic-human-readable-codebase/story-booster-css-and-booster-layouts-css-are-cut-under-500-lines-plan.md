---
title: 'booster.css and booster-layouts.css are cut under 500 lines'
type: 'refactor'
ticket: '22'
created: '2026-10-27'
status: 'built'
baseline_revision: '0db736ce'
route: 'oneshot'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** booster.css (1,595 lines) and booster-layouts.css (791) are over the 500-line limit.

**Approach:** Split each at top-level rule boundaries into files under 500 lines imported in the same cascade order; keep section comments, update the header comments, add the new files to the vitest css include list and to the two tests that read the stylesheets as raw text.

</intent-contract>

## Implementation Notes

Oneshot: a mechanical split. booster.css became booster (424), booster-canister (441), booster-effects (348), booster-celebration (383); booster-layouts.css became booster-layouts (446) and booster-layouts-tray (345). The two planning references left in booster.css (a design document name, a decision id) were removed. card-rarity-effects.test.ts and glitter.test.ts now concatenate the parts.

## Plan Change Log

## Review Triage Log

### 2026-10-27 — Review pass
- A cascade-equality check is the review of a mechanical split. No subagent lenses were run: the build ran inside a subagent that could not launch further ones.

## Verification

- `script/compare_css_cascade` -- identical
- `script/check_file_sizes` -- clean
- `npm run test:js` -- 71 files, 723 tests passed
- booster_test 43 runs and booster_screen_test 8 runs, 0 failures

## Auto Run Result

Cut as described; cascade identical, tests green.
