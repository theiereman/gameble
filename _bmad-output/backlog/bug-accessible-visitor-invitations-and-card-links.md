---
id: bug-accessible-visitor-invitations-and-card-links
type: bug
title: "Accessible visitor invitations and card links"
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

# Accessible visitor invitations and card links

## Description

The visitor invitation on a card detail repeated its visible sentence in an aria-label, and the accessible name of a linked card face left out the release year. The invitation is now named by its paragraph, and a card link reads its title, year and rarity, in English and French, with no visual change.

## Acceptance Criteria

Verify: a screen reader reads the visitor invitation once, and a card link as its title, year and rarity, in both locales.

## References

- plan — _bmad-output/backlog/bug-accessible-visitor-invitations-and-card-links-plan.md
- issue — https://github.com/theiereman/gameble/issues/27
- issue — https://github.com/theiereman/gameble/issues/34

## Notes

- Filed on 2026-10-17, after a build that ran without a ticket; the plan beside this file is the record of that build.
