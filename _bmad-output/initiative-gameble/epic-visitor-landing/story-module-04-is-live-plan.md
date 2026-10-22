---
title: 'Module 04 is live'
type: 'feature'
ticket: '6'
created: '2026-10-22'
status: 'built'
baseline_revision: '90bed9fa201125dfedb3026f0e75a9a77b86aebf'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred:
  - summary: >-
      Entries created between the page load and the module's first view are not shown, and a cached failed read keeps the no-activity line for up to 30 seconds.
    evidence: |-
      The list is cached 30 seconds and the stream opens on first view; accepted by the short-lifetime design, untested.
    severity: low
---

<intent-contract>

## Intent

**Problem:** Module 04 of the landing lists no feed entries; the visitor sees only the no-activity line.

**Approach:** The module lists the five latest feed entries (cached per locale, short lifetime) and a Stimulus controller subscribes to the public live stream only once the module is in view. A new entry is inserted at the top as one node and the last removed, held back while the pointer or focus is inside the module and while it is out of view, and handed over together afterwards. No live region.

Verify: A pack opened by a player appears at the top of an open landing's module 04 without a reload, and a landing never scrolled to module 04 opens no subscription.

</intent-contract>

## Implementation Notes

Oneshot: the existing public stream already prepends to `#feed-entries`, so the landing list reuses that id and the feed entry partial; no job or broadcast change. The stream source sits in a `<template>` the controller clones in on first view. Hover counts only for a mouse pointer. Reduced motion does not pause the list: the module's spec holds only on hover and focus.

## Plan Change Log

## Review Triage Log

### 2026-10-22 — Review pass
- verdicts: 7 findings — high 0, medium 1, low 3, false 0, maybe-false 0 (3 rejected as low)
- findings:
  - `[low]` `[patch]` Comments and "module 04" wording in the new tests and hold helper — removed.
  - `[medium]` `[patch]` A Turbo-cached snapshot could keep the stream source and double it on restore — the cloned source is marked temporary.
  - `[low]` `[defer]` No catch-up between render and first view — accepted by design.
  - `[low]` `[reject]` Negative assertion in the no-subscription test — the positive subscription test covers insertion on scroll; a fix adds complexity.
  - `[low]` `[reject]` Fixed sleep before the held-back absence check — an absence cannot be awaited; the release step uses retrying matchers.
  - `[low]` `[defer]` A database error is cached as an empty list for 30 seconds.
  - `[low]` `[reject]` Redundant CSS sibling rule — it targets the landing's own class.

## Verification

**Commands:**
- `bin/rails test test/controllers/landings_controller_test.rb test/system/landing_live_feed_test.rb`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks health` -- expected: pass

## Auto Run Result

Summary: module 04 lists the five latest feed entries (30 s fragment cache per locale) and a Stimulus controller subscribes to the public live stream on first view, inserts entries at the top, trims to five, and holds them while the mouse pointer or focus is inside or the module is out of view.

Files: LiveStream.landing_items, LandingsHelper#landing_feed_items, landings/_live view, landing.css, landing_feed_controller.ts, lib/stream_hold.ts (+ test), controller and system tests.

Verification: landings controller tests, controllers/jobs/packs suites, live_updates and power_on system tests, new landing_live_feed system test, vitest, tsc, zeitwerk, packwerk, rubocop pass; i18n-tasks has one inconsistent interpolation that predates this change.
Follow-up review recommended: false.
