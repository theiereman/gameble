---
title: 'Refactor sweep'
type: 'refactor'
ticket: '5'
created: '2026-10-07'
status: 'built'
baseline_revision: '3fc4caa7a17758436cedca22793c0fa1c6cfb9c0'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: 'The opened pack page (packs/show, epic 8 R5) still reads "Your pack, Brother" / "Ton paquet, Confrère" with "tu" and has no stylesheet.'
    evidence: 'config/locales/{en,fr}.yml packs.show; outside epic 10, left to the epic 8 sweep (lane 8.13).'
    severity: medium
  - summary: 'Kept deferred in deferred-work.md as features or device checks: fluid grid sizing, in-screen detail panel, rays and idle float, real-device gesture check, top-bar back button, donation link.'
    evidence: 'Implementation Notes, Sweep inventory.'
    severity: low
---

<intent-contract>

## Intent

**Problem:** Epic 10's screens are built, but the collection still speaks the medieval direction where a set list is empty ("No tome stands on these shelves yet, Brother", "Les étagères sont nues, Confrère"), against EXPERIENCE.md's voice (plain sentences, "vous", no title for the player); two keys of the old shelf (`library.show.tabs.label`, `library.show.empty.started`) outlive it; one card-detail system test is flaky; and the deferred findings epic 10 left in `deferred-work.md` need a fix, a record or a reason.

**Approach:** Cleanup only, inside the code epic 10 owns (collection and sets, card detail, public profile and shared card page, daily booster panel, spacing): reword the collection's empty, past-the-end and no-season lines as the public profile already says them, drop the two dead keys, make the phone Back test wait for Turbo's scroll record, and close or annotate each epic-10 entry of `deferred-work.md`. No behaviour change, no rename of shared keys, routes or classes (other lanes build on them at the same time), no card face change.

</intent-contract>

## Implementation Notes

**Route: oneshot.** About 40 changed lines: locale values in `config/locales/{en,fr}.yml`, three assertions of `test/controllers/library_controller_test.rb`, a wait in `test/system/card_detail_test.rb`, a comment rewrap in `app/views/library/_collection.html.erb`, and `resolved:` lines in `deferred-work.md`. Subagents unavailable, done in-session.

**Sweep inventory (what the epic's records and the code left, and what this story does with each).**

Fixed here:
- Medieval copy on a player screen: `library.show.empty.{tome,publisher,best_of_year}`, `library.show.past_the_end`, `library.show.no_season` (collection set list and the no-season panel), en and fr, reworded in plain "vous"-free sentences matching `public_profiles.show.*`. Same keys, so `public_profiles/_set_list` (lane 5.10) is untouched.
- Dead keys from the old shelf: `library.show.tabs.label` (the list's label is `library.sets.kinds`) and `library.show.empty.started` (the collection lists `ShelfLoading::KINDS` only; the profile has its own `public_profiles.show.empty.started`). `library.show.tabs.started` stays: the public profile's Started tab reads it.
- `deferred-work.md`, story 10.1's transitional shelf entry: `library/_shelf`, `_tome`, `library.css` and their keys are gone (story 10.3 and this story): marked resolved.
- `deferred-work.md`, story 10.2's faded-back query rule: decided, kept. The card's own page is what a share link opens; a signed-in player who does not hold the card must still see it there (CAP-9), and the showcase and pack faces lead to owned cards, so fading every unheld card on that page would hide shared cards. Marked resolved with the decision.
- `deferred-work.md`, story 10.2's flaky phone Back leg: the race is a scroll event still pending when `go_back` runs. Turbo files scroll positions from `scroll` events (`ScrollObserver#onScroll` → `history.updateRestorationData`), fired at the next frame; the test read `scrollY == 0` and went back within that frame, so the detail's 0 was filed under the grid's entry. The test now waits two animation frames before going back. A person cannot press Back within one frame of the restore; no app change. Marked resolved.
- `app/views/library/_collection.html.erb`: header comment rewrapped (one 150-column line).

Kept as recorded in `deferred-work.md` (features or checks, not cleanup):
- Fluid collection grid 120–170px with the art re-filtered (10.1): a layout and art-pipeline feature.
- In-screen detail panel beside the grid (10.1): a new tablet and desktop layout.
- Rays behind Épique and Légendaire, idle float (10.2, 10.3, one job): new visuals shared with the hub showcase and the booster (`booster.css`), epic 8's files swept in parallel by 8.13.
- Real-device check of the phone sub-view gestures (10.2): needs a person with devices (hitl).
- Top-bar "back one screen" button and the donation link (raised by the author during 10.3): new features; the first lives in the shell (epic 8), the second has no spec capability.

Dropped with a reason (review findings closed during the stories, re-read here):
- Story 10.7's "left out" findings (set group contents, history replace, hidden `kind` field, Game/Catalog SQL coupling, the seen post): each matches a decision in its Design Notes or AD-26 (the set group lists the aside's page plus chosen sets; filters replace the URL so Back leaves the collection; `kind` keeps the aside's list; `Game::CollectionStates` filters a Catalog relation through the public API and packwerk passes; a frame reload posts the watermark again, which `GREATEST` absorbs).
- Rejected findings of 10.2, 10.3 and 10.4 already carry their reasons in those plans; nothing new found in the code.
- Medieval names in code (`ShelfLoading`, `Spine`, `ShelvesHelper`, `brother_path`, the `/brothers/:token` URL): internal names and published URLs, not assets or styles; renaming them is a broad change of routes and shared helpers while lane 5.10 builds a friend's profile on them; a rename needs redirects and its own story.
- "Tome" in set labels and the kind chip: the spec's own vocabulary (spec CAP-6, catalog-and-rarity.md "Tomes"), not the old direction's; the mockups' "vol." differs only in the label format, left to the author.

Outside epic 10, noted for the orchestrator: the opened pack's page (`packs/show`, "mon dernier booster", epic 8 R5) still reads "Your pack, Brother" / "Ton paquet, Confrère" with "tu", and has no stylesheet; it belongs to the booster, swept by lane 8.13, so it is not touched here.

No medieval asset or style remains: `library.css`, `_shelf`, `_tome` and the old images are gone; a scan of class selectors in `collection.css`, `card-detail.css`, `profile.css`, `hub.css`, `card.css`, `shell.css`, `settings.css` finds none unused apart from Pagy's and dynamically built ones.

## Auto Run Result

Status: built.

- **Changes:** collection set-list copy (`library.show.empty.*`, `past_the_end`, `no_season`) reworded without the old "Brother" / shelf wording, en and fr; dead keys `library.show.tabs.label` and `library.show.empty.started` removed; `library_controller_test.rb` updated (plus a French no-season check); `card_detail_test.rb` waits two frames before Back (`wait_for_frames`), fixing its flaky Back leg; `_collection.html.erb` comment rewrapped; three `deferred-work.md` entries of epic 10 marked resolved (shelf transition, faded-back rule decided, flaky test).
- **Review:** not run. The author's quota was running out and the orchestrator asked to wrap up; the diff is copy, tests and records only (self-read, no finding).
- **Verification:** rubocop on changed Ruby files clean; packwerk validate and check clean; i18n-tasks missing and unused none; `bin/rails test` (PARALLEL_WORKERS=2) 1511 runs, 0 failures, 0 errors; system `library_test`, `tome_test`, `card_detail_test`, `public_profile_test` (PARALLEL_WORKERS=1) 22 runs green; `card_detail_test.rb` 5 more runs green. No frontend file touched, so typecheck and vitest were not run.
- **Left out:** see frontmatter `deferred` and the Sweep inventory; the pack page's medieval copy is epic 8's.

## Verification

**Commands** (env block of the lane brief; `DATABASE_URL=…/gameble_test_10_5`, `RAILS_ENV=test`):
- `bin/rubocop` -- no offenses
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` and `bundle exec i18n-tasks unused` -- none
- `npm run typecheck` and `npx vitest run` -- pass
- `bin/rails test` (PARALLEL_WORKERS=2) -- 0 failures, 0 errors
- `bin/rails test test/system/library_test.rb test/system/tome_test.rb test/system/card_detail_test.rb test/system/public_profile_test.rb` (PARALLEL_WORKERS=1) -- 0 failures; `card_detail_test.rb` re-run several times green
