---
remote: https://github.com/theiereman/gameble/issues/268
tracker_id: 268
key: ""
type: epic
title: "Readable by humans: the codebase before the public release"
parent: initiative-gameble
covers: []
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# Readable by humans: the codebase before the public release

## Description

Before the MVP goes to production and the GitHub repository opens to the public, the code is reworked so that a developer who works without AI can read, run and maintain it. The code explains itself through its names and structure rather than through comments citing planning documents; the backend reads as one Rails application split into domain directories; oversized files are cut; the front-end gets the linters a newcomer expects; the documentation is rewritten for a newcomer; the repository carries an AGPL-3.0 licence. Nothing a player sees changes. It is the last epic before production, run once every feature is written, so the cleanup covers the whole codebase once.

## Outcome

For a developer discovering gameble on GitHub: they clone it, run it and find their way in the code from the README alone, without the planning documents and without an AI assistant. The signal is Done when 5.

## Requirements

No capability of the spec: a platform epic. Each line cites the source it comes from.

- R1. The backend is one Rails application. The packs become domains under `app/domains/<name>/` (DDD vocabulary), still package boundaries checked by packwerk; Ruby namespaces unchanged. Source: author, 2026-10-07; amends the architecture spine, Modules and AD-2.
- R2. The code reads without comments: no reference to planning ids (AD-n, CAP-n, R-n, story n.n, epic n, DESIGN.md, EXPERIENCE.md) in code, tests or configuration; a comment survives only where the code cannot say it (an external constraint). Intent is carried by names, extracted methods and objects. Source: author, 2026-10-07.
- R3. No oversized source file: production Ruby and TypeScript files stay within 400 lines, CSS files within 500. Source: author, 2026-10-07 ("découper les trop gros fichiers").
- R4. A consistency pass removes duplication and the conventions that diverged between build sessions. Source: author, 2026-10-07 ("tout le reste aussi").
- R5. The front-end is linted and formatted: ESLint, Prettier and Stylelint, run in CI. Source: author, 2026-10-07.
- R6. Documentation for a newcomer: a rewritten README (what gameble is, setup, tests, deploy), an architecture overview, a glossary of the domain terms, CONTRIBUTING, `.env.example`. Source: author, 2026-10-07; spec Constraints, "All repo text is in English".
- R7. The repository is licensed AGPL-3.0. Source: author, 2026-10-07; spec Constraints, "Open source".
- R8. No private infrastructure in tracked configuration: LAN addresses and personal paths come from the environment or leave; the hosts and names accepted in the Notes stay. Source: author, 2026-10-07; narrowed 2026-10-27.

## Done when

1. The backend's domain code lives under `app/domains/`, packwerk's check passes in CI, and the full test suite is green.
2. A CI step finds no planning reference (AD-n, CAP-n, story n.n, epic n, DESIGN.md, EXPERIENCE.md) in `app`, `config`, `db`, `lib`, `script` or `test`.
3. No production Ruby or TypeScript file exceeds 400 lines and no CSS file exceeds 500.
4. ESLint, Prettier and Stylelint run in CI and pass.
5. A developer following only the README on a fresh machine runs the app and the tests; the repository holds the architecture overview, the glossary, CONTRIBUTING, `.env.example` and an AGPL-3.0 LICENSE.
6. No LAN address or personal path is hard-coded in tracked configuration; the hosts and names the Notes accept (staging domain, `theiereman`, the `LEGAL_*` name) stay.

## Boundaries

A cleanup of the whole codebase, no feature: behaviour, URLs, markup seen by players and query counts stay as they are; anything bigger than a cleanup goes to `deferred-work.md`. The AI tooling (`_bmad`, `_bmad-output`, `.claude`, `.agents`) and the git history stay as they are: they show how gameble was made. `AGENTS.md` stays, since development continues with AI. Not the production setup itself (the author does it after this epic).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- constraint — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Constraints ("All repo text is in English", "Open source")
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, sections Modules and AD-2 (packs, packwerk)
- prior art — _bmad-output/initiative-gameble/epic-collection-and-sharing/story-refactor-sweep-plan.md (a bounded cleanup with behaviour kept)
- guidance — .claude/skills/bmod-method/help/preparing-a-repo-for-agents.md

## Notes

- Decision (2026-10-07, author): the last epic of the MVP, after every feature epic and before production; meanwhile a rule in `AGENTS.md` (bmad-project-context) stops new planning references and explanatory comments in the code of the remaining epics.
- Decision (2026-10-07, author): the AI tooling and the git history stay in the public repository.
- Decision (2026-10-07, author): self-explanatory code over comments; no ADR folder in the repository, the architecture overview carries what a newcomer needs.
- Decision (2026-10-07, author): packwerk is kept; packs are renamed domains and moved to `app/domains/<name>/`, each still a packwerk package.
- Unknown: the exact layout inside `app/domains/<name>/` that packwerk, packs-rails (`pack_paths` in `packs.yml`, or a few lines of autoload configuration in its place) and Zeitwerk all accept — Rails autoloads every `app/*` folder, so `app/domains` must not become a `Domains` namespace. The architecture entry settles it with a short trial before the move; the move entry waits on it.
- Decision (2026-10-07, author): licence AGPL-3.0 (open source; a modified version served online must publish its source).
- Source conflict: architecture, Modules and AD-2 — the spine places domain code in `packs/<name>` vs the author's decision for `app/domains/<name>`; an entry of this epic amends the spine through bmad-architecture before the move.
- Assumption: the size limits (400 lines for Ruby and TypeScript, 500 for CSS) were proposed while slicing and accepted with the envelope; tests are not held to them.
- Waits on epics 5, 6, 7, 9 and 11 because: the cleanup covers the whole codebase once, after its last feature is written.
- Decision (2026-10-09, author): the host is chosen after comparing prices, at the end of this epic. Its last entry, with the author in the loop: the host's name, postal address and data-centre country go into `config/deploy.production.yml` (`LEGAL_HOST_NAME`, `LEGAL_HOST_ADDRESS`) and the privacy notice's processors; the app then refuses to boot in production when a `LEGAL_*` variable is missing, and the legal page's `access_publisher` fallback goes. Without the host line the legal page breaks the LCEN for an anonymous publisher, so production does not open before it.
- Decision (2026-10-27, author): `LEGAL_HOST_NAME: Thomas Eyermann` and `LEGAL_HOST_ADDRESS: France` are the real values (the author hosts it); this supersedes the 2026-10-09 line above on waiting for a host: the host entry keeps only the production boot check for missing `LEGAL_*` variables, the removal of the legal page's fallback and the privacy notice's processors line, and no longer waits on the author.
- Decision (2026-10-27, author): writes outside operations (`sum_weekly_goal_job.rb`, `handlers/player_activity.rb`) move behind operations, unless a write is truly justified as an exception (a bulk insert whose per-row operation would break its performance or its atomicity): then it stays and AGENTS.md documents the exception with its reason, for that one. The builder of entry 5 judges per write and records which.
- Decision (2026-10-27, author): `Catalog::UpsertDraftCard` is removed and `steam_apps.carded_run_id` dropped (entry 13) now, even while production is in maintenance on v0.1.1.
- Decision (2026-10-27, author): private infrastructure, "everything cited is acceptable": the staging domain `gameble.dotsncircles.com`, `theiereman` (image, repository, donation URL) and the `LEGAL_*` personal name stay as they are in tracked files. Entry 25 shrinks to what Done when 6 names that is not cited as acceptable: LAN addresses (`192.168.x.x`) and personal paths; it is no longer `hitl`. R8 and Done when 6 are narrowed to match.
- Decision (2026-10-27, author): newcomer docs. `CONTRIBUTING.md` becomes first of all a guide for developers (setup pointers, workflow, tests, conventions, architecture detail, how to read the codebase); the player-facing bug-report guide moves to `docs/reporting-problems.md` and is linked from the README. `README.md` becomes a quick summary of what the project is and its architecture only at the surface, linking to `CONTRIBUTING.md`, `RELEASING.md` and the `docs/` files (architecture overview, glossary, `docs/operations.md` which receives the deployment, backup, Sentry and Steam-import material now in the README). Entry 26 moves the material, entry 30 writes architecture and glossary, entry 31 rewrites README and CONTRIBUTING and adds `.env.example`.
- Decision (2026-10-27, author): the booster root controller entry may be split in two when it starts; it is pre-split into entries 15 (opening sequences and the render region) and 16 (reveal, store and celebration, ending at 400 lines or fewer), following the regions of `booster_controller.ts` at the head of `epic/port-off-react`.
- Prerequisite (2026-10-27): epic 21 (`epic/port-off-react`) is about to be merged into `develop`. The entries on the booster, the trade board and the front end's TypeScript (14 to 19, 22, 27, 28) run on develop after that merge; each says so in the first line of its description. The cuts and counts were measured on that branch's head, 4d331726.
- Decision (2026-10-27, agent's choice, for the author to confirm): the epic ships in release 0.5.0, the milestone of epics 17 and 19, which wait on it, so it ships first within that milestone. The sync stops without a release.
- Decision (2026-10-27, tracer bullet and lanes): entries 1, 2 then a small domain (6) through the checks of entry 3 prove the layout, the checks and the cleanup recipe; the front-end entries (14 to 24) and 8 are disjoint from `packs/` and run in parallel; 25 and 26 never run together with another README edit; 27 runs alone on the front end.
- Decision (2026-10-27, set check): independent review applied: pathspec exclusions for the AI tooling in greps, path arguments for the check scripts, `script/compare_css_cascade` committed by entry 20 and entries 21 to 24 after it, entries 9, 5 and 3 ordered before the entries that edit the same files, the legal boot check must not break the image build or staging. Suggested for the builders, not yet split: entries 5 (writes behind operations apart from the comment pass), 6 (accounts apart from catalog), 8, 12 (i18n apart) and 19 are large and may be split when they start; a handler that calls an operation must not publish a second event, so entry 5 may end in a documented exception.
- Decision (2026-10-27, author, layout of the domains): each domain lives at `app/domains/<name>/app/<kind>/<Namespace>/...`, its current pack tree moved down one level, with `app/domains` kept out of Rails' autoload roots by one line in `config/application.rb` (the exclusion of `domains` from the `app` path) and `packs.yml` listing `app/domains/*`; constants keep their names (`Accounts::Player`). The trial of entry 1 (branch `build/12-1-layout-trial`, plan `spike-settle-the-domain-layout-by-a-trial-plan.md`) moved `accounts` with packwerk, zeitwerk and the whole suite green. Entry 2 applies it to the four packs; the trial branch is not merged as it stands.
- Decision (2026-10-27, author, entry 34 added): a repost rate limit is added to this epic although it is a behaviour change, not a cleanup: a cap per player plus a duplicate guard on the card, in `Game::RepostCard`. The numbers (10 an hour, one repost of a card per 24 hours) are the agent's proposal, to confirm.
- Decision (2026-10-27, author, ESLint): TypeScript stays at 7; entry 28 (ESLint) waits until typescript-eslint supports TypeScript 7 (8.72.1 accepts `>=4.8.4 <6.1.0`). The built branch `build/12-28-eslint` (commit f4830bbc, which pins `typescript` 6.0.3) is not merged. Entry 29 no longer waits for entry 28 and wires only the checks that exist (the two scripts, Prettier, Stylelint, the Ruby suite); entry 28 is wired into CI when it lands.
- Decision (2026-10-27, author, ESLint): dropped for this epic ("tant pis pour eslint"); entry 28 is dropped, its branch `build/12-28-eslint` stays unmerged, and the epic's Done when no longer requires a JavaScript linter beyond Prettier and Stylelint.
