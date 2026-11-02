---
title: 'The ten achievements are renamed'
type: 'feature'
ticket: '5'
created: '2026-11-02'
status: 'built'
baseline_revision: 'd5df3bcd189f36b3b8a40937ea696fbcddc4446a'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The ten original achievements still wear their draft names, and Statistical Non-Compliance has a builder-draft French copy and a borrowed `gem` glyph.

**Approach:** Swap in the approved English and French titles and conditions from the EXPERIENCE table "Achievement titles and conditions" for the ten achievements and the condition of Statistical Non-Compliance, draw its own glyph (bell curve with a dot outside it) in the pixel-art source and export it, keep every key and earned grant, and update the landing's Succès tile that lists the old names.

</intent-contract>

## Tasks & Acceptance

- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- `achievements.names`, `achievements.conditions`, landing `achievements` tile
- [x] `script/pixel_art/export.mjs`, `app/helpers/achievements_helper.rb`, `app/frontend/images/pixel/achievement-outlier*.svg` -- `outlier` glyph mapped to `statistical_non_compliance`
- [x] tests naming the old titles updated; EXPERIENCE copy-deck lines naming the old titles updated

Acceptance: the achievements screen, profile's latest achievements, allocation recap, landing tile and unlock toast read the new titles in both locales (they all read `achievements.names`); keys and unlocked rows are untouched.

## Verification

Static only: ruby -c, rubocop, check_planning_references, check_file_sizes, `node script/pixel_art/export.mjs --check`, `i18n-tasks missing`. Suites run once by the author in the main tree.

## Review Triage Log

### 2026-11-02 - Review pass
- verdicts: 3 findings - high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` EXPERIENCE copy deck lines 140, 141, 729 kept old titles - updated
  - `[low]` `[patch]` toast.test.ts fixtures named old titles - renamed
  - `[low]` `[reject]` landing text lists achievements 1, 2, 4, 5 while example rows show 1, 5, 3, 4 - acceptable; long titles in landing rows need a visual check by the author

## Auto Run Result

Renamed the ten achievements (names, Statistical Non-Compliance condition, landing tile), added the `outlier` glyph, updated tests and the EXPERIENCE copy deck. Static checks only; suites not run. Residual risk: long titles may wrap in the landing tile rows.
