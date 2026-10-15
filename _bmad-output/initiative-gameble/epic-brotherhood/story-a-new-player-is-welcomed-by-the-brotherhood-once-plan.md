---
title: 'A new player is welcomed by the Brotherhood once'
type: 'feature'
ticket: '19'
created: '2026-10-15'
status: 'built'
baseline_revision: '758d704e606c265b82ea1dcdafcf744a34cd6ec4'
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

**Problem:** A new player lands on the hub with only the sign-in toast; the Brotherhood never introduces itself (spec CAP-26; EXPERIENCE.md, Hub "Welcome panel" and Copy deck "Welcome message").

**Approach:** A player row carries a `welcome_pending` flag, false for every existing row (the column's default) and set true by the sign-up itself. While it is true the hub shows, at its top, a panel with the welcome message and one closing button. The first real render of that panel enqueues a job that clears the flag, so it never shows again on any device; the button clears it at once and removes the panel. A sign-in that lands a pending player on the hub skips the welcome toast.

**Assumptions (author unavailable, conservative choice):**
- Existing players: the column is added `default: false, null: false` (no rewrite on Postgres 11+), so every row created before the release reads false without a backfill; only `Accounts::SignIn` creating a row sets true.
- "Shown once" means marked seen at its first display, not only when closed: the hub GET writes nothing and enqueues `Accounts::CloseWelcomeJob` (the same path as the last-seen job), skipped for a Turbo prefetch (`X-Sec-Purpose: prefetch`) so a hovered link never consumes it.
- The close button reads « Fermer » / "Close" (the Copy deck gives no label); it is a DELETE to `/:locale/welcome`, answered in Turbo Stream (panel removed, the focus moves to the hub's heading) or by a redirect to the hub without JavaScript.
- The sign-in toast is skipped only when the sign-in lands on the hub; an invite link's landing keeps it, and the panel waits for the hub. The focus after sign-in stays the documented one (first menu item; phone: the heading).
- A deleted account that signs up again is a new player and is welcomed. The flag is interface state, not personal data: not in the data export.

## Boundaries & Constraints

**Always:** GETs write nothing; the flag changes only through `Accounts::CloseWelcome` (housekeeping, no event) and the sign-up operation. Pundit policy for the new action. No database id in the DOM. Every string in `fr.yml` and `en.yml`, Copy deck text verbatim, French with U+202F before « : ; ? ! ». Panel style (`PanelComponent`), no modal, no animation, hub usable under it, phone and desktop.

**Never:** No change to any mechanic or to the bank. No planning ids in code. No `style` attribute.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| New player signs in | first sign-in | row `welcome_pending: true`; redirect to the hub without the welcome notice | none |
| First hub render | pending player GET hub | panel with title, four lines, « Fermer »; close job enqueued | none |
| Prefetch | same GET with `X-Sec-Purpose: prefetch` | panel rendered, no job | none |
| Later visit | flag cleared | no panel | none |
| Close | DELETE welcome | flag false; stream removes `#welcome-panel`; HTML redirects to the hub | visitor: refused, sign-in asked |
| Existing player | row from before | flag false: no panel, toast as before | none |

</frozen-after-approval>

## Code Map

- `db/migrate/20261015090000_add_welcome_pending_to_accounts_players.rb` -- new column; `db/schema.rb` gains its line only.
- `packs/accounts/app/operations/accounts/sign_in.rb` -- `create_or_find_by!(steam_id:) { it.welcome_pending = true }`: only a created row.
- `packs/accounts/app/operations/accounts/close_welcome.rb` (new) -- `call(player_id:)`, `update_all(welcome_pending: false)` on a player in good standing; like `note_last_seen.rb`.
- `packs/accounts/app/jobs/accounts/close_welcome_job.rb` (new) -- like `note_last_seen_job.rb`.
- `app/controllers/pages_controller.rb#home` -- `@welcome`, enqueue unless prefetch.
- `app/controllers/welcomes_controller.rb` (new), `app/policies/welcome_policy.rb` (new, `destroy? = player?`), `config/routes.rb` (`resource :welcome, only: :destroy` in the locale scope), `app/views/welcomes/destroy.turbo_stream.erb`.
- `app/controllers/sessions_controller.rb#create` -- notice only unless the pending player lands on the hub.
- `app/views/pages/_welcome.html.erb` (new), `app/views/pages/home.html.erb` -- rendered after the kicker header; h1 gets `id="hub-title"`.
- `app/frontend/controllers/welcome_controller.ts` (new) -- on a successful `turbo:submit-end`, focus `#hub-title`.
- `app/frontend/styles/hub.css` -- `.hub:has(> .hub-welcome)` adds a full-width top row in the three and two column grids; phone: `order: -1`.
- `config/locales/{fr,en}.yml` -- `pages.home.welcome.{title,founders,legacy,collection,wishes,close}`.

## Tasks & Acceptance

**Execution:**
- [x] migration, schema, `Accounts::SignIn`, `Accounts::CloseWelcome`, `Accounts::CloseWelcomeJob` -- the flag.
- [x] route, policy, `WelcomesController`, stream view -- the close.
- [x] `PagesController#home`, `_welcome` partial, `home.html.erb`, `hub.css`, `welcome_controller.ts`, locales -- the panel.
- [x] `SessionsController#create` -- no toast that time.
- [x] tests: `test/packs/accounts/sign_in_test.rb`, `close_welcome_test.rb`, `test/controllers/welcomes_controller_test.rb`, `pages_controller_test.rb`, `sessions_controller_test.rb`, `test/policies/welcome_policy_test.rb`.

**Acceptance Criteria:**
- Given a pending player, when the hub renders in fr or en, then the Copy deck's text shows in a section named by its title, with no database id.
- Given i18n-tasks, packwerk, zeitwerk and rubocop, when run, then they report nothing new.

## Implementation Notes

- Resumed 2026-10-15 after the container restarted mid-implementation: the files of the Code Map are mostly written but unverified and uncommitted in this worktree; read them, finish what is missing, then verify. Environment: `service postgresql start` if it is down, `export PATH=/opt/rbenv/versions/4.0.7/bin:$PATH DB_PORT=5432` (Postgres 16; regenerate `db/schema.rb` and keep only this migration's lines), system tests are disabled.

## Plan Change Log

- 2026-10-15, after review pass 1: the frozen assumption that a Turbo prefetch skips the close job let a hovered-then-clicked hub link show the panel without marking it seen (intent gap). The author chose (2026-10-15) to turn link prefetching off on every page while a welcome is pending (`turbo-prefetch` meta in the head), so every hub render that shows the panel is a real visit and enqueues the close job; the prefetch check in `PagesController#home` is gone. The frozen block still states the earlier assumption; only the author edits it.

## Review Triage Log

### 2026-10-15 — Review pass (quick)

- `medium` · intent_gap → resolved by the author: a hovered hub link was prefetched with `X-Sec-Purpose: prefetch`, skipped the close job, and a click reused that response, so the panel could show again (Turbo 8 reuses a prefetched response on click). Fixed by the author's choice: no prefetching while a welcome is pending; the test now checks the meta and its absence once closed.
- `low` · patch: a daily-countdown morph refresh after the close job ran would remove the panel under the reader; the panel is now `data-turbo-permanent`, so a morph keeps it until its button or the next visit.
- `low` · patch: new explanatory comments broke AGENTS.md's comment rule; removed from the new controller, policy, operation, partial, Stimulus controller, route and stylesheet. Updates to existing comment blocks (hub controller and view headers, sign-in operation) were kept so they stay accurate.

## Verification

**Commands:**
- `bin/rails test`, `npm run test:js`, `npm run typecheck` -- expected: pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: clean
- `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: nothing new
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` -- expected: `db/schema.rb` diff is the new column and the version only
