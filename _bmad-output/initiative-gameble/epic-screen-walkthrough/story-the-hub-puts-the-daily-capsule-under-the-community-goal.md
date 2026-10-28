---
id: 19
tracker_status: done
tracker_id: ""
type: story
title: "The hub puts the daily capsule under the community goal"
parent: epic-screen-walkthrough
after: []
hitl: true
risk: low
---

# The hub puts the daily capsule under the community goal

## Description

On the desktop hub (`app/frontend/styles/hub.css`, `.hub` grid areas; panels `app/views/pages/_daily_booster.html.erb`, `_goal.html.erb`, `_set_progress.html.erb`) the community goal spans the kicker and menu rows, so the set progress panel starts below it and a wide gap separates the two on the right (author, 2026-10-23, on staging). Swap the two panels' places: the daily capsule goes in the right column just under the community goal, and "SETS EN COURS" takes the left column under the menu where the daily capsule stood, so no column opens a gap. Decide with the author the order of the stacked blocks on the two-column (from 720px) and one-column (phone) layouts; EXPERIENCE.md's Hub content and the hub comment in `hub.css` follow.

## Acceptance Criteria

Verify: At 1180px and wider the right column shows the community goal then the daily capsule with no gap between them and the left column shows the menu then "SETS EN COURS"; the 720px and phone layouts keep an order the author approved; checked by the author on staging, in French and in English, signed in with and without a daily capsule; the hub system tests and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 9), author, 2026-10-23.
- Settled by the author, 2026-10-24: the two-column (720px) and phone layouts stack the community goal, then the daily capsule, then SETS EN COURS, the same order as the desktop's right column.
