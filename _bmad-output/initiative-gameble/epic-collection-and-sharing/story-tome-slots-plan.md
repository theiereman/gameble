---
title: 'Tome slots'
type: 'feature'
ticket: '2'
created: '2026-10-02'
status: 'built'
baseline_revision: 'e4debcffdab80ba7860dcfb5bba6336ddd954611'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md', '{project-root}/_bmad-output/initiative-gameble/epic-collection-and-sharing/story-library-of-sets-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The library lists the sets but a set cannot be opened, so a player cannot see which cards they own in it and which are missing (CAP-6; epic 4, R2, R6).

**Approach:** Each spine on the shelf opens its tome: the set's heading and progress, and its slots in order — an owned card shows its face with its copy count, a missing card is an empty slot that names the game. The tome sits beside the shelf, as in the mockup; on a phone the tome alone. A visitor sees every slot empty.

## Boundaries & Constraints

**Always:**
- Route `GET /<locale>/library/:kind/:key` constrained to `kind: /tome|publisher|best_of_year/`, helper `library_set_path`, action `LibraryController#set`; an unknown key, a key of another kind or no published season → 404; addressed by kind and key only (AD-15). The controller fetches the published season once and passes it: `Catalog::SeasonShelf.relation(kind:, season:)` (4.1's signature extended) and `Catalog::SetSlots.call(season_id:, kind:, key:)` → the set (an object with `kind`, `key`, `params`) and its card-season ids ordered by `position, id`, or nil.
- `Game::Quantities.call(player, card_season_ids)` → `{ card_season_id => quantity }` for quantities > 0, any player (never `current_player` implicitly; 4.4 passes another), `{}` without a query for nil; `Catalog::CardViews` (3.5) for the slots; the web layer joins them.
- Spines link to `library_set_path(kind, key, page: current shelf page)`; on the tome page the shelf shows that `page` (page 1 without it, where the open spine may be absent and nothing is current); the open spine carries `aria-current="page"`. The shelf and tome are partials taking the owner's data and a path builder (`library/_shelf` with `current_set:`, `library/_tome` with `slots`, `quantities`, `set`), so 4.4 renders another player's library with its own paths.
- Heading (`content_for(:title)` too): the 4.1 `SetLabel`; for a tome the members' release-year range ("Aventure · Tome 4 · 2011–2012", one year when equal); "owned / total" (a visitor "0 / 25").
- Slots in an `<ol>`, in order: owned → the small `CardComponent` face, with "×n" when n > 1 as a sibling of the component inside the `<li>` (the "×n" `aria-hidden`, a visually hidden "n copies" with one/other plurals); missing → an empty slot sized like `.card--small`, a 2 px dashed `{colors.ink-muted}` border on `{colors.surface-sunken}` with plate padding, showing the game's title (two lines at most), its year and "Missing card" as visible text (DESIGN.md, mockup `.slot`).
- Art loads lazily: the 3.5 card-art helper starts a draw only when the card nears the viewport (IntersectionObserver), so a large publisher set does not load every image at once.
- Layout: shelf beside the tome on wide screens; on a phone the tome alone with a "Back to the shelf" link; the layout's back button to the attic. "Set complete" styling is deferred (EXPERIENCE marks it an assumption).
- Queries per request (asserted exactly): player — lookup, season, shelf count, shelf page, totals, progress, set slots, card views, quantities (9); visitor — without lookup, progress and quantities (6).
- Copy in `fr` and `en`.
**Never:** no card detail page or links to it (4.3); no profile (4.4); no trading or marking of cards.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Player | owns 3 of 25 slots, one ×2 | 3 faces (one with ×2), 22 empty slots naming their games, "3 / 25" | — |
| Visitor | signed out | 25 empty slots | — |
| Order | memberships at positions 1…25 | slots in that order | — |
| Heading | tome of 2011–2012 releases; best of 2015; publisher | "Genre · Tome n · 2011–2012"; "Best rated of 2015"; the publisher | — |
| Locale | `fr` | French titles and labels | — |
| Unknown | bad kind, missing key, no season | 404 | — |
| Shelf link | a spine in the library | opens this tome, spine marked current | — |
| Phone | 390 px | tome alone, "Back to the shelf" | — |
| Queries | player / visitor | the exact counts above | — |
| Ids | the page | no database id in URLs or attributes | — |
| Wrong kind | key of a tome under `publisher` | 404 | — |
| No shelf page | the tome opened without `page` | shelf page 1, nothing current | — |
| Large set | a publisher set of 300 cards | art drawn only near the viewport | — |

</frozen-after-approval>

## Code Map

- `app/controllers/library_controller.rb`, `app/views/library/{show,_shelf}.html.erb`, `app/components/set_label.rb`, `app/frontend/styles/library.css` (4.1).
- `packs/catalog/app/queries/catalog/{season_shelf,set_totals,card_views}.rb`, `packs/game/app/queries/game/set_progress.rb` (4.1, 3.5).
- `app/components/{card_component,card_strings}.rb` (3.5) -- small face.
- `_bmad-output/initiative-gameble/ux-gameble/mockups/key-screens.html` (`library()`: shelf left, open tome right, phone without shelf).

## Tasks & Acceptance

**Execution:**
- [x] `packs/catalog/app/queries/catalog/set_slots.rb`, `packs/game/app/queries/game/quantities.rb`.
- [x] `LibraryController#tome` (or a `TomesController`), route, `app/views/library/tome.html.erb`, empty-slot markup and CSS, spine links, locales.
- [x] `test/` -- every matrix row.

**Acceptance Criteria:**
- Given a player who owns some cards of a tome, when they open it from the shelf, then owned cards show their face and copies, missing ones name their game, and a visitor sees the same tome with every slot empty.
- Given `bin/rails test`, `bin/rails test:system`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- The action is `LibraryController#set` (as Always says), so its view is `app/views/library/set.html.erb`; the tome itself is `library/_tome` (locals `set`, `slots` — `{ card_season_id => CardView }` in slot order — and `quantities`). The heading and owned / total are computed in the partial; `set.html.erb` repeats the heading for `content_for(:title)`.
- `Catalog::SetSlots` answers `Slots(set: SetRef(kind, key, params), card_season_ids)` from one LEFT JOIN, so a set without members has no slots. `Catalog::SeasonShelf.relation(kind:, season: PublishedSeason.call)`: the default keeps 4.1's callers; the controller passes the season it fetched.
- `SetLabel.heading(set, years)` adds the year range through `catalog.sets.with_years` ("%{label} · %{years}"), only for a tome with cards.
- `library/_shelf` takes `set_url: ->(kind, key, page)` and `current_set:`; spines are now `<a class="tome">` inside the `<li>` and always carry `page=` (the shelf's current page, 1 included). The current spine is rust, shadowed and pulled out by 8 px.
- Lazy art lives in the card-art Stimulus controller (server-rendered faces), not in `drawCardArt`, so the React reveal is unchanged; an IntersectionObserver with a 300 px margin starts the draw, falling back to drawing at once without one. The back-office card-preview system test now scrolls each server face into view before asserting every art settled.
- On a phone (≤ 720 px) the aside is hidden and "Back to the shelf" shown (it links to the shelf's kind and the `page` given); the tome's padding and gap shrink so two small cards sit side by side at 390 px.
- 404s: a kind outside the route constraint is a routing error; an unknown key, a key of another kind or no published season raise `RecordNotFound`.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 0, low 2, false 0, maybe-false 0

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | low | patch | Spines in one shelf row could differ in height once the binding became an `<a>` inside the `<li>` | `.shelf > li` is a flex box and the binding fills it. |
| 2 | low | patch | The empty slot hard-coded 160 × 240 instead of sharing the small card's size | `--card-small-width/height` defined once in `card.css`, used by `.card--small` and `.slot`. |


## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
