---
id: 20
tracker_status: done
tracker_id: ""
type: story
title: "landing.css is cut under 500 lines"
parent: epic-human-readable-codebase
covers: [R2, R3]
after: [epic-port-off-react, 3]
hitl: false
risk: medium
---

# landing.css is cut under 500 lines

## Description

Splits `landing.css` (2,054 lines) into per-section files of at most 500 lines, imported in the same cascade order from `app/frontend/entrypoints/application.css`, and cleans its comments. Commits the comparison as `script/compare_css_cascade` (resolves the imports, strips comments and whitespace, normalizes number and colour spelling, prints a diff against a git revision) for entries 21 to 24 and 27; entries 20 to 24 each add their imports to `application.css`, a one-line merge when they overlap.

## Acceptance Criteria

Verify: The compiled stylesheet's rules are identical in content and order before and after (a script concatenating the resolved imports, comments and whitespace stripped, diffed); `script/check_file_sizes` clean for these files; the landing system tests pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
