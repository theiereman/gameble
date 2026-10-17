---
id: bug-the-desktop-back-button-names-the-previous-different-screen
type: bug
title: "The desktop back button names the previous different screen, not an earlier page of the same one"
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

# The desktop back button names the previous different screen, not an earlier page of the same one

## Description

On the collection, changing page or set kind made the top bar's desktop back button appear, leading back to the same screen. The button now names and returns to the nearest earlier screen that differs from the current one, restored as it was left, and stays hidden right after a language change.

## Acceptance Criteria

Verify: changing page or set kind on the collection leaves the back button hidden; arriving from another screen, it names that screen and returns to it as it was left; it is hidden after switching the language.

## References

- plan — _bmad-output/backlog/bug-the-desktop-back-button-names-the-previous-different-screen-plan.md

## Notes

- Filed on 2026-10-17, after a build that ran without a ticket; the plan beside this file is the record of that build.
