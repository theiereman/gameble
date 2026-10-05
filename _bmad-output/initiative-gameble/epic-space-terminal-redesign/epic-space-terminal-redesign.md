---
tracker_id: ""
key: ""
type: epic
title: "Space terminal: shell, card and booster"
parent: initiative-gameble
covers: [CAP-1, CAP-3, CAP-4, CAP-5, CAP-7, CAP-16, CAP-18]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# Space terminal: shell, card and booster

## Description

The first half of the 2026-10-05 redesign of what epics 1 to 4 built: the new shell (tokens, fonts, top bar, phone tab bar, atmosphere, toasts, base components), the hub replacing the attic, the single server-rendered card face with the 32-colour filter, and the booster island with its opening exchange. The built code is brought in line with the updated architecture on the way. The collection, detail, profile, share and daily bonus screens follow in epic-space-terminal-screens.

## Outcome

For a player: from the hub to a revealed booster, the game as designed in `DESIGN.md` and `EXPERIENCE.md`, on desktop and phone. For the author: one shell and one card face that every later screen reuses.

## Requirements

- R1 (CAP-1, CAP-18; AD-27, AD-28): the shell (tokens, self-hosted fonts, top bar, phone tab bar, atmosphere layers, toasts, buttons and panels, focus ring) replaces the medieval one on every page except the back-office's restyle; the hub "Pont de commandement" replaces the attic, signed in and signed out; Steam sign-in is reached only through the official image in the sign-in panel, and signing in and out land on the hub; copy says "vous".
- R2 (CAP-3; AD-28): the five tiers are Commune, Peu commune, Rare, Épique, Légendaire, each with its colour and shape; code names are `common` to `legendary`, integers unchanged.
- R3 (CAP-7; AD-5, AD-16): one server component draws every card face (title, publisher, cover, genre, year, rarity shape and name, season number) at four sizes, with tilt, glare, holo and foil; each card of a published season has a random number; the genre is the card's tome genre; `Card.tsx` and `dust_tier` are gone.
- R4 (Images constraint; AD-17): covers are cropped, pixelated at 2 CSS px and reduced to 32 colours in a worker, with one palette per game, a bounded memory cache, the CORS and old-browser fallbacks and placeholder detection.
- R5 (CAP-4, CAP-5; AD-23): opening follows the opening protocol (request on activation, idempotency key replayed, refusal opens nothing); one activation reveals a card's rarity and game together; "Tout révéler" plays a Légendaire's full sequence; "mon dernier booster" shows an opened pack face up.
- R6 (Platforms constraint; AD-27): the booster has its desktop row and its phone pile and tray, portrait only, never scaled.
- R7 (AD-10, AD-11, AD-13, AD-28; CAP-16): jobs are enqueued after commit; GETs run on the reading role with writes prevented; the daily bonus is refused at a full reserve; `game_player_states` exists for every player; the Content-Security-Policy runs report-only.
- R8 (spec p95; AD-27): opening stays within 200 ms at the 95th percentile and the booster holds its frame budget on the reference low-end phone.

## Done when

1. Every page except the back-office shows the new shell, and the hub replaces the attic signed in and signed out; Jost, parchment, dust, the seal and the wipe reveal are gone.
2. Every card face comes from one server component, filtered to 32 colours in a worker, with its season number, tome genre and new tier.
3. Opening a booster follows the opening protocol on desktop and phone; a lost response replays the same pack and a refusal opens nothing.
4. AD-28's conformance list holds: tier codes renamed, `dust_tier` dropped, jobs after commit, GETs on the reading role, the full reserve refusing the bonus.
5. Opening stays within 200 ms at the 95th percentile and the booster holds its frame budget on the reference low-end phone.

## Boundaries

The web layer's shell, the hub, the card component, the booster island, the filter package, and the `Catalog` and `Game` changes AD-28 lists. Not the collection, detail, profile, share and daily bonus screens (epic-space-terminal-screens), friends and trades (epic 5), the feed, goal and ticker content (epic 6), backs beyond Standard (epic-card-backs), data controls and the legal page (epic 7). The back-office keeps its plain style with the new tokens.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, sections Capabilities and Constraints
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-5, AD-16, AD-17, AD-23, AD-27, AD-28
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md and EXPERIENCE.md
- mockups — _bmad-output/initiative-gameble/ux-gameble/mockups/key-screens.html and mobile.html (look and timing only, never source)
- review — _bmad-output/initiative-gameble/ux-gameble/review-feasibility.md, sections For the architecture and Epic 1 rework

## Notes

- Decision (2026-10-05): a new epic rather than stories in epics 1 to 4; shell first, then screen by screen, no feature flag (architecture AD-28). Approved by the author.
- Decision (2026-10-05): the redesign is split in two epics, this one (shell, card and booster) and epic-space-terminal-screens; approved by the author.
- Decision (2026-10-05): tracer bullet is entry 1, the shell with the exported logo and icons; the data (3, 4) and filter (5) lanes run beside it; the booster waits on the performance spike (9).
- Unknown: the reference low-end Android for the performance budget; entry 9 waits on it.
