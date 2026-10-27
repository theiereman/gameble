---
id: 6
tracker_status: done
tracker_id: 274
remote: https://github.com/theiereman/gameble/issues/274
type: story
title: "The catalog and accounts domains read without comments"
parent: epic-human-readable-codebase
covers: [R2, R4]
after: [2, 3]
hitl: false
risk: medium
---

# The catalog and accounts domains read without comments

## Description

Same cleanup for `app/domains/catalog` (98 files, 813 comment lines, 21 reference lines) and `app/domains/accounts` (43 files, 256 comment lines, 14 reference lines).

## Acceptance Criteria

Verify: `script/check_planning_references` reports nothing under the two domains; their tests, `bin/rubocop` and `packwerk check` pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
