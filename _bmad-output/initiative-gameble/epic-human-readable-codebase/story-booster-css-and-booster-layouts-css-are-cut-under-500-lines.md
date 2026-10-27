---
id: 22
tracker_status: done
tracker_id: 290
remote: https://github.com/theiereman/gameble/issues/290
type: story
title: "booster.css and booster-layouts.css are cut under 500 lines"
parent: epic-human-readable-codebase
covers: [R2, R3]
after: [16, 3, 20]
hitl: false
risk: medium
---

# booster.css and booster-layouts.css are cut under 500 lines

## Description

Runs on develop after epic 21 is merged. Splits `booster.css` (1,595 lines) and `booster-layouts.css` (791 lines) the same way, after the booster's anatomy of entries 15 and 16 is settled.

## Acceptance Criteria

Verify: `script/compare_css_cascade` shows no difference; `script/check_file_sizes` clean; `bin/rails test test/system/booster_test.rb` passes.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
