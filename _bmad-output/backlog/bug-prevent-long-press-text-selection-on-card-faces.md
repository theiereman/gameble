---
id: bug-prevent-long-press-text-selection-on-card-faces
type: bug
title: "Prevent long-press text selection on card faces"
parent: none
covers: []
after: []
assignee: ""
refined: false
hitl: false
risk: low
severity: P3
estimate: ""
---

# Prevent long-press text selection on card faces

## Description

On iPhone Safari, a long press on a card face selected its text or opened the link menu, interrupting the touch that tilts the card, in the collection grid and in an opened pack. Card faces no longer select text or open the menu while a touch tilts them.

## Acceptance Criteria

Verify: a finger held on a card tilts it with no selection or menu; a quick tap still opens the card detail; a desktop right-click still opens the browser menu; text outside card faces stays selectable.

## References

- plan — _bmad-output/backlog/bug-prevent-long-press-text-selection-on-card-faces-plan.md
- issue — https://github.com/theiereman/gameble/issues/31

## Notes

- Filed on 2026-10-17, after a build that ran without a ticket; the plan beside this file is the record of that build.
