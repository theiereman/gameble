---
tracker_id: ""
key: ""
type: epic
title: "Ready for the public"
parent: initiative-gameble
covers: [CAP-14, CAP-15]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Ready for the public

## Description

What must exist before strangers are invited: players control their personal data, moderators handle reports and bans, backups run, and the site states it has no affiliation with Steam or Valve.

## Outcome

For a player: control over their data. For the author: a site he can open to people he does not know.

## Requirements

Completed at this epic's inception. The source lines are CAP-14 and CAP-15 of the spec, the spec's Legal constraint, and the spine's Deferred items on backups.

## Done when

1. From their profile, a player sets their profile's visibility (public, friends only, private), exports their data and deletes their account; each works end to end.
2. A report on a username or profile appears in the back-office; a ban blocks the account's sign-in and hides its profile.
3. Only staff accounts reach the back-office.
4. A database backup has been restored successfully at least once.
5. A legal page, reached from "Mentions légales" in the profile and the public page footer, holds the notice that gameble has no affiliation with Steam or Valve, the terms of use and the privacy notice.
6. Before the first deploy (from the epic 3 retrospective, 2026-10-03): a player without a bank gets one when they use the game, a failed bank fill is retried, the healed bank's schedule is decided, and races between bank operations of different stories (open, register, bonus, heal) are tested.
7. The production Docker image is built in CI or as a pre-deploy check.

## Boundaries

Data controls, reports and bans in `Accounts`, the moderation pages, backups and the legal page. Not the import pages (epic-steam-catalog).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Capabilities
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-10, AD-14, AD-21
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Information Architecture

## Notes

- Assumption: backups, the restore drill and the legal page belong here rather than in the opening epic; proposed by the facilitator, approved with the epic set on 2026-10-02.
