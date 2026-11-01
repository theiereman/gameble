---
tracker_id: ""
key: ""
type: epic
title: "More achievements, and card backs easy to pick"
parent: initiative-gameble
covers: [CAP-17, CAP-20]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: "envelope"
---

# More achievements, and card backs easy to pick

## Description

Achievements become more numerous and more memorable: new conditions read within one capsule, over streaks, from the games' metadata and from the community, each with a title in the Brotherhood's tone and a short condition, and the ten existing ones are renamed in that tone. Some of them unlock card backs. The Personalization page, functional but hard to read, is reworked so a player picks a back easily and sees how each back was earned. Release 1.1.0, from GitHub issues #66 and #68 and the author's request of 2026-10-30.

## Outcome

For players who open packs every day: more moments to be surprised and rewarded, and backs they understand; the signal is achievements earned beyond the first ten and backs changed on the Personalization page.

## Requirements

Completed at inception, once `bmad-spec` has updated CAP-17. The lines from the source:

- E1 (CAP-17). New achievements, chosen by the author among #66's list and #68's "lazy opener" and "hardworking", with conditions within one capsule, over consecutive openings, on collection quantities and game metadata (studio, release year), and on community actions (discoveries, reposts, repeated trades).
- E2 (CAP-17). Every achievement has a title in the Brotherhood's tone and a short condition, in English and French, and no flavor text (author, 2026-10-31); the ten existing achievements are renamed in that tone without changing their condition or losing what players earned.
- E3 (CAP-17). A new achievement is granted at once to players whose history already meets it, where the history allows; each is granted once.
- E4 (CAP-20). Some new achievements unlock card backs.
- E5 (CAP-20). On the Personalization page a player picks their active back simply and sees, for each back, how they earned it, and for a locked one how to earn it.

## Done when

1. The chosen new achievements are granted in play, each once, in English and French, with their title and condition on the achievements screen.
2. The ten existing achievements show their new names, and no player loses an achievement they had.
3. A player who already met a new achievement's condition before its release holds it after the release, where the history records it.
4. On the Personalization page a player picks a back in one step and reads how each back was earned or can be earned.
5. Release 1.1.0 is on production, its achievement backfill run.

## Boundaries

The achievements and the card backs page, on the Brotherhood and Personalization side. Not secret achievements (#66, part 4, a later extension), not rewards in currency or capsules, not new back artwork beyond the backs the new achievements unlock, not the profile titles or menu themes.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-17 and CAP-20
- spec — _bmad-output/initiative-gameble/spec-gameble/brotherhood-tone.md
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, card backs catalogue
- prior work — _bmad-output/initiative-gameble/epic-card-backs/ and _bmad-output/initiative-gameble/epic-personalization/
- input — https://github.com/theiereman/gameble/issues/66
- input — https://github.com/theiereman/gameble/issues/68
- input — _bmad-output/initiative-gameble/deferred-work.md, the entry on reworking the Personalization page's layout

## Notes

- Decision (2026-10-30, author): the ten existing achievements are renamed in the Brotherhood's tone.
- Decision (2026-10-30, author): the Personalization page is functional but ugly: picking a back must be simpler and each back must say how it was earned. This settles the deferred-work entry asking how to rework the page.
- Decision (2026-11-01, author): the thirteen achievements of `spec-gameble/achievements.md` ship; the four backs go to Luck Is a Marketing Concept (Trèfle fané), Leave Request Denied (Assidu), Market Concentration (Siège social) and A Strictly Professional Relationship (Contrat); First Claim, All Rights Reserved unlocks none (2026-10-31). Excellence in Mediocrity is kept although nearly every player gets it at release.
- Decision (2026-11-01, author): N is 10 for both Lazy Opener and Hardworking.
- Decision (2026-10-31, author): achievements carry no flavor text.
- Decision (2026-11-01, author): the design part of entry 2 is done in `ux-gameble` on 2026-10-31: the Personalization page (`mockups/personalization.html`) and the four backs' art, names and pixel words (`mockups/achievement-backs.html`); entry 2 keeps the achievements' final titles and glyphs.
- Decision (2026-11-01, author): a release grants new achievements from history by running `game:backfill_achievements` from the entrypoint after `db:prepare`, measured on a staging candidate; if the boot time grows too much, it becomes a step of RELEASING.md (entry 4).
- Decision (2026-11-01, author): AD-37 is adopted as written; the epic stays one epic of thirteen entries, the achievements lane serial.
- Decision (2026-11-01): every new achievement is granted from history except Lazy Opener and Hardworking, whose reveal mode is recorded only from entry 3; tracer bullet entry 1 (Statistical Non-Compliance through every layer); entries 1, 2, 3 and 12 can start in parallel.
