---
key: ""
type: initiative
title: "gameble MVP: a Steam card game played every day by the Brotherhood"
parent: none
covers: [CAP-1, CAP-2, CAP-3, CAP-4, CAP-5, CAP-6, CAP-7, CAP-8, CAP-9, CAP-10, CAP-11, CAP-12, CAP-13, CAP-14, CAP-15, CAP-16, CAP-17, CAP-18, CAP-19, CAP-20, CAP-21]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
tracker_id: milestone-1
remote: https://github.com/theiereman/gameble/milestone/1
---

# gameble MVP: a Steam card game played every day by the Brotherhood

## Description

gameble is a free web trading card game where every card is a Steam game. Players open pre-drawn packs, reveal them, complete sets, trade with friends and feed a weekly Brotherhood goal. The spec owns the capabilities, constraints and non-goals; this initiative delivers its MVP.

## Outcome

For French- and English-speaking gamers with a Steam account: a card game worth opening every day. The signal is the spec's success signal.

## Requirements

The spec is the requirement source: `spec-gameble/spec-gameble.md`, capabilities CAP-1 to CAP-21. Its companions bind every epic: the architecture spine (AD-1 to AD-28), `DESIGN.md`, `EXPERIENCE.md`, `catalog-and-rarity.md`, `brotherhood-tone.md`.

## Done when

1. The author plays every day for a month alongside at least 10 active players, not all of them friends, and sees their pulls and trades in the feed.
2. Every capability CAP-1 to CAP-21 is live in production, in French and in English.
3. Opening a pack answers within 200 ms at the 95th percentile.
4. No blocking bug stays open for more than a day during the first month.

## Boundaries

One Rails application and its Steam import, cut by capability. Not the V2 market, later seasons or native apps; see the spec's non-goals and `later-roadmap.md`. Tracer path: a visitor signs in with Steam (epic 1), on a small imported and published catalog (epic 2), opens a pack and flips its cards (epic 3). Since the 2026-10-05 redesign, epic-space-terminal-redesign reworks the built screens before epics 5 to 7 build theirs in the new shell.

- Touch point: Steam OpenID — sign-in verification; owner: epic-foundation-and-steam-sign-in
- Touch point: hosting server, Cloudflare, Sentry, GitHub Actions — configured, not built; owner: epic-foundation-and-steam-sign-in
- Touch point: Steam store API and Web API — read by the import; owner: epic-steam-catalog
- Touch point: Steam CDN — card images loaded and filtered in the browser; owner: epic-packs-and-reveal

## References

- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Capabilities
- constraint — the same spec, section Constraints
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md and EXPERIENCE.md
- brief — _bmad-output/initiative-gameble/brief-gameble/brief-gameble.md, for history only

## Notes

- Decision: seven epics, cut by capability with a platform baseline first; the user approved the set and its order on 2026-10-02.
- Decision: the daily bonus (CAP-16) sits with packs and achievements (CAP-17) with the Brotherhood; approved 2026-10-02.
- Decision: CAP-18 is shared — epic 1 delivers the access rules, epic 4 the public pages; approved 2026-10-02.
- Decision: every choice more than one epic must adopt lives in the architecture spine; no cross-epic decision entry is needed.
- Open question: prestige formula and tier thresholds (spec); epic-steam-catalog waits on real import data. Resolved 2026-10-06: tier shares kept at calibration, formula chosen by the author (story 2.12).
- Open question: the list of achievements (spec); epic-brotherhood waits on it.
- Decision (2026-10-03): daily bonus booster odds confirmed (spec CAP-16). Open question: odds of the weekly goal's rare pack (spec); epic-brotherhood waits on it.
- Direction (2026-10-03): the author will redo the UX through bmad-ux, menus with a screen per feature replacing the attic's object metaphor.
- Open question: how much a trade counts in the weekly goal (spec); epic-brotherhood waits on it.
- Unknown: whether the 2–4 week estimate of the brief still holds after the scope added on 2026-10-02; to re-check once epics are incepted.
- Decision (2026-10-05): the space-terminal redesign reworks the built screens in a new epic, epic-space-terminal-redesign, placed after epic 4 and before epic 5 (shell first, then screen by screen, AD-28); epics 1 to 4 stay closed with their retrospectives. Approved by the author.
- Decision (2026-10-05): card backs (CAP-20) get their own epic, epic-card-backs, after epic 6, once every unlocking event exists; the redesign shows the Standard back only. Friends' presence (CAP-21) goes to epic 5; the repost (CAP-19) stays in epic 6. Approved by the author.
- Open question: the reference low-end Android for the performance budget (architecture Deferred); epic-space-terminal-redesign's booster work waits on it.
- Decision (2026-10-06, author): the MVP is built and validated on staging (gameble.dotsncircles.com); production (gameble.com on a VPS) is set up only at the very end, once the author has validated the MVP.
- Decision (2026-10-07, author): a last epic, epic-human-readable-codebase (12), after every feature epic and before production, makes the code readable and maintainable by a developer working without AI before the repository opens to the public: packs renamed domains (packwerk kept), self-explanatory code without planning references, oversized files cut, front-end linters, newcomer documentation, AGPL-3.0. The AI tooling and the git history stay public.
