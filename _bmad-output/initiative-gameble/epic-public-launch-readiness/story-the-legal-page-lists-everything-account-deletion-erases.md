---
id: 51
tracker_status: done
tracker_id: ""
type: story
title: "The legal page lists everything account deletion erases"
parent: epic-public-launch-readiness
after: [48]
hitl: true
risk: low
---

# The legal page lists everything account deletion erases

## Description

The privacy notice's deletion paragraph (legal.privacy.deletion) leaves out data the deletion erases, such as achievements, completed sets, daily bonus claims and goal rewards, and does not say what stays without the player's identity (past trades, first discoveries, goal contributions, reports, moderation history, the event log). It is completed to match what Accounts::DeletePlayer and its handlers do, the same list the deletion dialog now gives, in French and English; the author approves the wording before it ships.

## Acceptance Criteria

Verify: The paragraph names every kind of data the deletion erases and what stays anonymised, consistent with the deletion dialog and its test; both locales match; the author has approved the wording; the full suite passes.

## References

- parent — _bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness.md

## Notes

- Decision (author, 2026-10-13): the legal text is the author's; the build drafts it and stops for approval.
