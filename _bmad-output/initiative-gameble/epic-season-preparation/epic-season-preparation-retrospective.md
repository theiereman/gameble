---
epic: epic-season-preparation
date: 2026-10-27
verdict: accepted-with-open-items
criteria: declared
headless: true
---

# Retrospective: Season preparation (epic 11, release 0.4.0)

## Epic summary

Three tickets, all finished (`tickets.py status`: counts 3/3 done; no `pending_tickets`). Plan statuses: 11.3 `done`, 11.1 and 11.2 `built` with the tracker at `done` (issues #186, #187). The epic's own issue #104 stays open until the 0.4.0 milestone is closed.

| Ref | Ticket | Plan baseline | Build commit |
|---|---|---|---|
| 11.3 | Rarity follows popularity | `61230dc9` | `d2aa1cb3` (2026-10-13) |
| 11.1 | Import builds beside the draft | `b8027876` | `dba2bcb7` (2026-10-21), 61 files, +1667/-646 |
| 11.2 | Administrator curates the theme list | `cef54310` | `a98d0fa5` (2026-10-22) |

Ranges: 11.1 from `b8027876` to `cef54310`, which contains 250 files of unrelated landing and shell work, so a baseline-to-baseline diff is not the ticket's diff. I read each ticket from its own build commit instead (`git show --stat`); this narrowing applies to every finding below. 11.2's range runs to `a98d0fa5`, the last commit of the epic; later commits touching its files: none (`git log a98d0fa5..HEAD` on the themes controller, views and promotion operation is empty).

Evidence available: epic file, three tickets, three plans, deferred-work entries, pending-approvals. Missing: session logs (process-lesson analysis skipped), a previous retrospective for this epic (none exists, so nothing to follow through).

## Findings

Source references are to the files in this folder unless stated.

1. **Staged import holds up on the plan's matrix (accept).** `dba2bcb7` adds `StageCardSeason`, `PromoteStagedBatch`, `DiscardStagedBatch`, one event each, the `catalog_staged_card_seasons` table, a widened status check validated in a second migration and a partial unique index on `ready` (expand/contract as AGENTS.md requires), and `test/packs/catalog/staged_batch_test.rb` (235 lines) plus `test/packs/steam/staged_import_test.rb`. The architecture amendment for AD-5 and AD-19 that the plan listed first is in the same commit (`architecture-gameble.md`, 4 lines).
2. **11.1 has an empty Review Triage Log (fix now, process).** Its plan says `review: quick`, `lenses_ran: [quick]`, a `risk: high` and `hitl: true` ticket, yet the Review Triage Log, Implementation Notes and Plan Change Log are blank (`story-an-import-...-plan.md` lines 81-86). A reader cannot tell "reviewed, nothing found" from "not reviewed". 11.2's log, by contrast, lists 9 findings with verdicts.
3. **11.1 left three deferred items (defer).** From `dba2bcb7` in `deferred-work.md`: drop the unused `steam_apps.carded_run_id` column (contract migration); remove `Catalog::UpsertDraftCard`, which only seeds and tests still call and which still writes card-seasons straight into the draft; deploy the staged import only while no import run is active (a run in flight ends `ready` with season number 0 and is refused as stale). The third is operational and unverified in production by its own wording.
4. **11.2 quick review: two real defects patched, one open (defer).** Triage log of `...theme-list...-plan.md`: medium findings were genres taking the first five tag ids before dropping unknowns, and an attach select with no blank option (both `patch`). Rejected with reasons: theme left without tags still counts in `Themes.keys`, one query per request in `SetLabel.genre`. Deferred: French theme names sit in `db/default_themes.yml`, the seed migration and fixtures, outside `config/locales/fr.yml`; AGENTS.md says French belongs only there, and `deferred-work.md` asks the author to confirm the exception.
5. **11.3 is the best-evidenced ticket (accept).** Thorough review with four lenses, 18 findings, 9 patched, 1 deferred (dev seeds stamp the current `VERSION` on arbitrary scores, `db/seeds.rb:31`), 8 rejected with reasons; the one medium (nothing pinned `VERSION`) got a test (`[3, 5000.098]`). It includes an end-to-end published-tier test. Residual risk named in its Auto Run Result (about 24 % of cards change tier) was resolved by the author: pending-approvals "Settled on 2026-10-20" records the staging rescore as done with "the tiers and the hall of fame sets' rarity mix as expected".
6. **Cross-ticket boundary: 11.1 and 11.2 both change publication gating.** `PublishSeason` gains a "run waiting" refusal (11.1) and then `unclassified_tags` and `ufo_share_over_limit` refusals (11.2); 11.2 lowered the `seed_sets_draft` fixture UFO share under 5 % so publish tests keep passing (plan Code Map). No finding of conflict, but no single test exercises promote-then-classify-then-publish in sequence; the commits show per-ticket tests only. Not verified beyond reading file lists.
7. **Authors' decision drift in notes (accept).** The epic file's 2026-10-08 note says "almost alone" for the rarity rule; 11.3's triage log records the settled strict reading ("breaks ties between equal counts, no rating floor"). The epic and `tickets.toml` wording was not updated, by design of the skill that never writes ticket files. Cosmetic.

## Behavior verification

Not exercised in this retrospective: no test suite or app run. Behavior evidence is secondhand: 11.3's recorded run (2413 tests, 0 failures, packwerk, rubocop and i18n clean) and the author's staging rescore approval of 2026-10-20. I found no record of the author's staging check of 11.1's promote/discard flow or 11.2's themes page against a real import; the plan for 11.2 names a system test (`test/system/themes_page_test.rb`, 62 lines, in `a98d0fa5`) but I did not run it.

## Previous-retro follow-through

Nothing to follow through on: no retrospective file exists for this epic and none was designated as its predecessor. The epics' sibling retrospectives (for example `epic-card-catalog`) are of other epics.

## Action items

1. Author: record in the 11.1 plan (or confirm by one line in pending-approvals) whether the quick review ran and found nothing; `story-an-import-builds-beside-the-draft-and-replaces-it-only-once-plan.md`, Review Triage Log. Proposed, awaiting a human.
2. Author: before the season 2 import, run the promote and discard flow on staging with a real import and the themes page, then record it in pending-approvals; no such record exists.
3. Author: decide the French-names exception for `db/default_themes.yml` and the seed migration (`deferred-work.md` entry from `a98d0fa5`); if kept, add a one-line note to AGENTS.md.
4. Dev loop: ticket for the three deferred cleanups of finding 3, the deploy-timing one to be added to the release checklist before the next production deploy.
5. Process: when a build runs a review, a blank triage log should block `built` (plan template check); owner: the bmad-build maintainer (the author).

## Acceptance verdict

**accepted-with-open-items**, criteria declared (epic Done when).

1. Staging and discard: holds. `dba2bcb7` and its tests; promotion is one operation.
2. Every tag listed, classified, editable names: holds. `a98d0fa5` adds themes, classifications, the page and seeds.
3. Publication refused for unclassified tags or UFOs over share; preview shows sizes and share: holds in code and per the plan matrix (`publish_season.rb`, `_preview.html.erb` in the commit); not run here.
4. A published season never changes: not demonstrated by a dedicated test that I could point at; it is a stated boundary of all three plans and nothing in the three commits touches published rows, but this is unverified.

Open items: findings 2, 3 and 4 and action items 1 to 3. Issue #104 remains open pending the author's milestone close.

## Open questions

- Did the author promote a real run and publish a themed season on staging? Would confirm criteria 1 to 3 in practice.
- Is the French-in-data exception acceptable?

## Assumptions

- Epic resolved from the folder path in the invocation; `pending_tickets` was empty.
- The machine verdict was formed on the evidence alone; the fix-now and defer routing above is mine, unconfirmed.
- Plan ranges were not used for diff measurement because 11.1's range includes unrelated work; per-ticket build commits were used instead.
- Session logs absent: process lessons come only from plans and commit subjects.
