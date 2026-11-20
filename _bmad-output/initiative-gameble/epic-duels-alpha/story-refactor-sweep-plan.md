---
title: 'Refactor sweep'
type: 'refactor'
ticket: '7'
created: '2026-11-20'
status: 'built'
baseline_revision: 'e85ef13a55c16a09999d6bcfb8f2731c205922e3'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: []
deferred:
  - summary: >-
      Game::DeckCoverage keeps its own string-typed copy of the ten calls (DIRECTIONS = %w[high low], CALLS) beside Game::DuelStat::CALLS.
    evidence: |-
      deck_coverage.rb:6-7 predates this epic; DeckCoverage.percentile_in compares direction == "high" and Call#direction, the deck editor helper (deck_editor_helper.rb:82) and the coverage keys carry the string, so folding it into the symbol-typed DuelStat::CALLS touches the deck editor and is more than a mechanical swap.
    location: >-
      app/domains/game/app/queries/game/deck_coverage.rb:6
    severity: low
---

<intent-contract>

## Intent

**Problem:** Entries 1 to 6 left code shaped by what they removed or added in parallel: the achievement catalogue still threads an `offered` list through its callers although it no longer depends on a runtime switch, the shell keeps a tab helper split out only for the switch's two branches, the ten duel calls are spelled twice (`DeckArchetypes::CALLS` and the back-office stats table), `DuelBalance` keeps its own copy of the duel roles, and the practice bot's whole-catalog load carries no note of its limit.

**Approach:** Cleanup only, no behaviour change, no schema change: `Game::Achievements::OFFERED_KEYS` and argument-free `offered_keys` / `unearned`, with `AchievementBoard` and `EarnedAchievements` reading them directly; `ShellHelper#shell_tabs` inlines the exchanges and duels tabs; `Game::DuelStat::CALLS` replaces both spellings of the ten calls; `DuelBalance` reads `DuelRules::ROLES`; a `shortcut:` note on `PracticeBot.catalog`. Everything that would change behaviour or add scope goes to the new-story candidates below.

</intent-contract>

## Implementation Notes

Oneshot: about 30 changed lines over 8 files, all mechanical.

Scope came from the six plans' triage logs, rejected findings, assumptions and residual risks, and from `git log 57da342f^..e85ef13a` with its diffs. Checked and found clean (nothing to do):
- No `feature_enabled?`, `FeatureFlag`, `EnabledFeatures`, `FeatureGate`, Features screen or `features_path` left in `app`, `test`, `config`, `lib`, `script`, `docs` or `mobile`; `docs/` never described the switch.
- The deleted partials (`_menu_friend_trades`, `_menu_market`, the four friend-trades and market badges, `duels/_capsule`, `back_office/features/index`) leave no CSS selector, DOM id or stream target behind; `.duel-capsule*` already left `duel-reveal.css`; `.profile-stats__grid` and `--color-capsule-duel` are still read (profile stats, duel profile, duel board, duel-origin capsules already granted).
- `en.yml` and `fr.yml` hold the same keys; every key under the namespaces the epic touched (`shell.tabs`, `pages.home.menu`, `public_profiles.show.stats`, `duels.*`, `back_office.duels`, `back_office.dashboard`, `pages.how_it_works.duels|packs`) is read, statically or through a dynamic key i18n-tasks already ignores.
- No test helper in `test/support/` is unused; no fixture is left without a reader.
- Kept on purpose, per the entries' records: the `canister-small-duel` art, `Game::Pack::DUEL_SIZE`, `Game::DrawOdds::DUEL` (`LuckOdds`, duel packs already granted stay openable), `Game::DuelAchievementMetrics` and the duel achievement keys (the beta), `game_feature_flags` and `game_duels.capsule` (schema).

Files touched:
- `app/domains/game/app/models/game/achievements.rb` -- `OFFERED_KEYS`; `offered_keys` and `unearned(unlocked_keys)` lose the `offered` argument the switch needed.
- `app/domains/game/app/queries/game/achievement_board.rb`, `earned_achievements.rb` -- read `Achievements.offered` / `offered_keys` directly instead of threading a local list.
- `app/helpers/shell_helper.rb` -- `exchanges_and_duels_tabs` inlined into `shell_tabs` (its only caller since the market-tab branch left).
- `app/domains/game/app/models/game/duel_stat.rb` -- `CALLS = STATS.product(DIRECTIONS)`.
- `app/domains/game/app/models/game/deck_archetypes.rb` -- drops its own `CALLS` for `DuelStat::CALLS`.
- `app/views/back_office/duels/_stats_called.html.erb` -- iterates `Game::DuelStat::CALLS`.
- `app/domains/game/app/queries/game/duel_balance.rb` -- `DuelRules::ROLES` instead of its own `ROLES`.
- `app/domains/game/app/models/game/practice_bot.rb` -- `shortcut:` note on `catalog`.

No test changes: no test reads `exchanges_and_duels_tabs`, `DeckArchetypes::CALLS`, `DuelBalance::ROLES` or passes an argument to `offered_keys` / `unearned`.

New-story candidates (behaviour or scope, not done here):
- Pre-select the practice bot's pool in SQL (per archetype, or a sample per stat extreme) instead of loading every ranked `DuelStat` row of every season at each practice start (entry 4 residual risk).
- Refuse `ClaimAchievement` for an achievement outside `Achievements.offered` (a duel achievement unlocked by staff before the alpha can still be claimed by a direct POST; entry 1 rejected finding).
- Back-office duels page: show the empty-state line when every duel of a section was forfeited, and skip loading practice duels' deck snapshots (entry 6 rejected findings).
- Drop `game_feature_flags` in the release after 1.4.0, once no deployed code reads it (epic note, expand/contract).
- Let the practice test tell `StartPracticeDuel`'s `rules_version` write from the column default (entry 5 residual risk); only possible once `VERSION` passes 1 or with a model-level default override.

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[defer]` `DeckCoverage::CALLS` / `DIRECTIONS` is a third, string-typed copy of the ten calls left beside `DuelStat::CALLS` — real, but it predates this epic and its strings feed `percentile_in`, `Call#direction`, the coverage keys and the deck editor helper, so the swap is not mechanical; recorded in `deferred`.
  - `[low]` `[reject]` Implementation Notes count 8 files where the diff touches 9 — the fix is an edit of this build's plan, and the files list beside it is correct.

## Auto Run Result

Status: built

**Summary:** cleanup only, no behaviour or schema change. The achievement catalogue no longer threads an `offered` list through its callers (`Achievements::OFFERED_KEYS`, argument-free `offered_keys` and `unearned`; `AchievementBoard` and `EarnedAchievements` read them directly); `ShellHelper#shell_tabs` inlines the exchanges and duels tabs, split out only for the removed switch; `Game::DuelStat::CALLS` replaces `DeckArchetypes::CALLS` and the back-office stats table's own product; `DuelBalance` reads `DuelRules::ROLES`; `PracticeBot.catalog` carries a `shortcut:` note on its whole-catalog load.

**Files changed:**
- `app/domains/game/app/models/game/achievements.rb` — `OFFERED_KEYS`, no `offered` argument.
- `app/domains/game/app/queries/game/achievement_board.rb`, `earned_achievements.rb` — read the catalogue directly.
- `app/helpers/shell_helper.rb` — `exchanges_and_duels_tabs` inlined.
- `app/domains/game/app/models/game/duel_stat.rb`, `deck_archetypes.rb`, `app/views/back_office/duels/_stats_called.html.erb` — one `CALLS`.
- `app/domains/game/app/queries/game/duel_balance.rb` — `DuelRules::ROLES`.
- `app/domains/game/app/models/game/practice_bot.rb` — `shortcut:` note.

**Review:** 0 patches, 1 deferred (`DeckCoverage`'s string-typed calls), 1 rejected (file count in the notes: an edit of this plan).

**Follow-up review recommended:** false — nothing patched.

**Verification:** no suite or check run, by the coordinator's instruction; `ruby -c` passes on every changed Ruby file; greps find no reader of `exchanges_and_duels_tabs`, `DeckArchetypes::CALLS`, `DuelBalance::ROLES`, nor a caller passing an argument to `offered_keys` / `unearned`.

**Residual risks:** none beyond the unrun suite; the new-story candidates above stay open.

## Verification

Per the coordinator, suites run once in the main tree; this build runs none.

**Commands (coordinator):**
- `bin/rails test test/domains/game/achievement_board_test.rb test/domains/game/earned_achievements_test.rb test/domains/game/card_back_shelf_test.rb test/domains/game/duel_achievements_test.rb test/domains/game/deck_archetypes_test.rb test/domains/game/duel_balance_test.rb test/controllers/back_office/duels_controller_test.rb test/integration/shell_test.rb test/controllers/pages_controller_test.rb` -- expected: green
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/ci` -- expected: green
