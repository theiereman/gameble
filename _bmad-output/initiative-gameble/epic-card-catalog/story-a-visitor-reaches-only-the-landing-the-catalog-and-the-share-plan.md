---
title: 'A visitor reaches only the landing, the catalog and the shared pages'
type: 'feature'
ticket: 8
created: '2026-10-20'
status: 'built'
baseline_revision: '63c56fa8d0a93cccf246d07ea823c8f32a6bfea2'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred: []
commit: 'f87b3f56baa7369d723d1c13cc3146f6e70e0f9a'
---

<intent-contract>

## Intent

**Problem:** A signed-out visitor still opens the signed-out hub, the collection entry (with 14.7's À DÉCOUVRIR), set albums, the feed and PLUS, and every action needing an account opens a sign-in panel. The author decided (2026-10-20) that a visitor reaches only the landing, Toutes les cartes and its card detail, the public card page, public profiles with their albums, and Comment ça marche; everything else leads to the landing, account actions show greyed and disabled, and the panel goes.

**Approach:** One shared mechanism: player-only pages authorize with `PagePolicy#play?` (`player?`), and `ApplicationController#refuse` sends a refused visitor's HTML request to the landing (303, no flash; JSON and other formats keep 401 `sign_in_required`). Every policy already denying visitors (trades, friends, achievements, settings, booster, packs…) inherits the landing redirect. Then strip the visitor branches those pages no longer need, retire the sign-in panel, turn the landing's "Embarquer sur le pont" into the Steam sign-in POST, and grey the remaining account actions.

## Boundaries & Constraints

**Always:** a signed-in player's pages, links and behaviour unchanged; the open pages keep `PublicRead`, `PublicReadThrottle`, `Cache-Control: private` and no database id; every string in both en.yml and fr.yml, unused ones removed (i18n-tasks unused clean); no `style` attribute; no planning ids in code/tests; comments that named the signed-out hub, the sign-in panel or a visitor's view of a now-closed page rewritten or removed.

**Never:** no new route, operation, event or Stimulus controller; do not change sign-in itself (`SessionsController#create` still lands on the hub, or on an invite link origin); do not touch the friendship action ticket's scope beyond the visitor's greyed ÉCHANGE; never run system tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open pages | visitor GET `/fr/landing`, `/en/library/cards`, `/fr/cards/:slug` (from the grid), public card page, `/fr/brothers/:token`, `/fr/brothers/:token/library/:kind/:key`, `/fr/how-it-works`, `/fr/legal`, `/fr/invite/:token` | 200 | none |
| Closed pages | visitor GET `/fr` (hub), `/en/library`, `/fr/library/theme/x`, `/fr/feed`, `/fr/more`, `/fr/trades`, `/fr/friends`, `/fr/achievements`, `/fr/settings`, `/fr/booster` | 303 to `/fr/landing` (locale kept), no flash alert | none |
| Visitor POST / JSON | visitor POST to an account action (HTML) / JSON request | HTML: 303 to landing; JSON: 401 `sign_in_required` as today | none |
| Root | visitor GET `/` | redirect to `/<locale>/landing` directly; a player to `/<locale>` | none |
| Sign-out / account deletion | DELETE session / account | redirect to the landing with the farewell / deleted notice shown there | none |
| Sign-in failure, no origin | `/auth/failure` | redirect to the landing with the alert | none |
| Landing hero | visitor on `/fr/landing` | "Embarquer sur le pont" is a POST form to `/auth/steam` (origin the landing path, Turbo off), accessible name says it signs in with Steam; 09's "Embarquer sur le pont" likewise (link style); no link to the hub | none |
| GAMEBLE link | visitor on `/fr/library/cards`, card detail, public profile, how-it-works | wordmark (desktop) and phone brand link to `/fr/landing`; the phone "◀" bridge too; a player's wordmark still links to the hub | none |
| Tab bar | visitor on an open page with the tab bar | all five tabs greyed and disabled (no link, no dialog opener) | none |
| Public profile | visitor | SIGNALER and ÉCHANGE (accessible name "Échange avec <name>") shown greyed and disabled; a player's SIGNALER unchanged and no ÉCHANGE added for players | none |
| Card detail | visitor from the grid or a profile | its sets listed by name without links; no sign-in invitation section; PARTAGER kept | none |
| Public card page | visitor | "OUVRIR MES PREMIÈRES CAPSULES" is the Steam sign-in POST (no dialog) | none |
| Invite link | visitor on `/fr/invite/:token` | its sign-in button is the Steam sign-in POST with origin the invite path (sign-in returns there) | none |
| Landing 04 | visitor | "Ouvrir le fil d'activité" greyed and disabled (the feed is closed to visitors) | none |
| Panel gone | any page | no `#sign-in-panel`, no `opens: "sign-in-panel"`, no `shell.sign_in_panel.*` strings, no `.sign-in-panel__*` CSS | none |

</intent-contract>

## Code Map

- `app/policies/page_policy.rb` -- add `def play? = player?` (a page of the game itself, for a signed-in player).
- `app/controllers/application_controller.rb` `refuse_in_locale` -- visitor: `format.html { redirect_to landing_path, status: :see_other }` (no alert); JSON/any unchanged (401 with `authorization.sign_in_required`).
- `app/controllers/pages_controller.rb` -- `home` and `more` authorize `:play?`; drop the `if current_player` guards that became always true; rewrite header comment. `legal`, `how_it_works` stay `:show?`.
- `app/controllers/feeds_controller.rb` -- `:play?`; `@tab` no longer needs `if current_player`.
- `app/controllers/library_controller.rb` -- `show` and `set` authorize `:play?`; remove `load_discover` call; `cards` unchanged; rewrite header comment (visitor reaches only the grid).
- `app/controllers/concerns/set_board_loading.rb` -- delete `load_discover`.
- `app/controllers/locales_controller.rb` -- `current_player ? home_path(locale:) : landing_path(locale:)`.
- `app/controllers/sessions_controller.rb` -- `destroy` and `return_path` fallback → `landing_path`; `accounts_controller.rb` deletion → `landing_path`.
- `app/views/library/show.html.erb`, `_entry.html.erb`, `_set_results.html.erb`, `_set_progress_row.html.erb`, `_album.html.erb`, `set.html.erb` -- remove the visitor-only branches (`progress:` local false paths, the discover section); `set_rows_helper.rb` `set_label_sentence` and `.set-row--visitor` in `hub.css` go if nothing else uses them (`public_profiles/set.html.erb` uses the album with progress). `library/cards.html.erb` keeps its visitor handling.
- `app/views/pages/home.html.erb`, `_menu*.html.erb`, `_invitation.html.erb` (delete), `_goal.html.erb`, `more.html.erb` -- remove visitor branches and comments; menu items for players unchanged.
- `app/views/feeds/show.html.erb` -- remove the visitor Friends-tab button.
- `app/views/shell/_top_bar.html.erb` + a helper (e.g. `shell_home_path` in the shell helper: hub for a player, landing for a visitor) -- wordmark link, phone brand (a link for a visitor), `top-bar__bridge`; the brand stays a plain `p` on the hub and the landing only.
- `app/views/shell/_tab_bar.html.erb` -- visitor: every tab a disabled `<button type="button" class="tab-bar__tab" disabled>` with icon and label; ensure greyed styling in `shell.css`.
- `app/views/shell/_sign_in_panel.html.erb` (delete), `layouts/application.html.erb` (render + comment), `shell.css` `.sign-in-panel__*`, locales `shell.sign_in_panel.*`, `ButtonComponent` comment, `SteamSignInComponent` `autofocus` param (only the panel used it).
- `app/views/landings/_hero.html.erb`, `_boarding.html.erb` -- `button_to "/auth/steam", params: { origin: request.path }, form: { data: { turbo: false } }` with the existing classes (`button button--primary landing-hero__embark`; boarding `button button--link landing-boarding__embark`), `aria-label` from a reworded `landings.show.hero.embark_label` ("Embarquer sur le pont, se connecter avec Steam" / "Board the bridge, sign in through Steam"). A small shared helper for the Steam sign-in button is welcome (hero, boarding, public card pitch, invite link).
- `app/views/landings/_live.html.erb` -- the feed link becomes a disabled button with the same label and classes.
- `app/views/cards/show.html.erb` -- pass `set_url:` only for a player (nil for a visitor); delete the visitor `card-invitation` section and its CSS (keep `cards.show.invitation`/`sign_in`, still used by `_public`); `cards/_public.html.erb` pitch button → Steam sign-in POST.
- `app/views/invite_links/show.html.erb` -- visitor button → Steam sign-in POST, origin `request.path`.
- `app/views/public_profiles/_summary.html.erb` -- visitor: SIGNALER `ButtonComponent(variant: :link, size: :small, disabled: true)`; plus a disabled secondary small ÉCHANGE under the name with `aria_label` (new keys `public_profiles.show.trade` "ÉCHANGE"/"TRADE", `trade_label` "Échange avec %{name}"/"Trade with %{name}"); `profile.css` only if needed.
- Locales: remove `library.entry.discover`, `pages.home.invitation.*`, `shell.sign_in_panel.*` and any key orphaned by removed branches.
- Tests: `authorization_test.rb`, `read_only_requests_test.rb`, `pages_controller_test.rb`, `library_controller_test.rb`, `library_set_test.rb`, `feeds_controller_test.rb`, `how_it_works_test.rb`, `landings_controller_test.rb`, `cards_controller_test.rb`, `public_profiles_controller_test.rb`, `sessions_controller_test.rb`, `accounts_controller_test.rb`, `locales_controller_test.rb`, `trades/friends/achievements/settings/boosters/...` visitor tests (redirect target now the landing, no alert), `test/integration/shell_test.rb`, `rate_limit_test.rb`. Visitor tests of the hub/entry/album/feed content become redirect tests or are deleted; add tests for every matrix row. System tests: update only obviously broken visitor steps if cheap, never run.

## Tasks & Acceptance

**Execution:**
- [x] `page_policy.rb`, `application_controller.rb`, pages/feeds/library/locales/sessions/accounts controllers, `set_board_loading.rb` -- the access rule and redirects.
- [ ] library, pages, feeds views; locales; CSS -- remove the visitor branches of closed pages and 14.7's discover section.
- [ ] shell top bar, tab bar, layout, sign-in panel, ButtonComponent/SteamSignInComponent -- GAMEBLE to landing, greyed tabs, panel retired.
- [ ] landing hero/boarding/live, card show/public, invite link, public profile summary -- Steam sign-in buttons and greyed actions.
- [ ] tests listed in the Code Map -- the matrix rows.

**Acceptance Criteria:**
- Given a signed-in player, when they open any page touched here, then its markup and links are as before (the hub wordmark, menu, tabs, SIGNALER, card detail set links, feed tabs).
- Given a visitor, when any page renders, then no element opens a sign-in panel and no link leads to a page that redirects them, except the PLUS phone back on Comment ça marche (lands on the landing via the redirect).

## Implementation Notes

- `PagePolicy#play?` closes the hub, PLUS, the feed, the library entry and albums; `ApplicationController#refuse_in_locale` sends every refused visitor's HTML request to the landing (303, no flash), so the policies already denying visitors follow without change.
- `/legal` and `/invite/:token` stay open (landing footer; a friend's invitation, whose sign-in returns to it).
- Shell helpers `shell_home_path`, `shell_home_label`, `shell_back_label`, `steam_sign_in_button`; partial `shell/_sign_in_acceptance` keeps the terms and privacy line (the panel's wording) beside the four game-styled sign-in buttons.
- A visitor's tab bar: five disabled buttons. The plain wordmark stays only on the hub and the landing.
- A visitor's card detail in a set context: set names without links and no way back to the album (`CardsController#album_back?`).
- 14.7's discover section, the hub's visitor branches, `pages/_invitation` and the visitor set row/album forms removed.
- System tests not updated (never run): `test/system/share_card_test.rb`, `feed_test.rb`, `hub_test.rb`, `trades_test.rb`, `settings_test.rb` still use the sign-in panel or the signed-out hub.

## Plan Change Log

## Review Triage Log

### 2026-10-20 — Review pass
- verdicts: 25 findings — high 3, medium 3, low 14, false 5, maybe-false 0 (the intent-alignment divergences counted as findings)
- findings:
  - `[high]` `[patch]` blind: the sign-in panel's line "signing in accepts the terms / privacy notice" is gone with no replacement, while the privacy notice's legal basis rests on it — restored as a muted line beside the four game-styled Steam sign-in buttons (landing hero and boarding, public card pitch, invite link), new non-panel keys; reported to the author.
  - `[medium]` `[patch]` blind: a visitor's card detail in a set context still offers "◀ Grille" to the album, now closed — no album back for a visitor without an owner; tests sign in where they pin the album back and assert the visitor's absence.
  - `[low]` `[reject]` blind: disabled controls carry no reason, against ButtonComponent's note — the intent says "greyed and disabled, with nothing else".
  - `[low]` `[patch]` blind: the visitor's phone back reads "Pont" while leading to the landing — visitor label added.
  - `[low]` `[patch]` blind: the visitor phone-brand link hardcodes landing_path beside shell_home_path — uses shell_home_path.
  - `[low]` `[reject]` blind: steam_sign_in_button duplicates SteamSignInComponent's form — deliberate: a game-styled label versus Valve's image; three shared attributes, one helper.
  - `[low]` `[reject]` blind: LibraryController keeps PublicRead (old browsers, shared-page throttle) on the now player-only entry and albums — a player's old-browser access there is as before; a visitor is only redirected; no harm met in use.
  - `[low]` `[reject]` blind: a sign-in failure alert is lost when its origin is a closed page — every visitor-visible Steam button now sits on an open page; only a pre-deploy origin could hit it.
  - `[low]` `[patch]` blind + verification-gap: friend_profiles test title "sent home to sign in" stale — renamed. The other "uneven coverage" remarks (303 not asserted everywhere) rejected: the shared refusal's 303 and no-alert are asserted in authorization_test and per-page redirect tests.
  - `[false]` `[reject]` blind: rubocop Layout/EmptyLines in pages_controller_test — `bin/rubocop` ran clean on 853 files.
  - `[false]` `[reject]` blind: the plan holds no record of the work — the review pass runs before Finalize fills it.
  - `[low]` `[reject]` blind: the boarding module shows Valve's image and "Embarquer sur le pont" doing the same; the hero's visible label does not say it leaves for Steam — the intent makes "Embarquer sur le pont" the Steam sign-in; the accessible name says so.
  - `[medium]` `[patch]` edge-case + verification-gap: same root cause as the set-context back above (two rows).
  - `[medium]` `[patch]` verification-gap: same, tests pinning the closed album back as a visitor's expectation (fixed with it).
  - `[false]` `[reject]` edge-case: the landing's phone brand links to itself — the landing sets `content_for :public_page`, which takes the plain-brand branch; after the patch the plain branch is the hub and the landing by controller.
  - `[false]` `[reject]` edge-case: same claim against the Code Map (brand plain on the landing) — refuted as above.
  - `[low]` `[reject]` edge-case: older browsers without :has() see the landing's embark buttons and fail at the modern-only callback — the landing's Valve image (top bar and boarding) already did so before this change.
  - `[high]` `[patch]` edge-case: the acceptance line — same as the first row.
  - `[high]` `[patch]` verification-gap other: the acceptance line — same as the first row.
  - `[low]` `[patch]` intent-alignment: the public card page's wordmark stays plain text, so GAMEBLE does not lead to the landing "from every page" — the page is visitor-only (`@public`), now a link to the landing.
  - `[low]` `[reject]` intent-alignment: Comment ça marche's phone back to PLUS reaches the landing only through the redirect — accepted in the plan's acceptance criterion; it lands where intended.
  - `[low]` `[reject]` intent-alignment: the COLLECTION tab is greyed though the catalog is open — the tab opens /library, which the intent closes; no tab fronts the catalog.
  - `[low]` `[reject]` intent-alignment: EXPERIENCE.md rows (hero accessible name, sign-in panel interaction row, public card page "signed-out hub", daily capsule and feed tabs "sign-in panel") still describe the old behaviour — the author's document; reported to the author, not edited by a build.
  - `[false]` `[reject]` intent-alignment: no greyed menu entry is rendered — the hub and PLUS are closed to visitors, so none remains visible, as the intent's "if any remain visible" allows.
  - `[low]` `[reject]` intent-alignment: greyness and phone/desktop are checked only on server HTML — system tests are disabled by project policy.

## Design Notes

Kept open beyond the ticket's list, for reasons the list does not override: `/legal` (the landing footer and the public card page link it) and `/invite/:token` (a friend's invitation; signing in from it returns there). Both are reported to the author. "Embarquer sur le pont" posts to Steam directly (the same form as `SteamSignInComponent`, other markup), so origin is the landing: a failed sign-in comes back there; a success lands on the hub as every sign-in does.

## Verification

**Commands:** (prefix Rails commands with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w14_8`; never run system tests; do not commit)
- `bin/rails test` -- 0 failures
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/brakeman --quiet --no-pager --exit-on-warn` -- clean

## Auto Run Result

- Summary: a signed-out visitor reaches only the landing, Toutes les cartes and its card detail, the public card page, public profiles and their albums, Comment ça marche (plus `/legal` and invite links); every other page sends them to the landing (303, no flash; JSON keeps 401). "Embarquer sur le pont" (hero and 09) is the Steam sign-in POST; GAMEBLE and the phone back lead a visitor to the landing; account actions show greyed and disabled (tab bar, SIGNALER and ÉCHANGE on a public profile, the landing's feed link); the sign-in panel and 14.7's À DÉCOUVRIR are removed. Signed-in pages unchanged.
- Files: policy, application/pages/feeds/library/locales/sessions/accounts/cards controllers, `set_board_loading.rb`, shell helper, top bar, tab bar, layout, `_sign_in_acceptance` (new), `_sign_in_panel` and `pages/_invitation` (deleted), landing hero/boarding/live, cards show/public, invite link, public profile summary, library and hub views, CSS, locales, about 35 test files.
- Review (thorough, 4 lenses): 25 findings; patched 6 entries (1 high: the terms/privacy line restored; 1 medium: a visitor's set-context card detail lost its album back; 4 low: phone back label, phone brand path, public card page wordmark link, a test title); rejected the rest (see the triage log). No deferral.
- Follow-up review recommended: true — a high entry was patched: the restored terms/privacy line's placement beside the four sign-in buttons is checked from markup only.
- Verification: `bin/rails test` 2914 runs, 0 failures; `npm run test:js` 492 passed; typecheck, zeitwerk, packwerk, rubocop (853 files), i18n-tasks missing and unused, brakeman clean. No system test run.
- Residual risk: layouts (ÉCHANGE under the name, the acceptance lines, the greyed tab bar) unseen in a browser; five system tests broken by design until rebuilt.

