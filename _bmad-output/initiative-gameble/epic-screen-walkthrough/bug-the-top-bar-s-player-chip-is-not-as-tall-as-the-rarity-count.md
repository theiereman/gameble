---
id: 20
tracker_status: done
tracker_id: 248
remote: https://github.com/theiereman/gameble/issues/248
type: bug
title: "The top bar's player chip is not as tall as the rarity counter and the capsules chip"
parent: epic-screen-walkthrough
after: []
refined: false
hitl: false
risk: low
---

# The top bar's player chip is not as tall as the rarity counter and the capsules chip

## Description

In the signed-in top bar (`app/views/shell/_top_bar.html.erb`; chips in `app/frontend/styles/shell.css`, `.player-chip__button`, `.rarity-counter__button`, `.packs-chip`) the player chip does not have the same height as the rarity counter and the capsules chip beside it (author, 2026-10-23, on staging). Give the three chips one height at every width, where the bar shows them, without changing their content or their tap targets.

## Acceptance Criteria

Verify: On the hub, the collection and a card page, at desktop and phone widths, the three chips measure the same height, checked by the author on staging and by a system test that compares their heights; the full suite passes.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 10), author, 2026-10-23.
