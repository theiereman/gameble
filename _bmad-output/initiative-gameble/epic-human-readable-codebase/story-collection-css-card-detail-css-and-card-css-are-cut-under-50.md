---
id: 23
tracker_status: done
tracker_id: ""
type: story
title: "collection.css, card-detail.css and card.css are cut under 500 lines"
parent: epic-human-readable-codebase
covers: [R2, R3]
after: [epic-port-off-react, 3, 20]
hitl: false
risk: medium
---

# collection.css, card-detail.css and card.css are cut under 500 lines

## Description

Splits `collection.css` (1,436), `card-detail.css` (887) and `card.css` (630) the same way.

## Acceptance Criteria

Verify: `script/compare_css_cascade` shows no difference; `script/check_file_sizes` clean; the library and card detail system tests pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
