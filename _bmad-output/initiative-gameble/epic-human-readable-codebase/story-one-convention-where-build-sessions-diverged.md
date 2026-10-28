---
id: 12
tracker_status: done
tracker_id: ""
type: story
title: "One convention where build sessions diverged"
parent: epic-human-readable-codebase
covers: [R4]
after: [8, 11]
hitl: false
risk: medium
---

# One convention where build sessions diverged

## Description

Unifies the throttled-redirect lambda repeated in 9 of the 19 controllers using `rate_limit`, the two controller-local `answer` helpers (`reposts_controller.rb`, `trades_controller.rb`) beside `ApplicationController#refuse_with`, and the operation-result handling where three or more controllers share the same shape; adds the 19 missing `zero` forms to the French plural keys (text identical to `one`) and the dynamic `rate_limit.*` keys to `ignore_unused` in `config/i18n-tasks.yml`. Status codes, redirects and messages stay as they are.

## Acceptance Criteria

Verify: The controller tests and `test/integration` pass unchanged; `bundle exec i18n-tasks missing` and `unused` are clean; every French plural key under `config/locales/fr.yml` has a `zero` form.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md

## Notes

- Unknown: Which of the 37 `success?` branches really share one shape; the plan lists the groups it unifies and leaves the others.
