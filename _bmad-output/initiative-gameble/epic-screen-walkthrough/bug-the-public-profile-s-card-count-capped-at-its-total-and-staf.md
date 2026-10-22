---
id: 9
tracker_status: done
tracker_id: 201
remote: https://github.com/theiereman/gameble/issues/201
type: bug
title: "The public profile's card count capped at its total, and staff see a banned player's line again"
parent: epic-screen-walkthrough
covers: [R3]
after: [3]
refined: true
hitl: false
risk: low
severity: P3
---

# The public profile's card count capped at its total, and staff see a banned player's line again

## Description

The identity band's CARTES figure counts the games a player holds in any edition, over the published season's card total, so after a season change it can read more than its total (for example 120/100). It never exceeds the total. Staff reading a banned player's profile no longer see that the player is banned, since the visibility line left the band; the line comes back for staff only, never for players or visitors.

## Reproduction

1. A player holds games from an earlier season's editions that the published season no longer counts, so they hold more distinct games than the season has cards.
2. Open their public profile: CARTES shows a count above the total, for example 120/100. Expected: 100/100 at most.
3. Ban a player, sign in as a moderator or an administrator, and open the banned player's profile. Actual: nothing says the player is banned. Expected: a line says so.

## Cause Hypothesis

The figure takes the distinct games held in any edition (not limited to the published season) with no bound by the season's total. The visibility line, which carried the banned wording for staff, was dropped from the identity band with the redesign and nothing replaced it.

## Acceptance Criteria

1. **The card count never exceeds its total**
   **Given** a player who holds more distinct games across editions than the published season counts
   **When** anyone opens their public profile
   **Then** CARTES reads the season's total over the same total, and a player below the total still reads their own count
2. **Staff see the banned line**
   **Given** a banned player's profile
   **When** a moderator or an administrator opens it
   **Then** the identity band says the player is banned, in English and in French
3. **No one else sees it**
   **Given** a profile that is not banned
   **When** staff, a player or a visitor opens it, or a player or a visitor tries a banned player's profile
   **Then** the band shows no banned line (the banned profile is the unavailable page, as before)
4. **The profile costs the same queries**
   **Given** the public profile
   **When** it renders
   **Then** it runs no more queries than before
5. **Tests cover the condition found and fixed**
   **Given** the test suite
   **When** it runs
   **Then** a test that fails on the defect and passes on the fix covers each of criteria 1 to 3
6. **Or: no change is needed, with proof** (supersedes 1 to 5)
   **Given** the reproduction
   **When** it is run on the current code
   **Then** the expected behavior already holds, with the evidence recorded in Notes

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md
- source — the author's review of entry 3, 2026-10-19

## Notes

- Assumption: the banned line is a short text in the band's meta row, beside the member-since date.
