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
severity: P2
---

# Cards of an opened booster cannot be browsed, and the card detail loses the booster

## Description

After opening a booster, a player cannot go from one of its cards to the next. On a phone, the large view of a card has no previous or next, so the player closes it and opens the next one. On a desktop, opening a card's detail and going back shows a sealed booster: the five cards just pulled are gone. The player should be able to walk the booster's cards in turn on phone and desktop, and come back from a card's detail to the booster with its cards.

## Reproduction

Desktop, signed in with a booster in the reserve:

1. Open `/fr/booster`, press « Ouvrir le booster », then « Tout révéler ».
2. Click a revealed card. The browser goes to `/fr/cards/<slug>`. The detail shows no ◀ ▶.
3. Press the browser's Back. Actual: `/fr/booster` reloads with a sealed or empty canister; the five cards are gone. Expected: the booster with its five cards.

Phone, window 390 × 844:

1. Open a booster, then press « Ranger » or « Tout révéler ».
2. Tap a filled tray slot. Actual: the large view shows only « Voir la fiche » and « Fermer », no previous or next.
3. Tap « Voir la fiche ». Actual: ◀ ▶ walk the card's tome, not the booster; « ◀ Grille » leads to the tome's grid; nothing leads back to the booster.

## Cause Hypothesis

The opened booster lives only in the booster island's memory. After the opening the address stays `/fr/booster`, nothing is written to the browser history, and the booster page is kept out of the page cache, so Back renders a fresh, sealed booster. The opened pack has its own page (`/fr/packs/<token>`), but the island never uses it. The card detail is not told where it was opened from: its ◀ ▶ always walk one set (the card's tome by default), and they are hidden above the phone width. The phone's large view of a card was built with no previous or next.

## Acceptance Criteria

1. **The large view of a booster card walks the booster**
   **Given** a player on a phone who opened a booster and opened one of its cards in the large view
   **When** they press next or previous, or swipe
   **Then** the large view shows the neighbouring card of that booster, in the booster's order, without closing; there is no previous on the first card and no next on the fifth
2. **The card detail walks the booster it was opened from**
   **Given** a player who opened a card's detail from an opened booster, on a phone or a desktop
   **When** they use ◀ ▶ on the detail
   **Then** they move through the five cards of that booster, in its order, and no further
3. **Coming back from the detail shows the booster with its cards**
   **Given** a player on the detail of a card opened from a booster, whether or not they had revealed every card before leaving
   **When** they go back, by the browser's Back or the detail's return control
   **Then** they see the booster screen with that booster's five cards face up, and can open another of them
4. **The card detail walks the collection grid as shown**
   **Given** a player in the collection grid with its current filters and search
   **When** they open a card and use ◀ ▶ on its detail
   **Then** they move through the cards the grid shows, in the grid's order, and the return leads to the grid with the same filters and search
5. **Anywhere else, the detail walks the card's tome**
   **Given** a card detail opened from anywhere else (the feed, the hub's showcase, a shared link, a public profile, a pack's page)
   **When** the viewer uses ◀ ▶
   **Then** they walk the card's tome as they do today on a phone, now also on a desktop
6. **Tests cover the condition found and fixed**
   **Given** the test suite
   **When** it runs
   **Then** system tests at phone and desktop widths fail on the defect and pass on the fix: the large view's previous and next, the detail's ◀ ▶ over the booster, Back to the booster with its cards, and ◀ ▶ over a filtered grid
7. **Or: no change is needed, with proof**
   **Given** the reproduction
   **When** it is run on the current code
   **Then** the expected behaviour already holds, or the report was mistaken, with the evidence recorded in Notes — this supersedes 1 to 6

## References

- parent — _bmad-output/initiative-gameble/epic-space-terminal-screens/epic-space-terminal-screens.md, R2
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Booster › Card zoom; Collection › Card detail; State Patterns › Reveal abandoned
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Card zoom
- build record — _bmad-output/initiative-gameble/epic-space-terminal-screens/story-card-detail-plan.md
- build record — _bmad-output/initiative-gameble/epic-packs-and-reveal/bug-flip-all-on-a-phone-shows-every-card-plan.md

## Notes

- Found by the author's acceptance check of 3.11 and 10.2 on 2026-10-08, which both went to done with this bug carrying the fix.
- Decision (2026-10-08): the card detail has ◀ ▶ on phone and desktop, and a return to the opened booster (author).
- Decision (2026-10-08): coming back from a card's detail shows the booster with its five cards face up, even if the player had not revealed them all; the exact state left (tray, cards still hidden) is not restored (author).
- Decision (2026-10-08): from the collection grid, ◀ ▶ walk the grid as shown, with its filters and search; opened from anywhere else they walk the card's tome as today (author).
- Source conflict: EXPERIENCE.md says ◀ ▶ are phone only and that a left reveal resumes nothing on return; R2 says previous and next on the phone. The decisions above supersede both; this ticket updates EXPERIENCE.md (Card zoom, Card detail, Reveal abandoned) and the epic's R2 says so.
- Assumption: leaving the booster any other way (the hub, a menu) still resumes nothing on return, as today; only the way back from a card's detail shows the booster.
- Assumption: ◀ ▶ over the grid continue across its pages (60 cards per page) rather than stopping at the page's end.
