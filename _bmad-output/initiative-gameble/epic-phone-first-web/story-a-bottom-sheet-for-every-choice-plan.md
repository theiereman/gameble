---
title: 'A bottom sheet for every choice'
type: 'feature'
ticket: '3'
created: '2026-11-03'
status: 'built'
baseline_revision: '92d15445a3c9770a0d6de28ea3d112c4efca9892'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'orchestrator'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Every phone choice (filters, friend pick, card pick, profile edits) is to share one bottom sheet, but the app only has `<dialog class="modal">` dialogs styled as a sheet on the phone: no swipe to close, no focus trap beyond the native modal, no opener by link, no single controller later screens can reuse.

**Approach:** A `BottomSheetComponent` (a `<dialog class="modal bottom-sheet">`) driven by one `bottom-sheet` Stimulus controller, opened by a server-rendered `<a href="#<sheet id>">` link, closed by a downward drag on its grip, its close button, the scrim or Escape, with focus trapped inside and returned to the opener; reduced motion crossfades. Its first user is a quick-filter menu on the card list: a QUICK FILTERS link beside the search opens a sheet of one-tap filters (every card, goals, state, rarity), each a link to the card list with that single filter.

## Boundaries & Constraints

**Always:** server-rendered ERB, markup never built in script; no `style` attribute in server HTML (script may set a custom property); strings in `en.yml` and `fr.yml`; reuse the `.modal` look (centred on desktop, bottom sheet under 720px, `modal-fade` under reduced motion); tap targets at least 44px on the phone; no new query on the card list request.

**Decision (conservative, put to the author in `pending-approvals.md`):** the quick-filter menu is added beside the existing FILTRES zone, which stays as it is; it is a menu of preset links, not a moved copy of the filter form.

**Never:** the capsule or pack-opening screen; replacing or restyling the FILTRES zone, the three pastilles or the infinite list (entry 4); moving existing dialogs onto the new component; the trade board's card picker; new routes or controller actions.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open by tap | phone 390x844, tap QUICK FILTERS | sheet rises from the bottom as a modal dialog named by its title, focus on its first choice | none |
| Open by keyboard | focus the link, Enter | same; Escape closes it and focus returns to the link | none |
| Focus trap | Tab past the last choice / Shift+Tab before the close button | focus wraps inside the sheet | none |
| Drag | touch drag down on the grip by 200px | sheet closes, focus back on the link | a 30px drag springs back and stays open |
| Scrim / ✕ | click outside the panel, or ✕ | sheet closes, focus back on the link | none |
| Choose | tap MISSING | card list reloads with `state[]=missing`, that choice marked current next time | none |
| Desktop | 1400x1400, open | the same sheet opens centred | none |
| Visitor | signed out | only every card and rarity choices | none |

</intent-contract>

## Code Map

- `app/frontend/controllers/dialog_controller.ts`, `lib/dialog.ts` (`openDialog`, `takeOpener`) -- existing modal pattern to mirror and reuse (opener memory, `turbo:before-cache` close, sent-open upgrade). Do not change them.
- `app/views/friends/_remove_dialog.html.erb` -- reference markup: `PanelComponent.new(brackets: true, class: "modal__panel")`, `.modal__handle`, `.modal__head`, `.modal__title`, `.modal__close` with `pixel_icon("close")`.
- `app/frontend/styles/shell-controls.css` 184-283 (`.modal`, keyframes) and `shell-screens.css` 114+ phone block (`.modal` as sheet, `.modal__handle` shown) and ~305/340 (reduced motion `modal-fade`) -- the look inherited; new sheet-only rules go in a new `app/frontend/styles/bottom-sheet.css`, imported in `app/frontend/entrypoints/application.css` right after `shell-header-phone.css`.
- `app/components/panel_component.rb`, `toast_component.*` -- ViewComponent style (absolute i18n keys, `helpers.pixel_icon`); tests in `test/components/`.
- `app/frontend/lib/motion.ts`, `lib/swipe.ts` -- motion and gesture helpers to follow; controllers auto-register from `app/frontend/controllers/*_controller.ts`.
- `app/views/library/cards.html.erb` -> `_collection.html.erb` -> `_filters.html.erb` -- the card list; `_collection` is also rendered by `public_profiles/collection.html.erb` (must not get the menu). `.filters__search` holds the search field.
- `app/controllers/concerns/collection_grid_loading.rb` -- `@grid_context` (`{state:, rarity:, sets:, genre:, goals:, q:, seen:, brother:}`, blanks removed except `q`), `@grid_goals` (`GoalMarks`, `needs`, `GoalMarks.filter_value`), `state_choices` computed in `_collection`; `Catalog::Rarity::TIERS`, `Game::CollectionStates::STATES`.
- `app/helpers/collection_helper.rb` (15 lines), `goal_bookmark`, `goal_set_name` helpers used by `_filters`; `.filter-chip[aria-current="true"]` already styles a current link chip (`collection-filters.css`).
- Locale keys `library.filters.groups.*`, `library.filters.states.*`, `catalog.rarity.*` exist in both locales.
- Tests: `test/system/library_test.rb` (sign-in setup with `SteamSignIn`, `CatalogSeeds`, `publish_sets_draft`), `test/system/card_detail_test.rb:79` synthetic touch `PointerEvent`s, `test/controllers/library_controller_test.rb` (query budget, `LibraryRequests`). Do not add to `test/system/shell_test.rb` or `test/integration/shell_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `app/frontend/lib/bottom_sheet.ts` + `bottom_sheet.test.ts` -- pure helpers: drag offset (never negative), dismiss decision (offset at least min(96px, a third of the sheet height)), focus wrap target for Tab / Shift+Tab -- testable logic out of the controller.
- [x] `app/frontend/controllers/bottom_sheet_controller.ts` -- on the dialog: `openFrom` (document click on `a[data-bottom-sheet-opens="<id>"]`, preventDefault, `openDialog`), focus the first focusable of the body, else ✕; `close`, `closeOnScrim`, `keydown` (Tab wrap), `close` event returns focus via `takeOpener`; grip pointer drag for non-mouse pointers sets `--sheet-drag` and `data-dragging` on the dialog, release closes or springs back; listen for move/up on the dialog, no unguarded `setPointerCapture` (synthetic test pointers); close on `turbo:before-cache` and disconnect.
- [x] `app/components/bottom_sheet_component.rb` + `.html.erb` -- `BottomSheetComponent.new(id:, title:)` with content: dialog `aria-labelledby` its title, grip (handle plus head) as drag target, ✕ named by `bottom_sheet.close`, body; `app/helpers/bottom_sheet_helper.rb` `bottom_sheet_opener(id)` returning link attributes (`href: "#id"`, `aria-haspopup: dialog`, `aria-controls`, `data-bottom-sheet-opens`).
- [x] `app/frontend/styles/bottom-sheet.css` + import -- body scrolls within at most 85dvh on the phone; `translate: 0 var(--sheet-drag, 0)` with a short snap-back transition, none while dragging or under reduced motion (both `prefers-reduced-motion` and `html[data-motion]` forms); grip `touch-action: none`.
- [x] `app/views/library/_quick_filters.html.erb`, `_collection.html.erb`, `_filters.html.erb`, `cards.html.erb` -- `quick_filters: true` only from the card list; opener chip beside the search; sheet groups every card / goals / state (without `all`) / rarity, each a `filter-chip` link with `data-turbo-frame="_top"`, `aria-current="true"` when the active filters are exactly that one (helper in `collection_helper.rb` from `@grid_context` minus `seen`/`brother`, blank `q` ignored); CSS for the opener in `collection-filters.css`.
- [x] `config/locales/en.yml`, `fr.yml` -- `bottom_sheet.close`, `library.quick_filters.{open,title,every_card}` (fr: Fermer, Filtres rapides, Toutes les cartes).
- [x] Tests -- `test/components/bottom_sheet_component_test.rb`; `test/controllers/library_quick_filters_test.rb` (player sees all groups and the current mark, visitor rarity only, public profile collection has no menu, query count unchanged); `test/system/bottom_sheet_test.rb` covering every matrix row at 390x844 and the desktop centring, with the accessibility tree read through CDP (`Accessibility.getFullAXTree`) showing role dialog named "Quick filters".
- [x] `_bmad-output/initiative-gameble/pending-approvals.md` -- the conservative reading of "quick-filter menu" under Open.

**Acceptance Criteria:**
- Given a phone, when the sheet is open, then the page behind is inert and the sheet sits at the bottom edge full width; given a desktop, then it is centred both ways.
- Given reduced motion, when the sheet opens or springs back, then it only crossfades and does not slide.

## Implementation Notes

- The sheet is rendered by `_collection` right after the filter form, not inside it, so its links stay out of the form; the opener chip sits in `.filters__search` (`filters__search--menu`).
- `quick_filter_link` and `quick_filter_current?` live in `collection_helper.rb`; the goal choices carry `goal_name` as their accessible name, as the FILTRES goal chips do.
- The phone touch gap of the choices joins the existing selector in `collection-grid.css` (now 500 lines, at the limit): a new phone media query in `collection-filters.css` broke `collection-grid.test.ts`, which reads the first phone query of the collection sheets.
- Reduced motion: the sheet opens with `modal-fade` (inherited) and has no spring-back transition; a finger still moves it while dragging.
- The accessibility tree names the dialog "QUICK FILTERS" (the title's `text-transform`); the system test compares it case-insensitively.
- `test/controllers/library_controller_test.rb`'s id list gains the sheet's four ids. The card list with one goal costs 22 queries with and without the sheet (measured by turning the menu off).

## Plan Change Log

## Review Triage Log

- 2026-11-03, orchestrator read of the whole diff after the build agents stopped before their review: no blocking finding. `db/schema.rb` drift from a local database (an unmigrated `collected_at` and a reworded feed check) reverted, not part of this story.

## Verification

**Commands:**
- `npm run test:js && npm run format:check && npm run lint:css` -- expected: pass
- `bin/rails test test/components test/controllers/library_quick_filters_test.rb test/controllers/library_controller_test.rb test/helpers` -- expected: pass
- `bin/rails test test/system/bottom_sheet_test.rb test/system/library_test.rb` -- expected: pass
- `bin/ci && bin/rails zeitwerk:check && bundle exec packwerk check && bundle exec i18n-tasks missing` -- expected: pass
- `script/check_file_sizes && script/check_planning_references` -- expected: pass

## Code Review

### 2026-11-04 — 0 decision-needed, 1 patch, 3 defer, 4 rejected

- [x] [Review][Patch] Delete the explanatory block comments [app/frontend/styles/bottom-sheet.css]
- [x] [Review][Defer] No flick dismissal: a short fast swipe down leaves the sheet open (distance only) — deferred: a behaviour choice for the author, settle on the iPhone pass
- [x] [Review][Defer] A pen pointer released outside the dialog mid-drag, or a press that ends on the scrim, may leave a drag or close the sheet — deferred: unverified, settle on a real device
- [x] [Review][Defer] Closing on Turbo cache, the Turbo restore of an open sheet and reduced-motion spring-back have no browser test — deferred: system tests are run once before release

**Rejected**
- Quick-filter findings (current mark, goals list, state chip, search dropped): the quick-filter sheet was retired by the card list story.
- No-JavaScript opener: already deferred with the filter row.
- Mouse drag ignored: intended, desktop closes by button, scrim or Escape.
- Build-process notes (status, lenses_ran, unrun suites), wording of the plan, fr.yml key order, FOCUSABLE selector: low or edits the plan.
