---
id: 7
tracker_status: done
tracker_id: ""
type: story
title: "Another player's full collection, read-only"
parent: epic-screen-walkthrough
covers: [R3]
after: [6]
hitl: false
risk: medium
---

# Another player's full collection, read-only

## Description

« VOIR LA COLLECTION COMPLÈTE » and the friend profile's « VOIR LA COLLECTION » open that player's collection as the viewer's own collection screen shows it (sets and all cards, search and filters), read-only on the owner's cards; the friend profile loses its showcase and gains « VOIR LE PROFIL »; the old profile index of sets is retired, and a card opened from that collection leads back to it.

## Acceptance Criteria

Verify: Request tests show the collection following the owner's visibility, no write action on it, the back from a card returning to that player's grid, and the old index no longer served; the author approves the screen.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Information Architecture: Full collection (another player's); Component Patterns: Friend profile

## Notes

- Folds in the deferred back from a profile's card (« ◀ Grille » leading to the viewer's own set), from the closure of epic-space-terminal-screens (author, 2026-10-15).
