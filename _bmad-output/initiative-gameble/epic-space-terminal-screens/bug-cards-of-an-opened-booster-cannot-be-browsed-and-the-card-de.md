---
id: 8
type: bug
title: "Cards of an opened booster cannot be browsed, and the card detail loses the booster"
parent: epic-space-terminal-screens
covers: [R2]
after: [2]
refined: false
hitl: false
risk: medium
---

# Cards of an opened booster cannot be browsed, and the card detail loses the booster

## Description

Reproduction: open a booster. On a phone, a card opened large has no previous or next, so the player closes it and opens the next one. On a desktop, opening a card's detail and going back returns without the opened booster, so its other cards can no longer be checked. The card detail itself shows no previous or next, which R2 asks for on the phone. Cause hypothesis: the opened booster lives only in the island's client state with no address the detail can return to, and the detail is not told which list it was opened from. Expected: from an opened booster every card can be viewed in turn with previous and next, on phone and desktop; leaving the card detail returns to the opened booster as it was; the card detail has previous and next over the cards it was opened from (the booster, or the collection grid).

## Acceptance Criteria

Verify: System tests at phone and desktop widths open a booster, open a card, step previous and next through all five, come back and find the booster still opened with its cards; from the collection grid, previous and next on the card detail walk the grid. Or proof that no change is needed.

## References

- parent — _bmad-output/initiative-gameble/epic-space-terminal-screens/epic-space-terminal-screens.md
- epic-space-terminal-screens/story-card-detail-plan.md
- epic-packs-and-reveal/bug-flip-all-on-a-phone-shows-every-card-plan.md

## Notes

- Found by the author's acceptance check of 3.11 and 10.2 on 2026-10-08, which both went to done with this bug carrying the fix.
- Decision (2026-10-08): the card detail gets both previous and next and a return to the opened booster (author).
