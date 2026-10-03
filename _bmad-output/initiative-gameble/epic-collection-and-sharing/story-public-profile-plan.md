---
title: 'Public profile'
type: 'feature'
ticket: '4'
created: '2026-10-02'
status: 'built'
baseline_revision: 'aa79a41db73f41b8e6e125a29e79b3e958d7e51c'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md', '{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/story-library-of-sets-plan.md', '{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/story-tome-slots-plan.md']
warnings: ['oversized']
deferred:
  - summary: >-
      The epic Notes lines the intent requires (the player token is a public, non-secret handle; friend invites use a separate secret; link revocation is "hide profile") are not in the epic file.
    evidence: |-
      The build never writes a ticket file (bmad-build-auto ticket resolution rule), so epic-collection-and-sharing.md only carries the 2026-10-03 persona-name decision; the lines are queued in pending-approvals.md for the author to add.
    location: >-
      _bmad-output/initiative-gameble/epic-collection-and-sharing/epic-collection-and-sharing.md (Notes)
    severity: medium
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

- `packs/accounts/app/models/accounts/player.rb` (`has_secure_token :token`: 24 base58 chars, `banned?`), `packs/accounts/app/operations/accounts/sign_in.rb` (`call(steam_id:)`), `packs/accounts/app/queries/accounts/player_by_id.rb` (query pattern). Accounts depends on no pack (`packs/accounts/package.yml`): it never calls Steam.
- `app/controllers/sessions_controller.rb` -- the web layer orchestrates sign-in (`Steam::SignInIdentity` then `Accounts::SignIn`); the persona name is fetched here and passed to `Accounts::SignIn`.
- `packs/steam/app/clients/steam/web_api.rb` -- `get(path, params)` adds and redacts the key; `connection` retries 4 times with backoff up to 60 s (too slow for a sign-in); class attributes `adapter`, `retry_interval`.
- `config/initializers/steam.rb` -- outside production the key is read from `config/steam_api.key`, which EXISTS on this machine: in tests an unstubbed Web API call would reach the real Steam API with the author's key.
- `test/support/steam_api_stubs.rb` (`stub_steam_api` / `unstub_steam_api`, Faraday test stubs, `API_KEY`), `test/packs/steam/web_api_test.rb`, `test/controllers/sessions_controller_test.rb`. About 25 test files sign in through the OmniAuth mock and `SessionsController#create`.
- `app/controllers/library_controller.rb` -- `KINDS`, `SHELF_SIZE`, `MAX_PAGE`, `Spine(key, label, owned, total)`, `load_shelf(season)`, `page_param`, `set` action (season once, `SetSlots`, `CardViews`, `Quantities`). Keep its behaviour and its query counts (6/4 shelf, 9/6 set).
- `app/views/library/{show,set,_shelf,_tome}.html.erb` -- `_shelf` iterates `LibraryController::KINDS` for tabs and calls `set_url.call(kind, key, pagy.page)` with the open tab's kind; `_tome` already links faces and slots via `link_to_card_detail` (`app/helpers/card_details_helper.rb`, `data-turbo-prefetch="false"`); `_tome`'s `<h1 id="library-heading">`.
- `packs/catalog/app/queries/catalog/{season_shelf,set_totals,set_slots,card_views,published_season}.rb`, `packs/game/app/queries/game/{set_progress,quantities}.rb` -- reuse as is (`SeasonShelf::ORDER` per kind).
- `app/views/layouts/application.html.erb` -- `content_for(:title)`, `yield :head`, `content_for(:back_button)`; `app/policies/page_policy.rb`.
- `config/routes.rb` (inside `scope ":locale"`), `config/locales/{en,fr}.yml` (`library.*`; French plurals need a `zero:` form, see `library.show.progress`), `config/i18n-tasks.yml`.
- `test/fixtures/accounts/players.yml` -- fixture tokens (`player-token-0000000000001`) do not match the base58 route constraint; nothing depends on their literal value.
- `test/support/catalog_seeds.rb` (`publish_sets_draft`, `seed_published_sets`), `test/controllers/library_set_test.rb` (`sign_in`, `hold`, `set_members`, `assert_request_queries` clears the query cache first), `test/system/tome_test.rb`.
- `db/schema.rb` (`accounts_players`), `db/migrate/` (timestamped names, latest `20261003020000`).

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261003030000_add_persona_name_to_accounts_players.rb`, `db/schema.rb` -- `add_column :accounts_players, :persona_name, :string` (nullable). Migrate the TEST database only (`RAILS_ENV=test bin/rails db:migrate`); never touch the development database.
- [x] `packs/steam/app/clients/steam/web_api.rb` -- `get_player_summary(steamid:)`: one `GET /ISteamUser/GetPlayerSummaries/v2/` with `steamids`, one attempt (no retry) and a 5 s timeout; returns the stripped `personaname` of the player whose `steamid` matches, nil when Steam answers no such player or an empty name; raises `Steam::WebApi::Error` (key redacted) on failure or a malformed answer.
- [x] `packs/accounts/app/models/accounts/player.rb`, `packs/accounts/app/operations/accounts/sign_in.rb` -- `call(steam_id:, persona_name: nil)`: after the ban check, a present name (stripped, cut to 64 characters) different from the stored one is saved; nil or blank keeps the stored one. Comment updated (the player now has a display name).
- [x] `app/controllers/sessions_controller.rb` -- before `Accounts::SignIn`, fetch the name: `Steam::WebApi::Error` logged as a warning, any other error `Rails.error.report`ed, both give nil; sign-in goes on either way.
- [x] `test/test_helper.rb`, `test/support/steam_api_stubs.rb` -- safety net: before the workers fork, `Steam::WebApi.adapter` and `Steam::StoreApi.adapter` default to an empty Faraday test stub set, so no test can reach Steam; `stub_player_summary(steam_id, name)` / a failing variant in `SteamApiStubs`.
- [x] `packs/accounts/app/queries/accounts/player_by_token.rb`, `packs/accounts/app/models/accounts/public_profile.rb` -- `PlayerByToken.call(token)`; `PublicProfile.visible?(player, viewer:)` (false for nil or banned); `PublicProfile.code(token)` (first six Crockford base32 chars of SHA-256(token), from the digest's leading 30 bits, alphabet `0123456789ABCDEFGHJKMNPQRSTVWXYZ`).
- [x] `packs/catalog/app/queries/catalog/season_shelf.rb` -- `every_kind(season:)`: the season's sets of all kinds, ordered tome, publisher, best of year, then each kind's `ORDER`; nil without a season.
- [x] `packs/game/app/queries/game/started_sets.rb`, `packs/game/app/queries/game/collection_summary.rb` -- `StartedSets.relation(player, sets)`: `sets` narrowed to those with a member the player holds (`quantity > 0`), as one subquery (lazy, so Pagy's count and page stay two queries). `CollectionSummary.call(player, season: Catalog::PublishedSeason.call)` → `Summary(distinct_cards:, complete_sets:)`: one query when given the season (complete = a set with members, all held), zeros without a query for a nil player or season.
- [x] `app/controllers/concerns/shelf_loading.rb`, `app/controllers/library_controller.rb` -- extract `load_shelf` / `page_param` so both controllers share them; `Spine` gains `kind` (each spine's own set kind).
- [x] `config/routes.rb`, `app/controllers/public_profiles_controller.rb` -- the two routes of the intent; `show` (`kind` param: `started` default, or a `KINDS` value; anything else → `started`), `set` (as `LibraryController#set` with the owner; `tab=started` keeps the Started shelf beside the tome); unknown token or `visible?` false → `render "public_profiles/unavailable", status: :not_found`.
- [x] `app/views/library/_shelf.html.erb` -- locals `tabs:` (default `LibraryController::KINDS`) and `mark_complete:` (default false); spines link with `set_url.call(spine.kind, spine.key, pagy.page)` and are current by their own kind; a visible "Complete" (`library.show.complete`) on a spine with `total > 0 && owned == total` when `mark_complete`; tab and spine links `data-turbo-prefetch="false"`.
- [x] `app/views/public_profiles/{show,set,unavailable}.html.erb`, `app/views/library/show.html.erb`, `app/frontend/styles/library.css` -- profile pages (noindex in `:head`, title, header counts, shelf, tome); "Your public profile" link in the library for `current_player`.
- [x] `config/locales/{en,fr}.yml` -- `public_profiles.*`, `library.show.tabs.started`, `library.show.empty.started`, `library.show.complete`, `library.show.public_profile`; i18n-tasks clean.
- [x] `test/fixtures/accounts/players.yml` -- valid 24-char base58 tokens.
- [x] `test/packs/steam/web_api_test.rb`, `test/controllers/sessions_controller_test.rb`, `test/packs/accounts/{player_by_token,public_profile,sign_in}_test.rb`, `test/packs/game/{started_sets,collection_summary}_test.rb`, `test/controllers/public_profiles_controller_test.rb`, `test/controllers/library_controller_test.rb`, `test/system/public_profile_test.rb` -- every matrix row, the exact query counts, sign-in storing, renaming, keeping on failure or empty name, no database id or Steam id in the page.

**Acceptance Criteria:**
- Given a player's profile link, when a visitor opens it, then they see that player's Steam persona name as the title, that player's set progress and, in a tome, that player's cards; an unknown token is a 404 and a banned player's profile is not available.
- Given a player whose Steam persona name changed, when they sign in again, then their profile shows the new name; when Steam fails during sign-in, then they are signed in and the stored name is kept.
- Given `bin/rails test`, `bin/rails test:system`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `Steam::WebApi#get_player_summary` uses its own Faraday connection (`summary_connection`: no retry middleware, 5 s timeout and open timeout); `get` takes the connection as an optional third argument. A non-String `personaname` raises as a malformed answer.
- `Accounts::SignIn` reads `previously_new_record?` before storing the name (the save would reset it), so `PlayerRegistered` is still published on a first sign-in with a name. The same name (after strip and cut) writes nothing.
- `SessionsController#persona_name` runs before `Accounts::SignIn` for every verified Steam id, a banned one included (the ban check then refuses it and nothing is stored).
- `test/test_helper.rb` sets both clients' adapters to empty Faraday stubs before the fork; `SteamApiStubs#unstub_steam_api` restores them. An unstubbed `GetPlayerSummaries` call during the ~25 sign-in tests raises `Faraday::Adapter::Test::Stubs::NotFound` (not a `Faraday::Error`), which `SessionsController` reports and ignores; the sign-in goes on.
- `ShelfLoading` (concern) holds `KINDS`, `SHELF_SIZE`, `MAX_PAGE`, `Spine(kind, key, label, owned, total)`, `load_shelf(relation, owner:)` and `page_param`; `LibraryController::KINDS` / `::Spine` still resolve through it. Query counts of the library unchanged (6/4, 9/6).
- `Catalog::SeasonShelf.every_kind(season:)` orders by a `CASE` on the kind, then each kind's own order (genre, volume; key; key DESC). `Game::StartedSets.relation` is `sets.where(id: <memberships ⋈ holdings, quantity > 0, select set_id>)`; nil player → `sets.none`.
- `Game::CollectionSummary.call(player, season:)`: the default is a private sentinel, so a nil player costs no query even without a season; with no season given it looks the published one up (two queries). One SQL with two scalar subqueries.
- `PublicProfilesController`: `before_action`s authorize then load the owner; the unavailable page is rendered from the `before_action` (halts the action). The Started tab link carries no `kind`; Started spine links add `tab=started`. "Back to the shelf" on a profile tome keeps the open tab and the given page.
- Every profile page's `<title>` (shelf and tome) is the owner's name (`public_profiles.title` / `fallback_title`), via `PublicProfilesHelper#public_profile_title`. The persona name is cleaned of control characters (a NUL byte would fail the write) before it is stripped and cut. Pager links carry `data-turbo-prefetch="false"` too (Pagy's `anchor_string`).
- Query counts asserted: profile shelf 7 (visitor) / 8 (signed-in viewer); profile tome 9 / 10; an unknown 24-character token 1 (the lookup); a malformed token 0 (routing 404).
- The epic Notes lines and the development-database migration went to `pending-approvals.md`.

## Plan Change Log

## Review Triage Log

### 2026-10-03 — Review pass
- verdicts: 5 findings — high 0, medium 2, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` A Steam persona name holding a NUL byte made `player.update!` raise in PostgreSQL inside the sign-in transaction, so the sign-in failed (the intent says a Steam name never blocks sign-in) — patched: `store_persona_name` removes `[[:cntrl:]]` before stripping and cutting; test signs in with "Ga\u0000be\n" and stores "Gabe".
  - `[low]` `[patch]` The shelf's pager links (`series_nav`) lacked `data-turbo-prefetch="false"`, which the intent asks of the profile's links — patched: `series_nav(anchor_string: 'data-turbo-prefetch="false"')`; a 60-tome profile test and the library's 120-tome test assert every pager link carries it.
  - `[medium]` `[defer]` The epic Notes lines the intent asks for (public token, separate invite secret, revocation by "hide profile") are not in the epic file — real, but this build never writes a ticket file; recorded in pending-approvals.md for the author and in `deferred`.
  - `[low]` `[patch]` The profile tome page's `<title>` used a new key ("<set> · <name>") instead of the intent's title rule (`public_profiles.title` / `fallback_title`, `content_for(:title)` too) — patched: the tome page's title is `public_profile_title(@owner)`; the `public_profiles.set.title` key removed; test expects the name.
  - `[low]` `[reject]` The persona request's `timeout: 5` and `open_timeout: 5` apply separately, so a slow Steam could hold a sign-in about 10 s rather than 5 s — real but rare (Steam slow both to connect and to answer), still bounded and retry-free; an exact total bound needs a wrapping timer, more than a direct correction.

## Design Notes

- The epic Notes lines the intent asks for (public token, separate invite secret, revocation by "hide profile") cannot be written by this run, which never writes a ticket file; they go to `pending-approvals.md`.
- "Complete" labels and the Started tab are the profile's (`mark_complete: true`, `tabs: ["started", *KINDS]`); the player's own library keeps 4.1's three tabs and no label.
- Started-tab spine links add `tab: "started"` so the tome opens beside the Started shelf at the same page; without it, beside its kind's shelf (4.2's rule).
- The profile tome page shows no header counts (its query count excludes the summary); it names the owner above the tome, linking back to the profile.

## Verification

**Commands:**
- `RAILS_ENV=test bin/rails db:migrate` -- expected: the column added to the test database only.
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.

## Auto Run Result

**Summary:** Each player has a public profile at `/<locale>/brothers/<token>`, readable signed out: titled with their Steam persona name (read with `GetPlayerSummaries` at each sign-in and stored on the player; "Brother <code>" / "Confrère <code>" as fallback), header counts of distinct cards and complete sets, and their library with a first "Started" tab, "Complete" labels and their tomes at `/<locale>/brothers/<token>/library/:kind/:key`, all with the owner's progress and copies. An unknown token or a banned owner renders one unavailable page (404); pages carry `noindex`. The library links a signed-in player to their own profile.

**Files changed:**
- `db/migrate/20261003030000_add_persona_name_to_accounts_players.rb`, `db/schema.rb` -- nullable `persona_name` (test database only).
- `packs/steam/app/clients/steam/web_api.rb` -- `get_player_summary(steamid:)`, one attempt, 5 s timeouts.
- `packs/accounts/app/operations/accounts/sign_in.rb`, `packs/accounts/app/models/accounts/player.rb` -- stores the cleaned name at sign-in.
- `app/controllers/sessions_controller.rb` -- reads the name before signing in; a failure never blocks.
- `packs/accounts/app/queries/accounts/player_by_token.rb`, `packs/accounts/app/models/accounts/public_profile.rb` -- owner lookup, visibility, fallback code.
- `packs/catalog/app/queries/catalog/season_shelf.rb`, `packs/game/app/queries/game/{started_sets,collection_summary}.rb` -- the Started shelf and the header counts.
- `app/controllers/concerns/shelf_loading.rb`, `app/controllers/library_controller.rb`, `app/controllers/public_profiles_controller.rb`, `app/helpers/public_profiles_helper.rb`, `config/routes.rb` -- shared shelf loading and the profile pages.
- `app/views/library/{_shelf,show}.html.erb`, `app/views/public_profiles/{show,set,unavailable}.html.erb`, `app/frontend/styles/library.css`, `config/locales/{en,fr}.yml` -- views, styles and copy.
- `test/test_helper.rb`, `test/support/steam_api_stubs.rb`, `test/fixtures/accounts/players.yml` -- no test can reach Steam; base58 fixture tokens.
- `test/packs/**`, `test/controllers/{public_profiles_controller,library_controller,sessions_controller}_test.rb`, `test/system/public_profile_test.rb` -- every matrix row and the query counts.

**Review:** quick lens, 5 findings. Patched 3 (medium: NUL byte in the name blocked sign-in; low: pager links without `data-turbo-prefetch="false"`; low: tome page title off the intent's rule). Deferred 1 (medium: epic Notes lines, not writable by the build; in pending-approvals.md). Rejected 1 (low: the persona request can take about 10 s, connect and read timeouts adding up; rare, bounded, an exact bound needs more than a direct fix).

**Follow-up review:** false -- patched counts: high 0, medium 1, low 2.

**Verification:** after the patches, `bin/rails test` 857 runs 0 failures; `bin/rails test:system` 43 runs 0 failures; `packwerk check`, `rubocop` (281 files) and `i18n-tasks missing` clean. Migration run on the test database only.

**Residual risks:** the development database still needs `bin/rails db:migrate` (pending-approvals.md); a banned player's sign-in still makes one Steam call (nothing stored); sign-in tests that do not stub the name lookup report a harmless stub miss through `Rails.error.report`; French copy ("Entamées", "Complète", the unavailable text) is the implementer's choice.
