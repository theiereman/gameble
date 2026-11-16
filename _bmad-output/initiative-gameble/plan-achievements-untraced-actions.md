---
title: 'Achievements for actions that leave no trace today: goals, avatar, repo and support links'
type: 'feature'
ticket: ''
created: '2026-11-16'
status: 'built'
baseline_revision: '4bf9ec319e670e92a16953bd41604882a4fc98c2'
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

**Problem:** The author wants achievements for completing goals, changing the avatar, and looking at the GitHub repo and the support page. A reached goal is deleted without a trace, and a click on an outbound link is never recorded.

**Approach:** Keep three small per-player markers on `game_player_states` (goals completed, repo opened, support opened), read the avatar changes from the stored `AvatarChosen` events, add 7 catalogue entries, and record the two link clicks with a POST beacon.

## Boundaries & Constraints

**Always:** Follow the previous achievements plan's pattern: metrics in `AchievementProgress::METRIC_SQL`, strings in both locales, glyphs from `node script/pixel_art/export.mjs`. A write goes through an operation that publishes one event; the beacon is a POST, never a GET write, rate-limited like `TradeSeensController`, and absent for visitors. The migration is expand-only (strong_migrations) and `db/schema.rb` is regenerated as AGENTS.md says. Deleting an account clears the new markers, and the export and the legal text name them.

**Decisions (author, 2026-11-16):** Goals completed and both link clicks count from release day (existing players start at 0); the avatar count is retroactive, from events. Re-choosing the avatar already worn counts as a choice. Each link is an achievement of its own. Lots C, D and E stay out.

**Never:** No change to how a goal is reached or dropped, no new table, no beacon on the public landing page.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected |
|----------|--------------|----------|
| Goal reached | An opening completes 2 of a player's goals | `goals_completed` +2 in the same transaction as the drop; grant re-checked after commit |
| Goal removed by hand | `RemoveGoal` | counter unchanged |
| Avatar chosen | 5 `AvatarChosen` events for the player, others' events present | `avatar_choices` = 5, never another player's |
| First click | Signed-in player opens the repo link | marker set once, event published, achievement granted |
| Repeat click | Same link again | marker unchanged (first time kept), no second event |
| Visitor click | No session | no request sent (no beacon on the page) |
| Bad link | POST with an unknown link name | 404, nothing written |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/goal.rb` `drop_reached`, called by `handlers/goals_reached.rb` (events already in the Achievements handler) -- count per player before the delete.
- `app/domains/game/app/models/game/player_state.rb`, `operations/game/choose_avatar.rb` (inserts the row with `unique_by: :player_id`) -- the row to hold the markers; `release_player.rb` already deletes it.
- `app/domains/game/app/operations/game/mark_trade_seen.rb`, `trade_seens_controller.rb`, `trade_seen_policy.rb`, route `trades/:token/seen`, `app/frontend/controllers/trade_seen_controller.ts`, `views/trades/_seen_beacon.html.erb` -- the beacon pattern to copy.
- `app/helpers/external_links_helper.rb` -- `donation_link_to`, `donation_menu_item_to`, `source_code_link_to`, `source_code_menu_item_to`; used in settings, the hub menu, the player chip and the legal page (public: skip the beacon for visitors).
- `event_store_events` (`event_type`, jsonb `data`) for `Game::AvatarChosen`.
- Previous plan: `plan-achievements-from-existing-data.md` for catalogue, helper glyphs, locale and test shapes (`more_achievements_test.rb`).
- `queries/game/export_of.rb` and the privacy text under `config/locales/*.yml` (`activity:` and deletion lists) -- add the markers.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/*_add_untraced_actions_to_game_player_states.rb` -- `goals_completed` integer not null default 0, `source_code_opened_at`, `support_opened_at` timestamps; regenerate `db/schema.rb`.
- [ ] `goal.rb` (+ `player_state.rb`) -- add each player's reached goals to `goals_completed` when they are dropped.
- [ ] `operations/game/mark_link_opened.rb`, `events/game/link_opened.rb`, `external_link_opens_controller.rb`, policy, route, Stimulus controller, helper data attributes, event-store registration -- the beacon; first click only.
- [ ] `achievement_progress.rb`, `achievements.rb`, `handlers/achievements.rb` -- metrics `goals_completed`, `avatar_choices`, `source_code_opened`, `support_opened`; entries below; triggers `AvatarChosen` and `LinkOpened`.
- [ ] `achievements_helper.rb`, `export.mjs` -- glyphs (reuse `ledger`, `lens`, `coin`; one new `portrait`); run the exporter.
- [ ] `en.yml`, `fr.yml`, `export_of.rb` -- names, conditions, privacy and export wording.
- [ ] Tests -- one per matrix row, plus the policy and the controller; keep totals derived from `CATALOGUE`.

| Key | Metric | ≥ | Glyph | fr | en |
|---|---|---|---|---|---|
| goals_10 / 25 / 50 | goals_completed | 10/25/50 | ledger | Revue de projet · Chef de projet · Directeur de programme | Project Review · Project Manager · Programme Director |
| avatar_changed / avatar_rebrand | avatar_choices | 1 / 5 | portrait | Photo d'identité · Refonte de l'image de marque | ID Photo · Corporate Rebrand |
| source_audit | source_code_opened | 1 | lens | Audit de conformité | Compliance Audit |
| funding_review | support_opened | 1 | coin | Étude de financement | Funding Review |

**Acceptance Criteria:**
- Given a signed-in player, when they click the repo or support link, then the achievement is granted without a page reload being needed.
- Given the achievements screen, when it renders, then all 69 tiles show glyph, name and condition.

## Verification

**Commands:**
- `bin/rails test` and `npm run test:js` -- green
- `node script/pixel_art/export.mjs --check`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references`, `bundle exec i18n-tasks missing`, `npm run format:check` -- clean

## Implementation Notes

## Plan Change Log

## Review Triage Log

- Pass 1 (quick): 5 patched, 7 rejected.
  - patched · low-medium -- the legal page's source link bypassed the helper, so no beacon: now `source_code_link_to`.
  - patched · low -- middle-click opens a tab without `click`: the beacon also listens to `auxclick`.
  - patched · low -- hub menu test weakened: it now asserts the beacon on support and source, none on Discord.
  - patched · low -- no vitest spec for `link_open_controller.ts`: added (POST, CSRF, keepalive, middle click, failed fetch).
  - patched · low -- the catalogue test no longer pinned the seven new entries: pinned again; the `unknown_link` error key added in both locales.
  - rejected -- double count of a dropped goal under concurrency: goal drops run inside operations that already hold the player's bank lock.
  - rejected -- `AVATAR_CHOICES_SQL` scans all `AvatarChosen` events: the plan chose events for the retroactive count and avatar changes are rare; revisit if the event table grows.
  - rejected -- `MarkLinkOpened` Success value carries no meaning; no consumer reads it.
  - rejected -- no test of a visitor's absent beacon / no end-to-end `goals_10` grant: the controller answers a visitor with a refusal, and the grant rides the PackOpened and other triggers already tested.
  - false -- "69 tiles not rendered": the achievements controller test renders every tile and totals come from `CATALOGUE`.
