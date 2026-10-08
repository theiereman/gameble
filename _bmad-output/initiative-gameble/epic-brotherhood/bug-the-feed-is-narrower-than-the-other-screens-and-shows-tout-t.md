---
id: 13
type: bug
title: "The feed is narrower than the other screens and shows « Tout » twice"
parent: epic-brotherhood
covers: [R4]
after: [2]
refined: false
hitl: false
risk: low
---

# The feed is narrower than the other screens and shows « Tout » twice

## Description

Reproduction: open the activity feed (Fil d'activité) on a desktop. The list does not span the content width the other screens use, and a TOUS tab sits above a filter row whose first option is also « Tout ». Cause hypothesis: the feed sets its own narrower width instead of the shell's content width; the tab row was laid out for the AMIS tab of the Friends tab story and shows alone until then, beside the filters' own « all » option. Expected: the feed spans the same width as the other screens and one « Tout » is visible.

## Acceptance Criteria

Verify: A system test at desktop width finds the feed list as wide as the hub's content and one « Tout » on the feed, signed in and out; the phone layout is unchanged. Or proof that no change is needed.

## References

- parent — _bmad-output/initiative-gameble/epic-brotherhood/epic-brotherhood.md
- epic-brotherhood/story-feed-tracer-a-public-feed-of-notable-pulls-plan.md
- epic-brotherhood/story-feed-fallback-filters-and-empty-states-plan.md

## Notes

- Found by the author's acceptance check of 6.1 on 2026-10-08, which went to done.
- Open question: with the AMIS tab to come, whether the TOUS tab row waits for it or the type filter's « all » is renamed; settle with the Friends tab story.
