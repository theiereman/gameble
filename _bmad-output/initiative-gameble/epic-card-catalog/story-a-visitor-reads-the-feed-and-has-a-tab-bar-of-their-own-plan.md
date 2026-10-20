---
title: 'A visitor reads the feed and has a tab bar of their own'
type: 'feature'
ticket: 9
created: '2026-10-20'
status: 'built'
baseline_revision: '222a91c41b7a323e6953b0838709ad11c06d19c9'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
commit: 'c08a1ac9397940b5fb588908e839c706c4387dcf'
---

<intent-contract>

## Intent

**Problem:** After 14.8 the activity feed sends a visitor to the landing, the landing's module 04 "Ouvrir le fil d'activité" is a greyed button, and a visitor's phone tab bar shows five greyed tabs. The author decided (2026-10-20) that the feed opens again to visitors, read-only, and that a visitor's phone tab bar has two tabs, ACCUEIL (the landing) and TOUTES LES CARTES (/library/cards). EXPERIENCE.md (and DESIGN.md where it says the same) still describes the signed-out hub, the sign-in panel and "visiter le jeu sans compte" as current.

**Approach:** The feed authorizes with `:show?` again; a visitor reads All with its filters, the AMIS tab shown greyed and disabled (the friends tab needs an account); the landing's feed link is a link again; the tab bar renders a visitor's two tabs as links. Then rewrite the stale rows of the UX spines.

## Boundaries & Constraints

**Always:** a signed-in player's feed, landing and tab bar unchanged; every string in en.yml and fr.yml; no `style` attribute; no planning ids in code/tests; docs keep the author's decisions and dates, superseded ones marked "(superseded 2026-10-20: …)" or concisely rewritten; the terms line (signing in accepts the terms of use and the privacy notice) named beside every game-styled Steam sign-in in the docs.

**Never:** no new route, operation, event, Stimulus controller or pixel icon (reuse existing `tab-*` icons); do not reopen the hub, PLUS, the collection entry or any other closed page; do not touch docs sections unrelated to signed-out visitors; never run system tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Feed, visitor | visitor GET `/fr/feed`, `/en/feed?filter=pulls` | 200; entries filtered by Game::Visibility for no viewer; filters work; live stream on All | none |
| Feed friends tab, visitor | visitor GET `/fr/feed?tab=friends&filter=pulls` | 200, reads All (tab ignored); AMIS is a disabled `button.feed__tab`, TOUS current; no link to `/friends` | none |
| Feed phone back, visitor | visitor on the feed | no `top-bar__phone-back` to PLUS; the top bar's bridge back leads to the landing | none |
| Feed, player | signed in | unchanged (AMIS link, phone back to PLUS) | none |
| Landing 04 | visitor on `/fr/landing` | `a.landing-live__open[href='/fr/feed']` "Ouvrir le fil d'activité", no disabled button | none |
| Visitor tab bar | visitor on `/fr/library/cards` (phone) | two links: ACCUEIL → `/fr/landing` (tab-hub icon), TOUTES LES CARTES → `/fr/library/cards` (tab-collection icon) marked `aria-current=page`; no disabled tab; a two-column grid | none |
| Visitor tab bar elsewhere | visitor on the card detail, a public profile, the feed | Toutes les cartes current on the card detail; none current on a public profile or the feed | none |
| Player tab bar | signed in | the five tabs as before | none |
| Closed pages | visitor GET `/fr`, `/fr/more`, `/fr/library` | still 303 to the landing | none |

</intent-contract>

## Code Map

- `app/controllers/feeds_controller.rb` -- `authorize :page, :show?`; `@tab = params[:tab].presence_in(TABS) if current_player`; header comment: readable without an account, the Friends tab a player's.
- `app/views/feeds/show.html.erb` -- `content_for :phone_back` only `if current_player` (a visitor gets the top bar's default bridge back, `shell_home_path` = landing, label `shell.top_bar.back_landing`); AMIS: `link_to` for a player, else `tag.button t(".tabs.friends"), type: :button, class: "feed__tab segmented__option", disabled: true`; check `.feed__tab:disabled` reads greyed in `app/frontend/styles/feed.css` (or wherever `.segmented__option` lives), add the opacity rule if absent; update the header comment.
- `app/views/landings/_live.html.erb` -- `link_to t("landings.show.live.open_feed"), feed_path, class: "button button--link landing-live__open"` (as before 14.8).
- `app/views/pages/_menu_feed.html.erb` -- comment only if it now misstates.
- `app/views/shell/_tab_bar.html.erb` -- tabs list chosen by `current_player`: player's five unchanged; visitor's two `[:landing, "tab-hub", landing_path, controller_path == "landings"]`, `[:all_cards, "tab-collection", library_cards_path, (controller_path == "library" && action_name == "cards") || controller_path == "cards"]`, rendered with the same `link_to` markup (no trades badge); `ul` gets `tab-bar__list--visitor` for a visitor; drop the disabled-button branch; rewrite the header comment.
- `app/frontend/styles/shell.css` -- `.tab-bar__list--visitor { grid-template-columns: repeat(2, minmax(0, 1fr)); }`; the `button.tab-bar__tab` and `.tab-bar__tab:disabled` rules go if nothing else uses them (`[aria-disabled]` rule stays if used).
- `config/locales/en.yml`, `fr.yml` `shell.tabs` -- `landing: "Home"` / `"Accueil"`, `all_cards: "All cards"` / `"Toutes les cartes"` (labels are uppercased by CSS).
- `app/helpers/shell_helper.rb` -- read only (`shell_home_path`, `shell_back_label`).
- Tests: `test/controllers/feeds_controller_test.rb` (replace "a visitor is sent to the landing" with visitor read tests for the matrix rows; existing stranger tests may run signed out again where natural), `test/controllers/authorization_test.rb:53` (JSON 401 example uses `feed_path` → use `home_path`), `test/controllers/landings_controller_test.rb:160-161` (feed link), `test/integration/shell_test.rb:95-102` (visitor tab bar) and add a card-detail current case, `test/integration/rate_limit_test.rb` unchanged (feed not throttled as a public read). Check `test/controllers/read_only_requests_test.rb` and any test listing closed pages for `/feed`.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- rewrite: IA rows (l.28-52: Fil d'activité l.42 open to visitors read-only, AMIS greyed; Comment ça marche l.44; Public card page l.46; Soutenir l.52 — a visitor reaches it from the landing only; the IA paragraph "Signed-out visitors" l.64 and the phone tab bar description wherever it lists tabs: add the visitor's two tabs); Copy deck rows l.125 (Public page), l.128 (Sign-in panel: retired), l.144 (Steam sign-in name), l.146 Hero and 09 rows ("Embarquer sur le pont" signs in through Steam, accessible name, terms line); interaction rows l.210 (daily capsule panel: no sign-in panel), l.275 (feed tabs: visitor AMIS greyed), l.310 (final call 09), l.325 (public card page: Steam sign-in POST, terms line, no signed-out hub), l.326 (public profile: SIGNALER and ÉCHANGE greyed), l.328 (sign-in panel row: retired); state row l.357 (signed out: add the feed); Flow 5 steps l.567-578 (no signed-out hub, no panel: the button signs in directly, terms line; failure: Steam refuses → back on the public card page); Flow 6 l.617-627 (direct-visitor variant: landing, Embarquer sur le pont signs in); open questions l.679, 685, 688 (signed-out hub gone: close or mark superseded). Any other row naming the signed-out hub, the sign-in panel, or "visiter le jeu sans compte" as current.
- `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md` -- l.720-722 (Sign-in panel: retired, the game-styled button posts to Steam with the terms line beside it), l.805-809 (top bar: signed-out "hub" row), l.860-862 "#### Signed-out hub" (superseded: a visitor never sees the hub), Tab bar section (visitor's two tabs), l.998 Final call, l.1009 public card page.

## Tasks & Acceptance

**Execution:**
- [x] `feeds_controller.rb`, `feeds/show.html.erb`, feed CSS -- reopen the feed read-only, AMIS greyed, visitor back to the landing.
- [x] `landings/_live.html.erb` -- feed link restored.
- [x] `shell/_tab_bar.html.erb`, `shell.css`, locales -- the visitor's two-tab bar.
- [x] tests listed in the Code Map -- every matrix row.
- [x] `EXPERIENCE.md`, `DESIGN.md` -- the rows listed in the Code Map.

**Acceptance Criteria:**
- Given a visitor, when any page with the tab bar renders, then no tab is disabled and no tab leads to a page that redirects them.
- Given EXPERIENCE.md and DESIGN.md, when searched for "signed-out hub", "sign-in panel" and "sans compte", then every hit is marked superseded/retired or is history, none describes current behaviour.

## Implementation Notes

- A visitor's disabled AMIS uses the disabled tokens (`--color-disabled-bg`, `--color-disabled-text`) as the card detail's disabled nav does, not opacity, in `feed.css`.
- The tab bar never renders on the landing or the public card page (`content_for :public_page`), so ACCUEIL is never current; the card-detail current case is tested through a set-browsed detail (`set_kind`/`set_key`), the only detail a visitor sees with the shell.
- The `button.tab-bar__tab` and `.tab-bar__tab:disabled`/`[aria-disabled]` rules had no other user and were removed.
- Docs: the plan's "Flow 5 l.567-578" and "Flow 6 l.617-627" are Flow 1 and Flow 5 by content; both were rewritten, and Flow 6's step 1 ("Découvrir") too. EXPERIENCE's collection-opening row ("À DÉCOUVRIR" for a visitor) and the IA Landing and hub rows also named retired visitor paths and were marked superseded.

## Plan Change Log

## Review Triage Log

### 2026-10-20 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` EXPERIENCE.md copy deck "09 · Embarquement" still called "Embarquer sur le pont" a hub link, without the terms line — rewritten: it signs in through Steam, the Sign-in terms line beside it, superseding its hub link.
  - `[low]` `[patch]` EXPERIENCE.md Hero interaction row lacked the terms line its siblings carry — added.
  - `[low]` `[patch]` the visitor's card detail opened from the Toutes les cartes grid (their main path) was untested for the current tab; the implementation note calling the set-browsed detail the only one was inaccurate — `shell_test` now opens a card from the grid as a visitor and asserts TOUTES LES CARTES current (the note itself is left as written: a fix editing the plan is out of triage).

## Design Notes

AMIS stays visible but disabled for a visitor (as 14.8 greys every action needing an account) rather than hidden, so the feed reads the same for everyone. The feed is not added to `PublicRead`'s throttle (it was not before 14.8 either).

## Verification

**Commands:** (prefix Rails commands with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w14_9`; never run system tests; do not commit)
- `bin/rails test` -- 0 failures
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/brakeman --quiet --no-pager --exit-on-warn` -- clean

## Auto Run Result

- Summary: the activity feed opens again to a visitor, read-only (TOUS and its filters, AMIS a greyed disabled button, a friends query reads TOUS, the phone back leads to the landing); the landing's "Ouvrir le fil d'activité" is a link again; a visitor's phone tab bar holds two links, ACCUEIL (landing, tab-hub icon) and TOUTES LES CARTES (/library/cards, tab-collection icon, current on the grid and a card's detail). A player's feed, landing and tab bar unchanged. EXPERIENCE.md and DESIGN.md no longer present the signed-out hub, the sign-in panel or "visiter le jeu sans compte" as current, and name the terms line beside each game-styled Steam sign-in.
- Files: `feeds_controller.rb`, `feeds/show.html.erb`, `feed.css` (greyed AMIS), `landings/_live.html.erb`, `shell/_tab_bar.html.erb`, `shell.css` (two-column visitor list, unused disabled-tab rules removed), en/fr `shell.tabs.landing`/`all_cards`, tests (feeds, shell, authorization, landings), `ux-gameble/EXPERIENCE.md`, `ux-gameble/DESIGN.md`.
- Review (quick): 3 findings, 3 patched (1 medium, 2 low), none deferred or rejected.
- Follow-up review recommended: false — no high patched, one medium.
- Verification: `bin/rails test` 2941 runs, 0 failures; `npm run test:js` 492 passed; typecheck, zeitwerk, packwerk, rubocop (857 files), i18n-tasks missing and unused, brakeman clean. No system test run.
- Residual risk: the two-tab bar and the greyed AMIS unseen in a browser; doc wording for the author to read ("Comment ça marche" described as reached by a visitor only at its address, since no menu or PLUS row leads there).
