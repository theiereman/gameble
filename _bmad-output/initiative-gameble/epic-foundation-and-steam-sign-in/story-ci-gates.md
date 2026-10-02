---
id: 2
type: story
title: "CI gates"
parent: epic-foundation-and-steam-sign-in
covers: [R2, R8]
after: [1]
hitl: false
risk: low
tracker_id: 3
remote: https://github.com/theiereman/gameble/issues/3
tracker_status: backlog
---

# CI gates

## Description

Adds the GitHub Actions workflow that runs Minitest, Packwerk, strong_migrations, i18n-tasks and RuboCop on every pull request.

## Acceptance Criteria

Verify: A pull request that crosses a pack boundary or drops a translation key fails CI; a clean one passes.

## References

- parent — _bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/epic-foundation-and-steam-sign-in.md
