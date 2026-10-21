---
title: 'The Légendaire iridescence lets the card’s content show through'
type: 'bugfix'
ticket: 10
created: '2026-10-21'
status: 'built'
baseline_revision: 'ba180afc3bff9c8df6cd7972c18d3697e1868a09'
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

**Problem:** The iridescent reflection on Légendaire cards (`.card__reflection--iridescence`) is strong enough that the card's art and text are hard to read (author, 2026-10-20, on staging).

**Approach:** Tone down its opacity so the cover art, title and studio read clearly at every card size while the effect still marks a Légendaire; DESIGN.md records the new strength.

</frozen-after-approval>

## Implementation Notes

A one-value CSS change fits the oneshot route: layer opacity 0.21 → 0.07 (times the fresnel; the author asked for less than a first 0.12) in `app/frontend/styles/card.css`, about 67% weaker at the peak; DESIGN.md's reflection paragraph records it. The first try also cut the band peak to 0.6, which the review showed compounds to a 66% cut and risks losing the Légendaire mark, so the band peak stays 1. The author judges the strength on staging and may tune the number.

## Review Triage Log

- medium, patched: opacity and band peak multiply, so the cut overshot; band peak restored.
- low, patched: DESIGN.md wording now "times the fresnel".
- low, rejected: legibility is unchecked in code; the author verifies on staging, as the ticket's verify says.
