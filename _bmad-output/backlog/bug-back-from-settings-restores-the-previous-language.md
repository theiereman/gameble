---
id: bug-back-from-settings-restores-the-previous-language
type: bug
title: "Back from the settings after a language change restores the previous language"
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

# Back from the settings after a language change restores the previous language

## Description

On a computer (Chrome), every time: a player opens the settings, switches the language from French to English, then presses the back button to return to the screen they came from. The language is back to French. The locale is the first URL segment, so the back button most likely returns to the previous screen's URL in the old locale. Back after a language change should return to the screen the player came from, in the language they just chose.

## Acceptance Criteria

Verify: from a screen in French, open the settings, choose English, press back: the previous screen opens in English and the setting stays English; the browser's own back button behaves the same; back without a language change is unchanged.

## References

- issue — https://github.com/theiereman/gameble/issues/52 (video attached there)

## Notes

- Filed on 2026-10-19 from GitHub issue #52.
