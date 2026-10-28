---
id: 26
tracker_status: done
tracker_id: ""
type: story
title: "A not-owned card is greyed and locked on its detail too"
parent: epic-screen-walkthrough
after: []
hitl: true
risk: low
---

# A not-owned card is greyed and locked on its detail too

## Description

EXPERIENCE.md's Card detail row says a card shows as itself on its detail, never greyed or locked, owned or not (author, 2026-10-20), while Toutes les cartes and the other grids show a not-owned card faded and grey with a pixel lock. The author finds the mismatch inconsistent (screen walkthrough, 2026-10-23, on staging) and reverses the earlier call for the signed-in detail: show a card the player does not own greyed with the lock, as in the grids (`ux-gameble/mockups/catalog-not-owned.html`). A visitor and the public card page keep the card plain, since a visitor owns nothing and the shared page is the card's own face. Settle with the author whether the lock covers the zoom and the share preview image; EXPERIENCE.md's Card detail and Card not owned rows and DESIGN.md follow.

## Acceptance Criteria

Verify: A signed-in player opening a card they do not own sees it faded and grey with the lock, with the same face as in Toutes les cartes, and an owned card unchanged; a visitor and the public card page show the card plain; the card detail system tests (retrying matchers), the visitor case and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 18), author, 2026-10-23: consistency with the grids; it reverses the 2026-10-20 call that the detail never shows a card greyed or locked.
- Settled by the author, 2026-10-24: the lock covers the signed-in detail and its zoom; the share preview image keeps the card's plain public face.
