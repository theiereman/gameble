---
id: 21
tracker_status: done
tracker_id: ""
type: bug
title: "REVEAL ALL is briefly active while the next capsule deals its cards"
parent: epic-screen-walkthrough
after: []
refined: false
hitl: false
risk: low
---

# REVEAL ALL is briefly active while the next capsule deals its cards

## Description

When the player opens the next capsule, the booster's REVEAL ALL button (`app/frontend/components/BoosterView.tsx`, `revealAllDisabled`) is enabled for a short moment then greyed again while the cards are being uncovered, though pressing it then has no meaning (author, 2026-10-23, on staging). Keep it disabled from the moment the next capsule is requested until the cards can be revealed, with no flash of the active state. A bug fix only: the booster is frozen to fixes until its port to Stimulus lands.

## Acceptance Criteria

Verify: A system test opens a capsule then the next one and asserts with a retrying matcher that REVEAL ALL is never enabled between the request and the deal, then enabled once the cards can be revealed; `test/system/booster_test.rb` and vitest pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 12), author, 2026-10-23.
