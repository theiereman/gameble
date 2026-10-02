---
key: ""
type: initiative
title: "gameble MVP: a Steam card game played every day by the Brotherhood"
parent: none
covers: [CAP-1, CAP-2, CAP-3, CAP-4, CAP-5, CAP-6, CAP-7, CAP-8, CAP-9, CAP-10, CAP-11, CAP-12, CAP-13, CAP-14, CAP-15, CAP-16, CAP-17, CAP-18]
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

The spec is the requirement source: `spec-gameble/spec-gameble.md`, capabilities CAP-1 to CAP-18. Its companions bind every epic: the architecture spine (AD-1 to AD-22), `DESIGN.md`, `EXPERIENCE.md`, `catalog-and-rarity.md`, `brotherhood-tone.md`.

## Done when

1. The author plays every day for a month alongside at least 10 active players, not all of them friends, and sees their pulls and trades in the feed.
2. Every capability CAP-1 to CAP-18 is live in production, in French and in English.
3. Opening a pack answers within 200 ms at the 95th percentile.
4. No blocking bug stays open for more than a day during the first month.

## Boundaries

One Rails application and its Steam import, cut by capability. Not the V2 market, later seasons or native apps; see the spec's non-goals and `later-roadmap.md`. Tracer path: a visitor signs in with Steam (epic 1), on a small imported and published catalog (epic 2), opens a pack and flips its cards (epic 3).

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
- Open question: prestige formula and tier thresholds (spec); epic-steam-catalog waits on real import data.
- Open question: the list of achievements (spec); epic-brotherhood waits on it.
- Open question: odds of the daily bonus booster and of the weekly goal's rare pack (spec); epic-packs-and-reveal and epic-brotherhood wait on it.
- Open question: how much a trade counts in the weekly goal (spec); epic-brotherhood waits on it.
- Unknown: whether the 2–4 week estimate of the brief still holds after the scope added on 2026-10-02; to re-check once epics are incepted.
