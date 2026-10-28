---
id: 29
tracker_status: done
tracker_id: ""
type: story
title: "The friend profile dialog is arranged, not stacked"
parent: epic-screen-walkthrough
after: [28]
hitl: true
risk: low
---

# The friend profile dialog is arranged, not stacked

## Description

The friend profile dialog (`app/views/friends/_profile_dialog.html.erb`, opened from a friend row) puts the identity (avatar, name, presence, cards collected) above three buttons stacked one under the other at their own widths, "ÉCHANGE", "VOIR LE PROFIL" and "VOIR LA COLLECTION", then "SIGNALER" as a lone orange word, all left-aligned in a wide empty panel (author, 2026-10-23, on staging, with a screenshot). The dialog is opened by a click on the friend's pseudo in the friends list (16.28), so the row has no profile button, and the dialog's own buttons are rethought to fit. Arrange it: with the author, group the actions by weight (the trade as the main one, the two views of the friend together, the report kept apart), align them on a common width or grid inside the panel, and use the panel's width; the dialog keeps its focus rules, close button and Esc, and follows the action grouping chosen for the friends screen in 16.28 so the two read alike; EXPERIENCE.md's Friend profile row and DESIGN.md follow.

## Acceptance Criteria

Verify: The friend profile dialog on the desktop and the phone, in French and in English, shows the identity and the actions in the agreed arrangement with aligned buttons and the report apart; focus moves into the dialog and returns to its opener on close, Esc closes it; checked by the author on staging; the friends system tests (retrying matchers) and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 21), author, 2026-10-23, with a screenshot of the dialog.
- Settled by the author, 2026-10-24: as on the friends screen, ÉCHANGE is the only filled button; SIGNALER and the removal sit in a more-actions (⋯) menu, the two views of the friend side by side.
