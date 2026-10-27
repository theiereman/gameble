---
tracker_id: ""
key: ""
type: epic
title: "Sets players recognize"
parent: initiative-gameble
status: done
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
- R2 (CAP-6): a game joins every listed theme among its 5 most-voted Steam tags; a game with none joins the UFOs; the theme list (about forty themes, each grouping one or more tags, French and English names) lives in code; the UFOs hold under about 5 % of the catalog.
- R3 (CAP-6): franchise and studio sets come from Steam's `franchises` and `developers`, kept on each card by the import, with the minimum sizes and filters of `catalog-and-rarity.md` Sets.
- R4 (CAP-7): a card's genre is its main theme (the listed theme with the most votes among its top 5 tags); a card in the UFOs shows no genre.
- R5 (CAP-6; AD-10): theme and hall of fame sets have bronze, silver and gold tiers (10 %, 25 %, 50 % of their distinct cards) and complete at 100 %; franchise, studio and UFO sets are complete or not; each tier or completion reached for the first time on a published-season set writes one row, recording how it was reached, and publishes one event. From the next published season, every set of every kind is tiered by its size instead: zero to five ranks (Novice, Apprenti, Adepte, Expert, Maître) counted from the top, the last before completion always Maître, then complete, shares rounded up (`catalog-and-rarity.md`, Tiers); published seasons keep bronze, silver and gold.
- R6 (CAP-13): a tier reached or a set completed at opening shows a celebration after the reveal; the tiers and completions one opening reaches make one line in the feed and one in the LIVE ticker, naming the highest and the count.
- R7 (CAP-6, CAP-18): the collection opens on "EN COURS" (the player's sets by closeness to their next tier or completion, plus those just progressed in), then "À DÉCOUVRIR", then a search over every set; the hub shows "SETS EN COURS"; public and friends' profiles show the same, signed out included.
- R8 (CAP-6, CAP-18): a set opens as an album: owned cards, empty slots naming the missing games, its tiers or its "COMPLET" stamp.
- R9 (CAP-6): the grid of every card with its filters and search stays reachable from the collection as "TOUTES LES CARTES".
- R10 (AD-5): the retired kinds are removed before the public launch, with their sets' completions; the set kind check holds only the five kinds.
- R11 (CAP-6, CAP-7; AD-5): any edition of a member counts for a set; the collection shows one card per game, its best owned rarity and copies across editions; the total counter never drops at publication.

## Done when

1. Every card of the published season on staging is in at least one set; the UFOs hold under about 5 % of the cards; no set is named by a volume number.
2. The collection opens on the player's sets in progress; a new player sees "À DÉCOUVRIR" filled; the search finds any set.
3. A set opens as an album with its missing cards and its tiers or completion, for its owner and on a public profile signed out.
4. Reaching a tier or completing a set shows at opening, in the feed and in the LIVE ticker.
5. The filtered card grid is reachable from the collection.
6. A copy of any season counts for the published season's sets, and the collection shows one card per game with a total counter that does not drop when a season is published.
7. All of it runs on staging, in French and in English.

## Boundaries

`Catalog` (set kinds, theme list, the builder, card genre), `Steam` (developers and franchises), `Game` (tier rows, events, the opening's response), the collection, album, hub panel and feed lines. Not the back-office curation of the theme list (epic Season preparation), not card backs, titles or menu themes (epic Cosmetics).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- change — _bmad-output/initiative-gameble/change-recognizable-sets/change-recognizable-sets.md, sections 4.1 to 4.7
- spec — _bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md, section Sets (after the change's edits)
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-5, AD-10
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Hub and Collection; DESIGN.md, Collection (after the change's edits)
- forge — _bmad-output/initiative-gameble/forge-card-series/forge-card-series.md
- change — _bmad-output/initiative-gameble/change-season-carryover/change-season-carryover.md, sections 4.1, 4.5, 4.6, 4.8
- change — _bmad-output/initiative-gameble/change-set-tiers-by-size/change-set-tiers-by-size.md, sections 4.1 to 4.6

## Notes

- Decision (2026-10-08, author): approved through change-recognizable-sets; the term stays "set" in code, spec and UI.
- Decision (2026-10-08): the spike opens the epic, since the minimum sizes, hall of fame thresholds and theme list decide the builder; story 3 is the tracer: the new kinds appear in today's collection screens on staging.
- Settled (2026-10-09, spike): Steam's raw item in `steam_apps.details` carries developers (99.9 % of cards) and franchises (21.8 %) under `basic_info`, with HTML entities to unescape; story 2 reads them from there.
- Unknown: the screens of "EN COURS", the album and the celebration banner are not drawn yet; `bmad-ux` draws them before stories 5, 7 and 8.
- Waits on Steam catalog because: the import, the draft season and the publication.
- Waits on Space terminal: screens because: the collection, its filter zone and search, the hub panel.
- Waits on The Brotherhood because: set completion (6.7), the feed and its visibility (6.1, 6.2), the LIVE ticker (6.4).
- Decision (2026-10-09, author, agreed from the spike report `spike-sets-on-real-data-report.md`): franchises need at least 3 games and are dropped when named like a developer or publisher of the catalog or when no more than half of their games' titles share a whole word of their name, with the fixes listed in the report's section 2 (about 188 sets).
- Decision (2026-10-09, author, agreed): studios are the first developer only, names normalized, with at least 3 games and a most-reviewed game of at least 20,000 reviews (about 254 sets).
- Decision (2026-10-09, author, agreed): the theme list is the 42 themes of `spike-sets-on-real-data-probes/probe-3.rb`, an Adult theme included; the UFOs hold 4.35 % of season 2's cards.
- Decision (2026-10-09, author, agreed): hall of fame thresholds are Les Intouchables ≥ 97 % and ≥ 20,000 reviews, Les Pépites ≥ 98 % and < 1,000 reviews, Les Mal-aimés 40–69 % and ≥ 20,000 reviews, Les Phénomènes ≥ 200,000 reviews (about 90 to 100 cards each).
- Decision (2026-10-09, author, agreed): tiers are bronze 10 %, silver 25 %, gold 50 % of a theme's or hall of fame set's distinct cards, replacing 25 / 50 / 100 %: at the published odds gold at 100 % needs every Légendaire of the set, which packs alone never give.
- Decision (2026-10-14, author): any edition counts for a set and the collection shows one card per game (change-season-carryover, R11); entries 5, 7 and 8 amended, entry 15 added, entries 13 and 14 after it; the collection season selector plan is dropped.
- Decision (2026-10-14, author): the season mark and season count on a tier ("Or · 12 saisons") move from entry 8 to epic-seasons-carry-over, entry 3; production has one season at launch.
- Unknown: the edition count on the tile and the ÉDITIONS row are drawn with bmad-ux before entry 15.
- Decision (2026-10-15, author): no rebuild of season 1. Staging published a themed season 2, so season 1's retired sets show only on its own card pages and earn no tier; entry 4 becomes a migration that deletes the retired kinds' sets and completions, narrows the kind check, and removes the retired-kind code (AD-5, AD-10 amended).
- Decision (2026-10-15, author): the tier celebration banner as built on staging looks bad; entries 16 (redrawn with bmad-ux, hitl) and 17 (rebuilt to it) follow entry 5.
- Settled (2026-10-15, author): entry 5 done; staging's POST /packs over 14 openings on seasons 1 to 4: p50 67 ms, max 189 ms (the first, cold, after deploy), 45 to 60 queries each.
- Decision (2026-10-19, author): set tiers cut by set size for every kind, ranks Novice, Apprenti, Adepte, Expert, Maître then complete, from the next published season (change-set-tiers-by-size); supersedes the 2026-10-09 bronze, silver and gold shares for later seasons. Entries 21 (rank marks designed, hitl), 22 (tiers cut by size) and 23 (marks, album and celebration rebuilt) added; the next season published on staging waits for 22 and 23.
- Decision (2026-10-19, author, entry 21): ranks count from the top: the last tier before completion is always Maître, a smaller set drops ranks from Novice up (change-set-tiers-by-size, fourth decision).
