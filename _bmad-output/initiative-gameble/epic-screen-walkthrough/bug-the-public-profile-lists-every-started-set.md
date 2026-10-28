---
id: 18
tracker_status: done
tracker_id: ""
type: bug
title: "The public profile lists every started set"
parent: epic-screen-walkthrough
after: []
refined: false
hitl: false
risk: low
---

# The public profile lists every started set

## Description

The public profile's sets section (`app/views/public_profiles/_sets.html.erb`, rows from `started_set_rows` in `app/controllers/public_profiles_controller.rb`) lists every set the player has started, which makes the profile too long (author, 2026-10-23, on staging). Show only the 20 most complete sets, most complete first, and keep the section's count ("n sets entamés") at the true total so it does not read as 20; the full list stays one step away on the player's full collection, which the profile already links to.

## Acceptance Criteria

Verify: A profile with more than 20 started sets shows 20 rows, the most complete first, and a count that names the real total; a profile with fewer shows them all; the profile request test, the empty-state test and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 8), author, 2026-10-23.
