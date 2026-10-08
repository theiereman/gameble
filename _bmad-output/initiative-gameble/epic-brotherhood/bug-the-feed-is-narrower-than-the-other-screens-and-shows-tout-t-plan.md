---
title: 'The feed is narrower than the other screens and shows « Tout » twice'
type: 'bugfix'
ticket: '13'
created: '2026-10-08'
status: 'built'
baseline_revision: '45c342c7ec2efd8d05778ab37fb81d56d2a9efa5'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md', '{project-root}/_bmad-output/initiative-gameble/epic-brotherhood/bug-the-feed-is-narrower-than-the-other-screens-and-shows-tout-t.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** On a desktop the activity feed stops at 720 px (`.feed { max-width: 720px }` in `app/frontend/styles/feed.css`) while the hub and the collection fill the shell's content width, and a lone selected TOUS tab (`.feed__tabs`, `feeds.show.all`) sits above a filter row starting with TOUT, so the same choice shows twice.

**Approach:** Drop the feed's own width cap so it spans the content width like the hub, and remove the TOUS tab row (markup, CSS, locale key and its controller-test assertions) until the Friends tab story brings TOUS and AMIS together; the phone layout is untouched. A system test compares the feed's width with the hub's at desktop width, signed in and out, checks a single « All » on the feed, and checks the phone column has no sideways scroll.

</intent-contract>

## Implementation Notes

Oneshot: a CSS cap and one markup row to remove, a locale key that goes with it, two controller assertions and one new system test file.

## Review Triage Log

### 2026-10-08 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` The rewritten header line of feed.css kept story ids and the block named DESIGN.md/EXPERIENCE.md, one line overlong — fixed: the header says what the stylesheet does without planning references, rewrapped.
  - `[low]` `[patch]` The phone test compared `scrollWidth` with `innerWidth`, which includes the scrollbar — fixed: compares with `clientWidth`, as friends_test.rb does.
  - `[medium]` `[patch]` Every system test ran on an empty feed, so the list and its rows were never laid out or measured — fixed: setup opens a pack of five Épique cards; the width check measures `.feed__list` against the hub, the phone check runs with five entries.
  - `[low]` `[patch]` The "one « Tout »" check only proved a class was gone — fixed: a French test finds « Tout » once and no « Tous » in the feed; all four system tests fail on the baseline and pass on the fix.

## Verification

All Ruby commands need Ruby 4.0.7 from rbenv: prefix them with `export PATH=/opt/rbenv/shims:$PATH && `; system tests also need `CHROME_BIN=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/chrome.sh SE_CHROMEDRIVER=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/cd/chromedriver`.

**Commands:**
- `bin/rails test` -- expected: all green
- `bin/rails test test/system/feed_test.rb test/system/hub_test.rb` (system env above) -- expected: green; the new width test fails on the baseline
- `bin/rubocop && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

**Summary.** The feed drops its own 720 px cap and spans the shell's content width like the hub; the lone TOUS tab row is gone until the Friends tab story brings TOUS and AMIS, so the filter row's « Tout » is the only one. Phone layout unchanged.

**Files.**
- `app/frontend/styles/feed.css` -- no width cap, no tab row style, header without planning references.
- `app/views/feeds/show.html.erb` -- the tab row removed.
- `config/locales/en.yml`, `fr.yml` -- `feeds.show.all` removed (unused).
- `test/controllers/feeds_controller_test.rb` -- no tab, the "Everything" filter current.
- `test/system/feed_test.rb` (new) -- list width equals the hub's signed in and out, one « Tout » in French, phone column without sideways scroll.

**Review.** One quick pass: 4 patches (1 medium, 3 low), nothing deferred or rejected.

**Follow-up review recommended:** false.

**Verification.** `bin/rails test` 1750 runs green; `bin/rubocop`, `i18n-tasks missing`/`unused` clean; `test/system/feed_test.rb` 4 runs green (all 4 fail on `45c342c`), `hub_test.rb` and `share_card_test.rb` green.

**Residual risks.** None known; the Friends tab story re-adds a tab row and its key.
