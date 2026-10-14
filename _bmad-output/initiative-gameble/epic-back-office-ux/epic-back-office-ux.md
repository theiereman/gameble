---
tracker_id: ""
key: ""
type: epic
title: "Staff find their way around the back-office"
parent: initiative-gameble
covers: []
after: []
assignee: ""
risk: low
estimate: ""
estimate_basis: "envelope"
---

# Staff find their way around the back-office

## Description

The back-office grew one page at a time, story by story: the Steam import runs, the seasons and their publication, the card preview, the jobs, and moderation (the report queue, the player search, the bans and the history). This epic reworks its user experience once the game is public, so moderators and administrators reach each task quickly and understand each page without knowing how it was built. It is built after the public launch; its scope is worked out with the author in a dedicated session before inception.

## Outcome

For moderators and administrators: the everyday tasks (handle a report, ban or unban a player, run an import, publish a season) take fewer steps and no guessing; the signal is that a new moderator handles a report without being shown how.

## Done when

1. From the back-office's first page, a staff member reaches every page their role allows in one step, and sees no page it forbids.
2. Every back-office page uses the same navigation, headings and page layout.
3. Handling a report, banning and unbanning a player each take no more steps than today, and say what happened after each action.
4. Every back-office page works in French and in English, and on a phone for the moderation pages.

## Boundaries

The back-office's navigation, layout and moderation and administration screens. Not new moderation rules or new staff powers (epic-public-launch-readiness), not the season preparation tools themselves (epic-season-preparation), not the player-facing screens.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-2, CAP-3 and CAP-15
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Information Architecture

## Notes

- Decision (2026-10-14): the epic is added as an envelope, built after the public launch, and detailed in a dedicated session with the author before inception (author).
- Open question: which pages and which pains come first (the moderation pages, the import runs and seasons, the dashboard, the job queue).
- Open question: whether the back-office keeps the space terminal look of the game or gets a plainer, denser look of its own.
- Open question: whether the moderation pages must work on a phone.
- Waits on epic 12 because: it comes after the public release, once the back-office's pages are all written.
