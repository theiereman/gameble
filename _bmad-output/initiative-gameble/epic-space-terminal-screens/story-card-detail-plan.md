---
title: 'Card detail'
type: 'feature'
ticket: '2'
created: '2026-10-06'
status: 'built'
baseline_revision: '0574a2640f0a1a2d7940f367d38b5e764a1a9658'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 2
followup_review_recommended: false
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
- [x] Tests -- rework the controller, preview-tags and system tests above; add: faded back cases, set-context links from the tome, ◀ ▶ hrefs and disabled ends, query counts (visitor 3, player 10), a phone system test (390 × 844: ▶ moves to the next card and the URL changes without a new history entry, swipe moves too, "◀ Grille" returns to the grid at its scroll, actions visible without scrolling), French facts.

- [x] Follow-up review fixes (2026-10-06, see Plan Change Log; leave every task above as it is):
  - [x] Whole-season collection (`library/show.html.erb` renders `library/collection` with `set: nil`, so `library/_grid` links carry no set and a missing slot opens the face): each card's link there names the card's own tome (kind `tome`, the key of the one tome its card-season sits in, as `Catalog::CardViews::GENRE` finds it; a card-season sits in one tome at most), so a card the viewer does not hold opens on the faded back and ◀ ▶ browse that tome, the set the detail browses by default anyway. A card in no tome keeps a link without a set. Load the tomes of the page's cards in one query for the whole page (a Catalog query keyed by card-season id, returning `Catalog::SetSlots::SetRef`s, or an equivalent), only when no set is shown; never one query per card; keep query-count tests passing (raise a counted budget by one where the whole-season page now runs that query, and say so). A set page keeps passing its own set. Controller test: on `/library` the links of a held and a missing card carry `?set_key=<tome>&set_kind=tome`; system test: from `/library` a missing slot opens the faded back. Update the matching `deferred-work.md` entry (story 10.1's, "A grid slot opens the card's detail page …") so it no longer says the whole-season links name no set.
  - [x] Focus (EXPERIENCE.md "Focus after each step": "Sub-view opened (phone) → Its heading"; "Back or dialog closed → The element that opened it"): `app/frontend/controllers/sub_view_controller.ts` focuses the detail's heading (`h1`, already `tabindex=-1` and the `heading` target) when the detail connects on a phone layout (the ◀ ▶ shown, under 720px), unless a keyboard step is restoring focus to a nav control (existing `focusAfterStep`) or the page is a Turbo preview; use `preventScroll: true`. When a page is shown again by a restore visit (browser Back or "◀ Grille"'s `history.go`), focus the card link on it that leads to the card detail the user came back from (the history trail's entry right after the current one, matched on the link's pathname), with `preventScroll: true`, so the scroll Turbo restores is kept; nothing when no such link is on the page. Cover the trail lookup with a unit test (`history_trail.test.ts`) and extend the phone system test (`test/system/card_detail_test.rb`): the heading has focus once the detail opens from the grid, and after "◀ Grille" the focused element is the grid link of the card last shown, the grid still at its scroll.
  - [x] Position line (`app/views/cards/_detail.html.erb`): on an unnumbered card keep the season — "S1 · 3 / 13 · swipe to browse" — instead of dropping both season and number (`number_label` is nil without a number); controller test for an unnumbered card's position line.
  - [x] History trail (`app/frontend/lib/history_trail.ts`, `app/frontend/controllers/history_back_controller.ts`): Turbo 8 restores its restoration index from `history.state` on a reload or a back/forward document load (`turbo.es2017-esm.js`: `this.currentIndex = history.state?.turbo?.restorationIndex || 0`), so the comments saying it "restarts at 0" are wrong — correct them. A page restored from the back/forward cache re-runs neither the module nor `turbo:load` and could read a later document's trail: on `pageshow` with `persisted`, reset the trail and record the current entry. Keep the reset at module load (a reload losing the trail falls back to a plain visit, accepted).

- [x] Follow-up review fixes, loop 2 (2026-10-06, see Plan Change Log; leave every task above as it is):
  - [x] "◀ Grille" from the whole-season collection (EXPERIENCE.md Phone navigation: a sub-view slides over its screen with a contextual back "◀ GRILLE"): the back must lead to the grid the detail was opened from. Opened from `/library` (whose links now name the card's tome), "◀ Grille" goes back through history to the season grid, at its scroll and with the focus on its link to the card last shown, not to the tome's grid. Keep the server's href (the browsed set's grid, `library_set_path`) and its plain-visit fallback; in `app/views/cards/show.html.erb` give the history-back link the season collection's path (`library_path`) as an alternate target (a Stimulus value on `history_back_controller`, e.g. `alternates`, an array of pathnames), and in `app/frontend/controllers/history_back_controller.ts` go back to whichever of the href's pathname and the alternates is the nearest earlier trail entry (fewest steps via `stepsBackTo`); when none is in the trail, let the link navigate to its href as today. Only for a detail whose browse set is in the published season (the existing condition). Extend the phone system test (`test/system/card_detail_test.rb`): from `/library` on a phone, open a card (scroll the grid first), step with ▶, press "◀ Grille": the URL is `/library` (not the tome's grid), the grid at its scroll, the focus on its link to the card last shown. Controller test: the phone back link carries the season path as an alternate. Update story 10.1's `deferred-work.md` entry ("A grid slot opens the card's detail page …") so it no longer says "◀ Grille" leads to the tome's grid.
  - [x] Stale keyboard-step focus (`app/frontend/controllers/sub_view_controller.ts`): `focusAfterStep`, set by a keyboard ◀/▶ press, is cleared only by the next `connect`; when the step's frame visit fails or is cancelled (`endStep` from the `STEP_TIMEOUT_MS` fallback), a later detail's `connect` focuses a nav control instead of its heading. Clear `focusAfterStep` in `endStep()` (after the connect that consumes it has run, i.e. the normal path keeps working: `connect` reads it before `stepLoaded` ends the step, or reorder so it does).

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

**Review follow-ups (loop 1, follow-up review).**
- *Whole-season links:* new `Catalog::CardTomes.call(card_season_ids)` → `{ id => SetRef }` (one query, tomes only, first membership wins; + `test/packs/catalog/card_tomes_test.rb`). `LibraryController#load_grid` runs it only when the grid shows no set and adds the tome as a third element of each slot; `library/_grid` passes `set || tome` to `link_to_card_detail`. `/library` budgets raised by one: player 13 → 14, visitor 8 → 9 (banned player 1 + 9); a set's page is unchanged (15 / 10).
- *Focus:* `sub_view_controller` focuses the heading (`preventScroll`) on connect when ◀ ▶ are displayed and no keyboard step is restoring a nav control, never on a Turbo preview (also after a mouse or swipe step). `history_back_controller.ts` notes a `turbo:visit` of action `restore` and, on the following `turbo:load`, focuses the page's `a.card-link` whose pathname is the trail's entry right after the current one (`entryAfter`, unit-tested), with `preventScroll`.
- *Grid placeholder size (story 10.1's CSS):* `.collection-slot`'s `contain-intrinsic-size` added the bleed twice (it sizes the content box; the padding comes on top), so a slot not rendered yet (every slot right after a Turbo restore) stood 24px taller than once rendered. With the focus on a grid link, Chrome's scroll anchoring then kept that link in place as the slots shrank, leaving the grid 48px off its scroll (found by the phone system test). Fixed in `collection.css` to the card's own size: the restored grid no longer shifts, focus or not.
- *History trail:* the comments now say Turbo reads its restoration index back from `history.state` on a reload or back/forward document load; `pageshow` with `persisted` resets the trail and records the current entry.

**Review follow-ups (loop 2, follow-up review).**
- *"◀ Grille" from the whole season:* `cards/show.html.erb` gives the phone back `data-history-back-alternates-value` = `["<library_path>"]`; `history_back_controller.ts` (`alternates` Array value) goes back through `backSteps` (`lib/history_trail.ts`, unit-tested): one step when the entry right before is the href's page or an alternate (◀ ▶ only replace entries, so the page the detail was opened from is always one step back), else to the href's page when it is an earlier entry, else lets the href (the browsed set's grid) navigate. An alternate further back (COLLECTION → PONT → a showcase card) is ignored: the tome's grid is visited. Controller test checks the alternate; a phone system test opens a card from `/library` (scrolled; the test picks a card whose next tome card is on the grid's first page, as the season grid is paginated), steps ▶, presses "◀ Grille": back on `/library` at its scroll, focus on the link to the card last shown. Story 10.1's `deferred-work.md` entry updated.
- *Stale keyboard-step focus:* `endStep()` clears `focusAfterStep`; `step()` now sets it after `beginStep()` (which ends any running step). The consuming `connect` runs before `endStep` on the normal path (the frame renders before the promoted visit's `turbo:load`; with a View Transition, its update runs before `finished`).

**Surprises.** Turbo's head merge on promoted frame visits (above). `.top-bar__phone-back { display: none }` lost to `.button { display: inline-flex }` (same specificity, later rule): scoped to `.top-bar__start > .top-bar__phone-back`.

**Verification run.** `bin/rubocop` clean; `packwerk validate` + `check` clean; `i18n-tasks missing` none (and `unused` none); `node script/pixel_art/export.mjs --check` up to date; `npm run typecheck` + `npm run test:js` (136) pass; `bin/rails test` 1155 runs pass; `bin/rails test:system` 78 runs pass (5 full parallel runs: 3 green in a row at the end; two earlier runs each had a load-related error outside this story, e.g. `PackRevealTest` not finding the top bar's Steam sign-in at its setup, not reproduced since); `test/system/card_detail_test.rb` re-run 5× green after its scroll assertions were made to wait for Turbo's restore. A quick second ◀/▶ press cannot be ended by the first step's pending transition (a step id guards `endStep`).

## Plan Change Log

- 2026-10-06 — Integration with stories 8.8 and 10.1 (rebased onto `0574a26`): the hand-made `back-standard.svg` and its `standardBack` drawing were removed from `script/pixel_art/export.mjs`; `card_back_image` now draws story 8.8's `back-standard-l.png` (104 × 156 art pixels at 2 CSS px), and the faded back's plate stays clear of its ring, covering the decorative "GAMEBLE" word that 8.8's back draws at the bottom. Story 10.1 replaced the tome on `/library/:kind/:key` with the collection grid: `library/_grid` passes the set it shows to `link_to_card_detail`, so its ◀ ▶ browse it and "◀ Grille" returns to it; `library/_tome` (now only the public profile's) is back to story 10.1's version, without a set. The phone system test now waits for the forward restore visit to scroll the detail to its top before going back (going back within that instant filed the detail's scroll under the grid's history entry).
- 2026-10-06 — Follow-up review (loop 1). Triggering findings: (1) from the whole-season collection a missing slot opens the card's face, not the faded back, as its links name no set (EXPERIENCE.md Missing-card slot); (2) the phone sub-view focuses neither its heading on opening nor, on Back, the element that opened it (EXPERIENCE.md Focus after each step); (3) on an unnumbered card the position line drops the season; (4) the history trail's comments assume Turbo restarts its index at 0 on every document load, and a back/forward-cache restore can read a later document's trail. Amended: Design Notes "Set context" (the whole-season grid names each card's tome) and a new task group "Follow-up review fixes" under Execution; the stale "Tests" checkbox is ticked (those tests are in the commit). Known-bad state avoided: a player seeing the face of a card they do not hold from the COLLECTION tab; keyboard and screen-reader users left at the top of the document after opening a card or coming back to the grid; "◀ Grille" sending `history.go` to an unrelated entry after a back/forward-cache restore. KEEP: everything already committed (b7776c2) — the panel, `Catalog::SetNeighbours`, the frame layout override, ◀ ▶ replace visits and their View Transition, the swipe width guard, the scroll padding, the faded back as 8.8's `back-standard-l.png` with its plate clear of the ring, the set grid's links with their set, the phone system test waiting for the forward visit's scroll; no change to the share link's face or to the query rule for a card's own page.

- 2026-10-06 — Follow-up review, loop 2. Triggering findings: (1) from the whole-season collection "◀ Grille" leads to the card's tome grid (a plain visit, at its top) rather than back to the season grid the sub-view slid over (EXPERIENCE.md Phone navigation), as the links there now name the tome; (2) a keyboard ◀/▶ step whose frame visit fails leaves `focusAfterStep` set, so a later detail focuses a nav control instead of its heading. Amended: a new task group "Follow-up review fixes, loop 2" under Execution, and Design Notes "Set context" (the phone back's alternate). Known-bad state avoided: a phone user opening a card from the COLLECTION tab and losing their place in the season grid on "◀ Grille"; focus landing on ◀/▶ after a failed step. KEEP: everything already committed (b7776c2) and everything the loop-1 fixes put in the working tree (`Catalog::CardTomes` and the whole-season links naming the tome, heading and return-link focus, `entryAfter`, the unnumbered position line, the `pageshow` trail reset and corrected comments, the `contain-intrinsic-size` fix, their tests); the server-rendered href of "◀ Grille" stays the browsed set's grid. As all the code is kept, the revert before re-derivation is empty.

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

### 2026-10-06 — Review pass (follow-up)
- verdicts: 5 findings — high 0, medium 2, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[bad_plan]` From the whole-season collection (`/library`, grid `set: nil`) a missing slot's link names no set, so `@faded` is false and the detail shows the face of a card the viewer does not hold, against EXPERIENCE.md Missing-card slot — verified in `CardsController#show` (`@faded = !named.nil? && @copies.nil?`) and `library/_collection` (`set: grid.set`, nil for the season); plan amended: the whole-season grid's links name each card's tome (new task).
  - `[medium]` `[bad_plan]` The phone sub-view does not focus its heading when it opens, and Back / "◀ Grille" do not return focus to the grid slot that opened it (EXPERIENCE.md Focus after each step) — verified: `sub_view_controller` focuses the heading only after a keyboard step onto a disabled end; `history_back_controller` leaves focus to Turbo's restore; plan amended: a focus task.
  - `[low]` `[bad_plan]` The history trail's comments say Turbo's restoration index restarts at 0 on each document load, while Turbo 8 restores it from `history.state` on a reload or back/forward load; a back/forward-cache restore re-runs neither the module nor `turbo:load`, so the trail can hold a later document's indexes and "◀ Grille" can `history.go` to an unrelated entry — verified in `node_modules/@hotwired/turbo/dist/turbo.es2017-esm.js:4540`; the reload case only falls back to a plain visit (accepted); folded into the amended plan as a task, as a bad_plan loopback makes the patch route moot.
  - `[low]` `[bad_plan]` On an unnumbered card the position line drops the season with the number ("3 / 13 · swipe to browse"), where the plan says only the number part is omitted — verified: `[ view.number_label, … ].compact` and `CardView#number_label` nil without a number; folded into the amended plan as a task.
  - `[low]` `[reject]` The plan's records (export.mjs SVG task, Files touched, Auto Run Result, Residual risks, unchecked "Tests") describe the pre-rebase change — its fix is to edit this build's plan; the integration is recorded in the Plan Change Log, and Auto Run Result is rewritten at finalisation.

### 2026-10-06 — Review pass (follow-up, loop 2)
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[bad_plan]` From the whole-season collection "◀ Grille" points at the tome's grid (`cards/show.html.erb`, `library_set_path(@browse.set)`), which is no earlier trail entry, so it is a plain visit to another screen at its top; the season grid's scroll and the return focus are lost (EXPERIENCE.md Phone navigation: the contextual back of a sub-view over its screen) — verified: `library/_grid` passes `set || tome`, `stepsBackTo` matches the href's pathname only; plan amended: "◀ Grille" also accepts the season collection's path as an alternate history target (new task, loop 2).
  - `[low]` `[bad_plan]` `focusAfterStep` (module-level in `sub_view_controller.ts`) is cleared only by the next `connect`; `endStep()` from the 5 s fallback (a failed or cancelled step visit) leaves it set, so a later detail's `connect` focuses ◀/▶ instead of its heading — verified: `endStep` never resets it and the heading focus is the `else` of `if (focusAfterStep)`; a direct fix, folded into the loop-2 task group as moot under the bad_plan loopback.
  - `[low]` `[reject]` `cards/_detail.html.erb` hard-codes the "S" of "S1" for an unnumbered card outside the locale files and copies `Catalog::CardView#number_label`'s format — real but negligible: "S" is the same in both locales and `CardView#number_label` already hard-codes it, so the two cannot diverge unless that format is changed, which no one meets in everyday use; the fix would add a public method to `CardView`.

### 2026-10-06 — Review pass (follow-up, loop 2 re-review)
- verdicts: 1 findings — high 0, medium 1, low 0, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` "◀ Grille" went back to the alternate `/library` whenever it was any earlier trail entry (within `TRAIL_SPAN`), not only when the detail was opened from it: COLLECTION → PONT → a showcase card (browsing its first tome) → "◀ Grille" ran `history.go(-2)`, skipping the hub and landing on the season grid rather than visiting the tome's grid — verified in `history_back_controller.ts#back` (nearest of all candidates via `stepsBackTo`); fixed: new `backSteps` in `lib/history_trail.ts` takes an alternate only when it is the entry right before the current one (◀ ▶ only replace entries), else the href's page as before, else a plain visit; unit test covers the adjacent, bridge, far-back and right-before cases.

## Design Notes

- **Set context and the faded back.** The share link and the card's own page carry no set; in-app grids add `?set_kind=&set_key=` (a set's grid its own set; the whole-season collection each card's tome). Within a set (and when browsing with ◀ ▶, whose links always carry the set) a card not held shows the viewer's active back (AD-25; Standard for a visitor too); the card's own page shows the face to everyone so a shared link still shows the card until story 10.3 builds the public card page. Showcase and pack faces lead to owned cards, so they show the face anyway. On a phone, "◀ Grille" goes back through history to the browsed set's grid or, when the detail was opened from it, to the whole-season collection (an alternate target), whichever is the nearest earlier entry; otherwise it visits the set's grid.
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

**Summary.** The card page is rebuilt as DESIGN.md's bracketed "FICHE DE LA CARTE" panel in a `card-detail` Turbo Frame: card at card-l over a ground shadow, header kicker and number, title, description, fact rows (publisher, rarity, genre, year, season, sets, copies for a signed-in player), the kept ownership notice, "Voir sur Steam" (primary, new tab said in its name) and "Partager" (holders only, existing share controller). The page browses one set (named by `set_kind`/`set_key`, else the card's first set) through `Catalog::SetNeighbours`: on a phone ◀ ▶ (44 × 64) and swipe replace the frame and URL in a View Transition, a position line ("S1 · #n · i / n · glissez pour parcourir", "S1 · i / n · …" unnumbered), actions pinned above the tab bar, and "◀ Grille" going back through history to the grid it was opened from, at its scroll, with the focus on that grid's link to the card last shown; the sub-view's heading takes the focus as it opens. Within a named set a card the viewer does not hold shows story 8.8's Standard back (`back-standard-l.png`, 2 CSS px per art pixel) at 55 % with its title, year and "Non possédée"; the card's own page (share link) shows the face to everyone. Collection grids (story 10.1) name their set in each link; the whole season names each card's tome (`Catalog::CardTomes`, one query), so a missing slot opens on the faded back there too, and "◀ Grille" returns to the season grid.

Commits: `b7776c2` (story and its integration with 8.8 and 10.1, made during the rebase onto `0574a26`); the follow-up review (loops 1 and 2) in the commit that records this result.

**Files changed (follow-up).**
- `packs/catalog/app/queries/catalog/card_tomes.rb` (+ `test/packs/catalog/card_tomes_test.rb`) — each card-season's tome in one query.
- `app/controllers/library_controller.rb`, `app/views/library/_grid.html.erb` — whole-season links name the card's tome (budgets: player 13 → 14, visitor 8 → 9).
- `app/views/cards/_detail.html.erb` — the unnumbered position line keeps its season.
- `app/views/cards/show.html.erb` — "◀ Grille" carries the season collection as an alternate history target.
- `app/frontend/lib/history_trail.ts` (+ test) — `entryAfter`, `backSteps`; comments on Turbo's restoration index corrected.
- `app/frontend/controllers/history_back_controller.ts` — back-forward-cache reset, return-link focus on restore visits, alternates.
- `app/frontend/controllers/sub_view_controller.ts` — heading focus on a phone; a failed step's keyboard focus wish is cleared.
- `app/frontend/styles/collection.css` — a not-yet-rendered grid slot takes the card's own size (no shift after a Turbo restore).
- Tests: `cards_controller_test.rb`, `library_controller_test.rb`, `system/card_detail_test.rb`; `deferred-work.md` entries updated and one added.

**Review.** First pass (quick lens): 6 findings, 4 patched (2 medium, 2 low), 2 rejected. Follow-up, loop 1: 5 findings — 4 bad_plan (2 medium, 2 low: whole-season links, focus, history-trail comments and bfcache, unnumbered position line), 1 rejected (editing this plan's own records). Loop 2: 3 findings — 2 bad_plan (medium: "◀ Grille" from the whole season led to the tome's grid; low: stale keyboard-step focus), 1 rejected (the hard-coded "S" for an unnumbered card: the same in both locales and already hard-coded by `CardView#number_label`; the fix would add a public method). Loop 2 re-review: 1 finding, patched (medium: an alternate was taken however far back). Nothing deferred from review; one test flake deferred (below).

**Follow-up review: not recommended (false).** This pass patched one medium entry and no high; the plan has converged. Patched this pass: high 0, medium 1, low 0. The real-device check of swipe, transitions and the history back stays in `deferred-work.md`.

**Verification.** `node script/pixel_art/export.mjs --check` 82 files up to date; `bin/rubocop` clean; `packwerk validate` + `check` clean; `i18n-tasks missing` and `unused` none; `npm run typecheck` clean; `npm run test:js` 139 passed; `bin/rails db:schema:load` (test); `bin/rails test` 1207 runs, 0 failures; `bin/rails test:system` 81 runs, 0 failures (run after the last patch).

**Residual risks.** Touch interactions (swipe beside the tilt hold, the step's View Transition, the history back) are verified only in headless Chromium. The phone system test's browser-Back leg is flaky under parallel load (pre-existing at `b7776c2`: 6 of 8 file runs failed; now about 1 in 6), deferred in `deferred-work.md`. From a card's own page reached without the grid, "◀ Grille" still visits the browsed tome's grid. The frame-layout override applies to every Turbo Frame response.

## Verification

**Commands** (with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w102` and `CHROME_BIN=/usr/bin/chromium`):
- `bin/rubocop` -- no offences
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` -- none
- `node script/pixel_art/export.mjs --check` -- up to date
- `npm run typecheck && npm run test:js` -- pass
- `bin/rails test && bin/rails test:system` -- pass

Follow-up run (2026-10-06): rubocop, packwerk, i18n-tasks, export `--check`, typecheck clean; `npm run test:js` 138 passed; `bin/rails test` 1207 runs green; `bin/rails test:system` 80 runs green (one earlier full run had `TomeTest` "300 cards … art only near the viewport" miss the last card's art in time, green alone 5× and in the next full run); `test/system/card_detail_test.rb` 4× green.

Follow-up run, loop 2 (2026-10-06): rubocop, packwerk check, i18n-tasks missing, typecheck clean; `npm run test:js` 138 passed; `bin/rails test` 1207 runs green; `bin/rails test:system` 81 runs green; `test/system/card_detail_test.rb` run 11× as a file: 9 green, 2 with the existing phone test's last check (`assert_scrolled_to` after `go_forward`/`go_back`, line 283) seeing scroll 0 under parallel load; that test alone 6× green. Code this loop touches does not run on a native Back.

Follow-up finalisation (2026-10-06, after the loop-2 patch): export `--check`, rubocop, packwerk validate + check, i18n-tasks missing + unused, typecheck clean; `npm run test:js` 139 passed; `bin/rails test` 1207 runs, 0 failures; `bin/rails test:system` 81 runs, 0 failures.
