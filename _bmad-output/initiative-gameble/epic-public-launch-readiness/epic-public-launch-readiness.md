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

- R1 (CAP-14; AD-14, AD-13): a player sets their profile's visibility (public, friends only, private), kept in `Accounts` with a default, and `Game::Visibility.visible?(viewer, owner)` is the single visibility question; friends only counts no friend until epic 5 supplies the friendship query.
- R2 (CAP-14; AD-14): a player exports their data, assembled in the web layer from Accounts and Game queries; later epics add what they store.
- R3 (CAP-14; AD-10, AD-14): a player deletes their account after typing SUPPRIMER (DELETE in English); the record is anonymised, the steam id is released, `Accounts::PlayerDeleted` lets Game release what the player holds.
- R4 (CAP-15; AD-14): a visitor reports a username or profile with one of four reasons, anonymously; staff reach a queue; moderators and administrators ban and unban, no one bans an administrator or themselves; staff accounts are made from the console.
- R5 (Legal constraint): a legal page holds the no-affiliation notice, the ownership notice, the terms and the privacy notice.
- R6 (AD-7): healing runs when a season is published and gives every player short of ten packs, or with none, the missing packs all available at once; nothing else heals a bank; races between open, register, bonus and heal are tested.
- R7 (AD-21, AD-22, AD-27): the production image builds in CI, a backup is restored once, public pages are throttled or cached without caching private ones, and the CSP is enforced.

## Done when

1. From their profile, a player sets their profile's visibility (public, friends only, private), exports their data and deletes their account; each works end to end.
2. A report on a username or profile appears in the back-office; a ban blocks the account's sign-in and hides its profile.
3. Only staff accounts reach the back-office.
4. A database backup has been restored successfully at least once.
5. A legal page, reached from "Mentions légales" in the profile and the public page footer, holds the notice that gameble has no affiliation with Steam or Valve, the ownership notice (« Toutes les illustrations appartiennent aux éditeurs des jeux et à leurs artistes, que nous respectons. »), the terms of use and the privacy notice; the card detail then drops its per-card notice (`card_details.notice`).
6. Before the first deploy (from the epic 3 retrospective, 2026-10-03; decided by the author on 2026-10-07): a season's publication gives every player short of ten packs, or with none, the missing packs all available at once; nothing else heals a bank, no retry and no fill on use; races between bank operations of different stories (open, register, bonus, heal) are tested.
7. The production Docker image is built in CI or as a pre-deploy check.
8. Public pages are throttled or cached (never a private one) and the CSP is enforced after a run on staging.

## Boundaries

Data controls, reports and bans in `Accounts`, the moderation pages, backups and the legal page. Not the import pages (epic-steam-catalog).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Capabilities
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-10, AD-14, AD-21
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Information Architecture

## Notes

- Assumption: backups, the restore drill and the legal page belong here rather than in the opening epic; proposed by the facilitator, approved with the epic set on 2026-10-02.
- Decision (2026-10-07): epic 7 owns `Game::Visibility`, the visibility column and its setting; epic 5 and the feed consume it, so epic 7 is built before epics 5 and 6 in the initiative's order.
- Decision (2026-10-07): a deleted account releases its steam id so the player can sign up again.
- Decision (2026-10-07): a moderator cannot ban an administrator or themselves; unbanning is built; staff accounts are made from the console for now, written in the runbook.
- Decision (2026-10-07): the export holds what the player owns or did, except what identifies another player.
- Decision (2026-10-07): SIGNALER is built first on the public profile page, as a reusable operation, and epic 5's friend profile reuses it.
- Decision (2026-10-07): bank healing happens only at a season's publication, all packs at once; a player short of packs outside that moment waits for the next publication (author).
- Decision (2026-10-07): the CSP is enforced before opening to the public, after a run on staging checking its reports.
- Not built here: the legal texts (terms of use, privacy notice) and the restore drill are the author's (hitl); the donation link's place is decided with the legal page.
- Decision (2026-10-07): the existing fill of an empty bank before a daily bonus (`Game::CollectDailyBonus`, a player who never had a pack) is kept as the one exception to "healed only at a season's publication" (author).
