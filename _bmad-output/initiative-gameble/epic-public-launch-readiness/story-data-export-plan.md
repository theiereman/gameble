---
title: 'Data export'
type: 'feature'
ticket: '7'
created: '2026-10-08'
status: done
baseline_revision: 'a2d729261632006dbffd868554482f19a424b45c'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
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
  - **packs:** token, kind, season number, card back, available at, opened at, card slugs;
  - **daily bonus days**, **goal reward weeks** and **weekly contributions** (week, openings);
  - **set completions:** kind/key, completed at;
  - **first discoveries:** card, date;
  - **own feed entries:** kind, card, occurred at (a trade entry gives only the player's own card, never the partner or the partner's card);
  - **achievements:** achievement, unlocked at;
  - **friends**, **pending invitations** (received and sent) and **trades**: counts only, plus each trade's status, dates and the player's own offered cards;
  - **reports filed:** reason and date;
  - **reports received:** reason, date and handled date, never the reporter;
  - **moderation decisions concerning the player:** kind (ban, unban, dismissal), date and reason, never the staff member.
- All copy lives in `en.yml` and `fr.yml`. The privacy notice's access bullet now points to EXPORTER in the settings.

**Never:**
- No background job, no stored export file and no e-mail.
- No event-store dump.
- No identity of another player: no reporter, no staff member, no trade partner or partner card, no trade request side, no friend list; friends, invitations and trade counterparts are counts only.
- No GET that writes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Export | signed-in player with holdings, packs, a trade and a friend | 200 attachment JSON with every section; friend and trade counterpart absent | No error expected |
| Empty player | new player, nothing held | 200 JSON with empty sections | No error expected |
| Other player isolation | two players with distinct data | A's file holds none of B's cards, packs, name, token or code | No error expected |
| Second request | same player within 5 minutes | 429 (JSON) or redirect with alert (HTML) | throttled message |
| Moderated player | player reported by B, banned then unbanned by staff S | reports received and decisions with reason and dates; neither B's nor S's name, token or steam id | No error expected |
| Visitor | signed out | refused like other player-only actions | Pundit refusal |

</intent-contract>

## Code Map

- `config/routes.rb:64-69` -- settings routes and `resource :account, only: :destroy`. Add `resource :data_export, only: :create, path: "settings/export"` in the locale scope.
- `app/controllers/accounts_controller.rb` + `app/policies/account_policy.rb` (`destroy? = player?`) -- the model for the new `DataExportsController#create` and `DataExportPolicy#create? = player?`.
- `app/controllers/packs_controller.rb:100-109` (`throttled`, JSON 429 with `Retry-After`) and `rate_limit … by: -> { current_player&.id || request.remote_ip }` elsewhere -- reuse the pattern. `test/support/counting_rate_limit.rb` (`with_counting_rate_limit(Controller)`) makes limits count in tests, because the test cache is `:null_store`.
- New queries, `self.call(player)`, returning plain `Data` rows with no ids of other players:
  - `packs/accounts/app/queries/accounts/export_of.rb` -- the profile fields, the reports filed (reason, created_at), the reports received (`Accounts::Report` where `reported_id`: reason, created_at, handled_at) and the moderation decisions (`Accounts::ModerationAction` where `player_id`: kind, created_at, reason), never `reporter_id` or `staff_id`.
  - `packs/game/app/queries/game/export_of.rb` -- holdings (`card_season_id`, quantity, last_gained_at), packs, daily bonus claims, goal rewards, weekly contributions, set completions (via the set's kind/key from Catalog), first discoveries, own feed entries (never `partner_id` or `partner_card_season_id`), achievement unlocks (`Game::AchievementUnlock`: achievement, unlocked_at), each pack's `card_back`, friend code, and the counts of friends and pending invitations. Trades come from `game_trades` + `game_trade_items` (side `offer` from the player's perspective only: as proposer the `offer` side, as recipient the `request` side), with status, proposed_at and closed_at.
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
- [x] `packs/accounts/app/queries/accounts/export_of.rb` + test -- profile and reports filed -- the Accounts half.
- [x] `packs/game/app/queries/game/export_of.rb` + test -- the Game half, own data only, with counts for friends and invitations -- the Game half.
- [x] `app/models/player_export.rb` + `test/models/player_export_test.rb` -- assemble the JSON with slugs and tokens, no ids; cover the matrix rows "Export", "Empty player", "Other player isolation" and "Moderated player" (assert neither the other player's token, name, code nor any database id appears) -- the export body.
- [x] `config/routes.rb`, `app/controllers/data_exports_controller.rb`, `app/policies/data_export_policy.rb` + tests -- POST with `send_data`, the rate limit and its JSON or HTML refusal -- the endpoint.
- [x] `app/views/settings/show.html.erb`, `app/frontend/styles/settings.css` (only if the row needs it), `test/controllers/settings_controller_test.rb` -- the MES DONNÉES row -- entry point.
- [x] `app/frontend/controllers/data_export_controller.ts`, `app/frontend/lib/events.ts`, `toast_controller.ts`, `toast_component.rb`, `_toasts.html.erb` + vitest for the controller's state changes where practical -- PRÉPARATION…, EXPORT PRÊT toast with download, inline failure with retry.
- [x] `config/locales/{en,fr}.yml` -- the copy and the privacy notice's access bullet; update `test/controllers/pages_controller_test.rb` for the changed bullet.

**Acceptance Criteria:**
- Given a signed-in player on the settings, when they press EXPORTER, then the button reads PRÉPARATION… and an "EXPORT PRÊT" toast offers a `gameble-export-<date>.json` download holding their own data.
- Given the export failed (server error or throttled), when the response arrives, then the row says so inline and the button offers a retry.
- Given JavaScript is off, when the player submits EXPORTER, then the browser receives the JSON as an attachment.
- Given the legal page, when a reader looks at the access right, then it points to EXPORTER in the settings.

## Implementation Notes

- A pack not opened yet is listed without its cards or card back, so the export never spoils an upcoming booster.
- After a successful export, the row keeps a TÉLÉCHARGER link to the file while the page stays open, beside the EXPORT PRÊT toast's link, so closing the toast loses nothing (author, 2026-10-14); toasts keep their usual timer. An export failure is shown inline and in an alert toast; the data-export controller revokes its object URL on a new export and on disconnect. Toast actions accept only `blob:` URLs and site paths. The legal page's update date moves to 14 October 2026 for the access bullet.
- The time of a player's last export is kept in `accounts_players.last_exported_at`, written by `Accounts::NoteExport` (housekeeping, no event) when the file is built, erased by `Accounts::DeletePlayer`, shown under EXPORTER and TÉLÉCHARGER as "Dernier export : 04/10/2026 à 07:05 UTC" (server-rendered, then filled by the script from the file's `exportedAt` with the same locale pattern), and exported as `profile.lastExportedAt`. The privacy notice's stored data, its deletion paragraph and the delete dialog name it.
- The last export's file is kept server-side in `accounts_data_exports` (one row per player, replaced by the next export, erased by `Accounts::DeletePlayer`), written with the time by `Accounts::RecordExport`; TÉLÉCHARGER is a GET of `settings/export` serving it, read only, shown whenever an export exists. The limit is one export every 5 minutes after the last successful one (`Accounts::Player::EXPORT_INTERVAL`, checked on the locked row; a refusal is 429 with `Retry-After` and `nextExportAt`), replacing the Rails rate limit: until then EXPORTER is disabled with "Prochain export : …" below and re-enabled by the script, and a refusal brings no toast. Two simultaneous requests seen in development came from the app's JavaScript running twice after Vite's start, not from the page.
- Set completions also carry the set's season number, since a set key is unique only within its season and kind.
- Weekly contributions carry week and openings only, as listed; the `trades` counter of the same row is left out.
- The privacy notice's access bullet is one plain key (`access`), the same for every configuration; its "last updated" date was not changed.

## Plan Change Log

- 2026-10-14, author: the export also holds the reports received (reason, dates) and the moderation decisions concerning the player (kind, date, reason), without the reporter or the staff member, since the privacy notice lists them among stored data; achievements and each pack's card back are added as the player's own data; trade feed entries drop the partner. The system test task is dropped: system tests are disabled and new ones are not added.
- 2026-10-14, author: TÉLÉCHARGER sits beside EXPORTER, and the time of the last export is stored and shown below them, so the export's file stays the only thing not kept server-side.
- 2026-10-14, author: TÉLÉCHARGER stays available after leaving the page, so the last export's file is kept server-side until the next export or the account's deletion; this reverses "Nothing is stored server-side" and "no stored export file".

## Review Triage Log

| # | Finding | Verdict | Route | Evidence |
|---|---------|---------|-------|----------|
| 1 | A retry right after a server or network failure is throttled for 5 minutes | low | rejected | `rate_limit` counts in a before_action, so a failed export uses the slot; a 500 in the export is a bug and a dropped blob read is rare, and avoiding it means counting by hand after success, more than a direct correction. |
| 2 | The export is lost when its toast closes on its own after about 7 s | medium | patch | The toast timer closes it, `gameble:toast-dismissed` revokes the object URL, and the row offers no other download while the limit refuses a new export. |
| 3 | A failure is shown inline only, without a toast | low | patch | EXPERIENCE.md's Toast and "Network or server error" rows require inline and a toast; `fail()` dispatches nothing. |
| 4 | `toastActionHref` accepts `/\evil.example/` | low | patch | Browsers read a leading `/\` as `//`; only the export's own blob URL reaches it today, the fix is one character class. |
| 5 | The new comment on `ToastComponent`'s `action:` paraphrases the parameter | low | patch | AGENTS.md allows only external-constraint comments; deleting it is the fix. The other comment additions extend existing blocks and are kept. |
| 6 | A test name says a waiting pack keeps its cards while it asserts they are hidden | low | patch | `test/packs/game/export_of_test.rb` asserts `[ waiting.token, nil, nil, [] ]`. |

## Design Notes

The export is synchronous because a player's data is small (at most a few thousand holdings) and the architecture puts the assembly in the web layer. A job and a stored file would add a write path and a retention question for no gain. Defaults the author may change before implementation: JSON only (no CSV), a limit of 1 per 5 minutes, and counts instead of identities for friends, invitations and trade counterparties.

## Verification

**Commands:**
- `bin/rails test` -- expected: green
- `npm run test:js` and `npm run typecheck` (if defined) -- expected: green
- `bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: nothing reported
- `bin/rubocop`, `bundle exec packwerk check`, `bin/rails zeitwerk:check` -- expected: clean

## Auto Run Result

Status: ready-for-dev. The run halted after planning at the author's request (2026-10-08). The author confirms the export's contents (the Always list) against the privacy notice before implementation.
