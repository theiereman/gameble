---
title: 'The account deletion dialog names everything it erases'
type: 'feature'
ticket: '48'
created: '2026-10-13'
status: 'built'
baseline_revision: 'd4bb544d9e4230af98367803ead0077e33a5dc53'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The delete dialog's note (`accounts.dialog.note`) says only that the collection, the boosters, the open trades and the profile are erased. Deletion does much more, and keeps some things on purpose. `Accounts::DeletePlayer` clears the Steam id, the name, the last-seen time and the profile token. `Game::ReleasePlayer`, through `Game::Handlers::PlayerDeleted` and `Game::DropFriendsAndTrades`, cancels the open trades and deletes the invitations, friendships, feed entries (the player's own pulls, discoveries, reposts and trades, plus the trades naming them as partner), daily bonus claims, goal rewards, packs, holdings, set completions, achievement unlocks, friend code and player state (latest activity). It keeps the past trades, the first discoveries (their pack forgotten), the weekly contributions, the reports, the moderation history and the event log, none of them carrying the Steam id or the name. Card backs hold no player data (`Game::CardBacks` is always `standard`), so the dialog names none.

**Approach:** Rewrite the note in fr and en so it names every kind of data that is erased and says that open trades are cancelled. Add a second line, `accounts.dialog.kept`, naming what stays without the Steam id or the name, followed by the irreversibility sentence. Render both in `app/views/accounts/_dialog.html.erb`, which the field's `aria-describedby` already points to. A request test pins the copy: every table with a foreign key to `accounts_players` is classified as erased or kept, the test fails if a table is unclassified, and it checks that each class's phrase appears in the dialog in both locales. Update the delete dialog row in EXPERIENCE.md.

</intent-contract>

## Implementation Notes

Oneshot: two locale keys per language, one view line, one test and one UX line, about 60 lines. The legal page's privacy notice (`legal.privacy.deletion`) is the author's text and is left alone. It omits achievements, completed sets, daily bonuses and goal rewards; that gap is reported to the author, not fixed here.

Done: `accounts.dialog.note` rewritten and `accounts.dialog.kept` added in `config/locales/fr.yml` and `config/locales/en.yml`; `app/views/accounts/_dialog.html.erb` renders the kept line as `#delete-dialog-kept`, which the field's `aria-describedby` also names. The pin test is in `test/controllers/accounts_controller_test.rb`: every table with a foreign key to `accounts_players`, plus the player row and the event log, sits in `ERASED_OR_CANCELLED` or `KEPT`; each phrase must appear in the right line in both locales, and a kept phrase never appears in the note. The delete dialog row in `EXPERIENCE.md` now describes both lines.

Surprise: the copy is about six times longer, and `.modal` sets `overflow: visible`, which turns off the browser's own scrolling of a modal dialog. On a short screen the field and buttons would have ended up off-screen. `app/frontend/styles/settings.css` now gives `.delete-dialog` a max height and its own scroll, padded by the corner brackets' offset so that `overflow-y: auto` does not clip them. On the phone the dialog takes the full height with no padding. This is outside the plan's file list, and it is needed for the longer copy.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 6 findings — high 0, medium 1, low 3, false 0, maybe-false 0; 2 rejected without a severity grade
- findings:
  - `[medium]` `[patch]` The scroll rule applied only below 720px wide. A short window that is wider than that, such as a landscape phone, still pushed the buttons off-screen. — `.delete-dialog` now scrolls at every width, with `max-height: calc(100dvh - 2 * var(--space-gutter-phone))` and padding equal to the corner brackets' offset. The phone keeps `100dvh` with no padding. The EXPERIENCE.md sentence now says "when the screen is too short for it".
  - `[low]` `[reject]` The CSS change and the EXPERIENCE.md sentence are not in the plan. — Fixing this means editing the plan, so it is rejected. The change is recorded under Implementation Notes.
  - `[low]` `[patch]` The rewritten comment blocks in `_dialog.html.erb` and `settings.css` kept their DESIGN.md and EXPERIENCE.md references and added narration. — The references and the added narration are removed. Both comments are back to their earlier wording.
  - `[low]` `[patch]` The comment above `ERASED_OR_CANCELLED` narrates the code. — Deleted.
  - `[low]` `[reject]` The anonymised `accounts_players` row stays, and the kept line does not say so. — What the row keeps is the role, visibility, motion preference and creation date. None of it identifies the player or is shown anywhere, and the dialog promises no erasure of any of it. The intent asks for what is erased to be named; saying that "your account" stays would contradict the dialog's own title. Rejected; mentioned to the author.
  - `[low]` `[patch]` The `aria-describedby` assertion ran only on the English page and was not scoped to the dialog. — It now runs inside the loop for both locales, scoped to `dialog#delete-dialog`.

## Verification

**Commands:**
- `bin/rails test test/controllers/accounts_controller_test.rb` -- expected: green, the pin test included
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing` -- expected: all green

## Auto Run Result

- Summary: the delete dialog now names everything deletion erases or cancels, in fr and en. A second line names what stays without the Steam id or the name and says the action cannot be undone. A request test ties the copy to every table that names a player. The dialog scrolls when the screen is too short.
- Files: `config/locales/fr.yml` and `config/locales/en.yml` (note rewritten, `kept` added); `app/views/accounts/_dialog.html.erb` (kept line, aria, scroll class); `app/frontend/styles/settings.css` (dialog scroll); `test/controllers/accounts_controller_test.rb` (pin test); `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` (delete dialog row).
- Review: 4 patches (1 medium, 3 low), 0 deferred, 2 rejected (plan scope: the fix would edit the plan; the anonymised account row: no identifying data, and the dialog promises nothing about it).
- Follow-up review recommended: false (one medium patched, no high).
- Verification: `bin/rails test` 2415 runs, 0 failures; `npm run test:js` 273 passed; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no violations; `bin/rubocop` no offenses; `bundle exec i18n-tasks missing` none missing. No system tests, per AGENTS.md.
- Residual risks: the dialog's scrolling was not checked in a browser. The legal page's deletion paragraph (`legal.privacy.deletion`, the author's text) still omits achievements, completed sets, daily bonuses and goal rewards.
