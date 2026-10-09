---
title: 'The publisher named, a banned player told why, the legal page linked from every page'
type: 'feature'
ticket: '24'
created: '2026-10-09'
status: 'built'
baseline_revision: '5ba943c832e3872ce3416166502b22acd7b79687'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** After the legal review of 2026-10-09 the author decided: the privacy notice must name the data controller (Thomas Eyermann, reachable at the contact address); a banned player who tries to sign in only reads "Ce compte a été suspendu." and never learns the reason the moderator typed nor where to contest it, and the moderator is not told the player will read it; the legal page is reachable only from the settings and the public card footer. The sign-in panel also says one "accepts" the privacy notice.

**Approach:** A controller line at the top of the privacy section; the sign-in callback answers a banned player with a "Compte suspendu" page (status 403, rendered in place, nothing stored) showing the reason of their current ban, read through a new Accounts query by the Steam id the callback already holds, and the contact; a hint under every ban field; a « Mentions légales » link inside the fixed version label of the layout; the sign-in panel's line reworded.

## Boundaries & Constraints

**Always:** the reason is user content, rendered with ERB escaping only (never `html_safe`/`raw`); the banned page carries no player id, token or Steam id; the session is left as it was (no flash, no reset, no player id); the contact is `mail_to(contact_email, class: "legal__link")` when `config.x.legal.contact_email` is set, else `t("pages.legal.contact_fallback")`, through one helper shared by the legal page and the banned page; the version label keeps clearing the hub's LIVE ticker on desktop and phone and stays non-interactive itself (only the link takes the pointer); every string in `fr.yml` and `en.yml`; no `style` attribute; no planning ids or French outside `fr.yml`; no comments explaining code (AGENTS.md); retrying Capybara matchers; any window resize restored.

**Never:** a postal address or any other identity line in the publisher section (`publisher.anonymous` stays as it is); retention periods; host lines; changing `BanPlayer`, the moderation table or the reason rules; putting the reason in the flash or the session cookie (a 500-character reason of `<` or `&` escapes to ~3 KB of JSON and would overflow the 4 KB session cookie); a new route or a GET that looks a ban up by a parameter; changing `settings.show.legal` / `cards.show.legal` links.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Banned with reason | banned player (ban row reason "Insults in the name"), origin `/fr`, contact set | 403 page "Compte suspendu": lead "Ce compte a été suspendu. Vous ne pouvez plus vous connecter.", label "Motif indiqué par le modérateur", the reason, "Pour contester cette décision, écrivez à <mailto link>." | session unchanged, no player signed in |
| Reason with markup | reason `<b>x</b> & co` | shown as literal text, no `<b>` element | none |
| Old ban | banned, latest ban row has NULL reason, or no ban row at all | no reason block; "Pour connaître le motif de cette suspension ou la contester, écrivez à <contact>." | none |
| Banned again | ban (reason A), unban, ban (reason B) | reason B | none |
| Console ban after an unban | latest of ban/unban rows is `unban` while `banned_at` set | treated as old ban (contact only) | none |
| Contact unset | no `LEGAL_CONTACT_EMAIL`, English origin | "…write to the publisher." no `mailto:` | none |
| Legal page controller | `GET /fr/legal`, contact set / unset | privacy section opens with "Le responsable du traitement de vos données est Thomas Eyermann, éditeur de gameble, joignable à <mailto>." / "… éditeur de gameble." | none |
| Version label link | any page (hub signed in/out, back-office, public card, legal), desktop and phone | "Mentions légales" / "Legal notice" link to `/<locale>/legal` beside the version | none |
| Ban form | queue and players list rows with a ban form | hint "Le joueur lira cette raison s'il tente de se connecter." under the field, the field `aria-describedby` it | none |
| Sign-in panel | signed-out visitor, fr / en | "En vous connectant, vous acceptez les conditions d'utilisation et prenez connaissance de la politique de confidentialité." / "By signing in you accept the terms of use and acknowledge the privacy notice." with the same two anchors | none |

</intent-contract>

## Code Map

- `app/controllers/sessions_controller.rb#create` -- after `result = sign_in(...)`, a `Failure(:banned)` renders `sessions/banned` with `status: :forbidden` (a private method, e.g. `refuse_banned(steam_id)`, setting `@ban_reason = Accounts::CurrentBanReason.call(steam_id)`); other failures keep `fail_sign_in`. The callback runs inside the origin's locale (`requested_locale`); `authorize :session` already ran; `skip_around_action :read_only_unless_writing` applies (reads only here).
- `packs/accounts/app/queries/accounts/current_ban_reason.rb` (new) -- `Accounts::CurrentBanReason.call(steam_id)` → String or nil: nil unless `steam_id` is a String and the player with it is banned; latest `ModerationAction` of kinds `ban`/`unban` for that player ordered `created_at: :desc, id: :desc`; its `reason` when it is a `ban`. Pattern: `packs/accounts/app/queries/accounts/moderation_history.rb`, model `packs/accounts/app/models/accounts/moderation_action.rb`. No comments (newer files have none).
- `app/views/sessions/banned.html.erb` (new) -- `content_for :title` "Compte suspendu", `noindex` meta like `app/views/public_profiles/unavailable.html.erb`; `section.account-suspended` with `h1`, a `PanelComponent` holding the lead (`t("errors.accounts.banned")`), when `@ban_reason`: label `p` + `blockquote.account-suspended__reason`, then the contest line (`sessions.banned.contest_html` or `no_reason_html`, `contact:` from the helper).
- `app/helpers/` -- add `legal_contact` (e.g. in a new `legal_helper.rb`, or `external_links_helper.rb`), reading `Rails.configuration.x.legal.contact_email`; `app/views/pages/legal.html.erb` line 4 uses it (behaviour unchanged).
- `app/views/pages/legal.html.erb` -- first paragraph of the privacy section: `p.legal__controller` with `privacy.controller_html` (contact set) or `privacy.controller` (unset), like the `access_html`/`access_publisher` pair.
- `app/frontend/styles/settings.css` -- `.account-suspended*` beside the `.legal` block (column, gap, max-width 640px centred like `.profile-unavailable` in `profile.css:114`; reason on `--color-panel-sunken`, `overflow-wrap: anywhere`; label muted `--font-label` uppercase). Tokens only.
- `app/views/shell/_version.html.erb` -- becomes `div.app-version` holding `p.app-version__tag` (title, visually hidden label, `shell_version`) and `link_to t("shell.version.legal"), legal_path, class: "app-version__legal"`. Rendered by `app/views/layouts/application.html.erb` on every page (back-office, public card page included).
- `app/frontend/styles/shell.css:734-745` `.app-version` -- keep position/z-index/bottom rules on the wrapper (and the ticker lifts at l.540 and 1365-1375 untouched); wrapper `display: flex; align-items: baseline; gap`, `pointer-events: none`; `.app-version__tag` `margin: 0; user-select: none`; `.app-version__legal` `pointer-events: auto`, dim colour, underline, hover `--color-text-bright` or accent, visible `:focus-visible` ring as other shell links.
- `app/views/back_office/bans/_ban_action.html.erb` -- `p.ban-form__hint` with id `ban-reason-hint-#{player.token}` after the field; field `aria: { describedby: }`. `app/frontend/entrypoints/application.css:89-116` -- `.ban-form__hint` (`flex-basis: 100%`, `margin: 0`, muted, `--font-label`).
- `config/locales/fr.yml` / `en.yml` -- `shell.sign_in_panel.acceptance_html|terms|privacy` (fr 51-53, en 50-52); `shell.version.legal`; `pages.legal.privacy.controller_html|controller`; `sessions.banned.title|reason_label|contest_html|no_reason_html`; `back_office.bans.actions.reason_hint`.
- Tests to update: `test/controllers/sessions_controller_test.rb:308` (banned now 403 page, no flash); `test/integration/shell_test.rb:74` (panel text); `test/controllers/pages_controller_test.rb:57` (`body > p.app-version` becomes the wrapper); `test/system/hub_test.rb:207-208` (panel text; `click_on "terms of use"`); `test/system/moderation_test.rb:56` (the reported player now reads the reason); `test/system/settings_test.rb:189` and `share_card_test.rb:132` are already scoped (check they still pass).

## Tasks & Acceptance

**Execution:**
- [x] `packs/accounts/app/queries/accounts/current_ban_reason.rb`, `test/packs/accounts/current_ban_reason_test.rb` -- the query and its cases (reason, NULL reason, no row, re-ban, unban newest, not banned, unknown/non-String steam id)
- [x] `app/controllers/sessions_controller.rb`, `app/views/sessions/banned.html.erb`, the `legal_contact` helper, `app/frontend/styles/settings.css` -- the banned page
- [x] `app/views/pages/legal.html.erb` -- the controller line
- [x] `app/views/shell/_version.html.erb`, `app/frontend/styles/shell.css` -- the legal link beside the version
- [x] `app/views/back_office/bans/_ban_action.html.erb`, `app/frontend/entrypoints/application.css` -- the hint
- [x] `config/locales/fr.yml`, `config/locales/en.yml` -- the copy of Design Notes
- [x] `test/controllers/sessions_controller_test.rb` -- matrix rows banned/markup/old ban/re-ban/contact unset (English); session unchanged; body has no player token, id or steam id
- [x] `test/controllers/pages_controller_test.rb` -- controller line with and without contact; version wrapper and its link on the hub signed out and signed in (fr and en hrefs)
- [x] `test/integration/shell_test.rb` -- panel text; the version's legal link on a back-office page and on the public card page
- [x] `test/controllers/back_office/bans_controller_test.rb` (or where the form is asserted) -- hint present and referenced on the queue and the players list
- [x] `test/system/moderation_test.rb` -- the banned player reads "Insults in the name" and the contest line; `test/system/hub_test.rb` -- the version's link clears the ticker (existing rects) and, on a phone (restore size), a visitor taps "Mentions légales" and lands on `/fr/legal`; signed in on desktop the link leads to the legal page

**Acceptance Criteria:**
- Given a moderator who banned a player with a reason, when that player signs in with Steam, then they see the reason and the contact address and are not signed in.
- Given any page signed in or out, desktop or phone, when the visitor follows « Mentions légales » beside the version, then the legal page of their locale opens.
- Given the suite, when the verification commands run, then all pass.

## Implementation Notes

- The ban hint sits after the submit button inside the wrapping `.ban-form`, so `flex-basis: 100%` puts it on its own row under the field and button instead of pushing the button to a third row.
- `test/controllers/authorization_test.rb` asserted the old redirect and flash for a banned sign-in (from a live session, and after a moderator's ban); both now assert the 403 page (the lead, the reason "Cheating") and, for the live session, that the player id leaves the session and the page shows the visitor's top bar.
- The query also has cases for a dismissal after the ban (the reason stays) and two rows at the same time (the later id wins).

## Plan Change Log

## Review Triage Log

### 2026-10-09 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` (quick) The "Mentions légales" link takes the pointer, so content scrolled under the fixed bottom-left corner cannot be clicked there — real, but the ticket puts a link beside the fixed version label, so the link must sit above the content. The area is about one line of label text. At the end of a page, `.main`'s bottom padding (40px on desktop) leaves that corner empty. Reserving the corner on every page would be a layout change beyond a direct correction. All 174 system tests pass.
  - `[low]` `[reject]` (quick) Signing in again from the banned page sends `origin: /auth/steam/callback`, which `ORIGIN_PATH` rejects, so the retry falls back to the default locale and the hub — real, but only a banned player retrying from the refusal page meets it, and the retry refuses them again. The fix needs a new way to carry the origin into the shell's sign-in forms (more than a direct correction).
  - `[low]` `[patch]` (quick) `app/views/shell/_version.html.erb` extended an explanatory ERB comment ("beside the legal page"), against AGENTS.md — the comment is back to its original wording. The diff no longer touches it.

## Design Notes

Why render in place rather than a toast: the toast region reads the flash, which lives in the 4 KB cookie session; the reason is up to 500 characters and the cookie JSON escapes `<`, `>` and `&` to six bytes each, so a pathological reason would raise `CookieOverflow` on the callback. A page also keeps the reason and a working `mailto:` on screen. A reload of the callback re-runs OpenID and fails as today ("La connexion a échoué"), which is acceptable.

**French:**
- `sessions.banned.title`: Compte suspendu
- `sessions.banned.reason_label`: Motif indiqué par le modérateur
- `sessions.banned.contest_html`: Pour contester cette décision, écrivez à %{contact}.
- `sessions.banned.no_reason_html`: Pour connaître le motif de cette suspension ou la contester, écrivez à %{contact}.
- `pages.legal.privacy.controller_html`: Le responsable du traitement de vos données est Thomas Eyermann, éditeur de gameble, joignable à %{contact}.
- `pages.legal.privacy.controller`: Le responsable du traitement de vos données est Thomas Eyermann, éditeur de gameble.
- `shell.version.legal`: Mentions légales
- `back_office.bans.actions.reason_hint`: Le joueur lira cette raison s'il tente de se connecter.
- `shell.sign_in_panel.acceptance_html`: En vous connectant, vous acceptez les %{terms} et prenez connaissance de la %{privacy}. — `terms`: conditions d'utilisation — `privacy`: politique de confidentialité

**English:** "Account suspended"; "Reason given by the moderator"; "To contest this decision, write to %{contact}."; "To learn the reason for this suspension or contest it, write to %{contact}."; "The controller of your data is Thomas Eyermann, publisher of gameble, reachable at %{contact}." / "… publisher of gameble."; "Legal notice"; "The player will read this reason if they try to sign in."; "By signing in you accept the %{terms} and acknowledge the %{privacy}." — "terms of use" — "privacy notice".

## Verification

Environment for every command: `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w724 CHROME_BIN=/usr/bin/chromium`, from `/home/teyermann/projets/gameble/.claude/worktrees/agent-a83bb7838b2953ec3`.

**Commands:**
- `bin/rails test` -- expected: 0 failures, 0 errors
- `bin/rails test:system TEST="test/system/moderation_test.rb test/system/hub_test.rb test/system/shell_test.rb test/system/settings_test.rb test/system/share_card_test.rb test/system/public_profile_test.rb"` -- expected: green
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

Status: built.

**Summary:**
- **Data controller:** the privacy notice now opens by naming Thomas Eyermann as data controller. The line carries the contact `mailto:` link when one is set, and names him without a contact otherwise. The publisher section is unchanged.
- **Banned sign-in:** the Steam callback now answers a banned player with a "Compte suspendu" page (403), rendered in place. It writes no flash, no session change and no id. The page shows the reason of the current ban, escaped, and the contact to contest it. A ban with no recorded reason, or a console ban after an unban, shows the contact only. `Accounts::CurrentBanReason` reads the reason by the Steam id the callback already holds.
- **Ban form:** every ban form now tells the moderator that the player will read the reason.
- **Legal link:** a "Mentions légales" / "Legal notice" link sits inside the fixed version label on every page, signed in and out, desktop and phone, back-office and public card page included. The version label still clears the hub's LIVE ticker.
- **Sign-in panel:** the line now reads "…vous acceptez les conditions d'utilisation et prenez connaissance de la politique de confidentialité." / "By signing in you accept the terms of use and acknowledge the privacy notice."

**Files changed:**
- `packs/accounts/app/queries/accounts/current_ban_reason.rb`: the reason of the current ban.
- `app/controllers/sessions_controller.rb`, `app/views/sessions/banned.html.erb`, `app/helpers/legal_helper.rb`, `app/frontend/styles/settings.css`: the banned page and the shared contact helper.
- `app/views/pages/legal.html.erb`: the controller line, and the page now uses the shared helper.
- `app/views/shell/_version.html.erb`, `app/frontend/styles/shell.css`: the legal link beside the version.
- `app/views/back_office/bans/_ban_action.html.erb`, `app/frontend/entrypoints/application.css`: the hint under the ban field.
- `config/locales/{fr,en}.yml`: the new copy.
- Tests: `test/packs/accounts/current_ban_reason_test.rb` (new); `test/controllers/{sessions,pages,authorization}_controller_test.rb`, `test/controllers/back_office/bans_controller_test.rb`, `test/integration/shell_test.rb`, `test/system/{moderation,hub}_test.rb`.

**Review findings:** a quick review reported 3 findings, all low.
- Patched 1: an ERB comment had been extended, against AGENTS.md; it is back to its original wording.
- Deferred: none.
- Rejected 2:
  - The link takes clicks in the bottom-left corner. This is inherent to placing a link beside the fixed version label.
  - A retry from the banned page loses the origin's locale. Only a banned player retrying meets it, and the retry refuses them again.

**Follow-up review recommended:** false. Patched: high 0, medium 0, low 1.

**Verification:** commands were run with `DATABASE_URL=…/gameble_test_w724`.
- `bin/rails test`: 2087 runs, 0 failures.
- `bin/rails test:system`: 174 runs, 0 failures.
- `npm run test:js`: 210 passed.
- `zeitwerk:check`, `packwerk check`, `rubocop` (636 files), `i18n-tasks missing` and `i18n-tasks unused`: all clean.
- After the comment patch: `pages_controller_test` and `integration/shell_test`, 59 runs, 0 failures.

**Residual risks / for the author:**
- **Anonymity contradiction:** the publisher section still says the publisher "a choisi de rester anonyme", while the privacy notice now names him.
- **Stale legal lines:** `terms.moderation_html` and `privacy.rights.banned_html` still say a suspended player can ask for the reason. That stays true for old bans, but they do not say the reason is now shown at sign-in.
- **Small tap target:** on phones, the legal link is small label text.
- **Reload:** reloading the banned page re-runs OpenID and shows "La connexion a échoué".
