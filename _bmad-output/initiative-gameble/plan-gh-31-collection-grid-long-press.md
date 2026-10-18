---
title: 'Keep card tilt active during a collection grid long press'
type: 'bugfix'
ticket: ''
created: '2026-10-16'
status: 'in-progress'
baseline_revision: '7e6b6570113952a90fb6fb4ef0fbc8d8ee4140f0'
route: 'full'
route_source: 'pinned'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The existing long-press fix is merged and works on opened-pack cards, but the collection grid still selects text or opens Safari's link menu, which cancels the card tilt. There is no open PR for this remaining behavior.

**Approach:** Extend the touch-only context-menu guard to cover the collection card link that owns the card face, while keeping selection suppression scoped to the card and preserving normal navigation and desktop menus.

## Boundaries & Constraints

**Always:** Reuse `attachTilt` and its existing pointer lifecycle. Prevent context menus only during an active touch tilt. Preserve quick-tap navigation and desktop right-click. Keep text elsewhere on the page selectable.

**Never:** Disable selection globally, suppress mouse context menus, change card navigation, or alter tilt timing and vertical scrolling.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Collection long press | Touch holds a card inside its `.card-link` until tilt starts | Link menu is prevented and tilt continues | No error expected |
| Quick tap | Touch releases before the hold threshold | Card detail navigation remains available | No error expected |
| Desktop right-click | Mouse opens a card's context menu | Browser menu remains available | No error expected |
| Page text | User selects text outside card faces | Selection remains available | No error expected |

</frozen-after-approval>

## Code Map

- `app/frontend/lib/tilt.ts` -- `attachTilt` tracks the active touch driver and currently handles `contextmenu` on the card element.
- `app/frontend/lib/tilt.test.ts` -- fake-pointer tests cover touch suppression, mouse pass-through, card-link CSS scope and listener teardown.
- `app/components/card_component.html.erb` -- attaches the `tilt` controller to the shared `.card` face.
- `app/helpers/card_details_helper.rb` -- `link_to_card_detail` wraps card faces in `.card-link`.
- `app/views/library/_grid.html.erb` and `app/frontend/styles/collection.css` -- collection cards use that wrapper inside `.collection-slot`.
- `app/views/packs/show.html.erb` -- opened-pack cards use the same helper, so the fix must retain their working behavior.

## Tasks & Acceptance

**Execution:**
- [ ] `app/frontend/lib/tilt.ts` -- keep the touch-only context-menu guard on the card and remove the redundant link listener.
- [ ] `app/frontend/lib/tilt.test.ts` -- remove the synthetic link-target case and assert the card-link callout selector alongside existing touch, mouse and teardown coverage.
- [ ] `app/frontend/styles/card-detail.css` -- disable the iOS touch callout on links that directly wrap a card, before WebKit decides to show it.

**Acceptance Criteria:**
- Given an iPhone Safari long press on a collection card, when tilt begins, then no text is selected or link menu opened and tilt continues.
- Given a quick tap on a collection card, when released before tilt begins, then detail navigation still works.
- Given a desktop right-click on a collection card, when its context menu opens, then the browser menu remains available.
- Given the user selects ordinary page text, when they drag across it, then the selection works.

## Implementation Notes

Implementation handoff: update the existing regression coverage, but do not run tests, commit, or push. Leave test verification to CI.

## Plan Change Log

- The renewed review feedback requires callout suppression before WebKit's touch-start decision. The author directed this correction while asking that the approved frozen intent remain unchanged.

## Review Triage Log

## Design Notes

The shared card is inside a `.card-link` anchor in the collection grid. A touch `contextmenu` targets the card content and bubbles through the card; the additional listener on the enclosing link was redundant. WebKit can decide to show its callout at touch start, before the tilt state exists, so suppression applies to card links at all times. Verify the behavior on physical iPhone Safari.

## Verification

**Commands:**
- `npm run test:js` -- expected: Vitest passes, including the collection-link event case.
- `bin/rails test` -- expected: Rails suite runs in CI; do not run locally.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks:**
- On iPhone Safari, confirm a long press on a collection card keeps tilting without selecting text or opening the link callout. Physical iPhone verification remains outstanding.
- Confirm a quick tap still opens the card detail, desktop right-click remains available, and ordinary page text remains selectable.
