---
id: 29
tracker_status: done
tracker_id: 297
remote: https://github.com/theiereman/gameble/issues/297
type: story
title: "CI refuses what this epic cleaned"
parent: epic-human-readable-codebase
covers: [R2, R3, R5]
after: [4, 5, 6, 7, 8, 9, 10, 12, 13]
hitl: false
risk: low
---

# CI refuses what this epic cleaned

## Description

Wires `script/check_planning_references`, `script/check_file_sizes`, Prettier and Stylelint (ESLint follows once entry 28 can land) into `.github/workflows/ci.yml` and `config/ci.rb` (the `bin/ci` list), next to the existing markup-API check, and records the new commands in AGENTS.md.

## Acceptance Criteria

Verify: Both CI files run the four commands; a planted planning id, a 401-line Ruby file, a CSS file over 500 and a badly formatted TypeScript file each fail them; the full suite, `npm run test:js`, `zeitwerk:check` and `packwerk check` pass.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
