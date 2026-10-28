---
id: 38
tracker_status: done
tracker_id: ""
type: bug
title: "Two live update system tests fail at random on CI"
parent: epic-public-launch-readiness
after: []
refined: false
hitl: false
risk: low
---

# Two live update system tests fail at random on CI

## Description

Reproduction: CI's system-test job failed on develop (run 38230348728) and on the pg and vite Dependabot branches (runs 38234464038 and 38234490670), each time in LiveUpdatesTest, and passed when the failed job was rerun. Two tests fail: "the live feed keeps its newest entries up to the feed's limit" finds none of the five new legendary entries at the top of the feed, and "the swap after an acceptance plays out before the accepter's own update refreshes the board" fails its check that the update arrived while the cards were flying. Cause hypotheses: the swap test reads timing-dependent page state once instead of through a retrying matcher; in the feed test, the broadcast leaves before the feed page can apply it, or is applied and then replaced. Expected: both tests pass on every run under CI's load, and still fail when the live update they check is broken.

## Acceptance Criteria

Verify: Both tests pass in 20 consecutive parallel runs on a loaded machine, or CI's system-test job is green on five consecutive runs, with no retry, skip or sleep added; breaking the live update each test checks still makes it fail. Or proof that no change is needed.

## References

- parent — _bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness.md
- _bmad-output/backlog/bug-stable-system-tests-on-ci-the-window-size-restored-for-every-plan.md

## Notes

- Raised by the author on 2026-10-12 while the Dependabot pull requests were reviewed.
- Three local runs of both tests passed: the failures have only shown under CI's load.
