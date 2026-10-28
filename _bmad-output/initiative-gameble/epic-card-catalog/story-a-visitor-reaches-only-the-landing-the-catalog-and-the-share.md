---
id: 8
tracker_status: done
tracker_id: ""
type: story
title: "A visitor reaches only the landing, the catalog and the shared pages"
parent: epic-card-catalog
covers: [R4, R5]
after: [5]
hitl: false
risk: medium
---

# A visitor reaches only the landing, the catalog and the shared pages

## Description

A signed-out visitor reaches only the landing, Toutes les cartes and its card detail, the public card page, public profiles with their albums, and Comment ça marche; the hub, the collection entry (/library), a set album outside a public profile, the feed and every other page redirect a visitor to the landing. The GAMEBLE link leads a visitor to the landing from every page, Toutes les cartes included. The landing's "Embarquer sur le pont" becomes the Steam sign-in (POST to Steam's auth, returning to the hub). Every action that needs an account shows greyed and disabled for a visitor, with nothing else (ÉCHANGE and SIGNALER on a public profile, the tab bar and menu entries a visitor cannot open, etc.); the sign-in panel and its triggers are removed. The visitor's À DÉCOUVRIR section built by 14.7 is removed with the collection entry. EXPERIENCE.md (Navigation's signed-out visitors, landing Hero, Signed out, Friendship action, Sign-in panel rows) records the rules (author, 2026-10-20).

## Acceptance Criteria

Verify: Signed out, in fr and en, on phone and desktop: the landing, /library/cards, a card detail, a public card page, a public profile and its album, and Comment ça marche open; the hub, /library, the feed, trades, friends and achievements redirect to the landing; GAMEBLE leads to the landing from Toutes les cartes; Embarquer sur le pont starts Steam sign-in; actions needing an account are greyed and disabled with no sign-in panel; signed-in behaviour unchanged; full suite, vitest, packwerk, rubocop, typecheck pass.

## References

- parent — _bmad-output/initiative-gameble/epic-card-catalog/epic-card-catalog.md

## Notes

- Decision (author, 2026-10-20) on reviewing 14.7 on staging: a signed-out visitor has no reason to be on the hub or the collection; they see the landing and every card, and the shared pages. 14.7 is dropped; its visitor À DÉCOUVRIR goes with the collection entry.
