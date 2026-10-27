---
title: 'trades.css, settings.css and profile.css are cut under 500 lines'
type: 'refactor'
ticket: '24'
created: '2026-10-27'
status: 'built'
baseline_revision: '8893d6e8'
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

**Problem:** trades.css (1,066 lines), settings.css (683) and profile.css (599) are over the 500-line limit, and tokens.css and application.css still carry planning references.

**Approach:** Split each at top-level rule boundaries into files under 500 lines imported in the same cascade order, drop the section-divider comments, and rewrite the comments that name planning documents.

</intent-contract>

## Implementation Notes

Oneshot: a mechanical split. trades.css became trades, trades-board, trades-picker, trades-responsive, trades-result (73 to 409 lines); settings.css became settings, settings-pages, settings-summary (82 to 288); profile.css became profile and profile-responsive (153 and 431). Only the 8 divider comments were dropped. Planning references removed from settings.css, tokens.css and application.css; those left in shell.css and booster.css belong to other tickets.

## Plan Change Log

## Review Triage Log

### 2026-10-27 — Review pass
- A cascade-equality check is the review of a mechanical split: script/compare_css_cascade reports no difference against origin/develop; the comment count diff shows only the 8 divider comments gone. No subagent lenses were run.

## Verification

- `script/compare_css_cascade origin/develop` -- identical
- `script/check_file_sizes` on the new files -- clean
- trades, trade_board, settings and public_profile system tests -- 13, 5, 13 and 3 runs, 0 failures

## Auto Run Result

Cut as described; cascade identical, system tests green.
