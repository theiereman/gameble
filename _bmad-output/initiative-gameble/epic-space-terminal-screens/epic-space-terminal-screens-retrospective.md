---
epic: epic-space-terminal-screens
date: 2026-10-08
verdict: accepted-with-open-items
criteria: declared
headless: false
---

# Retrospective: Space terminal: screens (epic 10)

## Epic summary

**Epic:** `epic-space-terminal-screens` (epic 10). It covers R1–R7, and its Done when has six criteria.

**Tickets:** all seven are `built`, with state `review`, none `done`. None is unfinished, so `pending_tickets` is empty. In build order:

| Ref | Title | Status | Commits on `develop` |
|---|---|---|---|
| 10.1 | Collection and sets | built | `b4817ea`, `fc106d4` |
| 10.2 | Card detail | built | `5eccb64`, `40f90fd` |
| 10.3 | Public profile and shared card page | built | `ad8d15f` |
| 10.4 | Daily booster and settings | built | `e5559b7` |
| 10.6 | Airier spacing, a centred booster opening and a still star field | built | `59d2d0e` |
| 10.7 | Collection opens on owned cards, with a filter zone and a search | built | `cbff2d5`, `130c102` |
| 10.5 | Refactor sweep | built | `2313b44`, `f232218` |

None of the seven tickets has been called `done` yet. Closing them is the author's call, through `bmad-ticket`.

**Ranges.** The plans' `baseline_revision` values cannot give the ranges:

- The baselines of 10.1, 10.2 and 10.3 (`a26b1d7`, `0574a26`, `fadcde2`) exist only on `origin/claude/vibrant-bell-pjm16f`. That is a pre-rebase history, and `develop` holds rewritten copies of those commits.
- The baselines of 10.4, 10.6 and 10.7 (`9823293`, `4cb65b1`, `47cea18`) resolve to no object in any fetched ref.
- Only 10.5's baseline (`3fc4caa`) is on `develop`.

Epic 10's commits are interleaved with those of epics 5, 6, 7 and 8. `cbff2d5..130c102`, for example, carries ten commits from other epics. So each ticket's evidence is its own commits, listed above: `<first>^..<last>`, and for 10.7 one commit at a time. `git_evidence.py` ran once per ticket. No merge commit falls in any range, so `merges_measured` equals `merge_count`, both 0.

**Evidence inventory:**

| Evidence | State |
|---|---|
| Epic file, Requirements R1–R7, Done when 1–6 | read |
| `tickets.toml` and the seven plans | read |
| Plan review sections | read for 10.1, 10.2 (four passes), 10.3, 10.4, 10.7 and 10.5. 10.6's Review Triage Log is empty: no review ran. |
| Story files | none; no ticket was refined |
| Session logs | not available. Process lessons come from the plans and commits only. |
| `pending-approvals.md`, `deferred-work.md`, the UX log `.memlog.md` | read where they touch epic 10 |
| Previous retrospective | `epic-space-terminal-redesign-retrospective.md` (epic 8), read |
| Clone | full; not shallow |

Going-in concerns from the user: none.

## Findings

Severity and disposition are given for each finding. Every finding below was re-checked against the code at `735c138`.

### Spec-to-implementation reconciliation

- **S1. A filtered or paged view clears NOUVEAU on cards it never showed.** Medium-high; Done when 2. *Disposition: defer, author decision (open question 1).*
  - **The mechanism:** `LibraryController#load_grid` posts `@seen_up_to`, the latest gain among the new cards shown (`app/controllers/library_controller.rb:116`). That post goes through `app/views/library/_collection.html.erb:28-31`. `Game::MarkCollectionSeen` then raises one global watermark (`packs/game/app/operations/game/mark_collection_seen.rb:24-27`). From then on, every holding gained at or before that time is no longer new (`packs/game/app/queries/game/collection_slots.rb:17-19`).
  - **Why one pack goes all at once:** `Game::OpenPack` stamps the same time on every card of a pack.
  - **The scenario:** a player opens three packs, then types a search or ticks a rarity. The results frame reloads and posts. All fifteen cards lose NOUVEAU, though only the matching ones were shown.
  - **What was accepted, and what is new:** 10.1 accepted the paged case, citing the architecture (10.1 plan, Design Notes and Residual risks). 10.7 multiplied the views that post, and listed "the seen post" as left out. 10.5 then dropped that finding, since `GREATEST` absorbs repeated posts. But `GREATEST` addresses repeated posts, not the cards a view hid.
  - **Test gap:** no test covers filtered-out or other-page cards. `test/controllers/library_controller_test.rb:259-276` checks only that nothing is posted when the filters hide the new card.
- **S2. Done when 6 still says "the booster opening is centred on a large window".** Low. *Disposition: spec reconciliation.* 10.6 built the vertical centring (`59d2d0e`). The author then removed it in `6362b0f` and recorded the decision in `ux-gameble/.memlog.md` ("supersedes the vertical centring decision") and in `DESIGN.md`. The epic file's R7 and Done when 6 were not updated. This repeats epic 8's process item 8.
- **S3. Done when 5 ("No screen of the medieval direction remains") is not literally met.** Low. *Disposition: accept as-is, author-deferred.*
  - **Still there:** the opened pack page still says "Your pack, Brother" / "Ton paquet, Confrère", in the familiar "tu" (`config/locales/en.yml:258`, `fr.yml:263`, rendered by `app/views/packs/show.html.erb:9`).
  - **Already decided:** the author parked it with the rework of tomes (`pending-approvals.md:10`, author 2026-10-08).
  - **Outside this epic's screens:**
    - the hub's goal line "The whole Brotherhood…" comes from story 6.3 (`79e3cd3`);
    - `/brothers/:token` URLs and the `ShelfLoading`/`Spine` names were kept deliberately (10.5 plan, Sweep inventory).
- **S4. 10.7 renders the phone filter zone in place, not as a sheet.** Low; R7 and 10.7's description say "(a sheet)". *Disposition: accept as-is.* It was decided with the author away (10.7 plan, Design Notes). The author later confirmed the filter assumptions ("all confirmed", `.memlog.md`, 2026-10-07). Recorded here so later runs stop re-flagging it.
- **S5. NON in "Animations réduites" behaves the same as SYSTÈME.** Low. *Disposition: accept as-is, open question 2.* `motion_reduced?` tests only `== true` (`app/controllers/application_controller.rb:97-98`). This is documented: NON is stored so a later story can let it override the system (10.4 plan, Implementation Notes). A player who picks NON still gets reduced motion when their OS asks for it.

### Diff-scope review: the boundaries between tickets

The `bmad-review` skill ran inline with its adversarial, edge-case and verification-gap lenses, in a sub-agent, without fanning out further.

- **B1. A set's page opens empty for a player who holds cards elsewhere but none in that set.** Medium; boundary 10.1 / 10.7. *Disposition: fix now.*
  - **The cause:** `default_state` picks "owned" from `@unique`, which counts the whole season, not the set (`library_controller.rb:95-97`).
  - **What the player sees:** tapping a 0/25 set row shows "Nothing matches these filters". The filter count reads 0 and the zone is folded.
  - **Test gap:** the 10.7 tests pass `state: %w[all]` explicitly (`test/controllers/library_set_test.rb:54,131,136,149`). The no-parameter case has no test.
- **B2. ◀ ▶ and the position line follow the whole tome, not the grid the card was opened from.** Medium; boundary 10.2 / 10.7. *Disposition: defer.*
  - **The cause:** `Catalog::SetNeighbours` walks the tome and ignores filters and holdings (`packs/catalog/app/queries/catalog/set_neighbours.rb:17-32`).
  - **What the player sees:** from the owned-only grid, ▶ lands on faded "NOT OWNED" backs, and the line reads "5 / 25" against a grid of 3. On return, `focusReturnLink` finds no link to the last card shown (`app/frontend/controllers/history_back_controller.ts:50-57`).
  - **Test gap:** the system tests that open a detail from the season grid run as a visitor (`test/system/card_detail_test.rb:162,299`).
- **B3. On a phone, ◀ Grille from a card opened on a public profile goes to the viewer's own collection.** Medium; boundary 10.2 / 10.3. *Disposition: defer.* `public_profiles/set.html.erb:35,39` link to the card without naming a set. `cards/show.html.erb:84-88` then builds the back from the card's first tome, with only `library_path` as the other page it can go back to.
- **B4. A public profile's set is not paged.** Low-medium; boundary 10.1 (60 slots a page) / 10.3; R1. *Disposition: defer.* `ShelfLoading#load_set` loads every slot (`app/controllers/concerns/shelf_loading.rb:229-239`). Publisher sets above 60 cards exist (`test/controllers/library_set_test.rb:196`).
- **B5. Visitors are offered OWNED, NEW and DUPLICATES chips that can never match.** Low. *Disposition: defer.* The chips are rendered in `app/views/library/_filters.html.erb:144-149`; `packs/game/app/queries/game/collection_states.rb:142-144` makes them match nothing.
- **B6. A French plural key lacks its `zero` form.** Low. *Disposition: fix now; it breaks a repo rule.* The key is `fr.public_profiles.set.copies` (`config/locales/fr.yml:392-394`, from `ad8d15f`). It is never called with 0 today.

Checked and clean:

- **GET never writes:** the watermark moves only through `POST library/seen`, with its policy, rate limit and a cap at now.
- **Pundit:** every new action has a policy.
- **Writes:** they go through `Game::MarkCollectionSeen` and `Accounts::UpdateSettings`.
- **Ids:** no database ids in URLs or the DOM.
- **Inline styles:** no `style` attribute.
- **Locales:** en and fr have matching keys, including the dynamic ones.
- **Motion switch (Done when 4):** every loop, blink, the ticker, View Transitions, the ◀ ▶ step and the daily-booster arc stop under both `prefers-reduced-motion` and `html[data-motion=reduced]`.
- **Shared card page (Done when 3):** no `og:image`, `twitter:image` or `image_src`, and no player named, both tested.

### Aggregate views

- **A1. Growth.**
  - **`app/frontend/styles/card-detail.css`, 865 lines.** It holds the in-app detail (1–580) and the whole public card page (582–865: the LIVE ticker placeholders, the legal-link stub, overrides of the shell top bar). `ad8d15f` moved `library.css`'s 362 lines into it rather than into a file of the public page's own.
  - **`app/frontend/styles/collection.css`, 724 lines.** It also restyles the shell top bar (44, 662), and the profile uses it as its component library (`profile.css:4`).
  - **`test/controllers/library_controller_test.rb`, 621 lines.**

  *Disposition: defer*, as a cleanup ticket alongside 8.15.
- **A2. Duplication across tickets.**
  - **Grid slot markup is written twice:** `app/views/library/_grid.html.erb:24-45` and `app/views/public_profiles/set.html.erb:31-49`. Their i18n keys are doubled too, and they use different queries (`Game::CollectionSlots` and `Game::Quantities`). This is the root of B4.
  - **Set list and row partials exist twice:** `library/_set_list` and `_set_row`, and their `public_profiles/` copies.
  - **The default filter state is computed in four places:** `library_controller.rb:95`, `collection_states.rb:36`, `collection_filters_controller.ts:38,75` and `collection_helper.rb:184`.
  - **Rarity colour modifiers, five copies:** card-detail.css twice, collection.css, hub.css and shell.css.
  - **Two swipe implementations:** `lib/swipe.ts` and `components/useCardSwipe.ts`.
  - **Three CSRF fetch helpers:** `collection_seen_controller.ts:22`, `lib/opening.ts:49` and `Booster.tsx:245`.
  - **JSON error and throttling code is doubled:** `collection_seen_controller.rb:47-54` and `packs_controller.rb:87-101`.

  *Disposition: defer.* B1 sits in the default state computed in four places, and B4 in the doubled grid; fold them into the same cleanup.
- **A3. Pattern divergence: planning ids.** The epic's commits add about 170 lines that carry planning ids:
  - AD-n and CAP-n references;
  - "story 10.x" and "epic 10 R2, R6";
  - "DESIGN.md" and "EXPERIENCE.md";
  - two migration headers.

  Examples are `library_controller.rb:1-21`, `sub_view_controller.ts:6` and `card-detail.css:4`. The rule landed in `AGENTS.md` (`6d5d550`) after the epic's last commit, so the builds did not break a rule that existed at the time. The repo holds about 830 such occurrences in all. *Disposition: defer* to epic 12 (human-readable codebase). This is not epic 10's alone.
- **A4. Other divergence.**
  - **Comment volume:** long comment headers (`library_controller.rb` 29 lines) against the swept epic 5 code, which has none.
  - **Hand-rolled buttons:** `cards/_detail.html.erb:136,146` builds button classes instead of using `ButtonComponent`.
  - **Four names for one screen:** library, collection, shelf, tome.
  - **A stale comment:** `packs/game/app/models/game/holding.rb:7` says only `OpenPack` sets `last_gained_at`, but `accept_trade.rb:50,53` sets it too, and `last_gained_at` drives S1.

  *Disposition: defer* to epic 12. The stale comment rides the S1 fix.
- **A5. Architecture.** A manual grep found no dependency that breaks the pack diagram. `Game::CollectionStates` joins raw SQL on `catalog_card_seasons` (`collection_states.rb:43-50`); that direction (Game → Catalog) is allowed, and 10.5 recorded it as a decision. *Narrowed scope:* `bundle exec packwerk check` could not run here, because the gems are not installed (Ruby 4.0.7 is required, 3.3.6 is present). The plans of 10.1, 10.2 and 10.5 record it as clean.

## Behavior verification

**Runtime behavior was not exercised by this retrospective.** The container has no Docker daemon (for Postgres 18 on 5433), no Ruby 4.0.7 and no `node_modules`, so neither the app nor the test suites could run.

What stands in for it:

- **CI on `develop`** is green at `735c138`, which carries every epic 10 commit (run 78, 2026-10-08). That push CI runs lint and the non-system tests only.
- **The plans record their own system-test runs:**
  - 10.1: 76 runs green;
  - 10.2: 81 runs green, then a flaky Back leg that 10.5 fixed;
  - 10.5: the library, tome, card detail and public profile system tests green.
- **No recorded system run:** 10.6's plan lists the system files to run but records no result. 10.7's verification omits system tests and excludes `card_face_visual_test.rb`.
- **Touch gestures** (swipe, ◀ ▶ step, history back) are verified only in headless Chromium. The real-device check is in `deferred-work.md`.

So Done when 1 (design on desktop and phone) and Done when 6 (filters and search) rest on the plans' records and the code, not on an observed run.

## Previous-retro follow-through

From `epic-space-terminal-redesign-retrospective.md` (epic 8, dated 2026-10-08). That retrospective was written after epic 10's builds (2026-10-06 and 07), so epic 10 could not have acted on it. The record below shows the state today.

1. **Split `Booster.tsx`, review `booster.css` and `shell.css`.** Owner: dev loop. **Not landed:** `Booster.tsx` is still 1,616 lines. Ticket 8.15 is planned and in progress (`b41eada`, `e3372317`).
2. **Reconcile 8.5 / R4 / AD-17 with `pixelcrush`.** Owner: author. **No evidence found** in the epic 8 epic file or in `pending-approvals.md`. `735c138` settled other entries.
3. **Size the reading pool and test the CSP `report-uri`.** Owner: dev loop. **No evidence found:** `report_uri` is wired (`config/initializers/content_security_policy.rb:47`), but no test or pool change was found.
4. **Measure on a real low-end phone.** Owner: author. **Not landed;** it needs a device.
5. **Move `OpenPackBenchmark` out of `game_benchmark.rake`.** Owner: dev loop. **Not landed:** it is still in `packs/game/lib/tasks/game_benchmark.rake`.
6. **Close epic 8.** Owner: author. **Not landed:** epic 8 counts 12 in review, 1 done, 1 dropped, 1 in progress.
7. **Record a built commit in every plan; keep builds in the shared history.** Owner: author and orchestrator. **Not landed, and it recurred here:** no epic 10 plan has `built_revision`, and six of seven baselines are not on `develop` (see Epic summary).
8. **Record a post-build replacement decision in the epic Notes.** **Not landed, and it recurred:** see S2, the centring removed by `6362b0f` without an epic Notes entry.
9. **Run a retrospective only on a full clone.** **Landed:** this run used a full clone and checked it.

## Action items

All items are proposed. This retrospective changed no code, ticket, plan, spec or `deferred-work.md`.

1. **Decide S1, then fix or record it.** Owner: author, then the dev loop. There are two options:
   - Make the watermark move only when the unfiltered first page is shown.
   - Accept the imprecision explicitly in the architecture and in Done when 2.

   Either way, add a test for filtered-out cards and correct `holding.rb:7`. *Proposed remediation, or a spec reconciliation.*
2. **Fix B1:** compute the default state from the set's own owned count on a set page, and add the no-parameter test. Owner: dev loop. *Proposed remediation.*
3. **Fix B6:** add the `zero` form to `fr.public_profiles.set.copies`. Owner: dev loop; it can ride item 2. *Proposed remediation.*
4. **One collection-cleanup ticket** for A1, A2, B2, B3, B4 and B5:
   - one grid slot partial and one set list shared by the collection and the profile, with profile paging;
   - one place for the default state;
   - the public card page's CSS out of `card-detail.css`;
   - ◀ ▶ following the grid's own order, or a decision that they browse the tome.

   Owner: dev loop, after the author accepts it; it fits after the tome rework (`pending-approvals.md:10`). *Proposed remediation.*
5. **Reconcile Done when 6 and R7 with `6362b0f`**: the booster opening starts at the top. Record S3 (the pack page's copy waits on the tome rework) and S4 (the phone filters in place) in the epic Notes. Owner: author. *Proposed spec reconciliation.*
6. **Close the epic.** Owner: author, through `bmad-ticket`, after reading this document: mark the seven `built` tickets `done`, or decide otherwise.
7. **Process: run a review on every ticket, and record each system-test run.** 10.6 had no review, and neither 10.6 nor 10.7 records a system run. Owner: orchestrator (BMad configuration).
8. **Process, carried forward a third time: record `built_revision` in every plan, and keep ticket builds in the shared history.** Epic 8's item 7 recurred: six of seven baselines here are not on `develop`. Owner: author and orchestrator.
9. **Process: when a ticket's work becomes an input to a later ticket's view, the later plan should name the earlier invariant it must keep.** Two examples are the NOUVEAU watermark under filters (S1) and the default state on set pages (B1). Both defects sit where 10.7 changed what 10.1's views show, and 10.7's plan never names 10.1's watermark rule. Owner: author (story template or `bmad-ticket`).

Action-item count: **9**.

## Acceptance verdict

**accepted-with-open-items** (machine verdict, criteria declared). It awaits the author's decision on open question 1.

Every ticket is finished (`built`), so nothing forces a rejection. Against Done when:

1. **The screens follow the design on desktop and phone.** Met per the plans and the code; not exercised here (see Behavior verification).
2. **NOUVEAU marks exactly the cards gained since the last visit.** Met only under the global-watermark reading that 10.1 accepted. A filtered or paged view clears cards it did not show (S1), and no reservation marks one. Open item.
3. **The shared card page names no player and previews without an image.** Met: no player named, no image tags, both tested.
4. **"Animations réduites" stops every effect, signed in or out.** Met for OUI and SYSTÈME. NON does not override the OS (S5, documented).
5. **No medieval screen remains.** Met apart from the opened pack page's copy, which the author deferred (S3).
6. **The collection, filters and search, the booster opening and the star field.** Met for the owned-first opening, the filters, the search and the still star field. The centring was superseded by the author (`6362b0f`; S2).

If the author reads Done when 2 literally, S1 becomes blocking and the verdict becomes **rejected** until item 1 lands.

## Open questions

1. **Is the global NOUVEAU watermark acceptable now that filters and search exist (S1)?** If not, Done when 2 is unmet and the verdict is rejected.
2. **Should NON in "Animations réduites" override the OS's reduced-motion setting (S5)?** Today it is a choice that behaves like SYSTÈME.
3. **Should ◀ ▶ on the card detail browse the grid it came from (filtered, owned-only), or the whole tome (B2)?** The answer shapes item 4.
