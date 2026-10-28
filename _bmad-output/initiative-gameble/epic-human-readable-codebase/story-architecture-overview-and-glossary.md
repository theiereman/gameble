---
id: 30
tracker_status: done
tracker_id: ""
type: story
title: "Architecture overview and glossary"
parent: epic-human-readable-codebase
covers: [R6]
after: [1, 2, 16, 17, 26]
hitl: false
risk: low
---

# Architecture overview and glossary

## Description

Writes `docs/architecture.md` (the domains and their dependency diagram, the operation/event/query anatomy, the front-end screen anatomy, the CI checks and where to look first) and `docs/glossary.md` (the domain terms as the code spells them: season, set, tier, edition, card-season, holding, bank, pack versus domain, capsule, and so on), in English, from the spine as amended by entry 1, without planning ids. Both stay readable at a glance, with links into the code.

## Acceptance Criteria

Verify: Every constant and path named in the two documents exists (`git grep` check script or a reviewer's pass over the list); no planning id appears.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
