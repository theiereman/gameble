---
tracker_id: ""
key: ""
type: epic
title: "Every screen walked through before the release"
parent: initiative-gameble
covers: ["CAP-8", "CAP-10"]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: "entries"
---

# Every screen walked through before the release

## Description

Every screen was built and reviewed one story at a time. Before the last epic before production, the author and an agent walk through every screen of the game together, in one complete session, as a player, a visitor and staff would meet them, and record what works and what does not. Each finding becomes a ticket, a deferred-work entry or a decision, so what must be fixed before the public release is known before the codebase cleanup starts.

## Outcome

For the author: a single, complete view of the game's screens as they stand, with each problem placed before or after the release; the signal is a findings list with no item left undecided.

## Requirements

R1 and R2 are a review and map to no capability; R3 maps to CAP-8 and CAP-10. Each line cites the source it comes from.

- R1. Every screen of the Information Architecture is walked through in one session: signed out, as a player and as staff, in French and in English, on a phone and on a desktop. Source: author, 2026-10-14; EXPERIENCE.md, Information Architecture.
- R2. Every finding is recorded and decided: a ticket to build before the release, a deferred-work entry for after it, or a decision to keep it as it is. Source: author, 2026-10-14.
- R3. The public profile gets a design of its own, for the signed-out visitor, the player and the friend, and is rebuilt to it before the walkthrough: the player's showcase, stats, latest achievements and started sets, the friendship action, and another player's full collection read-only. Source: author, 2026-10-15; spec CAP-8, CAP-10.

## Done when

1. Every screen of EXPERIENCE.md's Information Architecture has been walked through, with each screen marked as walked through.
2. Each screen was seen signed out (where it allows it), as a player and as staff, in French and in English, on a phone and on a desktop.
3. Every finding is recorded with its screen and decided by the author: a ticket before the release, a deferred-work entry, or kept as it is.
4. The tickets to build before the release are in the tree, ordered before epic 12.
5. Before the walkthrough starts, the public profile, the showcase, the friendship action and another player's full collection match DESIGN.md and EXPERIENCE.md.

## Boundaries

A review of the screens as they stand, with the author; no code changes during the session. Not the back-office's UX rework (epic-back-office-ux, after the release), not the codebase cleanup (epic-human-readable-codebase).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Information Architecture and Edge States
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md
- design — _bmad-output/initiative-gameble/ux-gameble/mockups/key-public-profile.html
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-8 and CAP-10

## Notes

- Decision (2026-10-14): one complete session walking through every screen, before the final epic before production (author).
- Decision (2026-10-15): the public profile's UI and UX are reviewed before the walkthrough; bmad-ux designs the screen first, then a story builds it (author).
- Decision (2026-10-15): the public profile rebuild is sliced into five stories, the profile itself as the tracer, then the showcase, its order, the friendship action and another player's collection, in series since all touch the profile (author).
- Decision (2026-10-15): no closing refactor sweep; epic-human-readable-codebase follows (author).
- Waits on every feature epic because: the walkthrough sees every screen once, as players will.
