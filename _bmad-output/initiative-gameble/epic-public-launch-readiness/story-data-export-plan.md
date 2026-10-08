---
title: 'Data export'
type: 'feature'
ticket: '7'
created: '2026-10-08'
status: 'ready-for-dev'
baseline_revision: ''
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The settings promise "MES DONNÉES — EXPORTER" and the privacy notice grants a right of access, but a player has no way to get a copy of their data.

**Approach:** A signed-in player presses EXPORTER in the settings. A POST assembles, in the web layer, one JSON file of what the player owns or did, from new Accounts and Game queries. That file holds no data identifying another player. The response is that file as an attachment. With JavaScript, the button reads PRÉPARATION… while the request runs, then an "EXPORT PRÊT" toast offers the download, and a failure says so inline with a retry. Without JavaScript, the form posts and the browser downloads the file. One export per player every 5 minutes; a second request inside that window is refused.

## Boundaries & Constraints

**Always:**
- The export is a POST and is rate limited per player (`rate_limit to: 1, within: 5.minutes`). A refusal returns 429 with `Retry-After` and `{ error: { code: "throttled", message } }` for JSON requests, and redirects to the settings with an alert for HTML.
- It is reached only by a signed-in player, and has a Pundit policy.
- The file is `application/json`, named `gameble-export-YYYY-MM-DD.json`, and generated from current data at each request. Nothing is stored server-side.
- It carries no database id and no other player's identity (no persona name, token, steam id, friend code or counterparty). It uses card slugs plus season numbers, set kind/key, pack tokens, dates and weeks.
- Contents:
  - **profile:** steam id, persona name, visibility, reduced motion, own friend code, account creation date, last seen;
  - **collection:** card slug, season number, title, quantity, last gained;
  - **packs:** token, kind, season number, available at, opened at, card slugs;
  - **daily bonus days**, **goal reward weeks** and **weekly contributions** (week, openings);
  - **set completions:** kind/key, completed at;
  - **first discoveries:** card, date;
  - **own feed entries:** kind, card, occurred at;
  - **friends**, **pending invitations** (received and sent) and **trades**: counts only, plus each trade's status, dates and the player's own offered cards;
  - **reports filed:** reason and date.
- All copy lives in `en.yml` and `fr.yml`. The privacy notice's access bullet now points to EXPORTER in the settings.

**Never:**
- No background job, no stored export file and no e-mail.
- No event-store dump.
- No data a player received from or about another player beyond counts: no reports against the player, no trade request side, no friend list.
- No GET that writes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Export | signed-in player with holdings, packs, a trade and a friend | 200 attachment JSON with every section; friend and trade counterpart absent | No error expected |
| Empty player | new player, nothing held | 200 JSON with empty sections | No error expected |
| Other player isolation | two players with distinct data | A's file holds none of B's cards, packs, name, token or code | No error expected |
| Second request | same player within 5 minutes | 429 (JSON) or redirect with alert (HTML) | throttled message |
| Visitor | signed out | refused like other player-only actions | Pundit refusal |

</intent-contract>

## Code Map

- `config/routes.rb:64-69` -- settings routes and `resource :account, only: :destroy`. Add `resource :data_export, only: :create, path: "settings/export"` in the locale scope.
- `app/controllers/accounts_controller.rb` + `app/policies/account_policy.rb` (`destroy? = player?`) -- the model for the new `DataExportsController#create` and `DataExportPolicy#create? = player?`.
- `app/controllers/packs_controller.rb:100-109` (`throttled`, JSON 429 with `Retry-After`) and `rate_limit … by: -> { current_player&.id || request.remote_ip }` elsewhere -- reuse the pattern. `test/support/counting_rate_limit.rb` (`with_counting_rate_limit(Controller)`) makes limits count in tests, because the test cache is `:null_store`.
- New queries, `self.call(player)`, returning plain `Data` rows with no ids of other players:
  - `packs/accounts/app/queries/accounts/export_of.rb` -- the profile fields and the reports filed (reason, created_at).
  - `packs/game/app/queries/game/export_of.rb` -- holdings (`card_season_id`, quantity, last_gained_at), packs, daily bonus claims, goal rewards, weekly contributions, set completions (via the set's kind/key from Catalog), first discoveries, own feed entries, friend code, and the counts of friends and pending invitations. Trades come from `game_trades` + `game_trade_items` (side `offer` from the player's perspective only: as proposer the `offer` side, as recipient the `request` side), with status, proposed_at and closed_at.
  - Existing queries to reuse inside them where they fit: `Game::HeldCopies`, `Game::FriendCodeOf`, `Game::FriendsOf` (count only).
- `Catalog::CardViews.call(ids, locale:)` (`packs/catalog/app/queries/catalog/card_view.rb:13`, `CardView#id` is the slug) -- maps card_season ids to slug, season number and title in the web layer.
- `app/models/player_export.rb` -- the new web-layer assembler. `PlayerExport.new(player, locale:).to_h` combines the queries and the card views into the JSON hash, with camelCase keys like `PacksHelper#pack_opening_json`. `app/models/` already holds web-layer POROs (`player_stream.rb`).
- `app/views/settings/show.html.erb` -- add the "MES DONNÉES" row (label + EXPORTER secondary small button in a `form_with url: settings_export_path, method: :post, data: { turbo: false, controller: "data-export" }`) after SESSION and before COMPTE, per DESIGN.md:829. Update the header comment's "Export … come with their own stories".
- `test/controllers/settings_controller_test.rb:37,38,67` -- the row count and label lists gain "Mes données" / "My data".
- `app/frontend/controllers/data_export_controller.ts` (new) -- intercepts submit and `fetch`es the POST with the CSRF meta token and `Accept: application/json` (precedent: `collection_seen_controller.ts:22-31`). While it runs, the button is disabled and reads PRÉPARATION…. On 200, it reads the blob and builds an object URL, then dispatches `gameble:toast` with the title "EXPORT PRÊT" and a download action. On failure (non-2xx or network), it restores the button, now reading RÉESSAYER, and fills an inline `role="alert"` message from the error JSON or a generic text. It revokes the object URL when the toast is dismissed or after the toast duration.
- `app/frontend/lib/events.ts:9-13` -- `ToastDetail` gains an optional `action?: { label: string; href: string; download?: string }`.
- `app/frontend/controllers/toast_controller.ts`, `app/components/toast_component.rb` (+ its template), `app/views/shell/_toasts.html.erb` -- the toast renders an optional action link (`download` attribute when given) from the event. Server toasts are unchanged.
- `config/locales/{en,fr}.yml` -- the settings row (`data.label`, `data.export`, `data.preparing`, `data.retry`, `data.failed`), the toast (`data.ready_title`, `data.download`), the throttle message, and `pages.legal.privacy.rights.access_html` / `access_publisher`, which become one bullet pointing to EXPORTER in the settings (the contact e-mail stays in the publisher section).

## Tasks & Acceptance

**Execution:**
- [ ] `packs/accounts/app/queries/accounts/export_of.rb` + test -- profile and reports filed -- the Accounts half.
- [ ] `packs/game/app/queries/game/export_of.rb` + test -- the Game half, own data only, with counts for friends and invitations -- the Game half.
- [ ] `app/models/player_export.rb` + `test/models/player_export_test.rb` -- assemble the JSON with slugs and tokens, no ids; cover the matrix rows "Export", "Empty player" and "Other player isolation" (assert neither the other player's token, name, code nor any database id appears) -- the export body.
- [ ] `config/routes.rb`, `app/controllers/data_exports_controller.rb`, `app/policies/data_export_policy.rb` + tests -- POST with `send_data`, the rate limit and its JSON or HTML refusal -- the endpoint.
- [ ] `app/views/settings/show.html.erb`, `app/frontend/styles/settings.css` (only if the row needs it), `test/controllers/settings_controller_test.rb` -- the MES DONNÉES row -- entry point.
- [ ] `app/frontend/controllers/data_export_controller.ts`, `app/frontend/lib/events.ts`, `toast_controller.ts`, `toast_component.rb`, `_toasts.html.erb` + vitest for the controller's state changes where practical -- PRÉPARATION…, EXPORT PRÊT toast with download, inline failure with retry.
- [ ] `config/locales/{en,fr}.yml` -- the copy and the privacy notice's access bullet; update `test/controllers/pages_controller_test.rb` for the changed bullet.
- [ ] `test/system/settings_test.rb` -- export from the settings: the button reads PRÉPARATION… then the EXPORT PRÊT toast shows a download link; use retrying matchers.

**Acceptance Criteria:**
- Given a signed-in player on the settings, when they press EXPORTER, then the button reads PRÉPARATION… and an "EXPORT PRÊT" toast offers a `gameble-export-<date>.json` download holding their own data.
- Given the export failed (server error or throttled), when the response arrives, then the row says so inline and the button offers a retry.
- Given JavaScript is off, when the player submits EXPORTER, then the browser receives the JSON as an attachment.
- Given the legal page, when a reader looks at the access right, then it points to EXPORTER in the settings.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

The export is synchronous because a player's data is small (at most a few thousand holdings) and the architecture puts the assembly in the web layer. A job and a stored file would add a write path and a retention question for no gain. Defaults the author may change before implementation: JSON only (no CSV), a limit of 1 per 5 minutes, and counts instead of identities for friends, invitations and trade counterparties.

## Verification

**Commands:**
- `bin/rails test` -- expected: green
- `bin/rails test:system test/system/settings_test.rb` -- expected: green
- `npm run test:js` and `npm run typecheck` (if defined) -- expected: green
- `bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: nothing reported
- `bin/rubocop`, `bundle exec packwerk check`, `bin/rails zeitwerk:check` -- expected: clean

## Auto Run Result

Status: ready-for-dev. The run halted after planning at the author's request (2026-10-08). The author confirms the export's contents (the Always list) against the privacy notice before implementation.
