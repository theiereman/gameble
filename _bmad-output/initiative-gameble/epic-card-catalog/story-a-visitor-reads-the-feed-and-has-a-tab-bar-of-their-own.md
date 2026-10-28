---
id: 9
tracker_status: done
tracker_id: ""
type: story
title: "A visitor reads the feed and has a tab bar of their own"
parent: epic-card-catalog
covers: [R4]
after: [8]
hitl: false
risk: low
---

# A visitor reads the feed and has a tab bar of their own

## Description

Follow-up of 14.8 (author, 2026-10-20): the activity feed opens again to a signed-out visitor, read-only, and the landing's "Ouvrir le fil d'activité" works again (not greyed); on the phone a visitor's tab bar has two tabs, ACCUEIL (the landing) and TOUTES LES CARTES (/library/cards), instead of five greyed ones. The same change brings EXPERIENCE.md in line with 14.8 and these decisions: every row that still names the signed-out hub, the sign-in panel or "visiter le jeu sans compte" (Information Architecture, Copy deck, landing Hero and 09, public card page, public profile, capsule and feed rows, Flows 5 and 6, open questions), and the restored line that signing in accepts the terms and the privacy notice beside each game-styled Steam sign-in.

## Acceptance Criteria

Verify: Signed out, in fr and en: the feed opens read-only with no ownership actions, the landing's feed link opens it, the phone tab bar shows ACCUEIL and TOUTES LES CARTES; signed in unchanged; EXPERIENCE.md has no row describing the signed-out hub or the sign-in panel as current; full suite, vitest, packwerk, rubocop, typecheck pass.

## References

- parent — _bmad-output/initiative-gameble/epic-card-catalog/epic-card-catalog.md

## Notes

- Decision (author, 2026-10-20) on 14.8's open questions: reopen the feed to visitors; a two-tab visitor tab bar. /legal and /invite/:token stay open to visitors as 14.8 left them.
