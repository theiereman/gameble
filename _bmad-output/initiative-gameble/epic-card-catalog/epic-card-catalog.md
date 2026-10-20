---
remote: https://github.com/theiereman/gameble/issues/105
tracker_id: 105
key: ""
type: epic
title: "Every card of the game, browsable and searchable"
parent: initiative-gameble
covers: [CAP-6, CAP-7, CAP-18]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: "envelope"
---

# Every card of the game, browsable and searchable

## Description

The collection's "Toutes les cartes" grid at /library/cards becomes the game's catalog: every card of the published season shows its face, owned or not, so anyone can look through what exists and search for a game. A player still sees what they own, and a card they do not own is set apart; a signed-out visitor sees the same grid with no ownership data. No new screen and no new filter: the grid already lists every card of the published season, one card per game across editions, owned first, with its search, its FILTRES zone and the card detail beside it on desktop (13.9, 13.13, 13.14, 13.15, 13.20), and it is already open to visitors (`PublicRead`), who today see every slot as a locked missing slot.

## Outcome

For a player or a visitor: they can find out whether a game is a card, and see what it looks like, without having pulled it; the signal is that the grid answers a search for a game by name with the card's face.

## Requirements

- R1 (CAP-6): "Toutes les cartes" lists every card of the published season, one card per game across editions, owned first; a card the viewer does not own shows its published-season face, set apart from owned cards, never a locked missing slot; an owned card keeps its copies badge ("×n") and edition count. Set albums keep their missing slots.
- R2 (CAP-7): each card of the grid opens its card detail (beside the grid on desktop, its page on the phone), which shows the real card's face, owned or not, the same for every viewer, instead of the faded card back (author, 2026-10-20).
- R3 (CAP-6, CAP-18): the grid's existing search and filters (game name, rarity, set kind and set name, genre) narrow every card, for a player and for a visitor; an empty result says so. Nothing is added to them.
- R4 (CAP-18): a signed-out visitor opens the grid and the card detail and sees no ownership data (no state filter, copies, edition count, RAPPORT or owned count), under the public pages' throttling, never cached for another visitor, with no database id in the page or its links.
- R5 (CAP-18): a signed-out visitor reaches the grid from an entry the author chooses (see the open question in Notes).

## Done when

1. "Toutes les cartes" lists every card of the published season with its face, owned or not; a card not owned is set apart and an owned card shows its copies; a set album still shows its missing slots.
2. A search by game name narrows the list as it is typed, the rarity and set filters combine with it, and an empty result says so, for a player and for a signed-out visitor.
3. Each card in the list opens its card detail, which shows the real card's face, owned or not, the same for every viewer.
4. A signed-out visitor sees the grid and the detail with no ownership data, throttled like the other public pages, never cached for another visitor, with no database id, and reaches the grid from the entry the author chose.
5. The screen and its search work in French and in English, on a phone and on a desktop.

## Boundaries

The "Toutes les cartes" grid (`LibraryController#cards`, `library/_grid`, `_filters`, `_status`), the card detail it opens (`CardsController#show`, `cards/_detail`) and the visitor's way in to it; and, since 14.8 and 14.9 (author, 2026-10-20), the pages a signed-out visitor reaches: the landing, Toutes les cartes and its card detail, the public card page, public profiles with their albums, the activity feed read-only, Comment ça marche, the legal page and invitation links, every other page leading a visitor to the landing, and the visitor's phone tab bar. Not a new screen, a new filter or a new spec capability; not past seasons (the grid reads one card per game across editions, as the collection does); not the set albums' missing slots; not trading or selling cards; not the player's sets (epic-space-terminal-screens, epic-recognizable-sets).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-6 (the grid of every card, one card per game), CAP-7 (the card detail) and CAP-18 (what a visitor can open)
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-11 (a GET never writes), AD-14 (a policy per action, the signed-out visitor role), AD-15 (cards by slug, no database id)
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Information Architecture (row "Toutes les cartes"), Navigation (Signed-out visitors), State Patterns (Filter zone, Search, Missing-card slot, Copy badge, Grid across editions), Card back
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Collection grid, Missing-card slot, Card detail
- prior work — _bmad-output/initiative-gameble/epic-recognizable-sets/story-the-card-grid-as-the-secondary-view-plan.md, story-every-edition-counts-in-the-collection-plan.md, story-the-card-detail-beside-the-grid-on-tablet-and-desktop-plan.md, bug-larger-cards-in-the-filled-grid-on-desktop-plan.md
- prior work — _bmad-output/initiative-gameble/epic-public-launch-readiness/story-public-pages-throttled-or-cached-plan.md (`PublicReadThrottle` already counts `/:locale/library…` and `/:locale/cards…`; public pages stay `Cache-Control: private`)

## Notes

- Decision (2026-10-14): the epic is added as an envelope; it is detailed in a dedicated session with the author before inception (author).
- Open question: how this screen relates to the collection's existing "TOUTES LES CARTES" grid (CAP-6): a new screen beside it, or that grid opened to every card of the game. Resolved 2026-10-19, below.
- Open question: who reaches it (signed-out visitors or players only), and from where (the hub, the "Plus" menu, the collection). Who: resolved 2026-10-19, below; from where a visitor enters: still open, below.
- Open question: which seasons it covers (the published one only, or past seasons too) and what a card shows to a player who does not own it (face, missing slot, owned count). Resolved 2026-10-19, below.
- Open question: whether searching goes beyond the game's name (studio, franchise, theme, rarity filters), and whether this needs a new capability in the spec; `covers` is empty until then. Resolved 2026-10-19, below.
- Waits on epic 10 because: the collection's card grid, its filters and the card detail screen exist there.
- Decision (2026-10-14, author): the screen reads one card per game across editions, as the collection does (13.15, change-season-carryover); this settles the seasons part of the open question above for owned cards.
- Waits on epic 13 because: one card per game across editions (13.15).
- Decision (2026-10-19, author): no new screen; the collection's existing "Toutes les cartes" grid at /library/cards (13.9, 13.13, 13.14, 13.15, 13.20) is opened up to serve as the catalog.
- Decision (2026-10-19, author): signed-out visitors reach it too, so they can check whether their game is a card; it follows the public pages' throttling and caching rules, exposes no database id, and a visitor sees no ownership data.
- Decision (2026-10-19, author): the published season only. A card the viewer does not own shows its face, not a locked missing slot, so anyone sees what it looks like; a signed-in player still sees what they own (copies badge "×n") and a card not owned is visually set apart (for example faded, as 13.14's detail already fades a card not held). Set albums keep their missing slots unchanged. The exact treatment is a design point for the author to approve (entry 1).
- Decision (2026-10-19, author): search is the grid's existing filters (game name, rarity, set kind and set name); nothing new and no new spec capability; `covers` is CAP-6, CAP-7 and CAP-18.
- Open question: where a signed-out visitor enters the catalog from: a landing module (epic-visitor-landing), the signed-out hub's menu, the public card page, or several. Today a visitor reaches it only through the hub's menu 02 COLLECTION, then "TOUTES LES CARTES ▸". Left to the author; entry 5 is hitl and waits on the answer.
- Source conflict: EXPERIENCE.md, Navigation (Signed-out visitors) — "the collection shows every slot empty" for a visitor vs the author's 2026-10-19 decision that every card shows its face; entry 1 rewrites the rule.
- Source conflict: EXPERIENCE.md, State Patterns (Missing-card slot) and Card back — a missing card in the grid is a locked slot whose detail shows the faded card back, "only the player sees it" vs the same decision; entry 1 restricts the missing slot to set albums and settles what the detail shows.
- Finding (2026-10-19): /library/cards is already open to visitors (`LibraryController` includes `PublicRead`, `PagePolicy#show?` is true), already throttled by `PublicReadThrottle` and kept `Cache-Control: private`; for a visitor the grid's queries hold nothing, so the state filter, RAPPORT and owned count are already empty rather than absent.
- Decision (2026-10-19): entry 1 designs the card not owned and the visitor's view with the author before any build, as DESIGN.md and EXPERIENCE.md settle neither; entry 2 is the tracer bullet, a card not owned showing its face in the grid for a player and a visitor; entries 2, 3 and 4 run in one lane (the grid, then the detail, then the visitor's view, sharing the not-owned treatment entry 2 shapes); entry 5 waits on the author's choice of entry point; entry 6 is the refactor sweep.
- Decision (2026-10-19): entry 1 waits on 13.20 and 13.24, still being built on the same grid and detail column; entries 2 and 3 name 10.7 and 10.2, the grid with its filters and the card detail they change, as the epic's wait on epic 10.
- Decision (2026-10-19, author): a signed-out visitor enters the catalog from the landing; story 5 waits on the landing's shell (20.2).
- Decision (author, 2026-10-20, entry 1): a signed-in player's card not owned shows its face faded and grey with a pixel lock, in the grid only; the card detail always shows the real card, for everyone, so a shared link and every viewer see the same card; PARTAGER on every card; a visitor sees every face plain with no ownership data and no owned count on any collection page; another player's full collection fades the cards that player lacks; a menu entry "03 TOUTES LES CARTES" (hub and PLUS, visitors included) opens the catalog, added by entry 5. Approved on the mock mockups/catalog-not-owned.html.
- Decision (author, 2026-10-20, on reviewing v0.1.4-rc.1 on staging): 14.7 (a visitor's collection entry suggests sets to discover) was built (3278d2c3) and then dropped: a signed-out visitor has no reason to be on the hub or the collection. 14.8 removed its À DÉCOUVRIR with the collection entry.
- Decision (author, 2026-10-20, 14.8): a signed-out visitor reaches only the landing, Toutes les cartes and its card detail, the public card page, public profiles with their albums and Comment ça marche; the hub, the collection entry, a set album outside a profile and every other page lead a visitor to the landing; « Embarquer sur le pont » signs in through Steam; every action that needs an account shows greyed and disabled; the sign-in panel is removed. Built in f87b3f56 (with the test fix 42c9d71c).
- Decision (author, 2026-10-20, 14.9): the activity feed opens again to a visitor, read-only, and a visitor's phone tab bar holds ACCUEIL and TOUTES LES CARTES; the legal page and invitation links stay open to visitors; the terms and privacy line stands beside each game-styled Steam sign-in. Built in b67cd2eb.
- Decision (author, 2026-10-20, retrospective): the feed is read under the public pages' throttle, and the landing footer links Comment ça marche, so a visitor reaches it; R2 and Done when 3 now say the detail shows the real card to everyone, as entry 1 decided.
