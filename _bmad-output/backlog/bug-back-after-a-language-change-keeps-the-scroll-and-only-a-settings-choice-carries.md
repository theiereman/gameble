---
id: bug-back-after-a-language-change-keeps-the-scroll-and-only-a-settings-choice-carries
type: bug
title: "Back after a language change keeps the previous screen's scroll, and only a language chosen in the settings carries over"
parent: none
covers: []
after: []
assignee: ""
refined: true
hitl: false
risk: low
severity: P3
estimate: ""
tracker_id: "#52"
remote: https://github.com/theiereman/gameble/issues/52
---

# Back after a language change keeps the previous screen's scroll, and only a language chosen in the settings carries over

## Description

The fix of GitHub issue #52 (plan `bug-back-from-settings-restores-the-previous-language-plan.md`) makes back after a language change open the previous screen in the new language, but the screen loads fresh: at the top, without its scroll position or return focus. And any page read in the other language (a pasted link) switches the language of the earlier history entries. The author (2026-10-19): back after a language change must land at the previous screen's scroll position, as a plain back does, and only a language chosen in the settings carries over to the history; a page opened in another language by a link does not.

## Acceptance Criteria

Verify: from a French screen scrolled halfway, open the settings, choose English, press the app's back then the browser's back: the screen opens in English at the same scroll position; opening an English link in a French tab then pressing back returns to the French page in French; back without a language change is unchanged.

## References

- plan — _bmad-output/backlog/bug-back-from-settings-restores-the-previous-language-plan.md
- issue — https://github.com/theiereman/gameble/issues/52

## Notes

- Filed on 2026-10-19 from the author's review of the first fix.
