---
tracker_id: ""
key: ""
type: epic
title: "Packs and reveal"
parent: initiative-gameble
covers: [CAP-4, CAP-5, CAP-16]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# Packs and reveal

## Description

The core loop: a player's bank holds pre-drawn packs, the attic shows the chest and the timer, and opening a pack plays the dust, seal and flip reveal. The daily bonus adds a booster to the bank.

## Outcome

For a player: ten packs waiting at sign-up, one more every ten minutes, and a reveal worth opening. The signal is the spec's 200 ms p95 on pack opening.

## Requirements

- R1 (CAP-4; architecture AD-7): a player's bank holds ten pre-drawn packs of five cards, each with an availability time; pack credit is read from those times, and no task runs per player. Bonus and reward packs are rows of the same table, outside the cap of ten.
- R2 (CAP-4; `catalog-and-rarity.md`, Draw; AD-7; conventions, Randomness): a draw picks a rarity tier by the fixed per-card odds (steel 76 %, emerald 19 %, sapphire 4.3 %, amethyst 0.65 %, gold 0.05 %), then a card uniformly within that tier of the published season, with `SecureRandom`, from an in-memory list of the published season; a statistical test checks the odds (AD-22).
- R3 (CAP-4; AD-7, AD-10): a new player's bank is filled by a `Game` handler reacting to `Accounts::PlayerRegistered`: ten packs available at once, with at least one sapphire or better among the first ten packs, invisibly.
- R4 (CAP-4; AD-6, AD-7, AD-3): `Game::OpenPack` locks the player's bank, consumes one available pack, credits its five cards as counted holdings (one row per player and card-season with `quantity` and `reserved`, `quantity >= reserved >= 0`), publishes `Game::PackOpened`, and enqueues the draw of the replacement; a replacement is available ten minutes after the latest availability time in the bank, or ten minutes after the opening when the bank was full; a missing due pack is drawn by the operation itself; opening without an available pack is refused whatever the client does; opening answers within 200 ms at the 95th percentile.
- R5 (CAP-5; AD-16; EXPERIENCE.md, Component Patterns, Interaction Primitives, Responsive): the reveal is a React island mounted with Turbo Mount: five face-down cards covered in dust by the game's age; wiping (hover, finger, focus) reveals the rarity seal, flipping (click, tap, Enter) reveals the game; reveal length grows with rarity; "flip all" never skips a legendary's full reveal; on phone one card at a time with a progress mark; leaving mid-reveal loses nothing and resumes nothing; the accessibility floor applies (keyboard, seal shapes, titles as text, reduced motion).
- R6 (AD-17; CAP-5): card art is the game's vertical Steam image, loaded from Steam's CDN, pixelated and reduced to 16 colours in the browser by `packages/pixel-art-filter`, a standalone TypeScript package with no dependency on gameble, used by the card view component and the React components; a missing image still shows the frame and title.
- R7 (DESIGN.md, Components; EXPERIENCE.md): one card component, server-rendered (ViewComponent) and in React with the same look: face (art, title), back (frame, strap, medallion, the rarity seal by shape, dust by level).
- R8 (CAP-16; AD-9): once per UTC day a player collects a small bonus booster with better odds; a second collection the same day is refused by the database (one row per player and UTC day); the attic shows the panel while it is collectable.
- R9 (EXPERIENCE.md, Attic; CAP-18): the attic's chest shows the packs banked and opens one at a time; the timer counts down to the next pack and is hidden when the bank is full; signed out, the chest and the bonus panel are visible and acting on them leads to Steam sign-in.

## Done when

1. A new player finds ten packs in the chest and gets a sapphire or better by the tenth.
2. Opening a pack delivers five cards drawn in advance and adds them to the collection; opening without an available pack is refused.
3. The reveal shows dust by the age of the game, a rarity seal when wiped, and the game when flipped, on desktop and on phone; "flip all" never skips a legendary.
4. Card art is the vertical Steam image, pixelated and reduced to 16 colours in the browser.
5. Once a day, a player collects a bonus booster; a second attempt the same UTC day is refused.
6. Pack opening answers within 200 ms at the 95th percentile.

## Boundaries

The pack bank, draws and holdings in `Game`, the attic screen, the reveal React island, the card component and the image filter package. Not the library or card detail (epic-collection-and-sharing).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Capabilities
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-6, AD-7, AD-9, AD-16, AD-17
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, sections Component Patterns, Interaction Primitives, Key Flows (Flow 1)

## Notes

- Open question: odds of the daily bonus booster (spec). Assumption until the author decides: 3 cards, no steel, emerald 70 %, sapphire 24 %, amethyst 5 %, gold 1 % (`pending-approvals.md`).
- Decision (2026-10-02): breakdown of ten stories drafted by the orchestrator under the author's standing instruction to slice and build the following epics the same way, pending the author's review.
- Decision (2026-10-02): tracer bullet is story 1: a signed-in player finds ten packs in the chest, opens one, and sees its five cards listed — bank, draw, opening and holdings through every layer, without the reveal, timer or guarantee.
- Decision (2026-10-02): two lanes after the tracer: the game rules (2, 3, 7, 9) and the art (4, 5, 6); the reveal (6) joins both.
- Decision (2026-10-02): a JavaScript test runner (Vitest) is added with the image filter (story 4), recorded in the Stack table per AD-20.
- Decision (2026-10-02): a closing refactor sweep (story 10) follows every other story.
- Decision (2026-10-02): the reveal (story 6) takes its card count from the pack: a daily bonus pack has three cards (story 7).
- Measured (2026-10-02, story 9, `RAILS_ENV=test bin/rails game:benchmark_open_pack`): on a 15,000-card published season, 1,000 timed openings per series after 50 discarded, three runs, the worst POST `/en/packs` p95 is 9.3 ms (p50 7.8, p99 11.0, max 13.7; 15 queries per opening), the result page GET p95 4.8 ms (3 queries), `Game::OpenPack` alone p95 6.7 ms (14 queries); the cold `DrawPool` build on 15,000 rows takes 25–34 ms. An earlier run on the same machine, under load from a concurrent test suite, gave a worst POST p95 of 19.5 ms. Machine: Ruby 4.0.7, YJIT off; PostgreSQL 18.6 in Docker at localhost:5433; AMD Ryzen 5 3600, 12 CPUs. In-process, no concurrency, dev machine: a lower bound for production. No tuning was needed; the boot warm-up of the draw pool was not kept (cold build under 50 ms).
- Unknown: the final art of the attic; the author generates it from `ux-gameble/art-prompts.md`.
- Measured (2026-10-02, refactor sweep, after the reveal page): `game:benchmark_open_pack`, same machine — POST `/en/packs` worst p95 8.8 ms (15 queries per opening); the result page GET with the reveal (CardViews, CardStrings, BankSummary) p95 7.5–8.1 ms (7 queries); `Game::OpenPack` alone p95 6.3–6.4 ms; cold DrawPool build 24–30 ms.
