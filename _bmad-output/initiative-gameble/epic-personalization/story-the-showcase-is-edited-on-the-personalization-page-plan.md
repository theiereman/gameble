---
title: 'The showcase is edited on the Personalization page'
type: 'feature'
ticket: '6'
created: '2026-10-28'
status: 'built'
baseline_revision: '1d91ae607c80b73af123705588f35e18b72a659a'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Personalization page shows the player's showcase read-only, while the player edits it elsewhere (reorder on the public profile, remove from a card detail).

**Approach:** The page renders the public profile's showcase partial with the owner's controls, and the partial gains a remove button; the move and remove forms use the existing showcase endpoints and return to the page that sent them.

## Boundaries & Constraints

**Always:** Reuse `public_profiles/_showcase` and the `showcase-order` controller; copy in `en.yml` and `fr.yml`; the empty state stays on the page.

**Never:** A second copy of the editing markup; a new endpoint or operation; a style attribute.

</frozen-after-approval>

## Implementation Notes

Oneshot: the shared partial gets `removable`, the page partial renders it, the retired read-only list CSS goes, the system test covers reorder and remove.

## Verification

**Commands:**
- `bin/rails test test/system/personalization_test.rb test/system/public_profile_test.rb` -- expected: pass
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks missing`, `script/check_file_sizes`, `script/check_planning_references` -- expected: clean

## Review Triage Log

No independent lens: the fork could not spawn a subagent. Self-read of the diff:

- medium, patched: the shared partial put `?brother=<token>` on the card links, which would send the card detail's back link to the profile instead of the Personalization page; the page now passes `owner: nil` and the partial adds the context only for an owner.
- low, kept: the page shows the public profile's own heading and info mark above the cards instead of a bracketed panel, because the partial is shared; the empty state keeps the panel.
- The remove button reuses the move buttons' form and button classes; the `showcase-order` controller only reads `form[data-direction]`, so the remove form does not take part in dragging.
