---
id: 21
tracker_status: done
tracker_id: ""
type: story
title: "shell.css and hub.css are cut under 500 lines"
parent: epic-human-readable-codebase
covers: [R2, R3]
after: [epic-port-off-react, 3, 20]
hitl: false
risk: medium
---

# shell.css and hub.css are cut under 500 lines

## Description

Splits `shell.css` (1,615 lines, 10 planning references) and `hub.css` (955 lines) the same way.

## Acceptance Criteria

Verify: `script/compare_css_cascade` shows no difference; `script/check_file_sizes` clean; `bin/rails test test/system/shell_test.rb` and the hub system tests pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
