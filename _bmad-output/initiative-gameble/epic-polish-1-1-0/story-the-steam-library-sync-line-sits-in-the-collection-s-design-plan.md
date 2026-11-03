---
title: "The Steam library sync line sits in the collection's design"
type: 'bugfix'
ticket: '3'
created: '2026-11-03'
status: built
baseline_revision: 'adb132ada9d1b686706889077885565bf29f59be'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/mockups/steam-library-sync-line.html'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** On the collection entry, MA BIBLIOTHÈQUE STEAM shows its sync date (or that Steam does not share the library) in a full-width sunken box with a muted light, between the kicker and a tile that fills only one of the grid's two columns. No other section has a box there, so it reads as a stray banner (author, staging v1.1.0-rc.6).

**Approach (proposal A of `ux-gameble/mockups/steam-library-sync-line.html`, chosen by the author on 2026-11-03):** put the date in the section head, right of the kicker, as MES SETS's note and OBJECTIFS's count already do: muted label, the date itself bright. When Steam does not share the library, the head carries the last sync date and the not-shared sentence sits under the head as plain muted text, like the set search's status line. No box, no light, the tile untouched.

## Boundaries & Constraints

**Always:** both locales; the phone head wraps the note under the kicker (as MES SETS's head does); the not-shared case stays information, never orange; the section stays hidden by a typed search; no `style` attribute.

**Never:** change the set progress tile, its accessible name or the search results; add a link or a new behaviour (epic: defects only); touch the settings page's sync row.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Synced | `synced_at` set, not private | Head note "Synchronisée avec Steam le **3 novembre 2026**" / "Synced with Steam on **November 3, 2026**"; nothing between head and tile | No error expected |
| Not shared | private, `synced_at` set | Head note "Dernière synchronisation : **12 octobre 2026**" / "Last sync: **October 12, 2026**"; under the head the unchanged not-shared sentence | No error expected |
| Private at first sync | private, `synced_at` nil | No head note; the not-shared sentence alone under the head | No error expected |
| First of the month | date is a 1st | "1er octobre 2026" (existing `long_day_first`) | No error expected |

</intent-contract>

## Code Map

- `app/views/library/_steam_library.html.erb` -- the section; today `p.steam-library__sync` with `.steam-library__light` and `.steam-library__lines`.
- `app/helpers/custom_sets_helper.rb` -- `steam_library_sync_lines` returns `[note, last_sync]`; `steam_library_date` formats the day. Split into a head note (or nil) and the not-shared line.
- `app/frontend/styles/collection-custom-sets.css:128-152` -- the box, light and bold rules to remove. Head pattern to mirror: `.custom-sets__head` / `.custom-sets__note` (same file, flex wrap baseline space-between, `--font-label` muted) and `.goals__count b` (`collection-goals.css`, `--color-text-bright`). Muted line pattern: `.set-search__status` (`collection.css`, `--font-body-small` muted).
- `config/locales/{fr,en}.yml` `library.entry.steam_library.synced` / `last_sync` -- become `_html` keys with the date in `<b>` and no final period; `not_shared` unchanged.
- `test/controllers/library_controller_test.rb:1790-1850` -- three tests select `p.steam-library__sync`; repoint to the head note and the not-shared line.
- `test/system/steam_library_test.rb:66,100-101` -- asserts the synced text with a period and `b` "Last sync: …."; adjust.
- `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md:1017` (and reference line 1010) and `EXPERIENCE.md:116` -- the spines still describe the box and the period; update them to the chosen look and cite the new mockup.

## Tasks & Acceptance

**Execution:**
- [x] `app/helpers/custom_sets_helper.rb` -- replace `steam_library_sync_lines` with a head note (synced date, or last sync when private and synced, else nil) and a not-shared predicate or line -- the view renders two places instead of one box.
- [x] `app/views/library/_steam_library.html.erb` -- head wrapper holding the h2 and the note; the not-shared line under it; drop the light -- matches the sibling sections.
- [x] `app/frontend/styles/collection-custom-sets.css` -- remove `.steam-library__sync/__light/__lines`; add the head, note (`b` bright) and muted line rules, sharing the custom sets' head rules where a shared selector reads better -- one look for the player's sections.
- [x] `config/locales/fr.yml`, `config/locales/en.yml` -- `synced_html`, `last_sync_html` with `<b>%{date}</b>`, no final period -- the head notes of the other sections end without one.
- [x] `test/controllers/library_controller_test.rb`, `test/system/steam_library_test.rb` -- assert the head note, the not-shared line, no line for a synced library, no note for a never-synced private one, both languages -- the matrix above.
- [x] `DESIGN.md`, `EXPERIENCE.md` -- describe the head note and the plain not-shared line; reference the mockup -- the spines rule over the code.

**Acceptance Criteria:**
- Given a synced library, when the player opens the collection on desktop, then the date sits right of MA BIBLIOTHÈQUE STEAM on the kicker's line and nothing stands between the head and the tile.
- Given a library Steam does not share, when the player opens the collection on the phone, then the kicker, the last sync note and the not-shared sentence stack as plain text above the tile, with no box and no light.
- Given a typed set search, when results show, then the Steam library section stays hidden as before.

## Implementation Notes

- `steam_library_sync_lines` became `steam_library_head_note`: nil before any sync, the last sync note when private, else the synced note; the view shows `p.steam-library__not-shared` exactly when the library is private.
- `.steam-library__head` shares the `.custom-sets__head` rule, so the phone wrap comes for free; the old box comment went with the box.
- The French assertion on the note uses `.strip`, not `.squish`, which would turn the narrow no-break space before the colon into a plain space.
- The date stays bright inside the muted note, as in the approved mockup and OBJECTIFS's count.

## Plan Change Log

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 0 findings — high 0, medium 0, low 0, false 0, maybe-false 0
- findings: none; the quick lens checked the three acceptance criteria, the matrix rows, both locales and the AGENTS.md rules against the diff.

## Design Notes

**Author decision (2026-11-03): proposal A.** In the author's words (translated from French): the sentence « Synchronisée avec Steam le 3 novembre 2026. » just needs to sit better in the UI, for example next to the title, faded. B and C are rejected.

The mockup `ux-gameble/mockups/steam-library-sync-line.html` shows today's box and three proposals, each synced and not shared, desktop 1280 px and phone 390 px, in French with the project's tokens:

- **A, recommended: date in the section head.** Reuses the head-note pattern MES SETS and OBJECTIFS already show right above, so the player's three sections read alike. Smallest change, no effect on the tile, its accessible name or search results; a plain-text note is read naturally by a screen reader.
- **B: date as the tile's second secondary line** (the ticket's example). Under the kind line, recto and verso; the not-shared sentence under the grid. Costs: the fixed 280 px tile loses card room, the faces are `aria-hidden` so the date must join the tile's accessible sentence, the shared tile partial and the search results change too, and the desktop grid keeps its empty right cell.
- **C: a sync block in the empty grid cell beside the tile** (under it on the phone). Fills the desktop hole and has room to explain the private case, but a 280 px block for two lines of information outweighs it, it looks like a tile without being one, and on the phone it becomes a box again.


## Verification

**Commands:**
- `bin/rails test test/controllers/library_controller_test.rb` -- expected: green.
- `bin/rails test test/system/steam_library_test.rb` -- expected: green.
- `npm run lint:css && npm run format:check && script/check_file_sizes && script/check_planning_references` -- expected: clean.
- `bundle exec i18n-tasks health` -- expected: no missing or unused key.

**Manual checks (if no CLI):**
- Collection at 1280 px and 390 px, fr and en, synced and private: matches the chosen proposal in the mockup.

## Auto Run Result

Status: blocked
Blocking condition: waiting for the author to pick a look in ux-gameble/mockups/steam-library-sync-line.html
Planning only: the mockup shows today's box and proposals A (recommended), B and C, synced and not shared, desktop and phone. No application code changed. Once the author picks one, record the choice here, rewrite Code Map and Tasks if it is not A, and set the plan to ready-for-dev.

Unblocked 2026-11-03: the author picked proposal A; the build follows.

### Build result (2026-11-03)

Status: built
Summary: the Steam library section shows its sync date in its head, right of the kicker, muted with the date bright; when Steam does not share the library the head gives the last sync date and the not-shared sentence sits under the head as plain muted text. The sunken box and its light are gone; the tile is untouched.
Files:
- `app/helpers/custom_sets_helper.rb` -- `steam_library_head_note` replaces `steam_library_sync_lines`.
- `app/views/library/_steam_library.html.erb` -- head with the note, the not-shared line under it, no box or light.
- `app/frontend/styles/collection-custom-sets.css` -- head shares the custom sets' head rule; note and not-shared styles; box and light removed.
- `config/locales/en.yml`, `config/locales/fr.yml` -- `synced_html`, `last_sync_html` with the date in bold, no final period.
- `test/controllers/library_controller_test.rb`, `test/system/steam_library_test.rb` -- assert the head note, the not-shared line and their places, both languages.
- `ux-gameble/DESIGN.md`, `ux-gameble/EXPERIENCE.md` -- the head note and the plain line, the mockup cited as chosen.
Review: quick lens, 0 findings; no patch, nothing deferred, nothing rejected.
Follow-up review recommended: false (no patched entry).
Verification: library controller tests 77 runs 0 failures; steam library system tests 3 runs 0 failures; `npm run lint:css`, `npm run format:check`, `script/check_file_sizes`, `script/check_planning_references`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `i18n-tasks missing`, rubocop on the touched Ruby files all clean. `i18n-tasks health` reports 42 unused keys, one inconsistent interpolation and normalization, all present before this change and none on these keys.
Residual risks: none known; erb_lint is not in the bundle, so the view went through the tests only.
