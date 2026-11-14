---
tracker_id: ""
key: ""
type: epic
title: "Duel capsule, record and achievements"
parent: initiative-gameble
covers: ["CAP-42", "CAP-17", "CAP-20"]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# Duel capsule, record and achievements

## Description

Winning a duel gives a reason to come back without turning duels into a capsule farm: the first real win of the UTC day gives a duel capsule of 3 cards at the daily bonus odds, in the special reserve, in its own blue-steel canister, and it counts in the Flukeometer; a win where the game played one of the winner's moves gives none. The profile and the Duels screen show the player's wins, losses and draws and their last results; Comment ça marche explains duels. Ten duel achievements and the Duelliste card back reward duels the way CAP-17 and CAP-20 reward the rest of the game. The epic ends with release 1.4.0 in production, epics 42 to 44 together.

## Outcome

For the players: a duel worth winning once a day, a record to show, and achievements to chase. For the author: release 1.4 live in production, whose signal is the spec's: 30 days after it, at least 10 players have finished a live duel with no automatic move of theirs, and half of them duel again in a later week (spec, Success signal).

## Requirements

- R1 — A duel capsule is a pack of kind `duel` (AD-7): 3 cards at the daily bonus odds (CAP-16), in the special reserve, opened like any special capsule. Its origin is `{colors.capsule-duel}` with the crossed-blades emblem, exported by `script/pixel_art/export.mjs` and `origin_canisters.mjs` from the grid in DESIGN.md, and the label "CAPSULE DE DUEL"; the capsule screen reads "EN OUVERTURE · CAPSULE DE DUEL". `Game::Reserve::KINDS` and the kind and size checks on `game_packs` gain `duel`; `Game::Fortune` gains a `duel_packs` column and `LuckOdds` the duel kind, so the Flukeometer counts duel capsules. (CAP-42; `duel-rules.md`, Reward and record; AD-7, AD-54 Costs, AD-57; DESIGN.md, Colors (capsule origins) and Special capsules; EXPERIENCE.md, State Patterns, Special capsule in the reserve; Copy deck, Special capsules; Écrans des Duels board 10)
- R2 — The finishing move draws the duel capsule for the winner, in its transaction, when none of the winner's moves is automatic and the winner has no duel pack for the UTC day the duel ends; `duel_day`, set only on duel packs, with a unique index on player and `duel_day`, makes a second grant impossible whatever the client does. Other wins, losses and draws give nothing material; duels never mint PiCoins nor move a card between players. (CAP-42; `duel-rules.md`, Reward and record; spec Assumptions (the capsule's day) and Constraints (Duels move nothing between players); AD-57)
- R3 — On the player's first win of the UTC day the duel result shows "CAPSULE DE DUEL GAGNÉE" in a panel with the duel capsule's small canister and a `{colors.capsule-duel}` edge, linked to the capsule screen; a win with an automatic move of the winner says "Pas de capsule : un de vos coups a été joué automatiquement."; a later win that day says "Capsule de duel déjà gagnée aujourd'hui.". (CAP-42; EXPERIENCE.md, Duels, Duel result; Flow 11; DESIGN.md, Duels, Duel result; Copy deck, Duel result and record)
- R4 — Wins, losses and draws are read from finished duels and their seats; a profile's ACTIVITÉ stats show the "Duels" figure group under the profile's visibility rules. The Duels screen shows the player's record ("Duels : <w> victoires, <l> défaites, <d> égalités") with the link "Règles du duel" to Comment ça marche's duels section under it, and "DERNIERS DUELS", the last ten results, each row opening its duel result and named "Victoire contre <name>, 6 à 4", likewise for a loss or a draw, a removed opponent reading "anonyme". On desktop DERNIERS DUELS sits in the left column. (CAP-42; `duel-rules.md`, Reward and record; AD-57; EXPERIENCE.md, Duels, Duels screen and Duel record; Public profile; DESIGN.md, Duels, Duels screen, Duel record and Desktop; Copy deck, Public profile, Duels screen and challenges, Duel result and record)
- R5 — Comment ça marche has a duels section: decks, the five stats and the trump, a round, ties, automatic moves, the duel capsule and its odds, every number read from what the game applies. (CAP-42; EXPERIENCE.md, Information Architecture, Comment ça marche)
- R6 — Ten duel achievements join `Game::Achievements` with the titles, conditions and flavours of EXPERIENCE.md's rows 24 to 33 in both locales: finish a first duel; win a first duel, 10, 50 and 100 duels; win a round with a Commune card against a Légendaire card; win a duel 10 – 0; win a duel whose tied score went to the margin; duel 5 different friends; win at least one round with each of the five stats. Their metrics are read by `Game::AchievementProgress` from finished duels, their seats and rounds; a duel counts once it ends, automatic moves included, except that a round won by the player's automatic move does not count for Valuation Error or Certified Versatility. `GrantAchievementsJob` also follows `Game::DuelFinished`. They give recognition or a card back, never a capsule. (CAP-17; `achievements.md`, Duel achievements; AD-37, AD-57; EXPERIENCE.md, Achievement titles and conditions)
- R7 — Abuse of Dominant Position (50 wins) unlocks the "Duelliste" card back: a blue-steel frame on a dark field, the crossed blades of the duel emblem over two cards facing each other, "DUEL", drawn through the pixel art script and added to AD-25's back constant, with its unlock condition in the back picker. (CAP-20; `achievements.md`; AD-25, AD-37; DESIGN.md, Card backs; EXPERIENCE.md, Card backs; Écrans des Duels board 10)
- R8 — Release 1.4.0 ships epics 42 to 44 together: the author exercises the whole release with two accounts on staging, then cuts and promotes the candidate per RELEASING.md; production computes the first duel stats as a deploy data step. (Spec Constraints, Launch scope; Success signal; RELEASING.md)

## Done when

1. On staging, the first win of a UTC day with no automatic move of the winner puts a duel capsule in the special reserve, which opens in its own canister and counts in the Flukeometer; a second win that day and a win with an automatic move of the winner give none, and the result says why.
2. The profile shows the player's wins, losses and draws, and the Duels screen their record and last ten results, each opening its result.
3. The ten duel achievements unlock from real duels, each once, and 50 wins unlock the Duelliste back.
4. Release 1.4.0 runs in production: the duel stats were computed at deploy, two accounts have played a duel there, and the release is tagged.

## Boundaries

What duels give and record, and the release. No change to the duel's rules, clock or screens beyond the result's capsule line and DERNIERS DUELS (epic 43); no ranked duel, rating or ranking (CAP-43, later); no stake in cards or PiCoins.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-42, CAP-17, CAP-20, Constraints, Assumptions, Success signal
- spec — _bmad-output/initiative-gameble/spec-gameble/duel-rules.md, Reward and record
- spec — _bmad-output/initiative-gameble/spec-gameble/achievements.md, Duel achievements (release 1.4)
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-57, AD-54 Costs, and the 1.4 amendments to AD-7 (pack kinds) and AD-37 (`GrantAchievementsJob` follows `DuelFinished`); AD-25
- experience — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Duels (Duels screen, Duel result, Duel record), Public pages (Public profile), Achievement titles and conditions (24 to 33), Card backs, State Patterns (Special capsule in the reserve), Flow 11, Copy deck (Special capsules, Duel result and record, Public profile)
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Colors (capsule origins), Special capsules (origins, Duel pixel grids), Card backs (Duelliste), Duels (Duel result, Duel record, Desktop)
- mockups — Écrans des Duels, https://claude.ai/artifact/UgaV5njDmpmnuDcWAV4tuh, boards 7 (result), 10 (emblem, canister, Duelliste back), 11 (desktop Duels screen)
- release — RELEASING.md

## Notes

- Decision (2026-11-14, author): release 1.4.0 is epics 42 to 44, shipped to production together at the end of this epic; entry 5 is that release.
- Waits on epic 43 because: the capsule is drawn in the finishing move and refused after an automatic move (43.5's result screen, 43.6's marked automatic moves, and 43.8, which also changes the finishing move for a deleted seat); the record, the history and the achievements read finished duels, their seats and rounds and follow `Game::DuelFinished` (43.2); DERNIERS DUELS joins the desktop left column of 43.9.
- Decision (2026-11-14): entry 1, the capsule, opens the epic as its tracer: a duel's last move through the pack, the reserve, the Flukeometer and the result.
- Decision (2026-11-14): sequencing. Entries 2 and 3 run side by side after entry 1, entry 2 because it shares the result screen with it, entry 3 because it shares `script/pixel_art/export.mjs`; entry 4 is the sweep; entry 5 is the release, after it.
- Decision (2026-11-14): the refactor sweep is added before the release entry, since the epic has more than three entries.
- Decision (2026-11-14): the existing deploy step `game:backfill_achievements` keeps running; with no duel before 1.4 in production it grants no duel achievement there, as AD-57 expects. On staging it grants retroactively, without a toast, those already earned in duels played before entry 3 lands.
- Assumption: the duel capsule's origin name and colour are the locale key and the token of DESIGN.md; `--color-capsule-duel` already exists from entry 42.1.
- High-risk checks: entry 1's migrations (kind and size checks, `duel_day` and its unique index, the Fortune column) by CI's schema drift job and the staging deploy, and the once-a-day grant by the author on staging (Done when 1); entry 5 is the author's.
