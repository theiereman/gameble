---
id: bug-the-top-bar-title-runs-under-the-steam-sign-in-on-a-signed-out-phone
type: bug
title: "The top bar title runs under the Steam sign-in on a signed-out phone"
parent: none
covers: []
after: []
assignee: ""
refined: true
hitl: false
risk: low
severity: P3
estimate: ""
---

# The top bar title runs under the Steam sign-in on a signed-out phone

## Description

Seen in the build of ticket 16.3: at 390 px, signed out, the shared top bar's screen title (a player's name, or « PROFIL INDISPONIBLE ») runs under the Steam sign-in image. The top bar is shared, so every signed-out page with a screen title may show it.

## Acceptance Criteria

Verify: at 340, 390 and 430 px, signed out, on a public profile, the unavailable profile page, a public card page and Toutes les cartes, the title is truncated or wrapped before the sign-in image and never overlaps it; signed in and on desktop nothing changes.

## References

- plan — _bmad-output/initiative-gameble/epic-screen-walkthrough/story-the-public-profile-shows-a-player-off-plan.md

## Notes

- Filed on 2026-10-19 from the author's decisions on the day's builds.
- Dropped (2026-10-30, author): not worth fixing; the author drops it.
