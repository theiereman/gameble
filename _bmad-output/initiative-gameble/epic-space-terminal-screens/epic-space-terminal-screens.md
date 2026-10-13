---
tracker_id: ""
key: ""
type: epic
title: "Space terminal: screens"
parent: initiative-gameble
covers: [CAP-6, CAP-7, CAP-8, CAP-9, CAP-16, CAP-18]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Space terminal: screens

## Description

The second half of the 2026-10-05 redesign: the collection and its sets with NOUVEAU, the card detail, the public profile and the shared card page, the daily booster panel, and the profile and settings screen with the "Animations réduites" preference, all in the shell and card face of epic-space-terminal-redesign.

## Outcome

For a player: every screen epics 1 to 4 built follows `DESIGN.md` and `EXPERIENCE.md`. For the author: the old direction is fully retired before epics 5 to 7 start.

## Requirements

- R1 (CAP-6; AD-26): the collection shows the sets with their progress, owned faces with their copies, missing slots naming the game, and NOUVEAU on cards gained since the collection was last seen; grids beyond about 60 slots are paginated.
- R2 (CAP-7): the card detail ("FICHE DE LA CARTE") shows its facts, "VOIR SUR STEAM" and "PARTAGER"; on the phone it is a sub-view; previous and next on phone and desktop walk the opened booster or the collection grid it was opened from, else the card's tome, and the way back from it returns to the opened booster (amended 2026-10-08, bug 8); a card not owned shows the Standard back faded.
- R3 (CAP-8, CAP-9; AD-15): the public profile and the shared card page follow the design; the shared page shows the card only and its preview carries title and rarity with no image.
- R4 (CAP-16; AD-7): the daily booster panel claims a 3-card booster into the reserve, refuses at a full reserve, and counts down to midnight UTC.
- R5 (Reduced motion and player-facing words constraints; AD-18, AD-27): the profile and settings screen holds language, "Animations réduites" and sign-out; one motion switch drives CSS, Stimulus, islands and View Transitions.
- R6 (CAP-18): signed out, these screens show what needs no account and lead to the sign-in panel for the rest.
- R7 (CAP-6; UX update of 2026-10-07): the interface breathes more (panel padding and gaps up about one step), the booster opening is centred in the window without resizing, the star field stays still at screen changes and only twinkles, and the collection's card grid opens on every card, owned cards first (newest first), above the missing ones (amended 2026-10-13, bug 9), with a FILTRES zone of toggleable chips (state, rarity, set, genre) and a search over title and publisher in place of the rows of chips.

## Done when

1. The collection, sets, card detail, public profile, shared card page and daily booster panel follow the design on desktop and phone.
2. NOUVEAU marks exactly the cards gained since the collection was last seen; a reservation never marks one.
3. The shared card page names no player and previews without an image on Discord, X and WhatsApp.
4. "Animations réduites" stops every looping or blinking effect, the ticker and the View Transitions, signed in or out.
5. No screen of the medieval direction remains.
6. The collection's card grid opens on every card, owned cards first, above the missing ones; a player filters it by state, rarity, set and genre from one zone and searches by title or publisher; the booster opening is centred on a large window; the star field does not move at screen changes.

## Boundaries

The web layer's screens and their Stimulus controllers, the NOUVEAU watermark in `Game`, and the motion preference in `Accounts`. Not profile visibility, data export, deletion or the legal page (epic 7), and not friends, trades or the feed.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, sections Capabilities and Constraints
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-15, AD-16, AD-18, AD-26, AD-27
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md and EXPERIENCE.md
- mockups — _bmad-output/initiative-gameble/ux-gameble/mockups/key-screens.html and mobile.html (look and timing only, never source)

## Notes

- Decision (2026-10-05): split from epic-space-terminal-redesign; approved by the author.
- Decision (2026-10-07): the author's appearance remarks (ux-gameble/.memlog.md, entries of 2026-10-07; DESIGN.md and EXPERIENCE.md updated) become R7 and two stories, after story 4 and before the refactor sweep: global spacing, centred booster opening and the still star field first, then the collection's filter zone and search, so the two never edit the same stylesheets at once. Filter groups and the folded default are `[ASSUMPTION]` in the spines.
- Decision (2026-10-08): R2's previous and next extend to the desktop and follow where the detail was opened from (the opened booster, the collection grid as shown, else the card's tome); coming back from a card's detail shows the opened booster with its cards face up; bug 8 carries it and updates EXPERIENCE.md (author).
- Decision (2026-10-08, recorded 2026-10-13): the collection's card grid opens on every slot, owned cards first, newest first, then the missing ones, not on owned cards only; R7 and Done when 6 amended, bug 9 carries the fix and updates EXPERIENCE.md (author, retrospective S6).
