---
key: ""
type: epic
title: "Foundation and Steam sign-in"
parent: initiative-gameble
covers: [CAP-1, CAP-18]
after: []
assignee: ""
status: done
risk: medium
estimate: ""
estimate_basis: ""
---

# Foundation and Steam sign-in

## Description

The platform baseline every other epic builds on, proven by one real path: a visitor signs in with Steam on the production site. It sets up the application, its four packs, the checks CI enforces, the deployment, and the access rules.

## Outcome

For the author and every later epic: a deployed, tested application where a Steam account becomes a player. The signal is a real sign-in on the production URL.

## Requirements

- R1 (CAP-1): a visitor signs in with their Steam account and gets a player account; signing in again reuses it; there is no other sign-in method and no stored password.
- R2 (architecture AD-1, AD-2): one Rails application with the packs `catalog`, `steam`, `accounts` and `game`; the dependency direction is checked in CI.
- R3 (architecture AD-3, AD-10): state changes are `dry-operation` classes in one transaction; each publishes a Rails Event Store event in that transaction; a failure code maps to a locale key.
- R4 (architecture AD-14; CAP-18): the session is an encrypted cookie holding the player id; each request checks the ban; every controller action has a Pundit policy; roles are visitor, player, moderator, administrator; a signed-out visitor can look but cannot act.
- R5 (architecture AD-16; DESIGN.md): pages are rendered by Rails with ViewComponent and Hotwire; Vite, TypeScript and Turbo Mount are ready for React islands; the tokens of `DESIGN.md` are CSS custom properties; the typeface is Jost.
- R6 (architecture AD-18): all copy lives in French and English locale files; the locale is the first segment of the URL; the first visit follows the browser language.
- R7 (architecture AD-21): Kamal 2 deploys one image as web, jobs and import processes; PostgreSQL has four logical databases; Cloudflare sits in front; Sentry receives errors; `/up` reports health.
- R8 (architecture AD-22): tests are Minitest with fixtures; CI on GitHub Actions fails on a test failure, a pack boundary violation, a missing translation or an unsafe migration.
- R9 (EXPERIENCE.md, Information Architecture): signing in lands on the attic page; signed out, the same page shows the Steam sign-in button; staff reach an empty back-office shell.

## Done when

1. On the production URL, a visitor signs in with Steam and lands on the attic page; signing in again reuses the same account.
2. The site answers in French under `/fr` and in English under `/en`.
3. A pull request that crosses a pack boundary, drops a translation key or adds an unsafe migration fails CI.
4. A deploy with Kamal replaces the running version without an interrupted request.
5. Signed out, a visitor sees the attic page, and a request to a mutating action is refused.
6. An error raised in production appears in Sentry.

## Boundaries

The platform baseline and the `Accounts` sign-in path. Not the catalog, packs, or any game screen beyond the attic page shell; not data controls or moderation (epic-public-launch-readiness).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Capabilities
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-1, AD-2, AD-3, AD-10, AD-14, AD-16, AD-18, AD-20, AD-21, AD-22 and the Stack table
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, section Information Architecture
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, frontmatter tokens and section Typography

## Notes

- Unknown: `omniauth-openid` 2.0.2 is not verified on Rails 8.1; the spine allows a hand-written OpenID check inside `Steam` if it fails. The sign-in entry waits on the answer.
- Unknown: whether every pinned gem runs on Ruby 4.0.7; the spine's fallback is Ruby 3.4.11. The scaffold entry settles it.
- Decision: breakdown of ten stories approved by the user on 2026-10-02, with publication to GitHub Issues.
- Decision: tracer bullet is story 1, the walking skeleton deployed to production before anything else is added.
- Decision: the stories run mostly in one lane because they share the Gemfile, routes and configuration; stories 5 and 6 can run side by side.
- Decision: hitl on story 1 (server, domain, registry, secrets), story 6 (a real Steam account and the production return URL) and story 9 (the Sentry project and its DSN).
- Decision: a closing refactor sweep (story 10) follows every other story.
- Assumption: the set check was run by the facilitator in this conversation, not by independent agents.

- Decision (2026-10-02): the author closed the epic with every story built. Done when checks 1, 4 and 6 name production, which does not exist yet; they were verified locally and on the test LXC, and the production checks are owed with the deferred production deployment (`deferred-work.md`).
- Decision (2026-10-02): ticket tracking moved from GitHub Issues to the repo store at the author's request; the tracker fields were removed from this epic's files.
