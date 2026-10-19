---
title: 'The roadmap derives from the initiative'
type: 'feature'
ticket: 10
created: '2026-10-19'
status: 'built'
baseline_revision: '3eded637bd86575368f9addf3e2a00fb3d06d35e'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred:
  - summary: >-
      The AGENTS.md roadmap rule asks for a rerun only when a ticket or epic the roadmap shows changes status, but an unshown ticket of a shown epic without a frontmatter status also moves the milestone's derived status and fails the drift test.
    evidence: |-
      epic_status() in script/roadmap/export.py derives a milestone's status from every non-dropped ticket of its epic; the reviewer reproduced --check failing after an unchosen entry of a chosen epic went in-progress. The fix is a wording change in AGENTS.md (e.g. "a ticket of an epic the roadmap shows"), which the triage rules route to the author.
    location: >-
      AGENTS.md (Policy, roadmap bullet)
    severity: medium
  - summary: >-
      bin/rails test now needs python3 >= 3.11 on the PATH (tomllib), which neither .tool-versions nor AGENTS.md "Running and verifying" declares.
    evidence: |-
      test/lib/roadmap_export_test.rb runs python3 script/roadmap/export.py; an older Python fails with ModuleNotFoundError tomllib rather than a drift message. CI (ubuntu-latest, Python 3.12) and the author's machine (3.13) are fine. The fix edits AGENTS.md or the toolchain file.
    location: >-
      test/lib/roadmap_export_test.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** The landing's roadmap must show epics and a few player-facing stories with their status, but `_bmad-output` is not in the production image, and nothing keeps a shown roadmap in step with the initiative.

**Approach:** Opt-in `roadmap = { en = "...", fr = "..." }` fields on the initiative's `[[epic]]` tables and on epics' `[[entry]]` tables carry the author's wording; `script/roadmap/export.py` reads them plus each ticket's state from `tickets.py status`, and writes the app's roadmap data and its en/fr strings; `--check` and a Rails test fail on drift; AGENTS.md tells every session to rerun it.

## Boundaries & Constraints

**Always:** Status comes from `tickets.py status` JSON (never re-derived from plan files by hand). Output is deterministic and byte-stable (a second run changes nothing). Keys contain only `[a-z0-9_]`. Strings written as JSON-quoted YAML scalars (`json.dumps(..., ensure_ascii=False)`). Python stdlib only, Python >= 3.11 (`tomllib`). All repo text English except the generated `fr.yml`.

**Never:** Write any `roadmap` field into the real initiative (curation is the author's). Edit `_bmad/` or any ticket, epic or plan file other than this plan. Show the roadmap in a view (stories 11 and 12 do). Put planning ids in code, tests or generated keys.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Chosen epic and stories | epic and two entries with `roadmap` | one milestone, two stories, in build order, with mapped statuses; strings in both locale files | exit 0 |
| Unchosen tickets | entries without `roadmap` | absent from every output | — |
| Status mapping | ticket state `done` / `in-progress` or `review` / `planned` or `backlog` | `done` / `in_progress` / `to_come` | — |
| Epic status | frontmatter `status` done or in-progress; else derived | done, in progress as set; derived: every non-dropped ticket done (at least one) → done; any ticket in-progress, review or done → in_progress; else to_come | — |
| Dropped | dropped story, or epic with status dropped | left out | — |
| No curation | no `roadmap` field anywhere | `milestones: []` and empty `milestones: {}` locale trees | exit 0 |
| Bad field | `roadmap` not a table of exactly non-empty string `en` and `fr` | — | exit 1, message names the epic slug / entry title |
| Orphan story | entry has `roadmap`, its epic does not | — | exit 1, message names both |
| Key clash | two chosen entries in one epic give the same key | — | exit 1 |
| Drift | committed files differ from what the script writes | — | `--check` exits 1, prints `differs: <path>` per file and the command to rerun |
| Tree error | `tickets.py status` exits non-zero | — | exit 1 with its stderr |

</intent-contract>

## Code Map

- `_bmad/method/scripts/tickets.py` -- read-only. Run as `python3 _bmad/method/scripts/tickets.py --project-root <repo root> status <abs initiative dir>`; JSON has `tickets[]` (`epic` slug, `id`, `title`, `state` in planned/backlog/in-progress/review/done/dropped) and `epics[]` (`slug`, `status` from the epic file's frontmatter: '', in-progress, done, dropped). It tolerates extra keys in `[[epic]]`/`[[entry]]`; `pull` never copies them. Its `title_slug` (NFKD → ascii, non `[a-z0-9]` runs → `-`, 60 chars) is the model for keys (use `_`).
- `_bmad-output/initiative-gameble/tickets.toml` -- the initiative's `[[epic]]` tables (`id`, `slug`, `title`) in build order; roadmap order follows it. Each `epic-*/tickets.toml` lists `[[entry]]` tables (`id`, `title`, ...) in build order.
- `script/pixel_art/export.mjs` + `test/lib/pixel_art_export_test.rb` -- the pattern to copy: generator with `--check` and `--out`, Rails test running it through `Open3.capture2e(..., chdir: Rails.root.to_s)` and asserting the committed output matches.
- `config/locales/pagy/{en,fr}.yml` -- proof that subfolders of `config/locales` are loaded by Rails and read by i18n-tasks (`config/locales/**/*%{locale}.yml`).
- `AGENTS.md` -- the Policy bullet "Never hand-edit `app/frontend/images/pixel/`..." is the model for the new rule; the bullet "French belongs only in `config/locales/fr.yml`" needs the generated roadmap file and the `fr` wording added.

## Tasks & Acceptance

**Execution:**
- [x] `script/roadmap/export.py` -- new stdlib Python script. Options: `--initiative <dir>` (default `_bmad-output/initiative-gameble`, relative to the repo root = two levels above the script), `--out <dir>` (default repo root; writes `<out>/config/roadmap.yml`, `<out>/config/locales/roadmap/en.yml`, `<out>/config/locales/roadmap/fr.yml`), `--check` (compare, write nothing). Reads the initiative and epic `tickets.toml` files with `tomllib`, states from `tickets.py status`, validates per the matrix, writes only files whose content changed, prints a one-line summary (`roadmap: N milestones, M stories written` / `up to date`). -- the generator.
- [x] `config/roadmap.yml`, `config/locales/roadmap/en.yml`, `config/locales/roadmap/fr.yml` -- generated by running the script on the real initiative (empty roadmap today). -- the committed app data.
- [x] `test/lib/roadmap_export_test.rb` -- Minitest like the pixel art test: committed output matches (`--check`); a fixture initiative built in `Dir.mktmpdir` (two epics, entries with and without `roadmap`, plan files setting `status: done` / `in-progress`, one dropped) produces the expected YAML (parse with `YAML.load_file`), order and statuses; a second run changes nothing; `--check` fails after a plan status change and after a wording change, naming the file; bad field, orphan story and key clash fail with their message. -- covers the matrix.
- [x] `AGENTS.md` -- Policy: never hand-edit the three generated paths; after changing a `roadmap` field, or the status of a ticket or epic the roadmap shows, run `python3 script/roadmap/export.py` and commit its output (`--check` verifies, and `bin/rails test` fails on drift); the French bullet also allows `config/locales/roadmap/fr.yml` and a roadmap field's `fr`. -- keeps sessions in step.

**Acceptance Criteria:**
- Given the real initiative, when `python3 script/roadmap/export.py --check` runs right after the script, then it exits 0 and `bin/rails test test/lib/roadmap_export_test.rb` passes.
- Given a chosen ticket whose plan status changes, or whose `en`/`fr` wording changes, without rerunning the script, when `bin/rails test` runs, then the roadmap test fails naming the stale file.
- Given the generated files, when the app boots, then `I18n.t("roadmap.milestones", locale: :fr)` and `Rails.application.config_for(:roadmap)` load without error, and `bundle exec i18n-tasks missing` stays clean.

## Implementation Notes

- The roadmap fields stay unset in the real initiative: choosing what appears and its wording is the author's, so the committed roadmap is empty (`milestones: []`) until the author adds `roadmap = { en, fr }` to `[[epic]]` and `[[entry]]` tables and reruns the script.
- Each generated file starts with a one-line header saying it is written by the script.
- Keys YAML would read as booleans or numbers are quoted; a chosen entry in an epic folder missing from the initiative's `[[epic]]` list counts as an orphan.
- After review: non-printable characters are escaped in every scalar, a dropped chosen epic's entries are still validated, a relative `--out` resolves against the repo root, the locale test checks `I18n.exists?`, and the fixture covers a review-state story, a derived to-come epic and a frontmatter-done epic.

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 10 findings — high 0, medium 1, low 7, false 2, maybe-false 0
- findings:
  - `medium` `defer` AGENTS.md rerun rule misses unshown tickets of a shown epic, whose state moves the derived milestone status — reproduced by the reviewer; the fix edits AGENTS.md, so deferred to the author.
  - `low` `patch` `scalar()` left U+FEFF and C1 controls raw, which Psych refuses — every non-printable character is now escaped; a test reloads such a wording with `YAML.load_file`.
  - `low` `reject` an epic slug with no ASCII letters gives an empty key — epic folders are ASCII kebab-case slugs by convention; the fix is an added guard for a case not met in practice.
  - `low` `patch` a dropped chosen epic's entries skipped validation — entries are validated before the skip; a test covers it.
  - `low` `patch` the locale-loading test passed with `default: {}` even without the files loaded — it now asserts `I18n.exists?` in both locales.
  - `low` `patch` no test covered an epic whose frontmatter `done` wins over derivation — fixture epic `epic-wrapped-up` added.
  - `low` `patch` a relative `--out` resolved against the cwd unlike `--initiative` — now resolved against the repo root.
  - `false` `reject` French strings in the test fixture and the script's docstring break the English-only rule — 58 test files already hold French copy they assert, and the docstring shows a roadmap field's `fr` wording, which the new AGENTS.md bullet allows.
  - `low` `defer` python3 >= 3.11 is an undeclared requirement of `bin/rails test` — the fix edits AGENTS.md or `.tool-versions`.
  - `false` `reject` `package-lock.json` name changed by `npm install` in the worktree — not part of the reviewed diff; restored before commit.

## Design Notes

Generated shapes (keys: epic slug without `epic-`, entry title slug, both with `_`):

```yaml
# config/roadmap.yml
shared:
  milestones:
  - key: "visitor_landing"
    status: "in_progress"
    stories:
    - key: "the_roadmap_derives_from_the_initiative"
      status: "done"
# config/locales/roadmap/fr.yml
fr:
  roadmap:
    milestones:
      visitor_landing:
        name: "Bienvenue à bord"
        stories:
          the_roadmap_derives_from_the_initiative: "La feuille de route"
```

`shared:` lets story 11 read it with `config_for(:roadmap)`. Strings go in their own generated locale files rather than inside `en.yml`/`fr.yml`, which the script cannot rewrite safely. `review` (built, awaiting the author's staging check) maps to in progress: the roadmap never calls done what the author has not.

## Verification

**Commands:**
- `python3 script/roadmap/export.py --check` -- expected: exit 0, "up to date"
- `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w2010 bin/rails test test/lib/roadmap_export_test.rb` -- expected: all pass
- `bundle exec i18n-tasks missing` -- expected: no missing keys

## Auto Run Result

- **Summary:** `script/roadmap/export.py` turns opt-in `roadmap = { en = "...", fr = "..." }` fields on the initiative's `[[epic]]` tables and the epics' `[[entry]]` tables into `config/roadmap.yml` (milestone and story keys with done / in_progress / to_come statuses taken from `tickets.py status`) and `config/locales/roadmap/{en,fr}.yml` (the wording); `--check` and `test/lib/roadmap_export_test.rb` fail on drift; AGENTS.md tells every session to rerun it.
- **Files:**
  - `script/roadmap/export.py` — the generator, with `--check`, `--initiative` and `--out`.
  - `config/roadmap.yml`, `config/locales/roadmap/en.yml`, `config/locales/roadmap/fr.yml` — generated; empty until the author curates.
  - `test/lib/roadmap_export_test.rb` — the drift check on the committed files, plus a fixture initiative covering the matrix.
  - `AGENTS.md` — the never-hand-edit-and-rerun rule; French allowed in the generated fr file and a roadmap field's `fr`.
- **Review:** 5 patches applied (all low); 2 deferred (one medium, one low, both AGENTS.md or toolchain edits); 3 rejected (empty epic key: a guard for an unmet case; French in tests: false; package-lock: outside the diff, restored).
- **Follow-up review recommended:** false — patched 0 high, 0 medium, 5 low.
- **Verification:** `python3 script/roadmap/export.py --check` up to date; the roadmap test 16 runs, 0 failures; `bin/ci` passed (2724 runs, 0 failures; rubocop, packwerk, i18n-tasks missing, brakeman, schema checks); `bin/rails zeitwerk:check` and `npm run test:js` (407 tests) passed.
- **Residual risks:** the landing's roadmap stays empty until the author adds roadmap fields; every later status change of a ticket in a shown epic needs a rerun of the script, or the test suite fails.
