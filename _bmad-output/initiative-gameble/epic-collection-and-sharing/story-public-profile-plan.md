---
title: 'Public profile'
type: 'feature'
ticket: '4'
created: '2026-10-02'
status: 'draft'
baseline_revision: ''
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md', '{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/story-library-of-sets-plan.md', '{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/story-tome-slots-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player's collection can only be seen by that player; there is no page to show it to others (CAP-8; epic 4, R4, R6).

**Approach:** Each player gets a public profile at a link built on their random token: their library — the shelf with their progress (the sets they have started first) and their tomes with their cards — readable by anyone, signed out included. The profile is titled with the player's Steam persona name, read from Steam at each sign-in and stored on the player (decided by the author on 2026-10-03, superseding the "Brother" plus display code title). A signed-in player finds the link to their own profile in the library.

## Boundaries & Constraints

**Always:**
- Routes: `resources :brothers, only: :show, param: :token, controller: :public_profiles` (`brother_path`) and `GET /<locale>/brothers/:token/library/:kind/:key` (`brother_set_path`, 4.2's kind constraint); `token` constrained to `/[1-9A-HJ-NP-Za-km-z]{24}/`. `PublicProfilesController`, lazy keys `public_profiles.*`, `PagePolicy#show?`.
- `Accounts::PlayerByToken.call(token)` → the player or nil, no query for a non-String or blank token. `Accounts::PublicProfile.visible?(player, viewer:)` (in `packs/accounts`) → false for a banned player (epic 7 adds hidden and deleted; the owner will still see their own hidden profile). An unknown token or an invisible profile renders one localised `public_profiles/unavailable` page with the layout and status 404 (`render`, not an exception), so a ban cannot be told from a missing player.
- Persona name: `Steam::WebApi#get_player_summary(steamid:)` (`ISteamUser/GetPlayerSummaries/v2`, key redacted) returns the `personaname`; `Accounts::SignIn` stores it on the player (`persona_name`, nullable string, expand-only migration) at every sign-in, so a renamed Steam account is picked up on its next sign-in. A Steam failure or an empty name never blocks sign-in: the stored name is kept, or stays nil. Tests stub the client.
- Title (`content_for(:title)` too): `public_profiles.title` ("%{name}" from `persona_name`, escaped as user content); a player with no stored name falls back to `public_profiles.fallback_title` ("Brother %{code}" / "Confrère %{code}", `code` = the first six Crockford base32 characters of SHA-256(token)). The name is a display label, not unique; reports and moderation key on the token. It is personal data: epic 7's export and deletion must include it (recorded in the epic Notes).
- `<meta name="robots" content="noindex">` on profile pages.
- Content: the 4.1 `_shelf` and 4.2 `_tome` partials with the owner's `Game::SetProgress` and `Game::Quantities` (never the viewer's) and path builders on the profile routes; on the profile the shelf has an extra first tab "Started" (sets with `owned > 0`, the default) besides the three kinds (Decision); spines with `owned == total` carry a visible "Complete" label; card faces link to their card-season detail (4.3); links carry `data-turbo-prefetch="false"`.
- Header: `Game::CollectionSummary.call(player)` (at most two queries, over the published season's card-seasons with `quantity > 0`) → `{ distinct_cards:, complete_sets: }`, shown with one/other plurals in both locales.
- The library shows "Your public profile" to a signed-in player; a visitor sees no such link; a banned viewer counts as a visitor.
- Queries asserted exactly: profile shelf for a visitor — owner by token, season, shelf count, shelf page, totals, progress, summary (7), +1 for a signed-in viewer's lookup; profile tome — owner by token plus 4.2's tome queries with the owner's progress and quantities.
- No database id anywhere; the token only in URLs; no Steam id on the page.
- The epic Notes record: the player token is a public, non-secret handle; friend invites (epic 5) use a separate secret; link revocation is "hide profile" (epic 7).
- Copy in `fr` and `en`.

**Never:** no sharing of a card (4.5); no profile settings (epic 7); no report button (epic 7); no Steam id or avatar stored or shown.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Visitor | a player's profile link | the persona name as title, their started sets first, header counts | — |
| Tabs | "Started" / a kind | started sets / that kind's sets with the owner's progress | — |
| Complete | a set fully owned | its spine labelled "Complete"; counted in the header | — |
| Tome | open one of their tomes | their cards and copies, empty slots naming the rest | — |
| Owner's data | the viewer owns other cards | the owner's progress, not the viewer's | — |
| Empty collection | a player with no card | "Started" empty text; header 0 | — |
| No season | nothing published | the shelf's no-season text; header 0 | — |
| Unknown / malformed | random 24-char token / a 5-char token | the unavailable page, 404 / routing 404, no query | — |
| Banned | banned owner | the same unavailable page, 404 | — |
| Bad tome | wrong kind or key under a profile | 404 | — |
| Own link | signed-in player / visitor in the library | "Your public profile" / none | — |
| Robots | any profile page | `noindex` meta | — |
| Locale | `fr` | "Confrère …", French labels and plurals | — |
| Ids | the page | no database id; token only in URLs | — |

</frozen-after-approval>

## Code Map

- `app/controllers/library_controller.rb`, `app/views/library/{show,_shelf,_tome,set}.html.erb`, `app/components/set_label.rb` (4.1, 4.2).
- `packs/game/app/queries/game/{set_progress,quantities}.rb`, `packs/catalog/app/queries/catalog/{season_shelf,set_totals,set_slots,card_views}.rb`.
- `packs/accounts/app/queries/accounts/player_by_id.rb`, `app/models/accounts/player.rb` (token).
- `packs/accounts/app/operations/accounts/sign_in.rb`, `packs/steam/app/clients/steam/web_api.rb` -- where the persona name is read and stored.

## Tasks & Acceptance

**Execution:**
- [ ] `packs/accounts/app/queries/accounts/player_by_token.rb`, `app/models/accounts/public_profile.rb`, `packs/game/app/queries/game/collection_summary.rb`.
- [ ] `app/controllers/profiles_controller.rb`, routes, views, link from the library, locales.
- [ ] `test/` -- every matrix row.

**Acceptance Criteria:**
- Given a player's profile link, when a visitor opens it, then they see that player's Steam persona name as the title, that player's set progress and, in a tome, that player's cards; an unknown token is a 404 and a banned player's profile is not available.
- Given `bin/rails test`, `bin/rails test:system`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
