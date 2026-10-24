---
title: "A set album's missing cards look like the not-owned cards of the catalog"
type: 'feature'
ticket: 24
created: '2026-10-24'
status: 'blocked'
blocked_at: '2026-10-24'
blocked_reason: 'no subagents'
baseline_revision: '8dcacbf74d26517c0b7a5f4eb95dbb3ea42e003f'
route: 'oneshot'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** In a set album (`app/views/library/_album.html.erb`, rendered by `library#set` and `public_profiles#set`) a card the album's owner lacks is a hatched `.missing-slot` showing the game's name and year, while Toutes les cartes (and another player's full collection) shows the same card as the not-owned face: `CardComponent` with `owned: false` (faded, grey, pixel lock), linked by `link_to_card_detail(..., owned: false)` whose accessible name ends in "not owned". The author wants the album to match the catalog.

**Approach:** In the album, render a missing card as `CardComponent.new(card: slot.card, size: :grid, owned: false)` inside `link_to_card_detail(slot.card, strings:, context:, number: slot.number, owned: false)`, in set order beside the owned faces, leading to the same card detail as today, on the player's own album and on a public profile's album (judged by the owner's holdings, as another player's full collection is). Drop the missing-card slot entirely: its markup, its CSS in `app/frontend/styles/collection.css` (`.missing-slot*`, and its selector in the fill grid's face-size rule), the `library.grid.missing` key in `en.yml` and `fr.yml`, and the helper's strings-less "empty slot" branch (every caller now passes `strings:`, so `strings:` becomes required). Update the tests that asserted the slot (`test/controllers/library_set_test.rb`, `test/controllers/public_profiles_controller_test.rb`, `test/system/library_test.rb`, `test/system/collection_set_test.rb`, `test/system/card_detail_test.rb`, `app/frontend/lib/collection-grid.test.ts`) to assert the not-owned face, its "not owned" accessible name and its link, and update EXPERIENCE.md (Set album, Missing-card slot row removed, Card not owned (grid), Collection empty, card text order) and DESIGN.md (Set album, Missing-card slot removed, Card not owned) to say the album's missing cards are Card not owned faces.

</intent-contract>

## Implementation Notes

Oneshot: a view swap to an existing component and helper option, plus deletions and test and doc updates; about 60 lines added or changed beyond the deletions, all mechanical. The album's missing slot already carries the set's own card-season view (`SetAlbumLoading#album_slots`), so no loading change is needed.

- Files touched: `app/views/library/_album.html.erb` (missing card as `CardComponent owned: false` in a "not owned" link), `app/helpers/card_details_helper.rb` (`strings:` required, the empty-slot branch gone), `app/controllers/concerns/set_album_loading.rb` (comment), `app/frontend/styles/collection.css` (`.missing-slot*` removed), `config/locales/{en,fr}.yml` (`library.grid.missing` removed), the tests listed in the Approach plus `test/controllers/library_controller_test.rb` (vacuous `.missing-slot` absence checks dropped), and the two UX documents.
- Surprise: `PublicProfilesControllerTest#test_the_owner's_figures,_never_the_viewer's` counted `.set-album__grid .card` as the owner's cards; it now counts the faces not set apart, and the viewer's own holdings still never count (the album judges by the owner's).
- The phone album check in `test/system/library_test.rb` now compares an owned and a not-owned face on the same row (same top, width and height).
- `ux-gameble/mockups/key-collection-sets.html` still draws missing-card slots; the spines win over the mock and the ticket names only EXPERIENCE.md and DESIGN.md, so it is left as is.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/controllers/library_set_test.rb test/controllers/public_profiles_controller_test.rb test/helpers test/components` -- expected: pass
- `bin/rails test test/system/library_test.rb test/system/collection_set_test.rb test/system/card_detail_test.rb test/system/public_profile_test.rb` -- expected: pass
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/ci`, `PARALLEL_WORKERS=2 bin/rails test` -- expected: pass
- `rg -n "missing-slot|library\.grid\.missing" app config test` -- expected: no match

## Auto Run Result

Status: blocked
Blocking condition: no subagents. Step 4 (review) requires launching a context-free reviewer subagent; this session had no subagent tool, so per the workflow the run halted before review. Implementation and verification are complete and committed on the branch; to finish, set `status` to `in-review` and re-run `bmad-build-auto` on this plan in a session that can launch subagents (it resumes at step 4).

**Summary:** a set album's missing card (own album and a public profile's album, judged by the album owner's holdings) is now the catalog's Card not owned face (`CardComponent owned: false`: faded, grey, pixel lock, no tilt or rarity effects), in set order beside the owned faces, its link named like the catalog's ("…, season N, not owned" / "…, saison N, non possédée") and leading to the same card detail. The missing-card slot (markup, CSS, the `library.grid.missing` strings, the helper's strings-less branch) is gone; EXPERIENCE.md and DESIGN.md follow.

**Verification (DATABASE_URL on gameble_test_w1324, Postgres 16):**
- `PARALLEL_WORKERS=2 bin/rails test`: 3169 runs, 0 failures, 0 errors, 0 skips.
- `npm run test:js`: 53 files, 561 tests passed. `bin/rails zeitwerk:check`: all good. `bundle exec packwerk validate` and `check`: no offenses.
- `bin/ci` steps run one by one (its schema steps need Postgres 18 and no migration changed): `bin/rubocop` no offenses; `i18n-tasks missing` and `unused` clean; `npm run typecheck` clean; `brakeman` no warnings; `db:seed:replant` passes; `bin/bundler-audit` reports crass 1.0.7 (fix >= 1.0.8), pre-existing and unrelated to this change.
- System tests (`test/system/library_test.rb`, `collection_set_test.rb`, `card_detail_test.rb`, `public_profile_test.rb`) could not run: no Chrome in the container and selenium-manager's download of Chrome for Testing is refused by the egress proxy (403). They were updated but are unverified.
- `rg "missing-slot|library.grid.missing" app config test`: no match.

**Residual risks:** the four system test files are unrun; the new phone same-row geometry check and the 160 × 240 link size check in `collection_set_test.rb` are the most likely to need adjustment. A missing card now draws its cover art (as the catalog's faces do), so an album page loads up to sixty covers instead of the owned ones only.
