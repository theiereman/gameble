---
id: 8
tracker_status: done
tracker_id: 276
remote: https://github.com/theiereman/gameble/issues/276
type: story
title: "The web layer's Ruby reads without comments"
parent: epic-human-readable-codebase
covers: [R2, R4]
after: [epic-port-off-react, 3]
hitl: false
risk: medium
---

# The web layer's Ruby reads without comments

## Description

Cleans `app/controllers` (with `concerns`), `helpers`, `policies`, `components`, `jobs`, `channels`, `models` and the ERB comments (48 reference lines, 778 comment lines in `app` Ruby, led by `cards_controller.rb`, `collection_grid_loading.rb`, `application_controller.rb`, `shell_helper.rb`); no markup change.

## Acceptance Criteria

Verify: `script/check_planning_references` reports nothing under `app/controllers`, `helpers`, `policies`, `components`, `jobs`, `channels`, `models`, `views`; `bin/rails test` for those directories and the controller suites, and `bin/rubocop`, pass; rendered HTML of the controller tests is unchanged.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
