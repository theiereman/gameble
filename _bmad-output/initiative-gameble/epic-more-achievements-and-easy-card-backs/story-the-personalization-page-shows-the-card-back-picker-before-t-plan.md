---
title: 'The Personalization page shows the card back picker before the title picker, and the title picker takes less room'
type: 'feature'
ticket: '15'
created: '2026-11-02'
status: 'built'
baseline_revision: '60aa9c9b64bffe9d4549d4868e6aa887bef87651'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The card back picker sits after the title picker, and the title picker is a long list of radio buttons.

**Approach:** The back picker section comes first; the title picker becomes one menu listing the titles grouped by rank, with a no-title option, showing the current title.

</intent-contract>

## Implementation Notes

Oneshot: the back section now precedes the showcase and the title section (the ticket says the back picker comes first). The title picker is a native select with one optgroup per rank, submitted on change by the renamed change-submit controller (it no longer serves radios). The empty-state sentence that states how a title is earned is kept. Controller and system tests follow the select.

## Plan Change Log

## Review Triage Log

### 2026-11-02 - Review pass
- findings:
  - `[high]` `patch` the personalizations controller test still expected the old section order - updated to back, showcase, title (headings, intros, scopes).
  - `[low]` `patch` weak substring order test - removed; the updated heading-order assertion covers it.
  - `[low]` `patch` dense ERB - options moved to `profile_title_options` in the profile titles helper; stray blank line removed.
  - `[low]` `reject` one-option menu when no title is earned - the empty-state sentence explains how to earn one; hiding it adds a branch.
  - `[low]` `reject` generic `title` id and doubled rank in option text - the option text is the shipped title wording the tests and the profile share.
  - `[low]` `reject` arrow-key test removed - native select behaviour, no custom key handling remains.

## Auto Run Result

Back picker first, title picker is one grouped select with a no-title option. Files: personalization view, title picker partial, helper, stylesheet, renamed change-submit controller, controller and system tests. Verification: rubocop, format, CSS lint, tsc and repo checks clean; tests not run (instructed). Risk: the select's native dropdown look is unstyled beyond the closed control; the showcase now sits between the back picker and the title picker.

## Verification

**Commands:**
- `npm run format:check`, `npm run lint:css`, `npx tsc --noEmit`, rubocop -- expected: clean
