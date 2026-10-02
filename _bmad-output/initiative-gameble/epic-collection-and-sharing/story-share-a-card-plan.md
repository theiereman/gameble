---
title: 'Share a card'
type: 'feature'
ticket: '5'
created: '2026-10-02'
status: 'draft'
baseline_revision: ''
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md', '{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/story-card-detail-plan.md', '{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/story-public-profile-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player who pulls a card they are proud of cannot show it off; a link pasted on Discord, X or WhatsApp should make friends want to play (CAP-9; EXPERIENCE Flow 1; epic 4, R5, R6).

**Approach:** On a card's detail, a player who holds that card-season gets a share button that copies a link to their public profile with that card-season shown; the page shows the card's detail with an owner line and, for a visitor, an invitation to play, and its Open Graph and Twitter tags give the card's title and rarity and no game image.

## Boundaries & Constraints

**Always:**
- Routes: `GET /<locale>/brothers/:token/cards/:slug` and `GET /<locale>/brothers/:token/cards/:slug/seasons/:number` (`brother_card_path`, `brother_card_season_path`, mirroring 4.3), in `PublicProfilesController`; owner lookup, visibility and the unavailable page exactly as in 4.4 (an invisible owner wins over a bad slug); an unknown slug, numeric slug or season → 404 as in 4.3.
- The page: 4.4's profile with 4.3's `cards/_detail` first. The partial takes `copies:` (nil here: never the viewer's count), `owner:` (the owner line "From the collection of Brother <code>"), `share_url:` (nil here; only `cards#show` passes it, for a holder) and a set-path builder (here `brother_set_path`, so set links stay on the owner's profile). If the owner does not hold that card-season (traded away, or a crafted URL), the detail shows "No longer in Brother <code>'s collection" instead of the owner line, status 200. `content_for(:title)` = the og:title.
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

- `app/views/cards/_detail.html.erb`, `app/controllers/cards_controller.rb`, `packs/catalog/app/queries/catalog/card_detail.rb` (4.3).
- `app/controllers/profiles_controller.rb`, `packs/accounts/app/queries/accounts/player_by_token.rb` (4.4).
- `app/components/card_strings.rb` (rarity names), `app/views/layouts/application.html.erb` (`yield :head`), `app/views/pages/home.html.erb` (3.8's sign-in button form).
- `app/frontend/controllers/` (Stimulus).

## Tasks & Acceptance

**Execution:**
- [ ] `ProfilesController#card` (or equivalent), route, view, tags partial, share button and `share_controller.ts`, locales.
- [ ] `test/` -- every matrix row; a system test of the copy.

**Acceptance Criteria:**
- Given a player who holds a card, when they share it from its detail and a visitor opens the link, then the visitor sees the sharer's profile with the card's detail first, and the page's tags carry the title and rarity with no image.
- Given `bin/rails test`, `bin/rails test:system`, `npm run typecheck`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `npm run typecheck && bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.

**Manual checks (if no CLI):**
- After deploy (author): paste a share link in Discord, X and WhatsApp and check each preview.
