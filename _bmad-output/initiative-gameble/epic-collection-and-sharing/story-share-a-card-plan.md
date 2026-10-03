---
title: 'Share a card'
type: 'feature'
ticket: '5'
created: '2026-10-02'
status: 'built'
baseline_revision: 'd1c4c3cdb29a1a96a31c4e3659e571ab7a2841be'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md', '{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/story-card-detail-plan.md', '{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/story-public-profile-plan.md']
warnings: ['oversized']
deferred:
  - summary: >-
      An older browser (iOS 16 Safari, Firefox 92) now reads a shared card, but its invitation to sign in leads to a 406: the Steam callback and the attic still require a modern browser.
    evidence: |-
      allow_browser versions: :modern applies to SessionsController and PagesController (both < ApplicationController); only PublicProfilesController overrides public_read?, as the intent scopes it. The modern-browser rule on sign-in and the attic predates this story; recorded in pending-approvals.md for the author's decision.
    location: >-
      app/views/public_profiles/card.html.erb (invitation), app/controllers/application_controller.rb (allow_browser)
    severity: medium
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player who pulls a card they are proud of cannot show it off; a link pasted on Discord, X or WhatsApp should make friends want to play (CAP-9; EXPERIENCE Flow 1; epic 4, R5, R6).

**Approach:** On a card's detail, a player who holds that card-season gets a share button that copies a link to their public profile with that card-season shown; the page shows the card's detail with an owner line and, for a visitor, an invitation to play, and its Open Graph and Twitter tags give the card's title and rarity and no game image.

## Boundaries & Constraints

**Always:**
- Routes: `GET /<locale>/brothers/:token/cards/:slug` and `GET /<locale>/brothers/:token/cards/:slug/seasons/:number` (`brother_card_path`, `brother_card_season_path`, mirroring 4.3), in `PublicProfilesController`; owner lookup, visibility and the unavailable page exactly as in 4.4 (an invisible owner wins over a bad slug); an unknown slug, numeric slug or season → 404 as in 4.3.
- The page: 4.4's profile with 4.3's `cards/_detail` first. The partial takes `copies:` (nil here: never the viewer's count), `owner:` (the owner line "From the collection of <owner's profile title>", 4.4's persona name or its fallback), `share_url:` (nil here; only `cards#show` passes it, for a holder) and a set-path builder (here `brother_set_path`, so set links stay on the owner's profile). If the owner does not hold that card-season (traded away, or a crafted URL), the detail shows "No longer in <owner's profile title>'s collection" instead of the owner line, status 200. `content_for(:title)` = the og:title.
- Invitation for a visitor only (no CTA for a signed-in viewer): "Ten packs wait in the attic" with the Steam sign-in button posting `origin: home_path`, so a successful sign-in lands in the attic (EXPERIENCE Flow 1).
- Share button (4.3's detail, holder only): always the season-qualified absolute URL. A Stimulus `share` controller calls `navigator.clipboard.writeText` synchronously in the click when `window.isSecureContext && navigator.clipboard?.writeText` (the test LXC is plain HTTP); otherwise it selects a read-only input showing the URL and tries `document.execCommand("copy")`, saying "Link copied" only when that returns true, else "Press Ctrl+C to copy"; feedback in a `role="status"` region reset on connect.
- Absolute URLs (share link, `og:url`, canonical) come from a configured public base (`config.x.public_url`, from `PUBLIC_URL` in production, the request's base in development and test), never echoing a spoofed Host.
- Tags in `content_for(:head)`: `og:title` "<title> — <rarity name>" in the URL's locale; `og:description` a fixed invitation line; `og:type` website; `og:site_name` gameble; `og:url` and `<link rel="canonical">` the season-qualified URL without query string (the season-less route's canonical points to it); `og:locale` `en_US` / `fr_FR`; `twitter:card` summary; no `og:image`, `twitter:image` or `image_src` (asserted on the head); `<meta name="description">`; `noindex`. A French sharer posts French previews (intended).
- Crawlers and older browsers: `ApplicationController`'s `allow_browser versions: :modern` gets `unless: :public_read?`, true for `PublicProfilesController` GETs, so Discordbot, Discord's old-Firefox fetch, Twitterbot, WhatsApp and an iOS 16 Safari get the page (tested with those user agents).
- `pending-approvals.md` gains: whether X previews may carry a non-game image (a rarity back as PNG) since X may show a bare link without one; a Cloudflare note (Bot Fight Mode off or a WAF skip rule for these user agents on `/*/brothers/*`); the manual preview check on Discord, X and WhatsApp once a public HTTPS host exists.
- No database id; the token and slug only. Copy in `fr` and `en`.

**Never:** no image in the preview; no tracking of shares; no share button for a non-holder; no short-link service; no Web Share API.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Share button | holder / non-holder / visitor on a card detail | button / none / none | — |
| Copy, secure | press share on https or localhost | URL written, "Link copied" | — |
| Copy, http | no `navigator.clipboard` | input selected, execCommand result shown, or "Press Ctrl+C to copy" | fallback |
| Shared page | visitor opens the link | profile with the card's detail first, owner line, invitation | — |
| Signed-in viewer | a non-owner / the owner | detail and owner line, no CTA, no share button, no "You hold" | — |
| Tags | `en` | `og:title` "Portal 2 — Sapphire", `og:locale` en_US, `twitter:card` summary, no image tags, canonical season URL | — |
| French | `/fr/…` | French rarity, `og:locale` fr_FR | — |
| Season-less | `/brothers/:token/cards/:slug` | canonical points to the season form | — |
| Traded away | owner no longer holds it | detail with "No longer in … collection", 200 | — |
| Unknown | bad token / slug / season; numeric slug | unavailable page or 404 as in 4.4 / 4.3 | — |
| Spoofed Host | request with `Host: evil.example` | `og:url` from the configured base | — |
| User agents | Discordbot, old Firefox 92, Twitterbot, WhatsApp, iOS 16 Safari | 200 with the tags | `allow_browser` skipped |
| CTA | visitor signs in from the invitation | lands in the attic | — |
| Title | the shared page | `<title>` = og:title | — |

</frozen-after-approval>

## Code Map

- `app/controllers/public_profiles_controller.rb` -- `before_action :authorize_page, :load_owner` (unknown token or invisible owner renders `public_profiles/unavailable`, 404, halting the action: so an invisible owner already wins over a bad slug); `STARTED`, `TABS`, `shelf_relation(season)`; `show` loads `@kind`, `load_shelf`, `@summary` (`Game::CollectionSummary.call(@owner, season:)`). Add the `card` action here; do not change `show`/`set` behaviour or their query counts (7/8, 9/10).
- `app/controllers/concerns/shelf_loading.rb` -- `load_shelf(relation, owner:)`, `page_param`; reuse as is.
- `app/controllers/cards_controller.rb` -- `show`: `request.path_parameters[:number]&.to_i` (never `params[:number]`), `Catalog::CardDetail.call(slug:, locale:, season_number:)` (nil → `RecordNotFound`), `@copies` from `Game::Quantities` (only `quantity > 0` rows; `{}` and no query for nil player). Its query counts (player 4, visitor 2) must stay.
- `packs/catalog/app/queries/catalog/card_detail.rb` -- `Detail(view, short_description, publisher, credit, store_url, sets, card_season_id, current_season)`; `view.id` is the slug, `view.rarity`, `view.season_number`, `view.title`. Read only.
- `app/views/cards/_detail.html.erb` -- locals `detail:, copies:, owner:, set_url:`; `owner` renders `card_details.owner`. Add `owner_holds:` (default true via `local_assigns`) and `share_url:` (default nil); `cards/show.html.erb` passes `owner: nil`.
- `app/views/public_profiles/show.html.erb` -- the profile body (header with `h1#library-heading`, counts, `library/_shelf` with tabs, `tab_url`, `set_url` lambdas): extract into a partial shared with the card page, where the profile heading is an `h2` (the card's title is the page's `h1`).
- `app/helpers/public_profiles_helper.rb` -- `public_profile_title(player)` (persona name or "Brother <code>"): the owner's profile title for the owner line.
- `app/helpers/card_details_helper.rb` -- `card_detail_open_label` etc.; `CardStrings.for([view]).rarity_name(rarity)` gives the localised rarity (`catalog.rarity.*`).
- `app/controllers/application_controller.rb` -- `allow_browser versions: :modern` (its options go to `before_action`, so `unless:` works); `default_url_options` keeps the locale.
- `app/views/layouts/application.html.erb` -- `<title>` from `content_for(:title)`, `yield :head`; the status band already has a "Enlist through Steam" sign-in button (`/auth/steam`, `origin: request.path`): the invitation's button needs a different label.
- `app/views/pages/home.html.erb` -- sign-in pattern: `ButtonComponent.new(href: "/auth/steam", method: :post, params: { origin: … }, turbo: false)`; `TextPlateComponent`. `app/controllers/sessions_controller.rb#origin_path` accepts a local path.
- `app/frontend/controllers/*_controller.ts` -- auto-registered by `registerControllers` (file `share_controller.ts` → identifier `share`); `poller_controller.ts` shows the typed `static values`/`declare` style. `app/frontend/styles/card-detail.css` -- tokens only.
- `config/routes.rb` -- the brothers routes and token constraint `/[1-9A-HJ-NP-Za-km-z]{24}/`; `config/environments/production.rb`, `config/deploy.yml` (env `clear:`; the test LXC is `http://192.168.1.6`, `proxy.ssl: false`).
- `config/locales/{en,fr}.yml` -- `public_profiles.*`, `card_details.*` (`owner` exists).
- Tests: `test/controllers/public_profiles_controller_test.rb` (`sign_in`, `hold`, `set_members`), `test/controllers/cards_controller_test.rb` (`assert_request_queries` clears the query cache), `test/system/{card_detail_test,public_profile_test}.rb`, `test/support/catalog_seeds.rb`; fixtures `catalog_card_seasons(:portal_one)` (amethyst), `(:sapphire_card_one)` ("Blue Depths", sapphire), `accounts_players(:player)`.

## Tasks & Acceptance

**Execution:**
- [x] `config/initializers/public_url.rb`, `config/environments/production.rb`, `config/deploy.yml` -- `config.x.public_url = ENV["PUBLIC_URL"].presence&.chomp("/")`; deploy.yml `clear: PUBLIC_URL: http://192.168.1.6` -- the configured base.
- [x] `app/helpers/public_urls_helper.rb` -- `public_url_for(path)`: the configured base + path; without one, `request.base_url` outside production and an error in production -- never a spoofed Host where it matters.
- [x] `config/routes.rb` -- `brother_card` and `brother_card_season` (`number: /\d+/`), token-constrained, to `public_profiles#card`.
- [x] `app/controllers/application_controller.rb`, `app/controllers/public_profiles_controller.rb` -- `allow_browser versions: :modern, unless: :public_read?` (`public_read?` false by default; true for GET/HEAD in `PublicProfilesController`); `card` action: detail by slug and path number or 404, `@owner_holds` from `Game::Quantities` with the owner, the Started shelf and summary as `show`.
- [x] `app/views/public_profiles/{_profile,show,card}.html.erb`, `app/views/public_profiles/_share_tags.html.erb` -- the card page: tags in `:head`, title = og:title, `cards/_detail` (`copies: nil`, owner line or "No longer in …", set links to `brother_set_path` only when `current_season`), the visitor invitation, then the profile partial.
- [x] `app/views/cards/{_detail,show}.html.erb`, `app/controllers/cards_controller.rb` -- `owner_holds:` and `share_url:` locals; share block (button, read-only URL input, `role="status"`) only with a `share_url`; `cards#show` passes it for a holder (`@copies` present and a player).
- [x] `app/frontend/controllers/share_controller.ts`, `app/frontend/styles/card-detail.css` -- the copy behaviour of the intent; styles for the share block, owner line and invitation.
- [x] `config/locales/{en,fr}.yml` -- `public_profiles.card.*` (owner gone, invitation, sign-in label, og description), `card_details.share.*` (button, input label, copied, press Ctrl+C); i18n-tasks clean.
- [x] `test/controllers/public_profiles_card_test.rb`, `test/controllers/cards_controller_test.rb`, `test/system/share_card_test.rb` -- every matrix row (tags, no image tags on the head, canonical, locales, traded away, unknown, spoofed Host with `config.x.public_url` set, the five user agents, CTA landing in the attic, title), the query counts of the new page, no database id; system: copy through a stubbed `navigator.clipboard`, and the fallback with `document.execCommand` stubbed false.

**Acceptance Criteria:**
- Given a player who holds a card, when they share it from its detail and a visitor opens the link, then the visitor sees the sharer's profile with the card's detail first, and the page's tags carry the title and rarity with no image.
- Given `bin/rails test`, `bin/rails test:system`, `npm run typecheck`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `PublicProfilesController#card` reads the season number from `request.path_parameters` only (as 4.3); `@owner_holds` is `Game::Quantities` with the owner (a `quantity: 0` row counts as not held); the shelf is always the Started tab. Queries: visitor 10 (owner by token, card detail, sets, owner's quantity, published season, shelf count, shelf page, totals, progress, summary), signed-in viewer 11; profile show/set counts unchanged (7/8, 9/10); `cards#show` unchanged (4/2).
- `public_read?` (private, false in `ApplicationController`) is `request.get? || request.head?` in `PublicProfilesController`, so every profile page (show, set, card) is open to any browser; other pages still answer 406 to an old browser (tested).
- `public_profiles/_profile` holds the profile body with a `heading:` local (`:h1` on the profile, `:h2` under a shared card, `id="library-heading"` either way); `show.html.erb` renders it with the same markup as before.
- `public_profiles/_share_tags` writes `robots noindex`, `description`, `canonical`, `og:type/site_name/title/description/url/locale`, `twitter:card summary`; `og:site_name` is `layouts.application.application_name` ("gameble"). Helpers `shared_card_title(view)` and `og_locale` in `PublicProfilesHelper`.
- `PublicUrlsHelper#public_url_for` raises `PublicUrlsHelper::MissingPublicUrl` in production without `PUBLIC_URL`; `CardsController#share_url` calls it through `helpers`. The setting lives in `config/initializers/public_url.rb`; `production.rb` only carries a comment.
- `cards/_detail`: `owner_holds:` false renders `public_profiles.card.owner_gone` (`.card-detail__owner--gone`); the share block (`data-controller="share"`, strings as Stimulus values, a primary button, a labelled read-only `input`, an empty `role="status"` paragraph) renders only with `share_url:`.
- `share_controller.ts` also clears the status on each click; a rejected `writeText` falls back to selection and `execCommand`, then the Ctrl+C hint. A system test checks the status is empty after a Turbo cache restore (it fails without the reset in `connect`).
- `card-detail.css`: `.card-detail__body` now grows (`flex: 1 1 auto`) so the link field has room; `.shared-card > *` take the full width so the detail and profile keep their page width.
- Extra test: `test/helpers/public_urls_helper_test.rb` (configured base, request base outside production, error in production).
- `pending-approvals.md`: new entry to set `PUBLIC_URL` to the public HTTPS host (the Cloudflare and manual preview entries were already there; the X image question is settled).

## Plan Change Log

## Review Triage Log

### 2026-10-03 — Review pass
- verdicts: 5 findings — high 0, medium 1, low 4, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` The PUBLIC_URL note (pending-approvals.md) and the production.rb comment said only the shared card page fails without PUBLIC_URL, but `CardsController#show` calls `public_url_for` for every holder, so a holder's card detail is a 500 too — patched: both texts name both pages.
  - `[medium]` `[defer]` The invitation on a shared card leads an older browser (let in by `public_read?`) to a 406 after the Steam round-trip: `SessionsController` and `PagesController` keep `allow_browser :modern` — real; the intent scopes the exception to `PublicProfilesController` GETs and the modern-only rule on sign-in predates this story; deferred and recorded in pending-approvals.md for the author's decision.
  - `[low]` `[patch]` On the fallback copy path the status was cleared and rewritten in the same task, so a repeated press left the `role="status"` region unchanged and was not announced again — patched: `say()` writes in `requestAnimationFrame`; `execCommand` stays in the click.
  - `[low]` `[patch]` Tests expecting `http://www.example.com` failed with `PUBLIC_URL` exported in the shell (read at boot, reset only in teardown) — patched: setup saves and nils `config.x.public_url`, teardown restores it (cards, public card and helper tests); checked with `PUBLIC_URL=https://shell.example`.
  - `[low]` `[patch]` README did not mention `PUBLIC_URL`, now required in production — patched: one line beside the runtime variables.

## Design Notes

- pending-approvals.md already holds the Cloudflare and manual preview check entries (added with epic 4's notes); the X image question was settled by the author on 2026-10-03 (no image at all, even if X shows a bare link), so it is recorded under "Settled" rather than as an open question. New entry: set `PUBLIC_URL` to the public HTTPS host once one exists.
- Copy: when `writeText` rejects (permission), fall back to selecting the input and `execCommand`, then the Ctrl+C hint.

## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `npm run typecheck && bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.

**Manual checks (if no CLI):**
- After deploy (author): paste a share link in Discord, X and WhatsApp and check each preview.

## Auto Run Result

**Summary:** A player who holds a card-season gets a "Share this card" button on its detail, copying the season-qualified absolute link `/<locale>/brothers/<token>/cards/<slug>/seasons/<n>` (clipboard in a secure context, else a selected read-only field and `execCommand`, with "Link copied" / "Press Ctrl+C to copy" in a status region). The link opens the owner's public profile with the card's detail first, an owner line titled from 4.4 (or "No longer in …'s collection"), a visitor-only invitation whose sign-in lands in the attic, then the profile. The head carries `og:*`, `twitter:card summary`, canonical, description and `noindex`, title "<title> — <rarity>" in the URL's locale, and no image tag. Absolute URLs come from `PUBLIC_URL` (request base in development and test). Profile pages skip `allow_browser`, so Discordbot, Twitterbot, WhatsApp, Firefox 92 and iOS 16 Safari get them.

**Files changed:**
- `config/initializers/public_url.rb`, `config/environments/production.rb`, `config/deploy.yml`, `README.md` -- the public base from `PUBLIC_URL`.
- `app/helpers/public_urls_helper.rb` -- `public_url_for(path)`, an error in production without a base.
- `config/routes.rb` -- `brother_card`, `brother_card_season`.
- `app/controllers/application_controller.rb`, `app/controllers/public_profiles_controller.rb` -- `public_read?`; the `card` action.
- `app/controllers/cards_controller.rb` -- the holder's share URL.
- `app/helpers/public_profiles_helper.rb` -- `shared_card_title`, `og_locale`.
- `app/views/public_profiles/{card,_profile,_share_tags,show}.html.erb`, `app/views/cards/{_detail,show}.html.erb` -- the shared page, its tags, the extracted profile body, the share block and owner lines.
- `app/frontend/controllers/share_controller.ts`, `app/frontend/styles/card-detail.css` -- copy behaviour and styles.
- `config/locales/{en,fr}.yml` -- `public_profiles.card.*`, `card_details.share.*`.
- `test/controllers/public_profiles_card_test.rb`, `test/controllers/cards_controller_test.rb`, `test/helpers/public_urls_helper_test.rb`, `test/system/share_card_test.rb` -- every matrix row, query counts (10 / 11), no ids, the copy and its fallback.

**Review:** quick lens, 5 findings. Patched 4 (low: PUBLIC_URL note understated the failing pages; low: status not re-announced on repeated fallback presses; low: tests broke with PUBLIC_URL in the shell; low: README). Deferred 1 (medium: an older browser let onto a shared card meets a 406 when it signs in from the invitation; pending-approvals.md). Rejected 0.

**Follow-up review:** false -- patched counts: high 0, medium 0, low 4.

**Verification:** after the patches, `bin/rails test` 883 runs 0 failures; `bin/rails test:system` 46 runs 0 failures; `npm run typecheck`, `packwerk check`, `rubocop` (286 files) and `i18n-tasks missing` clean.

**Residual risks:** the deferred old-browser sign-in dead end; `PUBLIC_URL` must become the public HTTPS host once one exists, and an unset value breaks the card detail for holders in production; real previews on Discord, X and WhatsApp are unchecked until a public HTTPS host and the Cloudflare rule exist; English and French copy (invitation, og description, share labels) is the implementer's wording.
