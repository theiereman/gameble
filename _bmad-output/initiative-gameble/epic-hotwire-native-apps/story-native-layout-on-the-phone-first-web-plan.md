---
title: 'Native layout on the phone-first web'
type: 'feature'
ticket: '2'
created: '2026-11-04'
status: 'built'
baseline_revision: '084722f6ecb383274c8c827ca3742966f7d03395'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** In a Hotwire Native app the web tab bar is gone but the phone-first layout still reserves its height, and the app styles hide the web back buttons the phone design relies on.

**Approach:** Zero both tab bar height tokens in the app, keep the web header and its back buttons, and pin the result with a system test that drives a Hotwire Native user agent at 390 by 844.

</frozen-after-approval>

## Implementation Notes

Oneshot: a four-line stylesheet and one system test. Decision: the native shells hide their own navigation bar, so the web header and its back buttons are the only ones. The story's prerequisites (the header and Social stories) are in develop's history, so the code does not wait on their ticket state. Review was skipped as a pinned choice for a change this small.
