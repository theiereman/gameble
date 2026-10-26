---
id: 30
tracker_status: done
tracker_id: 258
remote: https://github.com/theiereman/gameble/issues/258
type: story
title: "Profile and settings use the width of a large screen"
parent: epic-screen-walkthrough
after: [28]
hitl: true
risk: low
---

# Profile and settings use the width of a large screen

## Description

On a desktop the Profil et paramètres screen (`app/views/settings/show.html.erb`) does not use the room a large screen offers, as the friends screen does (author, 2026-10-23, on staging); the screen is otherwise fine. Lay it out for the width: with the author, arrange the profile summary, the visibility and animation settings, the card-back picker and the legal and account links in columns or areas that fill a wide screen and stay in one column on the phone, in the way settled for the friends screen in 16.28 so the wide screens read alike; the settings' behavior, the back button and the language change keep working; EXPERIENCE.md's Profil et paramètres row and DESIGN.md follow.

## Acceptance Criteria

Verify: On a desktop width the screen fills its width in the agreed arrangement with every setting and the card-back picker reachable, the phone stays one column, the language change and the back button behave as before; checked by the author on staging in French and in English; the settings system tests (retrying matchers) and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 22), author, 2026-10-23: the same wide-screen gap as the friends screen; check the other single-column screens (Comment ça marche, the legal page, Succès, the feed) for it as they are walked.
