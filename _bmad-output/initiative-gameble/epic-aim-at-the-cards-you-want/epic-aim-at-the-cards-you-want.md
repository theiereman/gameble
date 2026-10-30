---
tracker_id: ""
key: ""
type: epic
title: "Aim at the cards you want"
parent: initiative-gameble
covers: [CAP-6, CAP-27, CAP-28]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: "envelope"
---

# Aim at the cards you want

## Description

A player stops collecting only at random: they see how much of each rarity they own against what the game holds, compose sets of their own from the cards they want or from the games they own on Steam, and pick a few active goals whose progress and missing cards the game keeps in front of them. Release 1.1.0, from GitHub issues #221, #214 and #64 (its first part), kept by the author on 2026-10-30.

## Outcome

For players with a growing collection: they know what they are missing and work towards chosen cards; the signal is players with at least one custom set or active goal, and goals completed.

## Requirements

Completed at inception, once `bmad-spec` has added the new capabilities. The lines from the source:

- E1 (CAP-6). The collection's rarity legend pop-up shows, for each rarity, the distinct cards owned and the total the game holds, for the published season and overall (#221); the author details at inception what more the pop-up offers.
- E2 (CAP-27). A player composes custom sets from cards they choose, and follows them like the game's sets: owned / total, album with the missing slots (#214).
- E3 (CAP-28). A player picks three to five active goals among the game's sets and their custom sets, sees their progress and their missing cards highlighted, and changes them freely; whether goals show on the profile and the bridge is settled at inception (#64).
- E4 (CAP-28). Active goals never change drop rates nor guarantee a card (#64).
- E5 (CAP-27). A player creates one custom set from the catalog games they own on Steam, with no size cap, synced with their library once a day; it is a special set, apart from the 10 custom sets, never an active goal nor a source of trade suggestions; it grants no card, and when Steam does not share the library the screen says so (author, 2026-10-30).

## Done when

1. In English and French, the rarity legend pop-up of the collection shows owned and total distinct cards per rarity, for the season and overall.
2. A player creates, edits and deletes a custom set, and opens it as an album with its missing slots.
3. A player sets three to five active goals, sets or custom sets, and sees each one's progress and missing cards where the collection shows them.
4. Pack draws are unchanged by goals: the pack odds tests pass untouched.
5. A player whose Steam game details are public creates their Steam library set, sees a game added to their library appear in it by the next day, and finds its list in their data export; deleting it erases that list.

## Boundaries

The collection and its sets, on the Collection side. Not the trade suggestions built on the goals (epic-trade-suggestions), not targeted boosters, not secret achievements tied to goals.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-6, CAP-27 and CAP-28
- spec — _bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md, Sets
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md and EXPERIENCE.md, Collection
- input — https://github.com/theiereman/gameble/issues/221, with its comments (owned / total per rarity, this season and overall)
- input — https://github.com/theiereman/gameble/issues/214
- input — https://github.com/theiereman/gameble/issues/64, parts 1 and 3, with the author's comment (three to five goals)
- input — the author's request of 2026-10-30: a custom set built from the games owned on Steam

## Notes

- Decision (2026-10-30, author): #221, #214 and #64 go to release 1.1.0; the trade suggestions of #64 are their own epic so 1.1.0 can ship without them.
- Decision (2026-10-30, author): three to five active goals at once, since sets share cards (#64, author's comment).
- Settled in the spec (2026-10-30): the rarity legend's filter, totals and place (CAP-6); custom set limits, private sets and tiers without reward (CAP-27); goals on the bridge, and on the profile for game sets only (CAP-28).
- Decision (2026-10-30, author): the Steam library set has no size cap and syncs once a day; it is a special set kept out of the costly operations (active goals, trade suggestions); the spec's Steam profile data and Catalog source constraints carry the exception.
- Unknown: the architecture rule letting a daily background job read a player's library within the Steam Web API's quota; `bmad-architecture` settles it before the story is built.
- Follow-up: the legal page's stored-data line and the privacy notice name the library list.
- Decision (2026-10-30, inception): twelve entries. The tracer bullet is entry 3, a custom set created and opened as an album through every layer. Entries 1, 2 and 6 run in parallel from the start; entry 3 then opens the custom sets lane (4, 5) and the goals lane (9, 11), entry 10 waits on both, and the library lane (7, 8) waits on 3 and 6. A closing refactor sweep (12) is kept.
- Decision (2026-10-30, author): the screens are designed first with `bmad-ux`, in a hitl entry (2) every screen entry waits on, rather than in each build.
- Decision (2026-10-30, author): the collection pages' top-bar counter opens the same rarity legend as the other pages' counter (entry 1).
- Decision (2026-10-30, inception): the high-risk entries 3, 7 and 9 (schema, a background job on Steam, the goals table) are each checked by the author on staging before the next entry of their lane starts.
- Decision (2026-10-30, inception): the backlog bug on the legal page's stored-data line is built before entry 8, which edits the same pages.
