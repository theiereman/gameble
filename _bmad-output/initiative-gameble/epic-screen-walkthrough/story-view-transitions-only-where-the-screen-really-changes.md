---
id: 27
tracker_status: done
tracker_id: 255
remote: https://github.com/theiereman/gameble/issues/255
type: story
title: "View transitions only where the screen really changes"
parent: epic-screen-walkthrough
after: []
hitl: true
risk: low
---

# View transitions only where the screen really changes

## Description

Navigations animate with a view transition (`view-transition-name: screen` in `app/frontend/styles/shell.css`, the `::view-transition-old(root)` and `new(root)` rules, the sub-view steps in `app/frontend/lib/sub_view_step.ts`), including between steps of Échanges where almost everything on screen stays the same, which feels meaningless (author, 2026-10-23, on staging). Inventory which navigations animate today, with the author keep the transition only where the layout or the content block really changes (for example hub to a screen, grid to card detail) and turn it off where the new screen shares nearly the same frame, starting with Échanges; reduced motion and the browsers without view transitions stay as they are. The trade board is a React island frozen to fixes, so keep the change to the transition rules and the page's `view-transition` meta, not the island.

## Acceptance Criteria

Verify: Moving between the Échanges steps shows no view transition while hub to collection and a grid to a card detail keep theirs, with reduced motion and in a browser without `startViewTransition` unchanged; checked by the author on staging; the system tests (retrying matchers) and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 19), author, 2026-10-23.
- Settled by the author, 2026-10-24: keep the transition only where the screen changes (hub to a screen, a grid to a card detail); the Échanges steps and the sub-views that keep the same frame lose it.
