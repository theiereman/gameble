---
title: "A set album's missing cards look like the not-owned cards of the catalog"
type: 'feature'
ticket: 24
created: '2026-10-24'
status: 'built'
baseline_revision: '8dcacbf74d26517c0b7a5f4eb95dbb3ea42e003f'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
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

### 2026-10-24 — Review pass
- verdicts: 5 findings — high 1, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `[high]` `patch` `test/system/library_test.rb` "the cards of a pack just opened are new…" still counted 8 `.card.card--grid` on the album, which now holds 16 faces with the not-owned ones — counts `.card.card--grid:not(.card--not-owned)` as 8.
  - `[medium]` `patch` DESIGN.md's Card not owned entry and EXPERIENCE.md's Card not owned (grid) row ended on an unqualified visitor rule that contradicts a public profile's album marking the owner's missing cards — the rule now names Toutes les cartes.
  - `[low]` `reject` The `Slot` comment in `set_album_loading.rb` gains a clause — it keeps an existing comment accurate about the new not-owned slot; dropping the clause would leave it wrong.
  - `[low]` `patch` The test comment "Two cards a row, the owned and the not-owned faces the same size." restates its assertion — removed.
  - `[low]` `reject` The rewritten `link_to_card_detail` comment — the diff shortens a pre-existing comment to match the narrowed signature; deleting it is outside this ticket.

## Verification

**Commands:**
- `bin/rails test test/controllers/library_set_test.rb test/controllers/public_profiles_controller_test.rb test/helpers test/components` -- expected: pass
- `bin/rails test test/system/library_test.rb test/system/collection_set_test.rb test/system/card_detail_test.rb test/system/public_profile_test.rb` -- expected: pass
- `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/ci`, `PARALLEL_WORKERS=2 bin/rails test` -- expected: pass
- `rg -n "missing-slot|library\.grid\.missing" app config test` -- expected: no match

## Auto Run Result

Status: built

- Summary: a set album's missing card (the player's own album and a public profile's, judged by the album owner's holdings) is the catalog's Card not owned face (`CardComponent owned: false`), in set order beside the owned faces, named like the catalog's and leading to the same card detail; the missing-card slot, its CSS and the `library.grid.missing` strings are gone; EXPERIENCE.md and DESIGN.md follow.
- Files: 16 files, among them `app/views/library/_album.html.erb`, `app/controllers/concerns/set_album_loading.rb`, `app/helpers/card_details_helper.rb`, the collection CSS, both locales, the library, collection set, card detail and public profile tests, DESIGN.md and EXPERIENCE.md.
- Review: the Quick lens ran from the coordinating session after the unattended run halted on `no subagents`. 5 findings: 3 patched (1 high, 1 medium, 1 low), 2 rejected (low) with their reasons above; nothing deferred.
- Follow-up review recommended: false — the high was a stale test count, now run and green, so no unverified risk remains to name.
- Verification: after the patches, `test/system/library_test.rb`, `collection_set_test.rb`, `card_detail_test.rb` and `public_profile_test.rb` 25 runs, 0 failures on Chromium 141 (unrun before); the unattended run's `PARALLEL_WORKERS=2 bin/rails test` 3169 runs, vitest 561, zeitwerk, packwerk, rubocop, i18n-tasks, typecheck, brakeman clean.
- Residual risks: an album page now draws up to sixty covers instead of the owned ones only.
