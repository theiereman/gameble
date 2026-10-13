---
id: 9
type: bug
title: "The collection grid hides the missing cards by default, where owned cards should come first"
parent: epic-space-terminal-screens
covers: [R7, R1]
after: [7]
refined: true
hitl: false
risk: low
severity: P2
---

# The collection grid hides the missing cards by default, where owned cards should come first

## Description

A player who owns cards of the season opens the collection's card grid and sees only the cards they own; the missing slots appear only once they switch the state filter to TOUT. The author asked for the owned cards to come first, above the missing ones, not alone. A set's album opened by the same player hides its missing slots too, and is empty when they own no card of that set. With no state asked, the grid should show every slot: on the whole season, owned cards first, newest first, then the missing ones; on a set, every slot in set order.

## Reproduction

Signed in as a player who owns at least one card of the published season, but none of some set:

1. Open the collection, then « TOUTES LES CARTES ▸ », with no filter. Actual: only owned cards; the filter zone counts no active filter. Expected: every slot of the season, owned cards first (newest first), then the missing ones.
2. Switch the state filter to TOUT. Actual: the missing slots now appear after the owned cards. This is the order the grid should open on.
3. Open the album of a set the player holds no card of. Actual: an empty grid. Expected: every slot of the set, in set order, as missing-card slots.
4. Open the album of a set the player holds some cards of. Actual: only those cards. Expected: every slot, owned cards face up, missing ones as missing-card slots.

## Cause Hypothesis

The default state is "owned" whenever the player holds any card of the whole season, not of the grid shown, so a set album with nothing owned falls on an empty owned-only grid. The default is decided in several places: the grid's loading for the collection, the same loading for the card detail that walks the grid, the filter zone's script, and the filter count in the helper. The default followed the spec faithfully: the spec turned the author's remark "owned cards should come first" into "opens on the cards the player owns" (retrospective finding S6). The whole-season order under TOUT already puts the newest gains first and unowned cards last, so the order itself may need no change.

## Acceptance Criteria

1. **The whole-season grid opens on every slot, owned first**
   **Given** a signed-in player who owns cards of the season
   **When** they open the card grid with no state asked
   **Then** it shows every card of the season: owned cards first, newest gained first, then the missing slots naming the game
2. **A set's album opens on every slot of the set**
   **Given** a signed-in player, owning some, all or none of a set's cards
   **When** they open that set's album with no state asked
   **Then** it shows every slot of the set in set order, owned cards face up and missing ones as missing-card slots
3. **The state filter narrows from that default**
   **Given** the grid opened with no state asked
   **When** the player opens the filter zone
   **Then** it counts no active state filter, and POSSÉDÉES, MANQUANTES, NOUVELLES and DOUBLONS each narrow the grid to their cards; TOUT EFFACER returns to the default
4. **The card detail walks the default grid**
   **Given** a card detail opened from the grid shown with no state asked
   **When** the player uses ◀ ▶
   **Then** they walk the same slots in the same order, missing ones included
5. **The spec says what the author decided**
   **Given** EXPERIENCE.md's Collection opening row
   **When** it is read after this ticket
   **Then** it says the card grid opens on every card, owned ones first (newest first), above the missing ones, and that the state filter narrows to POSSÉDÉES, MANQUANTES, NOUVELLES or DOUBLONS
6. **Tests cover the condition found and fixed**
   **Given** the test suite
   **When** it runs
   **Then** tests that fail on the defect and pass on the fix cover the whole-season default and its order, a set album with no card owned, the filter count on opening and the detail's walk; tests that pinned "owned" as the default now pin every slot
7. **Or: no change is needed, with proof**
   **Given** the reproduction
   **When** it is run on the current code
   **Then** the expected behavior already holds, or the report was mistaken, with the evidence recorded in Notes — this supersedes 1 to 6

## References

- parent — _bmad-output/initiative-gameble/epic-space-terminal-screens/epic-space-terminal-screens.md, R1, R7, Done when 6
- retrospective — _bmad-output/initiative-gameble/epic-space-terminal-screens/epic-space-terminal-screens-retrospective.md, findings S6 and B1, action items 1 and 2
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Collection › Collection opening, Set album, Filter zone
- build record — _bmad-output/initiative-gameble/epic-space-terminal-screens/story-collection-opens-on-owned-cards-with-a-filter-zone-and-a-sea-plan.md

## Notes

- Found by the epic's retrospective (S6, B1); the author decided S6 on 2026-10-08: fix now, with the spec reconciled.
- Decision (2026-10-08): the grid opens on every slot, owned cards first, newest first, then the missing ones; the state filter keeps POSSÉDÉES, MANQUANTES, NOUVELLES and DOUBLONS as narrowings (author, retrospective S6).
- Decision (2026-10-13): a set's album keeps its set order with missing-card slots, as EXPERIENCE.md's Set album row says; only the whole-season grid puts owned cards first (author).
- Source conflict: EXPERIENCE.md's Collection opening row and `ux-gameble/.memlog.md` (decision of 2026-10-07) say the grid opens on owned cards only. The author's decision above supersedes them; this ticket updates the EXPERIENCE.md row. The epic's R7 and Done when 6 were amended with this ticket.
- Where the default is decided today (from the retrospective, checked 2026-10-13): `grid_default_state` in `app/controllers/concerns/collection_grid_loading.rb`, called by `LibraryController` and `CardsController`; `app/views/library/_filters.html.erb` serves it to the filter zone's Stimulus controller as its default; the filter count compares against it.
