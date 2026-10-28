---
id: 13
tracker_status: done
tracker_id: ""
type: bug
title: "The feed is narrower than the other screens and shows « Tout » twice"
parent: epic-brotherhood
covers: [R4]
after: [2]
refined: true
hitl: false
risk: low
severity: P3
---

# The feed is narrower than the other screens and shows « Tout » twice

## Description

On a desktop, the activity feed does not use the content width the other screens use: its list stops well short of the right edge. At its top, a TOUS tab sits alone above a filter row that starts with TOUT, so the same choice appears twice. The feed should span the same width as the hub and the collection, and show one « Tout ».

## Reproduction

1. Open `/fr/feed`, signed in or out, in a window wider than about 785 px; it is plain at 1280 px.
2. Actual: the list stops at 720 px, left-aligned in a content area up to 1216 px wide, while the hub and the collection fill it. Expected: the same width as the hub.
3. Actual: a row with one selected tab, TOUS, sits above the filters TOUT, TIRAGES, DÉCOUVERTES, ÉCHANGES, REPOSTS, both highlighted. Expected: one « Tout ».
4. Under 720 px the phone column applies, so the width is right there, but the doubled label shows too.

## Cause Hypothesis

The feed sets its own maximum width, narrower than the shared content width the layout gives every screen, with no centring. The tab row was built as a single selected TOUS control, waiting for the AMIS tab of the Friends tab story, and both labels are upper-cased, so TOUS reads as a twin of the filter TOUT.

## Acceptance Criteria

1. **The feed spans the content width**
   **Given** the feed on a window wider than the phone layout, signed in or out
   **When** it renders
   **Then** its list spans the same content width as the hub and the collection
2. **One « Tout » until the friends tab exists**
   **Given** the feed while it has no AMIS tab
   **When** it renders
   **Then** no tab row shows, the filter row starts with TOUT, and every filter still narrows the list
3. **The phone layout is unchanged**
   **Given** the feed on a phone-width window
   **When** it renders
   **Then** it keeps the phone column, with no sideways scroll
4. **Tests cover the condition found and fixed**
   **Given** the test suite
   **When** it runs
   **Then** a test that fails on the defect and passes on the fix checks the feed's width against the hub's at desktop width, and one checks a single « Tout » on the feed
5. **Or: no change is needed, with proof**
   **Given** the reproduction
   **When** it is run on the current code
   **Then** the expected behaviour already holds, or the report was mistaken, with the evidence recorded in Notes — this supersedes 1 to 4

## References

- parent — _bmad-output/initiative-gameble/epic-brotherhood/epic-brotherhood.md, R4
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Fil d'activité
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Activity feed
- build record — _bmad-output/initiative-gameble/epic-brotherhood/story-feed-tracer-a-public-feed-of-notable-pulls-plan.md
- build record — _bmad-output/initiative-gameble/epic-brotherhood/story-feed-fallback-filters-and-empty-states-plan.md

## Notes

- Found by the author's acceptance check of 6.1 on 2026-10-08, which went to done.
- Decision (2026-10-08): the feed spans the full content width like the hub and the collection, not the centred 840 px cap of the key-screens mockup (author).
- Decision (2026-10-08): the TOUS tab row stays hidden until the Friends tab story (8) brings TOUS and AMIS together above the filters (author).
