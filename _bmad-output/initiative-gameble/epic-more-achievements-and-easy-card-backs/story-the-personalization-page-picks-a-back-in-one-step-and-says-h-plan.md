---
title: 'The Personalization page picks a back in one step and says how each back was earned'
type: 'feature'
ticket: '12'
created: '2026-11-01'
status: 'built'
baseline_revision: 'ded021fb11ba64766b8b94ed5924bd3ab41808de'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/AGENTS.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Personalization page works but reads badly: the back picker shows a large preview over a grid, equipping reloads the page with a toast, and no back says how it was earned (an achievement back only says "Unlock the matching achievement.").

**Approach:** Rework the page to `ux-gameble/mockups/personalization.html` (variant A) under `EXPERIENCE.md` and `DESIGN.md` (which win over the mock): VITRINE and TITRE DE PROFIL grouped, then DOS DE CARTE; each section a bracketed panel with a why line, a count and a scope tag; the back picker a mosaic grouped by origin in catalogue order under one strip naming the hovered, focused or tapped back. `Game::CardBackShelf` gives each back the facts behind how it was earned or can be earned; the helper turns them into the copy deck's sentences; a Stimulus controller equips in one click through the existing `Game::ChooseCardBack` (JSON), moves the lime frame in place and announces it in a hidden status region, never a toast.

## Boundaries & Constraints

**Always:** write only through `Game::ChooseCardBack`; a locked or unknown back is refused even by a forged request, nothing written; every string in en.yml and fr.yml (French copy exactly as the copy deck, `[ASSUMPTION]` strings used as written); French plural keys with a `zero` form; achievement names and conditions read from `achievements.names.<key>` / `achievements.conditions.<key>`, never copied; no database ids in markup; no `style` attribute in server HTML; no markup built in script (clone server-rendered `<template>`s, set `textContent`); the strip and the "ACTIF" plate `aria-hidden`; equip on `click`/`submit`, never `pointerdown`; focus stays on the back; focus ring on `:focus-visible` only; the page works without JS (forms submit and redirect).

**Never:** a toast on equip; a migration; a change to `Game::ChooseCardBack`'s rules or to `card_backs.names.*` (another lane adds names there) or `achievements.*`; the set progress on thumbnails; the title picker's preview/rank-column layout (it stays the radio list, only its section header changes); the season allocation screen's output (it keeps `card_back_condition` and `card_backs.conditions.*`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Equip earned | click an unlocked back | PATCH json 200; lime frame + ACTIF move to it, old one plain, labels swap, strip "ACTIF", status "Dos équipé. « X » apparaîtra…"; persists on reload | none |
| Equip with season | click "S1" under a multi-season back | stored with season 1, stamp S1, `aria-pressed` on S1, announcement with season | none |
| Locked click | click a locked back | strip shows its condition, no request | none |
| Forged | earned form's `back` input rewritten to a locked key, submitted | 422 json, nothing stored, frame stays on previous back | strip in alert colour + status "Le dos n'a pas pu être équipé. Réessayez." |
| Network failure | fetch rejects | same as forged | same |
| No JS | form submit | redirect to the page, the equipped back's button autofocused, no toast | HTML refusal keeps today's alert redirect |
| New account | no state, no unlock | Standard active, every other back locked with its line | none |
| Set absent | locked set back whose set is not in the published season | "Set absent de la saison en cours", no progress | none |
| Past event | locked event back | "Événement terminé" | none |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/card_back_shelf.rb` -- `Row` gains `unlocked_at`, `tier` (earned set back: the back tier of its latest earned season), `week` (goal back: earliest `GoalReward.week_start`), `progress` (locked set back: `Progress(held:, total:, required:)` in `Catalog::PublishedSeason.call`, nil when the set is absent) and `group` (`:base` for always/event, `:achievement`, `:goal`, `:theme`, `:hall_of_fame` from `unlock.target[0]`); `GROUPS` constant in that order. Keep `call(player)` returning catalogue-ordered rows.
- `app/domains/game/app/queries/game/earned_set_backs.rb` -- also select `back_tier.tier`; `rows` returns `[kind, key, number, tier]`; update `card_back_seasons.rb` destructuring. Callers: `grant_card_backs_job.rb` (via `call`), `card_back_seasons.rb`.
- Set progress: `Catalog::SeasonSets.every_kind(season:)` (kind, key, id), `Game::SetsInProgress.call(player, season:)` (held for started sets), `Catalog::SetFigures.call(ids)` (total, tiers). Back-tier required = smallest tier `required` with `required * 2 >= total` (same rule as `EarnedSetBacks::SQL`).
- `app/domains/game/app/models/game/card_backs.rb` -- catalogue order; read only.
- `app/helpers/card_backs_helper.rb` -- keep `card_back_name`, `card_back_condition` (allocation), `card_back_image` (class `back-picker__image` is used by `season-allocation.css`). Add: sentence (earned/to-earn), visual tail (date "le 24 octobre 2026" via `:long_day`/`:long_day_first` as `card_details_helper.rb#card_detail_pioneer_date`; Standard "à l'inscription"; set progress), spoken tail, accessible name per state, seasons list (`to_sentence`), tier label `library.set_progress.tiers.<tier>`.
- `app/controllers/card_backs_controller.rb` -- success: html redirect with `flash[:chosen_back]` only (drop toast flashes); json `{ back:, season:, announcement: }`. Failure path unchanged (`PersonalizationRefusal`, 422 json).
- `app/views/personalizations/show.html.erb` -- order: showcase, title, back; first two in a `personalization__public` wrapper.
- `app/views/personalizations/_section.html.erb` -- header: h2 kicker, why line, count (visible "3 / 5" `aria-hidden` + visually hidden "3 sur 5"), scope tag (pixel `eye` + "Visible par tous"/"Vous seul"), rule.
- `app/views/public_profiles/_showcase.html.erb` -- in `framed` mode only: why line, count n / 5, scope tag in its head, hint line under the cards; keep the info disclosure, ids and every existing behaviour (tests in `showcases_controller_test.rb`, `public_profiles_controller_test.rb`).
- `app/views/personalizations/_title_picker.html.erb` -- intro becomes the header's why line; count "n titres gagnés"; scope public.
- `app/views/personalizations/_back_picker.html.erb` (+ new `_back_tile.html.erb`, `_back_strip.html.erb` if useful) -- rewrite.
- `app/frontend/controllers/showcase_order_controller.ts`, `app/frontend/lib/showcase_order.ts` -- fetch/CSRF/status-announce pattern to copy.
- `app/frontend/styles/personalization.css` (219 lines; 500 max) -- page and section header; put the picker in a new `back-picker.css` imported where the other screen styles are.
- `script/pixel_art/export.mjs` `ICONS` -- add an `eye` icon grid (like `lock`), then `node script/pixel_art/export.mjs`.
- Tests: `test/system/personalization_test.rb` (two back tests to replace), `test/controllers/card_backs_controller_test.rb`, `test/domains/game/card_back_shelf_test.rb`, `test/domains/game/card_back_seasons_test.rb`, `test/controllers/season_allocations_controller_test.rb` (must stay green), `test/support/game_sets.rb` (`insert_set`, `published_cards`).

## Tasks & Acceptance

**Execution:**
- [ ] `earned_set_backs.rb`, `card_back_seasons.rb`, `card_back_shelf.rb` -- the shelf facts above -- one read model for the page.
- [ ] `card_backs_controller.rb` -- json success with announcement; no toast flash.
- [ ] `card_backs_helper.rb` -- sentences, tails, names.
- [ ] views listed above -- the page and the picker markup: strip (at rest the active back), chip `<template>`s (active/unlocked/locked), failure `<template>`, per-tile detail `<template>`, earned tiles as `button_to` forms carrying `data-active-label`/`data-unlocked-label`, locked tiles `<button type="button">`, ACTIF plate in every earned tile shown by the active class, one stamp per earned season (`hidden` but the shown one: active season, else latest), season buttons group, empty `role="status"` region, autofocus of `flash[:chosen_back]`'s button.
- [ ] `app/frontend/lib/back_picker.ts` (+ `.test.ts`) -- pure strip-target state (hover, focus, latest of the two, back to focused then active) and `sendChoice` (fetch PATCH json, CSRF) -- unit-tested.
- [ ] `app/frontend/controllers/back_picker_controller.ts` -- wires pointerenter/leave, focusin/out, click (tap fills the strip), submit interception, frame/label/stamp/`aria-pressed` swap, announce (clear then set), failure state; ResizeObserver sets `--back-picker-strip-height` on its own element for tiles' `scroll-margin-top`.
- [ ] `personalization.css`, `back-picker.css` -- DESIGN.md Back picker and Personnalisation page specs (80×120 `m` art, 56×84 phone, 12px gaps, first three groups share a wrapping row 32px apart, lime 3px frame then focus ring outside, hover lift 3px 160ms `--ease-out` only with `(hover: hover)` and no lift under reduced motion, sticky strip only `(min-height: 560px)`, phone targets ≥ 78×98 and season buttons ≥ 44×44).
- [ ] `config/locales/en.yml`, `fr.yml` -- keys under `personalizations.show.*` and `personalizations.show.card_back.*` (remove keys left unused, e.g. `card_backs.chosen`, `card_back.active/current/choose/locked`, `mark_label` if replaced); `date.formats` day-month for the goal week if needed.
- [ ] tests -- shelf facts (set tier + seasons, goal week, unlocked_at, locked progress, absent set, groups), controller json success/refusal and html redirect without toast, helper or view assertions for every sentence, system tests below.

**Acceptance Criteria:**
- Given a player with an unlocked set back, the goal back and Centurion, when they open Personalization in English and in French, then each back's strip line and accessible name read its earned sentence and date, and a locked achievement back reads "Débloquez le succès <I18n name> · <I18n condition>".
- Given an unlocked back, when the player clicks it once, then the frame and ACTIF move to it without reload or toast, the status region announces it, the focus stays on it, and a reload keeps it active.
- Given a forged request for a locked back, then nothing is stored and the strip shows the failure.
- Given the existing personalization, showcase and season allocation tests, then they pass (updated only where they asserted the removed preview or toast).

## Implementation Notes

- Locked set progress lives in a new query, `Game::SetBackProgress` (published season, `SetsInProgress` held, `SetFigures` total and tiers; required = smallest tier with `required * 2 >= complete`, complete falling back to the total), so `CardBackShelf` stays a thin assembler. `CardBackSeasons.of(rows)` lets the shelf read `EarnedSetBacks.rows` once for both seasons and tier; when two tiers tie as back tier, the latest season's highest one is named.
- A locked set back whose set is absent reads "Set absent de la saison en cours" as its sentence (no tail), like "Événement terminé".
- `SeasonMarkComponent` now passes extra html options (`hidden`, `data`) to its span, for the per-season stamps.
- `PersonalizationsHelper#personalization_fraction` renders every "n / total" count (visible `aria-hidden`, spoken "n sur total"); the section header is a shared partial `personalizations/_section_head`, used by `_section` and by the framed showcase.
- English hint interpolates `showcases.add`, so it stays the button's label; French reads exactly as the copy deck.
- `config/i18n-tasks.yml` ignores `personalizations.show.card_back.groups.*` and `.earned.events.*`, read by group or back key.
- The top bar does not stick, so the strip sticks at `top: 0`; tiles and season buttons get `scroll-margin-top` from `--back-picker-strip-height` while it sticks.
- Not built (not in the code map): the mock's dashed "Place libre" showcase slots.
- Verified: domain/controllers/helpers/models (2099 runs) and the full `bin/rails test` (3828) green; personalization + season allocation system tests green; vitest 768; rubocop, i18n-tasks unused/missing, packwerk, zeitwerk, file sizes, planning refs, markup APIs, prettier, stylelint, typecheck, pixel `--check` clean. Screenshots checked at 1280 and 390 px.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 4 findings — high 0, medium 2, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` (quick) `back_picker_controller.ts` read the active back and season from the root's values only in `connect()` and never wrote them back, so after a Turbo cache restore the strip named the old back, the old back could not be re-equipped and a third equip left two framed tiles — confirmed Turbo Drive is on and the page does not opt out of the cache; fixed: `equip()` now sets `activeValue` and sets or removes the season value.
  - `[low]` `[patch]` (quick) `personalizations.show.card_back.unlocked` was a fixed plural, so a new account read "1 / 55 débloqués" — fixed: plural key (zero/one/other in fr, one/other in en) with the unlocked count.
  - `[low]` `[patch]` (quick) `progress.spoken` / `spoken_missing` read "0 cartes" / "1 cartes" in a locked set back's accessible name — fixed: plural on `held`, helper test lines for 0 and 1 held.
  - `[medium]` `[patch]` (orchestrator check against the ticket's verify) the system tests were English only, never read a set back's or the goal back's earned line, and hardcoded achievement copy another lane is renaming — fixed: a new system test in English and French reads the earned lines of Roguelike, Confrère and Centurion and the locked line of Étoile d'or with achievement names and conditions from I18n; helper and controller tests build achievement copy from I18n too.

## Design Notes

Copy (fr from the copy deck; en and unmarked fr written here):
- Sections: why lines fr "Jusqu'à cinq cartes, en tête de votre profil public." / en "Up to five cards, at the top of your public profile."; hint fr "Ajoutez une carte depuis sa fiche, avec « Mettre en vitrine ». Faites glisser les cartes pour changer leur ordre." (en: use the English label of the add-to-showcase button); title and back keep their intros. Scope "Visible par tous"/"Visible to all", "Vous seul"/"Only you". Counts "%{count} sur %{total}"/"%{count} of %{total}" hidden; "n titres gagnés" (zero "Aucun titre gagné") / "n titles earned"; "débloqués"/"unlocked".
- Groups: "De base et événements"/"Basic and events", "Succès"/"Achievements", "Mission de la Confrérie"/"Brotherhood mission", "Sets · Thèmes"/"Sets · Themes", "Sets · Palmarès"/"Sets · Hall of fame". Chips "Actif"/"Active", "Débloqué"/"Unlocked", "Verrouillé"/"Locked" (uppercase by CSS).
- Earned: Standard "Offert à tous les joueurs" + "à l'inscription"/"Given to every player" + "when you signed up"; saison-1 "Offert aux joueurs de la saison 1"/"Given to the players of season 1"; soldes-hiver "Offert aux participants des Soldes d'hiver"/"Given to those who took part in the Winter sales"; millesime-2017 "Offert aux participants du Millésime 2017"/"Given to those who took part in Vintage 2017"; achievement "Gagné avec le succès %{name} · %{condition}"/"Earned with the achievement %{name} · %{condition}"; goal "Gagné en accomplissant la mission de la semaine du %{week}"/"Earned by completing the mission of the week of %{week}"; set "Gagné au palier %{tier} du set %{set} · %{seasons}" ("saison 1", "saisons 1 et 2")/"Earned at the %{tier} tier of the %{set} set · %{seasons}"; date "le %{date}"/"on %{date}".
- To earn: achievement "Débloquez le succès %{name} · %{condition}"/"Unlock the achievement %{name} · %{condition}"; goal "Accomplissez une mission de la Confrérie"/"Complete a Brotherhood mission"; set "Atteignez la moitié du set %{set}"/"Reach half of the %{set} set" + "%{held} / %{total} cartes · plus que %{missing}"/"%{held} / %{total} cards · %{missing} to go" (no "plus que" part when missing ≤ 0); spoken "%{held} cartes sur %{total}, plus que %{missing}"/"%{held} of %{total} cards, %{missing} to go"; absent "Set absent de la saison en cours"/"Set not in the current season"; event "Événement terminé"/"Event over".
- Names: "%{name}, %{state}. %{sentence}[, %{tail}]." then " Équiper."/" Equip." for an unlocked non-active back; states "actif/débloqué/verrouillé", "active/unlocked/locked".
- Equip: "Dos équipé. « %{name} » apparaîtra sur vos cartes face cachée." / "Card back equipped. %{name} will show on your face-down cards."; with season "Dos équipé. « %{name} », marque de la saison %{season}, apparaîtra sur vos cartes face cachée." / "Card back equipped. %{name}, with the mark of season %{season}, will show on your face-down cards."; failure "Le dos n'a pas pu être équipé. Réessayez." / "The card back could not be equipped. Try again."; season button "Équiper %{name} avec la marque de la saison %{season}" / "Equip %{name} with the mark of season %{season}", group "Marque de saison".
- Fallbacks when a fact is missing (earned set back with no tier row: "Gagné avec le set %{set}"/"Earned with the %{set} set"; goal back with no reward row: "Gagné en accomplissant une mission de la Confrérie"/"Earned by completing a Brotherhood mission").

Decisions: the goal back names the week of the player's earliest goal reward (the open question of the ticket). `aria-pressed="true"` only on the active back's current season button. Dates render on the server in the app time zone. The active back's button stays enabled (a click only fills the strip).

## Verification

**Commands** (with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w30_12 CHROME_BIN=/usr/bin/chromium`):
- `bin/rails test test/domains/game test/controllers test/helpers test/models` -- green
- `bin/rails test test/system/personalization_test.rb test/system/season_allocation_test.rb` -- green
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `node script/pixel_art/export.mjs --check` -- clean
- `bin/ci` pieces: `bundle exec rubocop` on touched files, `bundle exec i18n-tasks unused` and `missing`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references` -- clean

## Auto Run Result

- **Summary:** the Personalization page now groups VITRINE and TITRE DE PROFIL above DOS DE CARTE, each section with a why line, a count and a scope tag; the back picker is a mosaic grouped by origin in catalogue order under one strip naming the hovered, focused or tapped back with how it was earned (or can be), its date or set progress; one click equips a back in place through `Game::ChooseCardBack` (JSON), with a hidden polite announcement and no toast; a forged or failed choice leaves the frame and shows the failure in the strip.
- **Files:**
  - `app/domains/game/app/queries/game/{card_back_shelf,earned_set_backs,card_back_seasons,set_back_progress}.rb` -- shelf facts: unlock time, back tier, goal week, locked set progress, group.
  - `app/controllers/card_backs_controller.rb` -- JSON success with the announcement; HTML redirect without toast.
  - `app/helpers/card_backs_helper.rb`, `app/helpers/personalizations_helper.rb` -- sentences, tails, accessible names, counts, scope tag.
  - `app/views/personalizations/*`, `app/views/public_profiles/_showcase.html.erb`, `app/components/season_mark_component.html.erb` -- page order, section header, mosaic, strip, templates.
  - `app/frontend/controllers/back_picker_controller.ts`, `app/frontend/lib/back_picker.ts` (+ test) -- strip state, equip in place, announce.
  - `app/frontend/styles/{back-picker,personalization,season-mark}.css`, `app/frontend/entrypoints/application.css` -- the design.
  - `script/pixel_art/export.mjs`, `app/frontend/images/pixel/eye.svg` -- the scope tag's eye.
  - `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml` -- copy; `card_backs.chosen` and the old picker keys removed.
  - tests: shelf, helper, card backs, card back seasons and personalizations controllers, personalization system test.
- **Review:** 4 patched (medium 2, low 2), 0 deferred, 0 rejected.
- **Follow-up review recommended:** true -- two medium entries patched on a first pass; the unverified risk is the Turbo cache restore path (equip, navigate away, Back), which no test exercises.
- **Verification:** `bin/rails test test/domains/game test/controllers test/helpers test/models` 2099 runs green; `bin/rails test test/system/personalization_test.rb test/system/season_allocation_test.rb` 19 runs green; vitest 768 green; prettier, stylelint, pixel `--check`, file sizes, planning references, rubocop on touched Ruby, i18n-tasks unused and missing, packwerk, zeitwerk clean. French strings with « » use U+202F.
- **Residual risks:** the strip sticks at `top: 0` since the top bar does not stick; at 960px MISSION DE LA CONFRÉRIE may wrap below the first two groups; the hover lift was not seen in headless screenshots; dates render in the app time zone; a multi-season back equipped from its main button wears its latest season and announces it; the title picker keeps its radio-list layout (the preview and rank columns stay `[ASSUMPTION]`); the mock's dashed free showcase places are not built; English copy and the unmarked French fallbacks were written at build time.
