---
title: 'Only full set completions reach the activity feed'
type: 'feature'
ticket: ''
created: '2026-11-17'
status: 'built'
baseline_revision: 'e34e9da053bab30c763b4facac7ff9a0ed2a9370'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Every pack, trade or auction win that crosses a set tier writes a `set` entry to the activity feed, and these entries flood the feed.

**Approach:** Only a full set completion (`SetCompleted`) still writes a `set` entry and broadcasts it live, from any source, grouped as today with the other tiers crossed at the same time. A tier reached without completing a set (`SetTierReached`) no longer reaches the feed. No repost button. Existing entries stay.

</frozen-after-approval>

## Implementation Notes

Oneshot: the feed handler and the live broadcast stop listening to `SetTierReached`. `FeedEntry.record_sets` became `record_completion`: it only starts from a completion, so the per-share ranking of results is gone (a completion always heads its group; several completions fall back to the lowest set id). A completion still groups the other tiers reached by the same pack or trade in `set_count`. Feed tests that rendered lesser-tier entries now seed them directly, as legacy rows. `feeds_controller_test` "counters of a page are read in one query" fails when run alone on the baseline too: pre-existing, deferred.

## Review Triage Log

- low, patched: `record_sets` still took any `tier:` and its new ordering no longer ranked lesser tiers -- narrowed to `record_completion`, tests seed legacy rows with `create!`.
- low, patched: history comment above a test helper -- renamed `record_legacy_tier_entry`, comment dropped.
- low, rejected: ticker rendering of lesser tiers no longer tested -- only legacy rows reach it, and they leave the 12-item ticker quickly; the feed page rendering stays covered.
- low, rejected: `assert_no_broadcasts` in the live job test leans on a commons pack writing no notable pull -- the set notice assertion above it is the real check.

## Verification

**Commands:**
- `bin/rails test test/domains/game/feed_test.rb test/models/live_stream_test.rb test/domains/game/set_tier_test.rb` -- pass
- `bin/ci` -- pass
