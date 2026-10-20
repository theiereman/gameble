---
remote: https://github.com/theiereman/gameble/issues/103
tracker_id: 103
key: ""
type: epic
title: "Visitors meet gameble"
parent: initiative-gameble
covers: [CAP-1, CAP-13, CAP-24, CAP-25]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Visitors meet gameble

## Description

A signed-out visitor at /fr or /en meets the landing designed on 2026-10-14: the Brotherhood's mission, what gameble is, live activity from the game, how it works, what there is to unlock, the roadmap, the open-source project and the free model, then the way aboard. The landing ships only once its conditions hold: the lore text in both languages, the pioneer on the card detail, the roadmap's milestones in the database curated in the back-office, the app on JetBrains Mono and the repository public with a licence. The full roadmap page and the pioneer row are designed in this epic, then built.

## Outcome

For a visitor who knows nothing of gameble: a first page that makes them want to play, ending in a Steam sign-in or a visit to the repository; the spec's success signal, through players who were not invited by a friend.

## Requirements

- R1 (CAP-24): signed out, the landing shows its top bar, the lamp hero, the nine modules and the footer as `EXPERIENCE.md` and `DESIGN.md` (Landing) describe them, in French and English, on phone and desktop, under the enforced CSP; a signed-in player never sees it.
- R2 (CAP-24): the landing shows live activity: the five latest feed entries in module 04, inserted one at a time, the season and its three facts, and the weekly goal with its participants in module 02; each data block is cached per locale.
- R3 (CAP-24): the landing moves as designed (the lamp, module power-on, the star field drift, the side position gauge, the draggable cards passing over the content on desktop) and every motion gives way to reduced motion.
- R4 (CAP-24): a visitor's « Animations réduites » switch is remembered in a cookie the server reads from the first paint, and an "on" switch sets the account's setting at sign-in.
- R5 (CAP-25): the roadmap module shows milestones and a few player-facing stories with their status, from the database: one milestone per initiative epic is created automatically on deploy (the epic's title, to come) without ever editing or deleting one, and staff curate each milestone's and story's wording in both languages, visibility, status and order in the back-office; a stale roadmap is accepted; a link leads to the full roadmap page.
- R6 (CAP-13): the card detail names a card's pioneer to every viewer allowed to see that player's profile, and « anonyme » to anyone else; each edition has its own pioneer.
- R7 (CAP-1): signed out, the root (/fr, /en), the wordmark, signing out and deleting the account land on the landing; the signed-out hub keeps an address of its own, reached from the landing and the public card page.
- R8 (Constraints, Landing ship conditions): the lore text exists in French and English and fills module 02, the app uses JetBrains Mono, the roadmap's milestones are created from the initiative and curated in the back-office, the pioneer is built and the repository is public with a licence file, before the root switches to the landing.

## Done when

1. Signed out, /fr and /en show the landing in their language on phone and desktop with no CSP report; signed in, the same addresses show the hub.
2. A pack opened by a player appears at the top of module 04 of an open landing without a reload, and module 02 shows the current weekly goal with its participants.
3. With « Animations réduites » on, nothing on the landing moves on its own; switched on as a visitor, the setting is on in the account after sign-in.
4. The roadmap module and the full roadmap page show the milestones and stories staff chose to show, with the wording and status staff gave them in the back-office, and a deploy adds a milestone for a new epic of the initiative without touching the others.
5. A card detail names its pioneer, or « anonyme » to a viewer not allowed to see that profile.
6. Signing out and deleting an account land on the landing in production, and the signed-out hub is reached from the landing and the public card page.

## Boundaries

The visitor landing, the full roadmap page, the roadmap's data with its automatic milestones and its back-office pages, the pioneer row, the app-wide font and the signed-out root. Not the credits (story 7.59), the hub itself or the signed-out hub's content, which stay as they are.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-1, CAP-13, CAP-24, CAP-25
- constraint — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Constraints, Landing ship conditions
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Landing sections and Implementation notes (the mock deviations not to copy)
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Landing sections
- design — _bmad-output/initiative-gameble/ux-gameble/mockups/landing.html, the reference render
- lore — _bmad-output/initiative-gameble/spec-gameble/lore.md
- tone — _bmad-output/initiative-gameble/spec-gameble/brotherhood-tone.md, the landing exception
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, the pioneer read through `Game::Visibility`

## Notes

- Decision (2026-10-17, author): the landing build is its own epic, not more entries in epic 7; 7.56 is dropped and replaced by this epic.
- Decision (2026-10-17, author): the full roadmap page is designed and built in this epic, so the roadmap module ships with its link.
- Decision (2026-10-17, author): the pioneer row and the roadmap page are designed in a `bmad-ux` session (story 3) before their builds.
- Decision (2026-10-17): tracer bullet is story 2, the landing's shell with static copy at a provisional address; the root switch (story 15) closes the feature work, after every ship condition holds; the lamp hero, the least certain piece, follows the tracer.
- Decision (2026-10-17): stories 1, 3 and 10 can start at once; after story 2, stories 4, 5, 7 and 9 touch separate code.
- Assumption: the licence ship condition already holds (the GitHub repository is public with an AGPL-3.0 `LICENSE`, checked 2026-10-17); story 15 checks it again.
- Unknown: what « cette semaine » and « aujourd'hui » mean for the season facts; story 5 waits on it.
- Decision (author, 2026-10-20): the landing's sample cards are the published season's top card of each rarity, no curated list.
- Unknown: the signed-out hub's own address; story 15 settles it.
- Source conflict: architecture-gameble.md, the pioneer — it still cites `later-roadmap.md` as the pioneer's home vs the spec, where the pioneer moved into CAP-13 on 2026-10-14.
- Waits on epic 7 because: the enforced CSP (7.10) and the public pages' throttling and caching (7.55).
- Waits on epic 6 because: the feed (6.1), the weekly goal (6.3), the live broadcasts (6.4) and the first discoveries (6.7).
- Decision (2026-10-17): the landing's search-engine work moved here from epic 7 (was 7.16, now 18), after the root switch; keeping it in epic 7 would make epics 7 and 20 wait on each other.
- Decision (2026-10-19, author): the roadmap lives in the database instead of being generated from the initiative into the repository; story 10 (the generated roadmap, its CI drift check and its AGENTS.md rule) is dropped and replaced by story 19. Milestones are created automatically, one per initiative epic, and never edited or deleted by that pass; staff curate wording, visibility, status, order and stories in the back-office. Keeping a generated roadmap in step must not become a chore for every contributor, and a stale roadmap is accepted.
