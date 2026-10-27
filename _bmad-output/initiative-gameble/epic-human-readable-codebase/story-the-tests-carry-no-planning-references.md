---
id: 10
tracker_status: done
tracker_id: 278
remote: https://github.com/theiereman/gameble/issues/278
type: story
title: "The tests carry no planning references"
parent: epic-human-readable-codebase
covers: [R2]
after: [2, 3, 5]
hitl: false
risk: low
---

# The tests carry no planning references

## Description

Removes the planning references from 49 test files (62 lines; 17 under `test/domains/game`) and the story-narrating comments next to them, keeping test names and assertions; `test/lib/post_deploy_hook_test.rb` fixture strings are left.

## Acceptance Criteria

Verify: `script/check_planning_references` reports nothing under `test`; `bin/rails test` is green with the same test count.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
