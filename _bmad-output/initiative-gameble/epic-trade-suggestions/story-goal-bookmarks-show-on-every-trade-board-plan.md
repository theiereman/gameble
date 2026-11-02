---
title: 'Goal bookmarks show on every trade board'
type: 'feature'
ticket: 9
created: '2026-11-02'
status: 'in-progress'
baseline_revision: '6a713df243a1249cda9384b47c7d9ca76f5b7529'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The cards of the trade boards (proposal, summary, counter, draft, suggestion opener, picker) show no goal bookmark, although the grid, albums, capsule reveal and card detail do since commit 6a713df2.

**Approach:** Build the viewer's `GoalMarks` in `TradesController` and pass each card's goal positions to every `CardComponent` the trade surfaces render, on both sides; extend the accessible names so they end with the goals.

## Boundaries & Constraints

**Always:** Marks come from the signed-in viewer's goals (`GoalMarksLoading`), never the friend's, and are never stored. Bookmarks stay `aria-hidden`; a card's accessible name ends with `goal_card_words`. No `style` attribute, no database id in HTML, strings in both `en.yml` and `fr.yml`. A board with no matching goal shows no `.card__goals`.

**Never:** No change to `GoalMarks`, `CardComponent`, `card-goals.css` or the bookmark markup unless a trade card clips it. No TS markup change for faces (they are server HTML). No bookmark on the suggestion list rows (they have their own). No planning ids in code or tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Own card on a goal | Viewer has a goal whose set holds a card on their side | Numbered bookmark in the image's top-left corner, name ends with "goal n: set" | No error expected |
| Friend's card on a goal | Card on the friend's side belongs to the viewer's goal | Same bookmark and name | No error expected |
| No goal match | Board cards belong to no goal | No `.card__goals`, names unchanged | No error expected |
| Face loaded later | Editor fetches a face through `faces` JSON | Fetched HTML carries the bookmark | No error expected |
| Picker | Pick toggle for a goal card | `aria-label` ends with the goal words | No error expected |

</intent-contract>

## Code Map

- `app/controllers/trades_controller.rb` -- add `include GoalMarksLoading` and `helper_method :goal_marks` (as `LibraryController` does); `faces` action calls `trade_card_faces(views, goals: goal_marks)`.
- `app/helpers/trades_helper.rb` -- `trade_card_faces(views)` (~l.137) gains the goals; `trade_pick_label(pick)` appends `goal_card_words(goal_marks.goals_for(pick.view.card_id))`.
- `app/views/trades/_side.html.erb:17`, `_line.html.erb:4`, `_faces.html.erb:2` -- pass `goals: goal_marks.goals_for(view.card_id).map(&:position)` to `CardComponent.new`. The nil-line placeholder template in `_line` needs nothing.
- `app/models/goal_marks.rb`, `app/controllers/concerns/goal_marks_loading.rb`, `app/components/card_component.*`, `app/helpers/goals_helper.rb` (`goal_card_words`), `app/frontend/styles/card-goals.css` -- reuse as is. `Catalog::CardView#card_id` is the key.
- Accessible-name precedent: `card_detail_open_label` in `app/helpers/card_details_helper.rb` and how the grid card's name ends with goals in 6a713df2 (`git show 6a713df2`); follow it for the read-only `_side` and editor cards (visually-hidden goal words). The remove button label (`trade_board.strings.remove`) is a line name: leave it unless needed; `test/system/trade_board_test.rb` asserts `Remove Portal`.
- Tests to extend: `test/controllers/trades_controller_test.rb` (`goal_on` ~l.1186, `get_faces`/`faces_of` ~l.503, board assertions ~l.448), `test/controllers/trade_suggestion_prefills_test.rb`, `test/controllers/goal_bookmarks_pages_test.rb` (copy helpers and the "another player sees none" pattern), `test/system/goal_bookmarks_test.rb` (helpers `add`, `roguelike`, `marked_slots`, `assert_hangs_from_the_art`) for desktop and phone boards.

## Tasks & Acceptance

**Execution:**
- [ ] `app/controllers/trades_controller.rb` -- include `GoalMarksLoading`, expose `goal_marks`, pass goals to the faces JSON -- viewer's marks on every action
- [ ] `app/helpers/trades_helper.rb` -- goals in `trade_card_faces`, goal words in `trade_pick_label` -- fetched faces and picker names
- [ ] `app/views/trades/_side.html.erb`, `_line.html.erb`, `_faces.html.erb` -- pass goal positions to `CardComponent`, goal words in the read-only card name -- both sides on every board
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- only if a new string is needed (both files)
- [ ] `test/controllers/trades_controller_test.rb`, `test/controllers/trade_suggestion_prefills_test.rb` -- cover every matrix row incl. faces JSON, picker label, friend's side, no-goal board, other viewer sees only their own goals
- [ ] `test/system/goal_bookmarks_test.rb` (or `test/system/trade_board_test.rb`) -- bookmark hangs from the art on desktop and phone boards, none without goal; retrying Capybara matchers, restore any window resize

**Acceptance Criteria:**
- Given a goal whose set holds a card on a trade board, when the board renders on desktop or phone, then that card shows its numbered bookmark at the image's top-left corner and its accessible name ends with the goal words.
- Given a board with no goal card, when it renders, then no `.card__goals` appears.
- Given the friend views the same trade, then they see only their own goals' bookmarks.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/controllers/trades_controller_test.rb test/controllers/trade_suggestion_prefills_test.rb test/controllers/goal_bookmarks_pages_test.rb` -- expected: pass (run once, in the main tree; implementing agents write tests but do not run them)
- `bin/rails test test/system/goal_bookmarks_test.rb test/system/trade_board_test.rb` -- expected: pass
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_planning_references`, `script/check_file_sizes`, `bin/rails i18n-tasks` checks as in `bin/ci` -- expected: pass
