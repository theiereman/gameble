---
title: 'landing.css is cut under 500 lines'
type: 'refactor'
ticket: '20'
created: '2026-10-27'
status: 'built'
baseline_revision: '18466900cf365e4353f63ae82117f209c30cd405'
route: 'oneshot'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: false
warnings: []
deferred:
  - summary: >-
      script/compare_css_cascade has no test and is not wired into bin/ci.
    evidence: |-
      Verified once by hand (identical on this change; a changed value is reported). Entries 21 to 24 and 27 reuse it by hand.
    location: >-
      script/compare_css_cascade
    severity: low
  - summary: >-
      A plan under epic-card-catalog still names app/frontend/styles/landing.css.
    evidence: |-
      Historical plan text; the file no longer exists.
    location: >-
      _bmad-output/initiative-gameble/epic-card-catalog/story-a-visitor-s-way-in-to-every-card-plan.md
    severity: low
---

<intent-contract>

## Intent

**Problem:** landing.css is 2,054 lines, over the 500-line limit.

**Approach:** Split it into per-section files of at most 500 lines imported in the same cascade order from application.css, drop its section-divider comments, and commit script/compare_css_cascade to prove the cascade unchanged (comments and whitespace stripped, number and colour spelling normalized).

</intent-contract>

## Implementation Notes

Oneshot: a mechanical split at section boundaries. Seven files landing-{base,hero,concept,live,closing,responsive,gauge}.css (176 to 406 lines) replace landing.css; the file names carry what the divider comments said. script/compare_css_cascade resolves the imports in the tree and at a revision and diffs them.

## Plan Change Log

## Review Triage Log

### 2026-10-27 — Review pass
- verdicts: 24 findings — high 0, medium 0, low 8 real, false 0, maybe-false 0 (rest rejected as low or duplicates)
- findings:
  - `[low]` `[patch]` package-lock.json name changed by npm install in the worktree (reported by 3 lenses) — reverted, not staged
  - `[low]` `[patch]` unsupported @import forms left unresolved, import cycle, missing file (3 lenses) — script aborts with a message on each
  - `[low]` `[patch]` `+` spacing stripped inside calc() — `+` dropped from the whitespace normalization
  - `[low]` `[patch]` header documents baseline use and textual blind spots
  - `[low]` `[defer]` no test or CI wiring for the script; stale reference in an older plan
  - `[low]` `[reject]` HEAD default compares to itself after commit — header now says to name a revision; the epic runs it before committing
  - `[low]` `[reject]` normalization inside strings/url(), comments inside strings — textual blind spots documented; no such content in these files
  - `[low]` `[reject]` built-asset comparison, gauge-last ordering comment, divider and constraint comments removed — dividers only (all 19 comment lines were dividers); order is carried by the import order in application.css; Vite build ran in the system tests
  - `[low]` `[reject]` ticket id '20', seven-line import instead of one line, plan lacks recorded results — conforms to the tree's id scheme; the ticket itself states the one-line merge; results are in the final report

## Verification

- `script/compare_css_cascade HEAD` -- expected: Cascade identical
- `script/check_file_sizes` on the landing-*.css files -- expected: clean
- landing and public_profile system tests -- expected: pass

## Auto Run Result

Split landing.css (2,054 lines) into seven files of 176 to 406 lines, comments (19 section dividers) removed, same import position; added script/compare_css_cascade. Cascade identical to baseline; landing and public_profile system tests pass (36 runs, 0 failures).
