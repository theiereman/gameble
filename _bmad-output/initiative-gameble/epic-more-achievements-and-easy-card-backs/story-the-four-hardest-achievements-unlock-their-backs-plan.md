---
title: 'The four hardest achievements unlock their backs'
type: 'feature'
ticket: '11'
created: '2026-11-02'
status: done
baseline_revision: '28d15f8c59a13270fa9eae008871d1a90d775082'
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

**Problem:** Luck Is a Marketing Concept, Leave Request Denied, Market Concentration and A Strictly Professional Relationship earn no card back, although DESIGN.md catalogues Trèfle fané, Assidu, Siège social and Contrat for them.

**Approach:** Draw the four backs (words TREFLE, ASSIDU, SIEGE, PACTE) in `script/pixel_art` and export them in the five sizes, name them under `card_backs.names` in both locales, and add the four achievements to `Game::CardBacks::ACHIEVEMENT_BACKS`, so the existing handler grants them on `AchievementUnlocked` (silently when retroactive) and the achievement tiles and the picker show them with no further change.

</intent-contract>

## Implementation Notes

Oneshot: the grant path (handler, job, shelf, tile helper, picker) is already driven by `ACHIEVEMENT_BACKS`, so the change is data plus art.

- Art lives in the new `script/pixel_art/achievement_backs.mjs` (its own anatomy helpers, same frame/field/inner line/brackets/word rules as the other backs, word dropped when wider than the back less 16 art pixels), wired into `export.mjs` beside the set backs: files, descriptions and review sheet. Keys: `trefle-fane`, `assidu`, `siege-social`, `contrat`. The mockup's palettes are used; the Contrat word is PACTE as DESIGN.md says.
- `card_backs.conditions` and the card backs helper are untouched (entry 12 keyed them on the unlock kind).
- English names: Wilted clover, Assiduous, Headquarters, Contract. French: Trèfle fané, Assidu, Siège social, Contrat.
- Tests: grant once / toast in play / silent backfill per achievement (`grant_milestone_backs_test.rb`), tile shows the back (`achievements_controller_test.rb`), picker lists four locked backs for a new account in both languages (`card_backs_controller_test.rb`); catalogue count, shelf group and exported file list updated.

## Plan Change Log

## Review Triage Log

### 2026-11-02 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 0, false 3, maybe-false 0
- findings:
  - `[false]` `[reject]` size check does not cover .mjs — not a rule break; the new file is 176 lines.
  - `[false]` `[reject]` French titles in the art script — same as existing BACK_DESIGNS entries, which are file titles, not UI text.
  - `[false]` `[reject]` picker test assumes the moderator fixture holds none of the four backs — fixtures hold no card back unlocks; grant tests use it as a clean player.

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- expected: 385 files up to date
- `bundle exec rubocop` on touched Ruby, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks missing` (no card_backs entry) -- expected: clean
- Tests written, not run in this tree: `test/domains/game/grant_milestone_backs_test.rb`, `card_backs_test.rb`, `card_back_shelf_test.rb`, `test/controllers/achievements_controller_test.rb`, `card_backs_controller_test.rb`, `test/lib/pixel_art_export_test.rb`
