---
title: 'Card detail'
type: 'feature'
ticket: '3'
created: '2026-10-03'
status: done
baseline_revision: 'b818a88e4671f1ab2d8c2b4382a91c80eeaa9044'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md', '{project-root}/_bmad-output/initiative-gameble/spec-gameble/spec-gameble.md', '{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/story-tome-slots-plan.md']
warnings: ['oversized']
deferred:
  - summary: >-
      An empty slot's link is named by card_details.open, which hides its visible "Missing card" text from screen readers.
    evidence: |-
      aria-label on a.card-link (link_to_card_detail) overrides the link content; an empty slot and an owned face both read "<title>, <rarity>, season n". The intent-contract mandates that name; the author must decide (pending-approvals.md).
    location: >-
      app/helpers/card_details_helper.rb:link_to_card_detail, app/views/library/_tome.html.erb
    severity: medium
---

<intent-contract>

## Intent

**Problem:** A card cannot be opened to see the game it stands for, its credits and the sets it belongs to (CAP-7; epic 4, R3, R6).

**Approach:** A card's detail page, addressed by the card's slug: the large face and, beside it, the title, short description, release year, rarity, season, sets (each leading to its tome), publisher and copyright, the viewer's copies, and a link to the game's Steam store page, in the viewer's language. Cards in tomes and on the pack result page lead to it. Signed out, it opens too.

## Boundaries & Constraints

**Always:**
- Routes `GET /<locale>/cards/:slug` (the card-season of the published season) and `GET /<locale>/cards/:slug/seasons/:number` (that season's card-season); the slug is looked up with `find_by(slug:)` only (never `friendly.find`, which falls back to the primary key); unknown slug, a numeric id as slug, or a card absent from the season asked → 404. `PagePolicy#show?`. Helper names under `card_detail_*`; lazy locale keys under `card_details.*` (not `cards.*`, which `CardStrings` uses).
- `Catalog::CardDetail.call(slug:, locale:, season_number: nil)` → a struct: the 3.5 `CardView`, `short_description` (nil-able), `publisher`, `credit`, `store_url`, the sets of that season holding it as objects with `kind`, `key`, `params` in tab order (tome, publisher, best_of_year), and `card_season_id` (server-side only, never rendered). `Game::Quantities` (4.2) for the viewer's copies of that card-season.
- Page (plain parchment; `content_for(:title)` the card title): the large `CardComponent` face; the fields, rows left out when nil; sets as links to their tomes only for the published season (older seasons: labels without links); "You hold n copies" (one/other plurals) for a player with copies of that card-season; the credit as plain text with `white-space: pre-line` (Steam's English legal notice, not localised); the Steam link with `rel="noopener noreferrer external"` and `target="_blank"`, `?l=french` added in `fr`. The description is never on the card face. The body is a reusable partial `cards/_detail` (detail, copies, optional owner line) for 4.5's shared card.
- Links to it: owned faces and empty slots in a tome (4.2), and the faces of the pack page's later-visit branch (3.6), each wrapped in a link (`display: inline-block`, ink `:focus-visible` outline, `data-turbo-prefetch="false"`) named by `card_details.open` ("%{title}, %{rarity}, season %{season}") to the card-season's own route (slug and season number); the 3.5 markup inside unchanged; "×n" outside the link. Links from the reveal island are deferred (ticket verify reworded).
- Queries per request (asserted exactly): player — lookup, card detail, sets, quantities (4); visitor (2).
- Copy in `fr` and `en`; no database id anywhere.
**Never:** no share button (4.5); no trading; no editing.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Detail | a card of the published season, `en` | title, description, year, rarity name, season number, sets, publisher, credit, Steam link | — |
| French | same in `fr` | French title and description; French labels | — |
| No publisher / credit | nil publisher, nil credit | those rows left out | — |
| Copies | player with 2 copies / none / visitor | "You hold 2 copies" / nothing / nothing | — |
| Sets | a card in a publisher set and a tome | two links to their tomes, labelled | — |
| From a tome | click an owned face | its detail | — |
| From the pack page | later visit, click a face | its detail | — |
| Unknown | bad slug, card not in the published season | 404 | — |
| Visitor | signed out | the detail | — |
| Older season | `/cards/:slug/seasons/1` with season 2 published | season 1's rarity and dust; set labels without links | — |
| Numeric slug | `/cards/123` | 404 | — |
| No set / no description | a card in no set; nil description | those rows left out | — |
| One copy | 1 copy | "You hold 1 copy" | — |
| Empty slot link | a visitor clicks an empty slot | the card's detail | — |

</intent-contract>

## Code Map

- `packs/catalog/app/queries/catalog/card_views.rb` -- the one-query pluck pattern (columns, joins on `catalog_card_texts` by locale, enum names back to `CardView`); `CardDetail` follows it and builds the same `CardView` (`id:` = slug, `dust:` via `CardSeason.dust_tiers.fetch`). A card-season with nil rarity / dust (draft) is not found.
- `packs/catalog/app/queries/catalog/set_slots.rb` -- `SetSlots::SetRef(kind, key, params)`: reuse it for the detail's sets. `published_season.rb` -- "published season" = highest-numbered `status: published`; fold it into the detail query (subquery), not a separate query.
- `packs/catalog/app/models/catalog/{card,card_text,card_season,set,set_membership,season}.rb` -- read only. `catalog_cards`: `slug`, `release_date`, `image_url`, `store_url` (Steam, `https://store.steampowered.com/app/<id>/…`), `publisher`, `credit` (nullable); `catalog_card_texts`: `title`, `short_description` (nullable). Never `Card.friendly.find`.
- `packs/game/app/queries/game/quantities.rb` -- `Game::Quantities.call(player, [id])`, no query for nil player.
- `app/components/{card_component,card_strings,set_label}.rb` -- `CardComponent.new(card:, strings:, size: :large)`; `CardStrings.for([view])`; `SetLabel.for(set_ref)` names a set. Do not change their markup.
- `app/controllers/library_controller.rb` -- pattern (`authorize :page, :show?`, `RecordNotFound` for 404, `current_player`). `app/views/library/_tome.html.erb` -- owned faces and `.slot` empty slots to wrap in links; "×n" + visually-hidden copies stay outside the link. `app/views/packs/show.html.erb` -- the later-visit `<ol class="pack-result__cards">` faces to wrap; the reveal island branch untouched.
- `app/frontend/styles/library.css` (open tome, `.slot`), `app/frontend/entrypoints/application.css` (imports; add a `card-detail.css`), `tokens.css` -- tokens only, no raw values.
- `config/locales/{en,fr}.yml`, `config/routes.rb` (inside `scope ":locale"`).
- Tests: `test/controllers/library_set_test.rb` (its `assert_select "a[href*='/cards/']", false` must become the opposite; its query counts stay 9 / 6), `test/controllers/packs_controller_test.rb`, `test/system/{tome_test,pack_reveal_test}.rb`, `test/support/catalog_seeds.rb` (`publish_sets_draft`, `seed_card_seasons`), `assert_request_queries` helper pattern (clear the query cache first).

## Tasks & Acceptance

**Execution:**
- [x] `packs/catalog/app/queries/catalog/card_detail.rb` -- `Catalog::CardDetail.call(slug:, locale:, season_number: nil)` → `Detail(view, short_description, publisher, credit, store_url, sets, card_season_id, current_season)` or nil; one query for the card / text / card-season / season (published only; nil number → highest published; `current_season` true when it is the highest published), one for its sets (`SetRef`s ordered tome, publisher, best_of_year, then key) -- the Catalog read for the page.
- [x] `config/routes.rb` -- `get "cards/:slug" => "cards#show", as: :card` and `get "cards/:slug/seasons/:number" => "cards#show", as: :card_season` (`number: /\d+/`).
- [x] `app/controllers/cards_controller.rb` -- `show`: `authorize :page, :show?`; detail or `RecordNotFound`; `@copies = Game::Quantities.call(current_player, [id]).fetch(id, nil)`; `content_for(:title)` in the view; helper `card_detail_store_url(url)` (adds `l=french` in `fr`, merging any query) and `card_detail_open_label(view, strings)`.
- [x] `app/views/cards/show.html.erb`, `app/views/cards/_detail.html.erb` -- the page (back button) and the reusable body: locals `detail:`, `copies:` (nil → no line), `owner:` (nil → no line), `set_url:` (lambda `(set_ref) → path` or nil → labels without links); `cards#show` passes `->(set) { library_set_path(kind: set.kind, key: set.key) }` only when `current_season`.
- [x] `app/frontend/styles/card-detail.css` (+ import) -- parchment panel, large face beside a definition list, stacked on a phone (≤ 720 px), `.card-link` (`display: inline-block`, ink focus outline), `.card-detail__credit { white-space: pre-line }`.
- [x] `app/views/library/_tome.html.erb`, `app/views/packs/show.html.erb` -- wrap faces and empty slots in `link_to card_season_path(slug:, number:)`, `class: "card-link"`, `aria-label` from `card_details.open`, `data: { turbo_prefetch: false }`.
- [x] `config/locales/{en,fr}.yml` -- `card_details.*` (open, field labels, copies one/other, store link, sets heading); i18n-tasks clean.
- [x] `test/packs/catalog/card_detail_test.rb`, `test/controllers/cards_controller_test.rb`, `test/system/card_detail_test.rb`, updates to library_set / packs tests -- every matrix row, the exact query counts, no database id in the page.

**Acceptance Criteria:**
- Given a card of the published season, when a player opens it from a tome, then its detail shows every field in their language with a working Steam link and their copies, and a visitor can open the same page.
- Given `bin/rails test`, `bin/rails test:system`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `Catalog::CardDetail` folds the published season in as a scalar subquery (`MAX(number)` of published seasons), both to pick the default card-season and to answer `current_season`; it filters `status: published` for an explicit number too, so a draft season's number is 404. Empty description or credit read as nil. Sets are ordered by a `CASE` on kind (tome, publisher, best_of_year), then key; the second query is skipped when the card is not found.
- `CardsController#show` passes `request.path_parameters[:number]&.to_i` (path only, after review); an out-of-range number is a plain miss (no row), a non-digit one a routing 404.
- Helpers live in `app/helpers/card_details_helper.rb`: `card_detail_store_url`, `card_detail_open_label`, and `link_to_card_detail(view, strings) { … }`, used by `library/_tome` (faces and empty slots) and `packs/show` (later-visit faces), so the link markup is written once.
- `cards/_detail` renders the title as the page's `h1` (`#card-detail-heading`), the description as a paragraph, then a `<dl>` (released, rarity, season, sets, publisher, copyright), the copies line, and the Steam link as a secondary button. `owner:` renders "From the collection of %{owner}" (`card_details.owner`), ready for 4.5.
- `card-detail.css` reuses the library's 1000 px page width and 720 px phone breakpoint (raw values only where `library.css` already has them; media queries cannot read custom properties).
- `library_set_test`'s id check now also strips `/seasons/n` and "season n", which the new links and labels carry.

## Plan Change Log

## Review Triage Log

### 2026-10-03 — Review pass
- verdicts: 3 findings — high 0, medium 2, low 1, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` `CardsController#show` read `params[:number]`, so the query string bypassed the route constraint: `?number[]=1` a 500, `?number=abc` a 404, `?number=1` another season on the published-season URL — patched: the number is read from `request.path_parameters`; a controller test opens the three URLs and gets the published season (200).
  - `[medium]` `[defer]` The `card_details.open` aria-label on an empty slot's link replaces its visible text, so "Missing card" is not announced and an empty slot sounds like an owned face (and the face links drop the visually-hidden year) — real, but the intent-contract names every link by `card_details.open`; changing the name means renegotiating the intent. Deferred and recorded in pending-approvals.md for the author's decision.
  - `[low]` `[reject]` `card_detail_store_url` puts Steam's `l=french` in the web layer (AD-4) and re-encodes any existing query — the intent-contract asks for `?l=french` in `fr`; every store URL is a Steam URL today, and moving the knowledge into the Steam pack (a new field or port) adds surface for a fork that does not exist; the re-encoding only alters malformed queries Steam never returns.

## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.

## Auto Run Result

**Summary:** A card's detail page at `/<locale>/cards/:slug` (published season) and `/<locale>/cards/:slug/seasons/:number`: large face, title, description, year, rarity, season, sets (linked to their tomes in the published season), publisher, credit, the viewer's copies and the Steam store link, in `en` and `fr`, open to visitors. Owned faces and empty slots in a tome, and the pack page's later-visit faces, link to it.

**Files changed:**
- `packs/catalog/app/queries/catalog/card_detail.rb` -- the detail in two queries.
- `app/controllers/cards_controller.rb`, `config/routes.rb` -- the page and its two routes.
- `app/helpers/card_details_helper.rb` -- store URL (`l=french`), link label, shared card link.
- `app/views/cards/{show,_detail}.html.erb` -- the page and its reusable body (for 4.5).
- `app/views/library/_tome.html.erb`, `app/views/packs/show.html.erb` -- faces and empty slots link to the detail.
- `app/frontend/styles/card-detail.css`, `app/frontend/entrypoints/application.css` -- the page's styles.
- `config/locales/{en,fr}.yml` -- `card_details.*`.
- `test/packs/catalog/card_detail_test.rb`, `test/controllers/cards_controller_test.rb`, `test/system/card_detail_test.rb`, `test/controllers/{library_set,packs_controller}_test.rb` -- every matrix row, query counts, no ids.

**Review:** quick lens, 3 findings. Patched 1 (medium: season number read from the path only). Deferred 1 (medium: empty-slot link name hides "Missing card"; intent-mandated, in pending-approvals.md). Rejected 1 (low: Steam `l=french` in the web layer, intent-mandated and only Steam URLs exist).

**Follow-up review:** false -- patched counts: high 0, medium 1, low 0.

**Verification:** after the patch, `bin/rails test` 773 runs 0 failures; `bin/rails test:system` 41 runs 0 failures; `packwerk check`, `rubocop` (267 files) and `i18n-tasks missing` clean.

**Residual risks:** the deferred screen-reader naming of empty slots; French copy ("Collections", "Droits", "Tu en détiens…") and the 4.5 owner line wording are the implementer's choices; links from the reveal island are not built (pending-approvals.md).
