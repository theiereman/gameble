---
title: 'The achievement tiles read cleanly and are not squashed'
type: 'feature'
ticket: '14'
created: '2026-11-02'
status: done
baseline_revision: '8564e2b87e61b408c44913cd285a4288ddc4f887'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Achievements tiles are squashed: an uppercase title over two lines, the condition and the unlocked back all packed in one small tile.

**Approach:** One row per achievement (mockup option B): glyph, title in the title font with the condition beneath, the earned or unlockable back and the progress on the right, below the text on a phone.

</intent-contract>

## Implementation Notes

Oneshot: a view and stylesheet change with one system test. The tile partial is split into a text block and a side block; the list is a single column; the title uses the VT323 card-title token in normal case with balanced wrapping; the toast message wraps at word boundaries. The landing tile uses generic example labels, not the achievement titles, so it needed no change.

## Plan Change Log

## Review Triage Log

### 2026-11-02 - Review pass
- findings:
  - `[medium]` `patch` empty side block kept a dead column (`:empty` never matched) - the side block now renders only when there is a back or a progress.
  - `[low]` `patch` unrequested back colour and toast wrap changes - back colour restored; the toast keeps `anywhere` and only gains balanced wrapping.
  - `[medium]` `patch` flaky layout test without restore or retry - rewritten with a synchronizing placement check (the suite teardown restores the window).
  - `[low]` `reject` progress bar width varies with text - the count block has a fixed minimum width, cosmetic.

## Auto Run Result

Rows replace tiles on the Achievements page. Files: achievements `_tile` view and stylesheet, toast message wrapping, achievements system test. Verification: format check, CSS lint and rubocop clean; system tests not run (instructed). Risk: layout only seen in CSS, not in a browser.

## Verification

**Commands:**
- `npm run format:check`, `npm run lint:css`, rubocop on the test -- expected: clean
