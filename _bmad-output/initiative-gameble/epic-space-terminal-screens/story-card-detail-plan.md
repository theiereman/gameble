---
title: 'Card detail'
type: 'feature'
ticket: '2'
created: '2026-10-06'
status: 'built'
baseline_revision: 'a26b1d7f8bba85fb953601df45311edab245d20f'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The card page (`/cards/:slug[/seasons/:n]`) is still the interim story 4.3 layout: an xl face beside a plain definition list, no "FICHE DE LA CARTE" panel, no faded card back for a card not owned, no phone sub-view with ◀ ▶, swipe and position line (epic 10 R2, R6; AD-16, AD-25, AD-27).

**Approach:** Rebuild `cards/_detail` as DESIGN.md's bracketed "FICHE DE LA CARTE" panel (card at `card-l`, fact rows, description, sets, copies, ownership notice, "Voir sur Steam" and "Partager"), wrapped in a `card-detail` Turbo Frame. The page browses one set of the card's season (an explicit `set_kind`/`set_key` query, else the card's first set): a new Catalog query gives the position, total and neighbours, which feed the phone's ◀ ▶ links (frame navigations replacing the URL), swipe, the position line and a contextual "◀ Grille" back. Within a set, a card the viewer does not own shows their active back (Standard) at 55 % with its name and year.

## Boundaries & Constraints

**Always:**
- One card face renderer: `CardComponent` (size `:l`) (AD-16). No `style` attribute in server HTML; listeners removed on disconnect; motion off under `motionReduced()` / `prefers-reduced-motion` / `html[data-motion=reduced]` (instant or crossfade).
- No database id in URL, HTML or DOM (AD-15): sets by kind and key, cards by slug. GET only reads (AD-11).
- Rarity is shown for every card, owned or not (author). Keep the per-card ownership notice `card_details.notice` until the legal page exists (pending-approvals, 2026-10-05).
- "Partager" only when the signed-in viewer holds the card; it keeps the existing `share` controller (button, read-only link field, status region). The share sheet is story 10.3.
- "Voir sur Steam": primary, `target="_blank"`, `rel="noopener noreferrer external"`, its accessible name says it opens a new tab; French store URL kept (`card_detail_store_url`).
- Copy in en.yml and fr.yml, natural case (uppercase by CSS), French in "vous". Repo text in English.
- The card's own page without a set context (the form a share link takes) keeps showing the face to everyone, with preview tags, canonical/og:url and the visitor's invitation unchanged (public variant is story 10.3).

**Never:**
- No redesign of the public shared-card variant beyond keeping it working; no share sheet; no change to share-link format, preview tags or `CardDetailLoading`'s path-only season rule.
- No collection-grid rebuild (story 10.1 owns `library/*` and the grid); touch `library/_tome.html.erb` and `library/set.html.erb` only to pass the set to the card link.
- No booster changes: the reveal island's cards do not link to the detail (author).
- No rays, idle float or desktop right-hand collection panel (deferred), no new React island, no client router.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Owned, from a tome | player holds 2, `?set_kind=tome&set_key=action-1` | face `card--l`, rows incl. "2 copies", Partager, position "S1 · #n · 3 / 13", phone back "◀ Grille" to `/library/tome/action-1` | — |
| Not owned, within a set | player holds 0 or visitor, set context | Standard back at 55 % with title and year, rarity row still shown, no Partager, visitor gets no copies row | — |
| Card's own page | no set query (showcase, share link, pack face) | face for everyone; ◀ ▶ browse the card's first set (tome first); visitor invitation kept | — |
| Bad set context | `set_kind` unknown or set not holding the card | ignored: falls back to the first set | no 404 |
| Ends of a set | first / last slot | ◀ (resp. ▶) disabled button; swipe that way does nothing | — |
| No set | card in no set | no ◀ ▶, no position line, back is the bridge | — |
| Older season | `/seasons/1` while 2 is published | browses season 1's set; set names unlinked; no "◀ Grille" | — |

</intent-contract>

## Code Map

- `app/controllers/cards_controller.rb` -- `show`: add the browse set (explicit `params[:set_kind]` in `ShelfLoading::KINDS` and `params[:set_key]` matching one of `@detail.sets`, else `@detail.sets.first`), `@browse` from the new query, `@faded` (no copies and an explicit set context), the active back key `Game::CardBacks.active_key(current_player)`.
- `app/controllers/concerns/card_detail_loading.rb` -- unchanged (path-only season number).
- `packs/catalog/app/queries/catalog/card_detail.rb` -- `Detail.sets` are `SetSlots::SetRef`s of the card-season's season, library order; reuse, do not change its two queries.
- `packs/catalog/app/queries/catalog/set_slots.rb` -- slot order is `catalog_set_memberships.position, id`; the new query must use the same order and skip members without a `catalog_card_texts` row in the locale (as `CardViews` does for the grid).
- `app/views/cards/_detail.html.erb`, `app/views/cards/show.html.erb` -- rewrite (detail) / adapt (frame, top bar contents, invitation's button to secondary so "Voir sur Steam" is the one primary).
- `app/helpers/card_details_helper.rb` -- `link_to_card_detail(view, strings:, set: nil)` adds `set_kind`/`set_key` query when given; add the back image helper and prev/next URL helpers here.
- `app/views/library/_tome.html.erb`, `app/views/library/set.html.erb` -- pass `set:` to `link_to_card_detail` only from the player's own library (a `browse: true` local); the public profile's tome stays without it.
- `app/views/shell/_top_bar.html.erb`, `app/frontend/styles/shell.css` -- optional `content_for :phone_back` shown under 720 px in place of "◀ Pont".
- `app/frontend/controllers/starfield_controller.ts` -- a visit while `html[data-sub-view-step]` is set is no screen change (no star shift).
- `app/frontend/lib/tilt.ts` -- tilt holds after 150 ms of a still finger; swipe must not fight it (touch-action pan-y; a moved finger never tilts).
- `app/frontend/controllers/share_controller.ts` -- reused as is (targets `url`, `status`; action `share#copy`).
- `script/pixel_art/export.mjs`, `test/lib/pixel_art_export_test.rb` -- pixel art is only ever generated here (`--check` test).
- `app/frontend/styles/card-detail.css`, `tokens.css`, `card.css` (`.card--l` 208 × 312), `shell.css` (`.panel--brackets`, `.visually-hidden`, buttons, `.main` view-transition `screen`).
- Tests to rework: `test/controllers/cards_controller_test.rb`, `test/controllers/card_preview_tags_test.rb` (`main > .card-detail` selectors), `test/system/card_detail_test.rb`, `test/system/share_card_test.rb`, `test/controllers/library_set_test.rb` (card-link hrefs).

## Tasks & Acceptance

**Execution:**
- [x] `script/pixel_art/export.mjs` -- add a procedural `back-standard.svg` (104 × 156 art pixels, 208 × 312 CSS): slate frame lit top-left, dark diagonal-weave field (gradient quantised to a few colours), inner line, four accent corner brackets, a blue ring with a dotted outer ring and gold ticks, the existing `logo` grid centred, "GAMEBLE" in 5 × 7 letters below; deterministic, runs merged per colour; then run the script -- AD-25/AD-27 assets are exported files.
- [x] `packs/catalog/app/queries/catalog/set_neighbours.rb` (+ `test/packs/catalog/set_neighbours_test.rb`) -- `Catalog::SetNeighbours.call(card_season_id:, kind:, key:, locale:)` → `Data(set: SetRef, position:, total:, previous:, next:)` (neighbour slugs or nil) or nil when that set of the card-season's season does not hold it; one query (window functions `ROW_NUMBER`, `COUNT`, `LAG`/`LEAD` over slot order, filtered to the card-season); test order, ends, locale skip, wrong set, other season.
- [x] `app/controllers/cards_controller.rb` -- as in Code Map; update the header comment.
- [x] `app/helpers/card_details_helper.rb` -- `set:` on `link_to_card_detail`; `card_back_image(key)` (`image_tag vite_asset_path("images/pixel/back-#{key}.svg")`, 208 × 312, `alt=""`, key checked against `Game::CardBacks::KEYS`); neighbour URL helper keeping the season number and set query.
- [x] `app/views/cards/_detail.html.erb` -- bracketed panel (`PanelComponent brackets: true` or equivalent) with: header kicker "Fiche de la carte" + number label top right; stage with ◀ / ▶ (44 × 64, links with `data-turbo-frame="card-detail"`, `data-turbo-action="replace"`, aria-labels "Previous card"/"Next card"; disabled buttons at the ends) around the card (`CardComponent size: :l`, or the faded back + title + year + "Not owned" tag) over a ground shadow; h1 title; position line (`S1 · #4 215 · 3 / 13 · swipe to browse`, hint only when total > 1, number part omitted when unnumbered); description; fact rows label/value on panel-sunken: publisher, rarity (icon + name in rarity colour), genre, year, season ("Season 1"), sets (links to their set only in the published season), copies (signed-in only: "2 copies"/"None"); notice; share link field + status (when `share_url`); actions: "Voir sur Steam" + "Partager" (`share#copy`, only with `share_url`). Locals stay a Detail plus the new browse/faded/back data.
- [x] `app/views/cards/show.html.erb` -- `turbo_frame_tag "card-detail", target: "_top"` around the detail; `content_for :phone_back` "◀ Grille" (history-back controller) when the browse set is in the published season; visitor invitation outside the frame, its button secondary.
- [x] `app/views/shell/_top_bar.html.erb` + `shell.css` -- the `:phone_back` slot (bridge button hidden under 720 px when present; slot hidden from 720 px).
- [x] `app/views/library/_tome.html.erb`, `app/views/library/set.html.erb` -- `browse: true` local passes `set:` to the card links.
- [x] `app/frontend/lib/swipe.ts` (+ `swipe.test.ts`) -- `swipeStep(dx, dy, threshold = 70)` → -1 | 0 | 1 (horizontal dominant only).
- [x] `app/frontend/lib/history_trail.ts` (+ `history_trail.test.ts`) -- record `{restorationIndex → pathname}` in sessionStorage (try/catch), and `stepsBackTo(pathname)` → the distance to the nearest earlier entry with that pathname, or null.
- [x] `app/frontend/controllers/history_back_controller.ts` -- records on `turbo:load`/`turbo:frame-load`; on click, `history.go(-steps)` when the link's pathname is an earlier entry (grid restored at its scroll), else lets the link navigate.
- [x] `app/frontend/controllers/sub_view_controller.ts` -- on the detail article: swipe on the stage (pointer events, `touch-action: pan-y`) clicks the ◀/▶ link; nav clicks set `html[data-sub-view-step=prev|next]`; wraps the frame's `turbo:before-frame-render` in `document.startViewTransition` when motion is allowed (card out toward the step, new card in with a slight turn, 260 ms; `.main` loses its `screen` name meanwhile), clears the flag after; syncs `document.title` from a value; keeps focus on the same nav control after a step.
- [x] `app/frontend/controllers/starfield_controller.ts` -- skip the shift while `data-sub-view-step` is set.
- [x] `app/frontend/styles/card-detail.css` -- rewrite: panel up to ~720 px centred; container query: two columns (stage | info) when wide, one column when narrow; under 720 px viewport: nav buttons beside the card, position line shown, header number hidden, actions sticky above the tab bar (`--space-tabbar-height` + safe area); faded back at opacity .55; reduced-motion rules; view-transition animations.
- [x] `config/locales/en.yml`, `fr.yml` -- new and reworded `card_details.*`, `cards.show.grid`; drop keys no longer used.
- [ ] Tests -- rework the controller, preview-tags and system tests above; add: faded back cases, set-context links from the tome, ◀ ▶ hrefs and disabled ends, query counts (visitor 3, player 10), a phone system test (390 × 844: ▶ moves to the next card and the URL changes without a new history entry, swipe moves too, "◀ Grille" returns to the grid at its scroll, actions visible without scrolling), French facts.

**Acceptance Criteria:**
- Given a player in a tome on a phone, when they open a card and press ▶ twice then "◀ Grille", then the grid shows at the scroll it had and browser Back from the detail does the same.
- Given any card page, when it renders in en or fr, then title, publisher, rarity, genre, year, description, season, sets and (signed in) copies show in that language, and "Voir sur Steam" opens a new tab with that said in its name.
- Given a visitor opening a share link, then the face, the facts, the preview tags and the invitation show as before, with no copies and no Partager.
- Given reduced motion, when stepping through cards, then nothing slides or turns.

## Implementation Notes

**Files touched.** New: `packs/catalog/app/queries/catalog/set_neighbours.rb` (+ `test/packs/catalog/set_neighbours_test.rb`), `app/frontend/lib/swipe.ts` (+ test), `app/frontend/lib/history_trail.ts` (+ test), `app/frontend/controllers/sub_view_controller.ts`, `app/frontend/controllers/history_back_controller.ts`, `app/views/cards/_detail_nav.html.erb`, `app/views/layouts/_head.html.erb`, `app/views/layouts/turbo_rails/frame.html.erb`, `app/frontend/images/pixel/back-standard.svg` (exported). Changed: `cards_controller.rb`, `card_details_helper.rb`, `cards/_detail.html.erb`, `cards/show.html.erb`, `layouts/application.html.erb` (head moved to the partial), `shell/_top_bar.html.erb`, `library/_tome.html.erb`, `library/set.html.erb`, `starfield_controller.ts`, `card-detail.css`, `shell.css`, `en.yml`, `fr.yml`, `script/pixel_art/export.mjs`; tests `cards_controller_test.rb`, `card_preview_tags_test.rb`, `library_set_test.rb`, `system/card_detail_test.rb`, `system/share_card_test.rb`.

**Decisions.**
- *Frame layout overridden (not in the Code Map).* A frame visit promoted with `data-turbo-action` makes Turbo merge the response's `<head>` into the page's and set `<html lang>` from it. turbo-rails' bare `turbo_rails/frame` layout has no title, viewport, lang or view-transition meta, so the first ◀ ▶ blanked the title and dropped the viewport meta, `lang` and the View Transition meta (found by the phone system test). The page head moved to `layouts/_head.html.erb`, rendered by `application.html.erb` and by an app override of `layouts/turbo_rails/frame.html.erb` (with `<html lang>`). Frame responses stay shell-free (a frame visit costs 5 queries for a player, no top bar). Side effect: canonical/og tags and the title now follow the card after a step. The back-office `import_run` frame uses the same layout (bigger head, no behaviour change).
- *Turbo's own page View Transition is suppressed during a step.* The promoted visit renders no body but goes through `renderPageSnapshot`, which would start a second `startViewTransition` and skip the card's. `sub_view_controller` sets the `view-transition` meta to `none` from the press until the step ends (Turbo reads the live head), and restores it; the merged head brings the meta back anyway. The step flag (`html[data-sub-view-step]`) ends after `turbo:load` and the card transition's `finished`, with a 5 s fallback.
- *Recording the history trail.* Every page must be recorded, not only those with a back link, so `history_back_controller.ts` adds two document listeners (`turbo:load`, `turbo:frame-load`) once at module import, for the app's lifetime; the controller itself only handles the click. The trail is keyed by Turbo's `history.state.turbo.restorationIndex`, bounded to ±100 entries, try/catch around sessionStorage; modified clicks keep the browser's behaviour.
- *◀ ▶ and the position line are phone-only* (hidden from 720 px, per DESIGN "Phone: …"); the header number is hidden under 720 px instead. On desktop the "◀ Pont" button stays; "◀ Grille" is shown under 720 px only (`.top-bar__start--phone-back`).
- *Faded back* = named, valid set context and no copies (visitor or holder of 0). The card's own page and an ignored set query show the face. Title and year on the back are `aria-hidden` (h1 and the Year row carry them); "Not owned" is read.
- *Copy.* en kicker "Card file"; facts Publisher/Rarity/Genre/Year/Season/Sets/Copies (fr Éditeur/Rareté/Genre/Année/Saison/Sets/Exemplaires; "Collections" became "Sets", as the rest of the French copy says); copies "2 copies"/"None" (fr "2 exemplaires"/"Aucun"); "See on Steam"/"Voir sur Steam" + visually hidden "(new tab)"/"(nouvel onglet)" and the ↗ icon; "Share"/"Partager"; "Not owned"/"Non possédée"; "swipe to browse"/"glissez pour parcourir"; "Previous card"/"Next card"; `cards.show.grid` "Grid"/"Grille". The tutoiement in `card_details.share.manual` became "Appuyez…". Dropped: `card_details.year/rarity/season/sets/publisher` (moved under `facts`), the old "You hold…" copies.
- *Share status* is a VT323 sentence (not uppercased), still a `role=status` region; the share controller sits on the article (`data-controller="sub-view share"`) so "Partager" can live in the actions row while the link field stays above it.
- *Swipe* is touch-only (pointer events, `isPrimary`), ignored once the face reports `data-tilting` during the gesture; a step presses the ◀/▶ link, so an end (disabled button) does nothing.
- *Back art:* 104 × 156 art pixels, procedural and deterministic; the weave makes the SVG ~90 KB uncompressed (repetitive paths, gzips well).

**Review follow-ups (round 1).**
- *Scroll padding:* under 720 px, `html:has(.card-detail__actions)` adds the pinned actions' height (`--card-detail-actions-height`, a phone button plus padding, on `:root`) to `scroll-padding-bottom`, so a focused set link or share field is never hidden behind them.
- *Trail reset:* `resetTrail()` empties the trail when `history_back_controller.ts` loads (once per full document load, where Turbo's restoration index restarts at 0), so an index left by an earlier document never sends `history.go` to the wrong page. It has a unit test.
- *Swipe from 720 px:* `release()` presses ◀/▶ only when the control is displayed (`checkVisibility()`, else `offsetParent`), so a touch swipe on a wide screen does nothing.
- *Faded back plate:* title, year and "Not owned" now sit on one panel-sunken plate, 18 px from the back's bottom, with the title clamped to two lines. A system check with a long title asserts the plate stays below the back's word (≥ 216 px down) and the title has 2 lines at most.

**Surprises.** Turbo's head merge on promoted frame visits (above). `.top-bar__phone-back { display: none }` lost to `.button { display: inline-flex }` (same specificity, later rule): scoped to `.top-bar__start > .top-bar__phone-back`.

**Verification run.** `bin/rubocop` clean; `packwerk validate` + `check` clean; `i18n-tasks missing` none (and `unused` none); `node script/pixel_art/export.mjs --check` up to date; `npm run typecheck` + `npm run test:js` (136) pass; `bin/rails test` 1155 runs pass; `bin/rails test:system` 78 runs pass (5 full parallel runs: 3 green in a row at the end; two earlier runs each had a load-related error outside this story, e.g. `PackRevealTest` not finding the top bar's Steam sign-in at its setup, not reproduced since); `test/system/card_detail_test.rb` re-run 5× green after its scroll assertions were made to wait for Turbo's restore. A quick second ◀/▶ press cannot be ended by the first step's pending transition (a step id guards `endStep`).

## Plan Change Log

- 2026-10-06 — Integration with stories 8.8 and 10.1 (rebased onto `0574a26`): the hand-made `back-standard.svg` and its `standardBack` drawing were removed from `script/pixel_art/export.mjs`; `card_back_image` now draws story 8.8's `back-standard-l.png` (104 × 156 art pixels at 2 CSS px), and the faded back's plate stays clear of its ring, covering the decorative "GAMEBLE" word that 8.8's back draws at the bottom. Story 10.1 replaced the tome on `/library/:kind/:key` with the collection grid: `library/_grid` passes the set it shows to `link_to_card_detail`, so its ◀ ▶ browse it and "◀ Grille" returns to it; `library/_tome` (now only the public profile's) is back to story 10.1's version, without a set. The phone system test now waits for the forward restore visit to scroll the detail to its top before going back (going back within that instant filed the detail's scroll under the grid's history entry).

## Review Triage Log

### 2026-10-06 — Review pass
- verdicts: 6 findings — high 0, medium 2, low 3, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` Phone `scroll-padding-bottom` (shell.css) covers the tab bar only, so a focused element behind the pinned actions stays hidden (DESIGN.md Focus ring) — fixed: `html:has(.card-detail__actions)` under 720px adds `--card-detail-actions-height` (72px) to the scroll padding; the pinned bar's min-height uses it.
  - `[low]` `[patch]` The history trail (sessionStorage, keyed by Turbo's restorationIndex) survives a full page load while Turbo's index restarts at 0, so after Back across a full load "◀ Grille" could `history.go` to the wrong entry — fixed: `resetTrail` at module load, so only the current Turbo session's entries are trusted (unit test added); a one-call fix for a wrong navigation.
  - `[low]` `[reject]` `sub-view#step` runs on Ctrl/Cmd/Shift-click, leaving the step flag and the view-transition meta "none" until the 5 s fallback — real, but ◀ ▶ exist only under 720px where modified clicks practically never happen, and the fix adds a guard.
  - `[false]` `[reject]` `history_back_controller.ts` adds module-level `turbo:load`/`turbo:frame-load` listeners never removed, against "listeners removed on disconnect" — the module is evaluated once per document, so the two listeners are never duplicated or leaked; the boundary is about controller listeners, and the decision is recorded in Implementation Notes.
  - `[medium]` `[patch]` Swipe works at every width: on a touch device ≥720px it clicks the hidden ◀/▶ and changes the card with no visible control — fixed: `release()` clicks only an anchor that is displayed (`checkVisibility()` / `offsetParent`).
  - `[low]` `[patch]` On the faded back a long title (anchored `bottom: 76px`, wrapping upward) runs over the back's "GAMEBLE" word and ring — fixed: title, year and "Not owned" grouped in one bottom plate on panel-sunken, title clamped to two lines; system test with a very long French title checks the plate stays below the word. Long titles are common, so users meet it.

## Design Notes

- **Set context and the faded back.** The share link and the card's own page carry no set; in-app grids add `?set_kind=&set_key=`. Within a set (and when browsing with ◀ ▶, whose links always carry the set) a card not held shows the viewer's active back (AD-25; Standard for a visitor too); the card's own page shows the face to everyone so a shared link still shows the card until story 10.3 builds the public card page. Showcase and pack faces lead to owned cards, so they show the face anyway.
- **Replace, not advance, for ◀ ▶.** Opening the detail from the grid advances the URL; ◀ ▶ replace it, so browser Back from any card returns to the grid (Turbo restores its scroll) and "◀ Grille" can `history.back()` to it.
- **One query for the neighbours:**
  ```sql
  SELECT position, total, previous, next FROM (
    SELECT m.card_season_id, ROW_NUMBER() OVER w AS position, COUNT(*) OVER () AS total,
           LAG(c.slug) OVER w AS previous, LEAD(c.slug) OVER w AS next
    FROM catalog_set_memberships m JOIN catalog_sets s … JOIN catalog_card_seasons cs … JOIN catalog_cards c …
    JOIN catalog_card_texts t ON t.card_id = c.id AND t.locale = :locale
    WHERE s.season_id = (SELECT season_id FROM catalog_card_seasons WHERE id = :id) AND s.kind = :kind AND s.key = :key
    WINDOW w AS (ORDER BY m.position, m.id)) ranked WHERE card_season_id = :id
  ```
- **Integration with story 10.1:** the grid's links should call `link_to_card_detail(card, strings:, set:)`; the desktop right-hand panel can render `cards/_detail` (its container query collapses to one column at 340 px).

## Auto Run Result

**Summary.** The card page is rebuilt as DESIGN.md's bracketed "FICHE DE LA CARTE" panel in a `card-detail` Turbo Frame: card at card-l over a ground shadow, header kicker and number, title, description, fact rows (publisher, rarity, genre, year, season, sets, copies for a signed-in player), the kept ownership notice, "Voir sur Steam" (primary, new tab said in its name) and "Partager" (holders only, existing share controller). The page browses one set (named by `set_kind`/`set_key`, else the card's first set) through the new `Catalog::SetNeighbours` query: on a phone ◀ ▶ (44 × 64) and swipe replace the frame and URL in a View Transition, a position line "S1 · #n · i / n · glissez pour parcourir", actions pinned above the tab bar, and "◀ Grille" in the top bar going back through history to the grid at its scroll. Within a named set, a card the viewer does not hold shows the Standard back (new exported `back-standard.svg`) at 55 % with its title, year and "Non possédée"; the card's own page (share link) shows the face to everyone.

**Files changed.**
- `app/controllers/cards_controller.rb` — browse set, `@browse`, `@faded`, `@back_key`.
- `packs/catalog/app/queries/catalog/set_neighbours.rb` (+ test) — position, total and neighbours in one window-function query.
- `app/helpers/card_details_helper.rb` — `set:` on card links, detail/neighbour paths, `card_back_image`.
- `app/views/cards/_detail.html.erb`, `_detail_nav.html.erb`, `show.html.erb` — the panel, ◀ ▶, frame, phone back, secondary invitation button.
- `app/views/layouts/_head.html.erb`, `application.html.erb`, `turbo_rails/frame.html.erb` — one head for pages and frame responses (Turbo merges a promoted frame visit's head).
- `app/views/shell/_top_bar.html.erb`, `app/frontend/styles/shell.css` — phone-only contextual back slot; a sub-view step is no screen change.
- `app/views/library/_tome.html.erb`, `set.html.erb` — the own library's card links carry the set.
- `app/frontend/controllers/sub_view_controller.ts`, `history_back_controller.ts`, `starfield_controller.ts`; `app/frontend/lib/swipe.ts`, `history_trail.ts` (+ tests) — swipe, step transition, title and focus, history trail, no star shift on a step.
- `app/frontend/styles/card-detail.css` — rewritten.
- `script/pixel_art/export.mjs`, `app/frontend/images/pixel/back-standard.svg` — the Standard back.
- `config/locales/en.yml`, `fr.yml` — card detail copy ("vous").
- Tests: `cards_controller_test.rb`, `card_preview_tags_test.rb`, `library_set_test.rb`, `system/card_detail_test.rb`, `system/share_card_test.rb`.

**Review.** Quick lens, 6 findings: 4 patched (2 medium, 2 low), 2 rejected (a low modified-click case not reachable in practice on the phone-only controls, whose fix adds a guard; a false claim about module-level listeners, evaluated once per document). Nothing deferred from the review; scope deferrals are in `deferred-work.md`.

**Follow-up review: recommended (true).** Two medium entries were patched (scroll padding, swipe width guard). Unverified risk: the swipe, the step's View Transition and the history-trail back have been checked only in headless Chromium with synthetic pointer events, never on a real touch device (iOS Safari, Android Chrome).

**Verification.** `bin/rubocop` clean; `packwerk validate` and `check` clean; `i18n-tasks missing` none; `node script/pixel_art/export.mjs --check` up to date; `npm run typecheck` clean; `npm run test:js` 137 passed; `bin/rails test` 1155 runs, 0 failures; `bin/rails test:system` 78 runs, 0 failures (run after the patches).

**Residual risks.** Story 8.11 / epic 9 redraw the card backs: if they ship backs as PNGs in `app/frontend/images/pixel/`, `export.mjs --check` and `card_back_image` (SVG path) need reconciling. Story 10.1 rebuilds the grid in parallel: its links must pass `set:` to `link_to_card_detail`, and "◀ Grille" points at `library_set_path`. The frame-layout override applies to every Turbo Frame response.

## Verification

**Commands** (with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w102` and `CHROME_BIN=/usr/bin/chromium`):
- `bin/rubocop` -- no offences
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` -- none
- `node script/pixel_art/export.mjs --check` -- up to date
- `npm run typecheck && npm run test:js` -- pass
- `bin/rails test && bin/rails test:system` -- pass
