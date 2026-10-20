---
title: 'The card detail column waits as an empty detail, and a tablet held upright opens the detail page'
type: 'bugfix'
ticket: '24'
created: '2026-10-19'
status: dropped
baseline_revision: '273ecdd51d160c6c3c60984649574fe556f7565a'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** On the author's review of entry 14, the empty detail column beside "Toutes les cartes" (`/library/cards`) showed only a kicker and one bare sentence, and the first card chosen replaced it with a whole different layout. From 720 to 899 px (a tablet held upright) the detail opened under the grid, which the author does not want.

**Approach:** Until a card is chosen, the `card-detail` frame holds the card detail's own layout, empty: the same panel, kicker, ◀ ▶ (disabled), an empty `card-l` face with its ground shadow, the title line and the facts rows (publisher, rarity, year, sets, then copies and editions for a signed-in viewer) with waiting values, and the Steam button disabled; choosing a card fills the same places. The detail opens beside the grid from 900 px only; from 720 to 899 px a slot opens the card detail page, as on the phone. The copy deck records the waiting values in French and English.

## Boundaries & Constraints

**Always:**
- The waiting detail is server-rendered inside `turbo_frame_tag "card-detail"` in `library/_collection`, in place of `.collection-detail__placeholder`. It reuses the detail's markup classes (`card-detail` panel with brackets, `card-detail__header`, `__layout`, `__columns`, `__stage`, `__card`, `__shadow`, `__info`, `__facts`, `__fact`, `__actions`) plus a `card-detail--waiting` modifier, so the frame's existing padding, container query (◀ ▶ under the card below 304 px) and column widths apply unchanged.
- Its parts, in the detail's order:
  - Header: the kicker "Fiche de la carte" / "Card file" (existing `card_details.kicker`); no number.
  - Stage: ◀ and ▶ as disabled buttons (`cards/detail_nav` with `path: nil`), between them an empty face of `card-l` size (208 × 312): the missing slot's hatched ground and `line-deep` outline, no icon, no text; the ground shadow under it.
  - Info: the title line as a `p.card-detail__title` (not a heading; no id) reading the waiting title; then the facts list with the rows Publisher, Rarity, Year, Sets, and, when a player is signed in, Copies and Editions (existing `card_details.facts.*` labels), each value the waiting mark.
  - Actions: the "Voir sur Steam" button as a disabled `button` with the same classes as the real one.
- Waiting copy (new keys, both locales): title "Choisissez une carte" / "Choose a card"; every fact value "—" (one key, same in both locales is acceptable but it must exist in both files). The old `library.grid.detail_placeholder` key and the `collection-detail__placeholder/__kicker/__hint` styles go.
- Accessibility: the waiting title is read; the empty face, the disabled ◀ ▶, the facts list and the disabled Steam button are `aria-hidden="true"` (they carry nothing yet). No `sub-view` or `share` controller on the waiting panel.
- Choosing a card: unchanged frame visit (`collection_detail_controller.ts`); the loaded detail replaces the waiting one in the same column; nothing in the waiting panel is taller or wider than the detail's own parts at the same place.
- Opening beside the grid only from 900 px: `opensBeside` takes whether the detail column is shown (`(min-width: 900px)`) instead of the phone flag; under 900 px a slot click is left to the link (the detail page). The `@media (min-width: 720px) and (max-width: 899px)` rule that showed the frame under the grid goes, so the frame is `display: none` under 900 px. Code that only served the stacked layout (scrolling the frame into view after an open) goes too.
- The phone sub-view, the detail page, `cards#show`, routes and queries do not change.
- No `style` attribute, no planning ids, no database ids, no explanatory comments beyond file headers (update the headers of `library/_collection.html.erb`, `collection.css`'s detail section, `collection_detail_controller.ts`, `lib/collection_detail.ts`).

**Never:**
- No client-side rendering of the waiting state, no new endpoint, no change to `cards/_detail.html.erb`'s output for a real card.
- No change to the album, the set rows, or the 13.20 grid sizes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Desktop, nothing chosen | 1280 px, signed in | 340 px column: kicker, ◀ empty face ▶, "Choose a card", Publisher/Rarity/Year/Sets/Copies/Editions "—", Steam disabled | — |
| Visitor | signed out | same without Copies and Editions | — |
| Choose a card | click a slot at 1280 | the detail fills the column; the face, title and facts rows stay where they were | — |
| Filter reload | a card shown, tick a rarity | the grid reloads with the waiting detail again | — |
| 1024 px | — | 300 px column, ◀ ▶ under the empty face | — |
| Upright tablet | 800 px, click a slot | the card detail page opens (URL is the card's, full page), no frame under the grid | — |
| Phone | 390 px | unchanged: the detail page | — |
| French | `/fr` | "Fiche de la carte", "Choisissez une carte", "Éditeur", "—" | — |

</intent-contract>

## Code Map

- `app/views/library/_collection.html.erb` -- replace the placeholder panel inside `turbo_frame_tag "card-detail"` with `render "cards/detail_waiting", signed_in: <whether a player is signed in>` (check how `cards/show` and the library controller know the viewer: `current_player`/`signed_in?` helpers). Rewrite the header comment's layout lines (no detail under the grid; from 720 to 899 px a slot opens the detail page).
- New `app/views/cards/_detail_waiting.html.erb` -- the waiting detail as in the Boundaries, built with `PanelComponent.new(tag: :article, brackets: true, class: "card-detail card-detail--waiting")` like `cards/_detail.html.erb` (read it for the exact wrappers and class names; it is read-only). Header comment in the repo's partial style (what it is, its locals).
- `app/frontend/styles/card-detail.css` -- `.card-detail--waiting` rules: the empty face `card-detail__empty-face` at `card-l` size (use the same width and height source as `.card--l` in `card.css`; 208 × 312), `background` and `box-shadow` as `.missing-slot` in `collection.css` l.690-702; waiting values and title in `--color-muted`. Keep the real detail's rules untouched.
- `app/frontend/styles/collection.css` -- delete `.collection-detail__placeholder`, `__kicker`, `__hint` and the `@media (min-width: 720px) and (max-width: 899px)` block; rewrite the detail section comment.
- `app/frontend/lib/collection_detail.ts` (+ `collection_detail.test.ts`) -- `opensBeside(click, besideShown)`: false when the detail column is not shown; export `DETAIL_BESIDE = "(min-width: 900px)"`. Tests for 800 px (not beside) and 1024 px (beside).
- `app/frontend/controllers/collection_detail_controller.ts` -- use `window.matchMedia(DETAIL_BESIDE).matches`; drop `reveal` and the `steppingInto("open")` scroll (keep focusing the heading on a click of the card already shown).
- `config/locales/en.yml`, `fr.yml` -- new keys under `card_details.waiting` (`title`, `value`); delete `library.grid.detail_placeholder`.
- Tests:
  - `test/controllers/library_controller_test.rb` -- the cards page: `turbo-frame#card-detail article.card-detail.card-detail--waiting` with the kicker, `p.card-detail__title` "Choose a card" (fr "Choisissez une carte"), the fact labels in order with "—", `button.card-detail__nav[disabled]` × 2, `.card-detail__empty-face[aria-hidden=true]`, a disabled store button; Copies/Editions only when signed in; no `h1#card-detail-heading` inside the frame; no `[style]`; query counts unchanged. Replace the placeholder assertions.
  - `app/frontend/lib/collection-grid.test.ts` -- the test "shows under the grid from 720px only once a card is opened" becomes: `.collection-detail` is `display: none` and no rule shows it under 900 px (the stacked media block is gone); keep the 900/1180 column tests.
  - `test/system/*` touching the placeholder or the 800 px stacked detail (grep `collection-detail`, `detail_placeholder`, `Choose a card`): selector updates only, never run.
- Docs (`_bmad-output/initiative-gameble/ux-gameble/`):
  - `DESIGN.md` per-screen table, Collection row, 720 to 899px: "One column: sets strip, grid; a card opens its detail page, as on the phone (author, 2026-10-19)". Card detail line (l.924): add the waiting detail beside the grid (empty `card-l` face hatched like a missing slot, waiting values in muted, ◀ ▶ and VOIR SUR STEAM disabled, filled in place when a card is chosen).
  - `EXPERIENCE.md` -- the Card detail row (l.233) or the collection row that mentions the detail beside the grid: the waiting detail and the 720–899 behaviour; Copy deck: a "Card detail waiting" row: "FICHE DE LA CARTE" · title "Choisissez une carte" ("Choose a card") · every value "—".
  - `.memlog.md` -- one `(decision)` line (author, 2026-10-19).

## Tasks & Acceptance

**Execution:**
- [x] `cards/_detail_waiting.html.erb`, `library/_collection.html.erb`, locales -- the waiting detail in the frame.
- [x] `card-detail.css`, `collection.css` -- waiting styles; placeholder and stacked rules removed.
- [x] `lib/collection_detail.ts` (+ test), `collection_detail_controller.ts` -- open beside from 900 px only.
- [x] `library_controller_test.rb`, `collection-grid.test.ts`, system selectors -- as in the Code Map.
- [x] DESIGN.md, EXPERIENCE.md, `.memlog.md`.

**Acceptance Criteria:**
- Given `/library/cards` at 1280 px with no card chosen, when it renders, then the column shows an empty card face and the detail's fields with waiting values; when a card is then chosen, the face, title and facts take the same places (checked in headless Chrome: the face's and the first fact row's top and left do not move).
- Given 800 px, when a slot is clicked, then the card detail page opens; given 390 px, unchanged.
- Given the change, when `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` run, then they pass.

## Implementation Notes

- **Decisions:**
  - `collection_detail_controller.ts` chose `advance` or `replace` by whether the frame held any `.card-detail`; the waiting panel carries that class, so it now looks for `.card-detail:not(.card-detail--waiting)` (`CARD_SHOWN`), keeping "Back returns to the grid in one step".
  - `aria-hidden="true"` sits on the whole stage (covering both disabled ◀ ▶ and the shadow) and again on the empty face, on the facts list and on the disabled store button; the kicker and the title `p` are the only things read. The disabled store button reuses `button button--primary card-detail__store` with the label span and the external icon, without the "(new tab)" hint, which only a link needs.
  - The waiting title copies the h1's look (`--font-screen-title`) in `--color-muted`; the empty face hardcodes 208 × 312 like `.card-detail__back` does, and a vitest pins it to `.card--l` and its fill/outline to `.missing-slot`.
  - `lib/sub_view_step.ts`: one header line now says "the waiting detail" instead of "the placeholder"; `steppingInto`, left without a caller, was removed afterwards (below).
  - No system test referenced the placeholder or the 800 px stacked detail; none changed.
- **Files touched:** `app/views/cards/_detail_waiting.html.erb` (new), `app/views/library/_collection.html.erb`, `app/frontend/styles/card-detail.css`, `app/frontend/styles/collection.css`, `app/frontend/lib/collection_detail.ts` (+ test), `app/frontend/lib/collection-grid.test.ts`, `app/frontend/lib/sub_view_step.ts` (header line, `steppingInto` removed), `app/frontend/controllers/collection_detail_controller.ts`, `config/locales/en.yml`, `config/locales/fr.yml`, `test/controllers/library_controller_test.rb` (the placeholder test rewritten around an `assert_waiting_detail` helper, plus a visitor test), `ux-gameble/DESIGN.md`, `ux-gameble/EXPERIENCE.md`, `ux-gameble/.memlog.md`.
- **Surprises:** `collection.css` keeps an unrelated `@media (max-width: 899px)` (the status label), so the vitest asserts the removed block by its full media query and that `.collection-detail` is shown only by the 900px rule.
- **Verified afterwards by the caller** (headless Chrome, below); the implementing run started no server.

- Headless Chrome (scratch system test, not committed; seed cards, which have no publisher): at 1280 and 1024 px the empty face, ◀ ▶ and the title keep exactly their box when a card is chosen (1280: face 954,244 208×340, title 905,608; 1024: face 693,236, ◀ ▶ under it at 588); the frame is `display: none` at 800 px and a slot click there loads `/en/cards/seed-…/seasons/2` as a page; the phone is unchanged.
- The first headless run showed the fact rows shifting: the waiting list (publisher, rarity, year, sets) did not match the rows a real card shows (publisher, rarity, genre, year, season, sets). Genre and Season rows were added to the waiting detail, so the rows match a card with a publisher and a genre; a card's description (most have one) still pushes the rows below the title down, and a card lacking a row (publisher, genre, editions for a game not held) moves the rows below it up. DESIGN.md and EXPERIENCE.md say so.
- `steppingInto` in `lib/sub_view_step.ts` lost its last caller with the stacked layout and was removed.

## Plan Change Log

### 2026-10-19 — Waiting rows widened during verification
- Trigger: headless measurement: the waiting rows (the ticket's list) did not match the real detail's rows, so choosing a card moved them.
- Amended: the waiting facts are publisher, rarity, genre, year, season, sets (+ copies, editions for a player), the rows of a typical card; the intent's list is read as the ticket's examples of "the detail's fields".
- KEEP: everything else of the waiting detail and the 900 px rule.

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 5 findings — high 0, medium 2, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` On the phone the waiting panel, hidden but in the DOM, matched `html:has(.card-detail__actions)` in `card-detail.css`, adding the detail sub-view's 80 px of scroll padding to `/library/cards`. — The rule now reads `html:has(.card-detail:not(.card-detail--waiting) .card-detail__actions)`, so only a real detail's pinned actions pad the scroll.
  - `[medium]` `[reject]` A chosen card with a description pushes every fact row down, so the AC's "first fact row does not move" is not met, and DESIGN.md overstated it. — The description's length is the card's own and cannot be reserved; the intent's rule (nothing in the waiting panel taller or wider than the detail's part at the same place) holds, and the face, ◀ ▶ and title do not move. DESIGN.md, EXPERIENCE.md and the notes now say the rows below the title follow the card. Reported to the author.
  - `[low]` `[reject]` For a card the player does not hold, the waiting Editions row has no counterpart, so the rows below shrink. — Same nature as the description: the rows follow the card; documented with it. Reserving per-card rows would need the card.
  - `[low]` `[patch]` The partial's header, a test comment, EXPERIENCE.md and the notes said only the title is read, while the kicker is read too. — Text corrected to "the kicker and the title".
  - `[low]` `[patch]` The plan's Implementation Notes contradicted themselves (`steppingInto` kept then removed; headless check "not run" then reported). — Notes corrected.

## Design Notes

- **Server-rendered waiting detail:** the frame already starts with server HTML and returns to it on every filter reload; rendering the empty layout there keeps it in the first paint, with no script.
- **Disabled controls instead of gaps:** ◀ ▶ and the Steam button keep their footprint so the card and the rows do not move when the real detail arrives; the description paragraph of a real card can still push the rows below the title down, which the waiting detail cannot predict.

## Verification

**Commands:**
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bin/ci` (with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1320`; revert a stray `package-lock.json`) -- expected: green.

**Manual checks (if no CLI):**
- Headless Chrome on `/en/library/cards` at 1280, 1024, 800 and 390 px: the waiting detail, a card chosen in place, 800 px opening the page.

## Auto Run Result

- **Summary:** before a card is chosen, the detail column beside "Toutes les cartes" holds the card detail's own layout, empty: the kicker, ◀ ▶ disabled around an empty `card-l` face hatched like a missing slot, the title "Choisissez une carte" / "Choose a card", the publisher, rarity, genre, year, season and sets rows (copies and editions for a player) reading "—", and "Voir sur Steam" disabled; a chosen card takes the same face, ◀ ▶ and title. The detail opens beside the grid from 900 px only; from 720 to 899 px, as on the phone, a slot opens the card's page.
- **Files:**
  - `app/views/cards/_detail_waiting.html.erb` (new), `app/views/library/_collection.html.erb`: the waiting detail in the frame.
  - `app/frontend/styles/card-detail.css`, `collection.css`: waiting styles; the placeholder and the stacked 720–899 rule removed; the phone scroll padding limited to a real detail.
  - `app/frontend/lib/collection_detail.ts` (+ test), `collection_detail_controller.ts`, `lib/sub_view_step.ts`: open beside from 900 px, the first open still pushes a history entry, stacked-only scrolling and `steppingInto` removed.
  - `config/locales/{en,fr}.yml`: `card_details.waiting.*`, `library.grid.detail_placeholder` removed.
  - `test/controllers/library_controller_test.rb`, `app/frontend/lib/collection-grid.test.ts`.
  - DESIGN.md (Collection row, Card detail), EXPERIENCE.md (Card detail row, Copy deck "Card detail waiting"), `.memlog.md`.
- **Review:** 3 patched (1 medium, 2 low), 0 deferred, 2 rejected (the rows below the title follow the chosen card's description and rows; reported to the author).
- **Follow-up review recommended:** false (patched: high 0, medium 1, low 2).
- **Verification:** `bin/ci` green (2783 runs, 0 failures), `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `i18n-tasks missing`; headless Chrome as in Implementation Notes.
- **Residual risks:** most real cards have a description, so their fact rows sit lower than the waiting rows; the author may want a waiting description line or accept it.

