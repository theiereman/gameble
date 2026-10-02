---
id: 3
type: story
title: "Operations and events wiring"
parent: epic-foundation-and-steam-sign-in
covers: [R3]
after: [2]
hitl: false
risk: medium
tracker_id: 4
remote: https://github.com/theiereman/gameble/issues/4
tracker_status: backlog
---

# Operations and events wiring

## Description

Adds the dry-operation base class with its ActiveRecord transaction, configures Rails Event Store, and sets the failure-code-to-locale-key convention with one sample operation.

## Acceptance Criteria

Verify: A test shows the sample operation commits its change and its event together, and rolls both back on a Failure.

## References

- parent — _bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/epic-foundation-and-steam-sign-in.md
