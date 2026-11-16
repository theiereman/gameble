---
title: 'Achievements for viewing other players profiles and for being visited'
type: 'feature'
ticket: ''
created: '2026-11-16'
status: 'built'
baseline_revision: 'f52152da042e182e074d8bedd24a2769b385fc1a'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The author wants achievements for viewing another player's profile 1, 5 and 20 times, and for receiving 10, 50 and 100 visits on one's own profile. The game records no profile view.

**Approach:** A signed-in viewer's browser posts a beacon from a public profile page. An operation records the visit, at most once per viewer and profile per hour, in a new table, and publishes one event that re-checks both players. Six catalogue entries read the table.

## Boundaries & Constraints

**Always:** Follow `plan-achievements-untraced-actions.md` for the beacon (POST, rate-limited like `TradeSeensController`, absent for visitors), the operation and event shape, the handler trigger, glyphs (reuse `lens` and `showcase`), both locales and tests. The table is personal data: `ReleasePlayer` deletes the rows where the player is viewer or visited, the data export names the counts, and the privacy texts in both locales say it. The expand-only migration adds the table with an index on each player column in its own migration, and `db/schema.rb` is regenerated as AGENTS.md says. Only a profile the viewer may see (`Game::Visibility.visible?` with `staff_sees_all: false`) counts. The beacon controller `trade_seen_controller.ts` is reused through a neutral name (rename it and update the trades beacon and its test) rather than copied.

**Decisions (author, 2026-11-16):** A visit counts at most once per viewer and profile per hour; several a day are allowed. Looking at your own profile never counts. Existing players start at 0.

**Never:** No GET write, no beacon for visitors without an account, no visitor list shown to the visited player.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected |
|----------|--------------|----------|
| First visit | Viewer opens another visible profile | one row, one event, both players re-checked |
| Within the hour | Same viewer and profile again 20 minutes later | refused, no row, no event |
| After the hour | Same pair 61 minutes later | a second row |
| Own profile | Viewer is the owner | refused, nothing written |
| Hidden profile | Private, or friends-only for a stranger, banned, deleted | refused, nothing written |
| Other profile | Same viewer opens a different profile within the hour | counted |

</frozen-after-approval>

## Code Map

- `app/controllers/public_profiles_controller.rb`, `views/public_profiles/show.html.erb` -- where the beacon goes (GET never writes); route `brothers/:token`.
- `app/domains/game/app/operations/game/mark_trade_seen.rb`, `trade_seens_controller.rb`, `trade_seen_policy.rb`, `app/frontend/controllers/trade_seen_controller.ts` and test, `views/trades/_seen_beacon.html.erb` -- the beacon pattern.
- `app/domains/game/app/models/game/visibility.rb` -- the visibility rule.
- `release_player.rb`, `queries/game/export_of.rb`, privacy wording in `config/locales/*.yml` -- deletion, export, text.
- `achievements.rb`, `achievement_progress.rb`, `handlers/achievements.rb`, `achievements_helper.rb` -- catalogue wiring, as in the lot B plan.

## Tasks & Acceptance

**Execution:**
- [ ] Migrations: table `game_profile_visits` (viewer_id, visited_id, created_at); a concurrent index per player column in its own migration; regenerate `db/schema.rb`.
- [ ] `Game::MarkProfileVisited`, `Game::ProfileVisited` event, `ProfileVisit` model, controller, policy, route, beacon on the public profile page, neutral beacon controller.
- [ ] `release_player.rb`, `export_of.rb` (counts), privacy wording in both locales.
- [ ] Catalogue, metrics `profiles_viewed` and `profile_visits`, handler trigger (viewer and visited), glyph mapping, strings.
- [ ] Tests: each matrix row, controller, policy, metrics, deletion, export; totals derived from `CATALOGUE`.

| Key | Metric | ≥ | Glyph | fr | en |
|---|---|---|---|---|---|
| profiles_viewed_1 / 5 / 20 | profiles_viewed | 1/5/20 | lens | Visite de courtoisie · Tournée d'inspection · Audit des effectifs | Courtesy Call · Inspection Tour · Headcount Audit |
| profile_visits_10 / 50 / 100 | profile_visits | 10/50/100 | showcase | Accueil du public · Fréquentation notable · Pôle d'attraction | Public Reception · Notable Footfall · Place of Interest |

**Acceptance Criteria:**
- Given a signed-in player who opens another player's visible profile, when the page has loaded, then a visit is recorded and the achievements re-checked for both without a reload.

## Verification

**Commands:**
- `bin/rails test` and `npm run test:js` -- green
- `node script/pixel_art/export.mjs --check`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references`, `bundle exec i18n-tasks missing`, `npm run format:check` -- clean

## Implementation Notes

## Plan Change Log

## Review Triage Log

- Pass 1 (quick): 3 patched, 5 rejected.
  - patched -- the English deletion paragraph of the privacy page lacked the profile visits: added.
  - patched -- the hourly rule was check-then-insert; the operation now takes the viewer's bank lock first, serialising a pair's beacons.
  - patched -- no test showed a visit re-checking both players: one performs the job and checks the first achievement.
  - rejected -- `back_office/players/index.html.erb` parenthesised renders: needed, packwerk's ERB parser read `back:` followed by a new line as a hash value (a lot E leftover).
  - rejected -- hidden-profile beacon not tested at page level: the page gate is `@relation`, and the operation row is tested.
  - rejected -- hard-coded `last(14)` and trigger count: the catalogue pin is by design and the count is that test's pattern.
  - rejected -- deleted owner untested: `Visibility.visible?` returns false for it, shared with the other hidden cases.
  - rejected -- no vitest for the renamed controller: none existed before and the page test covers the beacon.
