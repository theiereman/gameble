---
tracker_id: ""
key: ""
type: epic
title: "A phone-first web experience"
parent: initiative-gameble
covers: []
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# A phone-first web experience

## Description

The web app is reshaped around how a phone session runs: open every capsule, check set progress, handle friends and trades, then cosmetics. A four-tab bar, a header kept only on top-level screens, one bottom-sheet grammar for choosing, a capsule screen that opens capsules in a row, goal-first sets, trade rows that show whose turn it is, a bell for what changed, and a Me page that is the public profile edited live. The intent document owns the decisions; the audit owns the evidence.

## Outcome

A player on a phone reaches every screen in at most two taps and opens a day's capsules without waiting for a desktop; the signal is the author using the phone as the main way to open capsules, and the audit's problems no longer reproducing at 390 by 844.

## Requirements

- R1: A four-tab bar (Capsule, Sets, Social, Me) replaces the five tabs and "More"; the header shows in full only on top-level screens (G home button, one merged capsule counter, the bell) and shrinks to a back button elsewhere; the page title stays as a visually hidden heading; the version and legal line no longer covers content; text and tap targets meet the audit's thresholds. (intent, section Shell)
- R2: The capsule screen is the landing screen; the next capsule is preselected and opens with one tap and chains until the reserve is empty; the daily capsule is a ready slot collected with a tap; the end of a capsule shows all its cards; an empty reserve proposes sets, friends and trades, then personalization and achievements, on phone and desktop. (intent, section Capsule flow)
- R3: One bottom sheet serves every choice; the card list paginates without end and returns to the same position after a card detail; three quick filters (goal, rarity, state) and a top search narrow it; Sets opens on the player's goals, then the other sets by closeness to completion, grouped by type, with all cards as a view. (intent, section Lists and filters)
- R4: Social opens on trades in progress and friends; a trade row shows the person, whose turn it is and the highest rarity; a trade starts from a missing card, sent with the player's own side empty; add-friend and new-trade stay at the bottom; the feed is secondary. (intent, section Social and trades)
- R5: A bell opens a dropdown of what is new: a trade updated, a friend request, the daily and community goal; each line is one sentence and one action and clears when its target is opened; it shows on desktop too. (intent, section Bell)
- R6: The Me tab is the public profile merged with the personalization page, edited in place through bottom sheets with the result shown live; the account settings keep their own page, linked once. (intent, section Me page)

## Done when

1. At 390 by 844 every top-level screen shows the reduced header with no clipped title and nothing overlapping content, and every destination of the former "More" is reached within two taps from the four tabs.
2. A player opens a full reserve capsule after capsule from one primary button, collects the daily capsule with a tap, and with an empty reserve sees the three proposals leading to Sets, Social and Me, on phone and on desktop.
3. With 100 or more cards, the card list scrolls without a visible wait, returns to the same card after a detail, and narrows by goal, rarity and state from a bottom sheet.
4. From a missing card a player starts a trade with a friend who holds it, sends it with their own side empty, and opens the updated trade from the bell after the friend answers.
5. The Me page changes a card back, the showcase and the title in place and the change shows at once; the settings page still holds the account items.
6. The whole path is checked on a real iPhone in Safari, and the phone experience ships to production.

## Boundaries

The web app's shell, lists, capsule screen, Social, bell and Me page at phone width, with desktop gaining the shared pieces (bottom sheet, empty-capsule state, bell). Not a native app (a later epic, after the phone web experience), not new trade rules, not vibration or sound on rare cards, not achievements in the bell.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- intent — _bmad-output/initiative-gameble/brainstorm-mobile-web-ux/brainstorm-mobile-web-ux.md, sections 2 to 5
- evidence — _bmad-output/initiative-gameble/audit-mobile-web/audit-mobile-web.md, section Findings
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md and DESIGN.md
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md
- prior work — _bmad-output/initiative-gameble/epic-trade-suggestions/epic-trade-suggestions.md and epic-aim-at-the-cards-you-want/epic-aim-at-the-cards-you-want.md

## Notes

- Decision (2026-11-02, author): one epic for the whole phone experience, past the usual size; the author chose it over two.
- Decision (2026-11-02, author): release 1.2.0, the mobile version; the native app (issue 332) comes after it.
- Decision (2026-11-02, author): tickets stay local, no tracker.
- Open question: whether the reserve count also shows as a badge on the Capsule tab; the author only chose the merged header counter.
- Unknown: the storage of the last-seen marker for trades and how it respects the rule that a GET never writes; entry 11 waits on it.
- Unknown: how the bell, the sheets and the tabs map onto the native shell later; not decided here.
- Decision (2026-11-02, author): entry 9 lists every friend holding the missing card, a friend with a single copy included, and any missing card qualifies, not only a goal card.
- Decision (2026-11-02, author): the trade board's card picker stays the advanced picker it is today; it does not move to the bottom sheet.
- Decision (2026-11-02, author): the tracer path is entries 1, 2 and 6, with the bottom sheet (3) and the bell (10) as separate lanes.
- Assumption: entry 13 precedes the sweep because it can reorder fixes.
- Waits on epic 28 and epic 29 because: goals and the suggestions of friends who hold a missing card already exist there.
