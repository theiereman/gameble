---
title: 'The Succès screen'
type: 'feature'
ticket: '11'
created: '2026-10-14'
status: 'built'
baseline_revision: '673ab9a'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The ten achievements are granted and toasted, but a player cannot see them: menu 06 and the PLUS row "Succès" are disabled ("bientôt disponible") and no screen lists what is earned or how far the rest are.

**Approach:** A signed-in-only SUCCÈS screen: the header count "n / 10" beside a gauge of one segment per achievement under "SUCCÈS OBTENUS", then the tiles grouped "OBTENUS · n" and "À OBTENIR · n", each with a pixel icon, name, condition and, for a countable achievement not yet earned, a 4px progress bar and "n / threshold". Menu 06 (with "earned/total") and the PLUS row link to it for a player and open the sign-in panel for a visitor.

**Decision (author, 2026-10-14):** Every countable achievement not yet earned (threshold above 1) shows its bar and "n / threshold" even at 0, so a new player sees "0 / 10", "0 / 100"… on those tiles.

## Boundaries & Constraints

**Always:** Read only (GET on the reading role); the controller reads through a Game query and authorizes with a Pundit policy. An achievement is earned when its unlock row exists; the header, the groups and menu 06 count the same rows. Tiles in catalogue order within each group. Progress shown is the metric clamped to the threshold. Every string in `en.yml` and `fr.yml` (French plurals with `zero`). No `style` attribute: the gauge and bars take their size from markup and CSS. New pixel icons only through `script/pixel_art/export.mjs`. No planning ids or explanatory comments in code; comments edited in touched files lose their planning references.

**Never:** No card-back "DOS" image (no achievement unlocks a back yet). No live update of the screen (the unlock toast already exists). No change to the achievements engine, its catalogue, grants or toast. No new `gameble:*` event.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Player with some earned | 3 unlock rows, 64 packs opened | "3 / 10", 3 of 10 segments lit; OBTENUS · 3 and À OBTENIR · 7; "100 boosters" shows a bar at 64/100 and "64 / 100" | — |
| New player | no unlock row | "0 / 10"; no OBTENUS group; À OBTENIR · 10; each countable tile shows an empty bar and "0 / threshold" | — |
| All earned | 10 rows | "10 / 10", every segment lit; no À OBTENIR group | — |
| Threshold 1 not earned | `first_trade`, 0 trades | tile without bar or count | — |
| Met, not yet granted | 10 packs opened, grant job pending | `boosters_10` under À OBTENIR, bar full, "10 / 10" | — |
| Visitor, menu 06 or PLUS row | signed out | button opening the sign-in panel | — |
| Visitor, direct GET | `/fr/achievements` | redirected home with the sign-in alert, as `/friends` | Pundit refusal |
| Phone | under 720px | one column, "◀ PLUS" back, PLUS tab current | — |

</frozen-after-approval>

## Code Map

- `packs/game/app/models/game/achievements.rb` -- `CATALOGUE` (key, metric, threshold), `find`; read, do not change.
- `packs/game/app/queries/game/achievement_progress.rb`, `unlocked_achievements.rb` -- the two reads to combine. New `packs/game/app/queries/game/achievement_board.rb`: `call(player)` → tiles `Data.define(:key, :threshold, :progress, :earned)` in catalogue order; `summary(player)` → `{ earned:, total: }` counting unlocked keys present in the catalogue.
- `config/routes.rb` -- `resource :achievements, only: :show` beside `resource :friends`.
- `app/controllers/friends_controller.rb`, `app/policies/friend_policy.rb` -- shape of a signed-in-only screen; new `AchievementsController#show` (`authorize :achievement, :show?`) and `AchievementPolicy` (`show? = player?`). `ApplicationController#refuse` already redirects a visitor home.
- `app/views/feeds/show.html.erb` (top) -- `content_for :back_button`, `:title`, `:screen_title`, `:phone_back` to `more_path` with `.more`; copy for `app/views/achievements/show.html.erb`.
- `app/views/pages/_goal.html.erb`, `hub.css` `.hub-goal__gauge` -- segmented gauge pattern; `app/views/pages/_set_progress.html.erb` -- `<progress aria-hidden>` bar with visually hidden text.
- New `app/helpers/achievements_helper.rb` -- key → glyph (Design Notes).
- `app/views/pages/_menu.html.erb` -- the `else` branch rendering the disabled item goes; new `pages/_menu_achievements.html.erb` modelled on `_menu_friends.html.erb` (link with `menu-item__meta` "3/10" aria-hidden plus visually hidden sentence; visitor button with `dialog-opener`). `app/controllers/pages_controller.rb#home` -- `@achievements = Game::AchievementBoard.summary(current_player)` for a player; pass it in `home.html.erb:28`.
- `app/views/pages/more.html.erb:36-42` -- disabled row becomes a link / sign-in button like the Amis row.
- `app/views/shell/_tab_bar.html.erb` -- add `achievements` to the PLUS-current controllers. `app/helpers/shell_helper.rb` `SCREEN_LABELS` -- `"achievements" => :achievements`.
- `config/locales/{en,fr}.yml` -- remove `pages.home.menu.soon`; add `pages.home.menu.achievements_meta`, `shell.screens.achievements`, `achievements.show.*`, `achievements.conditions.<key>`; `config/i18n-tasks.yml` `ignore_unused` gains `achievements.conditions.*`.
- `script/pixel_art/export.mjs` -- `ICONS` (grid + legend) and `DESCRIPTIONS` (every file needs one); `iconSvg`. Mockup glyphs and shading: `_bmad-output/initiative-gameble/ux-gameble/mockups/key-screens.html` `ACH_ICO`, `achIcon`, CSS `.ac-*`, `.ach*` (~L670).
- New `app/frontend/styles/achievements.css`, imported in `app/frontend/entrypoints/application.css` beside `feed.css`. Tokens: `--font-count-large(-phone)`, `--gauge-gap`, `--color-panel-sunken`, `--color-line-deep`, `--color-accent`.
- Tests to update: `test/controllers/pages_controller_test.rb:143-146` (06 disabled), `test/controllers/friends_controller_test.rb:348-362` (pattern for menu/PLUS tests), `test/integration/shell_test.rb` (tab bar), `test/policies/friend_policy_test.rb` (pattern).

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/queries/game/achievement_board.rb` + `test/packs/game/achievement_board_test.rb` -- tiles and summary; nil player, clamping, unknown stored key ignored.
- [x] `config/routes.rb`, `app/controllers/achievements_controller.rb`, `app/policies/achievement_policy.rb` + `test/policies/achievement_policy_test.rb` -- the screen's entry.
- [x] `app/views/achievements/show.html.erb`, `app/helpers/achievements_helper.rb`, `app/frontend/styles/achievements.css`, `application.css` -- header, groups, tiles; tiles fill columns of at least 260px, one column on the phone; locked tiles sunken with gray icon.
- [x] `script/pixel_art/export.mjs` then `node script/pixel_art/export.mjs` -- six glyphs, earned and locked variants.
- [x] `_menu.html.erb`, new `_menu_achievements.html.erb`, `pages_controller.rb`, `home.html.erb`, `more.html.erb`, `_tab_bar.html.erb`, `shell_helper.rb` -- enable 06 and the PLUS row.
- [x] `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml` -- copy (Design Notes).
- [x] `test/controllers/achievements_controller_test.rb` -- every matrix row (fr and en copy), the gauge's lit segments, the `<progress>` value/max, menu 06 meta and the PLUS row for player and visitor, PLUS tab current; update `pages_controller_test.rb` 06 assertions.

**Acceptance Criteria:**
- Given a signed-in player on the hub, when they press 6 inside the menu or click 06, then the SUCCÈS screen opens with the top-bar title "Succès", and the next screen's back button reads "◀ SUCCÈS".
- Given a player at 1280px and at 390px, when the screen renders, then tiles fill 260px+ columns on desktop and one column on the phone, with no horizontal scroll.

## Design Notes

Glyphs (7 × 7 grids from the mockup's `ACH_ICO`, each cell 2 × 2 art px, lit top edge, shaded bottom/right edge, as `achIcon`), exported as `achievement-<glyph>.svg` (lit/body/shade `#d2efff`/`#66c0f4`/`#2a6f9a`) and `achievement-<glyph>-locked.svg` (`#8f98a0`/`#5d6b78`/`#3d4a57`): `pack` (first_booster, boosters_10/100/500), `gem` (first_epic), `star` (first_legendary), `set` (first_complete_set, three_complete_sets), `trade` (first_trade), `card` (first_repost).

Condition drafts (fr / en), for the author to correct at review: Ouvrir un booster / Open a booster; Obtenir une carte Épique / Get an Epic card; Obtenir une carte Légendaire / Get a Legendary card; Compléter un set / Complete a set; Conclure un échange / Complete a trade; Ouvrir 10 (100, 500) boosters / Open 10 (100, 500) boosters; Compléter 3 sets / Complete 3 sets; Reposter une carte / Repost a card. Headings: "Succès obtenus" / "Achievements earned", "Obtenus · %{count}" / "Earned · %{count}", "À obtenir · %{count}" / "To earn · %{count}". Visually hidden sentences beside the aria-hidden figures: header "%{earned} succès obtenus sur %{total}", tile progress "%{progress} sur %{threshold}", menu 06 `achievements_meta` (fr `zero`/`one`/`other`).

## Implementation Notes

- The screen has an `h1` « SUCCÈS » as a small accented title, as the Friends and Feed screens do; the mockup shows none.
- Condition and progress texts use `--font-body-small`: no token exists for the mockup's VT323 17px.
- Menu 06 adds one count query to the player hub: `PLAYER_HUB_QUERIES` goes from 19 to 20. `settings_controller_test.rb` (outside the Code Map) asserted the disabled PLUS row and is updated. `config/i18n-tasks.yml` ignores `achievements.conditions.*`, read by key from the catalogue.
- Verified by the implementer: `bin/rails test` 2529 runs green, vitest 315, typecheck, rubocop, packwerk, zeitwerk, brakeman, pixel-art `--check`, i18n-tasks missing; the screen rendered in headless Chromium at 1280 and 390 px. Not tried signed in on a running app.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick, 2026-10-14) — high 0, medium 0, low 4, false 0, maybe-false 0

- `low` patch — new explanatory comments (the menu 06 partial's header, `achievements.css`'s opening block, the comment above `ACHIEVEMENT_GLYPHS`) break this plan's "no explanatory comments" boundary; deleted.
- `low` patch — the `achievements.conditions.*` ignore in `config/i18n-tasks.yml` sat under the comment about names looked up from an unlock's key; it gets an accurate comment.
- `low` patch — the visitor test's "no count" check searched the whole hub menu (menu 02's "0/100" could trip it); scoped to the 06 button.
- `low` patch — two differences from the reference mockup: gauge segments 10px instead of the 12px token, and a locked tile's icon frame not dimmed to .55; aligned.

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- expected: exit 0
- `bin/rails test` -- expected: green (system tests skipped)
- `npm run test:js`, `bin/rubocop`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: clean

**Manual checks:**
- Signed in, `/fr/achievements` at 1280px and 390px: header, gauge, groups, bars as in the mockup; signed out, menu 06 and the PLUS row open the sign-in panel.
