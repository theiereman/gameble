---
tracker_id: ""
key: ""
type: epic
title: "Card backs"
parent: initiative-gameble
covers: [CAP-20, CAP-23]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Card backs

## Description

Players earn card backs by reaching a theme or hall of fame set's back tier, contributing to a successful weekly goal, some achievements, and events, and choose the one their own face-down cards wear. Profile titles and menu themes are epic-profile-titles-and-themes.

## Outcome

For a player: a visible reward for completing sets and for taking part in the Brotherhood.

## Requirements

The lines of CAP-20 (spec) and the card backs part of CAP-23, with the author's answers of 2026-10-28 (`inception-proposal.md`, section 7). The back catalogue is in `DESIGN.md`, Card backs.

- R1 (CAP-20): every account has the Standard back. A theme or hall of fame set's back tier (its first tier at or above half its cards; gold in seasons published before the tier table) unlocks that set's back; the first contribution to a successful weekly goal unlocks Semaine 38; the achievements boosters_100, first_legendary and three_complete_sets unlock Centurion, Étoile d'or and Aurore; Saison 1, Millésime 2017 and Soldes d'hiver are granted by an administrator to a group. Each back unlocks once per player; later weekly goals grant no back. The goal back is granted when the reward is earned, not when it is claimed.
- R2 (CAP-20): a locked back states its unlock condition.
- R3 (CAP-20): a set back carries the mark of each season it was earned in; the player picks which season's mark the active back wears.
- R4 (CAP-20): the player picks one active back in the profile; it applies from the next pack opened.
- R5 (CAP-20): only the player sees their back, on their own face-down cards at opening; never on the detail of a card, nor on another player's cards or profile.
- R6 (CAP-20, `DESIGN.md` Card backs): the 46 set backs share one anatomy drawn by the pixel art export, with a word, colours and a motif per set approved by the author.
- R7 (CAP-20): backs earned before this epic ships (tiers, achievements, goal rewards) are granted once at its deploy.
- R8 (CAP-23): the seasonal allocation screen's recap lists the card backs earned in the season that ended.

## Done when

1. Every account has the Standard back; a locked back states its unlock condition.
2. Reaching a theme or hall of fame set's back tier (its first tier at or above half its cards; gold in earlier seasons), the first contribution to a successful weekly goal and the listed achievements unlock their backs, once each. A back earned again in a later season gains that season's mark, not a second unlock. Players who earned them before this epic ships receive them once at its deploy.
3. The player picks one active back in the profile; it shows on their own face-down cards from the next pack opened, and to nobody else. The player picks the season mark the active back wears.
4. An administrator can grant a back to a group of players for an event.
5. The seasonal allocation screen lists the backs earned in the season that ended.
6. All of it is live in production.

## Boundaries

The back catalogue in code, unlocks and the active back in `Game`, the back picker, the exported back assets, the back on the booster, and the backs in the seasonal recap. Not the events that unlock them (epics 6, 13 and 17 publish them), not the allocation screen itself (17.2), not the special packs' look (epic 19: their cards wear the active back), not profile titles and menu themes (epic-profile-titles-and-themes), not backs for franchise, studio and UFO sets, not a back shown to another player, not per-season redrawn backs, not a purchase or trade of backs.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-20
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-10, AD-25
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Card backs; EXPERIENCE.md, Profil et paramètres

## Notes

- Open question: which backs ship and their unlock rules (spec). Answered 2026-10-28 (R1).
- Decision (2026-10-05): its own epic after epic 6, once every unlocking event exists. Approved by the author.
- Decision (2026-10-07): this epic is not part of the MVP; it is built after the public launch (author). Epics 5 and 6 publish the events it will consume (SetCompleted, the goal reward, achievements).
- Decision (2026-10-08, author): renamed from "Card backs"; backs unlock on gold, titles and menu themes join (CAP-22, change-recognizable-sets). The folder keeps its name. Waits on epic-recognizable-sets for the set tier and completion events.
- Decision (2026-10-14, author): backs and titles carry season marks; a back is unlocked once and gains a mark per season it is earned in; titles are counted by set kind, key and tier across seasons (change-season-carryover). epic-seasons-carry-over waits on this epic for the backs its recap lists.
- Decision (2026-10-19, author): set tiers cut by set size (change-set-tiers-by-size): a set's back unlocks on its back tier, its first tier at or above half its cards (gold in earlier seasons); titles for each tier and the completion of any set, the tier's rank as title ("Adepte · Roguelike"), earlier seasons' bronze, silver and gold giving the same Apprenti, Adepte and Maître titles as those tiers, one title per set and rank (author, 2026-10-19); menu themes on 3, 10 and 25 complete sets. Done when 2, 5 and 6 amended; waits also on the tier table by set size (13.22).
- Source conflict: CAP-20 and AD-25 — the back shows "faded on the detail of a card they do not own" vs `EXPERIENCE.md`, Card backs: "the card detail no longer shows it for a card not owned" (author, 2026-10-20).
- Decision (2026-10-28, author): the faded back is dropped (R5); CAP-20 and AD-25's last rule are to be corrected through bmad-spec and bmad-architecture.
- Decision (2026-10-28, author): the 8 prototype backs ship (R1); the set backs share one generated anatomy (R6); the goal back is granted when the reward is earned; special packs' cards wear the active back; profile titles and menu themes (CAP-22) leave this epic for epic-profile-titles-and-themes, which follows it.
- Decision (2026-10-28, author): the MVP is everything before 1.0.0, and this epic follows it in release 1.2.0, after epics 17 and 19. Epic 17 ships its recap without backs; entry 2 also answers 17.1's allocation receipt, entry 8 adds the backs to 17.2's screen, and entries 2 and 7 grant the backs earned before the deploy (R7). Entry 5 follows 19.5 on the booster.
- Decision (2026-10-28): tracer bullet is entry 1 (catalogue, unlock rows, active back stored on the opened pack). After it, three lanes: art (3), unlock rules (2 then 7), picker (4); then 5, 6 and 8 in series on the booster and the recap; the refactor sweep closes the epic.
- Waits on epic 17 because: set backs are also earned by tiers received at a season change (17.1), and the recap screen that lists them is 17.2.
- Waits on epic 19 because: the special packs change the booster island and the pixel art export first (19.3 to 19.5).
