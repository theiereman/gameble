---
title: 'Prevent long-press text selection on card faces'
type: 'bugfix'
ticket: 'bug-prevent-long-press-text-selection-on-card-faces'
created: '2026-10-14'
status: 'done'
baseline_revision: '47391d33babf9405bb6887cd10a5a6772c89a86d'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** On iPhone Safari, a long press on a card face selects its text or opens the browser link menu, interrupting the touch gesture used to tilt the card. The issue occurs in both the collection grid and opened pack.

**Approach:** Disable text selection and WebKit touch callouts on card faces only. Prevent the context menu while a touch is actively driving a card tilt, while preserving quick-tap navigation and desktop right-click menus.

## Boundaries & Constraints

**Always:** Keep selection available for text outside card faces. Reuse the existing `attachTilt` lifecycle and event-state tracking. Preserve the existing quick-tap and tilt-click behavior.

**Never:** Prevent desktop context menus. Do not disable selection globally or change card navigation, pointer movement, scroll handling, or tilt timing.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Touch tilt | A finger remains on a card until its tilt starts, then a contextmenu event occurs | The event is prevented and the touch tilt can continue | No error expected |
| Quick tap | A finger is lifted before the tilt hold begins | The card click is not prevented and detail navigation remains available | No error expected |
| Desktop right-click | A mouse contextmenu event occurs on a card | The event is not prevented and the browser menu opens | No error expected |
| Text outside cards | The user selects ordinary page text | Selection remains available | No error expected |

</frozen-after-approval>

## Code Map

- `app/frontend/styles/card.css` -- the shared `.card` face rule; currently has `touch-action: pan-y` and no selection or touch-callout restrictions.
- `app/frontend/lib/tilt.ts` -- `attachTilt` tracks the active touch driver, binds pointer/touch/click handlers, and removes listeners during detach.
- `app/frontend/lib/tilt.test.ts` -- Vitest coverage for tilt interactions and raw `.card` CSS assertions; use its `FakeCard`, `pointer` helper, and fake timers.

## Tasks & Acceptance

**Execution:**
- [x] `app/frontend/styles/card.css` -- disable selection and the WebKit touch callout on `.card` only -- keep page text selectable.
- [x] `app/frontend/lib/tilt.ts` -- prevent `contextmenu` only while a touch driver is tilting and remove the listener on detach -- preserve desktop right-click.
- [x] `app/frontend/lib/tilt.test.ts` -- cover touch context-menu prevention, desktop context-menu pass-through, and card CSS rules -- protect both behavior boundaries.

**Acceptance Criteria:**
- Given a long press on a card face in iPhone Safari, when the finger begins tilting, then no text is selected and no browser link menu interrupts the gesture.
- Given a quick tap on a card, when the finger is lifted before tilt begins, then its detail link still activates.
- Given a desktop right-click on a card, when the context menu event fires, then the browser menu remains available.
- Given selectable text outside a card face, when the user selects it, then selection still works.
- Given the implementation, when `npm run test:js` and `bin/rails test` run, then both pass.

## Implementation Notes

- Scoped `user-select` and WebKit touch-callout suppression to `.card`; the context-menu handler uses the current touch driver and is detached with the other listeners.
- Added coverage for touch tilt, desktop context-menu pass-through, CSS scoping and listener teardown; the existing quick-tap test remains unchanged.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `npm run test:js` -- passed: 30 files and 305 tests.
- `npm run typecheck` -- passed.
- `bin/rails test` -- delegated to CI per user direction; not run locally.

**Manual checks (if no CLI):**
- On iPhone Safari, long-press a card in the collection and in an opened pack; confirm tilt continues without selection or callout, and a quick tap still opens card detail.
- On desktop, right-click a card and confirm the browser menu opens.
