---
title: "The Steam library sync line sits in the collection's design"
type: 'bugfix'
ticket: '3'
created: '2026-11-03'
status: blocked
baseline_revision: ''
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/mockups/steam-library-sync-line.html'
warnings: []
deferred: []
blocked_at: "2026-11-03"
blocked_reason: "waiting for the author to pick a look in ux-gameble/mockups/steam-library-sync-line.html"
---

<intent-contract>

## Intent

**Problem:** On the collection entry, MA BIBLIOTHÈQUE STEAM shows its sync date (or that Steam does not share the library) in a full-width sunken box with a muted light, between the kicker and a tile that fills only one of the grid's two columns. No other section has a box there, so it reads as a stray banner (author, staging v1.1.0-rc.6).

**Approach (proposal A, recommended, pending the author's pick in `ux-gameble/mockups/steam-library-sync-line.html`):** put the date in the section head, right of the kicker, as MES SETS's note and OBJECTIFS's count already do: muted label, the date itself bright. When Steam does not share the library, the head carries the last sync date and the not-shared sentence sits under the head as plain muted text, like the set search's status line. No box, no light, the tile untouched.

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
- [ ] `app/helpers/custom_sets_helper.rb` -- replace `steam_library_sync_lines` with a head note (synced date, or last sync when private and synced, else nil) and a not-shared predicate or line -- the view renders two places instead of one box.
- [ ] `app/views/library/_steam_library.html.erb` -- head wrapper holding the h2 and the note; the not-shared line under it; drop the light -- matches the sibling sections.
- [ ] `app/frontend/styles/collection-custom-sets.css` -- remove `.steam-library__sync/__light/__lines`; add the head, note (`b` bright) and muted line rules, sharing the custom sets' head rules where a shared selector reads better -- one look for the player's sections.
- [ ] `config/locales/fr.yml`, `config/locales/en.yml` -- `synced_html`, `last_sync_html` with `<b>%{date}</b>`, no final period -- the head notes of the other sections end without one.
- [ ] `test/controllers/library_controller_test.rb`, `test/system/steam_library_test.rb` -- assert the head note, the not-shared line, no line for a synced library, no note for a never-synced private one, both languages -- the matrix above.
- [ ] `DESIGN.md`, `EXPERIENCE.md` -- describe the head note and the plain not-shared line; reference the mockup -- the spines rule over the code.

**Acceptance Criteria:**
- Given a synced library, when the player opens the collection on desktop, then the date sits right of MA BIBLIOTHÈQUE STEAM on the kicker's line and nothing stands between the head and the tile.
- Given a library Steam does not share, when the player opens the collection on the phone, then the kicker, the last sync note and the not-shared sentence stack as plain text above the tile, with no box and no light.
- Given a typed set search, when results show, then the Steam library section stays hidden as before.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

The author picks the look first (ticket note: the approval is the hitl step). The mockup `ux-gameble/mockups/steam-library-sync-line.html` shows today's box and three proposals, each synced and not shared, desktop 1280 px and phone 390 px, in French with the project's tokens:

- **A, recommended: date in the section head.** Reuses the head-note pattern MES SETS and OBJECTIFS already show right above, so the player's three sections read alike. Smallest change, no effect on the tile, its accessible name or search results; a plain-text note is read naturally by a screen reader.
- **B: date as the tile's second secondary line** (the ticket's example). Under the kind line, recto and verso; the not-shared sentence under the grid. Costs: the fixed 280 px tile loses card room, the faces are `aria-hidden` so the date must join the tile's accessible sentence, the shared tile partial and the search results change too, and the desktop grid keeps its empty right cell.
- **C: a sync block in the empty grid cell beside the tile** (under it on the phone). Fills the desktop hole and has room to explain the private case, but a 280 px block for two lines of information outweighs it, it looks like a tile without being one, and on the phone it becomes a box again.

If the author picks B or C, rewrite Code Map and Tasks for it before building: B touches `_set_progress_tile.html.erb`, `set_tile_label` and a new kind-line key; C adds a block to the section's tile list and two new copy keys.

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
