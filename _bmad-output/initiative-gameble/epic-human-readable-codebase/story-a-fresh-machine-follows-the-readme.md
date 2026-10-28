---
id: 33
tracker_status: review
tracker_id: ""
type: story
title: "A fresh machine follows the README"
parent: epic-human-readable-codebase
covers: [R6, R7]
after: [29, 31, 32]
hitl: true
risk: low
---

# A fresh machine follows the README

## Description

On a clean clone (a container or a machine without the project's tooling), follows only the README to start Postgres, install, run the app and the Ruby and JavaScript tests, fixes the documentation where it fails, and walks the six Done when checks.

## Acceptance Criteria

Verify: The setup, `bin/rails test`, `npm run test:js` and the app's home page succeed from a clean clone with no step outside the README; the six Done when checks are ticked in the ticket plan.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
