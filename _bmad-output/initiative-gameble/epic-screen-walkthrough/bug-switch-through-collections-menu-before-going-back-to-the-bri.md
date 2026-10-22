---
id: 11
tracker_status: done
tracker_id: 223
remote: https://github.com/theiereman/gameble/issues/223
type: bug
title: "Switch through collections menu before going back to the bridge"
parent: epic-screen-walkthrough
covers: []
after: []
refined: true
hitl: false
risk: low
severity: P3
---

# Switch through collections menu before going back to the bridge

## Description

Requested in #222 by @Felzpath. From the capsule screen, "Back to the bridge" (and the wordmark) briefly shows the collection screen before the bridge appears. The player expects to go straight to the bridge.

## Reproduction

From the reporter's screen recording (Chrome, desktop, empty reserve), read frame by frame:

1. On the bridge, activate 01 "Open a capsule". The capsule screen shows with the reserve empty.
2. Activate "Back to the bridge". For a fraction of a second the collection screen shows, with its "◀ Capsule" back button, then the bridge.
3. The same happens through the wordmark: the transition frame shows the collection's top bar over the leaving capsule screen.

Not reproduced in headless Chrome: a plain bridge, capsule, bridge round trip; the same with 800 ms of latency; the same after a trip through the collection, with Turbo visits and with browser Back and Forward; rapid collection-then-bridge visits. In each the screen after the click is the bridge at once, and Turbo's snapshot cache holds only the collection under its own address.

## Cause Hypothesis

The screen shown first is a page rendered from a Turbo cached snapshot, since the collection appears complete at once with its "◀ Capsule" state. The bridge is exempt from the cache, so a snapshot of another page stored under the bridge's address would never be replaced or cleared and would be previewed on every visit to the bridge, which would explain "every time". How a collection snapshot gets stored under the bridge's address is not established.

## Acceptance Criteria

- Given a Turbo snapshot of another screen, such as the collection, stored under the bridge's address, when the player follows a link to the bridge, then the bridge appears at once and that screen is never rendered on the way.
- Given the same stored snapshot, when the player goes back or forward in history to the bridge, then the bridge appears at once and that screen is never rendered on the way.
- Given the player visits the bridge in either language, when the visit starts, then no stored snapshot answers it, whatever the page it holds.
- Given the player visits any screen other than the bridge, when the visit starts, then the stored snapshot of that screen still serves as its preview.
- Given the guard has run, when the player later returns to a screen the guard emptied from the cache, then that screen loads from the server without error.
- The original cause stays unproven: this guard prevents the symptom without a reproduction of how a foreign snapshot reaches the bridge's address. The ticket is done when the guard and its tests pass, not when the cause is found.

Verify: a system test seeds a snapshot of the collection under the bridge's address in the page's Turbo cache, visits the bridge by link and by history, and asserts the bridge shows without the collection ever rendering; the test fails with the guard disabled. A unit test covers the guard's address rule.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md
- request — #222

## Notes

- Decision (2026-10-22, the author): ship a defensive, preventive fix without a reproduction. On a visit to the bridge, Turbo must never preview a cached snapshot of another screen; the bridge appears at once. This replaces the earlier open question about asking the reporter.
- Unknown, accepted: how a collection snapshot reaches the bridge's address is not established; the plan records honestly that the original cause remains unproven. If the symptom persists after the guard, the cause is elsewhere and the ticket is reopened with a new recording.
- Open question for the reporter, optional and no longer blocking: the full navigation of the session before the recording, or a recording from a fresh tab.
