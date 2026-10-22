---
id: 11
type: bug
title: "Switch through collections menu before going back to the bridge"
parent: epic-screen-walkthrough
covers: []
after: []
refined: false
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

Verify: 

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md
- request — #222

## Notes

- Open question: which steps before the recording put a collection snapshot with "◀ Capsule" into the tab's Turbo cache (the collection must have been reached directly from the capsule screen)? Ask the reporter for the full navigation of the session before the recording, or a recording from a fresh tab.
- Unknown: the pollution of the cache under the bridge's address is a hypothesis; a fix guarded by a test that fails on the defect needs one reproduction first. Settle with the author whether to ask the reporter, or to ship a defensive guard (never preview a cached page of another screen on a visit to the bridge) without a reproduction.
