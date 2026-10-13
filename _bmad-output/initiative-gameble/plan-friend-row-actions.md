---
title: 'A friend row offers a trade and opens the friend profile from one button'
type: 'feature'
ticket: ''
created: '2026-10-09'
status: 'done'
baseline_revision: 'd480add057b3b7d4fdd21148ebcf5fd582ce887a'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** On the Friends screen, proposing a trade is hidden behind a click on the friend's name, which nothing marks as clickable; the row's "See the profile" button leads to the public profile page instead, so two controls open two different screens.

**Approach:** The friend's name becomes plain text. The row's "See the profile" button opens the friend profile dialog the name used to open, and a new "Propose a trade" button links to the trade draft with that friend. When the viewer's or the friend's profile is private, the "Trades closed" line takes the button's place, as in the friend profile.

Decisions:
- When a trade is impossible, the row shows the "Trades closed" line (with the settings link when the viewer's own profile is private), not nothing.
- The friend profile dialog keeps its own link to the public profile page; renaming it is out of scope.

</frozen-after-approval>

## Code Map

- `app/views/friends/show.html.erb` -- friend row: `button.friends__name` opener becomes a `span.friends__name`; actions get the profile opener and the trade action; the `friends/public_profile_link` render leaves the row (the partial stays, the dialog uses it).
- `app/components/button_component.rb` -- `opens:` builds a dialog opener, but takes no aria-label; the row needs "See the profile of Sam" because every row repeats the label, so write the opener as a tag with the same data attributes or give the component a `label:` option.
- `app/helpers/trades_helper.rb` -- `trades_closed_line(refusal, friend)` renders the closed line; add the per-friend refusal next to it, the same rule as `TradesController#privacy_refusal` (own private first, then friend private).
- `app/frontend/styles/friends.css` -- `.friends__name` rules are for a button (hover, focus-visible, reset); trim to text.
- `config/locales/{en,fr}.yml` -- `friends.public_profile.named` gives the profile aria-label; add a named aria-label for the trade button.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- "Friend row" behavior row says the avatar or name opens the profile; update it.
- Tests: `test/controllers/friends_controller_test.rb` (lines 47, 61-67, 135-150), `test/controllers/invitations_controller_test.rb:58`, `test/system/friends_test.rb` (clicks "Lea", focus returns to the name).

## Implementation Notes

Oneshot: a view, a helper, CSS, locales and their tests, well under 100 lines.
- `TradesController#privacy_refusal` moved to `TradesHelper#trades_refusal`, so the row and the trade actions share one rule.
- `ButtonComponent` takes `aria_label:`, since every row repeats "See the profile" and "Propose a trade".
- The row's actions container became a `div`: `trades_closed_line` renders a `<p>`.
- `test/system/trades_test.rb` opened a draft through the name and the dialog; it now uses the row's button.
- DESIGN.md's friend row names "VOIR LE PROFIL" too.

## Review Triage Log

Quick lens, one pass: 4 findings, 4 low, all patched.
- low, patched: the new class comment on `ButtonComponent` described its own API, against the no-comment policy; removed.
- low, patched: `aria_label:` was dropped by the disabled, form and plain branches; every branch now carries it.
- low, patched: no component test for `aria_label:`; one test covers all five branches.
- low, patched: DESIGN.md's friend row disagreed with EXPERIENCE.md; it names "VOIR LE PROFIL" now.
