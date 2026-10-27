# Inception proposal: epic-card-backs (epic 9)

Draft only. No `tickets.toml` edited, no sync, no commit. Nothing here is built; every path and count below was read from the repo on 2026-10-27.

## 1. The epic as it stands

- File: `epic-card-backs/epic-card-backs.md` (the folder holds only this file: no `tickets.toml`, no plans). Title "Cosmetics: card backs, titles and menu themes", `covers: [CAP-20, CAP-22]`, risk low, no release in the initiative `tickets.toml` (entry at line 129, id 9).
- Promise: players earn card backs (set back tier, a successful weekly goal, some achievements, events or seasons), pick one active back for their face-down cards, earn profile titles from tiers and completions, and rare menu themes from 3, 10 and 25 complete sets.
- Done when has six checks: (1) Standard for everyone, locked backs state their condition; (2) unlocks once each, a later season adds a mark, not a second unlock; (3) picker in the profile, applies from the next pack, "faded on the detail of a card they do not own", the player picks the season mark; (4) an administrator grants a back to a group; (5) titles; (6) menu themes with contrast checked.
- `after` in the initiative: epic 12 (public release), 13 (tier and completion events, tier table 13.22), 6 (set-completed, goal reward, achievement events), 8 (booster shows the active back), 10 (profile and settings screen), 21 (booster in Stimulus, 21.3, "frozen until then").
- Epic 17 (`epic-seasons-carry-over`, release 0.5.0) waits on this epic: its entry 2 (recap screen) has `after = [1, "13.7", "epic-card-backs"]`; its entry 1 verify says "a gold first reached at the receipt unlocks its set's card back" but its `after` does not name this epic.
- Epic 19 (`epic-special-packs`, 0.5.0): its Notes say epic 9 "touches the same island and the pixel art export; its inception orders against entries 3 to 5" (19.3 switch, 19.4 origin looks, 19.5 intro).
- Source conflict (to record in the epic's Notes at approval): Done when 3 and CAP-20 / AD-25 say the back shows "faded on the detail of a card they do not own"; `ux-gameble/EXPERIENCE.md` line 485-486 (Card backs, "What it is") says "the card detail no longer shows it for a card not owned; author, 2026-10-20". The newer decision wins; see question 3.
- Open before this inception: spec Open Questions line 266 ("which goal, achievement and event backs ship, and does every successful weekly goal grant one?"); architecture line 547 repeats it.
- Related deferred entry: `deferred-work.md`, "Deferred from: the retrospective of epic-brotherhood (2026-10-21)": the pack-bearing event is `Game::GoalRewardClaimed`; `claim_goal_reward.rb` shows the reward is earned first (a `game_goal_rewards` row, `GoalRewardGranted`), claimed later by a button. A back is not pack-bearing, so it should follow the earned event, not the claim (question 5).

## 2. What exists in the code for backs

| What | Path | State |
|---|---|---|
| Back catalogue | `app/domains/game/app/models/game/card_backs.rb` | `STANDARD = "standard"`, `KEYS = [STANDARD]`, `active_key(_player)` always returns standard. No unlock rule, no per-set backs. |
| Back stored on the opened pack | `db/schema.rb` `game_packs.card_back` (string, line 393); `app/domains/game/app/operations/game/open_pack.rb:28` (`card_back: CardBacks.active_key(player)`); `app/domains/game/app/models/game/pack.rb:29` (`card_back_key`, falls back to standard) | Works; no season-mark column. |
| Back on the booster | `app/views/boosters/_opened.html.erb:2` (`data-card-back`); `app/frontend/controllers/booster_stage_controller.ts:231`; `app/frontend/lib/booster_motion.ts:173-176` (`CARD_BACKS = ["standard"]`, `cardBackClass`, unknown key falls back to standard); `app/frontend/lib/booster_motion.test.ts:146-150`; `app/frontend/lib/booster_render.ts:173` | Only Standard is wired. CSS only has `.booster-card__back--standard` in `app/frontend/styles/booster-canister.css:324` and `booster-layouts.css:60,225` (sizes m, s, xl). The booster is a React island with Stimulus controllers; bug fixes only until 21.3. |
| Opening response and export | `app/models/player_export.rb:84` and `app/domains/game/app/queries/game/export_of.rb:5-67` export each pack's `card_back` | No unlock list in the opening response yet (AD-23 wants one). |
| Pixel art | `app/frontend/images/pixel/back-<name>-<xs|s|m|l|xl>.png`: 8 backs (standard, saison-1, semaine-38, etoile-dor, aurore, millesime-2017, centurion, soldes-hiver) x 5 sizes = 40 files, among 104 files in the folder. Drawn by `script/pixel_art/export.mjs` (`BACK_DESIGNS` line 1141, `CARD_SIZES` line 1150, `backCanvas` line 745, 5 x 7 letter font line 686); `node script/pixel_art/export.mjs --check` verifies; `test/lib/pixel_art_export_test.rb` | Only these 8 exist. DESIGN.md Card backs: they are the prototype's set, "the other backs that ship are open". |
| Landing promise | `app/views/landings/_unlock.html.erb:69-85` shows standard, aurore, etoile-dor, centurion with a `landings.show.unlock.soon` tag | Marketing tile already exists; the "soon" tag goes when backs ship. |
| Settings screen | `app/views/settings/show.html.erb`, `_profile_summary.html.erb`; route `resource :settings` (`config/routes.rb:87`); `test/system/settings_test.rb` | Rows: language, visibility, motion, session, data export, account, support, legal. No back picker, no title or theme row. |
| Player state | `db/schema.rb` `game_player_states` (columns: player_id, collection_seen_up_to, last_activity, last_activity_at); `app/domains/game/app/models/game/player_state.rb` | No active back, title or theme column. |
| Set tiers | `db/schema.rb` `game_set_tiers` (player_id, set_id, tier, reached_by `pack|trade`, pack_id, held; unique on player/set/tier; tiers novice..master, complete, legacy bronze/silver/gold); `catalog_sets` has `season_id`, `kind` (theme, franchise, studio, hall_of_fame, ufo), `key`; `app/domains/catalog/app/models/catalog/tier_table.rb` (the size table: the first tier at or above half the cards is adept from 200 cards, expert from 20 to 199, master from 5 to 19, completion below 5) | A set row is per season, so the seasons a back was earned in can be read by joining a tier row to `catalog_sets.season_id` (AD-25). |
| Events to consume | `app/domains/game/app/events/game/`: `SetTierReached`, `SetCompleted`, `AchievementUnlocked`, `GoalRewardGranted`, `GoalRewardClaimed`, `PackOpened`, `TradeAccepted`; subscriptions in `config/initializers/event_store.rb:11-33`; handlers in `app/domains/game/app/handlers/game/handlers/` (`achievements.rb`, `set_tier_feed.rb`, ...) | No back handler. |
| Achievements | `app/domains/game/app/models/game/achievements.rb`: 10 (first_booster, first_epic, first_legendary, first_complete_set, first_trade, boosters_10, boosters_100, boosters_500, three_complete_sets, first_repost); table `game_achievement_unlocks`; SUCCÈS screen in `app/views/achievements/` | None carries a back. |
| Titles, menu themes | none (grep of `app`, `config`, `db/schema.rb`) | Not started. |
| Admin grant | none; `app/domains/game/lib/tasks` exists for rake tasks | AD-25 wants one console operation. |

Counts that size the art: the sets spike (`epic-recognizable-sets/spike-sets-on-real-data-report.md`, lines 83 and 164) fixes 42 themes and 4 hall of fame sets, so 46 set backs plus Standard, and the 7 other prototype backs (see question 1). I did not verify where the theme list lives in code; the catalogue test (story 2) must fail when a theme or hall of fame set has no back.

## 3. Proposed stories, in build order

Tracer bullet: story 1 (catalogue, unlock rows, active back, one unlock end to end through a Standard-plus-one back), because every other story reads the unlock rows. Least certain: story 5 (the booster is frozen until 21.3 and the opening response changes) and the art in story 3.

Unlock conditions per back (catalogue constant in `Game`, AD-25; subject to question 1):

| Back | Unlock rule | Event |
|---|---|---|
| Standard | every account, no row | none |
| One per theme and hall of fame set (46) | that set's back tier: first tier whose required count is at least half its cards (`Catalog::TierTable`); `gold` for sets of seasons published before the table; once per player and set kind+key across seasons; each season it was earned in gives a mark | `Game::SetTierReached`, and the receipt of 17.1 (`SeasonAllocationReceived`) |
| Goal back | the first time the player contributes to a successful weekly goal | `GoalRewardGranted` |
| Achievement backs (proposal) | Centurion: `boosters_100`; Étoile d'or: `first_legendary`; Aurore: `three_complete_sets`; shown on the achievement's tile | `AchievementUnlocked` |
| Event backs (proposal) | Saison 1, Millésime 2017, Soldes d'hiver: granted by the administrator operation to a group | console operation |

Paste-ready drafts (ids are new; epic has no entries yet):

```toml
[[entry]]
id = 1
type = "story"
title = "The back catalogue, unlock rows and the active back"
description = "Adds game_card_back_unlocks (player, back key, unlocked_at, unique per player and key), active_card_back and active_card_back_season columns on game_player_states (nullable, expand only), the Game::CardBacks catalogue as one constant of key, asset and unlock rule (Standard needs no row), Game::UnlockCardBack as the single idempotent writer, and CardBacks.active_key reading the player's choice with a fall back to Standard when the back is not unlocked."
verify = "Operation tests show an unlock written once however many times it is asked, Standard active for a new account and for an account whose active back is not unlocked, the opening storing the active back on the pack, and the schema regenerated from the migrations."
covers = ["CAP-20"]
after = ["epic-human-readable-codebase", "13.22", "21.3"]
hitl = false
risk = "medium"

[[entry]]
id = 2
type = "story"
title = "A set's back unlocks on its back tier"
description = "A Game handler on SetTierReached (and on the 17.1 receipt) unlocks the back of a theme or hall of fame set when the tier reached is that set's back tier (its first tier at or above half its cards, gold in seasons published before the table), once per set kind and key across seasons, inside the publishing transaction and without publishing; franchise, studio and UFO sets grant nothing; a catalogue test fails when a theme or hall of fame set has no back."
verify = "Tests cover each size row of the tier table, a legacy gold, a trade that crosses the tier, the same set in a later season (no second unlock), and a franchise set (no back); packwerk and zeitwerk pass."
covers = ["CAP-20"]
after = [1]
hitl = false
risk = "medium"

[[entry]]
id = 3
type = "story"
title = "The set backs drawn and exported"
description = "Extends script/pixel_art/export.mjs with one shared set-back anatomy (frame, field, brackets, motif, 5 x 7 word) parameterised by a palette, a motif and a word per set, and exports the 46 backs of the 42 themes and 4 hall of fame sets in the five sizes, then registers each in the catalogue; the author supplies or approves the per-set word, palette and motif list first."
unknown = "Whether the author wants one drawn back per set or the shared anatomy with per-set variants (question 2); whether the 5 x 7 font covers every letter of every set word."
verify = "node script/pixel_art/export.mjs --check passes, 46 x 5 = 230 new PNGs exist beside the existing 40, and the catalogue test of story 2 passes."
covers = ["CAP-20"]
after = [1]
hitl = true
risk = "medium"

[[entry]]
id = 4
type = "story"
title = "The back picker on the settings screen"
description = "Adds Game::ChooseCardBack (POST, Pundit policy, Failure(:back_locked)), a Game::CardBackShelf query listing every back with its state and unlock condition, and a DOS DE CARTE section on app/views/settings/show.html.erb with a preview, the active mark, locked backs grayed under a padlock stating their condition, and the DOS ÉQUIPÉ and DOS VERROUILLÉ feedback; every back name and condition in en.yml and fr.yml, the errors.game.back_locked key in both."
unknown = "The picker's layout is not drawn in DESIGN.md (only copy in EXPERIENCE.md lines 122 and 408 and Flow 3); a short bmad-ux pass with the author, or the author accepts a grid of thumbnails with the preview above."
verify = "A system test equips an unlocked back and sees the preview and toast, a locked back shows its condition and cannot be equipped even by a forged POST, and the choice survives a reload; i18n-tasks and the locale files agree."
covers = ["CAP-20"]
after = [1, 2]
hitl = true
risk = "low"

[[entry]]
id = 5
type = "story"
title = "The active back on the booster and its unlocks announced"
description = "The server renders each opened pack's back as an asset the booster uses (replacing the CARD_BACKS list of booster_motion.ts and the Standard-only CSS), at the three layouts' sizes; the opening's JSON answer lists the backs it unlocked and the booster shows them after the reveal, and a back unlocked by a trade reaches the player through the private stream from a job after commit."
verify = "booster_test.rb opens a pack with the Roguelike back equipped and sees it on all five face-down cards on desktop and phone, an opening that crosses a back tier announces the back once, and Vitest covers the class choice and the unknown-key fallback."
covers = ["CAP-20"]
after = [3, 4, "21.3"]
hitl = false
risk = "high"
unknown = "How the unlock line chains with the celebration banner's order (EXPERIENCE.md, Set celebration)."

[[entry]]
id = 6
type = "story"
title = "A back earned in several seasons wears the season the player picks"
description = "Adds card_back_season to game_packs, reads the seasons a back was earned in from the player's tier rows joined to catalog_sets.season_id, lets the picker choose the mark, and adds the season-mark stamp (DESIGN.md, Season mark) as a component laid over the existing back, never a redrawn one; epic 17's recap reuses the stamp."
verify = "A player with a tier row of the same set in two seasons sees both marks in the picker, the pack stores the picked season, and the booster shows the stamp; a back earned once shows no choice."
covers = ["CAP-20"]
after = [5]
hitl = false
risk = "medium"

[[entry]]
id = 7
type = "story"
title = "Goal, achievement and event backs"
description = "Adds the unlock rules of the goal, achievement and event backs to the catalogue; handlers grant the goal back on GoalRewardGranted and the achievement backs on AchievementUnlocked; the SUCCÈS tile of an achievement that unlocks a back shows it; adds Game::GrantCardBack, one player per transaction, run from the console and a rake task in app/domains/game/lib/tasks, taking a group of players and a back key."
verify = "Tests show each rule granting once, the console operation granting a group with one failure not rolling back the others, and the SUCCÈS tile naming the back."
covers = ["CAP-20"]
after = [1, 4]
hitl = false
risk = "medium"
unknown = "Which achievement and event backs ship (question 1)."

[[entry]]
id = 8
type = "story"
title = "The recap can list a season's backs"
description = "Adds Game::CardBacksEarnedIn(player, season), the backs unlocked or marked in a season, for the allocation screen of 17.2."
verify = "A query test returns the backs a player earned in the ended season and none earned before it."
covers = ["CAP-20", "CAP-23"]
after = [2, 6, 7]
hitl = false
risk = "low"

[[entry]]
id = 9
type = "story"
title = "Refactor sweep"
description = "Cleans up what this epic's build records and deferred review findings name, removes the landing tile's soon tag once backs ship, and updates the spec, architecture and design documents to the epic's decisions (owner-only back, set backs, goal back)."
verify = "The full test suite, packwerk, zeitwerk, vitest and the pixel art check pass."
covers = []
after = [1, 2, 3, 4, 5, 6, 7, 8]
hitl = false
risk = "low"
```

Edits other epics need, left for the author to approve (not made): 17.1 `after` gains `"9.2"`; 17.2 `after` replaces `"epic-card-backs"` with `"9.8"` and its description says the stamp comes from 9.6 (its text still says "owns the season mark stamp entry 3 reuses", and entry 3 was removed on 2026-10-19); 19.3 `after` gains `"9.5"` (both change the booster island and the pixel art export).

Done-when edits for the epic file: replace "and faded on the detail of a card they do not own" in check 3 (question 3); the Requirements section needs R1 to R5 for CAP-20 (the five bullets of the spec) at approval.

## 4. Lanes that can run in parallel

After story 1 (it adds the tables everything reads), three lanes touch disjoint files:

- Lane A, art: story 3 (`script/pixel_art/export.mjs`, `app/frontend/images/pixel/`). Needs the author's briefs; it can start before any code if the catalogue keys are fixed.
- Lane B, unlock rules: stories 2 and 7 (handlers, operations, `CardBacks` constant, SUCCÈS view). They both add to the catalogue constant: expect a trivial merge.
- Lane C, picker: story 4 (`settings/show.html.erb`, a controller and policy, locales). Needs 2 only for real unlock data; can start with 1's stub.
- Serial tail: 5 (booster, after 21.3, and so frozen until then), then 6, then 8, then 9. Do not run 5 beside epic 19's 3 to 5 or epic 17's 1: same operation (`open_pack.rb`) and the same island.

## 5. Questions only the author can answer

1. Which backs beyond the 46 set backs ship, and does every successful weekly goal grant one? Recommend: one goal back (the prototype's Semaine 38, granted the first time a player contributes to a successful goal), three achievement backs (Centurion on `boosters_100`, Étoile d'or on `first_legendary`, Aurore on `three_complete_sets`) and three event backs (Saison 1, Millésime 2017, Soldes d'hiver) granted by the console operation. Consequence: all 8 prototype backs are used and no new art is needed for them; later goals add no back (the pack reward stays); "Semaine 38" lettering becomes a one-off, so say if you want the word changed (that redraws 5 files).
2. Per-set art: 46 distinct hand-designed backs, or one shared anatomy with a palette, motif and word per set? Recommend the shared anatomy, generated in `export.mjs`. Consequence: 46 x 5 = 230 new PNGs from code, not hand-drawn. The author must provide or approve, for each of the 42 themes and 4 hall of fame sets, a word (the 5 x 7 pixel font has only the glyphs the prototype needed, so accents and some letters may be missing), two or three colours and a motif; I can draft the list from the set names for approval. If the author wants distinct drawings, each costs a design pass and the epic grows.
3. The faded back on a card the player does not own: drop it? Recommend yes, following the 2026-10-20 EXPERIENCE decision, so the back shows only on the owner's face-down cards at opening and never on another player's cards or profile. Consequence: Done when 3, CAP-20 and AD-25 (last rule) are amended in story 9; no card-detail work.
4. Should a special pack (daily bonus, goal reward) show the origin look on its cards instead of the active back? Recommend no: the origin look is the canister and the intro (epic 19.4, 19.5), the cards always wear the active back. Consequence: epic 19 changes no back code.
5. Goal back event: grant on the reward being earned (`GoalRewardGranted`) rather than claimed. Recommend earned, since the claim can be refused for a full reserve (`claim_goal_reward.rb`). Consequence: a player with a full reserve still gets the back.
6. Do titles and menu themes (CAP-22, Done when 5 and 6) stay in this epic? Recommend a new epic, `epic-profile-titles-and-themes`, after this one. Consequence: this epic finishes in 9 stories for 0.5.0; the new one is about 4 stories (title derivation from tier rows, the title picker and its display in the feed, profile and trades, the menu theme constant with a contrast check, the theme picker) and CAP-22 stays unbuilt in 0.5.0, which epic 17 does not need.
7. Is 0.5.0 allowed to include work that follows epic 12? Epics 17 and 19 are already 0.5.0 and wait on epic 12, so recommend the same for this epic (after 12 and 21, before 17). Consequence: epic 12's readable-code sweep (which waits on "every feature written") does not cover epic 9, so story 9 carries its own cleanup.

## 6. Release and what stays out

- Release: 0.5.0 for stories 1 to 9, because epic 17 (0.5.0) needs the recap query (9.8), and epic 19 (0.5.0) shares the booster island. Order inside 0.5.0: 21, 12, then 9, then 17 and 19 (19.3 after 9.5).
- The initiative `tickets.toml` entry for id 9 needs `release = "0.5.0"` before sync (not edited here).
- Stays out: profile titles and menu themes (question 6; a new epic, a later release, CAP-22); the events that unlock backs (epics 6 and 13 already publish them); any back shown to another player; per-season redrawn backs (a season is a stamp, DESIGN.md Season mark); the allocation screen itself (epic 17); the origin look and intro of special packs (epic 19); backs for franchise, studio and UFO sets; a purchase or trade of backs.
