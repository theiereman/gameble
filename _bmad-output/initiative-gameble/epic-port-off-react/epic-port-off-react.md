---
remote: https://github.com/theiereman/gameble/issues/226
tracker_id: 226
key: ""
type: epic
title: "The booster and the trade board leave React for Stimulus"
parent: initiative-gameble
covers: []
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# The booster and the trade board leave React for Stimulus

## Description

The booster and the trade board are the last two React islands, mounted with Turbo Mount; every other screen is server HTML with Stimulus. A developer who knows Rails finds them foreign: two ways to write the front end, a props contract, hooks wrestling imperative animation. This epic ports both screens to the rules of the architecture spine (AD-16, AD-30, AD-31), the trade board first so that it sets the conventions, then the booster, and removes React from the toolchain. Nothing a player sees changes.

## Outcome

For a developer who knows Rails: the whole front end reads as Hotwire, server-rendered markup and thin Stimulus controllers over pure TypeScript modules, with no React left in the repository. The signal is Done when 1.

## Requirements

No capability of the spec: a platform epic. Each line cites the architecture section it comes from.

- R1. The trade board is a server-rendered screen built as a rich screen: a `trade-board` root controller holding its module from `app/frontend/lib/`, child controllers per region, the existing `trade-board`, `trade-send` and `trade-swap` controllers folded into that anatomy, the trade draft in browser storage read and written only by a module, its picker keeping its JSON faces batch, the live refresh held while a draft or counter is edited and the state reapplied after a morph. Its island and the `trade-changed` and `trade-editing` events are gone. Source: AD-16, AD-30, AD-31.
- R2. The booster's state and transitions (opening, reveal, store, layout, celebration, bank refresh, navigation lock) live in a DOM-free module, `app/frontend/lib/booster.ts` (its timings may move to a `lib/booster_*.ts` helper), tested by Vitest. Source: AD-16, AD-30.
- R3. The booster is a server-rendered screen built as a rich screen: one tree holding its three layouts, switched by `data-layout` only when idle, each card's faces per size as `<template>`s, a `booster` root controller with child controllers per region. Its island is gone. Source: AD-16, AD-27, AD-30.
- R4. Server HTML inside a JSON answer (the opening exchange, the trade faces batch) is placed by one shared helper in `app/frontend/lib` into a `<template>`; no other script builds markup except decorative `aria-hidden` nodes and canvases. Source: AD-16, AD-23.
- R5. Copy follows AD-18 in both screens: fixed variants rendered by the server and shown by CSS, run-time strings composed by `t()` from templates under the screen's `<screen>.strings` scope, reaching its root alone. Source: AD-18.
- R6. Players see no change: each screen's system tests pass as they stand, selectors and wording included; locale scopes may be renamed per AD-18, and only the island's code-loading failure test is replaced by the promise that remains, the form working without JavaScript. Controller tests that read an island's props are rewritten against the server-rendered markup. Source: AD-31.
- R7. React leaves the toolchain: React, react-dom, `@types/react` and `@types/react-dom`, Turbo Mount (gem and npm), `@vitejs/plugin-react` and its `react()` plugin, `vite_react_refresh_tag`, the `react-jsx` compiler option, and the development policy's `'unsafe-inline' 'unsafe-eval'` scripts unless something else still needs them; the spine's Stack table loses their rows. Source: AD-31, Stack.

## Done when

1. No file in the repository imports React, `app/frontend/components/` is gone, and neither `package.json`, `package-lock.json` nor `Gemfile.lock` lists react, react-dom, `@types/react`, `@types/react-dom`, turbo-mount or `@vitejs/plugin-react`.
2. `test/system/trades_test.rb` and `test/system/booster_test.rb` pass, unchanged except renamed locale scopes and the booster's code-loading failure test replaced by the no-JavaScript form test.
3. `bin/ci`, `npm run test:js` and `bin/rails zeitwerk:check` pass, and Vitest covers every transition of the booster's and the trade board's modules.
4. A CI step fails on `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `DOMParser` or `createContextualFragment` anywhere in `app/frontend` outside the shared helper and its test.

## Boundaries

The booster screen, the trade board and the front-end toolchain. No feature and no visible change: behaviour, URLs, copy, markup players rely on and the opening exchange's contract stay as they are. Not the rest of the codebase's cleanup, file sizes or linters (epic 12, which follows). Not the trade draft's move to the server, nor the picker's filters to a Turbo Frame.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, sections AD-16, AD-18, AD-23, AD-27, AD-30, AD-31 and Stack
- review — _bmad-output/initiative-gameble/architecture-gameble/reviews/review-adversarial-2026-10-22.md (the divergences AD-30 closes, grounded in the islands' code)
- review — _bmad-output/initiative-gameble/architecture-gameble/reviews/review-versions-2026-10-22.md (outlet limits in Stimulus 3.2.2, the toolchain leftovers)
- ux — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, sections Capsule, Opening protocol, Échanges, Motion, Accessibility Floor and Responsive & Platform

## Notes

- Decision (2026-10-22, author): React leaves the front end; the booster and the trade board are ported, the trade board first. Until the last port lands, both screens take bug fixes only (AD-31); epics 19 and 9, which change the booster, wait on this epic.
- Decision (2026-10-22, author): an epic of its own, before epic 12, so that epic 12's cleanup does not rework React code about to go. Release 0.5.0.
- Decision (2026-10-22, author): the booster is ported in two steps. Its state leaves React first, into `lib/booster.ts`, with React kept as a thin view and the system tests as the net; the view is then replaced in one change, as AD-31 requires.
- Decision (2026-10-22, author): the trade picker keeps its JSON faces batch.
- Decision (2026-10-22): tracer bullet is the trade board's port: the thinnest screen through every piece AD-30 names (root and child controllers, outlets, the HTML-in-JSON helper, the strings scope, the morph hold). The booster follows the conventions it sets.
- Decision (2026-10-22, author): the shared HTML helper is tested in Vitest under happy-dom, set for its test file alone; the other tests stay in the node environment.
- Decision (2026-10-22, author): entries 1 and 3 may each be split on a branch merged once if they outgrow a session; never React and Stimulus side by side on develop.
- Waits on epic 16 because: the 0.4.0 screens are walked through (16.1) before a port changes them; the freeze holds both screens still meanwhile.
