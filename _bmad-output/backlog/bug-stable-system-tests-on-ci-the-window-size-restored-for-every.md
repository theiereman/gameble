---
id: bug-stable-system-tests-on-ci-the-window-size-restored-for-every
type: bug
title: "Stable system tests on CI: the window size restored for every test, chromedriver stale nodes retried"
parent: none
covers: []
after: []
assignee: ""
refined: false
hitl: false
risk: low
severity: P2
estimate: ""
---

# Stable system tests on CI: the window size restored for every test, chromedriver stale nodes retried

## Description

The CI system-test job failed on about four runs out of five, each time on a different test. A phone-size test left the browser window resized for the tests after it, and chromedriver's stale-node errors were not retried. Every system test now starts at the desktop window size and Capybara retries a stale node.

## Acceptance Criteria

Verify: the CI system-test job passes on successive runs on develop, with no retry, skipped test or sleep added.

## References

- plan — _bmad-output/backlog/bug-stable-system-tests-on-ci-the-window-size-restored-for-every-plan.md

## Notes

- Filed on 2026-10-17, after a build that ran without a ticket; the plan beside this file is the record of that build.
