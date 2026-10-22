---
id: 2
tracker_status: done
tracker_id: 187
remote: https://github.com/theiereman/gameble/issues/187
type: story
title: "An administrator curates the theme list in the back-office before publishing"
parent: epic-season-preparation
covers: [CAP-6]
after: [1, 13.3]
hitl: true
risk: medium
---

# An administrator curates the theme list in the back-office before publishing

## Description

A back-office screen lists every Steam tag the import met with its game count; the administrator marks each tag as a theme, with French and English names (English tag name by default), or as not a theme; the preview shows each theme's size and the UFOs' share; a draft with an unclassified tag, or whose UFOs exceed the agreed share, cannot be published; replaces the theme list in code (13.3), seeded from it.

## Acceptance Criteria

Verify: Marking Roguelite as a theme and rescoring moves those games into it in the preview and lowers the UFOs' share; a new unclassified tag, or a UFOs' share above the limit, blocks the publish with a reason; a renamed theme shows its names as the card's genre.

## References

- parent — _bmad-output/initiative-gameble/epic-season-preparation/epic-season-preparation.md

## Notes

- après un import et avant de publier une saison je peux voir tous les genres qui ont été ajoutés et c'est moi qui décide lesquels fusionner vers un genre
- il faut tout classer avant de pouvoir publier ; le nom anglais sert par défaut mais je dois pouvoir entrer les traductions manuellement
