---
epic: epic-recognizable-sets
date: 2026-10-20
verdict: rejected
criteria: declared
headless: false
---

# Retrospective: Sets players recognize

## Epic summary

Epic `epic-recognizable-sets` (13). It has 26 tickets: 24 `done` and 2 `dropped` (13.14 and 13.24, superseded by 13.25). `pending_tickets` is empty and no ticket is left at `built`. Every built ticket ran a **quick** review; none ran a thorough one.

**Ranges.** The plans' baselines interleave with other epics' commits, so each ticket's range is its own code commit, identified from the commits that touch its plan:

| Tickets | Code commits |
|---|---|
| 13.2 – 13.4 | 13.2 b54247e5, 13.3 42075b21, 13.4 046fb0c8 |
| 13.5 – 13.9 | 13.5 5466a3a2, 13.6 f0769610, 13.7 0e0f2763, 13.8 b66f5b05, 13.9 f5a784a7 |
| 13.10 – 13.15 | 13.10 2d11e867, 13.11 666f06ba, 13.12 c8edae75, 13.13 ec6ef26b, 13.14 64970ee9, 13.15 90f898cf |
| 13.17 – 13.20 | 13.17 4057fc00, 13.18 0c47240f + 6ef0cd33 + 56dff430, 13.19 25acfa95, 13.20 e8efd616 + ebeaea40 |
| 13.22 – 13.26 | 13.22 47dfa417, 13.23 32fee1d1, 13.24 740d75bc, 13.25 140d4a41, 13.26 d6ecbd53 |

Tickets 13.1 (spike), 13.16 and 13.21 (designs) have no code. In total, the code and tests come to about +14.7k / −6.4k lines over 308 files.

**Evidence inventory.**
- Available:
  - the epic file and its Done when, and the initiative requirements;
  - every plan and the spike report;
  - the 25 commits;
  - `pending-approvals.md` (the author's staging checks) and `deferred-work.md`;
  - the release tags.
- Missing:
  - session logs;
  - any staging measurement after the build for Done when 1;
  - an author check on staging of the 13.17 banner and the 13.23 ranks.

**Plan file name.** `story-the-published-season-gets-its-new-sets-once-plan.md` holds ticket 4. The file keeps the slug of entry 4's title before it was repurposed on 2026-10-15; its title and content match "The retired set kinds removed".

## Findings

### Spec-to-implementation reconciliation

- **S1. Done when 2 and R7 are superseded.** "A new player sees À DÉCOUVRIR filled" was removed by the author's decision in 13.18 (`tickets.toml` entry 18). The entry now opens on the search, then the results, then EN COURS or a pointer line (`test/controllers/library_controller_test.rb:942`). Disposition: accept; reconcile the epic text (action 10).
- **S2. Done when 1 is not measured after the build.** The 5 % UFO limit is only flagged, never enforced (`packs/catalog/app/models/catalog/themes.rb:59`, back-office preview `_preview.html.erb:112`). The only figure is the spike's probe before the build (4.35 %, `spike-sets-on-real-data-report.md:102`), and 5df828fd has since added a theme. Disposition: open; needs a staging read.
- **S3. Done when 4 and 7 are only partly shown on staging.**
  - The author confirmed 13.7, 13.8 and 13.15 on staging (`pending-approvals.md:12-14`).
  - Neither the 13.17 banner nor 13.23's ranks on a published ranked season has a staging check.
  - `v0.1.3-rc.1` holds every code commit except the 13.18 rework (6ef0cd33, 56dff430).
  - Disposition: open; needs a release candidate and a ranked season published on staging.
- **S4. Built and then removed, about 1.4k lines.**
  - The side detail column: 13.14 (+528 −98) and 13.24 (+185 −94), removed by 13.25.
  - À DÉCOUVRIR, built in 13.7 and removed by 13.18.
  - The grid card size, changed three times in one day (13.13, 13.20, 13.25).
  - The opening banner, built in 13.5 with no drawn design and redrawn by 13.16/13.17.
  - The plans name the cause each time: the design was built before the author had seen it rendered. Disposition: process lesson (action 12).

### Diff-scope review: tiers and celebration

These come from `bmad-review` (adversarial, edge-case, verification-gap); T1, T2 and T4 were checked at HEAD.

- **T1. The first credit in a new season records every tier the player already meets at once.**
  - `packs/game/app/models/game/set_tier.rb:21-54` inserts every tier the count meets, for the sets of the credited card only.
  - A new season gives the sets new ids, while every edition counts. A player at 45/62 who opens one member card gets novice to expert at once: four events, an "EXPERT" feed line and a celebration crossing every tick.
  - Reversed case: a set already complete through earlier editions has no `complete` row until it is credited again.
  - Disposition: defer to **17.1** ("Carried tiers are received once per season, silently"), which exists for exactly this.
- **T2. The banner reports the threshold instead of the cards held.** `app/frontend/lib/celebration.ts:89` sets `owned: highest.required`. Going from 15 to 18 cards across apprentice at 16 shows and announces "16/62" while the album says 18/62. Disposition: fix now.
- **T3. Two rules for "tier reached".**
  - The album and the sets in progress derive the tier from current holdings (`set_standing.rb:19-21`, `set_album_loading.rb:19`).
  - The feed, the celebration, the export and the achievements read `game_set_tiers`.
  - `SetTier`'s own comment says "a tier stays reached when cards leave". After a trade, the album mark drops while the feed still says ADEPT.
  - Disposition: open question.
- **T4. "Completion only below `SMALLEST_TIERED`" is applied in two places and missing in three.**
  - Applied: `pack_set_tiers.rb:25` and `set_rows_helper.rb:42`.
  - Missing: `set_tier.rb:43`, `set_standing.rb:13-21` and `set_rows_helper.rb:30-36`.
  - It only bites on a season published before 47dfa417. No test covers a set under 5 cards in `PackSetTiers`.
  - Disposition: fix now, one rule.
- **T5. "Reaches N tiers" counts sets, not tiers.** The feed uses `COUNT(DISTINCT set_id)` (`feed_entry.rb:55`) and the folded banner uses `results.length` (`celebration.ts:122-123`). Two tiers in one set are under-counted. Disposition: fix now.
- **T6. The feed and the celebration break a tie between sets differently.** The feed orders by set id (`feed_entry.rb:52`), the celebration by name in the locale (`celebration.ts:77`). Disposition: defer, low.
- **T7. A tier reached by a trade is never celebrated** (`pack_set_tiers.rb:16`, `where(pack_id:)`). Disposition: accept as intended unless the author says otherwise.
- **T8. The decision to celebrate in `Booster.tsx` is untested** (`:347-356`, `:514`, `:544`, `:364-369`). Disposition: defer to 7.39.

### Diff-scope review: set domain

- **D1. The publish guard lets pre-13.3 drafts through.**
  - `packs/catalog/app/operations/catalog/publish_season.rb:105-107` refuses only genres that are not themes. Old genre keys are mostly theme keys, and a game with no tag had `genres: []`.
  - Such a draft publishes with no error. Its untagged cards go to the UFOs, and its franchise, studio and hall of fame sets come out empty, because `review_count` and `developers` were never filled (`hall_of_fame.rb:22-23`, `set_builder.rb:51-55`).
  - The preview (`draft_preview.rb:53-55`) repeats the rule and shows no missing review counts.
  - Disposition: fix now, before the season 1 import (epic 11 builds the import beside the draft).
- **D2. `fill_card_sources` writes today's review count into card-seasons published earlier** (`fill_card_sources.rb:68-72`). The card detail then shows it beside the rating frozen at publication. Disposition: defer.
- **D3. `drop_game_set_completions` ships in the same release as the code that stops reading it** (`db/migrate/20261019150000`). `main`'s `ReleasePlayer` still uses the table. Disposition: accept, since production runs one container in maintenance; record it for the next release.
- **D4. Stale migration comment.** `20261012120002_widen_catalog_sets_kind_check.rb:1-2` promises a rebuild that the author ruled out. Disposition: accept; migrations are history.

### Diff-scope review: collection screens

- **C1. A card opened from another player's album has no way back.** `app/views/public_profiles/set.html.erb:8` passes `slot_context: nil`. A signed-out visitor lands on the public card page with no Back, and a signed-in viewer's Back leads to their own album. Disposition: fix now.
- **C2. A slot showing an earlier season's edition loses its set context.**
  - `set_album_loading.rb:32` sets `member: shown_id == card_season_id`.
  - The best edition is often an old one, so ◀ ▶ walk the old season's set and there is no Back to the album.
  - Disposition: fix now.
- **C3. A set's cards are counted three different ways.** The album total, the slots (which drop members without a view, `:30`) and `SetNeighbours` disagree. "n / total" and the album page Back lands on can be wrong. Disposition: defer, low.
- **C4. The unique-cards figure is computed two ways** (`library_controller.rb:94` and `:100`). Disposition: defer, low.
- **C5. The grid's "seen" watermark can mark new cards seen without showing them** (`library_controller.rb:68`). This is older than the epic, but one tile per game widens it. Disposition: defer.
- **C6. Query cost.**
  - Each grid-opened detail step re-plucks every tile id (`cards_controller.rb:103`).
  - Each keystroke in the set filter re-runs the full `cards` action (`collection_filters_controller.ts:101-104`).
  - Disposition: defer; measure once a season adds a second large edition.
- **C7. Smaller issues** (the remembered album on friends' albums, `aria-current` on a row that is not the page, the "◀ Grille" label for an album, the status line overstating the listed results, EN COURS capped at 10 without saying so). Disposition: defer, low.
- **C8. Dead code and banned ids.**
  - `Game::Quantities` has no caller left.
  - `collection_summary.rb:2` reads "(CAP-8)", added in 90f898cf.
  - `card_details_helper.rb:75` describes a set context that no longer exists.
  - Disposition: fix now.
- **C9. Disabled system tests assert the removed side shelf** (`test/system/library_test.rb:43-133`, `card_detail_test.rb:127`). Disposition: defer to 7.39.

### Aggregate views

- **Architecture and rules.**
  - All 17 migrations are expand/contract: checks are added unvalidated and validated in a second migration, and the one concurrent index has its own migration.
  - No GET writes; "seen" is a POST.
  - No database ids are exposed; every new action authorizes.
  - i18n-tasks is clean.
- **Packwerk broke during this retro.**
  - The 13.18 rework 6ef0cd33 made packwerk fail to parse `app/views/library/_entry.html.erb`, which turned develop's CI red (run 39401568953).
  - It was fixed and pushed in 56dff430.
  - Cause: the rework ran the tests but not the full verification list.
- **Duplication.**
  - The tier reached is worked out in four places (`set_standing.rb`, `set_tier.rb` RECORD_SQL, `pack_set_tiers.rb`, `celebration.ts`).
  - Per-set held counts are written three times in SQL (`sets_in_progress.rb`, `set_tier.rb`, `collection_summary.rb`).
  - One card per game is re-implemented outside `HeldGames` (`collection_states.rb`, `collection_tiles.rb`).
  - Tier names are hand-copied in `opening.ts:34` and `celebration.ts:31`.
  - Tier colours are mapped in four stylesheets.
  - T3, T4 and T5 come out of this duplication.
  - Disposition: defer to `epic-human-readable-codebase`.
- **Size.**
  - `Booster.tsx` is about 875 lines in one component, with 24 `useState` and 31 `useRef`.
  - `booster.css` grew from 985 to 1567 lines; the celebration is 38 % of it.
  - `celebration.ts` has 37 exports mixing ranking, strings, geometry and timing.
  - `set_rows_helper.rb` serves four screens.
  - `library_controller_test.rb` grew from 651 to 1211 lines and was touched by 15 commits.
  - Disposition: defer to `epic-human-readable-codebase` as named candidates.
- **Comments.**
  - About 1,100 Ruby comment lines were added: 27 of `library_controller.rb`'s 103 lines, and migration headers that describe intent.
  - This goes against "comment only an external constraint".
  - Disposition: defer to `epic-human-readable-codebase`.

## Behavior verification

- The full suite passed after the last code change of the epic: `bin/rails test` with 2,840 runs and 0 failures; `npm run test:js` with 484 passed.
- `bundle exec packwerk check` is clean after 56dff430.
- The author checked on staging (`pending-approvals.md:12-15`):
  - the rescore;
  - the collection on sets in progress (13.7);
  - the set album (13.8);
  - every edition counting (13.15).
- Not exercised:
  - the 13.17 banner and the 13.23 ranks on a published ranked season;
  - the 13.18 rework on staging;
  - the UFO share after the build.
  - These are recorded as never checked, not as clean.

## Previous-retro follow-through

The previous epic in build order, `epic-visitor-landing`, is not finished and has no retrospective file. Nothing to follow through on because the file is missing.

## Action items

Proposed; the author decides what runs.

1. **Fix T2.** The banner and its announcement show the cards held, not the tier's threshold. Owner: next `bmad-build`.
2. **Fix T4.** One rule for sets under `SMALLEST_TIERED` (completion only) in `SetTier` recording, `SetStanding` and `set_tier_mark`, with a test on a 3-card set. Owner: next `bmad-build`.
3. **Fix T5.** The feed and the folded banner count tiers, not sets. Owner: next `bmad-build`, with 2.
4. **Fix D1.** Publishing and the preview refuse, from one rule, a draft with cards missing their sources: no review count, or genres not recomputed into themes. Owner: next `bmad-build`, before the season 1 import.
5. **Fix C1 and C2.** A card opened from a public profile album, or from a slot showing an earlier edition, keeps its album context and its Back. Owner: next `bmad-build`.
6. **Fix C8.** Remove `Game::Quantities` and its test; drop "(CAP-8)" and the stale grid-context comment. Owner: next `bmad-build` or the refactor sweep.
7. **Carry T1 into 17.1**, naming the burst at a season's first credit and the missing `complete` row for sets already complete. Owner: `bmad-ticket` refine of 17.1.
8. **Carry T8 and C9 into 7.39**: the decision to celebrate, and the stale side-shelf system tests. Owner: `bmad-ticket` refine of 7.39.
9. **Staging evidence for S2 and S3.** After the next release candidate, publish a ranked season on staging, record the UFO share, and the author checks the banner and the ranks. Owner: author.
10. **Reconcile the epic's Done when 2 and R7** with 13.18: no À DÉCOUVRIR; search, results, EN COURS. Owner: author (spec reconciliation, not applied).
11. **Process lesson: every rework, oneshot or not, runs the plan's full verification list, packwerk included.** The 13.18 rework ran only the tests and turned CI red. Owner: build process.
12. **Process lesson: draw and show a screen before building it.** About 1.4k lines were built and then removed (S4), each time because the author first saw the design rendered. Owner: orchestration, `bmad-ux` before builds of new screens.
13. **Process lesson: tickets that change a domain rule shared across screens get a thorough review.** 13.5, 13.15, 13.22 and 13.23 all had quick reviews, and T3–T5 sit on the seams between them. Owner: orchestration.

## Acceptance verdict

**Machine verdict: rejected.** No human decision has been recorded yet.

- Every ticket is finished, and Done when 3, 5 and 6 are met in the evidence.
- Done when 2 is superseded by the author (S1).
- Done when 1 has no measurement after the build (S2).
- Done when 4 and 7 are only partly shown on staging: no ranked season published, and the banner and the 13.18 rework not seen there (S3).
- The fix-now findings T2, T4, T5, D1, C1, C2 and C8 stand open.
- The criteria are declared in the epic file.

## Open questions

- Does the author accept the epic now (**accepted-with-open-items**), with S2 and S3 left to the next staging publication and the fix-now items run as follow-ups, or hold it until then?
- T3: once reached, does a tier stay shown in the album when cards leave (as `SetTier` says), or does the album follow current holdings (as it does today)?
- T7: should a tier reached through a trade be celebrated somewhere for the player who reached it?
