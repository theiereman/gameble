---
tracker_id: ""
key: ""
type: epic
title: "Seasons carry over"
parent: initiative-gameble
covers: [CAP-23]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Seasons carry over

## Description

When a new season is published, a returning player keeps everything they built and receives the Brotherhood's seasonal allocation: a screen, shown once before the hub, that recaps the tiers they reached in the season that ended and shows their tiers in the next season. Tiers the player still meets are received again with the new season's mark, silently, so no opening or trade ever celebrates a tier the player already had. The rule that any edition counts for a set is built before the launch in epic-recognizable-sets; this epic adds the season change itself.

## Outcome

For a returning player: a season change reads as a reward, never as a loss; the signal is that the rehearsal on staging shows no counter drop, no tier lost and the allocation once per player.

## Requirements

The lines of CAP-23 (spec), with the season rules of `catalog-and-rarity.md`, Seasons, and AD-5, AD-10, AD-25 of the architecture.

- R1 (CAP-23): at a player's first visit after a publication, before the hub and before any opening, a dedicated screen recaps the season that ended: the tiers reached during it, and nothing else: no achievements, weekly goal rewards or card backs (author, 2026-10-28).
- R2 (CAP-23): a second section, "Vos paliers dans la saison suivante", lists the tiers the player still meets in the new season's sets, received at once, and the tiers to win back. A tier is identified by its set and its name; bronze, silver and gold earned in earlier seasons stay as history and are never listed to win back.
- R3 (CAP-23): tiers carried into the new season are never celebrated at an opening or announced in the feed; an opening or a trade celebrates only the tiers it crosses itself.
- R4 (CAP-23): one Brotherhood line heads the screen; the rest is plain copy.
- R5 (CAP-23): a player with no card from an earlier season sees no allocation.
- R6 (CAP-23): a tier shows no season mark and no count of seasons (author, 2026-10-19); no season chip appears in the collection grid.
- R7 (Card copies constraint; AD-7): draws give only the published season's cards; a pack drawn before a publication and still unopened is redrawn in the published season.

## Done when

1. After a season is published on staging, a returning player is led to the allocation screen once, before the hub, with the tiers reached in the ended season and, in a second section, its tiers in the next season (received at once, to win back).
2. Tiers met at publication are received once; none is celebrated or announced in the feed, including when a friend's trade is accepted before the player returns.
3. A tier is identified by its set and its name; bronze, silver and gold earned in earlier seasons stay as history and are never listed to win back.
4. A player with no card from an earlier season goes straight to the hub.
5. Opening a pack answers within 200 ms at the 95th percentile after a publication.
6. All of it is live in production before production's second season is published.
7. After a publication, an opening never gives a card of an earlier season.

## Boundaries

The season change for players: receiving carried tiers, the allocation screen, and unopened packs redrawn at publication. Not the publication itself (epic-season-preparation), not the holding rule across editions and the collection's tiles (epic-recognizable-sets, entries 5 and 15), not season marks on card backs and titles (epic-card-backs).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-23; catalog-and-rarity.md, Seasons
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-5, AD-7, AD-9, AD-10, AD-11, AD-25
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Seasonal allocation; DESIGN.md, Season mark
- change — _bmad-output/initiative-gameble/change-season-carryover/change-season-carryover.md, sections 4.1 to 4.8

## Notes

- Decision (2026-10-14, author): seasons are reprints; the allocation and season marks follow the public launch and must be live before production's second season (change-season-carryover).
- Decision (2026-10-14, author): the allocation is received and seen apart; every operation that raises quantities first receives a pending allocation silently, and the hub and booster page lead to the screen while it is unseen.
- Decision (2026-10-14): tracer bullet is entry 1 (carried tiers received silently), so the screen and the marks build on rows that already exist.
- Decision (2026-10-14): the rehearsal follows the refactor sweep so it runs on the final code.
- Decision (2026-10-14, author, through the architecture review): unopened packs of an earlier season are redrawn in the published season at publication (entry 6), rather than opening old editions; the receipt's concurrency is settled by AD-10 (the received season checked under the bank lock).
- Decision (2026-10-14, author): the allocation goes to every player holding a card from an earlier season, traded ones included, not only to players who played that season (the architecture's rule).
- Decision (2026-10-14, author): built after epic 12, once production is open on its first season; epics 16 and 12 do not wait on it.
- Waits on epic 12 because: production opens after it, on its first season.
- Waits on epic 13 because: tiers counted across editions (13.5), tiers in the feed (13.6), the hub panel (13.7), the album (13.8) and the collection across editions (13.15).
- Decision (2026-10-19, author): set tiers cut by set size (change-set-tiers-by-size): a tier is identified by its set and its name; bronze, silver and gold from earlier seasons stay as history and are never listed to win back (R2, Done when 3).
- Decision (2026-10-19, author): tiers carry no season mark: no "Or · 12 saisons", no per-season list and no "à reconquérir" on the album, the profile or the hub; entry 3 "Season marks on tiers" is removed. Card backs keep their season marks (epic-card-backs).
- Decision (2026-10-28, author): card backs ship after the MVP (epic-card-backs, release 1.2.0), so this epic no longer waits on them: the recap ships without card backs, 17.1 unlocks no back, and the season mark stamp belongs to 9.6. Epic 9 answers the allocation receipt (9.2) and adds the backs to the recap (9.8). Source conflict: CAP-23's first line lists card backs in the recap until epic 9 lands.
- Decision (2026-10-28, author): the allocation screen has two sections: "Obtenu pendant la saison N", the tiers reached and nothing else, and "Vos paliers dans la saison suivante", the tiers received at once and those to win back. This supersedes the earlier lines that put achievements, goal rewards and card backs on the screen; 9.8 is affected.
