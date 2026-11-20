---
title: "Sprint Change Proposal: duels ship to everyone as an alpha that tests the rules"
date: 2026-11-20
status: approved
approved: 2026-11-20
scope: moderate
trigger: ../forge-duels-alpha-placement/forge-duels-alpha-placement.md (hardened with the author, 2026-11-20)
---

# Duels ship to everyone as an alpha that tests the rules

## 1. Issue summary

Release 1.4's duels are built (epics 42 to 44, every ticket `built`, state `review`) and already run in production behind a global switch, `Game::FeatureFlag` key `duels`, which an administrator turns on or off for every player from the back-office. The switch gates 15 places (6 controllers, 9 views and helpers), forks the tab bar between two layouts (`ShellHelper#shell_tabs`: ÉCHANGES + DUELS, or TRADES + MARKET), and the native apps already ignore it: on 2026-11-19 they were hard-coded to TRADES + MARKET with no DUELS tab. It gives no gradual rollout, only all or nobody, and doubles the navigation to test.

The author chose (forge, 2026-11-20) to ship duels to every player as an **alpha** whose purpose is to learn whether the designed duel is fun and whether players enjoy building varied decks, not to drive retention. If one deck dominates, as the 2026-11-14 simulation predicts for the coverage deck (82 to 90 % against every other recipe), the rules change. That purpose removes the rewards, keeps and strengthens the practice duel, adds measurement, and reopens the navigation decided on 2026-11-14.

Evidence:
- The switch: `app/domains/game/app/models/game/feature_flag.rb`, `app/controllers/concerns/feature_gate.rb`, `app/helpers/application_helper.rb:5`, commit `9adfffac`; no architecture decision records it.
- Built outside the plans and absent from spec and UX: the practice duel against a bot (`b95c6eff`, `Game::PracticeBot`, 30-minute clock, plays the automatic move half the time and a random one otherwise), the ALPHA banner, forfeit and duel feedback (`fffe0ead`). `later-roadmap.md` still lists "a solo practice duel" as later.
- The spec's 1.4 success criterion measures retention ("at least 10 players… half of them duel again in a later week").
- Production, 2026-11-19 (`forge-market-volume`): about 50 market sales a week against about 1,100 cards moved by friend trades; many players reach friend trades from their goals through the trade suggestions.
- The hub's numbered menu is hidden under the phone breakpoint (`app/frontend/styles/hub-responsive.css`), so on a phone a screen without a tab has no entry.

## 2. Impact analysis

### Epic impact

| Epic | Impact |
|---|---|
| 42 · duel-stats-and-decks | Stands. Its story "The DUELS tab, the Duels screen with the player's decks, and ÉCHANGES with its two sub-tabs" is superseded in part: MARCHÉ becomes the first sub-tab and the default. Its retro's pre-release items move to the new release ticket. |
| 43 · live-friend-duels | Stands unchanged. Its retro's pre-release items (staging play, secrecy broadcast test, nil-rating test, F3) move to the new release ticket. |
| 44 · duel-capsule-record-and-achievements | Rescoped. "The first real win of the day gives a duel capsule" and "Ten duel achievements and the Duelliste card back" are withheld for the alpha: their grants and displays leave the code paths, their data model stays. "The profile and the Duels screen show the player's record" is modified: the record leaves the public profile. "The author ships release 1.4.0 to production" is cancelled here and replaced in the new epic. |
| New · duels-alpha | Six stories and a release ticket (Section 5). |
| Market volume (CAP-45 to CAP-49, not yet sliced) | No conflict. CAP-49 already sets 3 free decks; the Duels screen's "MES DECKS · n / 5" follows it there. |

### Artifact conflicts

- **Spec:** CAP-42 (capsule), the 1.4 success criterion, the constraint "the duel capsule is their only material reward", CAP-16's special-reserve list, CAP-20's duel achievements, the CAP-42 assumption on the capsule's day, `achievements.md` (duel achievements), `later-roadmap.md` (practice listed as later; no entry for withheld rewards). No CAP covers the practice duel or the measurement.
- **Architecture:** AD-54 has no practice duel, bot seat or rules version; AD-57 grants the capsule and reads the record for the public profile; no rule says how unfinished features ship; the CAP-42 row of the mapping table.
- **UX:** Phone and Desktop navigation, the Échanges row, the Duels screen, Duel result, Public profile, the special capsules rows, the achievement rows 24 to 33 and the Duelliste back, the copy deck rows for Duels; nothing for the practice duel, the ALPHA banner or the feedback form. DESIGN.md: the duel capsule's canister and colour and the Duelliste back are withheld; the ALPHA tag has no entry.

### Technical impact

- Remove `Game::FeatureFlag`, `Game::SetFeatureFlag`, `Game::FeatureFlagSet`, `Game::EnabledFeatures`, `FeatureGate`, `feature_enabled?`, the back-office Features screen and every branch on them; the tab bar has one layout. `game_feature_flags` is dropped in the following release (expand/contract: code stops reading it first).
- Tests to rewrite or delete: `test/integration/duels_switch_test.rb`, `test/domains/game/set_feature_flag_test.rb`, `test/controllers/back_office/features_controller_test.rb`, and the flag set-up in `achievement_board_test.rb` and `card_back_shelf_test.rb`; `hotwire_native_test.rb` and `top_bars_controller_test.rb` follow the native tabs.
- Rewards withheld on production data: the `duel` pack kind, `game_fortunes.duel_packs` and the duel achievement keys stay in the schema, so any row staff testing created stays valid; only the grant and the displays go.
- New columns (expand/contract, strong_migrations): `game_duels.rules_version`; `game_duels.bot_archetype` for practice duels.
- Backfill of `game_player_states.exchanges_tab` through an operation run by a job, not a data migration that writes models.
- Native: the DUELS tab returns on iOS and Android (parts of `30e6f4a0` and `6661f3b7` reversed); the native tab code has never been compiled (epic 42 retro, F4).

## 3. Recommended approach

**Hybrid: direct adjustment plus a partial rollback.** A new epic carries the alpha; epic 44's rewards are withheld rather than deleted; epics 42 and 43 close once the release passes.

- Direct adjustment, because nearly everything the alpha needs exists: the duel, decks, the practice duel, the ALPHA banner, feedback, and the duel tables already store both decks, the result, the margins and every round.
- Partial rollback, because the rewards are built and in production behind the switch; disabling their grant and display costs less and risks less than deleting tables and achievement keys, and keeps them for the beta if the author wants them back.
- Not an MVP review: the public launch is behind us; this reshapes release 1.4 only.

Effort: medium (six stories, one of them the skilled bot). Risk: low to medium; the bot is the one new algorithm, the rest removes branches. Timeline: release 1.4 waits for the new epic instead of the old release ticket.

## 4. Detailed change proposals

### 4.1 Spec (`spec-gameble/`)

**CAP-42**

OLD:
- **intent:** Winning a duel gives a reason to come back without turning duels into a capsule farm.
- **success:** The first win of the UTC day gives a duel capsule of 3 cards at the daily bonus odds (CAP-16), in the special reserve, only if the game played none of the winner's moves; a second the same day is refused, whatever the client does. Other wins, losses and draws give nothing material. The profile shows the player's wins, losses and draws.

NEW:
- **intent:** A player sees how they fare at duels while the rules are tested, with nothing to farm.
- **success:**
  - During the alpha a duel gives nothing material: no capsule, no achievement, no card back.
  - The player's own Duels screen shows their wins, losses and draws against players, counting only duels played under the rules in force; practice duels never count.
  - The public profile shows no duel record during the alpha.

Rationale: a public record and a reward push players to the dominant deck the alpha is meant to detect, and records under two rules versions do not compare.

**New CAP-50, practice duel**

- **intent:** A player tries a deck and a strategy alone, at any time, against a bot that is worth beating.
- **success:**
  - From Duels, a player with a complete deck starts a practice duel against the bot, under the same rules as a live duel, with 30 minutes per move; it counts for nothing.
  - The bot reads both open decks and the shown card and plays for the margin, as a skilled player does.
  - Each practice duel deals the bot a named archetype deck, which changes from one practice duel to the next; the screen names it ("Le bot joue un deck Popularité").

**New CAP-51, alpha measurement**

- **intent:** The author learns from the alpha whether the duel is fun and which decks hold, to change the rules.
- **success:**
  - Duels carry an ALPHA tag in the tab bar and the menu, and an ALPHA banner on the Duels screen and the duel screen says games are analysed to balance the rules; the Duels screen and every duel result offer "Envoyer un feedback".
  - Each duel records the rules version it was played under, and a practice duel the bot's archetype.
  - A back-office page reads, per rules version and with live duels apart from practice duels: duels finished, win rate of the first caller, share of duels decided on the margin, share of automatic moves, win rate by deck recipe and, for practice, by the bot's archetype, and the stats called.

**Success criteria, release 1.4**

OLD: For live duels (release 1.4): 30 days after release 1.4, at least 10 players have finished a live duel with no automatic move of theirs, and at least half of them duel again in a later week (author, 2026-11-14).

NEW: For the duels alpha (release 1.4): the author reads the back-office page of CAP-51 and the duel feedback; if one deck recipe dominates live duels or practice, the rules change and the rules version is raised. No threshold is set; the author decides on the reading (author, 2026-11-20).

**Other spec lines**

- Constraints, "Duels move nothing between players": replace "the duel capsule (CAP-42) is their only material reward" with "during the alpha they give no material reward (CAP-42)".
- CAP-16: drop "and the duel capsule of CAP-42" from the special reserve's list.
- CAP-20: drop "and duels (CAP-41)" from what achievements read; `achievements.md`, "Duel achievements (release 1.4)": add "Withheld during the duels alpha (author, 2026-11-20); built, not granted or listed."
- Assumptions: remove "The day of the first-win duel capsule is the UTC day the duel ends".
- Non-goals: "Release 1.4 has no ranked or deferred duel" stays; add "deferred duels come with the duels beta".
- `later-roadmap.md`: remove "a solo practice duel" from Duel extras (now CAP-50); add "**Duel rewards** (built, withheld during the alpha): the first-win duel capsule, the ten duel achievements and the Duelliste back; they return with the duels beta (author, 2026-11-20)." Ranked and deferred duels: "after the alpha", deferred duels first with the beta.

### 4.2 Architecture (`architecture-gameble.md`)

**Consistency Conventions, new row**

NEW: | Unfinished features | A feature ships to every player, labelled (ALPHA) while it is tested; there is no runtime feature switch. A release that must not show a feature does not merge it. |

Rationale: the switch forked 15 places and the tab bar, and the native apps could not follow it.

**AD-54, additions**

NEW (appended to Rule):
- A practice duel is a duel with `practice` true against the player's bot (`Game::PracticeBot`, an `Accounts` player per human, private), started by `StartPracticeDuel` with no challenge; its move clock is 30 minutes. The bot's moves are computed by a pure object from `DuelRules` and `DuelView.for` the bot's seat, never from the human's hand, call or draw order; it plays for the margin. Its deck is one named archetype from a fixed list, built from the catalog at the duel's start, and the archetype is stored on the duel (`bot_archetype`).
- `game_duels.rules_version` holds the version of `DuelRules` a duel was played under, a constant raised with any rule change; every read that compares duels (record, back-office) filters or groups by it.

**AD-57**

OLD: The duel capsule is a pack of kind `duel` (AD-7)… The finishing move draws it for the winner… Wins, losses, draws, the history and the duel achievements (AD-37 metrics) read finished duels… `GrantAchievementsJob` also follows `Game::DuelFinished`.

NEW:
- During the alpha the finishing move grants nothing, and `GrantAchievementsJob` does not follow `Game::DuelFinished`; the `duel` pack kind, `duel_packs` and the duel achievement keys stay in the schema, unused.
- The record and the history read finished non-practice duels at the current `rules_version`, shown on the player's own Duels screen only.
- The back-office duel page (CAP-51) reads the duel tables directly, per `rules_version`, live and practice apart; at the alpha's volume no stored figures are needed.
- The export still lists the player's decks and duels.

**Mapping table:** CAP-42 row becomes "Duel record (alpha) | `Game` (duels) | AD-54, AD-57"; add CAP-50 "Practice duel | `Game` (duels) | AD-54, AD-56" and CAP-51 "Alpha measurement | `Game` (duels), back-office | AD-54, AD-57".

### 4.3 UX (`ux-gameble/EXPERIENCE.md`, `DESIGN.md`)

**Phone navigation**

OLD: A bottom tab bar of five tabs (author, 2026-11-14, mockup A…): PONT · CAPSULE · SETS · ÉCHANGES · DUELS. ÉCHANGES holds the market as its MARCHÉ sub-tab…

NEW: … PONT · CAPSULE · SETS · ÉCHANGES · DUELS; DUELS carries the ALPHA tag while duels are in alpha (author, 2026-11-20). ÉCHANGES holds the market as its first sub-tab, MARCHÉ, then ENTRE AMIS… The native apps show the same five tabs.

**Desktop navigation:** menu 04 DUELS carries the ALPHA tag; menu 03's sub-tabs read MARCHÉ, ENTRE AMIS.

**Échanges row**

OLD: Two sub-tabs (author, 2026-11-14, mockup A): ENTRE AMIS… and MARCHÉ… it opens on the sub-tab the player last used, kept per player, ENTRE AMIS the first time.

NEW: Two sub-tabs, MARCHÉ first, then ENTRE AMIS (author, 2026-11-20)… it opens on the sub-tab the player last used, kept per player, MARCHÉ the first time; at release 1.4 a player with a friend trade in the previous 30 days starts on ENTRE AMIS, so the goals-to-suggestions flow keeps its place.

**Duels screen:** add, under "DÉFIER UN AMI", the secondary action "S'ENTRAÎNER CONTRE LE BOT" (needs a complete deck; disabled with its reason otherwise); above the screen, the ALPHA banner: tag "ALPHA", "Attention, ce mode est en alpha. Il peut contenir des bugs et des problèmes d'équilibrage. Vos parties sont analysées pour équilibrer les règles.", "ENVOYER UN FEEDBACK". The record line stays; "MES DECKS · n / 5" follows CAP-49.

**New rows:** Practice duel (the duel screen against "Bot", "Le bot joue un deck <archetype>", 30 minutes per move, "Entraînement : ne compte pas" on its result); ALPHA banner; Feedback form (one text field up to 1,000 characters, back to Duels with a toast). Copy for all three in the copy deck, both locales, taken from what is built where it fits.

**Duel result:** drop the capsule lines ("CAPSULE DE DUEL GAGNÉE", "Pas de capsule…", "Capsule de duel déjà gagnée aujourd'hui."); add "ENVOYER UN FEEDBACK".

**Public profile:** drop the "Duels" figures during the alpha.

**Special capsules, Achievement titles 24 to 33, the Duelliste back:** mark "withheld during the duels alpha (author, 2026-11-20)".

**DESIGN.md:** the duel capsule's canister and colour and the Duelliste back marked withheld; add the ALPHA tag (as built: `.alpha-tag`, `.alpha-banner`) and its place on the tab and menu item.

### 4.4 Epics and stories (for `bmad-ticket`)

**Epic 44**
- "The first real win of the day gives a duel capsule": withheld for the alpha (grant removed by duels-alpha story 2).
- "Ten duel achievements and the Duelliste card back": withheld for the alpha (same).
- "The profile and the Duels screen show the player's record and last duels": public-profile figures removed by duels-alpha story 1.
- "The author ships release 1.4.0 to production": cancelled, replaced by the duels-alpha release ticket.

**Epic 42**, story "The DUELS tab, the Duels screen…, and ÉCHANGES with its two sub-tabs": sub-tab order and default superseded by duels-alpha story 3.

**New epic: duels-alpha** (order matters where marked)

1. **Duels are open to every player, labelled ALPHA.** The flag, its back-office screen and every branch it gates leave; the tab bar has one layout; the DUELS tab and menu 04 carry the ALPHA tag; the banner gains "Vos parties sont analysées pour équilibrer les règles."; the record leaves the public profile. Drop `game_feature_flags` in a follow-up release.
2. **Duels give no reward during the alpha.** The finishing move grants no capsule; duel achievements and the Duelliste back are neither granted nor listed; the result panel loses its capsule lines; the schema stays.
3. **ÉCHANGES opens on the market, friend traders keep their place, and the apps get DUELS back.** MARCHÉ first sub-tab and default; a job runs an operation that sets ENTRE AMIS for players with a friend trade in the last 30 days; iOS and Android show PONT · CAPSULE · SETS · ÉCHANGES · DUELS, built and run on both platforms. After 1.
4. **The practice bot plays skilled with a named archetype deck.** A pure object for the bot's call and answer (reads the open decks and the shown card, plays for the margin; the 2026-11-14 simulation's skilled player is the reference, its scripts must be rewritten); a fixed list of archetypes (coverage, single stat for each stat, two stats, trump sort, random) built from the catalog; the archetype stored on the duel and named on screen; a test that the skilled bot beats the automatic move clearly over many seeded duels.
5. **Each duel keeps its rules version, and the record counts the rules in force.** `rules_version` on `game_duels`, set at the start; the record filters on the current version.
6. **A back-office page shows how duels play.** The CAP-51 figures per rules version, live and practice apart; practice duels feed only their own table, by archetype, never the deck-recipe win rates. After 4 and 5.
7. **The author ships the duels alpha in release 1.4.0 (HITL).** On staging, with two accounts on a phone and a desktop: everything epics 42 and 43 list, minus the capsule and achievements; the ALPHA tag and banner; a practice duel against two archetypes; the back-office page; ÉCHANGES opening on MARCHÉ for a new account and on ENTRE AMIS for a friend trader. Before it: the retros' items (live staging play with refused, cancelled, lapsed, timeout, reload, drop, ban and deletion; the broadcast-level secrecy test; the nil-rating case; F3 confirmed); both native apps compiled and run with DUELS. Then promote, check the duel stats computed at deploy, publish v1.4.0. After 1 to 6.

## 5. Implementation handoff

**Scope: moderate.** The plan is reorganized (one epic rescoped, one added) but not replanned.

- **Author:** approve this proposal; apply the spec, architecture and UX edits of Section 4 (or have them applied); run the HITL release ticket.
- **`bmad-ticket`:** apply Section 4.4: withhold and modify epic 44's entries, cancel its release ticket, note epic 42's superseded part, create the duels-alpha epic with its seven entries and their order.
- **`bmad-build`:** one build per story, 1 to 6.

**Success criteria:** no `feature_enabled?` or `FeatureFlag` left in the code; one tab bar on web and native; no duel grants a capsule or an achievement; a new player's ÉCHANGES opens on MARCHÉ and a recent friend trader's on ENTRE AMIS; the bot beats the automatic move clearly and names its archetype; the back-office page reads per rules version; release 1.4.0 published with duels for everyone.

## Author decisions (2026-11-20)

- The withheld rewards (duel capsule, ten duel achievements, Duelliste back) return with the duels beta; the schema stays until then, no contract migration.
- The bot's archetypes: coverage, single stat (one per stat), two stats, trump sort, random.
- Practice duels never count in the deck-recipe win rates; the back-office page gives them their own table, by the bot's archetype.
