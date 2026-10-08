---
tracker_id: ""
key: ""
type: epic
title: "Collection and sharing"
parent: initiative-gameble
covers: [CAP-6, CAP-7, CAP-8, CAP-9, CAP-18]
after: []
assignee: ""
status: done
risk: medium
estimate: ""
estimate_basis: ""
---

# Collection and sharing

## Description

A player browses their collection by set in the library, opens a card's detail, has a public profile, and shares a card as a link. A visitor without an account can look at all of it.

## Outcome

For a collector: sets to complete, with empty slots that name what is missing. For anyone with a link: a page that makes them want to play.

## Requirements

- R1 (CAP-6; `catalog-and-rarity.md`, Sets; EXPERIENCE.md, Library): the library, reached from the attic's lectern, shows the published season's sets — publisher sets, tomes and best rated of the year — as tomes on shelves, each with its name and owned / total distinct cards for the viewer (a card in several sets counts in each; duplicates count once per card).
- R2 (CAP-6; EXPERIENCE.md, Tome, Empty slot): a tome opens onto its slots in order: an owned card shows its face (with the number of copies when more than one), a missing one is an empty slot naming the game.
- R3 (CAP-7; AD-18): a card's detail shows its art, title, short description, release year, rarity, season, sets (each leading to its tome), publisher with a notice that the game and its image belong to their owners (story 2.10, replacing the per-game copyright), and a link to its Steam store page; text in the viewer's language; the description appears only here.
- R4 (CAP-8; AD-15): each player has a public profile at a link built on their random token, showing their collection and set progress; it is reachable signed out.
- R5 (CAP-9; AD-15): a player shares a card they own as a link to the card's own page, which shows the card only, never who shared or holds it (author, 2026-10-03; story 4.7); its preview on Discord, X and WhatsApp carries the card's title and rarity and no game image.
- R6 (CAP-18; AD-15): signed out, a visitor opens the library (every slot empty), a public profile and a card's detail; no URL, page or response exposes a database id.
- R7 (AD-18; epic 2 Decision): set names and genre labels are rendered from locale keys (`catalog.sets.*`, `catalog.genres.*`) using `catalog_sets.params`, in French and English.

## Done when

1. The library shows publisher sets, tomes and "best rated of the year" sets, each with owned / total and empty slots naming the missing game.
2. A card's detail shows its title, description, year, rarity, season, sets, publisher, and a link to its Steam page.
3. A shared link opens the card's own page, with no owner shown; its preview on Discord, X and WhatsApp carries the title and rarity and no game image.
4. Signed out, a visitor can open the library with empty sets, a public profile and a card's detail.
5. No URL, page or response exposes a database id.

## Boundaries

The library, tome, card detail, public profile and share link. Not trades or the feed.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Capabilities
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-11, AD-15, AD-18
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, sections Information Architecture, State Patterns

## Notes

- Decision (2026-10-02): breakdown of six stories drafted by the orchestrator under the author's standing instruction; judged through the epic retrospective (author, 2026-10-03).
- Decision (2026-10-02): tracer bullet is story 1: the lectern leads to a library listing the season's sets with the viewer's progress, through Catalog and Game queries, set labels and the visitor view.
- Decision (2026-10-03, author): a public profile is titled with the player's Steam persona name, refreshed at each sign-in; "Brother" plus a short code from the token is the fallback when no name is stored. The name is personal data that epic 7's export and deletion must cover.
- Decision (2026-10-02): the status band's counts per rarity (EXPERIENCE.md) are not in this epic's Done when; left for a later story.
- Decision (2026-10-02): a closing refactor sweep (story 6) follows the other stories.
- Note (story 4.4): the player token is a public, non-secret handle (the profile link `/<locale>/brothers/<token>`); friend invites (epic 5) use a separate secret, never the token; revoking a profile link is "hide profile" (epic 7); the stored persona name (`accounts_players.persona_name`) is personal data that epic 7's export and deletion must include.
- Decision (2026-10-08): R1's lectern and tomes on shelves, and R2's tome, are superseded by epic-space-terminal-redesign R1 (the hub replaces the attic) and epic-space-terminal-screens R1 and R7 (stories 10.1 and 10.7: the collection with set progress rows and a set grid); kinds, progress and empty slots naming the game are kept.
- Decision (2026-10-08): the per-card ownership notice of R3 moves to the legal page (pending-approvals, settled 2026-10-05); story 7.3 removes `card_details.notice`.
- Closed (2026-10-08): the status band's per-rarity counts were built by story 10.1 (the collection's report panel); link previews on Discord, X and WhatsApp were checked by the author on staging (pending-approvals, 2026-10-06), the Cloudflare rule for production remaining an open pending approval.
- Closed (2026-10-08): all seven stories done, verified by the author; carried elsewhere: the persona name in the data export (story 7.7), throttling or caching public pages (story 7.10), a friend's public profile from the Friends screen (story 5.13), card detail previous and next (bug 10.8); the tome rework waits on the author (pending-approvals, "Tomes to rethink").
