---
tracker_id: ""
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
- R8. No private infrastructure in tracked configuration: LAN addresses, personal paths and private hosts come from the environment. Source: author, 2026-10-07.

## Done when

1. The backend's domain code lives under `app/domains/`, packwerk's check passes in CI, and the full test suite is green.
2. A CI step finds no planning reference (AD-n, CAP-n, story n.n, epic n, DESIGN.md, EXPERIENCE.md) in `app`, `config`, `db`, `lib`, `script` or `test`.
3. No production Ruby or TypeScript file exceeds 400 lines and no CSS file exceeds 500.
4. ESLint, Prettier and Stylelint run in CI and pass.
5. A developer following only the README on a fresh machine runs the app and the tests; the repository holds the architecture overview, the glossary, CONTRIBUTING, `.env.example` and an AGPL-3.0 LICENSE.
6. No LAN address, personal path or private host is hard-coded in tracked configuration.

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
