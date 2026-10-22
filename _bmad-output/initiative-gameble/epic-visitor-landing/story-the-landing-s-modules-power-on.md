---
id: 7
tracker_status: done
tracker_id: 172
remote: https://github.com/theiereman/gameble/issues/172
type: story
title: "The landing's modules power on"
parent: epic-visitor-landing
covers: [R3]
after: [2]
hitl: false
risk: medium
---

# The landing's modules power on

## Description

Adds the modules' one-time power-on as their top edge passes 85% of the viewport, the star field's drift with the scroll on the landing only, and the side position gauge from 1440px with its focus-moving markers, their maths in tested pure modules, all still under reduced motion.

## Acceptance Criteria

Verify: Scrolling powers each module on once, the gauge's markers move focus to each module's heading with aria-current, content shows without JavaScript, and under reduced motion modules only fade and the stars stay still.

## References

- parent — _bmad-output/initiative-gameble/epic-visitor-landing/epic-visitor-landing.md
