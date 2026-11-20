---
title: 'Duels are open to every player, labelled ALPHA, with no switch'
type: 'feature'
ticket: '1'
created: '2026-11-20'
status: 'built'
baseline_revision: 'a78e7c11f4d5844bdf45f34129b521c7ae0b2f42'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: true
context: ['{project-root}/AGENTS.md', '{project-root}/docs/design-system.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Duels run in production behind a global runtime switch (`Game::FeatureFlag` and its back-office screen); release 1.4 ships them to every player as an alpha, so the switch, its gated "off" branches and its screen must go, the duels must carry an ALPHA label, and the public profile must stop showing duel figures.

**Approach:** Delete the switch end to end and keep every gated branch's duels side, except `Game::Achievements.offered`, which keeps its switched-off side for good (catalogue without the duel achievements). Add the ALPHA tag to the DUELS tab and menu 04, extend the alpha banner's sentence, and drop the three duel figures from `public_profiles/_stats` and `Game::ProfileActivity`.

## Boundaries & Constraints

**Always:** every string in `en.yml` and `fr.yml`; no `style` attribute; the `game_feature_flags` table stays in `db/schema.rb`, unread; the badge partials `shell/_tab_friend_trades_badge`, `shell/_tab_market_badge`, `pages/_menu_friend_trades_badge`, `pages/_menu_market_badge` stay (native badges, player streams, top bar stream); `Game::Achievements::CATALOGUE` and the duel achievement keys stay; the duel stats feed handler publishes on every weekly run.

**Never:** no migration (the table drop is a later release); no edit of `db/migrate/20261118140000_create_game_feature_flags.rb`; no change to the capsule, `GrantAchievementsJob`'s subscription, the Duelliste back catalogue or the duel result lines (entry 2); no change to the native tab code (entry 3); no change to `Game::DuelRecord` (entry 5).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Any signed-in player | no `game_feature_flags` row | tab bar PONT · CAPSULE · SETS · ÉCHANGES · DUELS, DUELS with ALPHA; hub menu 03 ÉCHANGES, 04 DUELS with ALPHA | none |
| Duel pages | `/duels`, `/decks/new`, practice, feedback | answer normally, no 404 gate | none |
| Achievements | a duel achievement unlocked earlier | not listed, not counted in earned / total, never granted | none |
| Public / own profile | player with finished duels | ACTIVITÉ shows capsules, discoveries, trades only | none |
| Weekly duel stats | `DuelStatsComputed` reason weekly with moves | feed entry written | none |

</intent-contract>

## Code Map

Switch to delete (files): `app/domains/game/app/models/game/feature_flag.rb`, `app/domains/game/app/operations/game/set_feature_flag.rb`, `app/domains/game/app/events/game/feature_flag_set.rb`, `app/domains/game/app/queries/game/enabled_features.rb`, `app/controllers/concerns/feature_gate.rb` (+ `include FeatureGate` in `application_controller.rb`), `app/controllers/back_office/features_controller.rb`, `app/views/back_office/features/index.html.erb`, `app/policies/back_office/features_policy.rb`, route `resources :features` (+ its comment) in `config/routes.rb` (~286), tile `back_office_tile(:features, …)` in `app/helpers/back_office_dashboard_helper.rb:29`, `feature_enabled?` in `app/helpers/application_helper.rb`.

Locales to drop (both files): `back_office.features.*`, `back_office.dashboard.show.tiles.features`, `errors.game.unknown_feature` (en ~2310, fr ~4935; keep `errors.accounts.unknown_feature`, used by `Accounts::SendFeedback`); check `errors.game.administrator_required` is used elsewhere before touching it (leave it if so).

Gated branches → keep duels side: `require_feature :duels` in `duels_controller.rb`, `feedbacks_controller.rb`, `duel_moves_controller.rb`, `deck_cards_controller.rb`, `decks_controller.rb`; `ShellHelper#shell_tabs` (always `exchanges_and_duels_tabs`; delete `trades_and_market_tabs`); `shell/_tab_bar.html.erb` (drop the `:trades` friend-trades and `:market` branches); `pages/_menu.html.erb` (only `menu_trades` + `menu_duels`; delete now-unrendered `pages/_menu_friend_trades.html.erb`, `pages/_menu_market.html.erb`, and their locale keys only if nothing else uses them); `exchanges/_tabs.html.erb`, `layouts/application.html.erb:23`, `cards/show.html.erb:21`, `duels/_challenge_button.html.erb`, `pages/how_it_works.html.erb:95`; `Game::Handlers::DuelStatsFeed` (drop the `EnabledFeatures` clause).

Switched-off side kept: `Game::Achievements.offered` (`achievements.rb:110`) becomes a constant-backed method returning `CATALOGUE.reject(&:duel?)`, no argument. Callers unchanged: `AchievementBoard`, `EarnedAchievements`, `UnclaimedAchievements`, `CardBackShelf.offered_backs` (so Duelliste leaves the shelf), `GrantAchievementsJob` via `unearned`.

Profile: `public_profiles/_stats.html.erb` drops the duel `<dl>`; `Game::ProfileActivity` drops `duel_wins/duel_losses/duel_draws` and the three `DuelRecord::*_SQL` subqueries (leave `DuelRecord` as is); locale keys `public_profiles.show.stats.duel_*` go.

ALPHA: `duels/_alpha.html.erb` + `duels.alpha_warning` (append the sentence); tag markup reuses `.alpha-tag` from `app/frontend/styles/feedback.css`; tab `.tab-bar__tab` is `position: relative` with an absolute `.tab-bar__badge` at top right (`shell-status.css`); menu item in `pages/_menu_duels.html.erb`, `.menu-item` flex row (`hub.css`).

Tests touching the switch or the duel catalogue: delete `test/integration/duels_switch_test.rb`, `test/domains/game/set_feature_flag_test.rb`, `test/controllers/back_office/features_controller_test.rb`, `test/fixtures/game/feature_flags.yml`, `test/system/duel_achievements_test.rb`. Rewrite: `earned_achievements_test.rb` (no `EnabledFeatures` warm-up; totals = `offered.size`), `achievement_board_test.rb` (catalogue-order test reads `offered`; the "without duels" test loses its switch), `card_back_shelf_test.rb` (no switch; achievement group without `duelliste`), `duel_achievements_test.rb` (the job test and the Duelliste test assert nothing granted), `achievements_test.rb:~669` (metrics read = metrics of `offered`), `achievements_controller_test.rb:90,100,240`, `pages_controller_test.rb:200-201`, `public_profiles_controller_test.rb` (`CATALOGUE.size` → `offered.size`; duel figures gone at 96-97 and ~533), `profile_activity_test.rb`, `test/system/duel_record_test.rb:54-56`.

## Tasks & Acceptance

**Execution:**
- [x] Switch files above -- delete; strip `include FeatureGate`, `feature_enabled?`, route, tile, locale keys -- R1
- [x] Five duel controllers, shell helper, tab bar, hub menu, six views, `DuelStatsFeed` -- keep the duels side only; delete the two unrendered menu partials -- R1
- [x] `app/domains/game/app/models/game/achievements.rb` -- `offered` is the catalogue without duel achievements, for good -- entry 2 relies on it
- [x] `app/views/shell/_tab_bar.html.erb`, `app/views/pages/_menu_duels.html.erb`, `app/frontend/styles/feedback.css` -- ALPHA tag (`t("duels.alpha")`) on the DUELS tab, outside `.tab-bar__label`, pinned at the tab's top-left as the badge is at its top-right, and after the menu 04 label; compact modifier of `.alpha-tag` -- R2
- [x] `config/locales/{en,fr}.yml` `duels.alpha_warning` -- append "Your games are analysed to balance the rules." / "Vos parties sont analysées pour équilibrer les règles." -- R2
- [x] `public_profiles/_stats.html.erb`, `profile_activity.rb`, locales -- drop the duel figures -- R3
- [x] Tests listed in the Code Map -- delete or rewrite; add `test/system/duels_alpha_test.rb` -- verify line

**Acceptance Criteria:**
- Given a signed-in player and an empty `game_feature_flags`, when they load the hub at phone width, then the DUELS tab shows ALPHA; when they open Duels, then the banner reads "…Your games are analysed to balance the rules."; when they open a friend's public profile, then no "Duel wins / losses / draws" figure shows.
- Given the code, when grepping `app/` and `test/` for `feature_enabled?`, `FeatureFlag`, `require_feature`, `EnabledFeatures`, `SetFeatureFlag`, then nothing matches.
- Given a player with a duel achievement unlocked, when the Succès screen, the hub menu or the public profile counts achievements, then the total and earned count leave duel achievements out.
- Given a weekly `DuelStatsComputed` with moves, when the handler runs, then a `duel_stats` feed entry is written (existing `duel_stats_feed_test`).

## Implementation Notes

- Built without running any suite or check (coordinator runs them).
- Besides the listed keys, `shell.tabs.market` and `pages.home.menu.market` went from both locales: nothing renders them once the `:market` tab and the market menu entry are gone. `errors.game.administrator_required` stays (market and code-contribution operations use it).
- The tab's tag is `.alpha-tag.alpha-tag--compact.tab-bar__alpha`; the position lives in `shell-status.css` next to the badge, at the tab's very corner (`top: 0; left: 0`, compact line-height 10px so the box ends above the icon), since an ALPHA at 11px mono overflows the 72px tab if pinned to the icon's left as the badge is to its right.
- Menu 04 uses the plain `.alpha-tag`, between the label and the badge slot.
- The back-office `features` pixel icon entry is gone and `office-features.svg` deleted (the export does not remove stale files; `--check` passes).
- Pinned query counts lost the switch's one read per request.
- Extra assertions: the ALPHA tag in `pages_controller_test` (menu 04) and `shell_test` (DUELS tab).

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 7 findings — high 0, medium 3, low 4, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` `dashboard_controller_test.rb:64` still expects 15 office tiles after the features tile left — set to 14.
  - `[medium]` `[patch]` `card_backs_controller_test.rb:36,40,41` counts duelliste in the back sheet, which `offered` now leaves out — sheet total `KEYS.size - 1`, locked tiles `KEYS.size - 7`.
  - `[medium]` `[patch]` pinned query counts still include the switch's one read per request (bumped by 9adfffac in pages, cards, library, library_set, library_filter_row, library_goal_suggestions, public_profiles tests) — each lowered by 1; `git log -G` shows no count added since that commit on a switch-reading screen except PLAYER_HUB_QUERIES and suggested_forty, both lowered too.
  - `[low]` `[patch]` the compact ALPHA tag at top 4px covers the top-left of the DUELS tab icon — pinned to the tab corner (`top: 0; left: 0`) with a 10px line-height so its box ends above the icon.
  - `[low]` `[patch]` `script/pixel_art/back_office_icons.mjs` still generates the unused `office-features.svg` — entry removed, SVG deleted, `export.mjs --check` passes.
  - `[low]` `[reject]` the native app now shows the Échanges sub-tabs beside its own Trades and Market tabs — entry 3 of this epic reverses the native side of 6661f3b7 and 30e6f4a0, and release 1.4.0 ships the epic's entries together, so no player sees the in-between state.
  - `[low]` `[reject]` `ClaimAchievement` can still claim a duel achievement unlocked before this change by a direct POST — only staff testers had duels, the UI no longer lists it, and the entry-2 ticket states already granted rewards stay as they are; closing it would add a guard to an operation entry 2 owns.

## Design Notes

Assumptions (no one to ask):
- The tab's ALPHA tag sits absolutely at the tab's top-left, mirroring the count badge at top-right, in a compact `.alpha-tag` (button-sm font, no tracking) so it fits a 72px tab at 360px; the label stays "DUELS" so `.tab-bar__label` texts and the native tab parsing are unchanged.
- Menu 04's tag follows the label span, before the arrow, so tests reading `.menu-item__label` keep "Duels".
- The banner's new line extends `duels.alpha_warning` (one sentence, as EXPERIENCE.md writes it) instead of a second key.
- `FeatureFlagSet` events already in the event store stay there; nothing reads events of all types back.
- The unrendered `pages/_menu_friend_trades` and `pages/_menu_market` entry partials are deleted; their badge partials stay for the player streams.

## Verification

Per the coordinator, suites run once in the main tree; this build runs none.

**Commands (coordinator):**
- `bin/rails test` and `bin/rails test test/system/duels_alpha_test.rb test/system/duel_record_test.rb test/system/duels_test.rb` -- expected: green
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/ci` -- expected: green
- `grep -rnE "feature_enabled\?|FeatureFlag|require_feature|EnabledFeatures" app test` -- expected: no match

## Auto Run Result

Status: built

**Summary:** the runtime duels switch is gone end to end (model, operation, event, query, controller gate, helper, back-office Features screen, route, policy, tile, icon, locales); every gated branch keeps its duels side, `Game::Achievements.offered` keeps the catalogue without the duel achievements for good, the DUELS tab and menu 04 carry ALPHA, the alpha banner adds "Your games are analysed to balance the rules." / "Vos parties sont analysées pour équilibrer les règles.", and the public and own profile lose the duel figures (`ProfileActivity` drops its three duel columns). `game_feature_flags` stays in the schema, unread.

**Files changed:**
- `app/controllers/*` — `FeatureGate` concern and the five `require_feature :duels` gone; back-office features controller deleted.
- `app/domains/game/...` — `FeatureFlag`, `SetFeatureFlag`, `FeatureFlagSet`, `EnabledFeatures` deleted; `Achievements::OFFERED`; `DuelStatsFeed` always posts; `ProfileActivity` without duels.
- `app/helpers/*` — `feature_enabled?`, `trades_and_market_tabs`, the features tile gone.
- `app/views/*` — gates unwrapped (tab bar, hub menu, exchanges tabs, layout, card page, challenge button, how it works, profile stats); ALPHA tag on the tab and menu 04; menu_friend_trades / menu_market partials and the features view deleted.
- `app/frontend/styles/feedback.css`, `shell-status.css` — compact tag and its tab position.
- `script/pixel_art/back_office_icons.mjs`, `app/frontend/images/pixel/office-features.svg` — unused icon removed.
- `config/routes.rb`, `config/locales/{en,fr}.yml` — route and keys removed, banner sentence added.
- Tests — switch tests and fixture deleted, duel achievements system test deleted, catalogue totals read `offered`, duel figures and query counts adjusted, `test/system/duels_alpha_test.rb` added.

**Review:** 5 patches applied (3 medium, 2 low), 0 deferred, 2 rejected (native sub-tabs until entry 3; claim of a pre-existing duel achievement unlock — reasons in the triage log).

**Follow-up review recommended:** true — three medium findings patched; the patched count expectations, the card-back sheet counts and the new system test were never run, so a wrong count would only show in the coordinator's suite run.

**Verification:** no suite or check run in this build, by the coordinator's instruction; grep for `feature_enabled?|FeatureFlag|require_feature|EnabledFeatures|SetFeatureFlag|FeatureGate|features_path` over app, test, config, lib, script finds nothing; `node script/pixel_art/export.mjs --check` passes.

**Residual risks:** the ALPHA tag's tab position was never seen rendered; `i18n-tasks` may flag key ordering; the native app shows the Échanges sub-tabs until entry 3.
