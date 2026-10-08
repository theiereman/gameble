---
title: 'Refactor sweep'
type: 'refactor'
ticket: '6'
created: '2026-10-03'
status: done
baseline_revision: 'da3c97441c1831efacd62ad54e3c4583ebf666c9'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md']
warnings: ['oversized']
deferred:
  - summary: >-
      A database loaded from db/schema.rb dumps the three steam_* checks in another form than a database migrated from scratch, so a migration run on a schema-loaded test database rewrites them and CI's drift step fails.
    evidence: |-
      Pre-existing since story 2.11. db/schema.rb holds the fresh-migrate form ('x'::character varying::text), which a fresh postgres:18 container reproduces with CI's own step (no diff). Recreating that check from schema.rb deparses as ('x'::character varying)::text (checked on PostgreSQL 18.6), so `RAILS_ENV=test bin/rails db:migrate` after `db:test:prepare` dumps a different schema.rb. Workaround: `RAILS_ENV=test bin/rails db:drop db:create db:migrate` before committing a migration; a fix would rewrite the three checks in a form that round-trips.
    location: >-
      db/schema.rb:207-226 (steam_apps_details_exclusion_check, steam_apps_review_exclusion_check, steam_import_runs_status_check)
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Epic 4 left the same code twice: the two `set` actions (library, profile) load a tome line for line alike, the card detail and the shared card load the detail alike, four views rebuild the shelf's path lambdas, and five controller tests carry the same helpers; an empty slot's link name hides "Missing card" from screen readers (story 4.3, deferred, medium). The epic 2 and 3 retrospectives left items "for the next sweep": the pack-row hash built in three places (D1), no database check on `game_packs.card_season_ids` (O2), `HealBanksJob` serving every player even with a full bank (O5), and untested queue configuration and retry timing (F8).

**Approach:** A bounded cleanup. Intended visible changes, and only these: an empty slot's link is named by its visible text; the database refuses a malformed pack row; `HealBanksJob` skips full banks. Everything else keeps its behaviour, URLs, markup and exact query counts; findings bigger than a cleanup are recorded in `deferred-work.md`.

## Boundaries & Constraints

**Always:**
- `ShelfLoading#load_set(season, owner:)`: the published season (nil → `RecordNotFound`), `Catalog::SetSlots` by `params[:kind]`/`params[:key]` (nil → `RecordNotFound`), then `@set`, `@slots` (`{ card_season_id => CardView }` in slot order, as today) and `@quantities` (`Game::Quantities` of `owner`). `LibraryController#set` and `PublicProfilesController#set` use it, then set `@kind`, `@shelf_page` and `load_shelf` as today.
- `CardDetailLoading` concern (`app/controllers/concerns/card_detail_loading.rb`), private `load_card_detail`: season number from `request.path_parameters[:number]` only (never `params`), `Catalog::CardDetail.call(...)` → `@detail`, nil → `RecordNotFound`. Used by `CardsController#show` and `PublicProfilesController#card`.
- `app/helpers/shelves_helper.rb`: `library_shelf_links` → `{ tab_url:, set_url: }` (library routes) and `profile_shelf_links(token, kind)` → `{ tabs: PublicProfilesController::TABS, mark_complete: true, tab_url:, set_url: }` (Started tab without `kind`, `tab=started` on set links only when `kind` is Started), splatted into `render "library/shelf"` by `library/{show,set}` and `public_profiles/{_profile,set}`. Every href unchanged.
- `cards/_detail` links sets only when `detail.current_season` (decided in the partial); `cards/show` and `public_profiles/card` pass their `set_url` unconditionally.
- `link_to_card_detail(view, strings: nil, &)`: with `strings` (an owned face, `packs/show`'s faces) the `aria-label` from `card_details.open` as today; without (an empty slot) no `aria-label`, so its name is its visible title, year and "Missing card". `href`, class and `data-turbo-prefetch` unchanged.
- `test/support/library_requests.rb` (`LibraryRequests`): `sign_in(player)`, `hold(player, card_season_id, quantity)`, `set_members(season, key)` ordered by `position, id`, `assert_request_queries(count, &)` (clears the query cache first); the five epic-4 controller tests include it and drop their copies (call sites passing a record pass `.id`).
- D1: `Game::Pack.row(player_id:, kind:, season_id:, card_season_ids:, available_at:)` → the attribute hash with a fresh token (`kind` as a string); `FillBank`, `TopUpBank` (`insert_all!`) and `CollectDailyBonus` (`Pack.create!(Pack.row(...))`) use it.
- O2: migrations `20261003060000` (add, `validate: false`) and `20261003060001` (validate), strong_migrations pattern of `20261003050000/1`: check `game_packs_card_season_ids_check` — one-dimensional, at least one element, no NULL element (`array_position(card_season_ids, NULL) IS NULL`), exactly `Pack::SIZE` (5) for `regular` and `Pack::BONUS_SIZE` (3) for `bonus`; `db/schema.rb` updated; TEST database only. `GamePacks#create_pack` defaults a bonus pack to `BONUS_SIZE` cards.
- O5: `HealBanksJob` reads, per batch, each player's pack presence and bank count in one grouped query; a player with `BANK_SIZE` or more bank packs costs no further query; others get `FillBank` (no pack) or `HealBank` as today, failures reported and skipped.
- F8: tests that `config/queue.yml` serves `default` with a dispatcher in development and production, and serves the queue of `Game::HealBanksJob` and `Steam::RecoverStalledImportsJob`; that the waits between `Steam::ImportStepJob`'s attempts sum to less than `Steam::StalledImportRuns::STALL_AFTER` (read from the scheduled retries, time frozen).
- `deferred-work.md`: a `resolved:` line on each handled entry (the epic 2 and epic 3 retrospective entries, saying which parts are done and where the rest went); new entries for what is recorded instead (F2 rescore race, F5 freeze in models only, F7 capped refusal log, epic 4's rejected and residual findings: 4.3 `l=french` in the web layer and face links not reading the hidden year, 4.4 persona timeouts adding up to ~10 s, a banned player's sign-in Steam call and the unstubbed-lookup error reports in tests, 4.1 AD-11 reading role, 4.2 "set complete" styling in the library, the status band's rarity counts); a resolved entry for 4.3's empty-slot finding.
- `pending-approvals.md` (separate `docs:` commit): migrate development for the two new migrations; the "Empty slots name the missing card's rarity" entry reworded (the slot's link name is now its visible text; the rarity question stays for the detail page).
- Comments that describe changed code are updated.

**Never:** no new feature; no URL, markup or query-count change beyond the empty slot's `aria-label`; no test weakened or deleted (moved, tightened or added only); no development database, import, Steam call, push or deploy; nothing routed to epic 7 or the UX redesign; no cross-pack lock (F2) or database trigger (F5).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Empty slot | visitor opens a tome | slot link has no `aria-label`; its text holds title, year, "Missing card" | — |
| Owned face | player opens a tome; pack page later visit | `aria-label` "<title>, <rarity>, season n" as today | — |
| Query counts | library, set, profile, profile set, card, shared card | 6/4, 9/6, 7/8, 9/10, 4/2, 10/11 | — |
| Unknown set / card | as in 4.2–4.5 | 404 / unavailable page as today | — |
| Bad pack row | regular with 4 ids; bonus with 5; empty reward; a NULL id; a 2-D array | refused by the database | `ActiveRecord::StatementInvalid` |
| Valid rows | regular 5, bonus 3, reward 1+ | stored | — |
| Full bank | 3 players, banks full, on publication | no `HealBank`/`FillBank` call for them; queries independent of their number | — |
| Short / no bank | as in today's tests | topped up / filled | — |
| Retry timing | page job failing every attempt | sum of scheduled waits < 10 min; run failed after the last | — |

</intent-contract>

## Code Map

- `app/controllers/concerns/shelf_loading.rb` -- `KINDS`, `Spine`, `load_shelf`, `page_param`; add `load_set`.
- `app/controllers/{library,public_profiles,cards}_controller.rb` -- duplicated `set` bodies (library 27–43, profiles 42–57) and detail loading (cards 14–16, profiles 66–68). `PublicProfilesController`: `before_action :authorize_page, :load_owner`, `STARTED`, `TABS`, `shelf_relation`, `public_read?` — keep.
- `app/views/library/{show,set,_shelf,_tome}.html.erb`, `app/views/public_profiles/{_profile,set,card}.html.erb`, `app/views/cards/{_detail,show}.html.erb`, `app/views/packs/show.html.erb` (line 18, face link) -- shelf lambdas, set links, card links.
- `app/helpers/card_details_helper.rb` -- `link_to_card_detail`, `card_detail_open_label`.
- `packs/game/app/models/game/{pack,top_up_bank}.rb`, `packs/game/app/operations/game/{fill_bank,collect_daily_bonus,heal_bank}.rb`, `packs/game/app/jobs/game/heal_banks_job.rb`, `packs/accounts/app/queries/accounts/players_in_batches.rb` (batches of 500, not banned).
- `db/migrate/20261003050000_*`, `20261003050001_*` -- migration pattern; `db/schema.rb` `game_packs`.
- `packs/steam/app/jobs/steam/import_step_job.rb` (`ATTEMPTS = 3`, `retry_on StandardError, wait: :polynomially_longer`, `FAIL_RUN`), `packs/steam/app/queries/steam/stalled_import_runs.rb` (`STALL_AFTER`), `config/queue.yml`, `config/recurring.yml`.
- Tests: `test/controllers/{library_controller,library_set,public_profiles_controller,public_profiles_card,cards_controller,packs_controller}_test.rb` (library_set 91–98 asserts the slot links), `test/system/{tome,card_detail}_test.rb`, `test/support/{game_packs,catalog_seeds}.rb`, `test/packs/game/{heal_banks_job,top_up_bank,collect_daily_bonus,fill_bank}_test.rb`, `test/config/queue_config_test.rb`, `test/jobs/steam_import_step_job_test.rb` (stubs: `stub_app_list_page`, `stub_app_list_status(503, …)`; `Steam::WebApi.retry_interval` is 0 under stubs).
- `_bmad-output/initiative-gameble/{deferred-work,pending-approvals}.md` -- formats to follow.

## Tasks & Acceptance

**Execution:**
- [x] `app/controllers/concerns/{shelf_loading,card_detail_loading}.rb`, the three controllers -- `load_set`, `load_card_detail`; comments updated.
- [x] `app/helpers/shelves_helper.rb`, `app/views/library/{show,set}.html.erb`, `app/views/public_profiles/{_profile,set,card}.html.erb`, `app/views/cards/{_detail,show}.html.erb` -- shelf link builders; set links decided by the partial.
- [x] `app/helpers/card_details_helper.rb`, `app/views/library/_tome.html.erb`, `app/views/packs/show.html.erb` -- empty slot named by its text.
- [x] `test/support/library_requests.rb` and the five controller tests -- shared helpers; library_set and public_profiles tests assert the empty slot link has no `aria-label` and its text, the face keeps its label.
- [x] `packs/game/app/models/game/pack.rb`, `top_up_bank.rb`, `fill_bank.rb`, `collect_daily_bonus.rb` -- `Pack.row`.
- [x] `db/migrate/20261003060000_check_game_packs_card_season_ids.rb`, `db/migrate/20261003060001_validate_game_packs_card_season_ids_check.rb`, `db/schema.rb`, `test/support/game_packs.rb`, `test/packs/game/pack_test.rb` -- O2 and its matrix rows; `RAILS_ENV=test bin/rails db:migrate`.
- [x] `packs/game/app/jobs/game/heal_banks_job.rb`, `test/packs/game/heal_banks_job_test.rb` -- O5 and its matrix row.
- [x] `test/config/queue_config_test.rb`, `test/jobs/steam_import_step_job_test.rb` -- F8 tests.
- [x] `_bmad-output/initiative-gameble/deferred-work.md` -- resolved lines and new entries.
- [x] `_bmad-output/initiative-gameble/pending-approvals.md` -- the two entries (separate commit).

**Acceptance Criteria:**
- Given the suite before and after, when run, then every existing assertion still holds (moved helpers aside), the query counts are unchanged, and the new tests pass.
- Given `bin/rails test`, `bin/rails test:system`, `npm run typecheck`, `npm run test:js`, `bundle exec packwerk check`, `bin/rubocop` and `bundle exec i18n-tasks missing`, when run, then all pass.

## Implementation Notes

- `load_set` loads the card views and the owner's quantities before the shelf, so the queries of a set page come in another order; their number is unchanged (the count tests' comments list the new order).
- `cards/_detail` sets `set_url` to nil unless `detail.current_season`; both callers pass their lambda unconditionally.
- `link_to_card_detail` takes `strings:` as a keyword; the tome's faces and `packs/show` pass it, the empty slot does not.
- `LibraryRequests#set_members` orders by `position, id` everywhere; `library_controller_test.rb` ordered by `position` alone before (tightened).
- O2's check: `array_ndims(card_season_ids) = 1 AND cardinality(card_season_ids) >= 1 AND array_position(card_season_ids, NULL) IS NULL AND (kind <> 'regular' OR cardinality(card_season_ids) = 5) AND (kind <> 'bonus' OR cardinality(card_season_ids) = 3)`; the sizes are written out in the migration. `db/schema.rb` was edited by hand to the check's dumped form and the version: the test database's own dump also rewrote three unrelated `steam_*` checks (PostgreSQL's normalisation of a schema-loaded database), which were left out.
- O5: `HealBanksJob` groups the batch's packs by player with `COUNT(*) FILTER (WHERE kind = 'regular' AND opened_at IS NULL)`; a job over full banks costs two queries (the batch, the grouped read), whatever their number.
- F8: the retry test reads the scheduled time (`:at`) of each performed retry with time frozen; the queue test also checks the queue `config/recurring.yml` gives the stalled-import recovery.
- Comments updated: `ShelfLoading`, `CardDetailLoading`, `library/_shelf`, `library/_tome`, `cards/_detail`, `Game::HealBank`, `Game::HealBanksJob`, `Steam::ImportStepJob` (the retry waits versus `STALL_AFTER`), `test/support/game_packs.rb`.
- Review patch: `db/schema.rb` now holds the form a migration from scratch dumps (PostgreSQL 18), for the new check and for the three `steam_*` checks, which had drifted since story 2.11 (CI's `db:create db:migrate && git diff --exit-code -- db/schema.rb` step would fail); reproduced with `RAILS_ENV=test bin/rails db:drop db:create db:migrate`, no diff afterwards.

## Plan Change Log

## Review Triage Log

### 2026-10-03 — Review pass
- verdicts: 27 findings — high 0, medium 3, low 17, false 7, maybe-false 0
- findings:
  - `[low]` `[patch]` (blind) The comment on the query cache stayed above an unrelated test in five controller tests once `assert_request_queries` moved — deleted in the five files.
  - `[low]` `[reject]` (blind) `LibraryRequests` leaves OmniAuth's test-mode setup/teardown to each test — documented in the module; an `included` block across five files is more than a direct correction for a trap no current test meets.
  - `[medium]` `[patch]` (blind) `HealBanksJob::BANK_COUNT` restates `Pack.bank` in raw SQL with nothing tying them — grouped with the verification-gap row below; the `kind` half is now pinned by a test.
  - `[false]` `[reject]` (blind) `heal_bank.rb`'s header reads as if the rake task calls `HealBank` — it says "Run by Game::HealBanksJob", and `game:top_up_banks` runs that job (`game.rake:8`).
  - `[false]` `[reject]` (blind) The queue test checks dispatchers while recurring tasks come from the scheduler — F8 asked for the dispatcher (scheduled retries) and `default` being served; the recurring entry's queue is checked too; the `resolved:` line claims only that.
  - `[low]` `[reject]` (blind) No test walks every job class for a served queue — two non-import jobs exist and both are checked; a descendants walk needs eager loading, more than a direct correction.
  - `[low]` `[reject]` (blind) No shared-card test for an older season's unlinked sets — the rule now lives once in `cards/_detail`, covered by `cards_controller_test` "an older season by its number".
  - `[low]` `[reject]` (blind) `link_to_card_detail` without `strings:` silently means "empty slot" — every face caller already holds `strings` for `CardComponent`; an extra mode keyword adds surface for no current caller.
  - `[false]` `[reject]` (blind) `ShelvesHelper` makes views depend on controller constants — the views read `PublicProfilesController::STARTED` and `::TABS` before this change.
  - `[low]` `[reject]` (blind) `recording_operations` could mask a failure with `NameError` in `ensure` — only if `define_singleton_method` itself raised; test-only.
  - `[low]` `[reject]` (blind) The query-count test never spans two batches — the grouped read is per batch by construction; a two-batch test needs batch-size plumbing.
  - `[low]` `[patch]` (blind) The retry/stall comment and test said a retrying run is "never" taken for stalled, ignoring each attempt's HTTP time — reworded in `import_step_job.rb` and the test: only the waits are bounded; a recovery during a slow attempt enqueues a duplicate the cursor check stops.
  - `[low]` `[patch]` (blind) The pending-approvals entry kept the title "Empty slots name the missing card's rarity" — retitled "The card detail shows any card's rarity (epic 4, story 4.3)".
  - `[low]` `[reject]` (edge) Same `ensure` `NameError` masking in `recording_operations` — as above.
  - `[low]` `[reject]` (edge) A 2-D array might make `array_position` raise before `array_ndims` is checked — the insert is refused either way, only the message would differ; `pack_test` passes with the check's name.
  - `[low]` `[reject]` (edge) With `ATTEMPTS = 1` the waits test checks nothing — it asserts `ATTEMPTS` attempts ran; with one attempt there is no wait to bound.
  - `[low]` `[patch]` (edge) Orphaned query-cache comments — same as the first row, deleted.
  - `[low]` `[patch]` (edge) The "never taken for a stalled one" claim is false (Faraday retries and timeouts per attempt) — same rewording as above.
  - `[medium]` `[patch]` (verification-gap) The `kind = 'regular'` half of `BANK_COUNT` was unpinned: a short bank with unopened bonus or reward packs reaching ten would stop being healed with no failing test — the short player in "beside full banks…" now also holds an unopened bonus and reward pack; still healed once, bank at ten.
  - `[medium]` `[patch]` (intent) CI's schema-drift step was not run, and `db/schema.rb` drifted from a migration from scratch on three `steam_*` checks (since story 2.11), so "CI is green" would fail — reproduced on the test database; the fresh-migrate form committed; the step now leaves no diff.
  - `[low]` `[patch]` (intent) brakeman, bundler-audit and `packwerk validate` (CI steps) were not in the plan's verification — run: no warnings, no vulnerabilities, validation successful.
  - `[false]` `[reject]` (intent) 4.5's old-browser finding and 4.3's reveal-island links are only in `pending-approvals.md` — the invocation routes open product decisions there; they are recorded.
  - `[low]` `[reject]` (intent) The empty slot's name is asserted on the HTML, not the accessibility tree — with no `aria-label` the name is the link's content by the accname rules; an accessibility-tree system test is beyond a cleanup.
  - `[false]` `[reject]` (intent) D1 and O2 were done before the retrospective's trigger (a new pack writer) — the invocation asks for them in this sweep.
  - `[low]` `[reject]` (intent) O5 keeps walking every player's row — the retro's cost was about six queries per player; one grouped read per batch of 500 removes it; avoiding the walk needs an anti-join design, beyond a cleanup.
  - `[false]` `[reject]` (intent) The waits' sum depends on jitter — polynomial waits are about 3 s and 18 s plus at most 15 %, far below 600 s.
  - `[false]` `[reject]` (intent) Set pages run their queries in another order — the counts are unchanged and asserted; nothing depends on the order.

### 2026-10-03 — Review pass (follow-up)
- verdicts: 25 findings — high 0, medium 1, low 13, false 11, maybe-false 0
- findings:
  - `[low]` `[patch]` (blind) The "Migrate development for story 4.6" approval leaves out that the next deploy migrates too (`bin/docker-entrypoint` runs `db:prepare` on server start; a failed validation stops the boot) and gives no check to run first — entry now names the deploy and gives the SELECT for offending rows.
  - `[false]` `[reject]` (blind) F8's resolved line and the test name overstate the retry-versus-stall bound — both say "the waits"; the line reads "waits sum to less than `STALL_AFTER`", and the job comment states each attempt's HTTP time is outside the bound.
  - `[low]` `[reject]` (blind) `HealBanksJob`'s grouped count reads every past pack row of the batch, where `distinct.pluck(:player_id)` was index-only — true, but the job runs once per season publication and replaced per-player queries; a partial index or anti-join is beyond a direct correction.
  - `[low]` `[patch]` (blind) `cards/_detail` turned a missing `set_url` local into a silent nil — now `detail.current_season ? local_assigns.fetch(:set_url) : nil`, so a caller that forgets it raises again.
  - `[low]` `[patch]` (blind) The O2 migration's comment said a reward pack "holds any number" while the check requires one or more — reworded "one or more".
  - `[false]` `[reject]` (blind) Nothing ties `Pack::SIZE`/`BONUS_SIZE` to the check's literals — a change of either makes `FillBank`, `TopUpBank` and `CollectDailyBonus` inserts fail in their own tests on the test database; not silent.
  - `[low]` `[patch]` (blind) F5's deferred entry named `PublishSeason` as the only bulk write in `Catalog`; `PruneDraft#remove_others` `delete_all`s draft card-seasons too — evidence now names both (both draft-only, conclusion unchanged).
  - `[low]` `[reject]` (blind) New `deferred-work.md` entries carry no revisit trigger — the file's format does not ask for one; choosing triggers is a product call, not a direct correction.
  - `[low]` `[reject]` (blind) `hold` and request `sign_in` stay copied in game-pack, back-office and bonus tests — outside epic 4's five tests the intent names; a data/request split of the helpers across ~11 files is more than a direct correction.
  - `[low]` `[patch]` (blind) The queue test's recurring lookup used `dig`, so a missing entry failed as "include nil" — now `fetch`. The other claims are refuted: the three job queues are read from the jobs to catch drift (all `default` today), and `recurring.yml` has no ERB.
  - `[low]` `[reject]` (blind) The empty slot's name "Portal 2007 Missing card" has no separators — it is the visible text, as the intent asks; markup changes beyond the `aria-label` are out of the plan's Never list.
  - `[false]` `[reject]` (blind) `heal_bank.rb` says "short of ten" rather than `BANK_SIZE` — AD-7 fixes the bank at ten and the pack's comments name it so; nothing reads wrong.
  - `[false]` `[reject]` (blind) `BANK_COUNT` is named like a number — its comment says it is the per-player count expression; no caller misreads it.
  - `[low]` `[reject]` (edge) carried — a 2-D array might reach `array_position` before `array_ndims` — checked: PostgreSQL short-circuits (the expression yields false), and the insert would be refused either way; `pack_test` asserts the check's name.
  - `[false]` `[reject]` (edge) The validating migration aborts on a pack breaking the rule, with no repair path — every writer draws exactly `Pack::SIZE`/`BONUS_SIZE` cards (`Draw.pack` is `Array.new(size)`), so no such row is reachable; the approval entry now gives the check query.
  - `[medium]` `[defer]` (verification-gap, other) The three `steam_*` checks' rewrite in `db/schema.rb` may flip back on the next dump — true for a schema-loaded database (recreated, the check deparses `('x'::character varying)::text`), false as "another PostgreSQL version": a fresh `postgres:18` container (digest 5a5a84b1…, 18.6, CI's image) running CI's `db:create db:migrate && git diff --exit-code -- db/schema.rb` leaves no diff. Pre-existing since 2.11; deferred.
  - `[false]` `[reject]` (intent) "CI is green" was shown only locally, not on CI's `postgres:18` — now run on a fresh `postgres:18` container with CI's env: the drift step leaves no diff, `db:test:prepare` loads the schema and the pack tests pass (39 runs); the local server is the same image.
  - `[false]` `[reject]` (intent) carried — 4.5's old-browser finding and 4.3's reveal-island links are only in `pending-approvals.md` — open product decisions are routed there.
  - `[false]` `[reject]` (intent) 4.4's epic-Notes finding is not mentioned — settled by 530566b before this story; nothing left to record.
  - `[low]` `[reject]` (intent) carried — the empty slot's name is asserted on the HTML, not the accessibility tree.
  - `[false]` `[reject]` (intent) The sweep decided 4.3's deferred empty-slot question itself — "fixed or recorded" allows the fix, and the approval entry describes the new behaviour for the author to reverse.
  - `[false]` `[reject]` (intent) carried — D1, O2, O5 and F8 lie outside epic 4's code — the retro entries are addressed to "the next sweep".
  - `[low]` `[reject]` (intent) carried — "queries do not grow" is shown within one batch only.
  - `[low]` `[reject]` (intent) carried — no shared-card test for an older season's unlinked sets.
  - `[false]` `[reject]` (intent) carried — set pages run their queries in another order.

## Design Notes

- Recorded, not done: F2 needs a lock across `Steam` and `Catalog` (AD-2 forbids it); F5 a database trigger whose frozen columns need design; F7 waits on the real import's refusal count; 4.3's face links and 4.4's timeouts are low and outside a cleanup.
- F6 (set membership versus live card fields) is resolved by epic 4 as built: `SetLabel` names every set from `catalog_sets.params`; only the tome heading's year range and the detail's publisher read live card fields, which are the card's own identity.
- The store request spacing test and the stale `import_genres_page.rb` comment went with story 2.10 (no `StoreApi`, no genres page).

## Verification

**Commands:**
- `RAILS_ENV=test bin/rails db:migrate` -- expected: the check added to the test database only.
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `npm run typecheck && npm run test:js && bundle exec packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.

## Auto Run Result

**Summary:** Epic 4's duplication removed (one tome loader, one card-detail loader, shelf link builders, set links decided by the detail partial, shared request-test helpers); an empty slot's link is named by its visible text (title, year, "Missing card"); retro items done: `Game::Pack.row` (D1), the database check `game_packs_card_season_ids_check` (O2), `HealBanksJob` skipping full banks (O5), tests for the queue configuration and the retry waits (F8). F2, F5, F7 and epic 4's low findings recorded in `deferred-work.md`; `db/schema.rb` realigned with a migration from scratch so CI's drift check passes.

**Files changed:**
- `app/controllers/concerns/{shelf_loading,card_detail_loading}.rb`, `app/controllers/{library,public_profiles,cards}_controller.rb` -- shared set and detail loading.
- `app/helpers/{shelves_helper,card_details_helper}.rb`, `app/views/{library,public_profiles,cards,packs}/*` -- shelf links, set links in the partial, empty-slot link name.
- `packs/game/app/models/game/{pack,top_up_bank}.rb`, `packs/game/app/operations/game/{fill_bank,collect_daily_bonus,heal_bank}.rb`, `packs/game/app/jobs/game/heal_banks_job.rb` -- `Pack.row`, full banks skipped.
- `db/migrate/20261003060000_*`, `20261003060001_*`, `db/schema.rb` -- the pack-cards check (test database only); schema in its fresh-migrate form.
- `packs/steam/app/jobs/steam/import_step_job.rb` -- retry-wait comment.
- `test/support/{library_requests,game_packs}.rb`, `test/packs/game/{pack,heal_banks_job}_test.rb`, `test/config/queue_config_test.rb`, `test/jobs/steam_import_step_job_test.rb`, five epic-4 controller tests -- helpers, new tests, link-name assertions.
- `_bmad-output/initiative-gameble/deferred-work.md` (resolved lines, new entries), `pending-approvals.md` (migrate development, the rarity entry retitled; docs commit).

**Review:** thorough (four lenses), 27 findings. Patched 9 rows in 5 entries (medium: `BANK_COUNT`'s kind filter unpinned; medium: schema drift failing CI; low: orphaned comments, "never stalled" claim, stale pending-approvals title, CI's security and packwerk checks run). Deferred 0. Rejected 18: 11 low (not worth the added complexity, reasons in the log) and 7 false.

**Follow-up review:** true -- patched counts: high 0, medium 2, low 4 (entries). Unverified risk: the realigned `db/schema.rb` was checked against PostgreSQL 18.6 locally, not against CI's `postgres:18` image, whose dump of the three `steam_*` checks must match for the drift step to pass.

**Verification:** after the patches, `bin/rails test` 932 runs 0 failures; `bin/rails test:system` 46 runs 0 failures; `npm run typecheck`, `npm run test:js` (60), `packwerk validate` and `check`, `rubocop` (302 files), `i18n-tasks missing`, `brakeman`, `bundler-audit` clean; `RAILS_ENV=test bin/rails db:drop db:create db:migrate` leaves `db/schema.rb` unchanged. Test database only.

**Residual risks:** the development database needs the two migrations (pending-approvals.md); the check's validation fails if a development pack breaks the size rule (none expected); F2, F5, F7 and the low epic-4 findings stay recorded, not fixed.

### Follow-up pass (2026-10-03)

**Summary:** fresh four-lens review of 91a7ea7 and 77eec31. The previous pass's unverified risk is retired: a fresh `postgres:18` container (digest `5a5a84b1…`, PostgreSQL 18.6, what CI pulls) running CI's `bin/rails db:create db:migrate && git diff --exit-code -- db/schema.rb` leaves no diff, and `db:test:prepare` plus the pack tests pass on it. `HealBanksJob`'s filter matches `Pack.bank` (regular, unopened) and both halves are pinned by the short-bank test; `game_packs_card_season_ids_check` matches every writer's sizes.

**Files changed:** `app/views/cards/_detail.html.erb` (a missing `set_url` raises again); `db/migrate/20261003060000_check_game_packs_card_season_ids.rb` (comment: reward packs hold one or more); `test/config/queue_config_test.rb` (`fetch` for the recurring entry); `_bmad-output/initiative-gameble/deferred-work.md` (F5 evidence names `PruneDraft`; schema-flip entry); `_bmad-output/initiative-gameble/pending-approvals.md` (the 4.6 migrations also run on deploy, with a check query).

**Review:** 25 findings. Patched 5 (all low). Deferred 1 (medium, pre-existing: a schema-loaded test database dumps the `steam_*` checks differently). Rejected 19: 8 low and 11 false, reasons in the triage log.

**Follow-up review:** false -- follow-up pass, patched counts: high 0, medium 0, low 5.

**Verification:** `bin/rails test` 932 runs 0 failures; `bin/rails test:system` 46 runs 0 failures; `npm run typecheck`, `npm run test:js` (60), `packwerk validate` and `check`, `rubocop` (302 files), `i18n-tasks missing`, `brakeman` clean; CI's migrate and drift step on a fresh `postgres:18` container, no diff. Test databases only.

**Residual risks:** the development database and the next deploy need the two migrations (pending-approvals.md); a migration run on a schema-loaded test database rewrites the `steam_*` checks (deferred).
