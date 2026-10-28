---
id: 9
tracker_status: done
tracker_id: ""
type: story
title: "Config, migrations, lib and scripts read without planning references"
parent: epic-human-readable-codebase
covers: [R2]
after: [2, 3]
hitl: false
risk: low
---

# Config, migrations, lib and scripts read without planning references

## Description

Removes the planning references and name-restating comments from `config` (22 lines), `db/migrate` (55 lines in 38 files; comments only, no statement changes), `lib` (3) and `script` (15 lines, all in `script/pixel_art/export.mjs`, by editing the script, never `app/frontend/images/pixel`), and from `db/seeds.rb`.

## Acceptance Criteria

Verify: `script/check_planning_references` reports nothing under these directories; `git diff db/migrate` shows only comment lines; `db/schema.rb` is unchanged after the CI migration-drift step; `node script/pixel_art/export.mjs --check` passes.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
