---
title: 'Refactor sweep'
type: 'refactor'
ticket: 6
created: '2026-10-20'
status: 'built'
baseline_revision: '39df98bf7484d804a208e6445450985e5dc31238'
commit: '82fabc5b060dd28314f3dcf9a88020184664e3c2'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The epic's builds (tickets 2, 3, 4, 5, 7) left deferred findings and rejected-but-worth-revisiting notes: stale system tests expecting the faded card back and the grid's missing slots, a visitor's collection pages still loading the ownership summary they no longer show, the hub system test's "0" step, possible dead CSS, helpers or strings from the faded back and the grid's missing slots, duplicated markup between the two forms of a set row, and planning ids in the comments of the files the epic touched.

**Approach:** Cleanup only, no behaviour change. Each item is fixed, recorded (in this plan, or as a note on another ticket) or dropped with a reason, in the sweep table under Implementation Notes.

</intent-contract>

## Implementation Notes

Oneshot: mostly comment and test edits plus two small code simplifications (a visitor's summary loads skipped, the set row's two branches merged), about 100 lines across mechanical edits.

Sweep (each item and its outcome):

| Item | Source | Outcome |
|------|--------|---------|
| `test/system/card_detail_test.rb` expects the faded back and grid missing slots | ticket 3 `deferred` | Fixed: the two tests rewritten to the face, PARTAGER and no copies row (not run: system tests are disabled). |
| `test/system/library_test.rb` counts grid missing slots | ticket 3 `deferred` | Recorded on 7.39 (epic-public-launch-readiness tickets.toml): the file is stale well beyond this epic (the entry has no grid, a visitor has no status), so a rewrite belongs to the rebuild. |
| A visitor still loads the ownership summary | ticket 4 review, rejected | Fixed: `LibraryController` loads the summary and the unique cards only for a player; a visitor's album drops from six queries to five (the season's cards); the visitor's grid stays at seven, as its count of the whole season, read from the query cache before, now runs itself; the comments say so. |
| `test/system/hub_test.rb` presses "0" | ticket 5 review, rejected | Dropped: every digit 1 to 9 is an item, so "a digit no item carries" cannot be reached on the hub; the step still shows a key that names no item leaves the hub, and `menu_key.test.ts` covers "0". |
| Dead CSS, helpers, strings of the faded back and grid missing slots | ticket 3 | Dropped: none left. `.card-detail__back*`, `card_back_image` and `card_details.not_owned` went with ticket 3; `.missing-slot` and `.collection-grid--fill .missing-slot` still serve set albums. Two stale comments fixed (card-detail.css: the stage's card back at 55 %, the share sheet "a holder's"). |
| Duplication between the visitor set rows of tickets 5 and 7 | caller | Fixed: both already render `library/set_progress_row` with `progress: false`; its two branches, which repeated the name and kind, are merged into one link. |
| Planning ids in comments of the files the epic touched | caller | Fixed: DESIGN.md, EXPERIENCE.md, CAP-n, AD-n, epic and story references removed from those comments and test names. |
| A visitor's set search runs the unstarted sets' figures it does not show | found in the sweep | Recorded, not fixed: skipping it changes `search_rows`' contract for one cheap query; low value. |
| `i18n-tasks unused` fails on `landings.show.unlock.tiles.*` (keys built from a variable in `landings/_unlock`) | found in the sweep, pre-existing on develop | Fixed: ignored in `config/i18n-tasks.yml`, with the reason, as the other dynamic keys are. |

## Plan Change Log

## Review Triage Log

### 2026-10-20 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `test/system/shell_test.rb:6` still names "story 8.1", in a file the epic touched — removed.
  - `[low]` `[patch]` `app/components/card_component.rb:14` keeps the design section pointer "(Rarity effects)" — now "rarity effects" in the sentence.
  - `[low]` `[patch]` The plan's sweep row said the visitor's query counts drop; only the album's does (6 to 5), the grid's stays at 7 as its whole-season count, before read from the query cache, now runs itself — row corrected.
  - `[low]` `[patch]` card-detail.css: "under the focus ring" misread the dropped design reference — the clause removed.
  - `[low]` `[patch]` Reflowed comments over the wrap width (card-detail.css public page block, `_share_sheet`, `cards/show`, `card_detail_test.rb`) or broken short (card.css) — rewrapped.

## Verification

**Commands:** (prefix Rails commands with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w14_6`; never run system tests)
- `bin/rails test` -- 0 failures
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/brakeman --quiet --no-pager --exit-on-warn` -- clean

## Auto Run Result

- Summary: the epic's deferred and rejected findings swept, each fixed, recorded or dropped in the sweep table above; no behaviour change. A visitor's collection pages no longer load the ownership figures they do not show; the set row's player and visitor forms share one link; the faded-back system tests describe the face; planning ids left the comments and test names of the files the epic touched; `i18n-tasks unused`, failing on develop, passes again.
- Files: `app/controllers/library_controller.rb` (figures for a player only); `app/views/library/_set_progress_row.html.erb` (one link for both forms); comments in `app/components/card_component.rb`, `app/controllers/pages_controller.rb`, `app/frontend/styles/card.css`, `card-detail.css`, `collection.css`, `hub.css`, `app/views/cards/_detail.html.erb`, `_share_sheet.html.erb`, `show.html.erb`, `app/views/library/_report.html.erb`, `_status.html.erb`; `config/i18n-tasks.yml` (the landing's unlock tiles ignored); tests `test/controllers/library_controller_test.rb`, `library_set_test.rb` (query comments and the album's count), `card_preview_tags_test.rb`, `pages_controller_test.rb` (headers and names), `test/system/card_detail_test.rb` (two tests rewritten), `hub_test.rb`, `shell_test.rb` (headers); a note on 7.39 in `epic-public-launch-readiness/tickets.toml`.
- Review (quick): 5 low findings, all patched; none deferred or rejected.
- Follow-up review recommended: false (only low entries patched).
- Verification: `bin/rails test` 2913 runs, 0 failures; `npm run test:js` 492 passed; typecheck, zeitwerk, packwerk, rubocop (853 files), i18n-tasks missing and unused, brakeman clean. No system test run.
- Residual risk: the two rewritten system tests have not run (system tests are disabled).
