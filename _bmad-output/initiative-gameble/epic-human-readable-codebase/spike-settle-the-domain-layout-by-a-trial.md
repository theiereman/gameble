---
id: 1
tracker_status: done
tracker_id: 269
remote: https://github.com/theiereman/gameble/issues/269
type: spike
title: "Settle the domain layout by a trial"
parent: epic-human-readable-codebase
covers: [R1]
after: [epic-port-off-react, epic-public-launch-readiness, epic-friends-and-trades, epic-brotherhood, epic-season-preparation, epic-recognizable-sets, epic-card-catalog, epic-easier-trades, epic-screen-walkthrough, epic-visitor-landing]
hitl: true
risk: high
---

# Settle the domain layout by a trial

## Description

On a throwaway branch, moves `accounts` (the pack that depends on nothing) to `app/domains/accounts/` and finds the layout that packwerk, packs-rails (`pack_paths` in `packs.yml`, or a few lines of autoload configuration) and Zeitwerk all accept without making `app/domains` a `Domains` namespace, covering the nested `package.yml`, `Packs.all`, the rake tasks and the test directory; records the finding as a dated Decision in the epic Notes, then amends the architecture spine (Modules, AD-1, AD-2, the layer table) through bmad-architecture so that it says `app/domains/<name>`.

## Acceptance Criteria

Verify: On the trial branch `bundle exec packwerk validate && bundle exec packwerk check`, `bin/rails zeitwerk:check` and `bin/rails test test/packs` pass with `accounts` moved; the epic Notes hold the layout Decision and the spine no longer says `packs/<name>`.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md

## Notes

- Unknown: Whether `app/domains/<name>/` can hold `app/models/<ns>/...` below it (so `Accounts::Player` stays at that constant) or the domain's code sits directly in `app/domains/<name>/`; the trial answers it.
