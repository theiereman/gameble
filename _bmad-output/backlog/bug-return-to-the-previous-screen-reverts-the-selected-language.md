---
id: bug-return-to-the-previous-screen-reverts-the-selected-language
type: bug
title: "Return to the previous screen reverts the selected language"
parent: none
covers: []
after: []
assignee: ""
refined: false
hitl: false
risk: low
severity: P2
estimate: ""
tracker_id: "#52"
---

# Return to the previous screen reverts the selected language

## Description

The in-app return action reaches the previous screen in the language the player just chose, and same-language history restoration is unchanged.

## Acceptance Criteria

Verify: from a French screen, choose English in the settings and press return: the previous screen opens in English.

## References

- plan — _bmad-output/backlog/bug-return-to-the-previous-screen-reverts-the-selected-language-plan.md

## Notes

- Filed on 2026-11-05, after a build that ran without a ticket; the plan beside this file is the record of that build.
- An earlier build of GitHub issue #52; bug-back-from-settings-restores-the-previous-language and bug-back-after-a-language-change-keeps-the-scroll-and-only-a-settings-choice-carries hold the later ones.
