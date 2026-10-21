---
id: 41
tracker_status: done
tracker_id: 149
remote: https://github.com/theiereman/gameble/issues/149
type: story
title: "The private collaboration notes leave the agent instructions"
parent: epic-public-launch-readiness
after: []
hitl: true
risk: low
---

# The private collaboration notes leave the agent instructions

## Description

The root CLAUDE.md holds a "Personal notes (remove before the repo goes public)" section written for the private phase, when friends share the repository, such as assigning a GitLab issue to oneself on starting its ticket so the others see it is taken. The section is removed before the repository goes public, with anything else in the repository that only makes sense for that private group.

## Acceptance Criteria

Verify: CLAUDE.md no longer has the personal notes section; a search of the repository finds no instruction meant only for the private collaborators; the full suite, vitest, packwerk and zeitwerk pass.

## References

- parent — _bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness.md

## Notes

- Requested by the author on 2026-10-12.
- The author decides when the repository goes public; this is done just before.
