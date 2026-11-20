---
tracker_id: ""
key: ""
type: epic
title: "Duels open to every player as an alpha that tests the rules"
parent: initiative-gameble
covers: ["CAP-42", "CAP-50", "CAP-51"]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Duels open to every player as an alpha that tests the rules

## Description

Release 1.4's duels (epics 42 to 44) are built and run in production behind a global switch. This epic removes the switch and ships them to every player as an alpha whose purpose is to learn whether the duel is fun and whether players build varied decks: no rewards, a practice bot worth beating with named archetype decks, the rules version and the bot's archetype stored on each duel, a back-office page that reads them, and the navigation reworked so ÉCHANGES opens on the market while friend traders keep their place. Source: the approved change proposal `change-duels-open-alpha`, folded into spec CAP-42, CAP-50 and CAP-51.

## Outcome

Every player can duel a friend or the bot under an ALPHA label, and the author reads from the back-office alone which deck recipes hold, per rules version; the signal is the spec's success line for the duels alpha.

## Requirements

- R1 (CAP-51) — No runtime feature switch: `Game::FeatureFlag`, `SetFeatureFlag`, `FeatureFlagSet`, `EnabledFeatures`, `FeatureGate`, `feature_enabled?` and the back-office Features screen leave, with every branch they gate; the tab bar and the hub menu have one layout. (architecture, Consistency Conventions, Unfinished features)
- R2 (CAP-51) — The DUELS tab and menu 04 carry the ALPHA tag; the ALPHA banner on the Duels and duel screens adds "Vos parties sont analysées pour équilibrer les règles."; "Envoyer un feedback" stays on Duels and every result. (EXPERIENCE.md, ALPHA banner; DESIGN.md, Duels)
- R3 (CAP-42) — The public profile shows no duel figures; the record stays on the player's own Duels screen. (EXPERIENCE.md, Duel record)
- R4 (CAP-42) — No duel grants a capsule, an achievement or a card back: the finishing move draws no duel pack, `GrantAchievementsJob` does not follow `Game::DuelFinished`, the ten duel achievements and the Duelliste back are neither listed nor granted, the result loses its capsule lines; the `duel` pack kind, `duel_packs`, the `duel_day` index and the achievement keys stay in the schema for the beta. (AD-57)
- R5 — ÉCHANGES: MARCHÉ is the first sub-tab and `Game::ExchangesTab::DEFAULT` is `market`; at release a player with a friend trade in the previous 30 days has `exchanges_tab` set to `friends` through an operation; the iOS and Android apps show PONT · CAPSULE · SETS · ÉCHANGES · DUELS, matching the web. (EXPERIENCE.md, Phone navigation, Échanges)
- R6 (CAP-50) — The practice bot plays skilled: a pure object computes its call and answer from `DuelRules` and its own seat's `DuelView`, reading both open decks, the struck cards and the shown card, and plays for the margin. (duel-rules.md, Practice duel; AD-54)
- R7 (CAP-50) — Each practice duel deals the bot one archetype deck built from the catalog at the start (coverage, single stat for each stat, two stats, trump sort, random), changing from one practice duel to the next; `game_duels.bot_archetype` stores it and the duel screen names it ("Le bot joue un deck <archétype>"). (duel-rules.md, Practice duel; EXPERIENCE.md, Practice duel)
- R8 (CAP-51) — `game_duels.rules_version`, a `DuelRules` constant set at a duel's start; the record and the history count finished non-practice duels at the current version. (AD-54, AD-57)
- R9 (CAP-51) — A back-office page reads the duel tables per rules version: duels finished, first caller's win rate, share decided on the margin, share of automatic moves, stats called, win rate by deck recipe for live duels; practice duels in their own table by archetype, never in the recipe win rates. (AD-57)
- R10 — Release 1.4.0 ships epics 42, 43, 44 (rewards withheld) and this epic; the retros' pre-release items pass first. (spec, Constraints, Launch scope; epic 43 and 42 retrospectives, Action items)

## Done when

1. In production every signed-in player sees DUELS with its ALPHA tag on the web, both native app builds show the DUELS tab, and the code holds no `feature_enabled?` or `FeatureFlag`.
2. A finished duel, live or practice, grants no capsule, achievement or back, and the public profile shows no duel figures.
3. A new player's ÉCHANGES opens on MARCHÉ; a player with a friend trade in the 30 days before release opens on ENTRE AMIS.
4. Over many seeded practice duels the skilled bot beats the automatic move clearly, and each practice duel names the archetype the bot plays.
5. The back-office duel page shows the figures per rules version, live and practice apart, and release v1.4.0 is published.

## Boundaries

Release 1.4's duels and the ÉCHANGES sub-tab order only. Not deferred or ranked duels (beta and later), not the duel rewards' return (beta), not the deck slots bought with PiCoins (CAP-49, market volume), not a change to the duel rules themselves.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-42, CAP-50, CAP-51, Constraints, Success signal
- spec — _bmad-output/initiative-gameble/spec-gameble/duel-rules.md, Reward and record (alpha), Practice duel
- change — _bmad-output/initiative-gameble/change-duels-open-alpha/change-duels-open-alpha.md
- forge — _bmad-output/initiative-gameble/forge-duels-alpha-placement/forge-duels-alpha-placement.md
- simulation — _bmad-output/initiative-gameble/forge-decks-and-matches/simulation-2026-11-14.md, Model (the skilled player)
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-54, AD-56, AD-57, Consistency Conventions
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Phone navigation, Desktop navigation, Échanges, Duels; DESIGN.md, Duels
- retrospective — _bmad-output/initiative-gameble/epic-live-friend-duels/epic-live-friend-duels-retrospective.md, Action items
- retrospective — _bmad-output/initiative-gameble/epic-duel-stats-and-decks/epic-duel-stats-and-decks-retrospective.md, Action items

## Notes

- Decision: the author asked on 2026-11-20 to chain the work without stopping; the breakdown was drafted autonomously and validated by an independent check.
- Decision: entry 1 is the tracer bullet: removing the switch touches the shell, every duel screen, the profile and the back-office at once (2026-11-20).
- Decision: entries run in one lane, 1 to 6 each after the previous, because they share the duel views, the locale files, `game_duels` and `db/schema.rb` (2026-11-20, after the independent check).
- Deferred: drop `game_feature_flags` in the release after 1.4.0, once no deployed code reads it (strong_migrations, expand/contract).
- Assumption: the skilled bot follows the simulation's model description; its scripts were not kept, so entry 4 rewrites the strategy from the report.
- Assumption: the ALPHA tag keeps the built gold until the author picks another colour (DESIGN.md, Duels).
- Waits on epic 44 because: entries 1 and 2 change the record, the result and the rewards it built.
- Assumption: the ÉCHANGES backfill is a rake task the author runs once in production in entry 8, not a deploy step, since `bin/docker-entrypoint` runs on every boot.
- Assumption: duels already in production (staff tests behind the switch) read as rules version 1 through the column's default.
- Assumption: submitting the native apps to the stores is the author's choice of timing; Done when 1 asks for the builds, not the store release.
- Assumption: of the retros' pre-release items, epic 42 F1 and epic 43 F14 (A6) were accepted by the author on 2026-11-17, epic 43 F2 and F4 have landed (`1cb9ab01`, `40b8b8ab`), and epic 44's red `error_pages_test` is outside this release; entry 8 carries the rest.
- Decision: `Game::Achievements.offered` keeps its switched-off side for good, so the duel achievements leave the catalog with the switch in entry 1 and entry 2 removes only the capsule, the job subscription, the Duelliste back and the result lines (independent check, 2026-11-20).
