---
title: 'Phone booster rays stay with the top card'
type: 'bugfix'
ticket: ''
created: '2026-10-14'
status: 'built'
baseline_revision: '47391d33babf9405bb6887cd10a5a6772c89a86d'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-phone-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** In the phone booster pile, a revealed card stored below the top card keeps its large rarity rays visible. The static rays peek around the top card and look detached from the card that produced them.

**Approach:** Hide the rays on every non-top phone card, while retaining the existing rule that stops their animation. The top card continues to show its rays as designed.

</frozen-after-approval>

## Implementation Notes

Oneshot is appropriate because the fix is a small CSS-only change. Keep the existing `animation: none` declaration: the CSS source test checks that lower phone cards do not animate, and the hidden rays also satisfy the phone design's animation budget.

`app/frontend/styles/booster-layouts.css` gains a rays-only rule, one line of `display: none` on a non-top phone card, right after the shared sheen-and-rays `animation: none` rule. Hiding rather than fading keeps that rule free of `opacity`, which the stylesheet test asserts, and the top card's reveal rule is untouched.

## Verification

**Manual checks (if no CLI):** Confirm the non-top phone-card rays rule hides the rays without changing the top-card reveal rule or the existing no-animation assertion.

## Review Triage Log

- low — `app/frontend/styles/booster-layouts.css`: the review found a code comment describing local CSS behavior, which violates the repository rule that comments only document external constraints. Removed the comment; the selector and declaration state the behavior directly.
