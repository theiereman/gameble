---
title: 'Cards of an opened booster cannot be browsed, and the card detail loses the booster'
type: 'bugfix'
ticket: '8'
created: '2026-10-08'
status: 'built'
baseline_revision: 'ec6e3d71165fb04af7be0ecf22d4adfe78382ec6'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 1
followup_review_recommended: false
context: ['{project-root}/AGENTS.md', '{project-root}/_bmad-output/initiative-gameble/epic-space-terminal-screens/bug-cards-of-an-opened-booster-cannot-be-browsed-and-the-card-de.md']
warnings: ['oversized']
deferred:
  - summary: >-
      Planning ids remain in comment blocks edited by this change.
    evidence: |-
      BoosterZoom.tsx line 1 (DESIGN.md, EXPERIENCE.md), cards_controller.rb and sub_view_controller.ts headers (epic 10 R2, R6), Booster.tsx focus section, test/controllers/cards_controller_test.rb and boosters_controller_test.rb headers (CAP-7, story 4.3, AD-15) still name planning documents, against AGENTS.md; the text predates this change.
    location: >-
      app/frontend/components/BoosterZoom.tsx:1
    severity: low
---

<intent-contract>

## Intent

**Problem:** After opening a booster a player cannot walk its cards: the phone's card zoom has no previous/next, the card detail's ◀ ▶ walk the card's tome (and are hidden from 720 px), and Back from a card detail renders a fresh sealed booster because the opened pack lives only in the island's memory. From the collection grid, ◀ ▶ walk the card's tome instead of the grid as shown.

**Approach:** Give the card detail a browse context carried in its URL: an opened pack (`pack=<token>`) walks that pack's cards in pack order; the collection grid (`grid[...]` = the grid's filters, search and set) walks the grid as shown across its pages; otherwise the card's tome as today. ◀ ▶ show at every width. Before leaving for a card detail the booster island rewrites its own history entry to `/booster?pack=<token>`, and the booster page given an owned opened pack's token renders it dealt with every card face up. The phone card zoom gets previous/next and swipe over the cards in the tray, in booster order.

## Boundaries & Constraints

**Always:** the browse context is read-only on a GET and scoped to the viewer (`Game::OpenedPackByToken` is already owner-scoped; another player's or an unknown token is ignored, never an error). Every new string in `en.yml` and `fr.yml`. Tokens only in URLs (pack token, slugs), never ids. Restored booster: cards face up (desktop: all revealed; phone: all stored in the tray), whatever the player had revealed before leaving. Neighbour links stay frame visits with `turbo_action: "replace"` and keep the context query. System tests restore the window size (the base class teardown does) and use retrying Capybara matchers.

**Never:** no write, mark or job on the booster GET; no change to the Turbo cache exemption of `/booster` (it must stay `no-cache`); entering `/booster` without `pack` (tab bar, hub, menu) still starts sealed or empty; no change to the pack page `/packs/<token>` or to links from the feed, hub showcase, share page or public profile (they keep walking the tome); no new `gameble:*` event unless an island must talk to another; no `style` attribute in server HTML; no planning ids in code or tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Pack context | `/cards/<slug>/seasons/1?pack=<own token>`, card in that pack | ◀ ▶ walk the pack's cards in pack order, position "n / 5"; no ◀ on the first, no ▶ on the last; phone back "◀ Booster" → `/booster?pack=<token>` | — |
| Foreign/unknown/unopened token, or card not in pack | `?pack=<other>` | context ignored: tome browsing as today | No error, no 404 |
| Grid context, whole season | `?grid[state][]=owned&grid[q]=port` | ◀ ▶ walk the grid's ordered cards (same order and filters as `/library` with those params), across its 60-card pages; position "n / total"; "◀ Grille" href = `/library` with the same params and the `page` holding the card | — |
| Grid context, set page | `?grid[kind]=tome&grid[key]=action-1&grid[rarity][]=rare` | walk that set's grid as shown; back href = `/library/tome/action-1` with filters and page | unknown set → context ignored |
| Card not in the grid as shown | grid params that exclude the card | context ignored: tome browsing | — |
| Missing card from the grid | grid context, no copies | faded back (grid context counts as a named context) | — |
| Booster restored | GET `/booster?pack=<own opened token>` | island dealt, all five face up (phone: in the tray), bank and "open another" as after a finished reveal | foreign/unknown token → sealed/empty as today |
| Phone zoom | zoom on tray slot k | ◀ ▶ and swipe show the previous/next filled slot in booster order; none before the first or after the last filled | — |

</intent-contract>

## Code Map

- `app/controllers/cards_controller.rb` -- `show` (L30-41): `named_set` (L52-58) and `browse(set)` (L61-65) → `Catalog::SetNeighbours`; `@faded = !named.nil? && @copies.nil?`; `@public = current_player.nil? && named.nil?`. Add the pack and grid contexts here (pack wins over grid, grid over set); a context counts as "named" for `@faded`/`@public`.
- `packs/catalog/app/queries/catalog/set_neighbours.rb` -- `Neighbours = Data.define(:set, :position, :total, :previous, :next)` (slugs). Reuse this Data shape for every context (add what the view needs, e.g. the back target and the query to keep, in the controller or a small presenter, not in the Catalog query).
- `packs/game/app/queries/game/opened_pack_by_token.rb` -- owner-scoped opened pack; `PacksController#cards_of` (app/controllers/packs_controller.rb) gives the pack's cards in order: reuse for pack neighbours and for the restored booster.
- `app/controllers/library_controller.rb` -- `GRID_SIZE = 60`, params `state[] rarity[] sets[] genre[] q page`, set page adds `kind key`; `grid_filters` (L76-79), `effective_states`/`default_state` (L88-97), `load_grid` (L105-117: `Game::CollectionStates.call(player, grid.card_seasons, states:, newest_first: grid.set.nil?)`, `Catalog::CardTomes` only when no set). Extract the code that builds the ordered relation from params into a concern shared with `CardsController` (e.g. `CollectionGridLoading`) so the detail rebuilds exactly the grid shown; neighbours = the ordered ids plucked once, the card's index, its neighbours' slugs (one more query); a season holds at most a few thousand cards.
- `packs/catalog/app/queries/catalog/collection_grid.rb`, `packs/game/app/queries/game/collection_states.rb` -- grid base relation and ordering (set: membership position; whole season: owned newest first). Reuse, do not change their queries.
- `packs/catalog/app/queries/catalog/card_tomes.rb` -- used only so whole-season grid links name a tome; once grid links carry the grid context it is unused: delete it and its test, drop it from `load_grid` and the `_grid` slot triple, lower the `/library` query budgets by one.
- `app/helpers/card_details_helper.rb` -- `link_to_card_detail(view, strings:, set:)` (L49-53), `card_detail_path` (L57-60), `card_detail_neighbour_path` (L64-67): generalise to carry the context query (`pack:` or `grid:` hash) instead of only `set_kind/set_key`.
- `app/views/library/_grid.html.erb` (L25-35 `card_set = set || tome`), `app/views/library/_collection.html.erb` (L94-96) -- links carry the grid context (current filters, search, set) instead of a set.
- `app/views/cards/show.html.erb` (L18-26 phone back "◀ Grille" with `history-back` and `alternates`), `app/views/cards/_detail.html.erb`, `_detail_nav.html.erb` -- back label/href per context ("◀ Booster" → `booster_path(pack:)`; "◀ Grille" → the grid URL with filters and page; tome as today).
- `app/frontend/styles/card-detail.css` -- `.card-detail__nav { display: none }` (L115-129, comment "shown on the phone only") and the `@media (max-width: 719px)` rule (L481-483): show ◀ ▶ at every width on the wide two-column layout; the position line may stay phone-only.
- `app/frontend/controllers/sub_view_controller.ts` -- swipe `release()` clicks only a displayed control; works unchanged once ◀ ▶ are displayed. `history_back_controller.ts` + `lib/history_trail.ts` `backSteps` -- matches pathnames, so `/booster` and `/library` history entries are found as is.
- `app/views/boosters/show.html.erb` (L12 `turbo_exempts_page_from_cache`, L14 `turbo_mount("Booster", props: booster_props(...))`), `app/controllers/boosters_controller.rb#show`, `app/helpers/boosters_helper.rb#booster_props` (`cardUrl: card_path(slug: "SLUG")`), `app/helpers/packs_helper.rb#pack_opening_json` (pack token/url + cards; the same card shape serves the restored pack), `app/frontend/lib/booster_props.ts` -- add an optional `opened` prop (the opening JSON of the pack named by `params[:pack]`, owner-scoped, read-only).
- `app/frontend/components/Booster.tsx` -- state L158-200 (`phase`, `answer`, `revealed`, `stored`, `zoom`); `activateCard` L851-859 (`visit(cardUrl.replace(...))`); `openZoom` L787, `closeZoom` L792. Start dealt and all revealed (phone: all stored) when `props.opened` is set; before any visit to a card detail (`activateCard` and the zoom's "Voir la fiche") replace the current history entry's URL with `/booster?pack=<token>` keeping `history.state` (Turbo restores from `location` on popstate), and give the card URL `?pack=<token>`.
- `app/frontend/components/BoosterView.tsx` (L369-383 zoom render, L377 href), `BoosterZoom.tsx` -- add previous/next buttons (aria-labels from strings) and swipe (`lib/swipe.ts` `swipeStep`) moving `zoom` between filled tray slots in booster order; the zoom's href carries `?pack=`.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- L171 Card zoom, L177 Card detail ("Phone: ◀ ▶" → every width, context rules), L262 Reveal abandoned (the way back from a card's detail shows the booster with its cards face up), L52/L414 the contextual backs ("◀ BOOSTER").
- Tests: `test/system/booster_test.rb` (helpers `open_screen`, `on_phone`, `PHONE`, L209 card opens its page, L734 phone zoom), `test/system/card_detail_test.rb` (L162 and L298 whole-season tome cases to rework, `swipe`, `assert_history_length`), `test/controllers/cards_controller_test.rb` (query budgets L439-459: 9 / frame 5 / visitor 2), `test/controllers/library_controller_test.rb` (L139 tome links, L428-445 budgets), `test/controllers/library_set_test.rb` (L82-83 link hrefs, L232-249 budgets), `test/controllers/boosters_controller_test.rb` (L48 props, L60 cache meta), `test/support/game_packs.rb#create_pack(..., opened_at:)`.

## Tasks & Acceptance

**Execution:**
- [x] `app/controllers/concerns/collection_grid_loading.rb` (new) + `library_controller.rb` -- move the params → ordered grid relation code into the concern; LibraryController keeps its behaviour and query counts (minus CardTomes) -- one source for the grid's order and filters.
- [x] `app/controllers/cards_controller.rb` -- resolve the browse context: `params[:pack]` (owner's opened pack holding the card) → pack neighbours; else `params[:grid]` (rebuild the grid; card in it) → grid neighbours with the page holding it; else `named_set` / first set as today; expose the back target; header comment updated -- one context per detail.
- [x] `app/helpers/card_details_helper.rb` -- context-carrying link and neighbour path helpers.
- [x] `app/views/library/_grid.html.erb`, `_collection.html.erb`, `library_controller.rb` -- links carry the grid context; remove `Catalog::CardTomes` (+ `test/packs/catalog/card_tomes_test.rb`).
- [x] `app/views/cards/show.html.erb`, `_detail.html.erb`, `_detail_nav.html.erb` -- back per context; position line total per context.
- [x] `app/frontend/styles/card-detail.css` -- ◀ ▶ at every width.
- [x] `boosters_controller.rb`, `boosters_helper.rb`, `lib/booster_props.ts` -- optional `opened` prop for an owned opened pack named by `params[:pack]`.
- [x] `Booster.tsx`, `BoosterView.tsx`, `BoosterZoom.tsx` (+ vitest where logic is pure, e.g. the neighbour-slot helper) -- restored dealt state; history entry rewrite and `?pack=` on card links; zoom previous/next and swipe.
- [x] `config/locales/en.yml`, `fr.yml` -- "◀ Booster"/"◀ Booster", zoom "Previous card"/"Carte précédente", "Next card"/"Carte suivante" (reuse existing keys where they exist).
- [x] `EXPERIENCE.md` -- the four places listed in the Code Map; epic R2 already amended.
- [x] Tests -- controller: pack context (own, foreign, card not in pack), grid context (filters, search, set page, cross-page neighbour, card excluded → tome), faded from grid, back hrefs, booster `opened` props (own, foreign, unopened), updated query budgets with the reason in a comment; system (desktop 1400 and phone 390 × 844): open a booster, open a card, step ▶ through all five and ◀ back, Back → booster with five cards face up, open another card from it; phone zoom ▶/◀ and swipe through the tray, no ◀ on the first; from a filtered/searched grid ◀ ▶ walk the grid and "◀ Grille" returns to it with the filters. Rework the whole-season tome tests.
- [x] Follow-up review fixes, loop 1 (2026-10-08, see Plan Change Log; leave every task above as it is):
  - [x] "◀ Grille" after ◀ ▶ crossed a grid page (`app/frontend/controllers/history_back_controller.ts`, with `sub_view_controller.ts` which rewrites the link's href per step): the history trail matches pathnames only, so `history.go` lands on the page the detail was opened from even when the card shown now sits on another page of that grid. Go back through history only while the link's href is still the one the page was rendered with (the grid page the detail was opened from); once a step pointed it at another page, let the link visit its href. System test (phone): open the 60th card of a 61+ card grid from its first page, step ▶ onto the second page, press "◀ Grille": the URL carries `page=2` and the grid shows the card last seen.
  - [x] A grid filtered on new cards (`state[]=new`): the grid posts the player's watermark as soon as it shows new cards (`collection_seen_controller.ts`), so the detail rebuilding the grid finds no new card and falls back to the tome. The grid's links carry the watermark the grid was shown against (`seen`: `collection_seen_up_to` at render time, ISO 8601 UTC with microseconds, absent when the player had none) in the grid context; `Game::CollectionStates.call` takes an optional `seen_up_to:` that, when given, judges `new` against it instead of the player's current watermark; `CardsController#grid_browse` passes it. Only the grid context carries it, never another link. Controller test: with the watermark moved past the grid's cards after the grid rendered, a `state[]=new` grid context still walks those cards in order; a `seen` that is not a time is ignored (the current watermark).
  - [x] Dead alternates (`app/frontend/controllers/history_back_controller.ts`, `app/frontend/lib/history_trail.ts#backSteps` and `history_trail.test.ts`, `test/controllers/cards_controller_test.rb` assertion on `data-history-back-alternates-value`): no view passes alternates any more; delete the value, the `backSteps` alternates branch and their tests and comments.

**Acceptance Criteria:**
- Given a player on a phone in the card zoom of a booster card, when they press next/previous or swipe, then the zoom shows the neighbouring card in booster order without closing, with no previous on the first and no next on the last.
- Given a card detail opened from an opened booster on phone or desktop, when ◀ ▶ are used, then they move through that booster's cards in its order and no further; Back or "◀ Booster" shows the booster with its cards face up, and another card can be opened.
- Given the collection grid with filters and search, when a card's detail is opened and ◀ ▶ used, then they walk the grid as shown (across pages), and the return leads to the grid with the same filters and search.
- Given a card detail opened from the feed, hub, share link, public profile or pack page, when ◀ ▶ are used, then they walk the card's tome, on desktop too.

## Implementation Notes

- Pack context carries `slot` (the card's place in the pack, from 1) beside `pack`: a pack can draw the same card twice, and placing a card by its first occurrence would make ▶ loop between the two copies. A missing or wrong `slot` falls back to the card's first place in the pack. The island's links and the zoom's "Voir la fiche" carry both (`lib/booster_page.ts#cardHref`).
- The grid context always carries `grid[q]` (blank when nothing is searched), so the whole season's default grid (no filter) still names a context: Rails drops empty hashes from a query string.
- The phone's "◀ Grille" is outside the `card-detail` frame, so ◀ ▶ frame visits would leave its href on the first card's grid page; the detail carries its back path (`data-sub-view-back-value`) and `sub_view_controller.ts` points the top-bar link at it on connect. The heading focus on open stays phone-only now that ◀ ▶ show at every width.
- The history-back `alternates` (whole season → tome) are no longer passed: whole-season links now carry the grid context and their back href is that grid.
- Opening the next booster from a shown-again pack drops `?pack=` from the screen's entry, so a reload then starts fresh.
- `PacksController#cards_of` moved to the `PackCards` concern, shared with `BoostersController`. The zoom's ◀ ▶ pixel icons come in a new `arrowIcons` prop; the zoom strings are `boosters.island.zoom_previous`/`zoom_next` (the island takes the whole `boosters.island` group).
- DESIGN.md's Card zoom line still lists only "VOIR LA FICHE" and "FERMER"; left for the author.

**Verify-step completion (orchestrator, 2026-10-08).** A player who has seen no card yet now carries `seen` = 1970-01-01 (`CollectionGridLoading::NOTHING_SEEN`, via `LibraryController#shown_watermark`): with no watermark every gain is new, which the epoch reproduces, so their NOUVELLES grid stays walkable once the grid moved their first watermark; `library_controller_test.rb` asserts it.

## Plan Change Log

- 2026-10-08 — Review pass 1. Triggering findings: (1) "◀ Grille" goes back through history to the grid page the detail was opened from even after ◀ ▶ moved onto a card of another page, as the trail matches pathnames only; (2) a grid filtered on new cards cannot be walked: the grid posts the watermark on showing them, and the detail's rebuilt grid has no new card left; (3) the history-back alternates have no producer left. Amended: a new task group "Follow-up review fixes, loop 1" under Execution. Known-bad state avoided: a phone player returning to a grid page that does not hold the card last shown (focus lost, wrong page); the NOUVELLES filter silently falling back to the tome; dead code in the history trail. KEEP: everything already in the working tree (pack and grid contexts, CollectionGridLoading, PackCards, the restored booster and history rewrite, the zoom's ◀ ▶ and swipe, ◀ ▶ at every width, the `slot` parameter, the always-present `grid[q]`, the sub-view's back-href rewrite, the removal of Catalog::CardTomes, the tests and EXPERIENCE.md edits); the revert before re-derivation is empty.

## Review Triage Log

### 2026-10-08 — Review pass
- verdicts: 6 findings — high 0, medium 2, low 4, false 0, maybe-false 0
- findings:
  - `[medium]` `[bad_plan]` "◀ Grille" returns to the grid page the detail was opened from, not the page holding the card after ◀ ▶ crossed a page — verified: `backSteps` (lib/history_trail.ts) matches `target.pathname` only, so `/library?page=2` matches the earlier `/library` entry and `history.go(-1)` ignores the rewritten href; plan amended (loop-1 task 1).
  - `[medium]` `[bad_plan]` A `state[]=new` grid cannot be walked — verified: `_collection.html.erb` renders `collection-seen` with `seen_up_to`, the controller posts it, and `CollectionSlots::NEW` then excludes every card shown, so `grid_browse` finds no index and falls back to the tome; plan amended (loop-1 task 2).
  - `[low]` `[bad_plan]` The history-back alternates are dead code — verified: no view sets `data-history-back-alternates-value` (grep), only a test asserting its absence; a direct deletion, folded into the amended plan (loop-1 task 3).
  - `[low]` `[reject]` `boosters.island.zoom_previous`/`zoom_next` duplicate `card_details.previous`/`next` — real, but the island receives its whole `boosters.island` group as props (BoostersHelper#booster_strings); reusing the other keys adds a special case to that builder for two strings nobody meets as a defect.
  - `[low]` `[defer]` Planning ids remain in comment blocks this diff edited (BoosterZoom.tsx, cards_controller.rb, sub_view_controller.ts, Booster.tsx, two test headers) — pre-existing text, not written by this change; the epic's refactor sweep is the place to clear them repo-wide.
  - `[low]` `[reject]` On desktop a pointer step leaves focus on `<body>` — real for a mouse click (the replaced link took the focus with it), but keyboard steps keep focus through `focusAfterStep` and a mouse user does not rely on focus; restoring it adds a desktop branch to the sub-view.


### 2026-10-08 — Review pass (loop 1)
- verdicts: 5 findings — high 0, medium 0, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` "◀ Grille" still goes to the opened-from page after ◀ ▶ crossed a page, the player left the detail and came Back (the link reconnects with the rewritten href as its rendered one) — real, but needs a page crossing, a way out of the detail and Back before pressing it; the fix (recording queries in the history trail and comparing them) adds trail data and matching rules for a path players rarely take.
  - `[low]` `[reject]` The "◀ Grille" href drops the library's own `kind` and `shelf` (which list of sets is open) — real on the plain-visit path only (after a page crossing); filters, search and page are kept, as the acceptance criterion asks; carrying the shelf state adds two more context parameters for a side panel's position.
  - `[low]` `[patch]` The booster test named for the tab bar never entered through it — fixed: after a restored own pack, the test enters BOOSTER from the tab bar and asserts a sealed canister, no card and no filled tray slot.
  - `[low]` `[patch]` A one-shot read of the phone back's href, rewritten asynchronously — fixed: `assert_selector ".top-bar__phone-back[href*='page=2']"`.
  - `[low]` `[patch]` Comment lines this diff wrote in history_back_controller.ts named DESIGN.md/EXPERIENCE.md — fixed: reworded without them; older text stays under the deferred item.

## Design Notes

History rewrite (Booster.tsx), keeping Turbo's restoration state so popstate restores `/booster?pack=…` (fetched fresh: the page stays `no-cache`):

```ts
const url = new URL(location.href)
url.searchParams.set("pack", token)
history.replaceState(history.state, "", url)
visit(withPack(cardUrl.replace("SLUG", encodeURIComponent(slug)), token))
```

Only the way to a card detail rewrites the entry, so the tab bar, hub or a reload of `/booster` start fresh as before.

## Verification

All Ruby commands need Ruby 4.0.7 from rbenv: prefix them with `export PATH=/opt/rbenv/shims:$PATH && ` (and, for system tests, `CHROME_BIN=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/chrome.sh SE_CHROMEDRIVER=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/cd/chromedriver`: Chromium with `--no-sandbox` and its matching driver). Never run `npm install`.

**Commands:**
- `export PATH=/opt/rbenv/shims:$PATH && bin/rails test` -- expected: all green
- `export PATH=/opt/rbenv/shims:$PATH && CHROME_BIN=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/chrome.sh SE_CHROMEDRIVER=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/cd/chromedriver bin/rails test test/system/booster_test.rb test/system/card_detail_test.rb test/system/library_test.rb` -- expected: all green (run the touched files 3× to catch timing flakes)
- `npm run test:js && npm run typecheck` -- expected: pass
- `export PATH=/opt/rbenv/shims:$PATH && bin/rubocop && bundle exec packwerk check && bin/rails zeitwerk:check && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

**Summary.** The card detail browses one context carried in its URL: an opened pack (`pack`, `slot`) walks that pack in drawn order and leads back to the booster showing it; the collection grid (`grid[...]`: filters, search, set, and for a NOUVELLES grid the watermark it was shown against) walks the grid as shown across its pages and leads back to the page holding the card; otherwise one of the card's sets, as before. ◀ ▶ show at every width. Before leaving for a card detail the booster island names the pack in its own history entry, and `/booster?pack=<own token>` renders that pack dealt, every card face up (on the phone, in the tray). The phone's card zoom has ◀ ▶ and swipe over the stored cards in booster order.

**Files.**
- `app/controllers/cards_controller.rb` -- pack, grid and set browse contexts, `Browse`/`Back` data, back per context.
- `app/controllers/concerns/collection_grid_loading.rb` (new) -- the grid's scope, filters, order and context, shared by the library and the detail; `NOTHING_SEEN`.
- `app/controllers/concerns/pack_cards.rb` (new) -- an opened pack's cards in drawn order (packs, booster).
- `app/controllers/library_controller.rb`, `app/views/library/*` -- grid links carry the grid context; `Catalog::CardTomes` removed.
- `app/controllers/boosters_controller.rb`, `app/helpers/boosters_helper.rb`, `app/views/boosters/show.html.erb` -- the `opened` prop and the zoom's arrow icons.
- `packs/game/app/queries/game/collection_states.rb`, `collection_watermark.rb` (new) -- `seen_up_to:` override; the player's watermark.
- `app/helpers/card_details_helper.rb`, `app/views/cards/*` -- context-carrying links, back link, ◀ ▶.
- `app/frontend/components/Booster.tsx`, `BoosterView.tsx`, `BoosterZoom.tsx`, `lib/booster.ts`, `lib/booster_page.ts`, `lib/booster_props.ts` -- restored pack, history rewrite, zoom stepping and swipe.
- `app/frontend/controllers/sub_view_controller.ts`, `history_back_controller.ts`, `lib/history_trail.ts` -- back href kept current, history back only to the rendered page, alternates removed.
- `app/frontend/styles/card-detail.css`, `booster-layouts.css` -- ◀ ▶ at every width; the zoom's stage.
- `config/locales/en.yml`, `fr.yml` -- `cards.show.booster`, zoom previous/next.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- card zoom, card detail, reveal abandoned, contextual backs.
- Tests: controller (cards, boosters, library, library set, collection states) and system (booster, card detail).

**Review.** Two passes (quick lens). Pass 1: 2 medium and 1 low routed `bad_plan` (loop 1: back link across pages, NOUVELLES grid, dead alternates), 1 deferred (planning ids in older comments), 2 rejected (duplicate zoom strings: the island takes its whole string group; desktop pointer-step focus: keyboard steps keep focus). Pass 2: 3 low patched (booster tab-bar test, retrying matcher, comment wording), 2 rejected (back after leaving and returning to a detail that crossed a page; shelf state on the plain-visit back) — reasons in the triage log. Patched by verdict on the last pass: high 0, medium 0, low 3.

**Follow-up review recommended:** false.

**Verification.** `bin/rails test` 1732 runs green; `npm run test:js` 186 green; `npm run typecheck`, `bin/rubocop`, `packwerk check`, `zeitwerk:check`, `i18n-tasks missing`/`unused` clean; system `booster_test.rb`, `card_detail_test.rb`, `library_test.rb`: 55 runs, all green but `library_test.rb:188`.

**Residual risks.**
- `test/system/library_test.rb:188` ("the cards of a pack just opened are new…") fails here on the baseline commit `ec6e3d7` too (2 of 5 NEW tags found), so it is not this change's; not investigated.
- A grid-context detail plucks the whole grid's ids (a season's cards, at most a few thousand): 12–13 queries against 9 for a plain detail.
- System tests in this container need Chromium with `--no-sandbox` and ChromeDriver 141 (the planned `CHROME_BIN` alone fails).
