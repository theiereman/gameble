---
id: 24
tracker_status: done
tracker_id: 292
remote: https://github.com/theiereman/gameble/issues/292
type: story
title: "trades.css, settings.css and profile.css are cut under 500 lines"
parent: epic-human-readable-codebase
covers: [R2, R3]
after: [epic-port-off-react, 3, 20]
hitl: false
risk: medium
---

# trades.css, settings.css and profile.css are cut under 500 lines

## Description

Splits `trades.css` (1,066), `settings.css` (683, 3 planning references) and `profile.css` (599) the same way, and clears the references left in `tokens.css` (3) and `application.css` (1).

## Acceptance Criteria

Verify: `script/compare_css_cascade` shows no difference; `script/check_file_sizes` and `script/check_planning_references` clean for `app/frontend/styles` and `entrypoints`; the trades, settings and profile system tests pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
