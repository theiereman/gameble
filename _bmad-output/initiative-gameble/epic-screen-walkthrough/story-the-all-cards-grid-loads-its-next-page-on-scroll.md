---
id: 15
tracker_status: done
tracker_id: ""
type: story
title: "The all cards grid loads its next page on scroll"
parent: epic-screen-walkthrough
after: []
hitl: false
risk: medium
---

# The all cards grid loads its next page on scroll

## Description

The catalog (`library/cards`) pages its grid with Pagy offset pages (`app/controllers/concerns/collection_grid_loading.rb`, `GRID_SIZE`). Load the next page when the reader nears the end of the grid, appending its server-rendered cards, in a Stimulus controller that follows the front-end rules (no markup built in script, a `<template>` or a Turbo Stream/frame answer from the server). Keep the search, filters and sort in the next page's query, keep the numbered links as the fallback without JavaScript and for keyboard and screen-reader readers, announce the loaded cards politely, keep focus where it was, and make a back navigation return to the same scroll position (author, 2026-10-23). The screen is the catalog only; the controller is written to be reused by the collection grid later.

## Acceptance Criteria

Verify: On `/fr/library/cards` and `/en/library/cards` scrolling to the end appends the next page until the last, with a search and filters active the appended cards still match them, the page works with JavaScript off through its page links, and its system test (retrying matchers), vitest and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 5), author, 2026-10-23: infinite scroll on Toutes les cartes, expected to be simple on top of Pagy.
