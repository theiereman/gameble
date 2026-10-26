---
id: 16
tracker_status: done
tracker_id: 244
remote: https://github.com/theiereman/gameble/issues/244
type: bug
title: "The reduced-animations switch covers the wordmark on the phone landing"
parent: epic-screen-walkthrough
after: []
refined: false
hitl: true
risk: low
---

# The reduced-animations switch covers the wordmark on the phone landing

## Description

On the signed-out landing the top bar shows the "Animations réduites" switch (`app/views/shell/_top_bar.html.erb`, class `motion-switch`) and on a phone it sits over the gameble wordmark (author, 2026-10-23, on staging). Remove the switch from the phone's landing top bar so the wordmark is clear; the desktop keeps it, the visitor's reduced-motion preference still follows their system setting, and EXPERIENCE.md and DESIGN.md record where a phone visitor sets it, if anywhere.

## Acceptance Criteria

Verify: On a phone width the landing's top bar shows the wordmark and the sign-in button with no motion switch over them, in French and in English; the desktop landing still shows the switch and it still toggles; the landing's system test and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 6), author, 2026-10-23.
- Settled by the author, 2026-10-24: a phone visitor sets reduced motion nowhere on the landing; it follows the system setting, and a signed-in player finds the switch in Profile and settings.
