---
tracker_id: ""
key: ""
type: epic
title: "Sets players recognize"
parent: initiative-gameble
covers: [CAP-6, CAP-7, CAP-13, CAP-18]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# Sets players recognize

## Description

Tomes, publisher sets and "best rated of the year" sets are replaced by sets a player recognizes from their name: themes, franchises, studios, hall of fame sets and the UFOs. Theme and hall of fame sets have bronze, silver and gold tiers. The collection opens on the player's sets in progress, a set opens as an album, and the filtered card grid becomes a secondary view. Source: the approved change proposal `change-recognizable-sets`, from the forge `forge-card-series`.

## Outcome

For every player: the collection shows what they are completing, with names they recognize; the spec's success signal is the measure.

## Requirements

- R1 (CAP-6): every card of a published season belongs to at least one set; the kinds are themes, franchises, studios, hall of fame sets and the UFOs, as `catalog-and-rarity.md` Sets defines them; tomes, publisher sets and best-of-year sets are retired.
- R2 (CAP-6): a game joins every listed theme among its 5 most-voted Steam tags; a game with none joins the UFOs; the theme list (about thirty tags, French and English names) lives in code; the UFOs hold under about 5 % of the catalog.
- R3 (CAP-6): franchise and studio sets come from Steam's `franchises` and `developers`, kept on each card by the import, with a minimum size set on real data.
- R4 (CAP-7): a card's genre is its main theme (the listed theme with the most votes among its top 5 tags); a card in the UFOs shows no genre.
- R5 (CAP-6; AD-10): theme and hall of fame sets have bronze, silver and gold tiers (25 %, 50 %, 100 % of their distinct cards); franchise, studio and UFO sets are complete or not; each tier or completion reached for the first time writes one row and publishes one event.
- R6 (CAP-13): a tier reached or a set completed at opening shows a celebration after the reveal and a line in the feed and the LIVE ticker.
- R7 (CAP-6, CAP-18): the collection opens on "EN COURS" (the player's sets by closeness to their next tier or completion, plus those just progressed in), then "À DÉCOUVRIR", then a search over every set; the hub shows "SETS EN COURS"; public and friends' profiles show the same, signed out included.
- R8 (CAP-6, CAP-18): a set opens as an album: owned cards, empty slots naming the missing games, its tiers or its "COMPLET" stamp.
- R9 (CAP-6): the grid of every card with its filters and search stays reachable from the collection as "TOUTES LES CARTES".
- R10 (AD-5): the season published with the retired kinds gets its sets rebuilt once, before the public launch; its set completions are dropped.

## Done when

1. Every card of the published season on staging is in at least one set; the UFOs hold under about 5 % of the cards; no set is named by a volume number.
2. The collection opens on the player's sets in progress; a new player sees "À DÉCOUVRIR" filled; the search finds any set.
3. A set opens as an album with its missing cards and its tiers or completion, for its owner and on a public profile signed out.
4. Reaching a tier or completing a set shows at opening, in the feed and in the LIVE ticker.
5. The filtered card grid is reachable from the collection.
6. All of it runs on staging, in French and in English.

## Boundaries

`Catalog` (set kinds, theme list, the builder, card genre), `Steam` (developers and franchises), `Game` (tier rows, events, the opening's response), the collection, album, hub panel and feed lines. Not the back-office curation of the theme list (epic Season preparation), not card backs, titles or menu themes (epic Cosmetics).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- change — _bmad-output/initiative-gameble/change-recognizable-sets/change-recognizable-sets.md, sections 4.1 to 4.7
- spec — _bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md, section Sets (after the change's edits)
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-5, AD-10
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Hub and Collection; DESIGN.md, Collection (after the change's edits)
- forge — _bmad-output/initiative-gameble/forge-card-series/forge-card-series.md

## Notes

- Decision (2026-10-08, author): approved through change-recognizable-sets; the term stays "set" in code, spec and UI.
- Decision (2026-10-08): the spike opens the epic, since the minimum sizes, hall of fame thresholds and theme list decide the builder; story 3 is the tracer: the new kinds appear in today's collection screens on staging.
- Unknown: whether Steam's raw item stored in `steam_apps.details` carries developers and franchises; the spike confirms, story 2 waits on it.
- Unknown: the screens of "EN COURS", the album and the celebration banner are not drawn yet; `bmad-ux` draws them before stories 5, 7 and 8.
- Waits on Steam catalog because: the import, the draft season and the publication.
- Waits on Space terminal: screens because: the collection, its filter zone and search, the hub panel.
- Waits on The Brotherhood because: set completion (6.7), the feed and its visibility (6.1, 6.2), the LIVE ticker (6.4).
