---
id: 28
tracker_status: review
tracker_id: 256
remote: https://github.com/theiereman/gameble/issues/256
type: story
title: "The friends screen uses the width of a large screen and gives the friend list the lead"
parent: epic-screen-walkthrough
after: []
hitl: true
risk: low
---

# The friends screen uses the width of a large screen and gives the friend list the lead

## Description

On a desktop the Amis screen is one narrow column on the left with more than half the width empty: the invitation panel (link and code), the invitations strip, then the friends as rows of a name, a presence line and three buttons ("VOIR LE PROFIL", "ÉCHANGE", "RETIRER") that sit on one line and do not align from row to row because the name and presence widths differ (author, 2026-10-23, on staging, with a screenshot). Lay it out for the width: the friend list takes the larger area, on the right, structured as aligned columns or cards (name, presence, actions in a fixed place), and the invitations and the invite panel become the smaller side area; the friend list outweighs the invitations, including when there is no invitation and when a player has no friend. The friend's name becomes the way to open their profile dialog (a click or tap on the pseudo, with a keyboard-reachable control and an accessible name saying so), so "VOIR LE PROFIL" leaves the row; decide with the author how the remaining actions are grouped (the trade as the main action, the removal kept apart and hard to hit by mistake); the phone keeps one column; EXPERIENCE.md's Amis row and DESIGN.md follow.

## Acceptance Criteria

Verify: On a desktop width the friend list is the larger area with name, presence and actions in aligned places for every row, whatever the length of a name, and a click on the name opens the friend profile dialog; the invite panel and the invitations stand in the smaller area; the empty states for no friend and no invitation read well; the phone layout is one column; checked by the author on staging in French and in English; the friends system tests (retrying matchers) and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 20), author, 2026-10-23, with a screenshot of the desktop screen.
- Settled by the author, 2026-10-24: the pseudo opens the profile dialog, ÉCHANGE is the only filled button, and RETIRER moves into a more-actions (⋯) menu with a confirmation.
