---
id: 13
tracker_status: done
tracker_id: 281
remote: https://github.com/theiereman/gameble/issues/281
type: story
title: "Remove the dead code the sweeps recorded"
parent: epic-human-readable-codebase
covers: [R4]
after: [6, 7, 9, 10]
hitl: false
risk: medium
---

# Remove the dead code the sweeps recorded

## Description

Removes `Catalog::UpsertDraftCard` (moving `db/seeds.rb` and its tests to the staged operations) and drops the unused `steam_apps.carded_run_id` column with its foreign key and index in an expand/contract pair of migrations, regenerating `db/schema.rb` as CI does. The author approved it on 2026-10-27, even while production is in maintenance on v0.1.1.

## Acceptance Criteria

Verify: `git grep UpsertDraftCard -- . ':(exclude)_bmad' ':(exclude)_bmad-output' ':(exclude).claude' ':(exclude).agents'` finds nothing; `db/schema.rb` has no `carded_run_id`; the CI schema-drift steps and `bin/rails test` pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
