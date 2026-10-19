---
title: 'The public profile shows a player off'
type: 'feature'
ticket: 3
created: '2026-10-19'
status: 'built'
baseline_revision: '6b7a9557bf63f8321002e314a1cdb98c7ee46bfe'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The public profile (`/:locale/brothers/:token`) shows a bare summary (name, two counts, a visibility line) over the collection's set search and set list; its DESIGN.md section (Components: Public profile) and EXPERIENCE.md rows (Public profile; State Patterns) now describe a showcase page instead.

**Approach:** Rebuild the show page, in this order, for every viewer who may see it: the identity band (avatar, name h1, « Membre depuis mars 2026 », SIGNALER, the three key numbers CARTES owned/season total, SETS COMPLETS, SUCCÈS earned/total), the stats region (RARETÉS one figure per rarity, ACTIVITÉ capsules opened, first discoveries, trades concluded), SUCCÈS (count, segmented gauge, the four latest earned as earned tiles), SETS (« N sets entamés », the started sets as Set progress rows, complete first then by share owned, each opening the existing read-only album). No VITRINE section yet (the no-showcase state). Restyle the unavailable page to its design.

## Boundaries & Constraints

**Always:** Follow DESIGN.md « Public profile » and EXPERIENCE.md « Public profile » with the mock `ux-gameble/mockups/key-public-profile.html` as visual reference (rules win over the mock; its set-row tier marks predate the new set ranks — use today's Set progress row). Desktop one column; phone at 390px stacks the band (key numbers in three columns under a 2px rule), stats in three/two columns, SUCCÈS tiles in one column, sets in one column. h1 = player name; SUCCÈS and SETS are h2; stats a region named « Statistiques ». Every string in en.yml and fr.yml (plural keys with a `zero` form in French). Reads only through pack queries, any player (not only `current_player`), a fixed number of queries whatever the history. The GET writes nothing. No `style` attribute in server HTML. No database id in HTML. Visibility rules unchanged (`Game::Visibility`); unknown token, private, friends-only to a non-friend and banned all render the same unavailable page with 404.

**Never:** The relation action (« AJOUTER EN AMI »…, story 16.6), VITRINE and its reorder buttons (16.4, 16.5), « VOIR LA COLLECTION COMPLÈTE » and another player's full collection (16.7) — none of these appear. No tabs, filters, set search or visibility line. No change to the friend profile dialog, the settings summary, the album page (`public_profiles#set`) or the report dialog's behaviour. No migration.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Visitor, public owner | Owner holds cards, earned achievements, started and completed sets | Band with name, member-since month and year, SIGNALER opening the sign-in panel, CARTES n/total, SETS COMPLETS, SUCCÈS n/total; RARETÉS five figures summing to CARTES; ACTIVITÉ three counts; four latest achievements, newest first; sets complete first, then by share | — |
| Owner's own profile | viewer = owner | Same page, no SIGNALER | — |
| Nothing earned or started | New owner | SUCCÈS shows 0 / total and an unlit gauge, no « Derniers obtenus » label or tiles; SETS shows the zero count line and no rows | — |
| Fewer than four earned | 2 earned | Two tiles | — |
| No season published | — | Band with zero cards; the existing no-season line in place of stats/SUCCÈS/SETS | — |
| Hidden profile | Unknown token, private, friends-only to non-friend, banned | Unavailable page, 404, the restyled quiet panel | — |
| Staff | Staff viewer of a hidden profile | The profile, as today | — |

</intent-contract>

## Code Map

- `app/controllers/public_profiles_controller.rb` -- `show` loads `SetBoardLoading` search + `Game::CollectionSummary`; drop the set board from `show` (keep `SetAlbumLoading` for `set`), load the new figures.
- `app/views/public_profiles/{show,_profile,_summary,unavailable}.html.erb` -- rewrite; `_summary` becomes the identity band (keep SIGNALER logic: sign-in panel for a visitor, report dialog for another player, none for the owner; `reports/_dialog` rendered by the profile).
- `app/helpers/public_profiles_helper.rb` -- `public_profile_title`; `public_profile_visibility` loses its only caller here (check `rg public_profile_visibility`, delete if dead).
- Queries (all any-player, nil-safe): `Game::CollectionSummary.call(owner, season:)` (distinct_cards, complete_sets; 1 query), `Catalog::CardCount.call(season)`, `Game::HeldGames.by_rarity(owner)` ({1..5 => n}), `Game::AchievementBoard.summary(owner)` ({earned:, total:}), `Game::AchievementProgress.call(owner)` (`packs_opened`, `trades_accepted` = concluded), `Game::SetsInProgress.call(owner, season:)` ({set_id => Game::SetStanding}; `complete?`, `share`, `held`, `total`), `Catalog::SetsById`.
- New Game queries needed: the latest earned achievement keys (`Game::AchievementUnlock`, `unlocked_at` desc, then key; limit 4) and the first-discovery count (`Game::FirstDiscovery`, `player_id`). Combining counts into one query is welcome.
- `app/views/achievements/show.html.erb` + `app/helpers/achievements_helper.rb#achievement_icon` + `app/frontend/styles/achievements.css` -- the earned tile and the header (count + segmented gauge) are inline; extract partials reused by the profile, achievements screen output unchanged.
- `app/views/library/_set_progress_row.html.erb` (locals `href:, set:, standing:`), `SetBoardLoading::SetRow` -- reuse for SETS rows, href `brother_set_path(owner.token, kind:, key:)`.
- `accounts_players.created_at` -- member since (`l(..., format:)` with month name and year; fr month names exist in fr.yml).
- `app/frontend/styles/profile.css` -- `.profile*`, `.profile-unavailable`, report dialog rules; tokens in `tokens.css` (`--font-public-title`, `--font-count-large(-phone)`, `--font-showcase-name`, `colors.line-soft`…). Corner brackets via `PanelComponent brackets: true`.
- `config/locales/{en,fr}.yml` `public_profiles.*` -- Copy deck « Public profile » (EXPERIENCE.md line ~126) gives fr and en.
- `test/controllers/public_profiles_controller_test.rb` -- many tests assert the old search/visibility line and a query budget; rewrite those; keep visibility/ban/token/escaping/no-id tests.
- `test/system/public_profile_test.rb` -- update selectors that no longer exist (do not run system tests).

## Tasks & Acceptance

**Execution:**
- [ ] `packs/game/app/queries/game/` -- add the latest-achievements and activity (or first-discovery count) queries, with tests in `test/packs/game/`.
- [ ] `app/views/achievements/` -- extract the earned tile and the count+gauge header into partials; the achievements screen renders them unchanged.
- [ ] `app/controllers/public_profiles_controller.rb` -- `show` loads the figures above, sorts started sets complete first, then share desc, then set id; drops the set search.
- [ ] `app/views/public_profiles/` -- identity band, stats region, SUCCÈS, SETS, unavailable page per DESIGN.md; no-season line kept.
- [ ] `app/frontend/styles/profile.css` -- desktop and phone layouts per DESIGN.md; drop dead `.profile-summary__visibility`/counts rules.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- copy deck strings; remove keys no longer used (i18n-tasks unused must stay clean).
- [ ] `test/controllers/public_profiles_controller_test.rb`, `test/system/public_profile_test.rb` -- request tests per matrix and verify line; the profile GET writes nothing; updated query budget.

**Acceptance Criteria:**
- Given a public owner with figures, when a visitor GETs the profile, then each figure shows as in the matrix, the sets are complete first then by share owned, and the request writes no row.
- Given a private, a friends-only (viewer not a friend) or a banned owner, when the profile is requested, then the unavailable page answers with 404.

## Implementation Notes

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The no-database-id request test gained blanket strips (`>\d+<`, `\/ ?\d+`) that would hide an id in any URL path or all-number element, on the album page too — replaced by narrow strips of `.profile-figure__value` and `.achievements__count` only.
  - `[low]` `[patch]` profile.css dropped SUCCÈS to two columns from 720 to 1179px, against DESIGN.md (four columns at every desktop width) — the step is removed.
  - `[low]` `[patch]` `load_showcase` named the VITRINE feature it does not load — renamed `load_stats_and_sets`.

## Auto Run Result

- **Summary:** the public profile is rebuilt to DESIGN.md: the identity band (avatar, name h1, member since month and year, SIGNALER, CARTES n/total, SETS COMPLETS, SUCCÈS n/total), the « Statistiques » region (RARETÉS five figures in rarity colours, ACTIVITÉ capsules opened, first discoveries, trades concluded), SUCCÈS (count, segmented gauge, four latest earned tiles) and SETS (« N sets entamés », started sets as Set progress rows, complete first then by share, each opening the existing album). No VITRINE, relation action or full-collection button (later stories); the set search and visibility line are gone. The unavailable page is a quiet centred panel with the dimmed avatar; both pages carry the top-bar title.
- **Files:** `Game::EarnedAchievements` and `Game::ProfileActivity` (new queries, one SQL each, with tests; `AchievementProgress` exposes its two counts' SQL), `achievements/_header` and `_tile` (extracted, screen output byte-identical), `PublicProfilesController#show`, `public_profiles/*` views and `profile.css`, `public_profile_visibility` helper removed, en/fr copy plus full month names and a `month_year` date format, `i18n-tasks.yml` ignores `date.*`/`time.*`, request tests rewritten (matrix, no write on GET, 9 queries for a visitor whatever the history, 14 signed in), reports and system test selectors.
- **Review:** 3 patches (1 medium, 2 low), 0 deferred, 0 rejected. Follow-up review: false.
- **Verification:** `bin/ci` green before the patches (2832 runs, 0 failures); after the patches the profile and achievements request tests (39 runs) and rubocop green; `npm run test:js`, `npm run typecheck`, `zeitwerk:check`, packwerk green; headless Chrome screenshots at 1280 and 390px match the mock's layout. Full `bin/ci` reruns after rebase before push.
- **Residual risks:** the empty SUCCÈS/SETS states follow the plan's reading of an open question (see Design Notes); CARTES counts games held in any edition over the current season's total, as the summary always has, so it can exceed the total after a season change; at 390px a signed-out visitor's top-bar title runs under the Steam sign-in image (shell layout, also on other signed-out pages with a screen title).

## Design Notes

The empty SUCCÈS and SETS states are an open question in EXPERIENCE.md (« Open questions: Public profile »); the matrix row follows the page's own pattern of never showing an empty slot and keeps the section headings with their zero counts. The author confirms it on staging.

## Verification

**Commands:**
- `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1608 bin/rails test test/controllers/public_profiles_controller_test.rb test/controllers/achievements_controller_test.rb test/packs/game` -- expected: green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `npm run typecheck`, `npm run test:js` -- expected: clean
- Full `bin/rails test` and `bin/ci` -- run by the orchestrator through the shared slot wrapper.

**Manual checks:**
- The profile at 1280px and 390px matches the mock's layout (headless screenshot if available).
