---
title: 'The feed loads older entries without limit'
type: 'feature'
ticket: 1
created: '2026-11-02'
status: built
baseline_revision: '0f70ac39b4a873f8be6f7983a69829a28a7a728a'
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

**Problem:** The feed shows the 30 latest notable entries (padded with pull fillers up to 10) and stops there; a player cannot read further back.

**Approach:** Page the feed with a keyset cursor on `(occurred_at, id)` and load the next page as the player nears the end of the list, reusing the `next-page` Stimulus controller and the `rel="next"` link pattern of the collection grid. The live feed keeps prepending and no longer trims the list.

## Boundaries & Constraints

**Always:** Same order, same `Game::Visibility` rules, same `kind` and friends filters on every page. The first page keeps today's content, including the pull fillers of a sparse feed; later pages hold notable entries only. The cursor is an opaque token: no database id, no readable timestamp in HTML or URLs. The next link is a real anchor that also works without JavaScript (an HTML page for the same cursor). A GET never writes. Every string in `en.yml` and `fr.yml`. Server HTML carries no `style` attribute; the controller clones nothing, the server renders the entries.

**Never:** No change to which entries are notable or visible, to `Game::NewFeedEntries`, `LiveFeedJob` or the live broadcast. No new JavaScript pagination controller (reuse `next_page_controller.ts`). No planning ids in code or tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First page | More notable entries than one page | One page of entries plus a `rel="next"` link carrying a cursor token | No error expected |
| Next page | Request with a valid cursor, `Accept` turbo stream | Entries appended to the list, the next link replaced or removed | No error expected |
| Last page | Fewer entries left than a page | Entries appended, no next link | No error expected |
| Hidden players | Older entries by a banned or private player | Skipped like on the first page, none counted toward the page size | No error expected |
| Filters | `filter` and `tab=friends` in the request | Cursor keeps both; older pages obey them | No error expected |
| Live entry | A new entry is broadcast while older pages are loaded | Prepended on top, loaded older entries stay | No error expected |
| Bad cursor | Tampered or malformed token | First page served | No error, no 500 |
| Sparse feed | Fewer than 10 notable entries | Fillers on the first page only, no next link | No error expected |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/feed_entries.rb` -- `LIMIT` 30, `MIN` 10, `WINDOW` 90, `PASSES` 10; `listed` mixes notable entries and pull fillers; `visible` scans newest-first windows with a `(occurred_at, id) <` cursor. Becomes a page: `call(viewer, kind:, players:, after: nil)` returns the entries plus whether more may follow and the cursor of the last one. Keep it under 400 lines.
- `app/controllers/feeds_controller.rb` -- `show` builds `@items`; add the cursor param, an opaque token encrypted with `ActiveSupport::MessageEncryptor` (key from `Rails.application.key_generator`), a bad token means the first page, and `respond_to` html and turbo_stream (as `LibraryController#cards`). `@live` stays first page, unfiltered only.
- `app/views/feeds/show.html.erb`, `_entry.html.erb` -- list gets an id on every variant (today only the live one has `feed-entries`); wrap in `data-controller="next-page"` and `focusout->next-page#focusLeft`; add the next-link nav with `data-next-page-target="pages"`. Add `show.turbo_stream.erb`: append entries to the list, replace the links nav.
- `app/views/library/_pages.html.erb`, `_collection.html.erb`, `cards.turbo_stream.erb`, `app/frontend/controllers/next_page_controller.ts`, `app/frontend/lib/next_page.ts` -- the pattern to follow; reuse as is.
- `app/frontend/controllers/feed_announcer_controller.ts`, `app/frontend/lib/announce_batch.ts` (`beyondLimit`) and its test -- the live list is trimmed to `Game::FeedEntries::LIMIT` after each prepend, which would delete loaded older pages: remove the trimming and the `limit` value, delete `beyondLimit` and its test if nothing else uses it.
- `app/jobs/live_feed_job.rb`, `app/models/live_stream.rb`, `app/domains/game/app/queries/game/new_feed_entries.rb` -- read only; check they do not read `LIMIT`.
- `config/locales/en.yml`, `fr.yml` -- one accessible label for the links nav and, if shown, an end-of-feed or loading status; both files, French narrow no-break space before `: ; ? !`.
- Tests: `test/system/feed_test.rb`, `test/system/live_updates_test.rb`, `test/controllers/` feed tests, `test/domains/game/` feed entries tests, `app/frontend/lib/announce_batch.test.ts`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/feed_entries.rb` -- page by cursor, fillers on the first page only, report the next cursor -- unlimited reading
- [ ] `app/controllers/feeds_controller.rb` -- cursor token encode/decode, turbo_stream and html formats -- next page without JavaScript fallback
- [ ] `app/views/feeds/show.html.erb`, `show.turbo_stream.erb`, a links partial -- next link, list id, `next-page` wiring
- [ ] `app/frontend/controllers/feed_announcer_controller.ts`, `app/frontend/lib/announce_batch.ts`, its test -- stop trimming the live list
- [ ] `config/locales/en.yml`, `fr.yml` -- new strings in both
- [ ] tests -- query (pages, hidden players, fillers first page only, filters, bad cursor), controller (html and stream, token opaque, no id in HTML), system test scrolling to a second page on a feed longer than one page, live entry prepended with older pages loaded; write them, do not run them

**Acceptance Criteria:**
- Given a feed longer than one page, when the player scrolls to the end of the list, then the older entries are appended in order with no duplicate and no entry from a hidden player.
- Given the last page is loaded, when the player reaches the end, then no further request is made.
- Given older pages are loaded, when a live entry arrives, then it is prepended and nothing loaded is removed.
- Given a tampered cursor, when requested, then the first page is served.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/domains/game test/controllers` filtered to the feed files -- expected: pass (run once in the main tree; implementing agents write tests but do not run them)
- `bin/rails test test/system/feed_test.rb test/system/live_updates_test.rb` -- expected: pass
- `npm run test:js`, `npm run format:check`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_planning_references`, `script/check_file_sizes` -- expected: pass
