---
title: "The landing's shell for visitors"
type: 'feature'
ticket: '2'
created: '2026-10-20'
status: 'built'
baseline_revision: 'f33dd4ecb35324a3e637d8f1776f4a23b722925e'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The landing's reveal demo Stimulus controller has no running test of its DOM behaviour.
    evidence: |-
      Only lib/reveal_demo.ts is unit-tested; vitest runs in node and system tests are disabled, so unhiding the button, showing the current face, writing the announcement and turning back are unverified.
    location: >-
      app/frontend/controllers/reveal_demo_controller.ts
    severity: medium
---

<intent-contract>

## Intent

**Problem:** A signed-out visitor has no page that tells them what gameble is; the landing designed on 2026-10-14 exists only as a mock.

**Approach:** Serve the landing at the provisional address `/:locale/landing` (the root switch is a later story): the slim top bar, the hero without its lamp field, the nine modules with their static copy and example visuals, and the landing footer, in French and English, phone and desktop, under the enforced CSP. Module 01's five rarity cards, 03's reveal demo and the examples' thumbnails show the published season's top card of each rarity (highest prestige score). A signed-in player who opens it is redirected to the hub.

## Boundaries & Constraints

**Always:**
- Copy from `EXPERIENCE.md`, Copy deck, Landing (French, as written, U+202F before « : ; ? ! » and inside « »); English written here under the same voice rules (the author approves it in review). Every string in both `en.yml` and `fr.yml`.
- Layout and type from `DESIGN.md`, Components, Landing and Layout & Spacing (desktop ≥1180px, medium 720–1179px, phone <720px); the new `landing-*` typography and spacing tokens added to `tokens.css`; values from tokens, never raw.
- One h1 (the hook) and one h2 per module, the h2's accessible name holding the module label and the title ("01 · Concept, Chaque carte est un jeu Steam."); 07's recruiting line h3 with the roles h4; 08's support line h3. Modules are `<section>` without an accessible name; examples are `aria-hidden` or one block named "Exemple : …" (EXPERIENCE.md, Accessibility Floor, Landing).
- Sample cards (author, 2026-10-20): per rarity, the published season's card-season with the highest `prestige_score` in that rarity, read through a new Catalog query, cached in `Rails.cache` keyed on the published season and locale. With no published season, or a rarity with no card, that slot shows a face-down card (the Standard card back) and module 01 still lists the rarity name and odds; the reveal demo is then hidden.
- 01's chance per card comes from `Game::DrawOdds::REGULAR`, formatted like How it works (`HowItWorksHelper#odds_rows`).
- No `style` attribute, inline script or `data:` URI; content visible without JavaScript.
- Pundit-authorized action on the reading role (GET writes nothing); no database id in the HTML.
- The landing path is throttled like the other public pages (`PublicReadThrottle`).

**Never:**
- The lamp field and its readout, the moving cards, the side gauge, the module power-on, the star drift, the motion switch, live feed entries, the season name and facts, the weekly goal's live figures, the roadmap milestones and the lore text (later stories 4–9, 11, 14). Their slots stay as named below.
- The mock's deviations listed in `EXPERIENCE.md`, Implementation notes (no « TERMINAL EN LIGNE », footer link gaps per `{spacing.touch-gap}`, feed example rows with a period, no rotated small COMPLET text).
- Changing the root, the hub, the signed-out hub or the public card page.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Visitor, French | GET `/fr/landing`, signed out, published season | 200; `lang` fr; the hook as the only h1; exactly nine module h2s with "0n · Nom" in their names; five card faces in 01 in rarity order, each the season's top-prestige card of its rarity; odds under each | No error expected |
| Visitor, English | GET `/en/landing` | Same structure in English copy | No error expected |
| Player | GET `/en/landing` signed in | 303 redirect to `/en` (the hub) | No error expected |
| No published season | Only draft seasons | 200; 01 shows five face-down backs with rarity names and odds; no reveal demo button; thumbnails replaced by empty slots | No exception |
| Rarity missing | Published season without a legendary card | That slot face-down, the others faces | No exception |
| Two cards in a rarity | Different prestige scores | The higher score is shown | — |
| CSP | Any landing response | No `[style]` element, no inline `<script>` without the nonce | — |

</intent-contract>

## Code Map

- `config/routes.rb` -- inside `scope ":locale"`: add `get "landing" => "landings#show", as: :landing`.
- `app/controllers/application_controller.rb` -- `current_player`, `verify_authorized`, reading role on GET; redirect pattern `redirect_to home_path, status: :see_other` (see `welcomes_controller.rb:9`).
- `app/controllers/concerns/public_read.rb` -- include in the new controller so older browsers get the page (as `PagesController#public_read?` does for legal).
- `app/policies/page_policy.rb` -- headless `authorize :page, :show?` pattern; a dedicated `LandingPolicy` (`show? = true`) with its test in `test/policies/` follows `page_policy_test.rb`.
- `config/initializers/rack_attack.rb` -- `PublicReadThrottle` `PAGES = %w[cards brothers library]`: add `landing`; its path-list assertion in `test/integration/rate_limit_test.rb` ~217.
- `app/views/layouts/application.html.erb`, `app/views/shell/_top_bar.html.erb` -- `content_for :public_page, true` gives the slim top bar (plain wordmark, Steam image for visitors) and hides the tab bar; the landing uses it. Reference template: `app/views/cards/_public.html.erb`.
- `app/components/card_component.rb` -- `CardComponent.new(card: Catalog::CardView, size: :s|:m)`; `card_back_image(Game::CardBacks::STANDARD)` in `app/helpers/card_details_helper.rb:87` for face-down slots; `card_rays`/`card_top_rarity?` not used in 01 (no rays there).
- `app/components/steam_sign_in_component.rb` -- `SteamSignInComponent.new(origin:, autofocus: false)` for 09; `ButtonComponent`, `PanelComponent.new(tag:, quiet:, brackets:)`.
- `app/helpers/external_links_helper.rb` -- `DONATION_URL`, `SOURCE_CODE_URL`, `external_link_to` (new-tab suffix): reuse for 07, 08 and the footer.
- `app/helpers/shell_helper.rb:22` -- `pixel_icon(name)`; only existing icons (`app/frontend/images/pixel/*.svg`); never hand-edit that folder.
- `packs/catalog/app/queries/catalog/published_season.rb` -- `Catalog::PublishedSeason.call`; `Catalog::CardViews.call(ids, locale:)` returns `{ id => CardView }`; `Catalog::Rarity::TIERS` (1 common … 5 legendary); `Catalog::CardSeason#prestige_score`, `rarity` enum.
- `packs/game/app/models/game/draw_odds.rb` -- `REGULAR`; `app/helpers/how_it_works_helper.rb:15` `odds_rows`.
- `app/frontend/entrypoints/application.css` + `app/frontend/styles/tokens.css` -- add `landing.css` import and the `landing-*` tokens (DESIGN.md frontmatter lines ~232–320).
- `app/frontend/controllers/` -- Stimulus TypeScript controllers, registered as the existing ones are.
- `test/fixtures/catalog/` -- published season `one` with one card per rarity (`common_card_one` … `legendary_card_one`); `test/support/catalog_seeds.rb` `seed_card_seasons`; `test/support/steam_sign_in.rb` `sign_in`.
- `_bmad-output/initiative-gameble/ux-gameble/mockups/landing.html` -- look reference only, never source.

## Tasks & Acceptance

**Execution:**
- [ ] `packs/catalog/app/queries/catalog/landing_sample_cards.rb` + test -- `Catalog::LandingSampleCards.call(locale:)`: `{ rarity_key => CardView or nil }` for the five rarities from the published season's top-prestige card-season of each; `{}`-with-nils when none; cached keyed on season id and locale -- one query per rarity at most, ordered deterministically (prestige desc, id).
- [ ] `config/routes.rb`, `app/controllers/landings_controller.rb`, `app/policies/landing_policy.rb` (+ policy test) -- `show`: authorize, redirect a player to `home_path` (303), else render with sample cards and odds rows.
- [ ] `app/views/landings/show.html.erb` + partials per module under `app/views/landings/` -- hero (kicker with status light, h1 hook, line, primary « Embarquer sur le pont » linking `home_path` with its accessible name; the lamp field area left empty and `aria-hidden` for story 4), modules 01–09, footer; `content_for :public_page`, `content_for :title`. Live slots: 02 goal panel shows its kicker, title, explanation and "—" for line, count and gauge; 02 lore panel shows the dashed slot plus the narrators call with « Participer à l'écriture » linking `#` 07's h2; 04 shows the feed kicker, the no-activity line, « Ouvrir le fil d'activité » (feed path) and the season panel with "—" figures; 06 shows its header, title, subtitle and the status legend only. Example visuals as DESIGN.md lists them, reusing the sample cards' covers as thumbnails.
- [ ] `app/frontend/controllers/reveal_demo_controller.ts` + vitest -- 03's demo over server-rendered faces: « Révéler » shows the current sample face and writes its server-rendered announcement into a polite status; « Recommencer » turns it back and readies the next sample; focus stays on the button; reduced motion crossfades.
- [ ] `app/frontend/styles/landing.css`, `tokens.css`, `application.css` -- the three widths from DESIGN.md; on the phone 01's card row scrolls sideways (`touch-action: pan-x pan-y`, no tilt) and every other grid stacks; the hero entrance is pure CSS and still under `prefers-reduced-motion` and the reduced-motion class the app already uses; `content-visibility: auto` on modules.
- [ ] `config/locales/en.yml`, `fr.yml` -- `landings.show.*` keys, zero/one/other forms where counts appear.
- [ ] `config/initializers/rack_attack.rb`, `test/integration/rate_limit_test.rb` -- throttle `landing`.
- [ ] `test/controllers/landings_controller_test.rb` -- the matrix rows: both locales' headings (one h1, nine h2 with module labels), 01's five faces and top-prestige choice, no published season, a missing rarity, player redirect, no `[style]`, no unnonced inline script, Steam image and hub links, external links' new-tab names.

**Acceptance Criteria:**
- Given a signed-out visitor, when they open `/fr/landing` or `/en/landing` on a 390px phone or a 1440px desktop, then every module renders in one column (phone) or its designed grid (desktop) with no horizontal page scroll.
- Given the response, when the CSP is enforced, then the browser reports no violation (no inline style, no unnonced script).
- Given the reveal demo, when the visitor presses « Révéler » then « Recommencer », then a sample face shows and is announced, and the card turns back with focus on the button.

## Implementation Notes

## Plan Change Log

## Review Triage Log

### 2026-10-20 — Review pass
- verdicts: 29 findings — high 0, medium 3, low 9, false 13, maybe-false 4
- findings:
  - `[low]` `reject` Intent audit: phone and desktop viewports exercised by no test — system tests are disabled by AGENTS.md; the implementer checked 360/390/800/1000/1440px in headless Chromium with no horizontal scroll.
  - `[low]` `reject` Intent audit: "no CSP report" checked only by HTML proxy — headless Chromium run reported no violation besides the test fixtures' fake image host; runtime CSP tests need the disabled system suite.
  - `[false]` `reject` Intent audit: one h2 per section not asserted per section — the controller test counts nine h2s in order inside nine sections; each partial renders exactly one heading through `landing_module_heading`.
  - `[false]` `reject` Intent audit: reveal demo beyond the ticket text — it is module 03's designed content (EXPERIENCE.md) and no other ticket of the epic builds it.
  - `[maybe-false]` `reject` Intent audit: shared layout yield and `external_link_to` hint untested on other pages — both are additive (no yield content, hint defaults to the old text) and the full suite passes; would only be low.
  - `[medium]` `patch` Verification gap: season part of the sample-card cache key never exercised — added a test that warms the cache, publishes a newer season and gets its cards.
  - `[medium]` `defer` Verification gap: reveal demo controller's DOM behaviour unverified — no Stimulus DOM harness and system tests disabled; deferred.
  - `[maybe-false]` `reject` Blind: no link-preview meta, hreflang or canonical — the landing's meta is an open question and story 18's scope.
  - `[false]` `reject` Blind: nothing leads a visitor to the landing — provisional address by design; the root switch is story 15.
  - `[low]` `reject` Blind: reserve size 10 hard-coded — "Dix capsules vous attendent." and "Réserve : 10 / 10" are the author's fixed copy; interpolating adds complexity for no current harm.
  - `[low]` `reject` Blind: gauge segment count in helper and CSS — 24 is the designed constant; unlikely to change and a token adds plumbing.
  - `[low]` `reject` Blind: flip timings in TS and CSS — the designed durations; sharing them needs a CSSOM read, more than a direct correction.
  - `[false]` `reject` Blind: announcement stray punctuation with no details — `CardViews` always sets `year` from `release_date.year`, so details are never empty.
  - `[low]` `patch` Blind: narrative and French comments against AGENTS.md — narrative comments and French copy removed from every new file.
  - `[low]` `patch` Blind: three unused landing tokens — removed.
  - `[false]` `reject` Blind: "—" placeholders — the designed state for a figure that cannot be read (EXPERIENCE.md, State Patterns, Landing live data); live data is stories 5, 6 and 11.
  - `[medium]` `patch` Blind + Edge: cache entry of Marshal-dumped CardView has no shape version — key now includes `CardView.members`.
  - `[low]` `reject` Blind: in-page jump past `content-visibility: auto` modules may shift — the design requires content-visibility; the browser renders the target on jump; cosmetic.
  - `[false]` `reject` Blind: hero h1 tabindex -1 — the landing's h1 is the focus target after sign-out and deletion (EXPERIENCE.md, Focus after each step), wired by story 15.
  - `[low]` `reject` Blind: Steam origin adds a redirect hop — one 303 after sign-in, lands on the hub as designed.
  - `[false]` `reject` Blind: example literals and achievements tile mismatch — the examples follow the copy deck's 05 tile examples verbatim; figures are decorative and aria-hidden.
  - `[medium]` `defer` Blind: reveal demo controller has no vitest coverage — same root as the verification-gap deferral.
  - `[false]` `reject` Blind: no test for announcement without details — the case cannot occur (year always present).
  - `[low]` `reject` Blind: database-id regex test is narrow — the view renders no id-bearing attribute at all; a wider test adds nothing today.
  - `[low]` `reject` Edge: reduced-motion turn-back cuts the face instead of crossfading — cosmetic; fixing adds a leaving state.
  - `[medium]` `patch` Edge: cached CardView shape after deploy — grouped with the cache-version patch.
  - `[maybe-false]` `reject` Edge: top-prestige card without a text in the locale shows face down — imports write both locales' texts; would be low.
  - `[maybe-false]` `reject` Edge: cache write under prevent_writes untested — Solid Cache has its own connection class and Rack::Attack already writes Rails.cache in GETs in production; would be low.
  - `[false]` `reject` Edge: reveal index beyond face count — the count comes from the rendered faces and the index is taken modulo it.

## Design Notes

- Provisional address `/:locale/landing`; story 15 moves it to the root. `landing` added to the throttle now so the root switch only adds the root.
- Decision (author, 2026-10-20): the landing's sample cards are the published season's top card of each rarity, no curated list. With no published season the slots fall back to face-down Standard card backs: safe (no stale or draft card shown, no empty frame breaking the row's balance).
- Sign-in from the landing returns to `origin: request.path`, which redirects the new player to the hub, as EXPERIENCE.md wants.
- Feed path: find the existing feed route (`feeds#show` or similar) for « Ouvrir le fil d'activité »; it opens the sign-in for a visitor like any account-only screen.

## Verification

**Environment:** run every Rails command in this worktree with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w20_2` and `CHROME_BIN=/usr/bin/chromium` exported (database already created and loaded). Never run `bin/rails test:system`. Do not commit.

**Commands:**
- `bin/rails test` -- expected: pass (system tests skipped)
- `npm run test:js` and `npm run typecheck` -- expected: pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: clean
- `bundle exec i18n-tasks missing` -- expected: none
- `bin/brakeman --quiet --no-pager --exit-on-warn` -- expected: no warnings

## Auto Run Result

Status: built

Commit: 459b9ba22bd38dad3adf4e8b231742e8da2688fa

- **Change:** the landing at `/:locale/landing` for signed-out visitors (a player is redirected to the hub): slim top bar, hero without its lamp, the nine modules with their copy, examples and the sample cards (the published season's top card of each rarity, face-down Standard backs without a season), the reveal demo, the footer, in French and English, throttled like the public pages.
- **Files:** `LandingsController`, `LandingPolicy`, the route, `Catalog::LandingSampleCards`, `LandingsHelper`, `app/views/landings/*`, `reveal_demo` controller and pure module, `landing.css` and tokens, locale keys, the layout's `page_footer` slot, `external_link_to`'s `hint:`, the throttle's pages, tests.
- **Review:** patches 3 entries (cache shape version and season-key test, medium; comments and unused tokens, low); deferred 1 (reveal demo DOM test); rejected the rest with reasons in the triage log.
- **Follow-up review recommended:** false (no high patched; the two medium patches share one root, the cache key).
- **Verification:** `bin/rails test` 2875 runs, 0 failures, 0 errors; `npm run test:js` 492 passed; typecheck, zeitwerk, packwerk, rubocop (839 files), i18n-tasks missing, brakeman clean. Headless Chromium: no horizontal scroll at 360–1440px, one h1, no CSP violation besides the fixtures' image host.
- **Residual risks:** English copy is a draft for the author's approval; 01's phone row is not a tab stop while it overflows; the page title, the top bar's wordmark link and the copy deck's Steam image name are left to later stories (18, 15) and the open questions.
