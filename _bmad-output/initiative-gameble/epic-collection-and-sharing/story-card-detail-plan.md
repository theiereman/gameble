---
title: 'Card detail'
type: 'feature'
ticket: '3'
created: '2026-10-02'
status: 'draft'
baseline_revision: ''
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md', '{project-root}/_bmad-output/initiative-gameble/spec-gameble/spec-gameble.md', '{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/story-tome-slots-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

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

</frozen-after-approval>

## Code Map

- `packs/catalog/app/queries/catalog/{card_views,card_view,set_slots}.rb`, `app/models/catalog/{card,card_text,card_season,set}.rb`.
- `app/components/{card_component,card_strings,set_label}.rb`, `app/views/library/tome.html.erb` (4.2), `app/views/packs/show.html.erb` (3.6).
- `packs/game/app/queries/game/quantities.rb` (4.2).

## Tasks & Acceptance

**Execution:**
- [ ] `packs/catalog/app/queries/catalog/card_detail.rb`.
- [ ] `app/controllers/cards_controller.rb`, route, `app/views/cards/show.html.erb`, CSS, links from tome and pack faces, locales.
- [ ] `test/` -- every matrix row.

**Acceptance Criteria:**
- Given a card of the published season, when a player opens it from a tome, then its detail shows every field in their language with a working Steam link and their copies, and a visitor can open the same page.
- Given `bin/rails test`, `bin/rails test:system`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
